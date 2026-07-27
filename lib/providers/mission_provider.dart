import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/learner_profile_service.dart';
import '../services/supabase_service.dart';
import 'progress_provider.dart';

class MissionItem {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'lesson', 'practice', 'conversation', 'challenge', 'review'
  final Map<String, dynamic> targetData;
  final int xpReward;
  bool isCompleted;

  MissionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.targetData,
    this.xpReward = 30,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'type': type,
        'targetData': targetData,
        'xpReward': xpReward,
        'isCompleted': isCompleted,
      };

  factory MissionItem.fromJson(Map<String, dynamic> json) {
    return MissionItem(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      type: json['type'] as String,
      targetData: Map<String, dynamic>.from(json['targetData'] as Map? ?? {}),
      xpReward: json['xpReward'] as int? ?? 30,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

class MissionProvider extends ChangeNotifier {
  List<MissionItem> _missions = [];
  bool _isLoading = false;
  bool _bonusClaimed = false;

  List<MissionItem> get missions => _missions;
  bool get isLoading => _isLoading;
  bool get bonusClaimed => _bonusClaimed;

  bool get allCompleted =>
      _missions.isNotEmpty && _missions.every((m) => m.isCompleted);

  int get completedCount => _missions.where((m) => m.isCompleted).length;

  Future<void> initDailyMissions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final savedDate = await DbHelper.instance.getSetting('daily_mission_date');
      final savedJson = await DbHelper.instance.getSetting('daily_mission_json');
      final savedBonus = await DbHelper.instance.getSetting('daily_mission_bonus_claimed');

      if (savedDate == todayStr && savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedJson);
        _missions = list.map((e) => MissionItem.fromJson(e as Map<String, dynamic>)).toList();
        _bonusClaimed = savedBonus == 'true';
      } else {
        // Generate new missions for today
        await _generateMissionsForToday(todayStr);
      }
    } catch (e) {
      debugPrint("Error initializing daily missions: $e");
      _loadFallbackMissions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _generateMissionsForToday(String todayStr) async {
    try {
      final profile = await LearnerProfileService.instance.computeProfile();

      if (SupabaseService.instance.isInitialized) {
        try {
          final prompt =
              "Generate a 5-item daily English learning mission for a ${profile.cefrLevel} learner. "
              "Learner goal: ${profile.learningGoal}. Weakest area: ${profile.weakestGrammarCategory}. "
              "Output JSON array with 5 objects containing keys: "
              "\"id\", \"type\" (must be one of: \"lesson\", \"practice\", \"conversation\", \"challenge\", \"review\"), "
              "\"title\", \"subtitle\", \"xpReward\" (25-40). "
              "Return raw JSON array only.";

          final res = await SupabaseService.instance.invokeGroqProxy({
            'model': 'openai/gpt-oss-120b',
            'messages': [
              {"role": "system", "content": prompt}
            ],
            'temperature': 0.7,
            'response_format': {"type": "json_object"},
          });

          final reply = res['choices'][0]['message']['content'] as String;
          final parsed = jsonDecode(reply.trim());

          List<dynamic> itemsList = [];
          if (parsed is List) {
            itemsList = parsed;
          } else if (parsed is Map && parsed.containsKey('missions')) {
            itemsList = parsed['missions'] as List;
          } else if (parsed is Map && parsed.containsKey('items')) {
            itemsList = parsed['items'] as List;
          }

          if (itemsList.length >= 4) {
            _missions = itemsList.map((e) {
              final map = e as Map<String, dynamic>;
              return MissionItem(
                id: map['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
                title: map['title'] ?? 'Daily Practice Task',
                subtitle: map['subtitle'] ?? 'Improve your fluency',
                type: map['type'] ?? 'practice',
                targetData: {},
                xpReward: map['xpReward'] as int? ?? 30,
              );
            }).toList();

            await _saveMissionsToDb(todayStr);
            return;
          }
        } catch (e) {
          debugPrint("Groq mission generation failed, using profile fallback: $e");
        }
      }

      _loadProfileFallbackMissions(profile);
      await _saveMissionsToDb(todayStr);
    } catch (e) {
      debugPrint("Error generating missions: $e");
      _loadFallbackMissions();
    }
  }

  void _loadProfileFallbackMissions(LearnerProfile profile) {
    _missions = [
      MissionItem(
        id: 'm1',
        title: 'Grammar Focus: ${profile.weakestGrammarCategory.replaceAll('_', ' ').toUpperCase()}',
        subtitle: 'Complete 1 interactive lesson on ${profile.weakestGrammarCategory}',
        type: 'lesson',
        targetData: {'focus': profile.weakestGrammarCategory},
        xpReward: 30,
      ),
      MissionItem(
        id: 'm2',
        title: 'Vocabulary Sprint',
        subtitle: 'Review or save 5 words in your Smart Vocab Bank',
        type: 'practice',
        targetData: {},
        xpReward: 25,
      ),
      MissionItem(
        id: 'm3',
        title: 'AI Practice Call',
        subtitle: 'Topic: ${profile.recommendedTopic['title'] ?? "Daily Conversation"}',
        type: 'conversation',
        targetData: profile.recommendedTopic,
        xpReward: 40,
      ),
      MissionItem(
        id: 'm4',
        title: 'Scenario Challenge',
        subtitle: 'Roleplay a real-world scenario (Job Interview / Cafe / Meeting)',
        type: 'challenge',
        targetData: {},
        xpReward: 35,
      ),
      MissionItem(
        id: 'm5',
        title: 'Weak Area Spaced Review',
        subtitle: 'Resurface past grammar mistakes & correct them',
        type: 'review',
        targetData: {},
        xpReward: 30,
      ),
    ];
    _bonusClaimed = false;
  }

  void _loadFallbackMissions() {
    _missions = [
      MissionItem(
        id: 'm1',
        title: 'Daily Grammar Lesson',
        subtitle: 'Master key sentence structures & tense accuracy',
        type: 'lesson',
        targetData: {},
        xpReward: 30,
      ),
      MissionItem(
        id: 'm2',
        title: 'Vocabulary Practice',
        subtitle: 'Build your active word bank',
        type: 'practice',
        targetData: {},
        xpReward: 25,
      ),
      MissionItem(
        id: 'm3',
        title: '2-Min AI Voice Call',
        subtitle: 'Practice spoken fluency with live AI feedback',
        type: 'conversation',
        targetData: {},
        xpReward: 40,
      ),
      MissionItem(
        id: 'm4',
        title: 'Real-World Roleplay Challenge',
        subtitle: 'Practice high-impact everyday scenarios',
        type: 'challenge',
        targetData: {},
        xpReward: 35,
      ),
      MissionItem(
        id: 'm5',
        title: 'Mistake Review',
        subtitle: 'Correct your recent grammar slips',
        type: 'review',
        targetData: {},
        xpReward: 30,
      ),
    ];
    _bonusClaimed = false;
  }

  Future<void> _saveMissionsToDb(String todayStr) async {
    final jsonStr = jsonEncode(_missions.map((m) => m.toJson()).toList());
    await DbHelper.instance.setSetting('daily_mission_date', todayStr);
    await DbHelper.instance.setSetting('daily_mission_json', jsonStr);
    await DbHelper.instance.setSetting('daily_mission_bonus_claimed', _bonusClaimed.toString());
  }

  Future<void> completeMission(String id, ProgressProvider progressProvider) async {
    final index = _missions.indexWhere((m) => m.id == id);
    if (index != -1 && !_missions[index].isCompleted) {
      _missions[index].isCompleted = true;
      await progressProvider.addXP(_missions[index].xpReward);

      // Check if all completed and bonus not claimed
      if (allCompleted && !_bonusClaimed) {
        _bonusClaimed = true;
        await progressProvider.addXP(150); // Mission Complete Bonus!
      }

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      await _saveMissionsToDb(todayStr);
      notifyListeners();
    }
  }

  Future<void> refreshMissions() async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    _isLoading = true;
    notifyListeners();
    await _generateMissionsForToday(todayStr);
    _isLoading = false;
    notifyListeners();
  }
}

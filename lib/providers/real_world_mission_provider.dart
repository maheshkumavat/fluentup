import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/learner_profile_service.dart';
import '../services/supabase_service.dart';
import 'progress_provider.dart';

class RealWorldMission {
  final String id;
  final String title;
  final String description;
  final int difficultyTier; // 1-5
  final int fearLevel; // 1-8
  final int realWorldXpReward;
  bool isCompleted;
  String? reflectionText;

  RealWorldMission({
    required this.id,
    required this.title,
    required this.description,
    required this.difficultyTier,
    required this.fearLevel,
    this.realWorldXpReward = 50,
    this.isCompleted = false,
    this.reflectionText,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'difficultyTier': difficultyTier,
        'fearLevel': fearLevel,
        'realWorldXpReward': realWorldXpReward,
        'isCompleted': isCompleted,
        'reflectionText': reflectionText,
      };

  factory RealWorldMission.fromJson(Map<String, dynamic> json) {
    return RealWorldMission(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      difficultyTier: json['difficultyTier'] as int? ?? 1,
      fearLevel: json['fearLevel'] as int? ?? 1,
      realWorldXpReward: json['realWorldXpReward'] as int? ?? 50,
      isCompleted: json['isCompleted'] as bool? ?? false,
      reflectionText: json['reflectionText'] as String?,
    );
  }
}

class RealWorldMissionProvider extends ChangeNotifier {
  List<RealWorldMission> _missions = [];
  int _realWorldXP = 0;
  int _completedMissionsCount = 0;
  int _currentFearLevel = 1;
  bool _isLoading = false;

  List<RealWorldMission> get missions => _missions;
  int get realWorldXP => _realWorldXP;
  int get completedMissionsCount => _completedMissionsCount;
  int get currentFearLevel => _currentFearLevel;
  bool get isLoading => _isLoading;

  static const List<String> fearLevelLabels = [
    "Speak to AI Voice Partner",
    "Record Voice Note",
    "Video Pitch Recording",
    "Speak to Family Member",
    "Speak to Friend in English",
    "Speak to Unknown Person / Stranger",
    "Deliver a Formal Presentation",
    "Real High-Stakes Interview",
  ];

  Future<void> initRealWorldMissions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final savedXp = await DbHelper.instance.getSetting('user_real_world_xp');
      _realWorldXP = int.tryParse(savedXp ?? '0') ?? 0;

      final savedCount = await DbHelper.instance.getSetting('real_world_missions_count');
      _completedMissionsCount = int.tryParse(savedCount ?? '0') ?? 0;

      final savedFear = await DbHelper.instance.getSetting('fear_level');
      _currentFearLevel = int.tryParse(savedFear ?? '1') ?? 1;

      final savedJson = await DbHelper.instance.getSetting('real_world_missions_json');
      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedJson);
        _missions = list.map((e) => RealWorldMission.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        await generateRealWorldMissions();
      }
    } catch (e) {
      debugPrint("Error initializing Real World Missions: $e");
      _loadFallbackMissions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> generateRealWorldMissions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final profile = await LearnerProfileService.instance.computeProfile();

      if (SupabaseService.instance.isInitialized) {
        try {
          final prompt =
              "Generate 5 real-world offline English speaking missions for a ${profile.cefrLevel} learner in India. "
              "Learner goal: ${profile.learningGoal}. Current Fear Level: $_currentFearLevel/8. "
              "These should be achievable actions outside the app (e.g. asking security guard, ordering at shop, introducing to colleague). "
              "Output JSON array with 5 objects containing keys: "
              "\"id\", \"title\", \"description\", \"difficultyTier\" (1-5), \"fearLevel\" (1-8), \"realWorldXpReward\" (40-100). "
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
          }

          if (itemsList.length >= 3) {
            _missions = itemsList.map((e) {
              final map = e as Map<String, dynamic>;
              return RealWorldMission(
                id: map['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
                title: map['title'] ?? 'Real World Speaking Challenge',
                description: map['description'] ?? 'Speak in English outside the app',
                difficultyTier: map['difficultyTier'] as int? ?? 2,
                fearLevel: map['fearLevel'] as int? ?? _currentFearLevel,
                realWorldXpReward: map['realWorldXpReward'] as int? ?? 50,
              );
            }).toList();

            await _saveStateToDb();
            _isLoading = false;
            notifyListeners();
            return;
          }
        } catch (e) {
          debugPrint("Groq real world mission generation failed, using fallbacks: $e");
        }
      }

      _loadFallbackMissions();
      await _saveStateToDb();
    } catch (e) {
      debugPrint("Error generating real world missions: $e");
      _loadFallbackMissions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadFallbackMissions() {
    _missions = [
      RealWorldMission(
        id: 'rw1',
        title: 'Greet a Security Guard in English',
        description: 'Ask a security guard or shopkeeper "How is your day going?" in clear English.',
        difficultyTier: 1,
        fearLevel: 1,
        realWorldXpReward: 50,
      ),
      RealWorldMission(
        id: 'rw2',
        title: 'Order Something at a Shop / Cafe',
        description: 'Order your coffee or food item in 100% English without switching languages.',
        difficultyTier: 2,
        fearLevel: 2,
        realWorldXpReward: 60,
      ),
      RealWorldMission(
        id: 'rw3',
        title: '2-Minute Self Voice Note',
        description: 'Record yourself describing your daily routine or today\'s plan on your phone.',
        difficultyTier: 2,
        fearLevel: 2,
        realWorldXpReward: 50,
      ),
      RealWorldMission(
        id: 'rw4',
        title: 'Introduce Yourself to a Peer',
        description: 'Tell a coworker or classmate 3 interesting facts about your work or hobbies in English.',
        difficultyTier: 3,
        fearLevel: 4,
        realWorldXpReward: 75,
      ),
      RealWorldMission(
        id: 'rw5',
        title: 'Explain Your Project to Someone',
        description: 'Explain a technical concept or project you are building to a friend in English.',
        difficultyTier: 4,
        fearLevel: 6,
        realWorldXpReward: 90,
      ),
    ];
  }

  Future<void> completeMission(
    String id,
    ProgressProvider progressProvider, {
    String? reflectionText,
  }) async {
    final index = _missions.indexWhere((m) => m.id == id);
    if (index != -1 && !_missions[index].isCompleted) {
      _missions[index].isCompleted = true;
      _missions[index].reflectionText = reflectionText;

      final reward = _missions[index].realWorldXpReward;
      _realWorldXP += reward;
      _completedMissionsCount++;

      // Progress Fear Level if mission fearLevel is >= current level
      if (_missions[index].fearLevel >= _currentFearLevel && _currentFearLevel < 8) {
        _currentFearLevel++;
      }

      await progressProvider.addXP(reward);
      await _saveStateToDb();
      notifyListeners();
    }
  }

  Future<void> _saveStateToDb() async {
    final jsonStr = jsonEncode(_missions.map((m) => m.toJson()).toList());
    await DbHelper.instance.setSetting('user_real_world_xp', _realWorldXP.toString());
    await DbHelper.instance.setSetting('real_world_missions_count', _completedMissionsCount.toString());
    await DbHelper.instance.setSetting('fear_level', _currentFearLevel.toString());
    await DbHelper.instance.setSetting('real_world_missions_json', jsonStr);
  }
}

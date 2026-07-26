import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/learner_profile_service.dart';
import '../services/supabase_service.dart';

class RoadmapDay {
  final int dayNumber;
  final String title;
  final String description;
  final String activityType; // 'call', 'gym', 'vocab', 'code', 'roleplay'
  final String targetTopicId;
  final bool isUnlocked;
  final bool isCompleted;

  RoadmapDay({
    required this.dayNumber,
    required this.title,
    required this.description,
    required this.activityType,
    required this.targetTopicId,
    required this.isUnlocked,
    required this.isCompleted,
  });
}

class RoadmapProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _dynamicDays = [];
  List<int> _completedDays = [];
  bool _isLoading = false;
  bool _isGeneratingBatch = false;

  bool get isLoading => _isLoading;
  bool get isGeneratingBatch => _isGeneratingBatch;
  List<int> get completedDays => _completedDays;

  // Default seed days if DB is empty before first Groq extension
  final List<Map<String, dynamic>> _defaultSeedDays = [
    {
      "day_number": 1,
      "title": "Introduce Yourself",
      "description": "Voice practice: Tell your AI coach about your background & daily routine.",
      "activity_type": "call",
      "target_topic_id": "dl_1",
    },
    {
      "day_number": 2,
      "title": "Past Tense Precision",
      "description": "Grammar Gym: Master past simple vs present perfect structures.",
      "activity_type": "gym",
      "target_topic_id": "past",
    },
    {
      "day_number": 3,
      "title": "Job Interview Warmup",
      "description": "Voice practice: Answer introduction & background questions.",
      "activity_type": "call",
      "target_topic_id": "pro_1",
    },
    {
      "day_number": 4,
      "title": "High-Impact Vocabulary",
      "description": "Vocabulary: Master 5 new workplace terms with real-world context.",
      "activity_type": "vocab",
      "target_topic_id": "vocab",
    },
    {
      "day_number": 5,
      "title": "Project Status Update",
      "description": "Voice practice: Deliver a progress report on your current project.",
      "activity_type": "call",
      "target_topic_id": "pro_3",
    },
  ];

  Future<void> initRoadmap() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dbDays = await DbHelper.instance.getAllDynamicRoadmapDays();
      if (dbDays.isEmpty) {
        await DbHelper.instance.insertDynamicRoadmapDays(_defaultSeedDays);
        _dynamicDays = await DbHelper.instance.getAllDynamicRoadmapDays();
      } else {
        _dynamicDays = dbDays;
      }

      _completedDays = await DbHelper.instance.getCompletedRoadmapDays();
    } catch (e) {
      debugPrint("Error initializing roadmap: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<RoadmapDay> get roadmapDays {
    List<RoadmapDay> list = [];
    int maxCompleted = _completedDays.isEmpty ? 0 : _completedDays.reduce((a, b) => a > b ? a : b);

    for (var d in _dynamicDays) {
      int dayNum = (d['day_number'] as num).toInt();
      bool isComp = _completedDays.contains(dayNum) || (d['is_completed'] as int? ?? 0) == 1;
      bool isUnl = (dayNum == 1) || _completedDays.contains(dayNum - 1) || (dayNum <= maxCompleted + 1);

      list.add(RoadmapDay(
        dayNumber: dayNum,
        title: d['title'] as String? ?? 'Day $dayNum Practice',
        description: d['description'] as String? ?? 'Personalized English speaking practice session.',
        activityType: d['activity_type'] as String? ?? 'call',
        targetTopicId: d['target_topic_id'] as String? ?? 'dl_1',
        isUnlocked: isUnl,
        isCompleted: isComp,
      ));
    }
    return list;
  }

  RoadmapDay? get currentFocusDay {
    final days = roadmapDays;
    for (var d in days) {
      if (!d.isCompleted && d.isUnlocked) {
        return d;
      }
    }
    return days.isNotEmpty ? days.last : null;
  }

  Future<void> markDayCompleted(int dayNumber) async {
    if (!_completedDays.contains(dayNumber)) {
      _completedDays.add(dayNumber);
      notifyListeners();

      try {
        await DbHelper.instance.completeDynamicRoadmapDay(dayNumber);
      } catch (e) {
        debugPrint("Error completing roadmap day: $e");
      }

      // Check if auto-extension is needed (user completed last or second-to-last day)
      final highestDay = _dynamicDays.fold<int>(0, (max, d) {
        final dayVal = (d['day_number'] as num).toInt();
        return dayVal > max ? dayVal : max;
      });

      if (dayNumber >= highestDay - 1) {
        generateNextBatchAuto();
      }
    }
  }

  /// Dynamically generates the next 5 days batch using Groq based on performance data
  Future<void> generateNextBatchAuto() async {
    if (_isGeneratingBatch) return;

    _isGeneratingBatch = true;
    notifyListeners();

    try {
      final profile = await LearnerProfileService.instance.computeProfile();
      final recentScores = await DbHelper.instance.getRecentSessionScores(5);

      double avgScore = 7.5;
      if (recentScores.isNotEmpty) {
        double sum = 0;
        for (var s in recentScores) {
          sum += (s['overall_score'] as num? ?? 7.5).toDouble();
        }
        avgScore = sum / recentScores.length;
      }

      final highestDay = _dynamicDays.fold<int>(0, (max, d) {
        final dayVal = (d['day_number'] as num).toInt();
        return dayVal > max ? dayVal : max;
      });

      final startDay = highestDay + 1;

      String paceAdaptation;
      if (avgScore >= 8.5) {
        paceAdaptation = "Learner performance is excellent (Avg Score: ${avgScore.toStringAsFixed(1)}). Accelerate pace with advanced topics and higher CEFR complexity.";
      } else if (avgScore <= 6.5) {
        paceAdaptation = "Learner is currently struggling (Avg Score: ${avgScore.toStringAsFixed(1)}). Provide targeted reinforcement and supportive, structured exercises for ${profile.weakestGrammarCategory}.";
      } else {
        paceAdaptation = "Learner is making steady progress (Avg Score: ${avgScore.toStringAsFixed(1)}). Balance practice calls with grammar gym and vocabulary themes.";
      }

      final systemPrompt = "You are an expert adaptive English coach. Generate the next 5 days of a personalized practice roadmap starting from Day $startDay.\n"
          "Learner Profile: CEFR level '${profile.cefrLevel}', weakest grammar area '${profile.weakestGrammarCategory}', learning goal '${profile.learningGoal}'.\n"
          "Performance Context: $paceAdaptation\n"
          "Each day must have ONE clear focus (a Practice Call topic, Grammar Gym, Vocabulary, or Roleplay scenario) that logically builds on prior days.\n"
          "Respond ONLY in valid JSON array format containing 5 objects with exact keys:\n"
          "[\n"
          "  {\n"
          "    \"day_number\": $startDay,\n"
          "    \"title\": \"Short catchy title\",\n"
          "    \"description\": \"1 sentence description\",\n"
          "    \"activity_type\": \"call/gym/vocab/roleplay/code\",\n"
          "    \"target_topic_id\": \"dl_1 or pro_1 or past or vocab\"\n"
          "  }\n"
          "]";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": systemPrompt}
        ],
        'temperature': 0.7,
      });

      final jsonText = data['choices'][0]['message']['content'] as String;
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(jsonText);
      final rawList = jsonMatch != null ? jsonDecode(jsonMatch.group(0)!) as List : jsonDecode(jsonText.trim()) as List;

      List<Map<String, dynamic>> newDays = [];
      int dayNumCounter = startDay;
      for (var item in rawList) {
        final map = Map<String, dynamic>.from(item as Map);
        newDays.add({
          "day_number": dayNumCounter,
          "title": map['title'] as String? ?? "Day $dayNumCounter Focus",
          "description": map['description'] as String? ?? "Personalized speaking practice.",
          "activity_type": map['activity_type'] as String? ?? "call",
          "target_topic_id": map['target_topic_id'] as String? ?? "dl_1",
          "is_completed": 0,
        });
        dayNumCounter++;
      }

      await DbHelper.instance.insertDynamicRoadmapDays(newDays);
      _dynamicDays = await DbHelper.instance.getAllDynamicRoadmapDays();
    } catch (e) {
      debugPrint("Error generating dynamic roadmap batch: $e");
    } finally {
      _isGeneratingBatch = false;
      notifyListeners();
    }
  }
}

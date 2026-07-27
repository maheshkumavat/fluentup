import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/db_helper.dart';
import '../services/supabase_service.dart';

class CurriculumUnit {
  final String id;
  final String level;
  final String title;
  final String explanation;
  final String exampleCorrect;
  final String exampleCommonMistake;

  CurriculumUnit({
    required this.id,
    required this.level,
    required this.title,
    required this.explanation,
    required this.exampleCorrect,
    required this.exampleCommonMistake,
  });

  factory CurriculumUnit.fromJson(Map<String, dynamic> json) {
    return CurriculumUnit(
      id: json['id'] as String,
      level: json['level'] as String,
      title: json['title'] as String,
      explanation: json['explanation'] as String,
      exampleCorrect: json['example_correct'] as String,
      exampleCommonMistake: json['example_common_mistake'] as String,
    );
  }
}

class PracticeItem {
  final String prompt;
  final String expects; // 'typed' or 'spoken'
  String? userAnswer;
  bool? isCorrect;
  String? correctedSentence;
  String? explanation;

  PracticeItem({
    required this.prompt,
    required this.expects,
    this.userAnswer,
    this.isCorrect,
    this.correctedSentence,
    this.explanation,
  });
}

class UnitMastery {
  final String unitId;
  final int score;
  final int attempts;
  final String lastAttemptedDate;

  UnitMastery({
    required this.unitId,
    required this.score,
    required this.attempts,
    required this.lastAttemptedDate,
  });
}

class GymProvider extends ChangeNotifier {
  List<CurriculumUnit> _allUnits = [];
  Map<String, UnitMastery> _masteryMap = {};
  bool _isCurriculumLoaded = false;
  String? _userPlacementLevel;

  // Active Session State
  CurriculumUnit? _activeUnit;
  List<PracticeItem> _activeItems = [];
  int _currentItemIndex = 0;
  bool _isSessionLoading = false;
  bool _isItemSubmitting = false;
  int _sessionCorrectCount = 0;
  bool _isSessionCompleted = false;
  int _calculatedSessionScore = 0;
  String? _sessionErrorMessage;

  // Level Up Celebration Trigger
  String? _unlockedCelebrationLevel;

  // Adaptive Review Trigger
  int _completedSessionsCount = 0;
  CurriculumUnit? _adaptiveReviewUnit;

  // Getters
  List<CurriculumUnit> get allUnits => _allUnits;
  bool get isCurriculumLoaded => _isCurriculumLoaded;
  Map<String, UnitMastery> get masteryMap => _masteryMap;

  CurriculumUnit? get activeUnit => _activeUnit;
  List<PracticeItem> get activeItems => _activeItems;
  int get currentItemIndex => _currentItemIndex;
  bool get isSessionLoading => _isSessionLoading;
  bool get isItemSubmitting => _isItemSubmitting;
  bool get isSessionCompleted => _isSessionCompleted;
  int get sessionCorrectCount => _sessionCorrectCount;
  int get calculatedSessionScore => _calculatedSessionScore;
  String? get sessionErrorMessage => _sessionErrorMessage;

  // Enhanced Explanation State
  Map<String, dynamic>? _activeUnitSimpleExplanation;
  bool _isExplanationLoading = false;

  Map<String, dynamic>? get activeUnitSimpleExplanation => _activeUnitSimpleExplanation;
  bool get isExplanationLoading => _isExplanationLoading;

  String? get unlockedCelebrationLevel => _unlockedCelebrationLevel;
  CurriculumUnit? get adaptiveReviewUnit => _adaptiveReviewUnit;

  List<String> get levels => ['A1', 'A2', 'B1', 'B2', 'C1'];

  void clearLevelCelebration() {
    _unlockedCelebrationLevel = null;
    notifyListeners();
  }

  void clearAdaptiveReviewPrompt() {
    _adaptiveReviewUnit = null;
    notifyListeners();
  }

  List<CurriculumUnit> getUnitsForLevel(String level) {
    return _allUnits.where((u) => u.level == level).toList();
  }

  bool isUnitMastered(String unitId) {
    return (_masteryMap[unitId]?.score ?? 0) >= 75;
  }

  int getUnitScore(String unitId) {
    return _masteryMap[unitId]?.score ?? 0;
  }

  int getUnitAttempts(String unitId) {
    return _masteryMap[unitId]?.attempts ?? 0;
  }

  bool isUnitUnlocked(CurriculumUnit unit) {
    final index = _allUnits.indexWhere((u) => u.id == unit.id);
    if (index <= 0) return true; // First unit is always unlocked

    // Check Placement Unlocking
    if (_userPlacementLevel != null) {
      if (_userPlacementLevel == 'Intermediate') {
        if (unit.level == 'A1' || unit.level == 'A2' || (unit.level == 'B1' && unit.id == 'b1_u1')) {
          return true;
        }
      } else if (_userPlacementLevel == 'Advanced') {
        if (unit.level == 'A1' || unit.level == 'A2' || unit.level == 'B1' || (unit.level == 'B2' && unit.id == 'b2_u1')) {
          return true;
        }
      } else if (_userPlacementLevel == 'Beginner') {
        if (unit.level == 'A1' || (unit.level == 'A2' && unit.id == 'a2_u1')) {
          return true;
        }
      }
    }

    // Previous unit must be mastered
    final previousUnit = _allUnits[index - 1];
    return isUnitMastered(previousUnit.id);
  }

  double get overallProgressPercentage {
    if (_allUnits.isEmpty) return 0.0;
    final masteredCount = _allUnits.where((u) => isUnitMastered(u.id)).length;
    return masteredCount / _allUnits.length;
  }

  String get currentCefrLevel {
    for (final level in levels.reversed) {
      final units = getUnitsForLevel(level);
      if (units.any((u) => isUnitUnlocked(u))) {
        return level;
      }
    }
    return 'A1';
  }

  Future<void> initCurriculum() async {
    try {
      final jsonString = await rootBundle.loadString('assets/curriculum.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _allUnits = jsonList.map((e) => CurriculumUnit.fromJson(e as Map<String, dynamic>)).toList();

      await reloadMasteryData();

      // Read Placement Level from baseline assessment or settings
      final placement = await DbHelper.instance.getSetting('baseline_level');
      final latestAssessment = await DbHelper.instance.getLatestAssessment();
      _userPlacementLevel = placement ?? latestAssessment?['overall_level'] as String?;

      _isCurriculumLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading curriculum: $e");
    }
  }

  Future<void> reloadMasteryData() async {
    final records = await DbHelper.instance.getAllGrammarMastery();
    _masteryMap = {
      for (final r in records)
        r['unit_id'] as String: UnitMastery(
          unitId: r['unit_id'] as String,
          score: r['score'] as int,
          attempts: r['attempts'] as int,
          lastAttemptedDate: r['last_attempted_date'] as String,
        )
    };
    notifyListeners();
  }

  Future<void> fetchEnhancedUnitExplanation(CurriculumUnit unit) async {
    _isExplanationLoading = true;
    _activeUnitSimpleExplanation = null;
    notifyListeners();

    try {
      if (SupabaseService.instance.isInitialized) {
        final prompt =
            "You are a friendly, plain-spoken English grammar coach. Explain '${unit.title}' for an English learner.\n"
            "STRICT RULES:\n"
            "1. Use simple everyday language. Avoid grammar jargon like 'past participle', 'gerund', or 'clause' (e.g. say 'the word form for completed past events').\n"
            "2. Provide 3 concrete example sentences showing correct usage.\n"
            "3. Specifically call out 2 common mistakes Hindi-speaking English learners make for this concept (e.g. article misuse, using 'having', or direct word order translation habits).\n\n"
            "Respond strictly in JSON object:\n"
            "{\n"
            "  \"simple_explanation\": \"2-3 plain language sentences\",\n"
            "  \"examples\": [\"Example 1\", \"Example 2\", \"Example 3\"],\n"
            "  \"hindi_learner_tips\": [\"Tip 1 addressing common Hindi speaker mistake\", \"Tip 2 addressing another mistake\"]\n"
            "}";

        final data = await SupabaseService.instance.invokeGroqProxy({
          'model': 'openai/gpt-oss-120b',
          'messages': [
            {"role": "system", "content": prompt}
          ],
          'temperature': 0.4,
          'response_format': {"type": "json_object"},
        });

        final replyText = data['choices'][0]['message']['content'] as String;
        _activeUnitSimpleExplanation = jsonDecode(replyText.trim());
      }
    } catch (e) {
      debugPrint("Groq explanation generation fallback: $e");
    } finally {
      if (_activeUnitSimpleExplanation == null) {
        _activeUnitSimpleExplanation = {
          "simple_explanation": unit.explanation,
          "examples": [
            unit.exampleCorrect,
            "I practice English for 20 minutes every morning.",
            "They completed the project on time."
          ],
          "hindi_learner_tips": [
            "Avoid direct translation habits from Hindi sentence order.",
            "Watch out for common mistake: '${unit.exampleCommonMistake}'"
          ]
        };
      }
      _isExplanationLoading = false;
      notifyListeners();
    }
  }

  Future<void> startUnitPractice(CurriculumUnit unit, {int itemCount = 5}) async {
    _activeUnit = unit;
    _currentItemIndex = 0;
    _sessionCorrectCount = 0;
    _isSessionCompleted = false;
    _calculatedSessionScore = 0;
    _sessionErrorMessage = null;
    _activeItems = [];
    _isSessionLoading = true;
    notifyListeners();

    try {
      final items = <PracticeItem>[];

      if (SupabaseService.instance.isInitialized) {
        try {
          final systemPrompt =
              "Generate 5 short practice test questions for '${unit.title}' (${unit.explanation}) for a ${unit.level} English learner. "
              "Questions 1-2: Fill-in-the-blank sentence. Questions 3-4: 'Is this sentence correct?' (True/False or fix the mistake). Question 5: Spoken practice sentence. "
              "Respond strictly in JSON: {\"questions\": [{\"prompt\": \"...\", \"expects\": \"typed\"}, ..., {\"prompt\": \"...\", \"expects\": \"spoken\"}]}.";

          final data = await SupabaseService.instance.invokeGroqProxy({
            'model': 'openai/gpt-oss-120b',
            'messages': [
              {"role": "system", "content": systemPrompt}
            ],
            'temperature': 0.7,
            'response_format': {"type": "json_object"},
          });

          final replyText = data['choices'][0]['message']['content'] as String;
          final parsed = jsonDecode(replyText.trim());
          List qList = [];
          if (parsed is Map && parsed.containsKey('questions')) {
            qList = parsed['questions'] as List;
          } else if (parsed is List) {
            qList = parsed;
          }

          for (int i = 0; i < qList.length; i++) {
            final q = qList[i] as Map;
            final isLast = (i == qList.length - 1);
            items.add(PracticeItem(
              prompt: q['prompt'] ?? "Question ${i + 1} for ${unit.title}:",
              expects: isLast ? 'spoken' : (q['expects'] ?? 'typed'),
            ));
          }
        } catch (e) {
          debugPrint("Groq test questions batch fallback: $e");
        }
      }

      if (items.isEmpty) {
        for (int i = 0; i < itemCount; i++) {
          final isSpoken = (i == itemCount - 1);
          items.add(_generateFallbackItem(unit, isSpoken: isSpoken, index: i));
        }
      }

      _activeItems = items;
    } catch (e) {
      _sessionErrorMessage = "Failed to load practice items. Please try again.";
      debugPrint("Error starting unit practice: $e");
    } finally {
      _isSessionLoading = false;
      notifyListeners();
    }
  }

  PracticeItem _generateFallbackItem(CurriculumUnit unit, {required bool isSpoken, required int index}) {
    if (isSpoken) {
      return PracticeItem(
        prompt: "Say a complete sentence applying: '${unit.title}'. Correct example: '${unit.exampleCorrect}'",
        expects: 'spoken',
      );
    } else {
      final promptsList = [
        "Fill in the blank using the correct rule for '${unit.title}': '${unit.exampleCorrect.replaceAll(RegExp(r'\b\w+\b'), '___')}'",
        "Correct this sentence mistake: '${unit.exampleCommonMistake}'",
        "Write a short sentence demonstrating: '${unit.title}'",
      ];
      return PracticeItem(
        prompt: promptsList[index % promptsList.length],
        expects: 'typed',
      );
    }
  }

  Future<void> submitItemAnswer(String answer) async {
    if (_activeUnit == null || _currentItemIndex >= _activeItems.length) return;
    if (answer.trim().isEmpty) return;

    _isItemSubmitting = true;
    _sessionErrorMessage = null;
    notifyListeners();

    final item = _activeItems[_currentItemIndex];
    item.userAnswer = answer.trim();

    try {
      final systemPrompt =
          "You are a strict but kind English grammar coach evaluating '${_activeUnit!.title}'. "
          "The student was asked: '${item.prompt}'. They answered: '$answer'. "
          "Check specifically for grammar accuracy regarding '${_activeUnit!.title}'. "
          "Respond in JSON: {\"correct\": true/false, \"corrected_sentence\": \"...\", \"explanation\": \"one simple sentence explaining the fix, no grammar jargon\"}. "
          "Plain text JSON only, no emojis.";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": systemPrompt}
        ],
        'temperature': 0.3,
        'response_format': {"type": "json_object"},
      });

      final replyText = data['choices'][0]['message']['content'] as String;
      final result = jsonDecode(replyText.trim());

      item.isCorrect = result['correct'] == true;
      item.correctedSentence = result['corrected_sentence'] ?? answer;
      item.explanation = result['explanation'] ?? (item.isCorrect! ? "Great job!" : "Review example: ${_activeUnit!.exampleCorrect}");

      if (item.isCorrect!) {
        _sessionCorrectCount++;
      } else {
        await DbHelper.instance.insertMistake(
          item.prompt,
          answer,
          item.correctedSentence!,
          _activeUnit!.title,
          DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint("Error grading item answer: $e");
      // Fallback simple grading if network fails
      item.isCorrect = answer.trim().length > 3;
      item.correctedSentence = item.isCorrect! ? answer : _activeUnit!.exampleCorrect;
      item.explanation = item.isCorrect! ? "Good attempt!" : "Correct example: ${_activeUnit!.exampleCorrect}";
      if (item.isCorrect!) _sessionCorrectCount++;
    } finally {
      _isItemSubmitting = false;
      notifyListeners();
    }
  }

  void nextItem() {
    if (_currentItemIndex < _activeItems.length - 1) {
      _currentItemIndex++;
      notifyListeners();
    } else {
      finishSession();
    }
  }

  Future<void> finishSession() async {
    if (_activeUnit == null || _activeItems.isEmpty) return;

    final score = ((_sessionCorrectCount / _activeItems.length) * 100).round();
    _calculatedSessionScore = score;
    _isSessionCompleted = true;

    final previousMastery = _masteryMap[_activeUnit!.id];
    final attempts = (previousMastery?.attempts ?? 0) + 1;
    final highestScore = (previousMastery != null && previousMastery.score > score) ? previousMastery.score : score;

    await DbHelper.instance.saveGrammarMastery(_activeUnit!.id, highestScore, attempts);
    await reloadMasteryData();

    _completedSessionsCount++;

    // Check Level Up Celebration Trigger
    final currentLevelUnits = getUnitsForLevel(_activeUnit!.level);
    final allLevelMastered = currentLevelUnits.every((u) => isUnitMastered(u.id));
    if (allLevelMastered) {
      final currentLevelIdx = levels.indexOf(_activeUnit!.level);
      if (currentLevelIdx < levels.length - 1) {
        _unlockedCelebrationLevel = levels[currentLevelIdx + 1];
      }
    }

    // Check Adaptive Review Trigger (Every 5 completed sessions)
    if (_completedSessionsCount % 5 == 0) {
      _checkAdaptiveReviewNeeded();
    }

    notifyListeners();
  }

  void _checkAdaptiveReviewNeeded() {
    final masteredUnits = _allUnits.where((u) {
      final score = getUnitScore(u.id);
      return score >= 75 && score < 90;
    }).toList();

    if (masteredUnits.isNotEmpty) {
      // Pick lowest scoring past unit
      masteredUnits.sort((a, b) => getUnitScore(a.id).compareTo(getUnitScore(b.id)));
      _adaptiveReviewUnit = masteredUnits.first;
    }
  }
}

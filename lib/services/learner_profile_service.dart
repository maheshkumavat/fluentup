import 'package:flutter/foundation.dart';
import 'db_helper.dart';

class LearnerProfile {
  final String userName;
  final String learningGoal;
  final String cefrLevel;
  final double avgFluency;
  final double avgGrammar;
  final double avgVocabulary;
  final double avgPronunciation;
  final double overallScore;
  final String weakestGrammarCategory;
  final List<int> recentFillerWordCounts;
  final String levelSummary;
  final Map<String, String> recommendedTopic;

  const LearnerProfile({
    required this.userName,
    required this.learningGoal,
    required this.cefrLevel,
    required this.avgFluency,
    required this.avgGrammar,
    required this.avgVocabulary,
    required this.avgPronunciation,
    required this.overallScore,
    required this.weakestGrammarCategory,
    required this.recentFillerWordCounts,
    required this.levelSummary,
    required this.recommendedTopic,
  });
}

class LearnerProfileService {
  static final LearnerProfileService _instance = LearnerProfileService._internal();
  static LearnerProfileService get instance => _instance;
  LearnerProfileService._internal();

  /// Computes the LearnerProfile fresh on read from SQLite history
  Future<LearnerProfile> computeProfile() async {
    try {
      final db = DbHelper.instance;

      // 0. Fetch User Name & Learning Goal
      final userName = await db.getSetting('user_name') ?? 'Learner';
      final learningGoal = await db.getSetting('learning_goal') ?? 'Daily conversation confidence';

      // 1. Determine CEFR Level
      String cefr = 'B1';
      final assessment = await db.getLatestAssessment();
      if (assessment != null && assessment['placement_level'] != null) {
        cefr = assessment['placement_level'] as String;
      } else {
        final savedLevel = await db.getSetting('user_cefr_level');
        if (savedLevel != null && savedLevel.isNotEmpty) {
          cefr = savedLevel;
        }
      }

      // 2. Fetch session history & mistake stats
      final mistakeStats = await db.getMistakeCountsByTense();
      final recentScores = await db.getRecentSessionScores(10);

      double totalFluency = 0;
      double totalGrammar = 0;
      double totalVocab = 0;
      double totalPron = 0;
      double totalOverall = 0;
      final List<int> fillerCounts = [];

      if (recentScores.isNotEmpty) {
        for (var s in recentScores) {
          totalFluency += (s['fluency'] as num? ?? 7).toDouble();
          totalGrammar += (s['grammar'] as num? ?? 7).toDouble();
          totalVocab += (s['vocabulary'] as num? ?? 7).toDouble();
          totalPron += (s['pronunciation'] as num? ?? 7).toDouble();
          totalOverall += (s['overall_score'] as num? ?? 7.5).toDouble();
          fillerCounts.add((s['filler_word_count'] as num? ?? 0).toInt());
        }
        final len = recentScores.length;
        totalFluency /= len;
        totalGrammar /= len;
        totalVocab /= len;
        totalPron /= len;
        totalOverall /= len;
      } else {
        totalFluency = 7.5;
        totalGrammar = 7.5;
        totalVocab = 7.5;
        totalPron = 7.5;
        totalOverall = 7.5;
        fillerCounts.addAll([2, 1, 3]);
      }

      // 3. Compute Weakest Grammar Category
      String weakestCat = 'past_tense';
      int maxMistakes = -1;
      mistakeStats.forEach((key, val) {
        if (val > maxMistakes) {
          maxMistakes = val;
          weakestCat = key;
        }
      });

      if (maxMistakes <= 0) {
        // Fallback based on lowest average subscore
        if (totalGrammar <= totalVocab && totalGrammar <= totalFluency) {
          weakestCat = 'past_tense';
        } else if (totalVocab <= totalFluency) {
          weakestCat = 'vocabulary';
        } else {
          weakestCat = 'fluency';
        }
      }

      // 4. Generate Level Summary & Recommended Topic
      final levelSummary = _buildSummary(cefr, weakestCat, totalOverall);
      final topic = _getRecommendedTopic(weakestCat);

      return LearnerProfile(
        userName: userName,
        learningGoal: learningGoal,
        cefrLevel: cefr,
        avgFluency: totalFluency,
        avgGrammar: totalGrammar,
        avgVocabulary: totalVocab,
        avgPronunciation: totalPron,
        overallScore: totalOverall,
        weakestGrammarCategory: weakestCat,
        recentFillerWordCounts: fillerCounts.take(3).toList(),
        levelSummary: levelSummary,
        recommendedTopic: topic,
      );
    } catch (e) {
      debugPrint("Error computing LearnerProfile: $e");
      return const LearnerProfile(
        userName: 'Learner',
        learningGoal: 'Daily conversation confidence',
        cefrLevel: 'B1',
        avgFluency: 7.5,
        avgGrammar: 7.5,
        avgVocabulary: 7.5,
        avgPronunciation: 7.5,
        overallScore: 7.5,
        weakestGrammarCategory: 'past_tense',
        recentFillerWordCounts: [2, 1, 2],
        levelSummary: 'B1 • Solid foundations, building overall conversational fluency',
        recommendedTopic: {
          'title': 'Describe a Memorable Experience',
          'description': 'Practice narrative flow and past tense structures.',
          'focus_area': 'past_tense',
        },
      );
    }
  }

  String _buildSummary(String cefr, String weakArea, double score) {
    final areaLabel = _formatAreaLabel(weakArea);
    if (cefr == 'A1' || cefr == 'A2') {
      return "$cefr • Elementary • Building core sentence structure ($areaLabel focus)";
    } else if (cefr == 'B1') {
      return "$cefr • Intermediate • Good basic fluency, refining $areaLabel";
    } else if (cefr == 'B2') {
      return "$cefr • Upper-Intermediate • Strong expression, polishing $areaLabel precision";
    } else {
      return "$cefr • Advanced • Professional mastery, perfecting $areaLabel nuances";
    }
  }

  String _formatAreaLabel(String key) {
    switch (key) {
      case 'past':
      case 'past_tense':
        return 'past tense precision';
      case 'present':
      case 'present_simple':
        return 'present tense accuracy';
      case 'future':
        return 'future intent expressions';
      case 'conditionals':
        return 'hypothetical conditionals';
      case 'vocabulary':
        return 'vocabulary range';
      default:
        return 'grammatical precision';
    }
  }

  Map<String, String> _getRecommendedTopic(String weakCategory) {
    switch (weakCategory) {
      case 'past':
      case 'past_tense':
        return {
          'title': 'Describe a Memorable Past Trip',
          'description': 'Focus on narrative past tense (Simple Past vs Present Perfect).',
          'focus_area': 'past_tense',
        };
      case 'conditionals':
        return {
          'title': 'If You Could Redesign an App...',
          'description': 'Practice hypothetical conditional sentences ("If I were to...").',
          'focus_area': 'conditionals',
        };
      case 'vocabulary':
        return {
          'title': 'Engineering Tech Stack Debate',
          'description': 'Practice high-impact technical vocabulary and professional terms.',
          'focus_area': 'vocabulary',
        };
      case 'present':
      case 'present_simple':
        return {
          'title': 'My Daily Engineering Routine',
          'description': 'Refine habits and present simple frequency adverbs.',
          'focus_area': 'present_simple',
        };
      default:
        return {
          'title': 'Tell Me About Your Engineering Specialization',
          'description': 'Practice articulate explanations and professional conversational flow.',
          'focus_area': 'fluency',
        };
    }
  }
}

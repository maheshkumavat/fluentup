import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/supabase_service.dart';
import '../services/learner_profile_service.dart';

class PracticeCallProvider extends ChangeNotifier {
  String _coachName = "Maya";
  Map<String, dynamic>? _currentTopic;
  List<Map<String, String>> _messages = [];
  int _exchangeCount = 0;
  bool _isLoading = false;
  bool _isSpeakingTTS = false;
  bool _isListeningMic = false;
  String? _errorMessage;
  bool _isCallFinished = false;
  Map<String, dynamic>? _latestReport;
  List<Map<String, dynamic>> _scoreHistory = [];

  String get coachName => _coachName;
  Map<String, dynamic>? get currentTopic => _currentTopic;
  List<Map<String, String>> get messages => _messages;
  int get exchangeCount => _exchangeCount;
  bool get isLoading => _isLoading;
  bool get isSpeakingTTS => _isSpeakingTTS;
  bool get isListeningMic => _isListeningMic;
  String? get errorMessage => _errorMessage;
  bool get isCallFinished => _isCallFinished;
  Map<String, dynamic>? get latestReport => _latestReport;
  List<Map<String, dynamic>> get scoreHistory => _scoreHistory;

  Future<void> loadCoachName() async {
    try {
      final name = await DbHelper.instance.getSetting('coach_name');
      if (name != null && name.trim().isNotEmpty) {
        _coachName = name.trim();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading coach name: $e");
    }
  }

  void setCoachName(String name) async {
    _coachName = name.trim();
    notifyListeners();
    try {
      await DbHelper.instance.setSetting('coach_name', _coachName);
    } catch (e) {
      debugPrint("Error saving coach name: $e");
    }
  }

  void setIsSpeakingTTS(bool val) {
    _isSpeakingTTS = val;
    notifyListeners();
  }

  void setIsListeningMic(bool val) {
    _isListeningMic = val;
    notifyListeners();
  }

  Future<void> startCall({Map<String, dynamic>? topic}) async {
    await loadCoachName();
    _currentTopic = topic ?? {
      "id": "dl_1",
      "category": "Daily Life",
      "title": "Daily Routine Practice Call",
    };

    _exchangeCount = 0;
    _isCallFinished = false;
    _latestReport = null;
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    final topicTitle = _currentTopic!['title'] ?? 'General Conversation';
    final topicCategory = _currentTopic!['category'] ?? 'Daily Life';

    String initialGreeting;
    try {
      final prompt = "You are an encouraging English conversation coach named $_coachName. "
          "Generate ONE natural, engaging, friendly opening question to start a practice conversation specifically about '$topicTitle' (Category: $topicCategory). "
          "Do not default to generic small talk ('How was your day?') unless the topic itself is generic small talk. "
          "Keep it short, 1-2 warm spoken sentences max. No emojis or markdown.";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": prompt}
        ],
        'max_tokens': 120,
        'temperature': 0.7,
      });

      initialGreeting = (data['choices'][0]['message']['content'] as String).trim();
    } catch (e) {
      debugPrint("Notice: Groq dynamic opening question fallback used: $e");
      initialGreeting = "Hi there! I'm $_coachName. I'm excited to practice speaking about $topicTitle with you today! What comes to your mind first when you think about $topicTitle?";
    }

    _messages = [
      {
        "sender": "ai",
        "text": initialGreeting,
        "timestamp": DateTime.now().toIso8601String(),
      }
    ];

    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendUserVoiceInput(String text) async {
    if (text.trim().isEmpty) return;

    _messages.add({
      "sender": "user",
      "text": text,
      "timestamp": DateTime.now().toIso8601String(),
    });

    _exchangeCount++;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final topicTitle = _currentTopic?['title'] ?? 'General Conversation';
      final learnerProfile = await LearnerProfileService.instance.computeProfile();
      final cefrLevel = learnerProfile.cefrLevel;

      String phaseInstruction;
      if (_exchangeCount <= 2) {
        phaseInstruction = "Phase: Turns 1-2 (Simple). Ask concrete, simple questions using present tense and everyday vocabulary.";
      } else if (_exchangeCount <= 4) {
        phaseInstruction = "Phase: Turns 3-4 (Moderate). Ask for opinions, comparisons, or past experiences to naturally pull in past/future tense.";
      } else {
        phaseInstruction = "Phase: Turns 5+ (Advanced). Ask a more open-ended or hypothetical question calibrated to their CEFR level ($cefrLevel), using slightly richer vocabulary.";
      }

      final systemPrompt = "You are an encouraging, friendly English conversation tutor named $_coachName. "
          "The student is practicing speaking on the topic: '$topicTitle'. The student's estimated CEFR level is $cefrLevel. "
          "This is turn $_exchangeCount of the conversation. $phaseInstruction "
          "Respond in valid JSON format with keys:\n"
          "1. 'reply': (string, 2-3 spoken sentences max, warm conversational reply & follow-up question, no emojis).\n"
          "2. 'tip': (string or null, if the user's latest message had a noticeable grammar error or awkward wording, provide a SHORT gentle 1-sentence tip like 'You could also say \"...\" — it sounds more natural'. If their phrasing was already good, return null).\n"
          "Output ONLY valid JSON.";

      List<Map<String, String>> apiMessages = [
        {"role": "system", "content": systemPrompt}
      ];

      for (var msg in _messages) {
        apiMessages.add({
          "role": msg['sender'] == 'user' ? 'user' : 'assistant',
          "content": msg['text']!,
        });
      }

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': apiMessages,
        'max_tokens': 300,
        'temperature': 0.7,
      });

      final rawContent = data['choices'][0]['message']['content'] as String;
      String aiReply = rawContent.trim();
      String? inlineTip;

      try {
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawContent);
        if (jsonMatch != null) {
          final parsed = jsonDecode(jsonMatch.group(0)!);
          aiReply = parsed['reply'] as String? ?? aiReply;
          inlineTip = parsed['tip'] as String?;
        }
      } catch (e) {
        debugPrint("Notice: Per-turn JSON parse fallback: $e");
      }

      if (inlineTip != null && inlineTip.trim().isNotEmpty && inlineTip.toLowerCase() != 'null') {
        _messages[_messages.length - 1]['tip'] = inlineTip.trim();
      }

      _messages.add({
        "sender": "ai",
        "text": aiReply,
        "timestamp": DateTime.now().toIso8601String(),
      });

      // End call automatically after 6 exchanges
      if (_exchangeCount >= 6) {
        _isCallFinished = true;
      }
    } catch (e) {
      _errorMessage = "Connection error, try again.";
      debugPrint("Error in PracticeCallProvider: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> generateFeedbackReport() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Calculate transcript and local statistics
      StringBuffer transcriptBuf = StringBuffer();
      int userWordCount = 0;
      int fillerCount = 0;

      final fillerWords = ['um', 'like', 'actually', 'you know', 'uh', 'so', 'basically'];

      for (var msg in _messages) {
        final text = msg['text']!;
        if (msg['sender'] == 'user') {
          final words = text.toLowerCase().split(RegExp(r'\s+'));
          userWordCount += words.length;
          for (var word in words) {
            if (fillerWords.contains(word.replaceAll(RegExp(r'[^a-z]'), ''))) {
              fillerCount++;
            }
          }
          transcriptBuf.writeln("User: $text");
        } else {
          transcriptBuf.writeln("Coach ($_coachName): $text");
        }
      }

      final fullTranscript = transcriptBuf.toString();
      final learnerProfile = await LearnerProfileService.instance.computeProfile();
      final pastFillers = learnerProfile.recentFillerWordCounts.join(", ");

      final systemPrompt = "Analyze this English practice conversation transcript: '$fullTranscript'. "
          "Historical Context: In their last 3 sessions, the speaker used filler words [$pastFillers] times respectively. "
          "Score the speaker on: pronunciation_confidence (inferred from complexity, out of 10), fluency (out of 10), grammar (out of 10), vocabulary (out of 10), filler_word_count (count occurrences of um/like/actually/you know), pace_feedback (too fast/good/too slow), and overall_score out of 10. "
          "Give 2 specific strengths and 2 specific improvements in simple language. In strengths or improvements, if filler words dropped compared to historical context, explicitly acknowledge their progress honestly. "
          "Respond in JSON only with keys: pronunciation_confidence, fluency, grammar, vocabulary, filler_word_count, pace_feedback, overall_score, strengths (array of 2 strings), improvements (array of 2 strings).";

      try {
        final data = await SupabaseService.instance.invokeGroqProxy({
          'model': 'openai/gpt-oss-120b',
          'messages': [
            {"role": "system", "content": systemPrompt}
          ],
          'temperature': 0.3,
        });

        final jsonText = data['choices'][0]['message']['content'] as String;
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonText);
        if (jsonMatch != null) {
          _latestReport = jsonDecode(jsonMatch.group(0)!);
        } else {
          _latestReport = jsonDecode(jsonText.trim());
        }
      } catch (e) {
        debugPrint("Notice: Groq feedback report fallback calculated dynamically: $e");
        final avgWords = userWordCount > 0 ? (userWordCount / (_messages.length / 2)).clamp(4.0, 25.0) : 10.0;
        final calcFluency = ((avgWords / 2.0) + 4.0).clamp(5.0, 9.5);
        final calcGrammar = fillerCount == 0 ? 8.5 : (8.0 - (fillerCount * 0.5)).clamp(5.0, 9.0);
        final calcVocab = (userWordCount > 30 ? 8.5 : 7.0);

        _latestReport = {
          "pronunciation_confidence": (calcFluency * 0.9).roundToDouble(),
          "fluency": calcFluency.roundToDouble(),
          "grammar": calcGrammar.roundToDouble(),
          "vocabulary": calcVocab.roundToDouble(),
          "filler_word_count": fillerCount,
          "pace_feedback": avgWords > 15 ? "fast" : (avgWords < 6 ? "too slow" : "good"),
          "overall_score": double.parse(((calcFluency + calcGrammar + calcVocab) / 3.0).toStringAsFixed(1)),
          "strengths": [
            "Active participation with $userWordCount words spoken",
            fillerCount == 0 ? "Zero filler words used during session" : "Clear effort to communicate ideas"
          ],
          "improvements": [
            fillerCount > 0 ? "Reduce filler word usage ($fillerCount used)" : "Expand sentence complexity",
            "Practice smooth transition phrases"
          ]
        };
      }

      // Save report to SQLite
      if (_latestReport != null) {
        final topicName = _currentTopic?['title'] ?? 'Practice Call';
        final strengthsArr = _latestReport!['strengths'] as List? ?? ["Good effort"];
        final improvementsArr = _latestReport!['improvements'] as List? ?? ["Practice daily"];

        await DbHelper.instance.insertSessionScore(
          'practice_call',
          topicName,
          (_latestReport!['pronunciation_confidence'] as num? ?? 7).toInt(),
          (_latestReport!['fluency'] as num? ?? 7).toInt(),
          (_latestReport!['grammar'] as num? ?? 7).toInt(),
          (_latestReport!['vocabulary'] as num? ?? 7).toInt(),
          (_latestReport!['filler_word_count'] as num? ?? fillerCount).toInt(),
          (_latestReport!['pace_feedback'] as String? ?? 'good'),
          (_latestReport!['overall_score'] as num? ?? 7.5).toDouble(),
          jsonEncode(strengthsArr),
          jsonEncode(improvementsArr),
          DateTime.now().toIso8601String(),
        );

        await loadScoreHistory();
      }
    } catch (e) {
      debugPrint("Error generating feedback report: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _latestReport ?? {};
  }

  Future<void> loadScoreHistory() async {
    try {
      final scores = await DbHelper.instance.getAllSessionScores();
      _scoreHistory = scores;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading score history: $e");
    }
  }
}

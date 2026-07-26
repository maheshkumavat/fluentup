import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/supabase_service.dart';
import '../services/learner_profile_service.dart';

class VocabularyProvider extends ChangeNotifier {
  Map<String, dynamic>? _currentWord;
  List<Map<String, dynamic>> _dueWords = [];
  List<Map<String, dynamic>> _allWords = [];
  List<Map<String, dynamic>> _savedWords = [];
  int _currentReviewIndex = 0;
  int _wordsLearnedThisWeek = 0;
  bool _isLoading = false;
  bool _isSentenceChecking = false;
  String? _errorMessage;
  Map<String, dynamic>? _sentenceCheckResult;
  List<String> _additionalExamples = [];

  Map<String, dynamic>? get currentWord => _currentWord;
  Map<String, dynamic>? get wordOfTheDay => _currentWord;
  List<Map<String, dynamic>> get dueWords => _dueWords;
  List<Map<String, dynamic>> get allWords => _allWords;
  List<Map<String, dynamic>> get savedWords => _savedWords;
  int get currentReviewIndex => _currentReviewIndex;
  int get wordsLearnedThisWeek => _wordsLearnedThisWeek;
  bool get isLoading => _isLoading;
  bool get isSentenceChecking => _isSentenceChecking;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get sentenceCheckResult => _sentenceCheckResult;
  List<String> get additionalExamples => _additionalExamples;

  Map<String, dynamic>? get currentFlashcard =>
      (_dueWords.isNotEmpty && _currentReviewIndex < _dueWords.length)
          ? _dueWords[_currentReviewIndex]
          : _currentWord;

  Future<void> initVocabulary() async {
    await loadAllWords();
    await loadSavedWords();
    await loadWordsLearnedThisWeek();
    await fetchFreshWord();
  }

  Future<void> loadWordsLearnedThisWeek() async {
    try {
      final count = await DbHelper.instance.getWordsLearnedThisWeek();
      _wordsLearnedThisWeek = count;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading words learned this week: $e");
    }
  }

  Future<void> loadSavedWords() async {
    try {
      final saved = await DbHelper.instance.getSavedVocabularyWords();
      _savedWords = saved;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading saved words: $e");
    }
  }

  Future<void> loadAllWords() async {
    try {
      final words = await DbHelper.instance.getAllVocabularyWords();
      _allWords = words;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading all words: $e");
    }
  }

  Future<void> toggleSaveCurrentWord() async {
    if (_currentWord == null) return;
    final wordText = _currentWord!['word'] as String? ?? '';
    if (wordText.isEmpty) return;

    final existing = _allWords.firstWhere(
      (w) => (w['word'] as String).toLowerCase() == wordText.toLowerCase(),
      orElse: () => {},
    );

    bool currentSaved = false;
    int? wordId;

    if (existing.isNotEmpty) {
      wordId = existing['id'] as int;
      currentSaved = (existing['is_saved'] as int? ?? 0) == 1;
    }

    final newSavedState = !currentSaved;

    if (wordId != null) {
      await DbHelper.instance.toggleSaveVocabularyWord(wordId, newSavedState);
    } else {
      final now = DateTime.now();
      final nextReview = now.add(const Duration(days: 1)).toIso8601String();
      wordId = await DbHelper.instance.insertVocabularyWord(
        _currentWord!['word'] as String,
        _currentWord!['meaning'] as String,
        _currentWord!['example_sentence'] as String,
        _currentWord!['synonym'] as String? ?? '',
        nextReview,
        0,
        2.5,
        pronunciationGuide: _currentWord!['pronunciation_guide'] as String? ?? '',
        partOfSpeech: _currentWord!['part_of_speech'] as String? ?? '',
        usageContext: _currentWord!['usage_context'] as String? ?? '',
      );
      await DbHelper.instance.toggleSaveVocabularyWord(wordId, newSavedState);
    }

    _currentWord!['is_saved'] = newSavedState ? 1 : 0;
    await loadSavedWords();
    await loadAllWords();
    notifyListeners();
  }

  Future<void> fetchFreshWord() async {
    _isLoading = true;
    _errorMessage = null;
    _sentenceCheckResult = null;
    _additionalExamples = [];
    notifyListeners();

    try {
      final pastWordsList = _allWords.map((e) => e['word'] as String).join(", ");
      final learnerProfile = await LearnerProfileService.instance.computeProfile();
      final cefrLevel = learnerProfile.cefrLevel;

      final systemPrompt = "Give me one new English vocabulary word suitable for a learner at CEFR level '$cefrLevel'. "
          "Target vocabulary complexity matching CEFR level $cefrLevel. "
          "Do NOT use any of these words already shown to the user: [$pastWordsList]. "
          "Respond in JSON format only with fields:\n"
          "{\n"
          "  \"word\": \"...\",\n"
          "  \"pronunciation_guide\": \"simple phonetic spelling e.g. meh-TIC-yuh-lus\",\n"
          "  \"part_of_speech\": \"noun/verb/adjective/adverb\",\n"
          "  \"meaning\": \"simple one-line meaning\",\n"
          "  \"example_sentence\": \"ONE clear example sentence\",\n"
          "  \"usage_context\": \"short 1-sentence note on real-life context, e.g. Use this in professional emails or when describing careful work\",\n"
          "  \"synonym\": \"...\"\n"
          "}\n"
          "Never use emojis or emoji-style symbols in your response, plain text only.";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": systemPrompt}
        ],
        'temperature': 0.8,
        'response_format': {"type": "json_object"},
      });

      final replyJsonText = data['choices'][0]['message']['content'] as String;
      final wordMap = jsonDecode(replyJsonText.trim());

      _currentWord = Map<String, dynamic>.from(wordMap);
      _currentWord!['is_saved'] = 0;

      final now = DateTime.now();
      final nextReview = now.add(const Duration(days: 1)).toIso8601String();

      await DbHelper.instance.insertVocabularyWord(
        _currentWord!['word'] as String? ?? '',
        _currentWord!['meaning'] as String? ?? '',
        _currentWord!['example_sentence'] as String? ?? '',
        _currentWord!['synonym'] as String? ?? '',
        nextReview,
        0,
        2.5,
        pronunciationGuide: _currentWord!['pronunciation_guide'] as String? ?? '',
        partOfSpeech: _currentWord!['part_of_speech'] as String? ?? '',
        usageContext: _currentWord!['usage_context'] as String? ?? '',
      );

      await loadAllWords();
      await loadWordsLearnedThisWeek();
    } catch (e) {
      debugPrint("Error fetching fresh vocabulary word: $e");
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> evaluateUserSentence(String userSentence) async {
    if (_currentWord == null || userSentence.trim().isEmpty) return;

    _isSentenceChecking = true;
    _sentenceCheckResult = null;
    _additionalExamples = [];
    notifyListeners();

    final word = _currentWord!['word'] as String;
    final meaning = _currentWord!['meaning'] as String;

    try {
      final checkPrompt = "The target word is '$word' (meaning: '$meaning'). The student wrote this sentence using it: '$userSentence'. "
          "Check if the word is used correctly in context with right grammar. "
          "Respond in JSON format only: {\"correct\": true/false, \"feedback\": \"short 1-2 sentence explanation\"}";

      try {
        final evalData = await SupabaseService.instance.invokeGroqProxy({
          'model': 'openai/gpt-oss-120b',
          'messages': [
            {"role": "system", "content": checkPrompt}
          ],
          'temperature': 0.3,
          'response_format': {"type": "json_object"},
        });

        final evalJson = jsonDecode(evalData['choices'][0]['message']['content'] as String);
        _sentenceCheckResult = Map<String, dynamic>.from(evalJson);
      } catch (e) {
        debugPrint("Error evaluating sentence with Groq proxy: $e");
      }

      // Fetch 3 varied example sentences for context diversity
      final examplesPrompt = "Give me 3 different example sentences using the word '$word', each in a different context/situation (e.g. one casual, one professional, one academic), so they don't feel repetitive. Respond in JSON format only: {\"examples\": [\"sentence 1\", \"sentence 2\", \"sentence 3\"]}";

      try {
        final exData = await SupabaseService.instance.invokeGroqProxy({
          'model': 'openai/gpt-oss-120b',
          'messages': [
            {"role": "system", "content": examplesPrompt}
          ],
          'temperature': 0.7,
          'response_format': {"type": "json_object"},
        });

        final exJson = jsonDecode(exData['choices'][0]['message']['content'] as String);
        final list = (exJson['examples'] as List? ?? []).map((e) => e.toString()).toList();
        _additionalExamples = list;
      } catch (e) {
        debugPrint("Error fetching additional examples: $e");
      }
    } catch (e) {
      debugPrint("Error evaluating user sentence: $e");
      _errorMessage = "Failed to evaluate sentence: $e";
    } finally {
      _isSentenceChecking = false;
      notifyListeners();
    }
  }

  void clearSentenceEvaluation() {
    _sentenceCheckResult = null;
    _additionalExamples = [];
    notifyListeners();
  }
}

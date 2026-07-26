import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/supabase_service.dart';

class CodeExplanationProvider extends ChangeNotifier {
  String _codeSnippet = "";
  String _explanationText = "";
  bool _isLoading = false;
  String? _errorMessage;
  String? _feedbackResult;
  List<Map<String, dynamic>> _pastExplanations = [];

  String get codeSnippet => _codeSnippet;
  String get explanationText => _explanationText;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get feedbackResult => _feedbackResult;
  List<Map<String, dynamic>> get pastExplanations => _pastExplanations;

  void setCodeSnippet(String code) {
    _codeSnippet = code;
    notifyListeners();
  }

  void setExplanationText(String text) {
    _explanationText = text;
    notifyListeners();
  }

  void resetCurrentAttempt() {
    _explanationText = "";
    _feedbackResult = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> evaluateExplanation(String code, String explanation) async {
    if (code.trim().isEmpty || explanation.trim().isEmpty) return;

    _codeSnippet = code;
    _explanationText = explanation;
    _isLoading = true;
    _errorMessage = null;
    _feedbackResult = null;
    notifyListeners();

    try {
      final systemPrompt = "You are a senior software engineer interviewing a candidate. The candidate was shown this code snippet: '$code'. They explained it out loud as: '$explanation'. Evaluate TWO things separately: (1) Technical accuracy — did they correctly explain what the code does, any bugs/edge cases they missed. (2) English delivery — clarity, filler words (um, like, actually), grammar, whether a non-technical interviewer could follow their explanation. Give a short response in this format:\n[Technical Clarity:] [1-2 lines]\n[English Delivery:] [1-2 lines, plus one specific phrase they could have said better]\n[Model Explanation:] [a model 2-3 sentence explanation they can practice repeating]\nBe constructive, not harsh — this is a practice space, not a real interview. Never use emojis or emoji-style symbols in your response, plain text only.";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": systemPrompt}
        ],
        'temperature': 0.4,
      });

      final feedback = data['choices'][0]['message']['content'] as String;
      _feedbackResult = feedback;

      // Save to SQLite
      final timestamp = DateTime.now().toIso8601String();
      await DbHelper.instance.insertCodeExplanation(
        code,
        explanation,
        feedback,
        timestamp,
      );

      await loadPastExplanations();
    } catch (e) {
      _errorMessage = "Connection error. Please check your network and try again.";
      debugPrint("Error in evaluateExplanation: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPastExplanations() async {
    try {
      final records = await DbHelper.instance.getCodeExplanations();
      _pastExplanations = records;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading code explanations: $e");
    }
  }

  Future<void> clearHistory() async {
    try {
      await DbHelper.instance.clearAllCodeExplanations();
      _pastExplanations = [];
      notifyListeners();
    } catch (e) {
      debugPrint("Error clearing code explanations: $e");
    }
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/supabase_service.dart';

class ChatProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _autoReadReplies = false;
  String _speakingSpeed = 'normal';

  Map<String, int> _mistakeStats = {'past': 0, 'present': 0, 'future': 0, 'mixed': 0};

  String _coachName = 'Maya';

  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get autoReadReplies => _autoReadReplies;
  String get speakingSpeed => _speakingSpeed;
  String get coachName => _coachName;
  Map<String, int> get mistakeStats => _mistakeStats;

  // Load last 50 messages from DB
  Future<void> loadMessages() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Load user settings first
      final coachVal = await DbHelper.instance.getSetting('coach_name');
      if (coachVal != null && coachVal.trim().isNotEmpty) {
        _coachName = coachVal.trim();
      }

      final autoReadVal = await DbHelper.instance.getSetting('auto_read_replies');
      _autoReadReplies = autoReadVal == 'true';

      final speedVal = await DbHelper.instance.getSetting('speaking_speed');
      if (speedVal != null) {
        _speakingSpeed = speedVal;
      }

      final dbMsgs = await DbHelper.instance.getLastMessages(50);
      _messages = dbMsgs;

      // If no messages exist yet, insert a friendly default greeting
      if (_messages.isEmpty) {
        final initialText = "Hi there! I'm $_coachName, your English conversation tutor. I'm here to help you practice and improve your English in a friendly, judgment-free space. What is your name, and what branch of engineering are you studying?";
        final timestamp = DateTime.now().toIso8601String();
        
        await DbHelper.instance.insertMessage('ai', initialText, timestamp);
        _messages = await DbHelper.instance.getLastMessages(50);
      }
    } catch (e) {
      _errorMessage = "Failed to load chat history.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send message and get AI response
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userTimestamp = DateTime.now().toIso8601String();
    
    // Add user message to DB and UI
    try {
      await DbHelper.instance.insertMessage('user', text, userTimestamp);
      // Reload messages to get updated state with SQLite metadata
      _messages = await DbHelper.instance.getLastMessages(50);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = "Could not save message.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Construct messages payload for the Groq API
      // We start with the system instruction
      final List<Map<String, String>> apiMessages = [
        {
          "role": "system",
          "content": "You are a friendly, patient English conversation tutor for an Indian engineering student. Your name is $_coachName. Refer to yourself by this name naturally when appropriate. Have a natural, warm conversation on everyday topics. After your reply, on a NEW LINE, if the student made any grammar, tense, or word-choice mistakes in their last message, add a short correction in this exact format: '[Correction:] [what they said] -> [corrected version] (short reason in simple words)'. If there were no mistakes, don't add anything. Never be harsh, always encouraging. Keep your main reply conversational, 2-4 sentences max. Never use emojis or emoji-style symbols in your response, plain text only."
        }
      ];

      // Then add the historical conversation from the loaded messages
      for (var msg in _messages) {
        apiMessages.add({
          "role": msg['sender'] == 'user' ? 'user' : 'assistant',
          "content": msg['text'] as String,
        });
      }

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': apiMessages,
        'max_tokens': 500,
        'temperature': 0.7,
      });

      final replyText = data['choices'][0]['message']['content'] as String;
      final aiTimestamp = DateTime.now().toIso8601String();

        // Save AI response to DB
        await DbHelper.instance.insertMessage('ai', replyText, aiTimestamp);
        _messages = await DbHelper.instance.getLastMessages(50);
        _errorMessage = null;
    } catch (e) {
      _errorMessage = "Connection issue, try again";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear/Reset conversation
  Future<void> resetConversation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await DbHelper.instance.clearAllMessages();
      _messages = [];
      // Reload will insert the default greeting
      await loadMessages();
    } catch (e) {
      _errorMessage = "Failed to reset conversation.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check onboarding completed status
  Future<bool> isOnboardingCompleted() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId != null && userId.isNotEmpty) {
        final valUser = await DbHelper.instance.getSetting('onboarding_completed_$userId');
        if (valUser == 'true') return true;
      }
      final value = await DbHelper.instance.getSetting('onboarding_completed');
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  // Mark onboarding completed
  Future<void> setOnboardingCompleted() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId != null && userId.isNotEmpty) {
        await DbHelper.instance.setSetting('onboarding_completed_$userId', 'true');
      }
      await DbHelper.instance.setSetting('onboarding_completed', 'true');
    } catch (e) {
      // Ignored
    }
  }

  // Update auto-read setting
  Future<void> setAutoReadReplies(bool value) async {
    _autoReadReplies = value;
    notifyListeners();
    try {
      await DbHelper.instance.setSetting('auto_read_replies', value.toString());
    } catch (e) {
      debugPrint("Error saving auto_read_replies setting: $e");
    }
  }

  // Update speaking speed setting
  Future<void> setSpeakingSpeed(String value) async {
    _speakingSpeed = value;
    notifyListeners();
    try {
      await DbHelper.instance.setSetting('speaking_speed', value);
    } catch (e) {
      debugPrint("Error saving speaking_speed setting: $e");
    }
  }

  // Load mistake statistics from SQLite
  Future<void> loadMistakeStats() async {
    try {
      final stats = await DbHelper.instance.getMistakeCountsByTense();
      _mistakeStats = stats;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading mistake stats in ChatProvider: $e");
    }
  }

  // Clear mistake history (useful for complete resets)
  Future<void> clearMistakes() async {
    try {
      await DbHelper.instance.clearAllMistakes();
      _mistakeStats = {'past': 0, 'present': 0, 'future': 0, 'mixed': 0};
      notifyListeners();
    } catch (e) {
      debugPrint("Error clearing mistakes: $e");
    }
  }
}

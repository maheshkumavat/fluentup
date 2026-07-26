import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/supabase_service.dart';

class RoleplayProvider extends ChangeNotifier {
  Map<String, dynamic>? _selectedScenario;
  List<Map<String, String>> _messages = [];
  int _exchangeCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isCompleted = false;
  String? _finalSummary;
  int _mistakesCount = 0;
  List<Map<String, dynamic>> _completedSessions = [];

  final List<Map<String, dynamic>> _scenarios = [
    {
      "id": "tech_interview",
      "title": "Technical Job Interview",
      "subtitle": "For a software engineering role",
      "icon": Icons.code_rounded,
      "color": Colors.blueAccent,
      "initialGreeting": "Hello! Welcome to your technical interview for the Software Engineer position. Let's start with a brief intro: Can you tell me about your background and a project you built recently?",
      "systemPrompt": "You are conducting a mock technical job interview for a B.Tech Computer Science student applying for a Software Engineer role. Ask one interview question at a time (mix of technical basics — DSA, OOP, projects — and behavioral questions). Wait for their answer, then give brief encouraging feedback on their English (clarity, confidence, grammar) AND on their answer's content, then ask the next question. After 8 questions, give a final summary: strengths, 2 things to improve on English delivery, and an overall confidence score out of 10. Be realistic like a real interviewer but supportive, not intimidating. Never use emojis or emoji-style symbols in your response, plain text only.",
    },
    {
      "id": "hr_interview",
      "title": "HR / Behavioral Interview",
      "subtitle": "Practice STAR method responses",
      "icon": Icons.badge_rounded,
      "color": Colors.indigoAccent,
      "initialGreeting": "Welcome! Thanks for joining today's HR interview. To kick things off: Tell me about a time when you faced a difficult challenge in a team project and how you resolved it.",
      "systemPrompt": "You are an experienced HR interviewer conducting a behavioral interview. Focus specifically on evaluating whether the candidate structures their answers using the STAR method (Situation, Task, Action, Result). Ask one question at a time. After their response, provide constructive feedback on their English delivery and STAR structure, then ask the next question. After 8 exchanges, deliver a final summary highlighting key communication strengths, 2 areas to polish, and a final confidence rating out of 10. Never use emojis or emoji-style symbols in your response, plain text only.",
    },
    {
      "id": "group_discussion",
      "title": "College Group Discussion",
      "subtitle": "Express & defend your opinion",
      "icon": Icons.groups_rounded,
      "color": Colors.teal,
      "initialGreeting": "Welcome everyone to today's group discussion topic: 'Is Artificial Intelligence a threat or a tool for human employment?' Who would like to start with their opening thoughts?",
      "systemPrompt": "You are moderating a college group discussion with multiple participants (Simulate participant opinions like Student A and Student B in your responses). Ask for the user's viewpoint, counter politely with different perspectives, and prompt them to articulate their ideas clearly. Evaluate their fluency, turn-taking, and vocabulary. After 8 exchanges, present a final group performance review highlighting their expression clarity, confidence, and areas for improvement out of 10. Never use emojis or emoji-style symbols in your response, plain text only.",
    },
    {
      "id": "casual_conversation",
      "title": "Casual Conversation",
      "subtitle": "Small talk with a friendly stranger",
      "icon": Icons.chat_bubble_outline_rounded,
      "color": Colors.orangeAccent,
      "initialGreeting": "Hey there! It's a pleasant day today, isn't it? Mind if I sit here? What brings you here today?",
      "systemPrompt": "You are a friendly stranger initiating relaxed small talk at a café or park. Keep the conversation natural, engaging, and casual. Respond to their inputs warmly, ask open-ended follow-up questions, and gently note any major language blunders while maintaining a smooth chat flow. After 8 exchanges, wrap up the conversation politely and provide a friendly feedback summary of their conversational English fluency and confidence score out of 10. Never use emojis or emoji-style symbols in your response, plain text only.",
    },
    {
      "id": "restaurant_ordering",
      "title": "Ordering Food at a Restaurant",
      "subtitle": "Practice polite requests & dining",
      "icon": Icons.restaurant_rounded,
      "color": Colors.deepOrangeAccent,
      "initialGreeting": "Good evening! Welcome to Bistro Fluent. Here is your menu. Can I start you off with something to drink while you look over the food options?",
      "systemPrompt": "You are a courteous, attentive waiter at a restaurant. Guide the user through ordering drinks, appetizers, main courses, dealing with dietary queries, and paying the bill. Focus on coaching polite English phrasing (e.g., 'Could I please have...', 'I'd like...'). Ask realistic service questions. After 8 exchanges, conclude the interaction and provide a summary of their dining English politeness, vocabulary, and confidence score out of 10. Never use emojis or emoji-style symbols in your response, plain text only.",
    },
  ];

  List<Map<String, dynamic>> get scenarios => _scenarios;
  Map<String, dynamic>? get selectedScenario => _selectedScenario;
  List<Map<String, String>> get messages => _messages;
  int get exchangeCount => _exchangeCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isCompleted => _isCompleted;
  String? get finalSummary => _finalSummary;
  int get mistakesCount => _mistakesCount;
  List<Map<String, dynamic>> get completedSessions => _completedSessions;

  void startSession(Map<String, dynamic> scenario) {
    _selectedScenario = scenario;
    _exchangeCount = 0;
    _isCompleted = false;
    _finalSummary = null;
    _mistakesCount = 0;
    _errorMessage = null;

    _messages = [
      {
        "sender": "ai",
        "text": scenario["initialGreeting"] as String,
        "timestamp": _formatTime(DateTime.now()),
      }
    ];
    notifyListeners();
  }

  Future<void> sendRoleplayMessage(String text) async {
    if (text.trim().isEmpty || _selectedScenario == null) return;

    final userMsgTime = _formatTime(DateTime.now());
    _messages.add({
      "sender": "user",
      "text": text,
      "timestamp": userMsgTime,
    });
    _exchangeCount++;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final systemPrompt = _selectedScenario!['systemPrompt'] as String;
      
      // Build conversation history payload
      List<Map<String, String>> apiMessages = [
        {"role": "system", "content": systemPrompt}
      ];

      for (var msg in _messages) {
        apiMessages.add({
          "role": msg["sender"] == "user" ? "user" : "assistant",
          "content": msg["text"]!,
        });
      }

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': apiMessages,
        'temperature': 0.7,
      });

      final aiReply = data['choices'][0]['message']['content'] as String;

      _messages.add({
        "sender": "ai",
        "text": aiReply,
        "timestamp": _formatTime(DateTime.now()),
      });

      // Track mistakes dynamically if AI mentions grammar or correction hints
      if (aiReply.toLowerCase().contains("correction:") || aiReply.toLowerCase().contains("grammar") || aiReply.toLowerCase().contains("instead of")) {
        _mistakesCount++;
      }

      // Check if exchange limit reached or final summary provided
      if (_exchangeCount >= 8 || aiReply.toLowerCase().contains("overall confidence score") || aiReply.toLowerCase().contains("final summary")) {
        _isCompleted = true;
        _finalSummary = aiReply;
      }
    } catch (e) {
      _errorMessage = "Failed to connect. Please check your network.";
      debugPrint("Roleplay error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> finishAndSaveSession() async {
    if (_selectedScenario == null) return;

    final scenarioName = _selectedScenario!['title'] as String;
    final summaryText = _finalSummary ?? "Completed roleplay practice session.";
    final timestamp = DateTime.now().toIso8601String();

    try {
      await DbHelper.instance.insertSession(
        scenarioName,
        summaryText,
        _mistakesCount,
        timestamp,
      );
      await loadCompletedSessions();
    } catch (e) {
      debugPrint("Error saving session: $e");
    }
  }

  Future<void> loadCompletedSessions() async {
    try {
      final sessions = await DbHelper.instance.getSessions();
      _completedSessions = sessions;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading sessions: $e");
    }
  }

  Future<void> clearSessionsHistory() async {
    try {
      await DbHelper.instance.clearAllSessions();
      _completedSessions = [];
      notifyListeners();
    } catch (e) {
      debugPrint("Error clearing sessions: $e");
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

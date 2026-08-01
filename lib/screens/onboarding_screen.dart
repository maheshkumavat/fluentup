import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/chat_provider.dart';
import '../providers/practice_call_provider.dart';
import '../services/db_helper.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../widgets/coach_avatar.dart';
import '../widgets/level_ladder.dart';

class OnboardingChatMessage {
  final String sender; // 'coach' or 'user'
  final String text;
  final Widget? customWidget;

  OnboardingChatMessage({
    required this.sender,
    required this.text,
    this.customWidget,
  });

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'text': text,
      };

  factory OnboardingChatMessage.fromJson(Map<String, dynamic> json) => OnboardingChatMessage(
        sender: json['sender'] as String,
        text: json['text'] as String,
      );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ScrollController _scrollController = ScrollController();

  // Onboarding Step Index (0 to 12)
  int _currentStep = 0;
  static const int _totalSteps = 13;

  // Thread Chat Messages
  final List<OnboardingChatMessage> _messages = [];

  // Form State Values
  String _nativeLanguage = "Hindi";
  String _interfaceLanguage = "English";
  final TextEditingController _nameController = TextEditingController(text: "Learner");
  String _userName = "Learner";
  String _acquisitionSource = "Instagram";
  String _selectedCoach = "Maya";
  final TextEditingController _customCoachController = TextEditingController();
  String _learningGoal = "Everyday Conversation";
  String _customGoal = "";
  final TextEditingController _customGoalController = TextEditingController();
  String _selfReportedLevel = "Intermediate";

  // Speech, TTS & Assessment state
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isPlayingPreview = false;

  // Reading Passage State
  bool _isReadingPassage = false;
  bool _isAnalyzingReading = false;
  String _readingPassage = "FluentUp helps me practice spoken English every day with my personal AI coach.";
  String _readingTranscription = "";
  double _readingAccuracyPct = 85.0;
  bool _readingCompleted = false;

  // Free-Speech Baseline State
  bool _isListeningBaseline = false;
  bool _isAnalyzingBaseline = false;
  int _baselineSeconds = 60;
  Timer? _baselineTimer;
  String _baselineTranscription = "";
  String _freeSpeechCefr = "B1";
  String _baselineSummary = "Good baseline starting point.";

  // Final Combined Assessment
  String _finalCefrLevel = "B1";
  String _cefrReasoning = "Balanced starting proficiency based on reading, speech, and self-assessment.";

  @override
  void initState() {
    super.initState();
    _initTts();
    _checkExistingProgressOrStart();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isPlayingPreview = false);
      });
    } catch (e) {
      debugPrint("TTS init error: $e");
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _customCoachController.dispose();
    _customGoalController.dispose();
    _baselineTimer?.cancel();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _checkExistingProgressOrStart() async {
    final userId = SupabaseService.instance.currentUserId ?? 'local';
    try {
      final savedProgress = await DbHelper.instance.getOnboardingProgress(userId);
      if (savedProgress != null && (savedProgress['completed'] as int? ?? 0) == 0) {
        final step = (savedProgress['current_step'] as num? ?? 0).toInt();
        final stateJsonStr = savedProgress['state_json'] as String? ?? '';
        if (stateJsonStr.isNotEmpty) {
          final stateData = jsonDecode(stateJsonStr) as Map<String, dynamic>;
          _userName = stateData['user_name'] ?? 'Learner';
          _nativeLanguage = stateData['native_language'] ?? 'Hindi';
          _interfaceLanguage = stateData['interface_language'] ?? 'English';
          _acquisitionSource = stateData['acquisition_source'] ?? 'Instagram';
          _selectedCoach = stateData['selected_coach'] ?? 'Maya';
          _learningGoal = stateData['learning_goal'] ?? 'Everyday Conversation';
          _customGoal = stateData['custom_goal'] ?? '';
          _selfReportedLevel = stateData['self_reported_level'] ?? 'Intermediate';
          _currentStep = step;
        }
      }
    } catch (e) {
      debugPrint("Error checking onboarding progress: $e");
    }

    if (_messages.isEmpty) {
      _startConversationFlow();
    }
  }

  Future<void> _persistProgress() async {
    final userId = SupabaseService.instance.currentUserId ?? 'local';
    final stateData = {
      'user_name': _userName,
      'native_language': _nativeLanguage,
      'interface_language': _interfaceLanguage,
      'acquisition_source': _acquisitionSource,
      'selected_coach': _selectedCoach,
      'learning_goal': _learningGoal,
      'custom_goal': _customGoal,
      'self_reported_level': _selfReportedLevel,
    };
    await DbHelper.instance.saveOnboardingProgress(userId, _currentStep, false, jsonEncode(stateData));
  }

  // --- Step Flow Controller ---
  void _startConversationFlow() async {
    // Step 0: Warm Coach Intro Bubbles
    _messages.add(OnboardingChatMessage(
      sender: 'coach',
      text: "Hi there! Welcome to FluentUp — your personal AI English coach.",
    ));
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 600));

    _messages.add(OnboardingChatMessage(
      sender: 'coach',
      text: "I'm here to help you build real, natural confidence in speaking English without any judgment.",
    ));
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 600));

    _messages.add(OnboardingChatMessage(
      sender: 'coach',
      text: "Let's take just a minute to set up your personalized practice plan! First, what's your native language?",
    ));
    setState(() {});
    _scrollToBottom();
  }

  // Handle User Input Actions
  void _submitNativeLanguage(String lang) async {
    _nativeLanguage = lang;
    _messages.add(OnboardingChatMessage(sender: 'user', text: lang));
    _currentStep = 1;
    setState(() {});
    _scrollToBottom();
    await _persistProgress();

    // Reward before feedback
    _messages.add(OnboardingChatMessage(sender: 'coach', text: "Wonderful!"));
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));

    if (lang != "English") {
      _messages.add(OnboardingChatMessage(
        sender: 'coach',
        text: "Would you like app explanations in $lang, or keep everything in English?",
      ));
      _currentStep = 2;
    } else {
      _interfaceLanguage = "English";
      _askNameStep();
    }
    setState(() {});
    _scrollToBottom();
  }

  void _submitInterfaceLanguage(String choice) async {
    _interfaceLanguage = choice.contains("English") ? "English" : _nativeLanguage;
    _messages.add(OnboardingChatMessage(sender: 'user', text: choice));
    setState(() {});
    _scrollToBottom();
    await _persistProgress();

    _askNameStep();
  }

  void _askNameStep() async {
    _currentStep = 3;
    _messages.add(OnboardingChatMessage(
      sender: 'coach',
      text: "What should we call you?",
    ));
    setState(() {});
    _scrollToBottom();
  }

  void _submitName() async {
    final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : "Learner";
    _userName = name;

    final userId = SupabaseService.instance.currentUserId;
    if (userId != null && userId.isNotEmpty) {
      await DbHelper.instance.setSetting('user_name_$userId', name);
    }
    await DbHelper.instance.setSetting('user_name', name);

    _messages.add(OnboardingChatMessage(sender: 'user', text: name));
    setState(() {});
    _scrollToBottom();
    await _persistProgress();

    // Reward
    _messages.add(OnboardingChatMessage(sender: 'coach', text: "Nice to meet you, $name!"));
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 4: Acquisition Source
    _currentStep = 4;
    _messages.add(OnboardingChatMessage(
      sender: 'coach',
      text: "Where did you hear about FluentUp?",
    ));
    setState(() {});
    _scrollToBottom();
  }

  void _submitAcquisitionSource(String source) async {
    _acquisitionSource = source;
    final userId = SupabaseService.instance.currentUserId;
    if (userId != null && userId.isNotEmpty) {
      await DbHelper.instance.setSetting('acquisition_source_$userId', source);
    }
    await DbHelper.instance.setSetting('acquisition_source', source);

    _messages.add(OnboardingChatMessage(sender: 'user', text: source));
    setState(() {});
    _scrollToBottom();
    await _persistProgress();

    // Step 5: Coach Persona Naming
    _currentStep = 5;
    _messages.add(OnboardingChatMessage(
      sender: 'coach',
      text: "Who would you like your AI practice partner to be?",
    ));
    setState(() {});
    _scrollToBottom();
  }

  void _submitCoachPersona() async {
    final coach = _selectedCoach == "Custom" && _customCoachController.text.trim().isNotEmpty
        ? _customCoachController.text.trim()
        : _selectedCoach;

    final userId = SupabaseService.instance.currentUserId;
    if (userId != null && userId.isNotEmpty) {
      await DbHelper.instance.setSetting('coach_name_$userId', coach);
    }
    await DbHelper.instance.setSetting('coach_name', coach);

    if (mounted) {
      Provider.of<PracticeCallProvider>(context, listen: false).setCoachName(coach);
    }

    _messages.add(OnboardingChatMessage(sender: 'user', text: "Coach: $coach"));
    setState(() {});
    _scrollToBottom();
    await _persistProgress();

    // Step 6: Learning Goal Cards
    _currentStep = 6;
    _messages.add(OnboardingChatMessage(
      sender: 'coach',
      text: "Why are you learning English? Select your primary goal below:",
    ));
    setState(() {});
    _scrollToBottom();
  }

  void _submitLearningGoal(String goal, {String? customText}) async {
    _learningGoal = goal;
    if (customText != null && customText.isNotEmpty) {
      _customGoal = customText;
    }

    final userId = SupabaseService.instance.currentUserId;
    final saveGoal = _customGoal.isNotEmpty ? _customGoal : _learningGoal;
    if (userId != null && userId.isNotEmpty) {
      await DbHelper.instance.setSetting('learning_goal_$userId', saveGoal);
      if (_customGoal.isNotEmpty) {
        await DbHelper.instance.setSetting('custom_goal_$userId', _customGoal);
      }
    }
    await DbHelper.instance.setSetting('learning_goal', saveGoal);

    _messages.add(OnboardingChatMessage(sender: 'user', text: saveGoal));
    setState(() {});
    _scrollToBottom();
    await _persistProgress();

    // Step 7: Warm Transition Message (Part 2 step 2)
    _currentStep = 7;
    await _generateAndShowWarmTransitionMessage();
  }

  Future<void> _generateAndShowWarmTransitionMessage() async {
    String transitionText = "So, $_userName, you're working on $_learningGoal and your native language is $_nativeLanguage — that's great! We're going to have fun improving your English together.";

    try {
      final prompt = "Generate a warm, 1-2 sentence personalized transition message for an English learner.\n"
          "Learner name: '$_userName', goal: '$_learningGoal', native language: '$_nativeLanguage'.\n"
          "Keep it encouraging, simple, and brief (1-2 sentences). Respond in raw text only.";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "user", "content": prompt}
        ],
        'temperature': 0.7,
      });

      final reply = data['choices'][0]['message']['content'] as String;
      if (reply.trim().isNotEmpty) {
        transitionText = reply.trim();
      }
    } catch (e) {
      debugPrint("Transition message error: $e");
    }

    _messages.add(OnboardingChatMessage(sender: 'coach', text: transitionText));
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 600));

    // Step 8: Self-Reported Level Cards
    _currentStep = 8;
    _messages.add(OnboardingChatMessage(
      sender: 'coach',
      text: "How would you rate your current English speaking level?",
    ));
    setState(() {});
    _scrollToBottom();
  }

  void _submitSelfReportedLevel(String level) async {
    _selfReportedLevel = level;
    final userId = SupabaseService.instance.currentUserId;
    if (userId != null && userId.isNotEmpty) {
      await DbHelper.instance.setSetting('self_reported_level_$userId', level);
    }
    await DbHelper.instance.setSetting('self_reported_level', level);

    _messages.add(OnboardingChatMessage(sender: 'user', text: "Level: $level"));
    setState(() {});
    _scrollToBottom();
    await _persistProgress();

    // Reward before feedback
    _messages.add(OnboardingChatMessage(sender: 'coach', text: "Got it! Thanks for sharing."));
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 9: Reading Passage Assessment
    _currentStep = 9;
    await _setupReadingPassageStep();
  }

  Future<void> _setupReadingPassageStep() async {
    // Calibrate reading passage based on self-reported level
    if (_selfReportedLevel == "Beginner") {
      _readingPassage = "FluentUp helps me speak English every day. I love learning new words and practicing conversations with my AI coach.";
    } else if (_selfReportedLevel == "Advanced") {
      _readingPassage = "Articulating complex ideas with clarity requires consistent practice, natural pacing, and an expanding professional vocabulary.";
    } else {
      _readingPassage = "FluentUp provides a comfortable space to practice spoken English daily, build vocabulary, and gain confidence for work and conversations.";
    }

    _messages.add(OnboardingChatMessage(
      sender: 'coach',
      text: "Let's do a quick reading check! Read this passage out loud when you're ready:",
    ));
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _startRecordingReading() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && _isReadingPassage && mounted) {
          _stopAndAnalyzeReading();
        }
      },
    );

    if (available) {
      setState(() {
        _isReadingPassage = true;
        _readingTranscription = "";
      });

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _readingTranscription = result.recognizedWords;
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _stopAndAnalyzeReading() async {
    await _speech.stop();
    setState(() {
      _isReadingPassage = false;
      _isAnalyzingReading = true;
    });

    final transcription = _readingTranscription.trim().isNotEmpty ? _readingTranscription.trim() : _readingPassage;

    try {
      final prompt = "The learner was asked to read this passage aloud: '$_readingPassage'.\n"
          "Their transcribed speech was: '$transcription'.\n"
          "Assess reading fluency: how closely did they read it correctly (word accuracy), and note whether the pacing suggests confident or hesitant reading.\n"
          "Respond in JSON: {\"reading_accuracy_pct\": 88, \"fluency_note\": \"1 sentence note\"}";

      final res = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": prompt}
        ],
        'temperature': 0.3,
        'response_format': {"type": "json_object"},
      });

      final content = res['choices'][0]['message']['content'] as String;
      final parsed = jsonDecode(content.trim());
      _readingAccuracyPct = (parsed['reading_accuracy_pct'] as num? ?? 85).toDouble().clamp(40.0, 100.0);
    } catch (e) {
      debugPrint("Reading passage analysis error: $e");
      _readingAccuracyPct = 85.0;
    }

    final userId = SupabaseService.instance.currentUserId;
    if (userId != null && userId.isNotEmpty) {
      await DbHelper.instance.setSetting('reading_accuracy_pct_$userId', _readingAccuracyPct.toString());
    }
    await DbHelper.instance.setSetting('reading_accuracy_pct', _readingAccuracyPct.toString());

    setState(() {
      _isAnalyzingReading = false;
      _readingCompleted = true;
    });

    // Reward before feedback
    _messages.add(OnboardingChatMessage(
      sender: 'coach',
      text: "That was great! Clear reading reading check completed (${_readingAccuracyPct.toInt()}% accuracy).",
    ));
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 600));

    // Step 10: Free-Speech Baseline Assessment
    _currentStep = 10;
    _messages.add(OnboardingChatMessage(
      sender: 'coach',
      text: "Great! Now let's hear you speak naturally for a minute so I can understand your natural starting pace.",
    ));
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _startRecordingBaseline() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && _isListeningBaseline && mounted) {
          _stopAndAnalyzeBaseline();
        }
      },
    );

    if (available) {
      setState(() {
        _isListeningBaseline = true;
        _baselineSeconds = 60;
        _baselineTranscription = "";
      });

      _baselineTimer?.cancel();
      _baselineTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_baselineSeconds > 1) {
          if (mounted) setState(() => _baselineSeconds--);
        } else {
          _stopAndAnalyzeBaseline();
        }
      });

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _baselineTranscription = result.recognizedWords;
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _stopAndAnalyzeBaseline() async {
    _baselineTimer?.cancel();
    await _speech.stop();
    setState(() {
      _isListeningBaseline = false;
      _isAnalyzingBaseline = true;
    });

    final sample = _baselineTranscription.trim().isNotEmpty ? _baselineTranscription.trim() : "Hello, I want to practice speaking English fluently.";

    try {
      final systemPrompt = "You are an English proficiency assessor. Based on this spoken sample: '$sample', determine the speaker's starting CEFR level (A1, A2, B1, B2, C1, or C2) and give a 1-sentence summary. Respond in JSON only: {\"overall_level\": \"...\", \"one_line_summary\": \"...\"}";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": systemPrompt}
        ],
        'temperature': 0.3,
        'response_format': {"type": "json_object"},
      });

      final jsonText = data['choices'][0]['message']['content'] as String;
      final parsed = jsonDecode(jsonText.trim());

      _freeSpeechCefr = parsed['overall_level'] as String? ?? 'B1';
      _baselineSummary = parsed['one_line_summary'] as String? ?? 'Good baseline starting point.';
    } catch (e) {
      debugPrint("Baseline speech analysis error: $e");
      _freeSpeechCefr = "B1";
      _baselineSummary = "Good baseline starting level.";
    }

    // Step 11: Combined CEFR Level Calculation (Part 2 step 5)
    _currentStep = 11;
    await _computeCombinedCefrLevel();
  }

  Future<void> _computeCombinedCefrLevel() async {
    try {
      final prompt = "This learner reported their level as '$_selfReportedLevel'.\n"
          "Their reading passage accuracy was ${_readingAccuracyPct.toInt()}%.\n"
          "Their free-speech sample was assessed as approximately $_freeSpeechCefr.\n"
          "Considering all three signals together, what is the most appropriate starting CEFR level (A1/A2/B1/B2/C1) for this learner?\n"
          "Respond in JSON: {\"final_cefr_level\": \"B1\", \"reasoning\": \"one simple sentence\"}";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": prompt}
        ],
        'temperature': 0.3,
        'response_format': {"type": "json_object"},
      });

      final jsonText = data['choices'][0]['message']['content'] as String;
      final parsed = jsonDecode(jsonText.trim());

      _finalCefrLevel = parsed['final_cefr_level'] as String? ?? _freeSpeechCefr;
      _cefrReasoning = parsed['reasoning'] as String? ?? "Balanced starting level based on your reading, speech, and goal.";
    } catch (e) {
      debugPrint("Combined CEFR calculation error: $e");
      _finalCefrLevel = _freeSpeechCefr;
    }

    final userId = SupabaseService.instance.currentUserId;
    if (userId != null && userId.isNotEmpty) {
      await DbHelper.instance.setSetting('user_cefr_level_$userId', _finalCefrLevel);
    }
    await DbHelper.instance.setSetting('user_cefr_level', _finalCefrLevel);
    await DbHelper.instance.insertAssessment(7, 7, 7, 7, _finalCefrLevel, _cefrReasoning, DateTime.now().toIso8601String());

    setState(() {
      _isAnalyzingBaseline = false;
    });

    // Step 12: Level Ladder & Plan Summary
    _currentStep = 12;
    _messages.add(OnboardingChatMessage(
      sender: 'coach',
      text: "All set, $_userName! Based on your signals, we've calibrated your starting plan to CEFR $_finalCefrLevel.",
    ));
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _finishOnboarding() async {
    final userId = SupabaseService.instance.currentUserId ?? 'local';
    await DbHelper.instance.clearOnboardingProgress(userId);

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.setOnboardingCompleted();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _playVoicePreview(String coachName) async {
    await _flutterTts.stop();
    setState(() => _isPlayingPreview = true);

    double pitch = 1.0;
    String line = "Hi, I'm Maya, let me help you build your English confidence!";

    if (coachName == "Alex") {
      pitch = 0.85;
      line = "Hi, I'm Alex, ready to practice speaking English with you!";
    } else if (coachName == "Sam") {
      pitch = 1.25;
      line = "Hi, I'm Sam, let's build your speaking fluency together!";
    }

    await _flutterTts.setPitch(pitch);
    await _flutterTts.speak(line);
  }

  // --- UI Widget Builders ---

  Widget _buildCoachMessageBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radiusMd),
            topRight: Radius.circular(AppTheme.radiusMd),
            bottomRight: Radius.circular(AppTheme.radiusMd),
            bottomLeft: Radius.circular(4),
          ),
          border: const Border(
            left: BorderSide(color: AppTheme.primary, width: 3.5),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 15,
            height: 1.45,
            color: AppTheme.textPrimary,
          ),
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
    );
  }

  Widget _buildUserMessageBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radiusMd),
            topRight: Radius.circular(AppTheme.radiusMd),
            bottomLeft: Radius.circular(AppTheme.radiusMd),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
          ),
        ),
      ).animate().fadeIn(duration: 250.ms),
    );
  }

  // Render Inline Inputs based on current active step
  Widget _buildInlineInputArea() {
    switch (_currentStep) {
      case 0:
        // Native Language Chip Selection
        return _buildNativeLanguageInput();
      case 1:
        return const SizedBox.shrink(); // Processing
      case 2:
        // Interface Language Selection
        return _buildInterfaceLanguageInput();
      case 3:
        // Name Input
        return _buildNameInput();
      case 4:
        // Acquisition Source Chips
        return _buildAcquisitionSourceInput();
      case 5:
        // Coach Persona Selection & Voice Preview
        return _buildCoachPersonaInput();
      case 6:
        // Learning Goal Large Cards
        return _buildLearningGoalCardsInput();
      case 7:
        return const SizedBox.shrink(); // Warm transition message loading
      case 8:
        // Self Reported Level Cards
        return _buildSelfReportedLevelInput();
      case 9:
        // Reading Passage Check
        return _buildReadingPassageInput();
      case 10:
        // Free Speech Baseline Check
        return _buildBaselineSpeechInput();
      case 11:
        return const SizedBox.shrink(); // Combined CEFR calculating
      case 12:
        // Level Ladder & Final Summary
        return _buildSummaryAndLadderInput();
      default:
        return const SizedBox.shrink();
    }
  }

  // Input 0: Native Language Chips
  Widget _buildNativeLanguageInput() {
    final languages = ["Hindi", "Marathi", "Tamil", "Telugu", "Gujarati", "Bengali", "Kannada", "Malayalam", "Punjabi", "English", "Other"];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: languages.map((lang) {
          return ActionChip(
            label: Text(lang),
            labelStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w600),
            backgroundColor: AppTheme.surface,
            side: const BorderSide(color: AppTheme.hairline),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            onPressed: () => _submitNativeLanguage(lang),
          );
        }).toList(),
      ),
    );
  }

  // Input 2: Interface Language Choice
  Widget _buildInterfaceLanguageInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: () => _submitInterfaceLanguage("Explanations in $_nativeLanguage"),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          child: Text("Explanations in $_nativeLanguage (Bilingual)"),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _submitInterfaceLanguage("Everything in English"),
          child: const Text("Keep Everything in English"),
        ),
      ],
    );
  }

  // Input 3: Name Input with Character Counter
  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          maxLength: 50,
          style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 16, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "Enter your name...",
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _submitName,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text("Continue"),
        ),
      ],
    );
  }

  // Input 4: Acquisition Source
  Widget _buildAcquisitionSourceInput() {
    final sources = ["Instagram", "YouTube", "Google Search", "Friend/Family", "College", "Other"];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sources.map((src) {
        return ActionChip(
          label: Text(src),
          labelStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w600),
          backgroundColor: AppTheme.surface,
          side: const BorderSide(color: AppTheme.hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
          onPressed: () => _submitAcquisitionSource(src),
        );
      }).toList(),
    );
  }

  // Input 5: Coach Persona Naming & Voice Preview
  Widget _buildCoachPersonaInput() {
    final coaches = ["Maya", "Alex", "Sam"];

    return Column(
      children: [
        Row(
          children: coaches.map((coach) {
            final isSelected = _selectedCoach == coach;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedCoach = coach);
                  _playVoicePreview(coach);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.hairline,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isSelected ? Icons.volume_up : Icons.person_outline,
                        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                        size: 24,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        coach,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Tap to Hear",
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _submitCoachPersona,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text("Confirm Coach Persona"),
        ),
      ],
    );
  }

  // Input 6: Learning Goal Large Cards (Part 2 step 1)
  Widget _buildLearningGoalCardsInput() {
    final goals = [
      {
        "title": "IELTS / Exam Preparation",
        "desc": "Structured practice for exam speaking and vocabulary",
        "icon": Icons.assignment_outlined,
      },
      {
        "title": "Improve My Career",
        "desc": "Interviews, meetings, emails, presentations",
        "icon": Icons.work_outline,
      },
      {
        "title": "Everyday Conversation",
        "desc": "Talk confidently with friends, family, and daily life",
        "icon": Icons.chat_bubble_outline,
      },
      {
        "title": "Travel",
        "desc": "Airports, hotels, restaurants, and getting around",
        "icon": Icons.flight_takeoff,
      },
      {
        "title": "Excel at College/School",
        "desc": "Classroom discussions, presentations, assignments",
        "icon": Icons.school_outlined,
      },
      {
        "title": "Something Else",
        "desc": "Custom personalized focus area",
        "icon": Icons.edit_note_outlined,
      },
    ];

    return Column(
      children: [
        ...goals.map((g) {
          final title = g['title'] as String;
          final desc = g['desc'] as String;
          final icon = g['icon'] as IconData;
          final isSelected = _learningGoal == title;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                side: BorderSide(
                  color: isSelected ? AppTheme.primary : AppTheme.hairline,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: ListTile(
                onTap: () {
                  if (title == "Something Else") {
                    setState(() => _learningGoal = title);
                  } else {
                    _submitLearningGoal(title);
                  }
                },
                leading: Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
                title: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  desc,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),

        if (_learningGoal == "Something Else") ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customGoalController,
            style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Specify your custom goal...",
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: const BorderSide(color: AppTheme.hairline),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _submitLearningGoal("Something Else", customText: _customGoalController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text("Save Custom Goal"),
          ),
        ],
      ],
    );
  }

  // Input 8: Self Reported Level Cards (Part 2 step 3)
  Widget _buildSelfReportedLevelInput() {
    final levels = [
      {
        "level": "Beginner",
        "desc": "I know a few words but can't make full sentences yet",
        "icon": Icons.font_download_outlined,
      },
      {
        "level": "Intermediate",
        "desc": "I can make simple sentences and have basic conversations",
        "icon": Icons.chat_outlined,
      },
      {
        "level": "Advanced",
        "desc": "I can hold full conversations and understand most things",
        "icon": Icons.record_voice_over_outlined,
      },
    ];

    return Column(
      children: levels.map((l) {
        final level = l['level'] as String;
        final desc = l['desc'] as String;
        final icon = l['icon'] as IconData;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: const BorderSide(color: AppTheme.hairline),
            ),
            child: ListTile(
              onTap: () => _submitSelfReportedLevel(level),
              leading: Icon(icon, color: AppTheme.primary),
              title: Text(
                level,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                desc,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Input 9: Reading Passage Card with Positive Success State (Part 2 step 4)
  Widget _buildReadingPassageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _readingCompleted ? Colors.green.withValues(alpha: 0.08) : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: _readingCompleted ? Colors.green : AppTheme.hairline,
          width: _readingCompleted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _readingCompleted ? Icons.check_circle : Icons.menu_book,
                color: _readingCompleted ? Colors.green : AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _readingCompleted ? "READING CHECK COMPLETED" : "READ ALOUD PASSAGE",
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: _readingCompleted ? Colors.green : AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _readingPassage,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          if (!_readingCompleted) ...[
            ElevatedButton.icon(
              onPressed: (_isReadingPassage || _isAnalyzingReading) ? null : _startRecordingReading,
              icon: Icon(_isReadingPassage ? Icons.mic : Icons.mic_none, color: Colors.white),
              label: Text(_isReadingPassage
                  ? "Listening... Tap when done"
                  : _isAnalyzingReading
                      ? "Analyzing reading..."
                      : "Tap to Read Aloud"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isReadingPassage ? AppTheme.secondaryAccent : AppTheme.primary,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Input 10: Free Speech Baseline Card
  Widget _buildBaselineSpeechInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.mic, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                "60-SECOND SPEECH SAMPLE",
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.primary,
                ),
              ),
              const Spacer(),
              if (_isListeningBaseline)
                Text(
                  "$_baselineSeconds s",
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Topic hint: Describe your typical daily routine, your job/studies, or why you want to speak fluent English.",
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: (_isListeningBaseline || _isAnalyzingBaseline) ? null : _startRecordingBaseline,
            icon: Icon(_isListeningBaseline ? Icons.mic : Icons.mic_none, color: Colors.white),
            label: Text(_isListeningBaseline
                ? "Listening... ($_baselineSeconds s remaining)"
                : _isAnalyzingBaseline
                    ? "Evaluating fluency..."
                    : "Start 60s Voice Assessment"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isListeningBaseline ? AppTheme.secondaryAccent : AppTheme.primary,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  // Input 12: Level Ladder & Final Summary Screen
  Widget _buildSummaryAndLadderInput() {
    return Column(
      children: [
        LevelLadder(
          currentCefrLevel: _finalCefrLevel,
          customMotivatingMessage: _cefrReasoning,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _finishOnboarding,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
          child: const Text(
            "Let's Start Practice",
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Bar & Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.containerPadding, vertical: 10),
              child: Row(
                children: [
                  const CoachAvatar(
                    state: CoachAvatarState.idle,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "FluentUp",
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "Step ${(_currentStep + 1).clamp(1, _totalSteps)} of $_totalSteps",
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Subtle Skip Link
                  InkWell(
                    onTap: _finishOnboarding,
                    child: const Text(
                      "Skip for now",
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textVariant,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Thin progress bar filling as user moves through steps
            LinearProgressIndicator(
              value: ((_currentStep + 1) / _totalSteps).clamp(0.05, 1.0),
              backgroundColor: AppTheme.hairline,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 3,
            ),

            // Continuous Chat Scroll Area
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppTheme.containerPadding),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    final msg = _messages[index];
                    if (msg.sender == 'coach') {
                      return _buildCoachMessageBubble(msg.text);
                    } else {
                      return _buildUserMessageBubble(msg.text);
                    }
                  } else {
                    // Inline Interactive Input Area
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                      child: _buildInlineInputArea(),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

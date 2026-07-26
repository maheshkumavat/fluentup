import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1 State: User Name
  final TextEditingController _nameController = TextEditingController(text: "Learner");
  String _userName = "Learner";

  // Step 2 State: Coach Selection & TTS
  String _selectedCoach = "Maya";
  final TextEditingController _customCoachController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlayingPreview = false;

  // Step 3 State: Baseline Assessment
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isAnalyzing = false;
  int _remainingSeconds = 60;
  Timer? _timer;
  String _transcribedText = "";
  String _cefrLevel = "B1";
  String _assessmentSummary = "Good baseline starting point.";

  // Step 4 State: Learning Goal
  String _selectedGoal = "Daily conversation confidence";
  final List<Map<String, String>> _goalOptions = [
    {
      "goal": "Job interviews",
      "subtitle": "Prepare for technical, behavioral, & HR questions",
      "icon": "work",
    },
    {
      "goal": "Daily conversation confidence",
      "subtitle": "Build natural small talk & everyday fluency",
      "icon": "chat",
    },
    {
      "goal": "Study abroad",
      "subtitle": "Excel in academic discussions & presentations",
      "icon": "school",
    },
    {
      "goal": "General fluency",
      "subtitle": "Enhance vocabulary, grammar precision, & speaking pace",
      "icon": "auto_awesome",
    },
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
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
    _pageController.dispose();
    _nameController.dispose();
    _customCoachController.dispose();
    _timer?.cancel();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _playCoachVoicePreview(String coachName) async {
    await _flutterTts.stop();
    setState(() => _isPlayingPreview = true);

    double pitch = 1.0;
    String sampleLine = "Hi, I'm Maya, let's get started!";

    if (coachName == "Alex") {
      pitch = 0.85;
      sampleLine = "Hi, I'm Alex, ready to practice speaking English!";
    } else if (coachName == "Sam") {
      pitch = 1.25;
      sampleLine = "Hi, I'm Sam, let's build your voice confidence together!";
    } else if (coachName == "Custom") {
      pitch = 1.0;
      final customName = _customCoachController.text.trim().isNotEmpty
          ? _customCoachController.text.trim()
          : "your coach";
      sampleLine = "Hi, I'm $customName, let's get started!";
    }

    await _flutterTts.setPitch(pitch);
    await _flutterTts.speak(sampleLine);
  }

  Future<void> _saveStep1Name() async {
    final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : "Learner";
    _userName = name;
    final userId = SupabaseService.instance.currentUserId;
    if (userId != null && userId.isNotEmpty) {
      await DbHelper.instance.setSetting('user_name_$userId', name);
    }
    await DbHelper.instance.setSetting('user_name', name);

    _goToNextStep();
  }

  Future<void> _saveStep2Coach() async {
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
    _goToNextStep();
  }

  Future<void> _startRecordingBaseline() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && _isListening && mounted) {
          _stopAndAnalyzeBaseline();
        }
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _remainingSeconds = 60;
        _transcribedText = "";
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 1) {
          if (mounted) setState(() => _remainingSeconds--);
        } else {
          _stopAndAnalyzeBaseline();
        }
      });

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _transcribedText = result.recognizedWords;
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
    _timer?.cancel();
    await _speech.stop();
    setState(() {
      _isListening = false;
      _isAnalyzing = true;
    });

    final sample = _transcribedText.trim().isNotEmpty ? _transcribedText.trim() : "Hello, I want to learn English.";

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

      _cefrLevel = parsed['overall_level'] as String? ?? 'B1';
      _assessmentSummary = parsed['one_line_summary'] as String? ?? 'Solid starting baseline.';
    } catch (e) {
      debugPrint("Baseline speech analysis error: $e");
      _cefrLevel = "B1";
      _assessmentSummary = "Good baseline starting level.";
    }

    final userId = SupabaseService.instance.currentUserId;
    if (userId != null && userId.isNotEmpty) {
      await DbHelper.instance.setSetting('user_cefr_level_$userId', _cefrLevel);
    }
    await DbHelper.instance.setSetting('user_cefr_level', _cefrLevel);

    await DbHelper.instance.insertAssessment(7, 7, 7, 7, _cefrLevel, _assessmentSummary, DateTime.now().toIso8601String());

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
      });
      _goToNextStep();
    }
  }

  Future<void> _saveStep4Goal() async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId != null && userId.isNotEmpty) {
      await DbHelper.instance.setSetting('learning_goal_$userId', _selectedGoal);
    }
    await DbHelper.instance.setSetting('learning_goal', _selectedGoal);

    _goToNextStep();
  }

  Future<void> _finishOnboarding() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.setOnboardingCompleted();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _goToNextStep() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.containerPadding, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.language, color: AppTheme.primary, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    "FluentUp",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "Step ${_currentStep + 1} of 5",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: (_currentStep + 1) / 5.0,
              backgroundColor: AppTheme.hairline,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),

            // Step Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentStep = page),
                children: [
                  _buildStep1NameInput(),
                  _buildStep2CoachSelection(),
                  _buildStep3BaselineAssessment(),
                  _buildStep4LearningGoal(),
                  _buildStep5PersonalizedSummary(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 1: "What should we call you?"
  Widget _buildStep1NameInput() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.containerPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline, size: 36, color: AppTheme.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            "What should we call you?",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your AI coach will use your name naturally in practice calls and greetings.",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: "Enter your name...",
              hintStyle: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.normal),
              filled: true,
              fillColor: AppTheme.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saveStep1Name,
              child: const Text("Continue", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // STEP 2: Coach Selection + Voice Preview
  Widget _buildStep2CoachSelection() {
    final coachOptions = ["Maya", "Alex", "Sam", "Custom"];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: CoachAvatar(
              size: 80,
              state: CoachAvatarState.idle,
              coachName: _selectedCoach,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Choose Your AI Coach",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Tap any coach to select and hear a 2-second voice sample.",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ...coachOptions.map((name) {
            final isSelected = _selectedCoach == name;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedCoach = name);
                  _playCoachVoicePreview(name);
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.hairline,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isSelected ? AppTheme.primary : AppTheme.surfaceContainer,
                        radius: 20,
                        child: Icon(Icons.face, color: isSelected ? Colors.white : AppTheme.textSecondary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isPlayingPreview && isSelected ? Icons.volume_up : Icons.volume_up_outlined,
                          color: AppTheme.primary,
                        ),
                        tooltip: "Listen Voice Preview",
                        onPressed: () {
                          setState(() => _selectedCoach = name);
                          _playCoachVoicePreview(name);
                        },
                      ),
                      if (isSelected) const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),

          if (_selectedCoach == "Custom") ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customCoachController,
              decoration: const InputDecoration(
                hintText: "Enter custom coach name...",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saveStep2Coach,
              child: const Text("Continue to Assessment", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // STEP 3: Baseline Speech Assessment
  Widget _buildStep3BaselineAssessment() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            "Baseline Speech Assessment",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Prompt: \"Tell me about your daily routine\"",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryAccent,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Record a 60-second response to establish your starting CEFR fluency level.",
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textSecondary),
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isListening ? _stopAndAnalyzeBaseline : _startRecordingBaseline,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? AppTheme.secondaryAccent : AppTheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? AppTheme.secondaryAccent : AppTheme.primary).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white, size: 44),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isListening ? "Recording... 0:${_remainingSeconds.toString().padLeft(2, '0')}" : "Tap Mic to Record Sample (60s)",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _isListening ? AppTheme.secondaryAccent : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (_transcribedText.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.hairline),
              ),
              child: Text(
                "\"$_transcribedText\"",
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontStyle: FontStyle.italic, color: AppTheme.textPrimary),
              ),
            ),
          ],
          if (_isAnalyzing) ...[
            const SizedBox(height: 20),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 10),
                  Text("Analyzing speech sample via AI...", style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                _cefrLevel = "B1";
                _goToNextStep();
              },
              child: const Text("Skip Sample (Default B1)", style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textSecondary)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // STEP 4: "Why are you learning English?"
  Widget _buildStep4LearningGoal() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            "Why are you learning English?",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "We'll prioritize practice topics aligned with your core objective.",
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ..._goalOptions.map((opt) {
            final goal = opt["goal"]!;
            final isSelected = _selectedGoal == goal;
            IconData iconData = Icons.auto_awesome;
            if (opt["icon"] == "work") iconData = Icons.work_outline;
            if (opt["icon"] == "chat") iconData = Icons.chat_bubble_outline;
            if (opt["icon"] == "school") iconData = Icons.school_outlined;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () => setState(() => _selectedGoal = goal),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withOpacity(0.08) : AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.hairline,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconData, color: isSelected ? Colors.white : AppTheme.textSecondary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              opt["subtitle"]!,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected) const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saveStep4Goal,
              child: const Text("Continue", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // STEP 5: Personalized Summary Screen
  Widget _buildStep5PersonalizedSummary() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.containerPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 24),
          Text(
            "Welcome $_userName!",
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "YOUR PERSONALIZED SUMMARY",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _cefrLevel,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 16, color: AppTheme.textPrimary, height: 1.5),
                    children: [
                      const TextSpan(text: "Based on your speaking sample, you're starting at level "),
                      TextSpan(text: _cefrLevel, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      const TextSpan(text: ". We'll focus on "),
                      TextSpan(text: _selectedGoal, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryAccent)),
                      const TextSpan(text: "-related practice to start."),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Coach: $_selectedCoach • Goal: $_selectedGoal",
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _finishOnboarding,
              child: const Text("Enter FluentUp Home", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

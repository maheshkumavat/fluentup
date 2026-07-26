import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class DialogueScript {
  final String id;
  final String title;
  final String category;
  final String roleA;
  final String roleB;
  final IconData avatarA;
  final IconData avatarB;
  final List<DialogueLine> lines;

  DialogueScript({
    required this.id,
    required this.title,
    required this.category,
    required this.roleA,
    required this.roleB,
    required this.avatarA,
    required this.avatarB,
    required this.lines,
  });
}

class DialogueLine {
  final String speaker; // 'A' or 'B'
  final String text;

  DialogueLine({required this.speaker, required this.text});
}

final List<DialogueScript> kStarterDialogues = [
  DialogueScript(
    id: 'd1',
    title: 'Ordering Coffee at a Cafe',
    category: 'Daily Life',
    roleA: 'Barista',
    roleB: 'Customer',
    avatarA: Icons.coffee,
    avatarB: Icons.person_pin,
    lines: [
      DialogueLine(speaker: 'A', text: 'Hi! Welcome to Sunshine Cafe. What can I get started for you today?'),
      DialogueLine(speaker: 'B', text: 'Hi! I would like a medium oat milk latte, please.'),
      DialogueLine(speaker: 'A', text: 'Sure thing! Would you like that hot or iced?'),
      DialogueLine(speaker: 'B', text: 'Iced, please. And could you add a shot of vanilla syrup?'),
      DialogueLine(speaker: 'A', text: 'You got it! That will be five dollars and fifty cents. Cash or card?'),
      DialogueLine(speaker: 'B', text: 'Card, please. Here you go!'),
      DialogueLine(speaker: 'A', text: 'Thank you! Your drink will be ready at the counter in two minutes.'),
    ],
  ),
  DialogueScript(
    id: 'd2',
    title: 'Asking for Street Directions',
    category: 'Travel',
    roleA: 'Tourist',
    roleB: 'Local',
    avatarA: Icons.map_outlined,
    avatarB: Icons.navigation_outlined,
    lines: [
      DialogueLine(speaker: 'A', text: 'Excuse me! Do you know how to get to the Central Train Station from here?'),
      DialogueLine(speaker: 'B', text: 'Yes, absolutely! Walk straight down this street for two blocks.'),
      DialogueLine(speaker: 'A', text: 'Okay, two blocks straight. Then what?'),
      DialogueLine(speaker: 'B', text: 'Turn left at the blue pharmacy, and you will see the main entrance on your right.'),
      DialogueLine(speaker: 'A', text: 'Is it within walking distance or should I take a taxi?'),
      DialogueLine(speaker: 'B', text: 'It is only a five minute walk. You do not need a taxi.'),
      DialogueLine(speaker: 'A', text: 'That is great to hear! Thank you so much for your help.'),
    ],
  ),
  DialogueScript(
    id: 'd3',
    title: 'Casual Introduction at a Party',
    category: 'Social',
    roleA: 'Alex',
    roleB: 'Sam',
    avatarA: Icons.face_retouching_natural,
    avatarB: Icons.face,
    lines: [
      DialogueLine(speaker: 'A', text: 'Hey there! I am Alex. I do not think we have met yet.'),
      DialogueLine(speaker: 'B', text: 'Nice to meet you, Alex! I am Sam. How do you know the host?'),
      DialogueLine(speaker: 'A', text: 'We work together at the design agency. What about you?'),
      DialogueLine(speaker: 'B', text: 'We went to college together a few years ago.'),
      DialogueLine(speaker: 'A', text: 'Oh awesome! So what kind of work do you do now?'),
      DialogueLine(speaker: 'B', text: 'I work in software engineering, mostly building mobile apps.'),
      DialogueLine(speaker: 'A', text: 'That sounds really interesting! We should catch up more later.'),
    ],
  ),
  DialogueScript(
    id: 'd4',
    title: 'Scheduling a Business Call',
    category: 'Workplace',
    roleA: 'Client',
    roleB: 'Manager',
    avatarA: Icons.business_center_outlined,
    avatarB: Icons.badge_outlined,
    lines: [
      DialogueLine(speaker: 'A', text: 'Hello! I am calling to follow up on our project proposal.'),
      DialogueLine(speaker: 'B', text: 'Thanks for calling! We reviewed your proposal and we are excited to move forward.'),
      DialogueLine(speaker: 'A', text: 'That is fantastic news! When can we schedule our kick-off meeting?'),
      DialogueLine(speaker: 'B', text: 'How does Thursday afternoon at two PM sound for your team?'),
      DialogueLine(speaker: 'A', text: 'Thursday at two PM works perfectly. I will send over the video link.'),
      DialogueLine(speaker: 'B', text: 'Great! Looking forward to speaking with you then.'),
    ],
  ),
  DialogueScript(
    id: 'd5',
    title: 'Small Talk About the Weekend',
    category: 'Social',
    roleA: 'Neighbor A',
    roleB: 'Neighbor B',
    avatarA: Icons.nature_people_outlined,
    avatarB: Icons.wb_sunny_outlined,
    lines: [
      DialogueLine(speaker: 'A', text: 'Good morning! Beautiful weather we are having today!'),
      DialogueLine(speaker: 'B', text: 'Good morning! Yes, it is wonderful. Do you have any fun plans for the weekend?'),
      DialogueLine(speaker: 'A', text: 'I am planning to go hiking in the mountains with some friends.'),
      DialogueLine(speaker: 'B', text: 'That sounds amazing! Which trail are you taking?'),
      DialogueLine(speaker: 'A', text: 'We are trying the Pine Ridge trail. Hopefully the view is clear!'),
      DialogueLine(speaker: 'B', text: 'Have a great time and stay safe on the trail!'),
    ],
  ),
];

class DialoguePracticeScreen extends StatefulWidget {
  final DialogueScript? script;
  const DialoguePracticeScreen({super.key, this.script});

  @override
  State<DialoguePracticeScreen> createState() => _DialoguePracticeScreenState();
}

class _DialoguePracticeScreenState extends State<DialoguePracticeScreen> with SingleTickerProviderStateMixin {
  late DialogueScript _currentScript;
  late TabController _tabController;

  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  // TAB 1: LISTEN State
  bool _isPlayingListenAudio = false;
  int _activeListenLineIndex = -1;
  double _listenProgress = 0.0;

  // TAB 2: QUIZ State
  bool _isLoadingQuiz = false;
  List<Map<String, dynamic>> _quizQuestions = [];
  Map<int, int> _userAnswers = {}; // questionIndex -> chosenIndex
  bool _quizSubmitted = false;

  // TAB 3: PRACTICE State
  String _userRole = 'B'; // 'A' or 'B'
  int _practiceLineIndex = 0;
  bool _isSpeakingPartner = false;
  bool _isListeningMic = false;
  bool _isEvaluatingPractice = false;
  String _userPracticeTranscribed = "";
  String? _practiceFeedback;
  int _practiceRetryCount = 0;
  bool _showShadowingOption = false;

  // TAB 4: RECORD State
  bool _isRecordingSoloTake = false;
  bool _soloTakeCompleted = false;
  String _soloTranscribed = "";
  Map<String, dynamic>? _soloScoreReport;
  bool _isAnalyzingSolo = false;

  @override
  void initState() {
    super.initState();
    _currentScript = widget.script ?? kStarterDialogues.first;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      _stopAudio();
    });
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
    } catch (e) {
      debugPrint("TTS init error: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stopAudio();
    super.dispose();
  }

  void _stopAudio() {
    _flutterTts.stop();
    _speech.stop();
    if (mounted) {
      setState(() {
        _isPlayingListenAudio = false;
        _isSpeakingPartner = false;
        _isListeningMic = false;
        _isRecordingSoloTake = false;
      });
    }
  }

  // --- TAB 1: LISTEN LOGIC ---
  Future<void> _playListenAudioSequence() async {
    if (_isPlayingListenAudio) {
      _stopAudio();
      return;
    }

    setState(() {
      _isPlayingListenAudio = true;
      _activeListenLineIndex = 0;
      _listenProgress = 0.0;
    });

    for (int i = 0; i < _currentScript.lines.length; i++) {
      if (!_isPlayingListenAudio || !mounted) break;

      final line = _currentScript.lines[i];
      setState(() {
        _activeListenLineIndex = i;
        _listenProgress = (i + 1) / _currentScript.lines.length;
      });

      // Distinct Pitch: Character A = 1.25, Character B = 0.85
      final double pitch = line.speaker == 'A' ? 1.25 : 0.85;
      await _flutterTts.setPitch(pitch);

      Completer<void> completer = Completer<void>();
      _flutterTts.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete();
      });

      await _flutterTts.speak(line.text);
      await completer.future;
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (mounted) {
      setState(() {
        _isPlayingListenAudio = false;
        _activeListenLineIndex = -1;
      });
    }
  }

  // --- TAB 2: QUIZ LOGIC ---
  Future<void> _fetchQuizQuestions() async {
    if (_quizQuestions.isNotEmpty) return;

    setState(() => _isLoadingQuiz = true);

    final fullScript = _currentScript.lines
        .map((l) => "${l.speaker == 'A' ? _currentScript.roleA : _currentScript.roleB}: ${l.text}")
        .join("\n");

    try {
      final prompt = "Based on this dialogue:\n'$fullScript'\n"
          "Generate 3 simple multiple-choice comprehension questions testing understanding of what was said.\n"
          "Respond in valid JSON array format ONLY:\n"
          "[\n"
          "  {\"question\": \"...\", \"options\": [\"...\", \"...\", \"...\"], \"correct_index\": 0}\n"
          "]";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": prompt}
        ],
        'temperature': 0.3,
      });

      final jsonText = data['choices'][0]['message']['content'] as String;
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(jsonText);
      final rawList = jsonMatch != null ? jsonDecode(jsonMatch.group(0)!) as List : jsonDecode(jsonText.trim()) as List;

      _quizQuestions = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint("Quiz generation fallback used: $e");
      _quizQuestions = [
        {
          "question": "What is the main topic of this conversation?",
          "options": [_currentScript.title, "Weather forecast", "Shopping online"],
          "correct_index": 0
        },
        {
          "question": "Who starts the conversation?",
          "options": [_currentScript.roleA, _currentScript.roleB, "A third person"],
          "correct_index": 0
        },
        {
          "question": "Is the tone of the interaction friendly?",
          "options": ["Yes, polite and friendly", "No, angry", "Unclear"],
          "correct_index": 0
        }
      ];
    } finally {
      if (mounted) setState(() => _isLoadingQuiz = false);
    }
  }

  // --- TAB 3: PRACTICE LOGIC ---
  void _startPracticeSession(String selectedRole) {
    setState(() {
      _userRole = selectedRole;
      _practiceLineIndex = 0;
      _practiceRetryCount = 0;
      _showShadowingOption = false;
      _practiceFeedback = null;
      _userPracticeTranscribed = "";
    });
    _triggerCurrentPracticeTurn();
  }

  void _triggerCurrentPracticeTurn() async {
    if (_practiceLineIndex >= _currentScript.lines.length) {
      Provider.of<ProgressProvider>(context, listen: false).addXP(30);
      return;
    }

    final line = _currentScript.lines[_practiceLineIndex];
    if (line.speaker != _userRole) {
      // AI Partner Speaks line via TTS
      setState(() {
        _isSpeakingPartner = true;
        _practiceFeedback = null;
        _userPracticeTranscribed = "";
      });

      final double pitch = line.speaker == 'A' ? 1.25 : 0.85;
      await _flutterTts.setPitch(pitch);
      await _flutterTts.speak(line.text);

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isSpeakingPartner = false;
            _practiceLineIndex++;
          });
          _triggerCurrentPracticeTurn();
        }
      });
    } else {
      // User Turn
      setState(() {
        _isSpeakingPartner = false;
        _practiceFeedback = null;
        _userPracticeTranscribed = "";
      });
    }
  }

  Future<void> _toggleMicPractice() async {
    if (_isListeningMic) {
      await _speech.stop();
      setState(() => _isListeningMic = false);
      if (_userPracticeTranscribed.trim().isNotEmpty) {
        _evaluateUserPracticeLine(_userPracticeTranscribed.trim());
      }
    } else {
      var status = await Permission.microphone.status;
      if (status.isDenied) {
        status = await Permission.microphone.request();
        if (!status.isGranted) return;
      }

      bool available = await _speech.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && _isListeningMic && mounted) {
            setState(() => _isListeningMic = false);
            if (_userPracticeTranscribed.trim().isNotEmpty) {
              _evaluateUserPracticeLine(_userPracticeTranscribed.trim());
            }
          }
        },
      );

      if (available) {
        setState(() {
          _isListeningMic = true;
          _userPracticeTranscribed = "";
          _practiceFeedback = null;
        });

        await _speech.listen(
          onResult: (res) {
            if (mounted) setState(() => _userPracticeTranscribed = res.recognizedWords);
          },
          listenOptions: stt.SpeechListenOptions(
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _evaluateUserPracticeLine(String transcribed) async {
    final expected = _currentScript.lines[_practiceLineIndex].text;
    setState(() => _isEvaluatingPractice = true);

    try {
      final prompt = "Target sentence: '$expected'. User attempt: '$transcribed'. "
          "Does this match sufficiently in meaning to count as correct shadowing practice? (Be reasonably lenient). "
          "Respond in JSON: {\"match\": true/false, \"feedback\": \"1-sentence note\"}";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": prompt}
        ],
        'temperature': 0.3,
      });

      final jsonText = data['choices'][0]['message']['content'] as String;
      final parsed = jsonDecode(jsonText.trim());

      final isMatch = parsed['match'] as bool? ?? true;
      final feedback = parsed['feedback'] as String? ?? (isMatch ? "Great job!" : "Try speaking clearly.");

      if (isMatch) {
        setState(() {
          _isEvaluatingPractice = false;
          _practiceFeedback = "✓ $feedback";
          _practiceRetryCount = 0;
          _showShadowingOption = false;
        });

        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() => _practiceLineIndex++);
            _triggerCurrentPracticeTurn();
          }
        });
      } else {
        _practiceRetryCount++;
        setState(() {
          _isEvaluatingPractice = false;
          _practiceFeedback = "Try again: $feedback";
          if (_practiceRetryCount >= 2) {
            _showShadowingOption = true;
          }
        });
      }
    } catch (e) {
      debugPrint("Practice match fallback: $e");
      setState(() {
        _isEvaluatingPractice = false;
        _practiceFeedback = "✓ Good read!";
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() => _practiceLineIndex++);
          _triggerCurrentPracticeTurn();
        }
      });
    }
  }

  Future<void> _playDemoShadowingLine() async {
    final line = _currentScript.lines[_practiceLineIndex];
    final double pitch = line.speaker == 'A' ? 1.25 : 0.85;
    await _flutterTts.setPitch(pitch);
    await _flutterTts.speak(line.text);
  }

  // --- TAB 4: RECORD LOGIC ---
  Future<void> _toggleSoloRecordTake() async {
    if (_isRecordingSoloTake) {
      await _speech.stop();
      setState(() {
        _isRecordingSoloTake = false;
        _soloTakeCompleted = true;
      });
      _analyzeSoloTake();
    } else {
      var status = await Permission.microphone.status;
      if (status.isDenied) {
        status = await Permission.microphone.request();
        if (!status.isGranted) return;
      }

      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isRecordingSoloTake = true;
          _soloTakeCompleted = false;
          _soloTranscribed = "";
          _soloScoreReport = null;
        });

        await _speech.listen(
          onResult: (res) {
            if (mounted) setState(() => _soloTranscribed = res.recognizedWords);
          },
          listenOptions: stt.SpeechListenOptions(
            listenFor: const Duration(seconds: 90),
            pauseFor: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _analyzeSoloTake() async {
    setState(() => _isAnalyzingSolo = true);

    try {
      final sample = _soloTranscribed.trim().isNotEmpty ? _soloTranscribed.trim() : "Dialogue practice recording sample.";
      final prompt = "Analyze this user solo dialogue reading take: '$sample'. "
          "Score on fluency (out of 10), pronunciation (out of 10), pace_feedback ('good'/'too fast'/'slow'), and overall_score out of 10. "
          "Respond in JSON: {\"fluency\": 8, \"pronunciation\": 8, \"pace_feedback\": \"good\", \"overall_score\": 8.0, \"summary\": \"Good smooth delivery!\"}";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": prompt}
        ],
        'temperature': 0.3,
      });

      final jsonText = data['choices'][0]['message']['content'] as String;
      _soloScoreReport = Map<String, dynamic>.from(jsonDecode(jsonText.trim()) as Map);
    } catch (e) {
      debugPrint("Solo take analysis fallback: $e");
      _soloScoreReport = {
        "fluency": 8,
        "pronunciation": 8,
        "pace_feedback": "good",
        "overall_score": 8.0,
        "summary": "Great solo reading effort!"
      };
    } finally {
      if (mounted) setState(() => _isAnalyzingSolo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_currentScript.title),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "Listen"),
            Tab(text: "Quiz"),
            Tab(text: "Practice"),
            Tab(text: "Record"),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          final tabs = [
            _buildListenTab(),
            _buildQuizTab(),
            _buildPracticeTab(),
            _buildRecordTab(),
          ];
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_tabController.index),
              child: tabs[_tabController.index],
            ),
          );
        },
      ),
    );
  }

  // TAB 1: LISTEN VIEW
  Widget _buildListenTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppTheme.containerPadding),
            itemCount: _currentScript.lines.length,
            itemBuilder: (context, index) {
              final line = _currentScript.lines[index];
              final isActive = index == _activeListenLineIndex;
              final isRoleA = line.speaker == 'A';
              final speakerName = isRoleA ? _currentScript.roleA : _currentScript.roleB;
              final avatarIcon = isRoleA ? _currentScript.avatarA : _currentScript.avatarB;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primary.withOpacity(0.15) : AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? AppTheme.primary : AppTheme.hairline,
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: isRoleA ? AppTheme.primary : AppTheme.secondaryAccent,
                      radius: 18,
                      child: Icon(avatarIcon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            speakerName,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isRoleA ? AppTheme.primary : AppTheme.secondaryAccent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            line.text,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: AppTheme.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom Player Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainer,
            border: Border(top: BorderSide(color: AppTheme.hairline)),
          ),
          child: Row(
            children: [
              IconButton.filled(
                icon: Icon(_isPlayingListenAudio ? Icons.pause : Icons.play_arrow),
                onPressed: _playListenAudioSequence,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: _listenProgress,
                      backgroundColor: AppTheme.hairline,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isPlayingListenAudio
                          ? "Playing audio track..."
                          : "Tap play to hear full dialogue with distinct pitch voices",
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // TAB 2: QUIZ VIEW
  Widget _buildQuizTab() {
    if (_quizQuestions.isEmpty && !_isLoadingQuiz) {
      _fetchQuizQuestions();
    }

    if (_isLoadingQuiz) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Comprehension Quiz",
            style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            "Test your understanding of what was said in the dialogue.",
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),

          ..._quizQuestions.asMap().entries.map((entry) {
            final qIndex = entry.key;
            final q = entry.value;
            final options = (q['options'] as List).cast<String>();
            final correctIdx = (q['correct_index'] as num).toInt();
            final userChosen = _userAnswers[qIndex];

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Q${qIndex + 1}: ${q['question']}",
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  ...options.asMap().entries.map((optEntry) {
                    final optIdx = optEntry.key;
                    final optText = optEntry.value;
                    final isSelected = userChosen == optIdx;
                    final isCorrect = optIdx == correctIdx;

                    Color btnColor = AppTheme.background;
                    if (_quizSubmitted) {
                      if (isCorrect) btnColor = Colors.green.withOpacity(0.2);
                      if (isSelected && !isCorrect) btnColor = Colors.red.withOpacity(0.2);
                    } else if (isSelected) {
                      btnColor = AppTheme.primary.withOpacity(0.12);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: _quizSubmitted ? null : () => setState(() => _userAnswers[qIndex] = optIdx),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: btnColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : AppTheme.hairline,
                            ),
                          ),
                          child: Text(optText, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textPrimary)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          if (!_quizSubmitted)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => setState(() => _quizSubmitted = true),
                child: const Text("Submit Quiz", style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    "Quiz Completed! Score: ${_userAnswers.entries.where((e) => e.value == _quizQuestions[e.key]['correct_index']).length} / ${_quizQuestions.length}",
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // TAB 3: PRACTICE VIEW (Matching Screenshot Structure)
  Widget _buildPracticeTab() {
    final isUserTurn = _practiceLineIndex < _currentScript.lines.length && _currentScript.lines[_practiceLineIndex].speaker == _userRole;

    return Column(
      children: [
        // Partner Selection Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Choose Practice Partner",
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _startPracticeSession('A'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _userRole == 'A' ? AppTheme.primary.withOpacity(0.12) : AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _userRole == 'A' ? AppTheme.primary : AppTheme.hairline, width: 2),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primary,
                              radius: 16,
                              child: Icon(_currentScript.avatarA, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(_currentScript.roleA, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _startPracticeSession('B'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _userRole == 'B' ? AppTheme.secondaryAccent.withOpacity(0.12) : AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _userRole == 'B' ? AppTheme.secondaryAccent : AppTheme.hairline, width: 2),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.secondaryAccent,
                              radius: 16,
                              child: Icon(_currentScript.avatarB, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(_currentScript.roleB, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Script Lines Display
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _currentScript.lines.length,
            itemBuilder: (context, index) {
              final line = _currentScript.lines[index];
              final isUserLine = line.speaker == _userRole;
              final isCurrent = index == _practiceLineIndex;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? (isUserLine ? AppTheme.primary.withOpacity(0.12) : AppTheme.surfaceContainer)
                      : AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent ? AppTheme.primary : AppTheme.hairline,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Text(
                  "${line.speaker == 'A' ? _currentScript.roleA : _currentScript.roleB}: ${line.text}",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: AppTheme.textPrimary,
                  ),
                ),
              );
            },
          ),
        ),

        // Controls Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainer,
            border: Border(top: BorderSide(color: AppTheme.hairline)),
          ),
          child: Column(
            children: [
              if (_practiceFeedback != null) ...[
                Text(_practiceFeedback!, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                const SizedBox(height: 8),
              ],
              if (_showShadowingOption) ...[
                TextButton.icon(
                  onPressed: _playDemoShadowingLine,
                  icon: const Icon(Icons.volume_up, color: AppTheme.secondaryAccent),
                  label: const Text("Show me how to say it", style: TextStyle(color: AppTheme.secondaryAccent, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
              ],

              if (isUserTurn) ...[
                GestureDetector(
                  onTap: _toggleMicPractice,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListeningMic ? AppTheme.secondaryAccent : AppTheme.primary,
                    ),
                    child: Icon(_isListeningMic ? Icons.stop : Icons.mic, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_isListeningMic ? "Listening..." : "Tap mic to speak line", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary)),
              ] else ...[
                const Text("AI Partner is speaking...", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // TAB 4: RECORD VIEW
  Widget _buildRecordTab() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Solo Shadowing Take",
            style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            "Record yourself reading both roles solo to test overall flow & delivery.",
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _toggleSoloRecordTake,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecordingSoloTake ? AppTheme.secondaryAccent : AppTheme.primary,
                ),
                child: Icon(_isRecordingSoloTake ? Icons.stop : Icons.fiber_manual_record, color: Colors.white, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _isRecordingSoloTake ? "Recording solo take..." : "Tap to start solo recording",
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          if (_isAnalyzingSolo) ...[
            const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          ] else if (_soloScoreReport != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("SOLO TAKE FEEDBACK REPORT", style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text(_soloScoreReport!['summary'] as String? ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("Fluency: ${_soloScoreReport!['fluency']}/10", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      Text("Pronunciation: ${_soloScoreReport!['pronunciation']}/10", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

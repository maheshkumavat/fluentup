import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/db_helper.dart';
import '../services/learner_profile_service.dart';
import '../services/supabase_service.dart';
import '../services/tts_service.dart';
import '../theme.dart';

class SoundTarget {
  final String word;
  final String phonetic;
  final String trickySound;
  int? lastScore;
  String? lastTip;
  int attemptsCount;

  SoundTarget({
    required this.word,
    required this.phonetic,
    required this.trickySound,
    this.lastScore,
    this.lastTip,
    this.attemptsCount = 0,
  });

  factory SoundTarget.fromJson(Map<String, dynamic> json) {
    return SoundTarget(
      word: json['word'] as String? ?? 'think',
      phonetic: json['phonetic'] as String? ?? 'thingk',
      trickySound: json['tricky_sound'] as String? ?? 'the th sound',
    );
  }
}

class SoundPracticeScreen extends StatefulWidget {
  const SoundPracticeScreen({super.key});

  @override
  State<SoundPracticeScreen> createState() => _SoundPracticeScreenState();
}

class _SoundPracticeScreenState extends State<SoundPracticeScreen> {
  bool _isLoading = true;
  String _passage = "";
  List<SoundTarget> _targets = [];
  int _activeTargetIndex = 0;

  // Speech & TTS infrastructure
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isPlayingTts = false;
  bool _isListening = false;
  bool _isEvaluating = false;
  String _transcribedWord = "";
  bool _sessionCompleted = false;

  @override
  void initState() {
    super.initState();
    _initTtsAndSpeech();
    _generatePassageAndTargets();
  }

  Future<void> _initTtsAndSpeech() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isPlayingTts = false);
      });

      await _speech.initialize();
    } catch (e) {
      debugPrint("Init TTS/Speech error: $e");
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _generatePassageAndTargets() async {
    setState(() => _isLoading = true);

    try {
      final profile = await LearnerProfileService.instance.computeProfile();
      final systemPrompt = "You are a speech coach creating a pronunciation practice exercise for a ${profile.cefrLevel} English learner.\n"
          "Generate a short, natural 2-sentence passage. Then identify 2-3 specific words in that passage that Hindi/Marathi-speaking English learners commonly mispronounce.\n"
          "For each target word, give a simple phonetic spelling (not IPA, just readable like 'peynt' for 'paint') and specify the tricky sound.\n"
          "Respond ONLY in valid JSON with keys:\n"
          "{\n"
          "  \"passage\": \"2 sentences text\",\n"
          "  \"target_words\": [\n"
          "    {\"word\": \"think\", \"phonetic\": \"thingk\", \"tricky_sound\": \"the th sound\"},\n"
          "    {\"word\": \"world\", \"phonetic\": \"wurld\", \"tricky_sound\": \"the silent l sound\"}\n"
          "  ]\n"
          "}";

      final res = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": systemPrompt}
        ],
        'temperature': 0.7,
        'response_format': {"type": "json_object"},
      });

      final content = res['choices'][0]['message']['content'] as String;
      final parsed = jsonDecode(content.trim());

      _passage = parsed['passage'] as String? ?? "I think speaking with confidence opens up many new opportunities around the world.";
      final rawList = parsed['target_words'] as List? ?? [];
      _targets = rawList.map((e) => SoundTarget.fromJson(Map<String, dynamic>.from(e as Map))).toList();

      if (_targets.isEmpty) {
        _targets = [
          SoundTarget(word: "think", phonetic: "thingk", trickySound: "the th sound"),
          SoundTarget(word: "world", phonetic: "wurld", trickySound: "the R and L sound"),
        ];
      }
    } catch (e) {
      debugPrint("Error generating sound practice passage: $e");
      _passage = "I think speaking with clarity helps everyone understand your technical ideas clearly.";
      _targets = [
        SoundTarget(word: "think", phonetic: "thingk", trickySound: "the th sound"),
        SoundTarget(word: "technical", phonetic: "tek-ni-kuhl", trickySound: "the K sound"),
      ];
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _playTts(String text) async {
    await TtsService.instance.stop();
    setState(() => _isPlayingTts = true);
    TtsService.instance.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingTts = false);
    });
    await TtsService.instance.speak(text, rate: "-10%");
  }

  Future<void> _recordTargetAttempt(SoundTarget target) async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && _isListening && mounted) {
          _evaluateAttempt(target);
        }
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _transcribedWord = "";
      });

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _transcribedWord = result.recognizedWords;
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 5),
          pauseFor: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _evaluateAttempt(SoundTarget target) async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _isEvaluating = true;
    });

    final attemptText = _transcribedWord.trim().isNotEmpty ? _transcribedWord.trim() : target.word;
    target.attemptsCount++;

    int score = 85;
    String tip = "Great effort! Keep practicing the ${target.trickySound}.";

    try {
      final prompt = "The learner attempted to pronounce the target word: '${target.word}'.\n"
          "What the learner's speech was transcribed as: '$attemptText'.\n"
          "Target tricky sound: '${target.trickySound}'.\n"
          "Evaluate pronunciation accuracy on a scale of 0-100 (be encouraging) and give 1 brief actionable tip to improve the '${target.trickySound}'.\n"
          "Respond in JSON: {\"score\": 88, \"tip\": \"1 sentence tip\"}";

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
      score = (parsed['score'] as num? ?? 85).toInt().clamp(40, 100);
      tip = parsed['tip'] as String? ?? "Great effort! Keep focusing on the ${target.trickySound}.";
    } catch (e) {
      debugPrint("Error evaluating sound attempt: $e");
      final exactMatch = attemptText.toLowerCase().contains(target.word.toLowerCase());
      score = exactMatch ? 92 : 78;
      tip = exactMatch
          ? "Spot on! Your ${target.trickySound} came through clearly."
          : "Focus on pronouncing '${target.phonetic}' cleanly.";
    }

    target.lastScore = score;
    target.lastTip = tip;

    // Store attempt in local SQLite database
    final userId = SupabaseService.instance.currentUserId ?? 'local';
    final dateStr = DateTime.now().toIso8601String();
    await DbHelper.instance.insertPronunciationAttempt(
      userId: userId,
      word: target.word,
      trickySound: target.trickySound,
      score: score,
      attemptNumber: target.attemptsCount,
      date: dateStr,
    );

    if (mounted) {
      setState(() {
        _isEvaluating = false;
      });
    }
  }

  List<TextSpan> _buildPassageSpans() {
    final List<TextSpan> spans = [];
    final lowerPassage = _passage.toLowerCase();

    int lastIndex = 0;
    for (var target in _targets) {
      final targetWord = target.word;
      final targetLower = targetWord.toLowerCase();
      final idx = lowerPassage.indexOf(targetLower, lastIndex);

      if (idx != -1) {
        if (idx > lastIndex) {
          spans.add(TextSpan(text: _passage.substring(lastIndex, idx)));
        }
        final actualWord = _passage.substring(idx, idx + targetWord.length);
        final isActive = _targets[_activeTargetIndex].word.toLowerCase() == targetLower;

        spans.add(
          TextSpan(
            text: actualWord,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive ? AppTheme.primary : AppTheme.secondaryAccent,
              decoration: TextDecoration.underline,
              decorationColor: isActive ? AppTheme.primary : AppTheme.secondaryAccent,
              decorationThickness: 2.0,
            ),
          ),
        );
        lastIndex = idx + targetWord.length;
      }
    }

    if (lastIndex < _passage.length) {
      spans.add(TextSpan(text: _passage.substring(lastIndex)));
    }

    return spans;
  }

  Widget _buildSummaryScreen() {
    final avgScore = _targets.fold<double>(0, (sum, t) => sum + (t.lastScore ?? 80)) / _targets.length;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.containerPadding),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
            ),
            const SizedBox(height: 20),
            const Text(
              "Nice work today!",
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You completed your targeted sound practice session.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Average Score Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.hairline),
              ),
              child: Column(
                children: [
                  const Text(
                    "TARGET SOUNDS MASTERY",
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${avgScore.toInt()}%",
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.hairline),
                  const SizedBox(height: 12),

                  // Sound List
                  ..._targets.map((t) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          const Icon(Icons.graphic_eq, size: 18, color: AppTheme.secondaryAccent),
                          const SizedBox(width: 8),
                          Text(
                            t.word,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "(${t.phonetic})",
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${t.lastScore ?? 80}%",
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: const Text(
                "Back to Home",
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text("Sound Practice")),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                "Generating target sounds passage...",
                style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_sessionCompleted) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text("Sound Practice Complete")),
        body: _buildSummaryScreen(),
      );
    }

    final activeTarget = _targets[_activeTargetIndex];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Sound Practice"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                "Word ${_activeTargetIndex + 1} of ${_targets.length}",
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Targeted word practice tool (transcription-assisted sound coaching)",
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Passage Container with underlined target words
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 17,
                      height: 1.5,
                      color: AppTheme.textPrimary,
                    ),
                    children: _buildPassageSpans(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Active Target Word Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      activeTarget.word,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Phonetic: /${activeTarget.phonetic}/",
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Focus: ${activeTarget.trickySound}",
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // TTS & Mic Action Buttons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // TTS Button
                        OutlinedButton.icon(
                          onPressed: _isPlayingTts ? null : () => _playTts(activeTarget.word),
                          icon: Icon(
                            _isPlayingTts ? Icons.volume_up : Icons.volume_up_outlined,
                            size: 20,
                            color: AppTheme.primary,
                          ),
                          label: const Text("Hear It"),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(130, 48),
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Mic Record Button
                        ElevatedButton.icon(
                          onPressed: (_isListening || _isEvaluating)
                              ? null
                              : () => _recordTargetAttempt(activeTarget),
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            size: 20,
                            color: Colors.white,
                          ),
                          label: Text(_isListening
                              ? "Listening..."
                              : _isEvaluating
                                  ? "Checking..."
                                  : "Tap to Speak"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isListening ? AppTheme.secondaryAccent : AppTheme.primary,
                            minimumSize: const Size(140, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Evaluation Score & Tip Display
                    if (activeTarget.lastScore != null) ...[
                      const SizedBox(height: 20),
                      const Divider(color: AppTheme.hairline),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Score: ",
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${activeTarget.lastScore}/100",
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: activeTarget.lastScore! >= 80 ? Colors.teal : AppTheme.secondaryAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          activeTarget.lastTip ?? "",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            height: 1.4,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 24),

              // Navigation Controls
              Row(
                children: [
                  if (_activeTargetIndex > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _activeTargetIndex--),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(100, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                      child: const Text("Previous"),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      if (_activeTargetIndex < _targets.length - 1) {
                        setState(() => _activeTargetIndex++);
                      } else {
                        setState(() => _sessionCompleted = true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    child: Text(_activeTargetIndex < _targets.length - 1 ? "Next Sound" : "Finish Practice"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

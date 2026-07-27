import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/practice_call_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/roadmap_provider.dart';
import '../providers/progress_provider.dart';
import '../theme.dart';
import '../widgets/coach_avatar.dart';
import '../services/voice_service.dart';
import 'feedback_report_screen.dart';

class PracticeCallScreen extends StatefulWidget {
  final Map<String, dynamic>? topic;
  const PracticeCallScreen({super.key, this.topic});

  @override
  State<PracticeCallScreen> createState() => _PracticeCallScreenState();
}

class _PracticeCallScreenState extends State<PracticeCallScreen> with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _showTranscript = false;
  bool _isInitializing = true;
  String _initStatus = "Connecting to AI Coach...";
  String _currentSpeechInput = "";

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _enableScreenProtection();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCallSequence();
    });
  }


  Future<void> _initCallSequence() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _initStatus = "Requesting permissions...";
    });

    try {
      var status = await Permission.microphone.status;
      if (status.isDenied) {
        await Permission.microphone.request();
      }
    } catch (e) {
      debugPrint("Notice: Mic permission init check: $e");
    }

    if (!mounted) return;
    setState(() {
      _initStatus = "Initializing Speech Engine...";
    });

    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _flutterTts.setCompletionHandler(() {
        debugPrint("[PracticeCall] TTS Completion Handler Fired.");
        if (mounted) {
          setState(() => _isSpeaking = false);
          final callProvider = Provider.of<PracticeCallProvider>(context, listen: false);
          callProvider.setIsSpeakingTTS(false);
        }
      });
    } catch (e) {
      debugPrint("Notice: TTS Engine init: $e");
    }

    try {
      await _speech.initialize();
    } catch (e) {
      debugPrint("Notice: STT Engine init: $e");
    }

    if (!mounted) return;
    final topicName = widget.topic?['title'] ?? 'Practice Call';
    setState(() {
      _initStatus = "Preparing $topicName...";
    });

    final provider = Provider.of<PracticeCallProvider>(context, listen: false);
    await provider.startCall(topic: widget.topic);

    if (!mounted) return;
    setState(() {
      _isInitializing = false;
    });

    if (provider.messages.isNotEmpty) {
      final initialMsg = provider.messages.first['text']!;
      _speakCoachResponse(initialMsg);
    }
  }

  static const _securityChannel = MethodChannel('com.fluentup.app/security');

  Future<void> _enableScreenProtection() async {
    try {
      await _securityChannel.invokeMethod('enableSecure');
    } catch (e) {
      debugPrint("Error enabling native FLAG_SECURE: $e");
    }
  }

  Future<void> _disableScreenProtection() async {
    try {
      await _securityChannel.invokeMethod('disableSecure');
    } catch (e) {
      debugPrint("Error clearing native FLAG_SECURE: $e");
    }
  }

  @override
  void dispose() {
    _disableScreenProtection();
    _pulseController.dispose();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speakCoachResponse(String text) async {
    if (!mounted) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final callProvider = Provider.of<PracticeCallProvider>(context, listen: false);

    final rate = chatProvider.speakingSpeed == 'slow' ? 0.35 : 0.48;

    debugPrint("[PracticeCall] TTS Speaking: '$text'");
    setState(() => _isSpeaking = true);
    callProvider.setIsSpeakingTTS(true);

    await _flutterTts.stop();
    await VoiceService.instance.configureVoiceForPersona(_flutterTts, persona: 'Coach', baseRate: rate);
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setVolume(1.0);

    // Safety fallback timer in case native TTS completion handler is swallowed by OS
    final estimatedSeconds = (text.length / 10).ceil() + 3;
    Future.delayed(Duration(seconds: estimatedSeconds), () {
      if (mounted && _isSpeaking) {
        debugPrint("[PracticeCall] Safety TTS timeout reached ($estimatedSeconds s). Resetting _isSpeaking to false.");
        setState(() => _isSpeaking = false);
        callProvider.setIsSpeakingTTS(false);
      }
    });

    await _flutterTts.speak(text);
  }

  Future<void> _toggleMicListening() async {
    final callProvider = Provider.of<PracticeCallProvider>(context, listen: false);

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      callProvider.setIsListeningMic(false);
      if (_currentSpeechInput.trim().isNotEmpty) {
        final textToSubmit = _currentSpeechInput.trim();
        _currentSpeechInput = "";
        _handleUserMessageSubmit(textToSubmit);
      }
    } else {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
      callProvider.setIsSpeakingTTS(false);

      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              callProvider.setIsListeningMic(false);
              if (_currentSpeechInput.trim().isNotEmpty) {
                final textToSubmit = _currentSpeechInput.trim();
                _currentSpeechInput = "";
                _handleUserMessageSubmit(textToSubmit);
              }
            }
          }
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _currentSpeechInput = "";
        });
        callProvider.setIsListeningMic(true);

        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _currentSpeechInput = result.recognizedWords;
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenFor: const Duration(seconds: 45),
            pauseFor: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleUserMessageSubmit(String text) async {
    if (text.trim().isEmpty) return;
    final callProvider = Provider.of<PracticeCallProvider>(context, listen: false);
    await callProvider.sendUserVoiceInput(text);

    if (mounted) {
      if (callProvider.messages.isNotEmpty) {
        final lastMsg = callProvider.messages.last;
        if (lastMsg['sender'] == 'ai') {
          _speakCoachResponse(lastMsg['text']!);
        }
      }

      if (callProvider.isCallFinished) {
        _endCallAndShowReport();
      }
    }
  }

  void _endCallAndShowReport() async {
    await _flutterTts.stop();
    await _speech.stop();

    final callProvider = Provider.of<PracticeCallProvider>(context, listen: false);
    final report = await callProvider.generateFeedbackReport();

    if (mounted) {
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final roadmapProvider = Provider.of<RoadmapProvider>(context, listen: false);
      progressProvider.addXP(30);
      roadmapProvider.markDayCompleted(roadmapProvider.currentFocusDay?.dayNumber ?? 1);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FeedbackReportScreen(
            reportData: report,
            topicTitle: callProvider.currentTopic?['title'] ?? 'Practice Call',
          ),
        ),
      );
    }
  }

  void _showTextInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainer,
        title: const Text("Type Your Reply", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Type response here...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              final text = textController.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) {
                _handleUserMessageSubmit(text);
              }
            },
            child: const Text("Send", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<PracticeCallProvider>(context);

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CoachAvatar(
                  size: 140,
                  state: CoachAvatarState.idle,
                  coachName: callProvider.coachName,
                ),
                const SizedBox(height: 28),
                const CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 20),
                Text(
                  _initStatus,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
          onPressed: () {
            _flutterTts.stop();
            _speech.stop();
            Navigator.pop(context);
          },
        ),
        title: Column(
          children: [
            Text(
              widget.topic?['title'] ?? 'Practice Call',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              "Coach: ${callProvider.coachName}",
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CoachAvatar(
                      size: 160,
                      state: _isSpeaking
                          ? CoachAvatarState.speaking
                          : (_isListening ? CoachAvatarState.listening : CoachAvatarState.idle),
                      coachName: callProvider.coachName,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isListening
                          ? "Listening..."
                          : (_isSpeaking
                              ? "${callProvider.coachName} is speaking..."
                              : (callProvider.isLoading ? "Thinking..." : "Tap mic to reply")),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _isListening
                            ? AppTheme.secondaryAccent
                            : (_isSpeaking ? AppTheme.primary : AppTheme.textSecondary),
                      ),
                    ),
                    if (_currentSpeechInput.isNotEmpty && _isListening) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          "\"$_currentSpeechInput\"",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_showTranscript) ...[
              Container(
                height: 200,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  border: Border(top: BorderSide(color: AppTheme.hairline)),
                ),
                child: ListView.builder(
                  itemCount: callProvider.messages.length,
                  itemBuilder: (context, index) {
                    final m = callProvider.messages[index];
                    final isUser = m['sender'] == 'user';
                    final hasTip = isUser && m.containsKey('tip') && m['tip'] != null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Column(
                        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${isUser ? 'You' : callProvider.coachName}: ${m['text']}",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: isUser ? FontWeight.w600 : FontWeight.normal,
                              color: isUser ? AppTheme.primary : AppTheme.textPrimary,
                            ),
                          ),
                          if (hasTip) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade900.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade700, width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber.shade300),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      m['tip']!,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        color: Colors.amber.shade200,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.containerPadding,
                vertical: 20,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.hairline)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: _showTextInputDialog,
                        icon: const Icon(Icons.keyboard, color: AppTheme.textSecondary, size: 28),
                        tooltip: "Type instead",
                      ),
                      GestureDetector(
                        onTap: _toggleMicListening,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening ? AppTheme.secondaryAccent : AppTheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening ? AppTheme.secondaryAccent : AppTheme.primary).withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 4,
                              )
                            ],
                          ),
                          child: Icon(
                            _isListening ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showTranscript = !_showTranscript;
                          });
                        },
                        icon: Icon(
                          _showTranscript ? Icons.subtitles : Icons.subtitles_outlined,
                          color: AppTheme.textSecondary,
                          size: 28,
                        ),
                        tooltip: "Toggle Transcript",
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _endCallAndShowReport,
                    child: const Text(
                      "End Call",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

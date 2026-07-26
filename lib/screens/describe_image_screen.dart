import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/unsplash_service.dart';
import '../services/supabase_service.dart';
import '../widgets/tactile_button.dart';
import '../theme.dart';

class DescribeImageScreen extends StatefulWidget {
  const DescribeImageScreen({super.key});

  @override
  State<DescribeImageScreen> createState() => _DescribeImageScreenState();
}

class _DescribeImageScreenState extends State<DescribeImageScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  UnsplashPhoto? _currentPhoto;
  bool _isLoadingPhoto = true;
  bool _isListening = false;
  bool _isAnalyzing = false;
  bool _autoMode = false;
  int _autoCountdown = 5;
  Timer? _autoTimer;

  String _transcription = "";
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _loadNextImage();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _loadNextImage() async {
    _autoTimer?.cancel();
    setState(() {
      _isLoadingPhoto = true;
      _transcription = "";
      _feedback = null;
      _isListening = false;
    });

    try {
      final photo = await UnsplashService.instance.getRandomPhoto();
      if (mounted) {
        setState(() {
          _currentPhoto = photo;
          _isLoadingPhoto = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading image: $e");
      if (mounted) {
        setState(() => _isLoadingPhoto = false);
      }
    }
  }

  Future<void> _toggleMicListening() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_transcription.trim().isNotEmpty) {
        _analyzeDescription();
      }
    } else {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              if (_transcription.trim().isNotEmpty) {
                _analyzeDescription();
              }
            }
          }
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _transcription = "";
          _feedback = null;
        });

        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _transcription = result.recognizedWords;
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

  Future<void> _analyzeDescription() async {
    if (_currentPhoto == null || _transcription.trim().isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _feedback = null;
    });

    try {
      final prompt = "An English learner was shown an image described as: '${_currentPhoto!.altDescription}'. "
          "They described it out loud as: '$_transcription'. "
          "Give feedback on: how complete/accurate their description was (did they miss obvious details), "
          "their grammar and vocabulary use, and one suggestion for a richer way to describe it. "
          "Keep it encouraging, plain text only, no emojis.";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": prompt}
        ],
        'temperature': 0.4,
      });

      final reply = data['choices'][0]['message']['content'] as String;
      if (mounted) {
        setState(() {
          _feedback = reply;
          _isAnalyzing = false;
        });

        if (_autoMode) {
          _startAutoAdvanceTimer();
        }
      }
    } catch (e) {
      debugPrint("Error analyzing image description: $e");
      if (mounted) {
        setState(() {
          _feedback = "Good effort describing the scene! Focus on describing background elements and actions.";
          _isAnalyzing = false;
        });
      }
    }
  }

  void _startAutoAdvanceTimer() {
    _autoTimer?.cancel();
    setState(() => _autoCountdown = 5);

    _autoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_autoCountdown > 1) {
        setState(() => _autoCountdown--);
      } else {
        timer.cancel();
        _loadNextImage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Describe the Image"),
        actions: [
          Row(
            children: [
              const Text("Auto Mode", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary)),
              Switch(
                value: _autoMode,
                activeColor: AppTheme.primary,
                onChanged: (val) {
                  setState(() {
                    _autoMode = val;
                    if (!_autoMode) _autoTimer?.cancel();
                  });
                },
              ),
            ],
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.hairline),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Frame Display
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: _isLoadingPhoto
                    ? Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ).animate(onPlay: (controller) => controller.repeat())
                       .shimmer(duration: 1200.ms, color: Colors.white24)
                    : (_currentPhoto == null
                        ? const Center(child: Text("Failed to load image."))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: _currentPhoto!.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 220,
                                width: double.infinity,
                                color: AppTheme.surfaceContainer,
                              ).animate(onPlay: (c) => c.repeat())
                               .shimmer(duration: 1200.ms, color: Colors.white24),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.image_not_supported, size: 48, color: AppTheme.textSecondary),
                              ),
                            ),
                          )),
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),
              const SizedBox(height: 24),

              // Spoken Recording Section
              Center(
                child: Column(
                  children: [
                    TactileButton(
                      onTap: _toggleMicListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening ? AppTheme.secondaryAccent : AppTheme.primary,
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening ? AppTheme.secondaryAccent : AppTheme.primary).withOpacity(0.3),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isListening ? "Listening... Speak your description" : "Tap Mic & Describe What You See",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isListening ? AppTheme.secondaryAccent : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Transcribed text display box
              if (_transcription.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "YOUR SPOKEN DESCRIPTION",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "\"$_transcription\"",
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_isAnalyzing) ...[
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 8),
                      Text(
                        "Analyzing description completeness & grammar...",
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Feedback Report Display
              if (_feedback != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.analytics, color: AppTheme.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "AI DESCRIPTION FEEDBACK",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _feedback!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_autoMode) ...[
                  Center(
                    child: Text(
                      "Auto Mode ON: Loading next image in ${_autoCountdown}s...",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _loadNextImage,
                  icon: const Icon(Icons.skip_next, color: AppTheme.primary),
                  label: const Text("Next Image"),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

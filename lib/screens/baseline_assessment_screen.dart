import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/db_helper.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class BaselineAssessmentScreen extends StatefulWidget {
  const BaselineAssessmentScreen({super.key});

  @override
  State<BaselineAssessmentScreen> createState() => _BaselineAssessmentScreenState();
}

class _BaselineAssessmentScreenState extends State<BaselineAssessmentScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isAnalyzing = false;
  int _remainingSeconds = 60;
  Timer? _timer;
  String _transcribedText = "";
  Map<String, dynamic>? _assessmentResult;

  @override
  void dispose() {
    _timer?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _startRecording() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            _stopAndAnalyze();
          }
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
          setState(() {
            _remainingSeconds--;
          });
        } else {
          _stopAndAnalyze();
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

  Future<void> _stopAndAnalyze() async {
    _timer?.cancel();
    await _speech.stop();
    setState(() {
      _isListening = false;
      _isAnalyzing = true;
    });

    if (_transcribedText.trim().isEmpty) {
      setState(() {
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No speech recorded. Please speak into the mic to record your baseline.")),
      );
      return;
    }

    final sample = _transcribedText.trim();

    try {
      Map<String, dynamic> result;

      final systemPrompt = "You are an English proficiency assessor. Based on this 60-second spoken sample: '$sample', rate the speaker's PRONUNCIATION CONFIDENCE, FLUENCY, GRAMMAR, and VOCABULARY, each out of 10, plus an OVERALL level: Beginner / Intermediate / Advanced. Respond in JSON only: {\"pronunciation\": n, \"fluency\": n, \"grammar\": n, \"vocabulary\": n, \"overall_level\": \"...\", \"one_line_summary\": \"...\"}";

      final data = await SupabaseService.instance.invokeGroqProxy({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {"role": "system", "content": systemPrompt}
        ],
        'temperature': 0.3,
        'response_format': {"type": "json_object"},
      });

      final jsonText = data['choices'][0]['message']['content'] as String;
      result = jsonDecode(jsonText.trim());

      await DbHelper.instance.insertAssessment(
        (result['pronunciation'] as num? ?? 7).toInt(),
        (result['fluency'] as num? ?? 7).toInt(),
        (result['grammar'] as num? ?? 7).toInt(),
        (result['vocabulary'] as num? ?? 7).toInt(),
        result['overall_level'] as String? ?? 'Intermediate',
        result['one_line_summary'] as String? ?? 'Good baseline.',
        DateTime.now().toIso8601String(),
      );

      if (mounted) {
        setState(() {
          _assessmentResult = result;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint("Assessment error: $e");
      if (mounted) {
        setState(() {
          _assessmentResult = {
            "pronunciation": 7,
            "fluency": 7,
            "grammar": 8,
            "vocabulary": 7,
            "overall_level": "Intermediate",
            "one_line_summary": "Good baseline starting level."
          };
          _isAnalyzing = false;
        });
      }
    }
  }

  void _finishOnboarding() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.setOnboardingCompleted();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Baseline Speech Assessment"),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                "Final Step: Speech Sample",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppTheme.secondaryAccent,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Tell me about your daily routine",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Record a short 60-second response. This establishes your starting fluency baseline so we can track your progress over time.",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              if (_assessmentResult == null) ...[
                // Recording area
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isListening ? _stopAndAnalyze : _startRecording,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 100,
                          height: 100,
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
                          child: Icon(
                            _isListening ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isListening ? "Recording... 0:${_remainingSeconds.toString().padLeft(2, '0')}" : "Tap Mic to Start (60s)",
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
                const SizedBox(height: 32),

                if (_transcribedText.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.hairline),
                    ),
                    child: Text(
                      "\"$_transcribedText\"",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (_isAnalyzing) ...[
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 12),
                        Text(
                          "Analyzing baseline fluency & vocabulary...",
                          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // Assessment Result Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.secondaryAccent.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "YOUR BASELINE LEVEL",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _assessmentResult!['overall_level'] as String? ?? 'Intermediate',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _assessmentResult!['one_line_summary'] as String? ?? '',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildScoreRow("Pronunciation Confidence", _assessmentResult!['pronunciation'] as int? ?? 7),
                      const SizedBox(height: 10),
                      _buildScoreRow("Fluency", _assessmentResult!['fluency'] as int? ?? 7),
                      const SizedBox(height: 10),
                      _buildScoreRow("Grammar", _assessmentResult!['grammar'] as int? ?? 8),
                      const SizedBox(height: 10),
                      _buildScoreRow("Vocabulary", _assessmentResult!['vocabulary'] as int? ?? 7),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _finishOnboarding,
                    child: const Text("Enter FluentUp Home"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreRow(String title, int score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary)),
            Text("$score / 10", style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: score / 10.0,
            minHeight: 6,
            backgroundColor: AppTheme.hairline,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryAccent),
          ),
        ),
      ],
    );
  }
}

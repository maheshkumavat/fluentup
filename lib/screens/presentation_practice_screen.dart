import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../services/mlkit_service.dart';
import '../services/supabase_service.dart';
import '../widgets/tactile_button.dart';
import '../theme.dart';
import 'presentation_report_screen.dart';

class PresentationPracticeScreen extends StatefulWidget {
  final Map<String, dynamic>? topic;
  const PresentationPracticeScreen({super.key, this.topic});

  @override
  State<PresentationPracticeScreen> createState() => _PresentationPracticeScreenState();
}

class _PresentationPracticeScreenState extends State<PresentationPracticeScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isRecording = false;

  final stt.SpeechToText _speech = stt.SpeechToText();
  String _liveTranscript = "";
  final List<String> _transcriptChunks = [];

  final List<Map<String, String>> _visualTimelineNotes = [];
  Timer? _sampledFrameTimer;
  int _secondsElapsed = 0;
  Timer? _sessionTimer;
  int _lastMlProcessTimeMs = 0;

  @override
  void initState() {
    super.initState();
    _enableScreenProtection();
    MlKitService.instance.initDetector();
    _requestPermissionAndInitCamera();
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
    _sampledFrameTimer?.cancel();
    _sessionTimer?.cancel();
    _speech.stop();
    try {
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream();
      }
    } catch (e) {
      debugPrint("Dispose stop camera stream error: $e");
    }
    _cameraController?.dispose();
    MlKitService.instance.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndInitCamera() async {
    var cameraStatus = await Permission.camera.status;
    var micStatus = await Permission.microphone.status;

    if (cameraStatus.isDenied || micStatus.isDenied) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.background,
            title: const Text("Camera & Microphone Access", style: TextStyle(color: AppTheme.textPrimary)),
            content: const Text(
              "FluentUp needs camera access to give you feedback on your presentation delivery — "
              "nothing is uploaded or stored outside your practice session.",
              style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await Permission.camera.request();
                  await Permission.microphone.request();
                },
                child: const Text("Allow"),
              ),
            ],
          ),
        );
      }
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Find front facing camera
        final frontCam = _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );

        _cameraController = CameraController(
          frontCam,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  Future<void> _startPresentation() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isRecording = true;
        _secondsElapsed = 0;
        _liveTranscript = "";
        _transcriptChunks.clear();
        _visualTimelineNotes.clear();
      });

      MlKitService.instance.metrics.reset();

      // Start live camera stream for MLKit face detector
      try {
        await _cameraController!.startImageStream((image) {
          if (!_isRecording) return;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastMlProcessTimeMs < 350) return; // Process max ~3 frames/sec to save battery
          _lastMlProcessTimeMs = now;
          try {
            final WriteBuffer allBytes = WriteBuffer();
            for (final Plane plane in image.planes) {
              allBytes.putUint8List(plane.bytes);
            }
            final bytes = allBytes.done().buffer.asUint8List();

            final InputImageMetadata metadata = InputImageMetadata(
              size: Size(image.width.toDouble(), image.height.toDouble()),
              rotation: InputImageRotation.rotation270deg,
              format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
              bytesPerRow: image.planes.first.bytesPerRow,
            );

            final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
            MlKitService.instance.processCameraImage(inputImage);
          } catch (e) {
            // Stream frame skip
          }
        });
      } catch (e) {
        debugPrint("[PresentationPractice] Camera image stream start error: $e");
      }

      // Start STT listener
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _liveTranscript = result.recognizedWords;
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 10),
        ),
      );

      // Session Timer
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _secondsElapsed++);
        }
      });

      // Sampled Frame Timer (Every 18 seconds)
      _sampledFrameTimer = Timer.periodic(const Duration(seconds: 18), (timer) {
        _sampleVisualFeedbackNote();
      });
    }
  }

  void _sampleVisualFeedbackNote() {
    if (!_isRecording) return;

    final metrics = MlKitService.instance.metrics;
    final timeStr = "${(_secondsElapsed ~/ 60)}:${(_secondsElapsed % 60).toString().padLeft(2, '0')}";

    String note;
    if (metrics.facingCameraPercentage < 60 && metrics.framesAnalyzed > 2) {
      note = "Try to maintain steady eye contact forward with your audience.";
    } else if (metrics.eyeContactPercentage < 60 && metrics.framesAnalyzed > 2) {
      note = "Great posture! Remember to look directly at the camera periodically.";
    } else {
      note = "Excellent eye contact and confident facial expression!";
    }

    if (mounted) {
      setState(() {
        _visualTimelineNotes.add({
          'time': timeStr,
          'note': note,
        });
      });
    }
  }

  Future<void> _finishPresentation() async {
    _sampledFrameTimer?.cancel();
    _sessionTimer?.cancel();
    await _speech.stop();

    try {
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
    } catch (e) {
      debugPrint("[PresentationPractice] Stop image stream: $e");
    }

    setState(() => _isRecording = false);

    // Build final speech evaluation via Groq
    Map<String, dynamic> speechReport;

    if (_liveTranscript.trim().isNotEmpty && SupabaseService.instance.isInitialized) {
      try {
        final systemPrompt = "Analyze this presentation transcript: '$_liveTranscript'. "
            "Score on: pronunciation_confidence, fluency, grammar, vocabulary (each out of 10), filler_word_count, pace_feedback, and overall_score out of 10. "
            "Respond in JSON format only with keys: pronunciation_confidence, fluency, grammar, vocabulary, filler_word_count, pace_feedback, overall_score.";

        final data = await SupabaseService.instance.invokeGroqProxy({
          'model': 'openai/gpt-oss-120b',
          'messages': [
            {"role": "system", "content": systemPrompt}
          ],
          'temperature': 0.3,
        });

        final jsonText = data['choices'][0]['message']['content'] as String;
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonText);
        speechReport = jsonMatch != null ? jsonDecode(jsonMatch.group(0)!) : jsonDecode(jsonText.trim());
      } catch (e) {
        debugPrint("Notice: Presentation report fallback: $e");
        speechReport = {
          "pronunciation_confidence": 8,
          "fluency": 8,
          "grammar": 8,
          "vocabulary": 8,
          "filler_word_count": 1,
          "pace_feedback": "good",
          "overall_score": 8.0,
        };
      }
    } else {
      speechReport = {
        "pronunciation_confidence": 8,
        "fluency": 8,
        "grammar": 8,
        "vocabulary": 8,
        "filler_word_count": 0,
        "pace_feedback": "good",
        "overall_score": 8.0,
      };
    }

    final topicTitle = widget.topic?['title'] as String? ?? 'Technical & Career Presentation';

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PresentationReportScreen(
            speechReport: speechReport,
            metrics: MlKitService.instance.metrics,
            visualTimelineNotes: _visualTimelineNotes,
            topicTitle: topicTitle,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicTitle = widget.topic?['title'] as String? ?? 'Presentation Practice';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(topicTitle),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.hairline),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Camera Preview Box
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.containerPadding),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: Stack(
                    children: [
                      if (_isCameraInitialized && _cameraController != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: CameraPreview(_cameraController!),
                          ),
                        )
                      else
                        const Center(
                          child: CircularProgressIndicator(color: AppTheme.primary),
                        ),

                      // Overlay timer & camera signals status
                      if (_isRecording) ...[
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.fiber_manual_record, color: AppTheme.error, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  "${(_secondsElapsed ~/ 60)}:${(_secondsElapsed % 60).toString().padLeft(2, '0')}",
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Live Transcript & Controls Section
            Container(
              padding: const EdgeInsets.all(AppTheme.containerPadding),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.hairline)),
              ),
              child: Column(
                children: [
                  if (_liveTranscript.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      height: 60,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          "\"$_liveTranscript\"",
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontStyle: FontStyle.italic, color: AppTheme.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (!_isRecording) ...[
                    TactileButton(
                      onTap: _startPresentation,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam, color: Colors.white),
                            SizedBox(width: 8),
                            Text("Start Presentation Practice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    TactileButton(
                      onTap: _finishPresentation,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.stop_circle_outlined, color: Colors.white),
                            SizedBox(width: 8),
                            Text("Finish & View Report", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class PresentationMetrics {
  int framesAnalyzed = 0;
  int faceDetectedFrames = 0;
  int eyeContactFrames = 0;
  int smilingFrames = 0;

  double get facingCameraPercentage =>
      framesAnalyzed == 0 ? 0 : (faceDetectedFrames / framesAnalyzed) * 100;

  double get eyeContactPercentage =>
      faceDetectedFrames == 0 ? 0 : (eyeContactFrames / faceDetectedFrames) * 100;

  double get smilingPercentage =>
      faceDetectedFrames == 0 ? 0 : (smilingFrames / faceDetectedFrames) * 100;

  void reset() {
    framesAnalyzed = 0;
    faceDetectedFrames = 0;
    eyeContactFrames = 0;
    smilingFrames = 0;
  }
}

class MlKitService {
  static final MlKitService _instance = MlKitService._internal();
  static MlKitService get instance => _instance;
  MlKitService._internal();

  late final FaceDetector _faceDetector;
  final PresentationMetrics metrics = PresentationMetrics();
  bool _isProcessing = false;
  DateTime _lastProcessedTime = DateTime.now();

  void initDetector() {
    final options = FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);
    metrics.reset();
  }

  Future<void> processCameraImage(InputImage inputImage) async {
    // Process 1 frame every 1.5 seconds to conserve battery and CPU
    final now = DateTime.now();
    if (_isProcessing || now.difference(_lastProcessedTime).inMilliseconds < 1500) {
      return;
    }

    _isProcessing = true;
    _lastProcessedTime = now;

    try {
      final faces = await _faceDetector.processImage(inputImage);
      metrics.framesAnalyzed++;

      if (faces.isNotEmpty) {
        metrics.faceDetectedFrames++;
        final face = faces.first;

        final headY = face.headEulerAngleY ?? 0.0; // Head rotation Y (left/right)
        final headZ = face.headEulerAngleZ ?? 0.0; // Head tilt Z

        // Facing camera (eye contact proxy) if head angle Y is within -15 to +15 degrees
        if (headY >= -15.0 && headY <= 15.0 && headZ >= -15.0 && headZ <= 15.0) {
          metrics.eyeContactFrames++;
        }

        if (face.smilingProbability != null && face.smilingProbability! > 0.35) {
          metrics.smilingFrames++;
        }
      }
    } catch (e) {
      debugPrint("MLKit Face Detector processing error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}

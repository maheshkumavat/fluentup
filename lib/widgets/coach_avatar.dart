import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

enum CoachAvatarState { idle, listening, speaking }

class CoachAvatar extends StatefulWidget {
  final CoachAvatarState state;
  final double size;
  final String? coachName;
  final bool showBadge;

  const CoachAvatar({
    super.key,
    this.state = CoachAvatarState.idle,
    this.size = 120.0,
    this.coachName,
    this.showBadge = false,
  });

  @override
  State<CoachAvatar> createState() => _CoachAvatarState();
}

class _CoachAvatarState extends State<CoachAvatar> with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _rippleController;
  late AnimationController _speakingController;

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _speakingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _rippleController.dispose();
    _speakingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _breathingController,
        _rippleController,
        _speakingController,
      ]),
      builder: (context, child) {
        double scale = 1.0;
        if (widget.state == CoachAvatarState.idle) {
          scale = 0.98 + (_breathingController.value * 0.04);
        } else if (widget.state == CoachAvatarState.speaking) {
          scale = 0.96 + (_speakingController.value * 0.08);
        }

        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _CoachAvatarPainter(
                    state: widget.state,
                    breathingProgress: _breathingController.value,
                    rippleProgress: _rippleController.value,
                    speakingProgress: _speakingController.value,
                    primaryColor: AppTheme.primary,
                    accentColor: AppTheme.secondaryAccent,
                  ),
                ),
              ),
              if (widget.coachName != null && widget.coachName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.state == CoachAvatarState.speaking
                            ? Colors.green
                            : widget.state == CoachAvatarState.listening
                                ? AppTheme.secondaryAccent
                                : AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.coachName!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CoachAvatarPainter extends CustomPainter {
  final CoachAvatarState state;
  final double breathingProgress;
  final double rippleProgress;
  final double speakingProgress;
  final Color primaryColor;
  final Color accentColor;

  _CoachAvatarPainter({
    required this.state,
    required this.breathingProgress,
    required this.rippleProgress,
    required this.speakingProgress,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.35;

    // 1. Draw outer ripple rings if listening
    if (state == CoachAvatarState.listening) {
      final ripplePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      for (int i = 0; i < 3; i++) {
        final progress = (rippleProgress + (i * 0.33)) % 1.0;
        final radius = baseRadius + (progress * baseRadius * 0.7);
        final opacity = (1.0 - progress).clamp(0.0, 1.0);
        ripplePaint.color = accentColor.withOpacity(opacity * 0.6);
        canvas.drawCircle(center, radius, ripplePaint);
      }
    }

    // 2. Draw speaking glow aura
    if (state == CoachAvatarState.speaking) {
      final glowPaint = Paint()
        ..color = primaryColor.withOpacity(0.15 + (speakingProgress * 0.15))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(center, baseRadius * 1.3, glowPaint);
    }

    // 3. Main Avatar Background Circle
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.12),
          primaryColor.withOpacity(0.04),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius));
    canvas.drawCircle(center, baseRadius, bgPaint);

    // 4. Hairline Ring Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = primaryColor.withOpacity(0.6 + (breathingProgress * 0.3));
    canvas.drawCircle(center, baseRadius, borderPaint);

    // 5. Abstract Line-Art Geometry (Waveform / Orbit Nodes)
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = state == CoachAvatarState.listening ? accentColor : primaryColor;

    if (state == CoachAvatarState.speaking) {
      // Draw 5 dynamic soundwave vertical lines
      final spacing = 8.0;
      final heights = [12.0, 24.0, 32.0, 24.0, 12.0];

      for (int i = 0; i < 5; i++) {
        final x = center.dx + ((i - 2) * spacing);
        final dynamicH = heights[i] * (0.6 + (math.sin((speakingProgress * math.pi * 2) + i) * 0.4).abs());
        canvas.drawLine(
          Offset(x, center.dy - (dynamicH / 2)),
          Offset(x, center.dy + (dynamicH / 2)),
          linePaint,
        );
      }
    } else if (state == CoachAvatarState.listening) {
      // Draw minimalist listening arc waveform
      final path = Path();
      final r = baseRadius * 0.5;
      path.addArc(
        Rect.fromCircle(center: center, radius: r),
        rippleProgress * math.pi * 2,
        math.pi * 1.2,
      );
      canvas.drawPath(path, linePaint);
    } else {
      // Idle: Geometric minimalist concentric arcs
      final path1 = Path();
      path1.addArc(
        Rect.fromCircle(center: center, radius: baseRadius * 0.55),
        breathingProgress * math.pi,
        math.pi * 1.3,
      );
      canvas.drawPath(path1, linePaint);

      final innerPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = accentColor;
      canvas.drawCircle(center, 4, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoachAvatarPainter oldDelegate) => true;
}

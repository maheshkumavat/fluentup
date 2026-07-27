import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/roadmap_provider.dart';
import '../theme.dart';

import 'explain_code_screen.dart';
import 'grammar_gym_screen.dart';
import 'practice_call_screen.dart';
import 'roleplay_screen.dart';
import 'vocabulary_screen.dart';

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RoadmapProvider>(context, listen: false).initRoadmap();
    });
  }

  void _onNodeSelected(RoadmapDay day) {
    if (!day.isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🔒 Day ${day.dayNumber} is locked! Complete Day ${day.dayNumber - 1} first."),
          backgroundColor: Colors.grey.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _showDayDetailsModal(day);
  }

  void _launchActivity(RoadmapDay day) {
    Navigator.of(context).pop(); // Close modal

    if (day.activityType == 'call') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PracticeCallScreen(
            topic: {
              "id": day.targetTopicId,
              "title": day.title,
              "initialGreeting":
                  "Hi! Welcome to Day ${day.dayNumber}: ${day.title}. Let's practice speaking on this topic!",
            },
          ),
        ),
      );
    } else if (day.activityType == 'gym') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const GrammarGymScreen()),
      );
    } else if (day.activityType == 'vocab') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const VocabularyScreen()),
      );
    } else if (day.activityType == 'code') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const ExplainCodeScreen()),
      );
    } else if (day.activityType == 'roleplay' || day.dayNumber % 6 == 0) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => RoleplayScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const GrammarGymScreen()),
      );
    }
  }

  void _showDayDetailsModal(RoadmapDay day) {
    final isBoss = day.dayNumber % 6 == 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isBoss
                          ? AppTheme.secondaryAccent.withValues(alpha: 0.15)
                          : AppTheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isBoss
                          ? Icons.emoji_events
                          : _getIconForActivity(day.activityType),
                      color: isBoss ? AppTheme.secondaryAccent : AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBoss ? "👑 BOSS CHALLENGE • DAY ${day.dayNumber}" : "DAY ${day.dayNumber} • ${_getActivityLabel(day.activityType)}",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: isBoss ? AppTheme.secondaryAccent : AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          day.title,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                day.description,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _launchActivity(day),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBoss ? AppTheme.secondaryAccent : AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    day.isCompleted ? "Replay Activity (+15 XP)" : "Start Lesson (+50 XP)",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getIconForActivity(String type) {
    switch (type) {
      case 'call':
        return Icons.phone_in_talk;
      case 'gym':
        return Icons.menu_book;
      case 'vocab':
        return Icons.style;
      case 'code':
        return Icons.code;
      default:
        return Icons.fitness_center;
    }
  }

  String _getActivityLabel(String type) {
    switch (type) {
      case 'call':
        return "AI Voice Call";
      case 'gym':
        return "Grammar Lesson";
      case 'vocab':
        return "Vocab Mastery";
      case 'code':
        return "Code Explanation";
      default:
        return "Interactive Lesson";
    }
  }

  @override
  Widget build(BuildContext context) {
    final roadmapProvider = Provider.of<RoadmapProvider>(context);
    final days = roadmapProvider.roadmapDays;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.timeline, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text(
              "Learning Path",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.hairline),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              // Path Title Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map, color: AppTheme.secondaryAccent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "YOUR FLUENCY ROADMAP",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppTheme.secondaryAccent,
                            ),
                          ),
                          Text(
                            "Completed ${roadmapProvider.completedDays.length} / ${days.length} Nodes",
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Duolingo-Style Vertical Winding Path
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index];
                  final isBoss = day.dayNumber % 6 == 0;
                  final isCheckpoint = day.dayNumber % 10 == 0;

                  // Alternating X positions for winding path
                  // Index pattern: Center (0), Left (-60), Center (0), Right (60)
                  double xOffset = 0.0;
                  final posCycle = index % 4;
                  if (posCycle == 1) xOffset = -70.0;
                  if (posCycle == 3) xOffset = 70.0;

                  return Column(
                    children: [
                      // Checkpoint Banner if applicable
                      if (isCheckpoint) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.primary, Colors.blue.shade700],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                "CHECKPOINT • DAY ${day.dayNumber}",
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Node & Connector line
                      SizedBox(
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Connecting Vertical/Curved Line
                            if (index < days.length - 1)
                              CustomPaint(
                                size: const Size(200, 110),
                                painter: PathConnectorPainter(
                                  startX: xOffset,
                                  endX: (index + 1) % 4 == 1
                                      ? -70.0
                                      : ((index + 1) % 4 == 3 ? 70.0 : 0.0),
                                  isCompleted: day.isCompleted,
                                ),
                              ),

                            // Node Container Button
                            Transform.translate(
                              offset: Offset(xOffset, 0),
                              child: GestureDetector(
                                onTap: () => _onNodeSelected(day),
                                child: _buildPathNode(day, isBoss),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 250.ms, delay: Duration(milliseconds: math.min(index * 40, 600)));
                },
              ),

              if (roadmapProvider.isGeneratingBatch) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: AppTheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPathNode(RoadmapDay day, bool isBoss) {
    final size = isBoss ? 72.0 : 60.0;

    Color nodeBg;
    Color borderColor;
    IconData iconData;

    if (!day.isUnlocked) {
      nodeBg = AppTheme.surfaceContainer;
      borderColor = AppTheme.hairline;
      iconData = Icons.lock;
    } else if (day.isCompleted) {
      nodeBg = AppTheme.primary;
      borderColor = Colors.white;
      iconData = Icons.check;
    } else {
      // Current active node
      nodeBg = isBoss ? AppTheme.secondaryAccent : AppTheme.primary;
      borderColor = isBoss ? Colors.amber : AppTheme.secondaryAccent;
      iconData = isBoss ? Icons.emoji_events : _getIconForActivity(day.activityType);
    }

    Widget nodeWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: nodeBg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: day.isUnlocked ? 3.5 : 2.0),
        boxShadow: day.isUnlocked && !day.isCompleted
            ? [
                BoxShadow(
                  color: isBoss
                      ? AppTheme.secondaryAccent.withValues(alpha: 0.5)
                      : AppTheme.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Center(
        child: Icon(
          iconData,
          color: day.isUnlocked ? Colors.white : AppTheme.textSecondary,
          size: isBoss ? 32 : 24,
        ),
      ),
    );

    // Pulse animation for current active node
    if (day.isUnlocked && !day.isCompleted) {
      nodeWidget = nodeWidget
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(begin: 1.0, end: 1.08, duration: 800.ms, curve: Curves.easeInOut);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        nodeWidget,
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.hairline),
          ),
          child: Text(
            "Day ${day.dayNumber}",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: day.isUnlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class PathConnectorPainter extends CustomPainter {
  final double startX;
  final double endX;
  final bool isCompleted;

  PathConnectorPainter({
    required this.startX,
    required this.endX,
    required this.isCompleted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isCompleted ? AppTheme.primary : AppTheme.hairline
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final p1 = Offset(size.width / 2 + startX, 30);
    final p2 = Offset(size.width / 2 + endX, size.height - 30);

    final controlP1 = Offset(p1.dx, p1.dy + (p2.dy - p1.dy) / 2);
    final controlP2 = Offset(p2.dx, p1.dy + (p2.dy - p1.dy) / 2);

    path.moveTo(p1.dx, p1.dy);
    path.cubicTo(controlP1.dx, controlP1.dy, controlP2.dx, controlP2.dy, p2.dx, p2.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PathConnectorPainter oldDelegate) {
    return oldDelegate.startX != startX ||
        oldDelegate.endX != endX ||
        oldDelegate.isCompleted != isCompleted;
  }
}

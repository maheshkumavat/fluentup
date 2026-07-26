import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/roadmap_provider.dart';
import '../theme.dart';
import 'practice_call_screen.dart';
import 'grammar_gym_screen.dart';
import 'vocabulary_screen.dart';
import 'explain_code_screen.dart';

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

  void _onDaySelected(RoadmapDay day) {
    if (!day.isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Complete Day ${day.dayNumber - 1} to unlock this day!")),
      );
      return;
    }

    if (day.activityType == 'call') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PracticeCallScreen(
            topic: {
              "id": day.targetTopicId,
              "title": day.title,
              "initialGreeting": "Hi! Welcome to Day ${day.dayNumber}: ${day.title}. Let's practice speaking on this topic!",
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
            Icon(Icons.language, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text(
              "Adaptive Roadmap",
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
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.containerPadding, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Personalized Daily Syllabus",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Your roadmap dynamically adapts to your scores & extends indefinitely with your coach.",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Vertical Timeline List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index];
                  final isLast = index == days.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Timeline indicator column
                        Column(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: day.isCompleted
                                    ? AppTheme.primary
                                    : (day.isUnlocked ? AppTheme.secondaryAccent : AppTheme.surfaceContainer),
                                border: Border.all(
                                  color: day.isUnlocked ? AppTheme.primary : AppTheme.hairline,
                                ),
                              ),
                              child: Center(
                                child: day.isCompleted
                                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                                    : Text(
                                        "${day.dayNumber}",
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: day.isUnlocked ? Colors.white : AppTheme.textSecondary,
                                        ),
                                      ),
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: day.isCompleted ? AppTheme.primary : AppTheme.hairline,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // Day Focus Card
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: InkWell(
                              onTap: () => _onDaySelected(day),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: day.isUnlocked ? AppTheme.background : AppTheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: day.isUnlocked ? AppTheme.hairline : AppTheme.hairline.withOpacity(0.5),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "DAY ${day.dayNumber}",
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                            color: day.isUnlocked ? AppTheme.primary : AppTheme.textSecondary,
                                          ),
                                        ),
                                        if (!day.isUnlocked)
                                          const Icon(Icons.lock_outline, size: 16, color: AppTheme.textSecondary)
                                        else if (day.isCompleted)
                                          const Icon(Icons.check_circle, size: 18, color: AppTheme.primary),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      day.title,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: day.isUnlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      day.description,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: index * 50)).slideY(begin: 0.05, end: 0);
                },
              ),

              if (roadmapProvider.isGeneratingBatch) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Generating next personalized batch via AI...",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

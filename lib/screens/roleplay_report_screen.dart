import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/roleplay_provider.dart';
import 'roleplay_chat_screen.dart';
import '../theme.dart';

class RoleplayReportScreen extends StatelessWidget {
  const RoleplayReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roleplayProvider = Provider.of<RoleplayProvider>(context);
    final scenario = roleplayProvider.selectedScenario;
    final summary = roleplayProvider.finalSummary ?? 
        "Your English conversation focused on natural dialogue, professional vocabulary, and grammatical structure.";

    final mistakesCount = roleplayProvider.mistakesCount;
    final accuracyScore = (100 - mistakesCount * 6).clamp(50, 100);
    final fluencyScore = (100 - mistakesCount * 4).clamp(60, 98);
    final vocabScore = (100 - mistakesCount * 5).clamp(55, 95);
    final overallScore = ((accuracyScore + fluencyScore + vocabScore) / 3).round();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.language, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text(
              "FluentUp",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.hairline),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Report Header
              const Text(
                "REPORT • TODAY",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Session Summary",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                summary,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, color: AppTheme.hairline),

              // Overall Score Section
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "OVERALL SCORE",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    "$overallScore / 100",
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Linear Progress Bar
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: overallScore / 100.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ScoreMetric(label: "Accuracy", value: "$accuracyScore%"),
                  _ScoreMetric(label: "Fluency", value: "$fluencyScore%"),
                  _ScoreMetric(label: "Vocabulary", value: "$vocabScore%"),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, color: AppTheme.hairline),

              // Strengths Section
              const SizedBox(height: 24),
              const Text(
                "STRENGTHS",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const _FeedbackRow(
                icon: Icons.check_circle,
                iconColor: AppTheme.primary,
                title: "Grammatical Accuracy",
                description: "Excellent use of past tenses and sentence structure during the dialogue.",
              ),
              const SizedBox(height: 16),
              const _FeedbackRow(
                icon: Icons.check_circle,
                iconColor: AppTheme.primary,
                title: "Vocabulary Range",
                description: "Incorporated sophisticated industry-specific terminology naturally into conversation.",
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, color: AppTheme.hairline),

              // Areas to Improve Section
              const SizedBox(height: 24),
              const Text(
                "AREAS TO IMPROVE",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const _FeedbackRow(
                icon: Icons.error_outline,
                iconColor: AppTheme.error,
                title: "Prepositional Phrases",
                description: "Occasional hesitation when referring to specific timeframes or geographic locations.",
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, color: AppTheme.hairline),

              // Actions
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (scenario != null) {
                      roleplayProvider.startSession(scenario);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const RoleplayChatScreen()),
                      );
                    }
                  },
                  child: const Text("Practice Scenario Again"),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Back to Scenarios"),
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

class _ScoreMetric extends StatelessWidget {
  final String label;
  final String value;
  const _ScoreMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _FeedbackRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

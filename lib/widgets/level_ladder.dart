import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme.dart';

class LevelLadder extends StatelessWidget {
  final String currentCefrLevel;
  final String? customMotivatingMessage;
  final bool compact;

  const LevelLadder({
    super.key,
    required this.currentCefrLevel,
    this.customMotivatingMessage,
    this.compact = false,
  });

  static const List<Map<String, String>> levels = [
    {"cefr": "C2", "label": "Native-like", "subtitle": "Mastery & natural nuance"},
    {"cefr": "C1", "label": "Proficient", "subtitle": "Complex & spontaneous fluency"},
    {"cefr": "B2", "label": "Advanced", "subtitle": "Confident professional expression"},
    {"cefr": "B1", "label": "Intermediate", "subtitle": "Conversational & everyday clear"},
    {"cefr": "A2", "label": "Beginner", "subtitle": "Basic routine phrases & topics"},
    {"cefr": "A1", "label": "Novice", "subtitle": "Foundational words & simple terms"},
  ];

  int _getCefrIndex(String cefr) {
    final clean = cefr.trim().toUpperCase();
    final idx = levels.indexWhere((l) => l['cefr'] == clean);
    if (idx != -1) return idx;
    if (clean.startsWith("A1")) return 5;
    if (clean.startsWith("A2")) return 4;
    if (clean.startsWith("B1")) return 3;
    if (clean.startsWith("B2")) return 2;
    if (clean.startsWith("C1")) return 1;
    if (clean.startsWith("C2")) return 0;
    return 3; // Default to B1 / Intermediate
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = _getCefrIndex(currentCefrLevel);
    final currentLabel = levels[currentIdx]['label']!;
    final targetIdx = (currentIdx - 1).clamp(0, levels.length - 1);
    final targetLabel = levels[targetIdx]['label']!;

    final message = customMotivatingMessage ??
        (currentIdx == 0
            ? "You've reached top proficiency! Keep polishing your fluency daily."
            : "You're starting at $currentLabel ($currentCefrLevel). Let's build your fluency step-by-step to reach $targetLabel!");

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.hairline, width: AppTheme.hairlineWeight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Badge & Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.show_chart, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                "FLUENCY LADDER",
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  "CEFR $currentCefrLevel",
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Vertical Rungs Ladder
          Column(
            children: List.generate(levels.length, (index) {
              final item = levels[index];
              final isCurrent = index == currentIdx;
              final isTarget = index == targetIdx && currentIdx != 0;
              final isCompleted = index > currentIdx;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    // Timeline Node Column
                    SizedBox(
                      width: 28,
                      child: Column(
                        children: [
                          Container(
                            width: isCurrent ? 20 : 12,
                            height: isCurrent ? 20 : 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCurrent
                                  ? AppTheme.primary
                                  : isCompleted
                                      ? AppTheme.primary.withValues(alpha: 0.4)
                                      : isTarget
                                          ? AppTheme.secondaryAccent
                                          : AppTheme.hairline,
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isCurrent
                                ? const Center(
                                    child: Icon(Icons.check, size: 12, color: Colors.white),
                                  )
                                : null,
                          ),
                          if (index < levels.length - 1)
                            Container(
                              width: 2,
                              height: compact ? 16 : 22,
                              color: index >= currentIdx
                                  ? AppTheme.primary.withValues(alpha: 0.3)
                                  : AppTheme.hairline,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Level Label Card
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: compact ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppTheme.primary.withValues(alpha: 0.08)
                              : isTarget
                                  ? AppTheme.secondaryAccent.withValues(alpha: 0.06)
                                  : AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(
                            color: isCurrent
                                ? AppTheme.primary
                                : isTarget
                                    ? AppTheme.secondaryAccent.withValues(alpha: 0.5)
                                    : AppTheme.hairline,
                            width: isCurrent ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              item['label']!,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: compact ? 13 : 14,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                color: isCurrent
                                    ? AppTheme.primary
                                    : isTarget
                                        ? AppTheme.secondaryAccent
                                        : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "(${item['cefr']})",
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isCurrent ? AppTheme.primary : AppTheme.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "YOU ARE HERE",
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            if (isTarget)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "NEXT GOAL",
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryAccent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          )
              .animate()
              .fadeIn(duration: 400.ms, curve: Curves.easeOut)
              .slideY(begin: 0.05, end: 0, duration: 400.ms),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.hairline),
          const SizedBox(height: 12),

          // Motivating Coach Note
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline, size: 18, color: AppTheme.secondaryAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

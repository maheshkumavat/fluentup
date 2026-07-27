import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../providers/real_world_mission_provider.dart';
import '../theme.dart';
import '../widgets/tactile_button.dart';

class RealWorldMissionsScreen extends StatefulWidget {
  const RealWorldMissionsScreen({super.key});

  @override
  State<RealWorldMissionsScreen> createState() => _RealWorldMissionsScreenState();
}

class _RealWorldMissionsScreenState extends State<RealWorldMissionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RealWorldMissionProvider>(context, listen: false).initRealWorldMissions();
    });
  }

  void _showCompletionDialog(RealWorldMission mission) {
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.stars, color: AppTheme.secondaryAccent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Complete Mission",
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Did you complete this offline mission in real life?",
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "\"${mission.title}\"",
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Optional reflection note (how did it feel?):",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: noteController,
                maxLines: 3,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "e.g., I felt nervous at first, but the guard smiled and replied in English!",
                  hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.hairline),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Not Yet", style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final rwProvider = Provider.of<RealWorldMissionProvider>(context, listen: false);
                final pProvider = Provider.of<ProgressProvider>(context, listen: false);

                await rwProvider.completeMission(
                  mission.id,
                  pProvider,
                  reflectionText: noteController.text.trim(),
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("🎉 +${mission.realWorldXpReward} Real World XP Earned! Fear Level Progressed!"),
                      backgroundColor: AppTheme.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Yes, I Did This!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rwProvider = Provider.of<RealWorldMissionProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.public, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text(
              "Real World Missions",
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
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Real-World XP Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, Colors.blue.shade800],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.military_tech, color: Colors.amber, size: 28),
                        SizedBox(width: 8),
                        Text(
                          "REAL-WORLD CONFIDENCE",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${rwProvider.completedMissionsCount} Missions",
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              "Completed Offline in Real Life",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${rwProvider.realWorldXP} RW-XP",
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // PHASE D: FEAR-BREAKING PROGRESSION LADDER (LEVELS 1-8)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Your Confidence Ladder",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Level ${rwProvider.currentFearLevel} of 8",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Fear Level Ladder Cards
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: Column(
                  children: List.generate(8, (index) {
                    final levelNum = index + 1;
                    final isUnlocked = levelNum <= rwProvider.currentFearLevel;
                    final isCurrent = levelNum == rwProvider.currentFearLevel;
                    final title = RealWorldMissionProvider.fearLevelLabels[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCurrent
                                  ? AppTheme.secondaryAccent
                                  : (isUnlocked ? AppTheme.primary : AppTheme.background),
                              border: Border.all(
                                color: isUnlocked ? AppTheme.primary : AppTheme.hairline,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                "$levelNum",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isUnlocked ? Colors.white : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                color: isUnlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "CURRENT",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryAccent,
                                ),
                              ),
                            )
                          else if (isUnlocked)
                            const Icon(Icons.check, color: AppTheme.primary, size: 18)
                          else
                            const Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 16),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 28),

              // PHASE C: ACTIVE REAL-WORLD MISSIONS LIST
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Today's Real-World Missions",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20),
                    onPressed: () {
                      rwProvider.generateRealWorldMissions();
                    },
                    tooltip: "Generate New Real World Missions",
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (rwProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rwProvider.missions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final mission = rwProvider.missions[index];

                    return TactileButton(
                      onTap: () {
                        if (!mission.isCompleted) {
                          _showCompletionDialog(mission);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: mission.isCompleted
                              ? AppTheme.primary.withValues(alpha: 0.08)
                              : AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: mission.isCompleted
                                ? AppTheme.primary.withValues(alpha: 0.4)
                                : AppTheme.hairline,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  mission.isCompleted ? Icons.check_circle : Icons.outlined_flag,
                                  color: mission.isCompleted ? AppTheme.primary : AppTheme.secondaryAccent,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    mission.title,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: mission.isCompleted
                                          ? AppTheme.textSecondary
                                          : AppTheme.textPrimary,
                                      decoration: mission.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "+${mission.realWorldXpReward} RW-XP",
                                    style: const TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              mission.description,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            if (mission.reflectionText != null && mission.reflectionText!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "💬 Reflection: ${mission.reflectionText}",
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

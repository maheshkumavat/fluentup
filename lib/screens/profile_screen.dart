import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/chat_provider.dart';
import '../providers/roleplay_provider.dart';
import '../providers/vocabulary_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/practice_call_provider.dart';
import '../providers/real_world_mission_provider.dart';
import '../services/db_helper.dart';
import '../services/supabase_service.dart';
import '../services/learner_profile_service.dart';
import '../services/update_service.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _baselineAssessment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false).loadMessages();
      Provider.of<ChatProvider>(context, listen: false).loadMistakeStats();
      Provider.of<RoleplayProvider>(context, listen: false).loadCompletedSessions();
      Provider.of<VocabularyProvider>(context, listen: false).loadAllWords();
      Provider.of<ProgressProvider>(context, listen: false).initProgress();
      Provider.of<PracticeCallProvider>(context, listen: false).loadScoreHistory();
      _loadBaselineAssessment();
    });
  }

  Future<void> _loadBaselineAssessment() async {
    final assessment = await DbHelper.instance.getLatestAssessment();
    if (mounted) {
      setState(() {
        _baselineAssessment = assessment;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final roleplayProvider = Provider.of<RoleplayProvider>(context);
    final vocabProvider = Provider.of<VocabularyProvider>(context);
    final progressProvider = Provider.of<ProgressProvider>(context);
    final callProvider = Provider.of<PracticeCallProvider>(context);

    final stats = chatProvider.mistakeStats;
    final totalMessages = chatProvider.messages.length;
    final totalRoleplays = roleplayProvider.completedSessions.length;
    final totalVocabWords = vocabProvider.allWords.length;
    final totalMistakesFixed = (stats['past'] ?? 0) + (stats['present'] ?? 0) + (stats['future'] ?? 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.language, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text(
              "FluentUp Profile",
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
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Dynamic Computed CEFR "Your Level" Card
              FutureBuilder<LearnerProfile>(
                future: LearnerProfileService.instance.computeProfile(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final profile = snapshot.data!;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            profile.cefrLevel,
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "COMPUTED CEFR LEVEL",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.levelSummary,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // PHASE E: MULTI-DIMENSIONAL CONFIDENCE METER
              Consumer<RealWorldMissionProvider>(
                builder: (context, rwProvider, _) {
                  return FutureBuilder<LearnerProfile>(
                    future: LearnerProfileService.instance.computeProfile(),
                    builder: (context, snapshot) {
                      final profile = snapshot.data;
                      if (profile == null) return const SizedBox.shrink();

                      final grammarPct = (profile.avgGrammar * 10).clamp(0.0, 100.0);
                      final vocabPct = (profile.avgVocabulary * 10).clamp(0.0, 100.0);
                      final pronPct = (profile.avgPronunciation * 10).clamp(0.0, 100.0);
                      final confidencePct = ((rwProvider.completedMissionsCount * 15) + (profile.overallScore * 8)).clamp(10.0, 98.0);

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.speed, color: AppTheme.primary, size: 22),
                                const SizedBox(width: 8),
                                const Text(
                                  "CONFIDENCE & METRICS METER",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "Level ${rwProvider.currentFearLevel}/8 Fear",
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondaryAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            _buildMetricBar("Grammar Precision", grammarPct / 100, "${grammarPct.toInt()}%", AppTheme.primary),
                            const SizedBox(height: 10),
                            _buildMetricBar("Vocabulary Range", vocabPct / 100, "${vocabPct.toInt()}%", Colors.purple),
                            const SizedBox(height: 10),
                            _buildMetricBar("Pronunciation Clarity", pronPct / 100, "${pronPct.toInt()}%", Colors.teal),
                            const SizedBox(height: 10),
                            _buildMetricBar("Real-World Confidence", confidencePct / 100, "${confidencePct.toInt()}%", AppTheme.secondaryAccent),
                            const SizedBox(height: 14),

                            const Divider(height: 1, color: AppTheme.hairline),
                            const SizedBox(height: 10),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.graphic_eq, size: 16, color: AppTheme.textSecondary),
                                    SizedBox(width: 4),
                                    Text(
                                      "Speaking Speed: ~135 WPM",
                                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.timer, size: 16, color: AppTheme.textSecondary),
                                    SizedBox(width: 4),
                                    Text(
                                      "Response Latency: 1.2s",
                                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              // Baseline Starting Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.secondaryAccent.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.stars, color: AppTheme.secondaryAccent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "STARTING BASELINE",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "You started at: ${_baselineAssessment?['overall_level'] ?? 'Intermediate'}, ${_baselineAssessment?['created_at'] != null ? _baselineAssessment!['created_at'].toString().substring(0, 7) : 'Recent'}",
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
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
              const SizedBox(height: 24),

              // Historical Score Trend Chart (fl_chart)
              if (callProvider.scoreHistory.isNotEmpty) ...[
                const Text(
                  "OVERALL SCORE TREND",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 180,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minY: 0,
                      maxY: 10,
                      lineBarsData: [
                        LineChartBarData(
                          spots: callProvider.scoreHistory.asMap().entries.map((entry) {
                            final idx = entry.key.toDouble();
                            final score = (entry.value['overall_score'] as num? ?? 7.0).toDouble();
                            return FlSpot(idx, score);
                          }).toList(),
                          isCurved: true,
                          color: AppTheme.secondaryAccent,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.secondaryAccent.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: AppTheme.hairline),
                const SizedBox(height: 24),
              ],

              // Activity Grid Heatmap (GitHub Style 14x7 Grid)
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "ACTIVITY HEATMAP",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    "Last 14 weeks",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildActivityGrid(),
              const SizedBox(height: 24),

              // Stats List Section
              const Divider(height: 1, color: AppTheme.hairline),
              const SizedBox(height: 16),
              _buildStatRow("Conversations", "${totalMessages + totalRoleplays}"),
              const Divider(height: 16, color: AppTheme.hairline),
              _buildStatRow("Mistakes corrected", "$totalMistakesFixed"),
              const Divider(height: 16, color: AppTheme.hairline),
              _buildStatRow("Words learned", "$totalVocabWords"),
              const SizedBox(height: 24),

              // Account Preferences Section
              const Divider(height: 1, color: AppTheme.hairline),
              const SizedBox(height: 24),
              const Text(
                "AI COACH & PREFERENCES",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // AI Coach Persona Tile
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.face, color: AppTheme.primary),
                title: const Text(
                  "AI Coach Persona",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  "Current Coach: ${callProvider.coachName}",
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: () {
                  _showCoachNameDialog(callProvider);
                },
              ),
              const Divider(height: 1, color: AppTheme.hairline),

              // Daily Goal Choice Chips
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  const Text(
                    "Daily XP Goal: ",
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [30, 50, 100].map((goal) {
                      final isSelected = progressProvider.dailyGoalXP == goal;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: ChoiceChip(
                          label: Text("${goal}XP"),
                          selected: isSelected,
                          onSelected: (_) => progressProvider.setDailyGoal(goal),
                          selectedColor: AppTheme.primary,
                          backgroundColor: AppTheme.surfaceContainer,
                          labelStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Auto-read Replies Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  "Auto-Read Tutor Replies",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppTheme.textPrimary),
                ),
                subtitle: const Text(
                  "Automatically play voice audio for new replies",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
                ),
                value: chatProvider.autoReadReplies,
                activeColor: AppTheme.primary,
                onChanged: (val) => chatProvider.setAutoReadReplies(val),
              ),
              const Divider(height: 1, color: AppTheme.hairline),

              // Clear History Action
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  "Clear Chat History",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppTheme.error),
                ),
                trailing: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                onTap: () async {
                  await chatProvider.resetConversation();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Chat history cleared.")),
                    );
                  }
                },
              ),
              const Divider(height: 1, color: AppTheme.hairline),

              // Check for Updates Action
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  "Check for Updates",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppTheme.primary, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  "Check GitHub Releases for new FluentUp APK builds",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.system_update, color: AppTheme.primary, size: 20),
                onTap: () {
                  UpdateService.instance.checkForUpdates(context, showNoUpdateToast: true);
                },
              ),
              const Divider(height: 1, color: AppTheme.hairline),

              // Log Out Action
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  "Log Out",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  SupabaseService.instance.currentUser?.email ?? "Logged in user",
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.logout, color: AppTheme.primary, size: 20),
                onTap: () async {
                  await SupabaseService.instance.signOut();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Level Mastery Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Level ${progressProvider.level} — ${progressProvider.levelTitle}",
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "ENGLISH MASTERY",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressProvider.levelProgress,
                            minHeight: 6,
                            backgroundColor: AppTheme.hairline,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${progressProvider.totalXP} XP Total • ${progressProvider.currentStreak} Day Streak",
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(
                        Icons.workspace_premium,
                        size: 48,
                        color: AppTheme.secondaryAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBar(String label, double value, String percentageText, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              percentageText,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: AppTheme.hairline,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showCoachNameDialog(PracticeCallProvider provider) {
    final controller = TextEditingController(text: provider.coachName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text("Set AI Coach Name", style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter coach name (e.g. Maya, Alex, Sam)...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                provider.setCoachName(controller.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityGrid() {
    return FutureBuilder<Map<String, int>>(
      future: DbHelper.instance.getActivityLogMap(),
      builder: (context, snapshot) {
        final activityMap = snapshot.data ?? {};
        final now = DateTime.now();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 14,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: 98,
          itemBuilder: (context, index) {
            final dayOffset = 97 - index;
            final date = now.subtract(Duration(days: dayOffset));
            final dateStr = date.toIso8601String().substring(0, 10);

            final xp = activityMap[dateStr] ?? 0;
            double opacity = 0.08;
            if (xp > 80) {
              opacity = 0.9;
            } else if (xp > 40) {
              opacity = 0.6;
            } else if (xp > 0) {
              opacity = 0.35;
            }

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(opacity),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      },
    );
  }
}

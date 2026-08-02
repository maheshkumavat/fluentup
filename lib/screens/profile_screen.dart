import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/chat_provider.dart';
import '../providers/roleplay_provider.dart';
import '../providers/vocabulary_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/practice_call_provider.dart';
import '../providers/real_world_mission_provider.dart';
import '../providers/mission_provider.dart';
import '../providers/roadmap_provider.dart';
import '../services/db_helper.dart';
import '../services/supabase_service.dart';
import '../services/learner_profile_service.dart';
import '../services/update_service.dart';
import '../widgets/level_ladder.dart';
import '../theme.dart';
import 'leaderboard_screen.dart';

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
              const SizedBox(height: 16),
              FutureBuilder<LearnerProfile>(
                future: LearnerProfileService.instance.computeProfile(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return LevelLadder(currentCefrLevel: snapshot.data!.cefrLevel, compact: true);
                },
              ),
              const SizedBox(height: 20),

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
              const SizedBox(height: 20),

              // Leaderboard Card & Coin Store Section
              _buildLeaderboardCard(),
              _buildCoinStoreSection(progressProvider),
              const SizedBox(height: 20),

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

              // Leaderboard Privacy Opt-Out Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  "Show me on the Leaderboard",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppTheme.textPrimary),
                ),
                subtitle: const Text(
                  "Display your stats publicly on the global leaderboard",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
                ),
                value: progressProvider.leaderboardOptIn,
                activeColor: AppTheme.primary,
                onChanged: (val) => progressProvider.toggleLeaderboardOptIn(val),
              ),
              const Divider(height: 1, color: AppTheme.hairline),

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

              // Danger Zone: Account Deletion
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "DANGER ZONE",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Permanently delete your account and all associated local and cloud data. This action is irreversible.",
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
                        label: const Text("Delete Account", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _confirmAccountDeletion(context),
                      ),
                    ),
                  ],
                ),
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

  void _confirmAccountDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 28),
            SizedBox(width: 8),
            Text("Delete Account?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ],
        ),
        content: const Text(
          "Are you sure you want to delete your account?\n\nThis will permanently delete your user profile, streak, XP progress, practice records, and all local data. This action cannot be undone.",
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              _executeAccountDeletion(context);
            },
            child: const Text("Yes, Delete Permanently"),
          ),
        ],
      ),
    );
  }

  void _executeAccountDeletion(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppTheme.error),
      ),
    );

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await SupabaseService.instance.deleteAccount();
      if (mounted) {
        nav.pop(); // Close loading dialog
        nav.pushNamedAndRemoveUntil('/auth', (route) => false);
        messenger.showSnackBar(
          const SnackBar(content: Text("Your account has been deleted successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        nav.pop(); // Close loading dialog
        messenger.showSnackBar(
          SnackBar(content: Text("Error deleting account: $e")),
        );
      }
    }
  }

  Widget _buildLeaderboardCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.secondaryAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_events, color: AppTheme.secondaryAccent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "GLOBAL LEADERBOARD",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Compete & Learn Together",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "See how your XP ranks against fellow speakers.",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
              );
            },
            child: const Text("View", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinStoreSection(ProgressProvider progressProvider) {
    final missionProvider = Provider.of<MissionProvider>(context, listen: false);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.monetization_on_outlined, color: Color(0xFFFFB300), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    "COINS STORE",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
                ),
                child: Text(
                  "${progressProvider.coins} Coins",
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Earn coins alongside XP for completing missions and lessons. Redeem them below:",
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // 1. Streak Freeze Card
          _buildRedeemItemTile(
            icon: Icons.ac_unit,
            iconColor: Colors.lightBlue,
            title: "Streak Freeze",
            subtitle: "Protects your streak for 1 missed day (${progressProvider.streakFreezes} active)",
            cost: 50,
            canAfford: progressProvider.coins >= 50,
            onRedeem: () async {
              final success = await progressProvider.redeemStreakFreeze();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? "Streak Freeze redeemed!" : "Not enough coins for Streak Freeze."),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),

          // 2. Extra Hint Token Card
          _buildRedeemItemTile(
            icon: Icons.lightbulb_outline,
            iconColor: Colors.amber,
            title: "Extra Hint Token",
            subtitle: "Reveals answer tip immediately in Grammar Gym (${progressProvider.extraHints} available)",
            cost: 10,
            canAfford: progressProvider.coins >= 10,
            onRedeem: () async {
              final success = await progressProvider.redeemExtraHint();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? "Extra Hint Token redeemed!" : "Not enough coins for Extra Hint."),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),

          // 3. Skip Today's Mission Card
          _buildRedeemItemTile(
            icon: Icons.fast_forward_rounded,
            iconColor: Colors.purple,
            title: "Skip Today's Mission",
            subtitle: "Marks today complete without doing it (Limit: 1/week)",
            cost: 100,
            canAfford: progressProvider.coins >= 100,
            onRedeem: () async {
              final allowed = await progressProvider.canSkipMissionThisWeek();
              if (!allowed) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Mission Skip can only be redeemed once per week.")),
                  );
                }
                return;
              }
              final success = await progressProvider.redeemSkipMission();
              if (success) {
                final uncompleted = missionProvider.missions.where((m) => !m.isCompleted).toList();
                if (uncompleted.isNotEmpty) {
                  final roadmapProvider = Provider.of<RoadmapProvider>(context, listen: false);
                  await missionProvider.completeMission(uncompleted.first.id, progressProvider, roadmapProvider: roadmapProvider);
                }
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? "Today's mission skipped & bonus XP awarded!" : "Could not skip mission."),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),

          // Redemption History Link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showRedemptionHistoryModal(context),
              icon: const Icon(Icons.history, size: 16, color: AppTheme.primary),
              label: const Text("Redemption History", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.primary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemItemTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required int cost,
    required bool canAfford,
    required VoidCallback onRedeem,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: canAfford ? AppTheme.primary : AppTheme.textSecondary,
              side: BorderSide(color: canAfford ? AppTheme.primary : AppTheme.hairline),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: canAfford ? onRedeem : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_outlined, size: 14, color: Color(0xFFFFB300)),
                const SizedBox(width: 4),
                Text("$cost", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRedemptionHistoryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: AppTheme.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Redemption History",
                    style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: DbHelper.instance.getCoinRedemptions(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final redemptions = snapshot.data!;
                    if (redemptions.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: Text("No redemptions yet. Complete missions to earn coins!", style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: redemptions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.hairline),
                      itemBuilder: (context, index) {
                        final item = redemptions[index];
                        final name = item['item_name'] as String? ?? 'Redemption';
                        final cost = item['cost'] as int? ?? 0;
                        final dateStr = item['timestamp'] as String? ?? '';
                        String formattedDate = dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          subtitle: Text(formattedDate, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary)),
                          trailing: Text("-$cost coins", style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.error)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

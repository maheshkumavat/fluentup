import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safe_device/safe_device.dart';

import '../providers/mission_provider.dart';
import '../providers/practice_call_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/roadmap_provider.dart';
import '../services/learner_profile_service.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/tactile_button.dart';
import '../widgets/floating_assistant_widget.dart';

import 'chat_screen.dart';
import 'describe_image_screen.dart';
import 'explain_code_screen.dart';
import 'grammar_gym_screen.dart';
import 'practice_call_screen.dart';
import 'presentation_practice_screen.dart';
import 'profile_screen.dart';
import 'roadmap_screen.dart';
import 'roleplay_screen.dart';
import 'topic_library_screen.dart';
import 'vocabulary_screen.dart';
import 'real_world_missions_screen.dart';
import 'sound_practice_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isRootedOrTampered = false;
  bool _exploreExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RoadmapProvider>(context, listen: false).initRoadmap();
      Provider.of<PracticeCallProvider>(context, listen: false).loadCoachName();
      Provider.of<MissionProvider>(context, listen: false).initDailyMissions();
      _checkDeviceSecurity();
      UpdateService.instance.checkForUpdates(context);
    });
  }

  Future<void> _checkDeviceSecurity() async {
    if (!kDebugMode) {
      try {
        final isJailBroken = await SafeDevice.isJailBroken;
        final isRealDevice = await SafeDevice.isRealDevice;

        if (isJailBroken || !isRealDevice) {
          debugPrint("Security warning: Rooted or simulated environment detected.");
          if (mounted) {
            setState(() {
              _isRootedOrTampered = true;
            });
          }
        }
      } catch (e) {
        debugPrint("Error checking device security: $e");
      }
    }
  }

  void _navigateToMissionTarget(MissionItem item, Map<String, String>? recTopic) async {
    final missionProvider = Provider.of<MissionProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    bool? completed;

    switch (item.type) {
      case 'lesson':
        completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (context) => const GrammarGymScreen()),
        );
        break;
      case 'practice':
        completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (context) => const VocabularyScreen()),
        );
        break;
      case 'conversation':
        completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => PracticeCallScreen(topic: item.targetData.isNotEmpty ? item.targetData : recTopic),
          ),
        );
        break;
      case 'challenge':
        completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (context) => RoleplayScreen()),
        );
        break;
      case 'review':
        completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (context) => const GrammarGymScreen()),
        );
        break;
      case 'sound':
        completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (context) => const SoundPracticeScreen()),
        );
        break;
      default:
        completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (context) => const TopicLibraryScreen()),
        );
    }

    // Auto-check mission upon return ONLY if completed was returned true
    final roadmapProvider = Provider.of<RoadmapProvider>(context, listen: false);
    if (!item.isCompleted && completed == true) {
      await missionProvider.completeMission(item.id, progressProvider, roadmapProvider: roadmapProvider);
    }
  }

  Widget _buildHomeHub() {
    final progressProvider = Provider.of<ProgressProvider>(context);
    final missionProvider = Provider.of<MissionProvider>(context);

    const targetGoalXP = 100;
    final todayXpProgress = (progressProvider.todayXP / targetGoalXP).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.language, color: AppTheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text(
              "FluentUp",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const Spacer(),

            // Streak Flame Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.secondaryAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.secondaryAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: AppTheme.secondaryAccent, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    "${progressProvider.currentStreak}",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Total XP Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 2),
                  Text(
                    "${progressProvider.totalXP} XP",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Coin Balance Badge
            GestureDetector(
              onTap: () {
                setState(() => _currentIndex = 3); // Navigate to profile tab
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on_outlined, color: Color(0xFFFFB300), size: 18),
                    const SizedBox(width: 3),
                    Text(
                      "${progressProvider.coins}",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Leaderboard Icon Action
            IconButton(
              icon: const Icon(Icons.emoji_events, color: AppTheme.secondaryAccent, size: 22),
              tooltip: "Leaderboard",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
                );
              },
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.hairline),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<LearnerProfile>(
          future: LearnerProfileService.instance.computeProfile(),
          builder: (context, snapshot) {
            final profile = snapshot.data;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.containerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOP SECTION: Greeting, Level & Daily Goal XP Progress
                  if (profile != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Welcome back, ${profile.userName} 👋",
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Goal: ${profile.learningGoal}",
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // CEFR Level Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "LEVEL",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                profile.cefrLevel,
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Daily XP Goal Progress Bar
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.track_changes, color: AppTheme.primary, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Today's Goal: ${progressProvider.todayXP}/$targetGoalXP XP",
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "${(todayXpProgress * 100).toInt()}%",
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: todayXpProgress,
                              minHeight: 10,
                              backgroundColor: AppTheme.hairline,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 2. MAIN SECTION: TODAY'S MISSION CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: missionProvider.allCompleted
                            ? AppTheme.secondaryAccent.withOpacity(0.8)
                            : AppTheme.primary.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.flag, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    "TODAY'S MISSION",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "${missionProvider.completedCount}/${missionProvider.missions.length} Done",
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18, color: AppTheme.textSecondary),
                              onPressed: () {
                                missionProvider.refreshMissions();
                              },
                              tooltip: "Regenerate Today's Missions",
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Complete today's guided sequence to level up your fluency:",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Mission Item Checklist
                        if (missionProvider.isLoading)
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
                            itemCount: missionProvider.missions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = missionProvider.missions[index];

                              return TactileButton(
                                onTap: () => _navigateToMissionTarget(item, profile?.recommendedTopic),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: item.isCompleted
                                        ? AppTheme.primary.withOpacity(0.08)
                                        : AppTheme.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: item.isCompleted
                                          ? AppTheme.primary.withOpacity(0.4)
                                          : AppTheme.hairline,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Checkbox Icon
                                      Icon(
                                        item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                        color: item.isCompleted ? AppTheme.primary : AppTheme.textSecondary,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),

                                      // Item Title & Description
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.title,
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: item.isCompleted
                                                          ? AppTheme.textSecondary
                                                          : AppTheme.textPrimary,
                                                      decoration: item.isCompleted
                                                          ? TextDecoration.lineThrough
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                                _buildTypeChip(item.type),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.subtitle,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 12,
                                                color: item.isCompleted
                                                    ? AppTheme.textSecondary.withOpacity(0.7)
                                                    : AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // XP Reward Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: item.isCompleted
                                              ? AppTheme.primary.withOpacity(0.2)
                                              : AppTheme.secondaryAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          "+${item.xpReward} XP",
                                          style: TextStyle(
                                            fontFamily: 'JetBrains Mono',
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: item.isCompleted
                                                ? AppTheme.primary
                                                : AppTheme.secondaryAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        // Reward Animation / Celebration Banner
                        if (missionProvider.allCompleted) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.secondaryAccent.withOpacity(0.9),
                                  Colors.amber.shade700,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.secondaryAccent.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.emoji_events, color: Colors.white, size: 36),
                                    SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "🎉 MISSION COMPLETE!",
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            "+150 Bonus XP Earned! Great job today!",
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.arrow_forward, color: AppTheme.primary, size: 18),
                                    label: const Text(
                                      "Start Next Day's Missions",
                                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () async {
                                      final roadmapProvider = Provider.of<RoadmapProvider>(context, listen: false);
                                      await missionProvider.refreshMissions();
                                      roadmapProvider.generateNextBatchAuto();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Next day's missions generated!")),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 3. SECONDARY "EXPLORE ALL PRACTICE MODES" SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Explore Practice Modes",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _exploreExpanded = !_exploreExpanded;
                          });
                        },
                        icon: Icon(
                          _exploreExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: AppTheme.primary,
                        ),
                        label: Text(
                          _exploreExpanded ? "Show Less" : "View All",
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Secondary Feature Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: [
                      _buildExploreCard(
                        title: "AI Voice Call",
                        icon: Icons.phone_in_talk,
                        color: AppTheme.primary,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PracticeCallScreen(topic: profile?.recommendedTopic),
                            ),
                          );
                        },
                      ),
                      _buildExploreCard(
                        title: "Grammar Gym",
                        icon: Icons.fitness_center,
                        color: Colors.purple.shade600,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const GrammarGymScreen()),
                          );
                        },
                      ),
                      _buildExploreCard(
                        title: "Vocab Bank",
                        icon: Icons.style,
                        color: Colors.teal.shade600,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const VocabularyScreen()),
                          );
                        },
                      ),
                      _buildExploreCard(
                        title: "Sound Practice",
                        icon: Icons.graphic_eq,
                        color: Colors.teal.shade700,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const SoundPracticeScreen()),
                          );
                        },
                      ),
                      _buildExploreCard(
                        title: "Roleplay",
                        icon: Icons.theater_comedy,
                        color: Colors.orange.shade700,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => RoleplayScreen()),
                          );
                        },
                      ),
                      if (_exploreExpanded) ...[
                        _buildExploreCard(
                          title: "Describe Image",
                          icon: Icons.image,
                          color: Colors.indigo.shade600,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const DescribeImageScreen()),
                            );
                          },
                        ),
                        _buildExploreCard(
                          title: "Explain Code",
                          icon: Icons.code,
                          color: Colors.blueGrey.shade700,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const ExplainCodeScreen()),
                            );
                          },
                        ),
                        _buildExploreCard(
                          title: "Presentation",
                          icon: Icons.mic_external_on,
                          color: Colors.redAccent.shade700,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const PresentationPracticeScreen()),
                            );
                          },
                        ),
                        _buildExploreCard(
                          title: "Real World Missions",
                          icon: Icons.public,
                          color: Colors.amber.shade800,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => RealWorldMissionsScreen()),
                            );
                          },
                        ),
                        _buildExploreCard(
                          title: "Topic Library",
                          icon: Icons.apps,
                          color: Colors.blue.shade700,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const TopicLibraryScreen()),
                            );
                          },
                        ),
                        _buildExploreCard(
                          title: "Text Chat",
                          icon: Icons.chat_bubble_outline,
                          color: Colors.deepOrange.shade600,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const ChatScreen()),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    String label = type.toUpperCase();
    Color bg = AppTheme.primary.withOpacity(0.1);
    Color text = AppTheme.primary;

    switch (type) {
      case 'lesson':
        label = "LESSON";
        bg = Colors.purple.withOpacity(0.12);
        text = Colors.purple.shade700;
        break;
      case 'practice':
        label = "PRACTICE";
        bg = Colors.teal.withOpacity(0.12);
        text = Colors.teal.shade700;
        break;
      case 'conversation':
        label = "VOICE CALL";
        bg = AppTheme.primary.withOpacity(0.12);
        text = AppTheme.primary;
        break;
      case 'challenge':
        label = "CHALLENGE";
        bg = Colors.orange.withOpacity(0.12);
        text = Colors.orange.shade800;
        break;
      case 'review':
        label = "REVIEW";
        bg = Colors.indigo.withOpacity(0.12);
        text = Colors.indigo.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  Widget _buildExploreCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TactileButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.hairline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeHub(),
      const RoadmapScreen(),
      const VocabularyScreen(),
      const GrammarGymScreen(),
      RoleplayScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Column(
            children: [
              if (_isRootedOrTampered)
                Container(
                  color: Colors.amber.shade900,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        Icon(Icons.security, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "This device appears to be rooted, some features may be restricted for security",
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: screens,
                ),
              ),
            ],
          ),
          const Positioned(
            bottom: 16,
            right: 16,
            child: FloatingAssistantWidget(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: AppTheme.background,
          border: Border(
            top: BorderSide(color: AppTheme.hairline, width: AppTheme.hairlineWeight),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: AppTheme.background,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.flag_outlined),
              activeIcon: Icon(Icons.flag, color: AppTheme.primary),
              label: "Missions",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timeline_outlined),
              activeIcon: Icon(Icons.timeline, color: AppTheme.primary),
              label: "Roadmap",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.style_outlined),
              activeIcon: Icon(Icons.style, color: AppTheme.primary),
              label: "Vocab",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book, color: AppTheme.primary),
              label: "Grammar",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.theater_comedy_outlined),
              activeIcon: Icon(Icons.theater_comedy, color: AppTheme.primary),
              label: "Roleplay",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person, color: AppTheme.primary),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}

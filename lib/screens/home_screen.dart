import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safe_device/safe_device.dart';
import 'chat_screen.dart';
import 'roadmap_screen.dart';
import 'grammar_gym_screen.dart';
import 'roleplay_screen.dart';
import 'vocabulary_screen.dart';
import 'profile_screen.dart';
import 'practice_call_screen.dart';
import 'topic_library_screen.dart';
import '../providers/roadmap_provider.dart';
import '../providers/practice_call_provider.dart';
import '../providers/progress_provider.dart';
import '../services/learner_profile_service.dart';
import '../services/update_service.dart';
import '../widgets/coach_avatar.dart';
import '../widgets/tactile_button.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isRootedOrTampered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RoadmapProvider>(context, listen: false).initRoadmap();
      Provider.of<PracticeCallProvider>(context, listen: false).loadCoachName();
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

  Widget _buildHomeHub() {
    final roadmapProvider = Provider.of<RoadmapProvider>(context);
    final callProvider = Provider.of<PracticeCallProvider>(context);
    final currentDay = roadmapProvider.currentFocusDay;

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
            Consumer<ProgressProvider>(
              builder: (context, progressProvider, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: AppTheme.secondaryAccent, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        "${progressProvider.currentStreak}",
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryAccent,
                        ),
                      ),
                    ],
                  ),
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
            final recTopic = profile?.recommendedTopic;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.containerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personalized Welcome Header
                  if (profile != null) ...[
                    Text(
                      "Hey ${profile.userName}, ready to practice?",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Goal: ${profile.learningGoal}",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.secondaryAccent,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Unified "Your Level" Badge Card
                  if (profile != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.hairline),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              profile.cefrLevel,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "YOUR LEVEL",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  profile.levelSummary,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Today's Focus Card (Linked to Roadmap)
                  if (currentDay != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "TODAY'S FOCUS • DAY ${currentDay.dayNumber}",
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const Icon(Icons.stars, color: AppTheme.secondaryAccent, size: 20),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentDay.title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentDay.description,
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
                    const SizedBox(height: 24),
                  ],

                  // Prominent "Start Practice Call" Primary Action (Personalized Topic)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const CoachAvatar(
                          size: 64,
                          state: CoachAvatarState.idle,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Practice Call with ${callProvider.coachName}",
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          recTopic != null
                              ? "Targeted Topic: ${recTopic['title']} — ${recTopic['description']}"
                              : "Voice-first interactive 2-minute call session with live feedback.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TactileButton(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PracticeCallScreen(topic: recTopic),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: const Text(
                              "Start Practice Call Now",
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 24),

              // Topic Library & Extra Features Quick Links
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TopicLibraryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.apps, color: AppTheme.primary),
                      label: const Text("35+ Topic Library"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentIndex = 1; // Switch to Roadmap tab
                        });
                      },
                      icon: const Icon(Icons.timeline, color: AppTheme.primary),
                      label: const Text("Full Roadmap"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Text Chat Drawer Link
              const Divider(height: 1, color: AppTheme.hairline),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, color: AppTheme.primary),
                ),
                title: const Text(
                  "Text Chat Mode",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  "Prefer typing? Access the classic text conversation mode.",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ChatScreen()),
                  );
                },
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
      body: Column(
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
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home, color: AppTheme.primary),
              label: "Home",
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

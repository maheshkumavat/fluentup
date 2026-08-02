import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allTimeLeaderboard = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      await progressProvider.syncLeaderboardStats();

      final currentUserId = SupabaseService.instance.currentUserId;

      if (SupabaseService.instance.isInitialized) {
        final response = await SupabaseService.instance.client
            ?.from('leaderboard_stats')
            .select('user_id, display_name, total_xp, current_streak, coins, is_public')
            .eq('is_public', true)
            .order('total_xp', ascending: false)
            .limit(50);

        if (response != null) {
          final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(response as List);
          
          // Check if current user is in rows, if missing or not synced yet, add local row
          bool currentUserFound = false;
          for (var r in rows) {
            if (r['user_id'] == currentUserId) {
              currentUserFound = true;
              break;
            }
          }

          if (!currentUserFound && currentUserId != null && progressProvider.leaderboardOptIn) {
            rows.add({
              'user_id': currentUserId,
              'display_name': 'You (Current User)',
              'total_xp': progressProvider.totalXP,
              'current_streak': progressProvider.currentStreak,
              'coins': progressProvider.coins,
              'is_public': true,
            });
            rows.sort((a, b) => (b['total_xp'] as int).compareTo(a['total_xp'] as int));
          }

          if (mounted) {
            setState(() {
              _allTimeLeaderboard = rows;
              _isLoading = false;
            });
          }
          return;
        }
      }

      // Fallback local row if Supabase not reachable
      if (mounted) {
        setState(() {
          _allTimeLeaderboard = [
            {
              'user_id': currentUserId ?? 'local_user',
              'display_name': 'You',
              'total_xp': progressProvider.totalXP,
              'current_streak': progressProvider.currentStreak,
              'coins': progressProvider.coins,
              'is_public': true,
            }
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading leaderboard: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Could not sync leaderboard data.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.instance.currentUserId;
    final progressProvider = Provider.of<ProgressProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: AppTheme.secondaryAccent, size: 24),
            SizedBox(width: 8),
            Text(
              "Global Leaderboard",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: const [
              Tab(text: "All Time"),
              Tab(text: "This Week"),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildLeaderboardList(currentUserId, progressProvider, isWeekly: false),
            _buildLeaderboardList(currentUserId, progressProvider, isWeekly: true),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardList(String? currentUserId, ProgressProvider progressProvider, {required bool isWeekly}) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_errorMessage != null && _allTimeLeaderboard.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchLeaderboard,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (_allTimeLeaderboard.isEmpty) {
      return const Center(
        child: Text("No users on the leaderboard yet.", style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLeaderboard,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.containerPadding),
        itemCount: _allTimeLeaderboard.length,
        itemBuilder: (context, index) {
          final item = _allTimeLeaderboard[index];
          final rank = index + 1;
          final isCurrentUser = (currentUserId != null && item['user_id'] == currentUserId) || item['display_name'].toString().toLowerCase().contains('you');
          final displayName = item['display_name'] as String? ?? 'Learner';
          final xp = item['total_xp'] as int? ?? 0;
          final streak = item['current_streak'] as int? ?? 0;
          final coins = item['coins'] as int? ?? 0;

          // Rank badge styling
          Widget rankWidget;
          if (rank == 1) {
            rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 28);
          } else if (rank == 2) {
            rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFC0C0C0), size: 26);
          } else if (rank == 3) {
            rankWidget = const Icon(Icons.emoji_events, color: Color(0xFFCD7F32), size: 24);
          } else {
            rankWidget = Text(
              "#$rank",
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? AppTheme.primary.withValues(alpha: 0.12)
                  : AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrentUser ? AppTheme.primary : AppTheme.hairline,
                width: isCurrentUser ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Center(child: rankWidget),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w600,
                                color: isCurrentUser ? AppTheme.primary : AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "YOU",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: AppTheme.secondaryAccent, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            "$streak streak",
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.monetization_on_outlined, color: Color(0xFFFFB300), size: 14),
                          const SizedBox(width: 2),
                          Text(
                            "$coins coins",
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "$xp XP",
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

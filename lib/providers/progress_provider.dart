import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/db_helper.dart';
import '../services/supabase_service.dart';
import '../services/learner_profile_service.dart';

class ProgressProvider extends ChangeNotifier {
  int _totalXP = 0;
  int _coins = 0;
  int _streakFreezes = 0;
  int _extraHints = 0;
  int _dailyGoalXP = 50; // Default goal
  int _currentStreak = 0;
  int _todayXP = 0;
  bool _notificationsEnabled = true;
  bool _leaderboardOptIn = true;
  Map<String, int> _activityHeatmap = {};

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  int get totalXP => _totalXP;
  int get coins => _coins;
  int get streakFreezes => _streakFreezes;
  int get extraHints => _extraHints;
  int get dailyGoalXP => _dailyGoalXP;
  int get currentStreak => _currentStreak;
  int get todayXP => _todayXP;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get leaderboardOptIn => _leaderboardOptIn;
  Map<String, int> get activityHeatmap => _activityHeatmap;

  int get level => (_totalXP ~/ 500) + 1;
  int get levelProgressXP => _totalXP % 500;
  double get levelProgress => (_totalXP % 500) / 500.0;
  double get dailyGoalProgress => (_todayXP / _dailyGoalXP).clamp(0.0, 1.0);

  String get levelTitle {
    final l = level;
    if (l == 1) return "Novice Speaker";
    if (l == 2) return "Active Learner";
    if (l == 3) return "Conversationalist";
    if (l == 4) return "Fluent Practice Pro";
    return "Master Orator";
  }

  String get levelBadgeIcon {
    final l = level;
    if (l == 1) return "[L1]";
    if (l == 2) return "[L2]";
    if (l == 3) return "[L3]";
    if (l == 4) return "[L4]";
    return "[L5]";
  }

  Future<void> initProgress() async {
    await _loadSavedProgress();
    await _initLocalNotifications();
    syncLeaderboardStats();
  }

  Future<void> _loadSavedProgress() async {
    try {
      final savedXpStr = await DbHelper.instance.getSetting('user_xp');
      _totalXP = int.tryParse(savedXpStr ?? '0') ?? 0;

      final savedCoinsStr = await DbHelper.instance.getSetting('user_coins');
      _coins = int.tryParse(savedCoinsStr ?? '0') ?? 0;

      final savedFreezesStr = await DbHelper.instance.getSetting('streak_freezes_count');
      _streakFreezes = int.tryParse(savedFreezesStr ?? '0') ?? 0;

      final savedHintsStr = await DbHelper.instance.getSetting('extra_hints_count');
      _extraHints = int.tryParse(savedHintsStr ?? '0') ?? 0;

      final savedOptInStr = await DbHelper.instance.getSetting('leaderboard_opt_in');
      _leaderboardOptIn = savedOptInStr == null || savedOptInStr == 'true';

      final savedGoalStr = await DbHelper.instance.getSetting('daily_goal_xp');
      _dailyGoalXP = int.tryParse(savedGoalStr ?? '50') ?? 50;

      final savedNotifStr = await DbHelper.instance.getSetting('notifications_enabled');
      _notificationsEnabled = savedNotifStr == null || savedNotifStr == 'true';

      final logs = await DbHelper.instance.getActivityLogs();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      
      final Map<String, int> map = {};
      _todayXP = 0;

      for (var log in logs) {
        final d = log['date'] as String;
        final xp = log['xp_earned'] as int;
        map[d] = xp;

        if (d == todayStr) {
          _todayXP = xp;
        }
      }
      _activityHeatmap = map;

      // Calculate streak
      _calculateStreak(map);

      notifyListeners();
    } catch (e) {
      debugPrint("Error loading progress: $e");
    }
  }

  void _calculateStreak(Map<String, int> map) {
    final now = DateTime.now();
    int streak = 0;
    int freezesAvailable = _streakFreezes;

    for (int i = 0; i < 365; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final dateStr = checkDate.toIso8601String().substring(0, 10);

      if (map.containsKey(dateStr) && (map[dateStr] ?? 0) > 0) {
        streak++;
      } else {
        if (i == 0) {
          continue;
        }
        if (freezesAvailable > 0) {
          freezesAvailable--;
          streak++; // Protect 1 missed day
        } else {
          break;
        }
      }
    }
    _currentStreak = streak;
  }

  Future<void> addXP(int points) async {
    if (points <= 0) return;

    _totalXP += points;
    _todayXP += points;

    // Award ~1 coin per 10 XP
    final coinsEarned = (points / 10).round();
    final coinsToAdd = (coinsEarned == 0 && points > 0) ? 1 : coinsEarned;
    _coins += coinsToAdd;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    _activityHeatmap[todayStr] = (_activityHeatmap[todayStr] ?? 0) + points;

    _calculateStreak(_activityHeatmap);

    // Save to SQLite
    await DbHelper.instance.setSetting('user_xp', _totalXP.toString());
    await DbHelper.instance.setSetting('user_coins', _coins.toString());
    await DbHelper.instance.logDailyActivity(todayStr, points);

    notifyListeners();
    syncLeaderboardStats();

    // Trigger local reminder update
    if (_todayXP >= _dailyGoalXP) {
      await _cancelReminderNotification();
    }
  }

  Future<bool> redeemStreakFreeze() async {
    if (_coins < 50) return false;

    _coins -= 50;
    _streakFreezes += 1;
    await DbHelper.instance.setSetting('user_coins', _coins.toString());
    await DbHelper.instance.setSetting('streak_freezes_count', _streakFreezes.toString());
    await DbHelper.instance.insertCoinRedemption('Streak Freeze', 50);

    _calculateStreak(_activityHeatmap);
    notifyListeners();
    syncLeaderboardStats();
    return true;
  }

  Future<bool> redeemExtraHint() async {
    if (_coins < 10) return false;

    _coins -= 10;
    _extraHints += 1;
    await DbHelper.instance.setSetting('user_coins', _coins.toString());
    await DbHelper.instance.setSetting('extra_hints_count', _extraHints.toString());
    await DbHelper.instance.insertCoinRedemption('Extra Hint Token', 10);

    notifyListeners();
    syncLeaderboardStats();
    return true;
  }

  bool useExtraHintToken() {
    if (_extraHints > 0) {
      _extraHints--;
      DbHelper.instance.setSetting('extra_hints_count', _extraHints.toString());
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> canSkipMissionThisWeek() async {
    final lastSkipStr = await DbHelper.instance.getSetting('last_skip_mission_timestamp');
    if (lastSkipStr == null || lastSkipStr.isEmpty) return true;
    try {
      final lastSkip = DateTime.parse(lastSkipStr);
      final daysDiff = DateTime.now().difference(lastSkip).inDays;
      return daysDiff >= 7;
    } catch (_) {
      return true;
    }
  }

  Future<bool> redeemSkipMission() async {
    if (_coins < 100) return false;
    final allowed = await canSkipMissionThisWeek();
    if (!allowed) return false;

    _coins -= 100;
    await DbHelper.instance.setSetting('user_coins', _coins.toString());
    await DbHelper.instance.setSetting('last_skip_mission_timestamp', DateTime.now().toIso8601String());
    await DbHelper.instance.insertCoinRedemption("Skip Today's Mission", 100);

    // Bonus XP for completed mission
    _totalXP += 50;
    _todayXP += 50;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    _activityHeatmap[todayStr] = (_activityHeatmap[todayStr] ?? 0) + 50;
    _calculateStreak(_activityHeatmap);

    await DbHelper.instance.setSetting('user_xp', _totalXP.toString());
    await DbHelper.instance.logDailyActivity(todayStr, 50);

    notifyListeners();
    syncLeaderboardStats();
    return true;
  }

  Future<void> setDailyGoal(int goalXp) async {
    _dailyGoalXP = goalXp;
    await DbHelper.instance.setSetting('daily_goal_xp', goalXp.toString());
    notifyListeners();
  }

  Future<void> toggleNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    await DbHelper.instance.setSetting('notifications_enabled', enabled.toString());
    
    if (enabled) {
      await _scheduleDailyReminder();
    } else {
      await _cancelReminderNotification();
    }
    notifyListeners();
  }

  Future<void> toggleLeaderboardOptIn(bool optIn) async {
    _leaderboardOptIn = optIn;
    await DbHelper.instance.setSetting('leaderboard_opt_in', optIn.toString());
    notifyListeners();
    syncLeaderboardStats();
  }

  Future<void> syncLeaderboardStats() async {
    try {
      if (SupabaseService.instance.isInitialized && SupabaseService.instance.isLoggedIn) {
        final userId = SupabaseService.instance.currentUserId;
        if (userId != null && userId.isNotEmpty) {
          final profile = await LearnerProfileService.instance.computeProfile();
          final userName = profile.userName.isNotEmpty ? profile.userName : 'Learner';

          await SupabaseService.instance.client?.from('leaderboard_stats').upsert({
            'user_id': userId,
            'display_name': userName,
            'total_xp': _totalXP,
            'current_streak': _currentStreak,
            'coins': _coins,
            'is_public': _leaderboardOptIn,
            'updated_at': DateTime.now().toIso8601String(),
          });
          debugPrint("[ProgressProvider] Synced stats to Supabase leaderboard_stats for $userName");
        }
      }
    } catch (e) {
      debugPrint("[ProgressProvider] Notice: Error syncing leaderboard stats: $e");
    }
  }

  // Local Notifications Setup
  Future<void> _initLocalNotifications() async {
    try {
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );

      if (_notificationsEnabled && _todayXP < _dailyGoalXP) {
        await _scheduleDailyReminder();
      }
    } catch (e) {
      debugPrint("Error initializing notifications: $e");
    }
  }

  Future<void> _scheduleDailyReminder() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'fluentup_daily_reminder',
        'Daily Practice Reminders',
        channelDescription: 'Gentle reminder to meet your daily English practice goal',
        importance: Importance.high,
        priority: Priority.high,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      // Show notification if target daily goal not reached
      await _flutterLocalNotificationsPlugin.show(
        id: 888,
        title: "FluentUp Practice Waiting",
        body: "Your English practice is waiting - even 5 minutes counts today.",
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint("Error scheduling reminder: $e");
    }
  }

  Future<void> _cancelReminderNotification() async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id: 888);
    } catch (e) {
      debugPrint("Error cancelling reminder: $e");
    }
  }

  Future<void> resetProgress() async {
    try {
      await DbHelper.instance.clearAllActivityLogs();
      await DbHelper.instance.setSetting('user_xp', '0');
      await DbHelper.instance.setSetting('user_coins', '0');
      await DbHelper.instance.setSetting('streak_freezes_count', '0');
      await DbHelper.instance.setSetting('extra_hints_count', '0');
      _totalXP = 0;
      _coins = 0;
      _streakFreezes = 0;
      _extraHints = 0;
      _todayXP = 0;
      _currentStreak = 0;
      _activityHeatmap = {};
      notifyListeners();
      syncLeaderboardStats();
    } catch (e) {
      debugPrint("Error resetting progress: $e");
    }
  }
}

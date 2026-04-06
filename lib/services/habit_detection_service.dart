import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/user_activity_service.dart';

/// Service for analyzing user habits and triggering behavior-based notifications
class HabitDetectionService {
  static final HabitDetectionService _instance = HabitDetectionService._internal();
  factory HabitDetectionService() => _instance;
  HabitDetectionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final UserActivityService _activityService = UserActivityService();

  /// Analyze user habits and trigger appropriate notifications
  Future<void> analyzeAndNotify(String uid) async {
    try {
      // Get all relevant data
      final insights = await _activityService.getUsageInsights(uid);
      final taskStats = await _getTaskStats(uid);
      final moodStats = await _getMoodStats(uid);
      final settings = await _getUserNotificationSettings(uid);

      if (!settings.enabled) {
        debugPrint('[HabitDetection] Notifications disabled');
        return;
      }

      // Check for excessive usage pattern
      if (settings.riskAlerts && insights['usagePattern'] == 'heavy') {
        await _sendExcessiveUsageAlert(uid, insights);
      }

      // Check for skipped tasks
      if (settings.dailyReminders && taskStats['incompleteTodayCount'] > 0) {
        await _sendTaskReminder(uid, taskStats);
      }

      // Check for missed mood check-ins
      if (settings.moodCheckIns && moodStats['daysSinceLastMood'] > 1) {
        await _sendMoodCheckInPrompt(uid);
      }

      // Check for inactivity (no tasks completed in 3+ days)
      if (settings.encouragement && taskStats['daysSinceLastCompletion'] >= 3) {
        await _sendEncouragementNotification(uid);
      }

      // Check for streak milestones
      if (settings.milestones && taskStats['streak'] > 0 && taskStats['streak'] % 7 == 0) {
        await _sendStreakMilestone(uid, taskStats['streak'] as int);
      }

      debugPrint('[HabitDetection] Analysis complete for user $uid');
    } catch (e) {
      debugPrint('[HabitDetection] Error analyzing habits: $e');
    }
  }

  Future<Map<String, dynamic>> _getTaskStats(String uid) async {
    try {
      final tasksSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .get();

      final tasks = tasksSnapshot.docs;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int incompleteTodayCount = 0;
      int streak = 0;
      DateTime? lastCompletionDate;

      for (final doc in tasks) {
        final data = doc.data();
        final completed = data['completed'] as bool? ?? false;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate();

        // Count incomplete tasks created today
        if (createdAt != null && !completed) {
          final taskDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
          if (taskDay == today) {
            incompleteTodayCount++;
          }
        }

        // Track last completion
        if (completed && completedAt != null) {
          if (lastCompletionDate == null || completedAt.isAfter(lastCompletionDate)) {
            lastCompletionDate = completedAt;
          }
        }
      }

      // Calculate streak (simplified - actual calculation is in TaskProvider)
      if (lastCompletionDate != null) {
        final completionDay = DateTime(
          lastCompletionDate.year,
          lastCompletionDate.month,
          lastCompletionDate.day,
        );
        if (completionDay == today || completionDay == today.subtract(const Duration(days: 1))) {
          // User is active, get actual streak
          streak = await _calculateStreak(uid);
        }
      }

      final daysSinceLastCompletion = lastCompletionDate != null
          ? now.difference(lastCompletionDate).inDays
          : 999;

      return {
        'incompleteTodayCount': incompleteTodayCount,
        'daysSinceLastCompletion': daysSinceLastCompletion,
        'streak': streak,
        'lastCompletionDate': lastCompletionDate,
      };
    } catch (e) {
      debugPrint('[HabitDetection] Error getting task stats: $e');
      return {
        'incompleteTodayCount': 0,
        'daysSinceLastCompletion': 999,
        'streak': 0,
        'lastCompletionDate': null,
      };
    }
  }

  Future<int> _calculateStreak(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .where('completed', isEqualTo: true)
          .orderBy('completedAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      int streak = 0;
      DateTime currentDate = DateTime.now();

      for (final doc in snapshot.docs) {
        final completedAt = (doc.data()['completedAt'] as Timestamp?)?.toDate();
        if (completedAt == null) continue;

        final taskDate = DateTime(completedAt.year, completedAt.month, completedAt.day);
        final checkDate = DateTime(currentDate.year, currentDate.month, currentDate.day);

        if (taskDate == checkDate) {
          streak++;
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      debugPrint('[HabitDetection] Error calculating streak: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> _getMoodStats(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('moods')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return {'daysSinceLastMood': 999};
      }

      final lastMood = (snapshot.docs.first.data()['createdAt'] as Timestamp).toDate();
      final daysSince = DateTime.now().difference(lastMood).inDays;

      return {'daysSinceLastMood': daysSince};
    } catch (e) {
      debugPrint('[HabitDetection] Error getting mood stats: $e');
      return {'daysSinceLastMood': 999};
    }
  }

  Future<NotificationSettings> _getUserNotificationSettings(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('notifications')
          .get();

      if (!doc.exists) {
        return const NotificationSettings();
      }

      return NotificationSettings.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('[HabitDetection] Error getting settings: $e');
      return const NotificationSettings();
    }
  }

  Future<void> _sendExcessiveUsageAlert(String uid, Map<String, dynamic> insights) async {
    final avgMinutes = (insights['averageDuration'] as int) ~/ 60;
    
    final notification = NotificationModel(
      uid: uid,
      title: '⏰ Screen Time Alert',
      body: 'You\'ve been spending $avgMinutes minutes per session recently. Consider taking a break.',
      type: NotificationType.warning,
      priority: NotificationPriority.high,
      scheduledAt: DateTime.now(),
      createdAt: DateTime.now(),
      data: {'type': 'excessive_usage', 'avgMinutes': avgMinutes},
    );

    await _notificationService.showInstantNotification(notification);
    await _saveNotification(notification);
  }

  Future<void> _sendTaskReminder(String uid, Map<String, dynamic> taskStats) async {
    final count = taskStats['incompleteTodayCount'] as int;
    
    final notification = NotificationModel(
      uid: uid,
      title: '📋 Don\'t Forget Your Tasks',
      body: 'You have $count task${count > 1 ? 's' : ''} waiting for you today. Let\'s check them off!',
      type: NotificationType.reminder,
      priority: NotificationPriority.medium,
      scheduledAt: DateTime.now(),
      createdAt: DateTime.now(),
      data: {'type': 'task_reminder', 'count': count},
    );

    await _notificationService.showInstantNotification(notification);
    await _saveNotification(notification);
  }

  Future<void> _sendMoodCheckInPrompt(String uid) async {
    final notification = NotificationModel(
      uid: uid,
      title: '💭 How Are You Feeling?',
      body: 'It\'s been a while since your last check-in. Take a moment to track your mood.',
      type: NotificationType.checkIn,
      priority: NotificationPriority.medium,
      scheduledAt: DateTime.now(),
      createdAt: DateTime.now(),
      data: {'type': 'mood_checkin'},
    );

    await _notificationService.showInstantNotification(notification);
    await _saveNotification(notification);
  }

  Future<void> _sendEncouragementNotification(String uid) async {
    final encouragements = [
      'You\'ve got this! Every small step counts.',
      'Remember why you started. You\'re stronger than you think.',
      'One day at a time. You\'re making progress!',
      'Your journey matters. Keep going!',
      'Believe in yourself. You\'re capable of amazing things.',
    ];

    final message = (encouragements..shuffle()).first;

    final notification = NotificationModel(
      uid: uid,
      title: '💪 Stay Strong',
      body: message,
      type: NotificationType.encouragement,
      priority: NotificationPriority.low,
      scheduledAt: DateTime.now(),
      createdAt: DateTime.now(),
      data: {'type': 'encouragement'},
    );

    await _notificationService.showInstantNotification(notification);
    await _saveNotification(notification);
  }

  Future<void> _sendStreakMilestone(String uid, int streak) async {
    final notification = NotificationModel(
      uid: uid,
      title: '🎉 Streak Milestone!',
      body: 'Congratulations! You\'ve maintained a $streak-day streak. Keep up the amazing work!',
      type: NotificationType.milestone,
      priority: NotificationPriority.high,
      scheduledAt: DateTime.now(),
      createdAt: DateTime.now(),
      data: {'type': 'streak_milestone', 'streak': streak},
    );

    await _notificationService.showInstantNotification(notification);
    await _saveNotification(notification);
  }

  Future<void> _saveNotification(NotificationModel notification) async {
    try {
      await _firestore
          .collection('users')
          .doc(notification.uid)
          .collection('notifications')
          .add(notification.toMap());
    } catch (e) {
      debugPrint('[HabitDetection] Error saving notification: $e');
    }
  }
}

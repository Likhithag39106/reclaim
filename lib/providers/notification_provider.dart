import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/habit_detection_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final HabitDetectionService _habitService = HabitDetectionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  NotificationSettings _settings = const NotificationSettings();
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;

  NotificationSettings get settings => _settings;
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get unreadCount => _notifications.where((n) => !n.read).length;

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      await _notificationService.initialize();
      final granted = await _notificationService.requestPermissions();
      debugPrint('[NotificationProvider] Permissions granted: $granted');
    } catch (e) {
      _error = e.toString();
      debugPrint('[NotificationProvider] Initialize error: $e');
    }
  }

  /// Load notification settings for user
  Future<void> loadSettings(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('notifications')
          .get();

      if (doc.exists) {
        _settings = NotificationSettings.fromMap(doc.data()!);
      } else {
        _settings = const NotificationSettings();
        await saveSettings(uid, _settings);
      }

      notifyListeners();
      debugPrint('[NotificationProvider] Settings loaded');
    } catch (e) {
      _error = e.toString();
      debugPrint('[NotificationProvider] Load settings error: $e');
    }
  }

  /// Save notification settings
  Future<void> saveSettings(String uid, NotificationSettings settings) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('notifications')
          .set(settings.toMap());

      _settings = settings;
      
      // Reschedule daily reminders if enabled
      if (settings.enabled && settings.dailyReminders) {
        await _scheduleDailyReminder(settings);
      } else {
        await _notificationService.cancelAll();
      }

      notifyListeners();
      debugPrint('[NotificationProvider] Settings saved');
    } catch (e) {
      _error = e.toString();
      debugPrint('[NotificationProvider] Save settings error: $e');
    }
  }

  /// Load notifications for user
  Future<void> loadNotifications(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _notifications = snapshot.docs
          .map((doc) => NotificationModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      _isLoading = false;
      notifyListeners();
      debugPrint('[NotificationProvider] Loaded ${_notifications.length} notifications');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[NotificationProvider] Load notifications error: $e');
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String uid, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});

      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(read: true);
        notifyListeners();
      }

      debugPrint('[NotificationProvider] Marked as read: $notificationId');
    } catch (e) {
      _error = e.toString();
      debugPrint('[NotificationProvider] Mark as read error: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String uid) async {
    try {
      final batch = _firestore.batch();
      
      for (final notification in _notifications.where((n) => !n.read)) {
        if (notification.id != null) {
          final docRef = _firestore
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .doc(notification.id);
          batch.update(docRef, {'read': true});
        }
      }

      await batch.commit();

      _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
      notifyListeners();

      debugPrint('[NotificationProvider] Marked all as read');
    } catch (e) {
      _error = e.toString();
      debugPrint('[NotificationProvider] Mark all as read error: $e');
    }
  }

  /// Run habit analysis and send notifications
  Future<void> runHabitAnalysis(String uid) async {
    try {
      await _habitService.analyzeAndNotify(uid);
      await loadNotifications(uid);
      debugPrint('[NotificationProvider] Habit analysis complete');
    } catch (e) {
      _error = e.toString();
      debugPrint('[NotificationProvider] Habit analysis error: $e');
    }
  }

  /// Schedule daily reminder based on settings
  Future<void> _scheduleDailyReminder(NotificationSettings settings) async {
    try {
      final timeParts = settings.reminderTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      await _notificationService.scheduleDailyNotification(
        id: 1, // Fixed ID for daily reminder
        title: '📋 Daily Task Reminder',
        body: 'Don\'t forget to complete your tasks today!',
        hour: hour,
        minute: minute,
      );

      debugPrint('[NotificationProvider] Daily reminder scheduled for $hour:$minute');
    } catch (e) {
      debugPrint('[NotificationProvider] Schedule daily reminder error: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

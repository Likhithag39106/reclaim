import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
  debugPrint('[FCM] Title: ${message.notification?.title}');
  debugPrint('[FCM] Body: ${message.notification?.body}');
  debugPrint('[FCM] Data: ${message.data}');
}

/// Firebase Cloud Messaging service for push notifications
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      // Request permission (iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[FCM] User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('[FCM] User granted provisional permission');
      } else {
        debugPrint('[FCM] User declined or has not accepted permission');
        return;
      }

      // Get FCM token
      _fcmToken = await _messaging.getToken();
      debugPrint('[FCM] Token: $_fcmToken');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[FCM] Token refreshed: $newToken');
      });

      // Configure foreground notification presentation (iOS)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Setup message handlers
      _setupMessageHandlers();

      debugPrint('[FCM] Initialized successfully');
    } catch (e) {
      debugPrint('[FCM] Initialization error: $e');
    }
  }

  /// Save FCM token to Firestore for user
  Future<void> saveTokenToFirestore(String uid) async {
    if (_fcmToken == null) {
      debugPrint('[FCM] No token available to save');
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
        'fcmToken': _fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FCM] Token saved to Firestore');
    } catch (e) {
      debugPrint('[FCM] Error saving token: $e');
    }
  }

  /// Remove FCM token from Firestore (on logout)
  Future<void> removeTokenFromFirestore(String uid) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
      debugPrint('[FCM] Token removed from Firestore');
    } catch (e) {
      debugPrint('[FCM] Error removing token: $e');
    }
  }

  /// Setup message handlers for different states
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background messages (app in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle initial message (app opened from terminated state)
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleInitialMessage(message);
      }
    });
  }

  /// Handle foreground messages (app is active)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message: ${message.messageId}');
    
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      // Show local notification
      final notificationModel = NotificationModel(
        uid: data['uid'] ?? '',
        title: notification.title ?? 'Reclaim',
        body: notification.body ?? '',
        type: _parseNotificationType(data['type']),
        priority: _parseNotificationPriority(data['priority']),
        scheduledAt: DateTime.now(),
        createdAt: DateTime.now(),
        data: data,
      );

      await _notificationService.showInstantNotification(notificationModel);
    }

    // Save to Firestore
    if (data['uid'] != null) {
      await _saveNotificationToFirestore(data['uid'], message);
    }
  }

  /// Handle message when app is opened from background
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    debugPrint('[FCM] Message opened app: ${message.messageId}');
    
    final data = message.data;
    
    // Navigate to appropriate screen based on notification type
    if (data['type'] != null) {
      _navigateBasedOnType(data['type'], data);
    }
  }

  /// Handle initial message (app opened from terminated state)
  Future<void> _handleInitialMessage(RemoteMessage message) async {
    debugPrint('[FCM] Initial message: ${message.messageId}');
    
    final data = message.data;
    
    // Navigate to appropriate screen
    if (data['type'] != null) {
      _navigateBasedOnType(data['type'], data);
    }
  }

  /// Save notification to Firestore
  Future<void> _saveNotificationToFirestore(String uid, RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': notification.title,
        'body': notification.body,
        'type': message.data['type'] ?? 'reminder',
        'priority': message.data['priority'] ?? 'medium',
        'data': message.data,
        'read': false,
        'sentAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FCM] Error saving notification: $e');
    }
  }

  /// Parse notification type from string
  NotificationType _parseNotificationType(String? type) {
    if (type == null) return NotificationType.reminder;
    return NotificationType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => NotificationType.reminder,
    );
  }

  /// Parse notification priority from string
  NotificationPriority _parseNotificationPriority(String? priority) {
    if (priority == null) return NotificationPriority.medium;
    return NotificationPriority.values.firstWhere(
      (e) => e.name == priority,
      orElse: () => NotificationPriority.medium,
    );
  }

  /// Navigate based on notification type
  void _navigateBasedOnType(String type, Map<String, dynamic> data) {
    debugPrint('[FCM] Navigate to: $type');
    // Navigation logic will be implemented with proper context
    // This is a placeholder for the navigation handler
    switch (type) {
      case 'reminder':
        debugPrint('[FCM] Navigate to tasks');
        break;
      case 'encouragement':
        debugPrint('[FCM] Navigate to dashboard');
        break;
      case 'checkIn':
        debugPrint('[FCM] Navigate to mood tracker');
        break;
      case 'milestone':
        debugPrint('[FCM] Navigate to analytics');
        break;
      case 'warning':
        debugPrint('[FCM] Navigate to recovery plan');
        break;
      default:
        debugPrint('[FCM] Navigate to dashboard');
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('[FCM] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('[FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Error unsubscribing from topic: $e');
    }
  }

  /// Delete FCM token
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;
      debugPrint('[FCM] Token deleted');
    } catch (e) {
      debugPrint('[FCM] Error deleting token: $e');
    }
  }
}

/// Sample FCM payload structures for backend
class FCMPayloadExamples {
  /// Task Reminder Notification
  static const taskReminder = {
    "to": "<FCM_TOKEN>",
    "notification": {
      "title": "📋 Task Reminder",
      "body": "Don't forget to complete your daily tasks!",
      "sound": "default"
    },
    "data": {
      "uid": "<USER_ID>",
      "type": "reminder",
      "priority": "medium",
      "screen": "tasks"
    },
    "android": {
      "priority": "high",
      "notification": {
        "channel_id": "task_reminders",
        "color": "#4CAF50"
      }
    },
    "apns": {
      "payload": {
        "aps": {
          "sound": "default",
          "badge": 1
        }
      }
    }
  };

  /// Excessive Usage Warning
  static const excessiveUsageWarning = {
    "to": "<FCM_TOKEN>",
    "notification": {
      "title": "⏰ Screen Time Alert",
      "body": "You've been using the app for 45 minutes. Consider taking a break.",
      "sound": "default"
    },
    "data": {
      "uid": "<USER_ID>",
      "type": "warning",
      "priority": "high",
      "screen": "recovery_plan",
      "avgMinutes": "45"
    },
    "android": {
      "priority": "high",
      "notification": {
        "channel_id": "usage_warnings",
        "color": "#FF9800"
      }
    }
  };

  /// Milestone Achievement
  static const milestoneAchievement = {
    "to": "<FCM_TOKEN>",
    "notification": {
      "title": "🎉 Milestone Achieved!",
      "body": "Congratulations! You've completed 7 days of recovery!",
      "sound": "default"
    },
    "data": {
      "uid": "<USER_ID>",
      "type": "milestone",
      "priority": "high",
      "screen": "analytics",
      "days": "7"
    },
    "android": {
      "priority": "high",
      "notification": {
        "channel_id": "milestones",
        "color": "#9C27B0"
      }
    }
  };

  /// Mood Check-in Prompt
  static const moodCheckIn = {
    "to": "<FCM_TOKEN>",
    "notification": {
      "title": "💭 How Are You Feeling?",
      "body": "Take a moment to track your mood today.",
      "sound": "default"
    },
    "data": {
      "uid": "<USER_ID>",
      "type": "checkIn",
      "priority": "medium",
      "screen": "mood_tracker"
    }
  };

  /// Encouragement Message
  static const encouragement = {
    "to": "<FCM_TOKEN>",
    "notification": {
      "title": "💪 You've Got This!",
      "body": "Remember why you started. Every small step counts.",
      "sound": "default"
    },
    "data": {
      "uid": "<USER_ID>",
      "type": "encouragement",
      "priority": "low",
      "screen": "dashboard"
    }
  };
}

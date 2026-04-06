import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  reminder,          // Daily task reminder
  encouragement,     // Positive reinforcement
  checkIn,          // Mood check-in prompt
  milestone,        // Achievement unlocked
  warning,          // Excessive app usage detected
  recovery,         // Relapse risk alert
  streak,           // Streak milestones
}

enum NotificationPriority {
  low,
  medium,
  high,
  critical,
}

class NotificationModel {
  final String? id;
  final String uid;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationPriority priority;
  final Map<String, dynamic>? data;
  final DateTime scheduledAt;
  final DateTime? sentAt;
  final bool read;
  final DateTime createdAt;

  const NotificationModel({
    this.id,
    required this.uid,
    required this.title,
    required this.body,
    required this.type,
    this.priority = NotificationPriority.medium,
    this.data,
    required this.scheduledAt,
    this.sentAt,
    this.read = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String?,
      uid: map['uid'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.reminder,
      ),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => NotificationPriority.medium,
      ),
      data: map['data'] as Map<String, dynamic>?,
      scheduledAt: (map['scheduledAt'] as Timestamp).toDate(),
      sentAt: map['sentAt'] != null ? (map['sentAt'] as Timestamp).toDate() : null,
      read: map['read'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'uid': uid,
      'title': title,
      'body': body,
      'type': type.name,
      'priority': priority.name,
      if (data != null) 'data': data,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      if (sentAt != null) 'sentAt': Timestamp.fromDate(sentAt!),
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? uid,
    String? title,
    String? body,
    NotificationType? type,
    NotificationPriority? priority,
    Map<String, dynamic>? data,
    DateTime? scheduledAt,
    DateTime? sentAt,
    bool? read,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      data: data ?? this.data,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      sentAt: sentAt ?? this.sentAt,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NotificationSettings {
  final bool enabled;
  final bool dailyReminders;
  final bool moodCheckIns;
  final bool milestones;
  final bool encouragement;
  final bool riskAlerts;
  final String reminderTime; // Format: "HH:mm"
  final List<int> reminderDays; // 1-7 for Mon-Sun
  final bool doNotDisturbEnabled;
  final String? doNotDisturbStart; // Format: "HH:mm"
  final String? doNotDisturbEnd; // Format: "HH:mm"

  const NotificationSettings({
    this.enabled = true,
    this.dailyReminders = true,
    this.moodCheckIns = true,
    this.milestones = true,
    this.encouragement = true,
    this.riskAlerts = true,
    this.reminderTime = "09:00",
    this.reminderDays = const [1, 2, 3, 4, 5, 6, 7],
    this.doNotDisturbEnabled = false,
    this.doNotDisturbStart,
    this.doNotDisturbEnd,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      enabled: map['enabled'] as bool? ?? true,
      dailyReminders: map['dailyReminders'] as bool? ?? true,
      moodCheckIns: map['moodCheckIns'] as bool? ?? true,
      milestones: map['milestones'] as bool? ?? true,
      encouragement: map['encouragement'] as bool? ?? true,
      riskAlerts: map['riskAlerts'] as bool? ?? true,
      reminderTime: map['reminderTime'] as String? ?? "09:00",
      reminderDays: (map['reminderDays'] as List<dynamic>?)?.cast<int>() ?? [1, 2, 3, 4, 5, 6, 7],
      doNotDisturbEnabled: map['doNotDisturbEnabled'] as bool? ?? false,
      doNotDisturbStart: map['doNotDisturbStart'] as String?,
      doNotDisturbEnd: map['doNotDisturbEnd'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'dailyReminders': dailyReminders,
      'moodCheckIns': moodCheckIns,
      'milestones': milestones,
      'encouragement': encouragement,
      'riskAlerts': riskAlerts,
      'reminderTime': reminderTime,
      'reminderDays': reminderDays,
      'doNotDisturbEnabled': doNotDisturbEnabled,
      if (doNotDisturbStart != null) 'doNotDisturbStart': doNotDisturbStart,
      if (doNotDisturbEnd != null) 'doNotDisturbEnd': doNotDisturbEnd,
    };
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? dailyReminders,
    bool? moodCheckIns,
    bool? milestones,
    bool? encouragement,
    bool? riskAlerts,
    String? reminderTime,
    List<int>? reminderDays,
    bool? doNotDisturbEnabled,
    String? doNotDisturbStart,
    String? doNotDisturbEnd,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      dailyReminders: dailyReminders ?? this.dailyReminders,
      moodCheckIns: moodCheckIns ?? this.moodCheckIns,
      milestones: milestones ?? this.milestones,
      encouragement: encouragement ?? this.encouragement,
      riskAlerts: riskAlerts ?? this.riskAlerts,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderDays: reminderDays ?? this.reminderDays,
      doNotDisturbEnabled: doNotDisturbEnabled ?? this.doNotDisturbEnabled,
      doNotDisturbStart: doNotDisturbStart ?? this.doNotDisturbStart,
      doNotDisturbEnd: doNotDisturbEnd ?? this.doNotDisturbEnd,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum RecoveryPlanStatus {
  active,
  paused,
  completed,
  abandoned,
}

enum SeverityLevel {
  low,      // Occasional issues, easy to control
  medium,   // Regular patterns, needs attention
  high,     // Severe addiction, urgent intervention
}

class RecoveryGoal {
  final String id;
  final String description;
  final bool completed;
  final DateTime? completedAt;
  final int points;

  const RecoveryGoal({
    required this.id,
    required this.description,
    this.completed = false,
    this.completedAt,
    this.points = 10,
  });

  factory RecoveryGoal.fromMap(Map<String, dynamic> map) {
    return RecoveryGoal(
      id: map['id'] as String,
      description: map['description'] as String,
      completed: map['completed'] as bool? ?? false,
      completedAt: map['completedAt'] != null 
          ? (map['completedAt'] as Timestamp).toDate() 
          : null,
      points: map['points'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'completed': completed,
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      'points': points,
    };
  }

  RecoveryGoal copyWith({
    String? id,
    String? description,
    bool? completed,
    DateTime? completedAt,
    int? points,
  }) {
    return RecoveryGoal(
      id: id ?? this.id,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      points: points ?? this.points,
    );
  }
}

class RecoveryMilestone {
  final String id;
  final String title;
  final String description;
  final int targetDays;
  final bool achieved;
  final DateTime? achievedAt;
  final int rewardPoints;

  const RecoveryMilestone({
    required this.id,
    required this.title,
    required this.description,
    required this.targetDays,
    this.achieved = false,
    this.achievedAt,
    this.rewardPoints = 100,
  });

  factory RecoveryMilestone.fromMap(Map<String, dynamic> map) {
    return RecoveryMilestone(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      targetDays: map['targetDays'] as int,
      achieved: map['achieved'] as bool? ?? false,
      achievedAt: map['achievedAt'] != null 
          ? (map['achievedAt'] as Timestamp).toDate() 
          : null,
      rewardPoints: map['rewardPoints'] as int? ?? 100,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetDays': targetDays,
      'achieved': achieved,
      if (achievedAt != null) 'achievedAt': Timestamp.fromDate(achievedAt!),
      'rewardPoints': rewardPoints,
    };
  }

  RecoveryMilestone copyWith({
    String? id,
    String? title,
    String? description,
    int? targetDays,
    bool? achieved,
    DateTime? achievedAt,
    int? rewardPoints,
  }) {
    return RecoveryMilestone(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetDays: targetDays ?? this.targetDays,
      achieved: achieved ?? this.achieved,
      achievedAt: achievedAt ?? this.achievedAt,
      rewardPoints: rewardPoints ?? this.rewardPoints,
    );
  }
}

class AlternativeActivity {
  final String id;
  final String title;
  final String description;
  final int durationMinutes;
  final List<String> categories; // e.g., ["physical", "mental", "social"]

  const AlternativeActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    this.categories = const [],
  });

  factory AlternativeActivity.fromMap(Map<String, dynamic> map) {
    return AlternativeActivity(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      durationMinutes: map['durationMinutes'] as int,
      categories: (map['categories'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'durationMinutes': durationMinutes,
      'categories': categories,
    };
  }
}

class RecoveryPlanModel {
  final String? id;
  final String uid;
  final String addiction; // Type of addiction being addressed
  final String title;
  final String description;
  final SeverityLevel severity;
  final RecoveryPlanStatus status;
  
  // Goals and milestones
  final List<RecoveryGoal> dailyGoals;
  final List<RecoveryMilestone> milestones;
  final List<AlternativeActivity> alternativeActivities;
  
  // Progress tracking
  final int currentDay;
  final int totalPoints;
  final int relapseCount;
  final DateTime? lastRelapseDate;
  
  // Time restrictions
  final Map<String, dynamic>? timeRestrictions; // e.g., {"maxDailyMinutes": 30}
  
  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final DateTime? lastAdaptedAt;

  const RecoveryPlanModel({
    this.id,
    required this.uid,
    required this.addiction,
    required this.title,
    required this.description,
    this.severity = SeverityLevel.medium,
    this.status = RecoveryPlanStatus.active,
    this.dailyGoals = const [],
    this.milestones = const [],
    this.alternativeActivities = const [],
    this.currentDay = 1,
    this.totalPoints = 0,
    this.relapseCount = 0,
    this.lastRelapseDate,
    this.timeRestrictions,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.lastAdaptedAt,
  });

  factory RecoveryPlanModel.fromMap(Map<String, dynamic> map) {
    return RecoveryPlanModel(
      id: map['id'] as String?,
      uid: map['uid'] as String,
      addiction: map['addiction'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      severity: SeverityLevel.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => SeverityLevel.medium,
      ),
      status: RecoveryPlanStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RecoveryPlanStatus.active,
      ),
      dailyGoals: (map['dailyGoals'] as List<dynamic>?)
          ?.map((e) => RecoveryGoal.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      milestones: (map['milestones'] as List<dynamic>?)
          ?.map((e) => RecoveryMilestone.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      alternativeActivities: (map['alternativeActivities'] as List<dynamic>?)
          ?.map((e) => AlternativeActivity.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      currentDay: map['currentDay'] as int? ?? 1,
      totalPoints: map['totalPoints'] as int? ?? 0,
      relapseCount: map['relapseCount'] as int? ?? 0,
      lastRelapseDate: map['lastRelapseDate'] != null
          ? (map['lastRelapseDate'] as Timestamp).toDate()
          : null,
      timeRestrictions: map['timeRestrictions'] as Map<String, dynamic>?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      lastAdaptedAt: map['lastAdaptedAt'] != null
          ? (map['lastAdaptedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'uid': uid,
      'addiction': addiction,
      'title': title,
      'description': description,
      'severity': severity.name,
      'status': status.name,
      'dailyGoals': dailyGoals.map((g) => g.toMap()).toList(),
      'milestones': milestones.map((m) => m.toMap()).toList(),
      'alternativeActivities': alternativeActivities.map((a) => a.toMap()).toList(),
      'currentDay': currentDay,
      'totalPoints': totalPoints,
      'relapseCount': relapseCount,
      if (lastRelapseDate != null) 
        'lastRelapseDate': Timestamp.fromDate(lastRelapseDate!),
      if (timeRestrictions != null) 'timeRestrictions': timeRestrictions,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (lastAdaptedAt != null) 'lastAdaptedAt': Timestamp.fromDate(lastAdaptedAt!),
    };
  }

  RecoveryPlanModel copyWith({
    String? id,
    String? uid,
    String? addiction,
    String? title,
    String? description,
    SeverityLevel? severity,
    RecoveryPlanStatus? status,
    List<RecoveryGoal>? dailyGoals,
    List<RecoveryMilestone>? milestones,
    List<AlternativeActivity>? alternativeActivities,
    int? currentDay,
    int? totalPoints,
    int? relapseCount,
    DateTime? lastRelapseDate,
    Map<String, dynamic>? timeRestrictions,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? lastAdaptedAt,
  }) {
    return RecoveryPlanModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      addiction: addiction ?? this.addiction,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      dailyGoals: dailyGoals ?? this.dailyGoals,
      milestones: milestones ?? this.milestones,
      alternativeActivities: alternativeActivities ?? this.alternativeActivities,
      currentDay: currentDay ?? this.currentDay,
      totalPoints: totalPoints ?? this.totalPoints,
      relapseCount: relapseCount ?? this.relapseCount,
      lastRelapseDate: lastRelapseDate ?? this.lastRelapseDate,
      timeRestrictions: timeRestrictions ?? this.timeRestrictions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      lastAdaptedAt: lastAdaptedAt ?? this.lastAdaptedAt,
    );
  }

  // Calculate completion percentage
  double get completionPercentage {
    if (dailyGoals.isEmpty) return 0.0;
    final completed = dailyGoals.where((g) => g.completed).length;
    return (completed / dailyGoals.length) * 100;
  }

  // Check if plan needs adaptation
  bool get needsAdaptation {
    if (lastAdaptedAt == null) return currentDay >= 7;
    final daysSinceAdaptation = DateTime.now().difference(lastAdaptedAt!).inDays;
    return daysSinceAdaptation >= 7 || relapseCount >= 2;
  }

  // Get next milestone
  RecoveryMilestone? get nextMilestone {
    final unachieved = milestones.where((m) => !m.achieved).toList();
    if (unachieved.isEmpty) return null;
    unachieved.sort((a, b) => a.targetDays.compareTo(b.targetDays));
    return unachieved.first;
  }
}
class AnalyticsModel {
  final String uid;
  final int totalTasksCompleted;
  final int currentStreak; // consecutive days
  final double moodAverage; // 1-10
  final Map<String, int> tasksCompletedByAddiction; // addiction -> count
  final double screenTimeReduction; // percentage
  final DateTime lastUpdated;

  AnalyticsModel({
    required this.uid,
    required this.totalTasksCompleted,
    required this.currentStreak,
    required this.moodAverage,
    required this.tasksCompletedByAddiction,
    required this.screenTimeReduction,
    required this.lastUpdated,
  });

  factory AnalyticsModel.fromFirestore(Map<String, dynamic> data) {
    return AnalyticsModel(
      uid: data['uid'] ?? '',
      totalTasksCompleted: data['totalTasksCompleted'] ?? 0,
      currentStreak: data['currentStreak'] ?? 0,
      moodAverage: (data['moodAverage'] ?? 5.0).toDouble(),
      tasksCompletedByAddiction: Map<String, int>.from(
        data['tasksCompletedByAddiction'] ?? {},
      ),
      screenTimeReduction: (data['screenTimeReduction'] ?? 0.0).toDouble(),
      lastUpdated: (data['lastUpdated'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'totalTasksCompleted': totalTasksCompleted,
      'currentStreak': currentStreak,
      'moodAverage': moodAverage,
      'tasksCompletedByAddiction': tasksCompletedByAddiction,
      'screenTimeReduction': screenTimeReduction,
      'lastUpdated': lastUpdated,
    };
  }
}
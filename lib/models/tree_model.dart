class TreeModel {
  final String uid;
  final int growthLevel; // 0-100 (each completed task adds points)
  final int totalGrowthPoints;
  final DateTime createdAt;
  final DateTime? lastUpdated;

  TreeModel({
    required this.uid,
    required this.growthLevel,
    required this.totalGrowthPoints,
    required this.createdAt,
    this.lastUpdated,
  });

  factory TreeModel.fromFirestore(Map<String, dynamic> data) {
    return TreeModel(
      uid: data['uid'] ?? '',
      growthLevel: data['growthLevel'] ?? 0,
      totalGrowthPoints: data['totalGrowthPoints'] ?? 0,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      lastUpdated: (data['lastUpdated'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'growthLevel': growthLevel,
      'totalGrowthPoints': totalGrowthPoints,
      'createdAt': createdAt,
      'lastUpdated': lastUpdated ?? DateTime.now(),
    };
  }
}
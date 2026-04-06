enum RiskLevel { low, medium, high }

class RelapseRiskModel {
  final String id;
  final String uid;
  final RiskLevel riskLevel;
  final double riskScore; // 0-100
  final String reason; // explanation
  final DateTime calculatedAt;
  final Map<String, dynamic> factors; // mood, missedTasks, screenTime, etc.

  RelapseRiskModel({
    required this.id,
    required this.uid,
    required this.riskLevel,
    required this.riskScore,
    required this.reason,
    required this.calculatedAt,
    required this.factors,
  });

  factory RelapseRiskModel.fromFirestore(
    Map<String, dynamic> data,
    String docId,
  ) {
    return RelapseRiskModel(
      id: docId,
      uid: data['uid'] ?? '',
      riskLevel: RiskLevel.values.byName(data['riskLevel'] ?? 'low'),
      riskScore: (data['riskScore'] ?? 0.0).toDouble(),
      reason: data['reason'] ?? '',
      calculatedAt:
          (data['calculatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      factors: Map<String, dynamic>.from(data['factors'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'riskLevel': riskLevel.name,
      'riskScore': riskScore,
      'reason': reason,
      'calculatedAt': calculatedAt,
      'factors': factors,
    };
  }
}
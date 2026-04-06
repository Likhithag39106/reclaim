import '../models/relapse_risk_model.dart';
import '../models/mood_model.dart';

class MLRelapseService {
  // Mock ML model to predict relapse risk based on user data
  Future<RelapseRiskModel> predictRelapseRisk({
    required String uid,
    required List<MoodModel> recentMoods,
    required int missedTasks,
    required double avgScreenTime,
  }) async {
    // Simulate model inference delay
    await Future.delayed(const Duration(milliseconds: 1000));

    final riskScore = _calculateRiskScore(
      recentMoods: recentMoods,
      missedTasks: missedTasks,
      avgScreenTime: avgScreenTime,
    );

    final riskLevel = _determinRiskLevel(riskScore);
    final reason = _generateReason(riskScore, recentMoods, missedTasks);

    return RelapseRiskModel(
      id: '', // Firestore will generate
      uid: uid,
      riskLevel: riskLevel,
      riskScore: riskScore,
      reason: reason,
      calculatedAt: DateTime.now(),
      factors: {
        'avgMood': recentMoods.isNotEmpty
            ? recentMoods.fold<double>(0, (sum, m) => sum + m.rating) /
                recentMoods.length
            : 5.0,
        'missedTasks': missedTasks,
        'avgScreenTime': avgScreenTime,
      },
    );
  }

  double _calculateRiskScore({
    required List<MoodModel> recentMoods,
    required int missedTasks,
    required double avgScreenTime,
  }) {
    double score = 0;

    // Mood factor (higher negative mood = higher risk)
    if (recentMoods.isNotEmpty) {
      final avgMood = recentMoods.fold<double>(0, (sum, m) => sum + m.rating) /
          recentMoods.length;
      score += (10 - avgMood) * 5; // Low mood increases risk
    }

    // Missed tasks factor
    score += missedTasks * 3;

    // Screen time factor
    score += avgScreenTime * 2;

    return score.clamp(0, 100);
  }

  RiskLevel _determinRiskLevel(double score) {
    if (score < 30) return RiskLevel.low;
    if (score < 70) return RiskLevel.medium;
    return RiskLevel.high;
  }

  String _generateReason(
    double score,
    List<MoodModel> moods,
    int missedTasks,
  ) {
    final buffer = StringBuffer();

    if (score >= 70) {
      buffer.write(
        'High risk detected. ',
      );
    } else if (score >= 30) {
      buffer.write(
        'Moderate risk detected. ',
      );
    } else {
      buffer.write(
        'Low risk. You\'re doing well. ',
      );
    }

    if (moods.isNotEmpty) {
      final avgMood =
          moods.fold<double>(0, (sum, m) => sum + m.rating) / moods.length;
      if (avgMood < 5) {
        buffer.write('Recent mood has been low. ');
      }
    }

    if (missedTasks > 2) {
      buffer.write('Several missed tasks. ');
    }

    buffer.write('Consider reaching out for support.');

    return buffer.toString();
  }
}
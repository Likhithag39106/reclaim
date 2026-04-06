import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/mood_model.dart';

/// ML-based relapse risk predictor using TensorFlow Lite
class MLRelapsePredictor {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  // static const int _inputSize = 10; // Number of features
  static const String _modelPath = 'assets/models/relapse_predictor.tflite';

  /// Initialize the TFLite interpreter
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _isInitialized = true;
      debugPrint('[MLRelapsePredictor] Model loaded successfully');
      debugPrint('[MLRelapsePredictor] Input tensors: ${_interpreter?.getInputTensors()}');
      debugPrint('[MLRelapsePredictor] Output tensors: ${_interpreter?.getOutputTensors()}');
    } catch (e) {
      debugPrint('[MLRelapsePredictor] Failed to load model: $e');
      debugPrint('[MLRelapsePredictor] Falling back to rule-based prediction');
      _isInitialized = false;
    }
  }

  /// Predict relapse risk (0.0 to 1.0)
  /// Returns probability of relapse in next 7 days
  Future<double> predictRelapseRisk({
    required UserModel user,
    required List<TaskModel> recentTasks,
    required List<MoodModel> recentMoods,
    required Map<String, dynamic> activityData,
  }) async {
    if (!_isInitialized || _interpreter == null) {
      // Fallback to rule-based prediction
      return _ruleBasedPrediction(user, recentTasks, recentMoods, activityData);
    }

    try {
      // Extract features
      final features = _extractFeatures(
        user: user,
        recentTasks: recentTasks,
        recentMoods: recentMoods,
        activityData: activityData,
      );

      // Prepare input tensor [1, 10]
      final input = Float32List.fromList(features);
      final inputBuffer = [input];

      // Prepare output tensor [1, 1]
      final output = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _interpreter!.run(inputBuffer, output);

      final riskScore = (output[0][0] as double).clamp(0.0, 1.0);
      debugPrint('[MLRelapsePredictor] ML Risk score: ${(riskScore * 100).toStringAsFixed(1)}%');
      debugPrint('[MLRelapsePredictor] Input features: ${features.map((f) => f.toStringAsFixed(2)).join(", ")}');

      return riskScore;
    } catch (e) {
      debugPrint('[MLRelapsePredictor] Prediction error: $e');
      return _ruleBasedPrediction(user, recentTasks, recentMoods, activityData);
    }
  }

  /// Extract 10 features for ML model
  List<double> _extractFeatures({
    required UserModel user,
    required List<TaskModel> recentTasks,
    required List<MoodModel> recentMoods,
    required Map<String, dynamic> activityData,
  }) {
    final features = <double>[];

    // Feature 1: Task completion rate (last 7 days)
    final completedTasks = recentTasks.where((t) => t.completed).length;
    final completionRate = recentTasks.isEmpty ? 0.5 : completedTasks / recentTasks.length;
    features.add(completionRate);

    // Feature 2: Average mood score (last 7 days, normalized 0-1)
    final avgMood = recentMoods.isEmpty
        ? 0.6
        : recentMoods.map((m) => m.rating).reduce((a, b) => a + b) / recentMoods.length / 5.0;
    features.add(avgMood);

    // Feature 3: Days since last relapse (normalized)
    const daysSinceRelapse = 30.0; // Default if no relapse data
    features.add((daysSinceRelapse / 365.0).clamp(0.0, 1.0));

    // Feature 4: Current streak (normalized, max 90 days)
    final streak = recentTasks.where((t) => t.completed).length.toDouble();
    features.add((streak / 30.0).clamp(0.0, 1.0));

    // Feature 5: Average daily sessions (normalized, max 20)
    final avgSessions = (activityData['avgDailySessions'] as double? ?? 5.0);
    features.add((avgSessions / 20.0).clamp(0.0, 1.0));

    // Feature 6: Average session duration (normalized, max 60 min)
    final avgDuration = (activityData['avgSessionDuration'] as double? ?? 20.0);
    features.add((avgDuration / 60.0).clamp(0.0, 1.0));

    // Feature 7: Days inactive (last 7 days)
    final daysInactive = activityData['daysInactive'] as int? ?? 0;
    features.add((daysInactive / 7.0).clamp(0.0, 1.0));

    // Feature 8: Mood variance (stability indicator, 0 = stable, 1 = volatile)
    final moodVariance = _calculateMoodVariance(recentMoods);
    features.add(moodVariance);

    // Feature 9: Weekend vs weekday usage ratio
    final weekendRatio = activityData['weekendRatio'] as double? ?? 1.0;
    features.add((weekendRatio - 1.0).abs().clamp(0.0, 1.0));

    // Feature 10: Time of day pattern irregularity (0 = regular, 1 = irregular)
    final timeIrregularity = activityData['timeIrregularity'] as double? ?? 0.3;
    features.add(timeIrregularity.clamp(0.0, 1.0));

    return features;
  }

  /// Calculate mood variance as a stability indicator
  double _calculateMoodVariance(List<MoodModel> moods) {
    if (moods.length < 2) return 0.0;

    final ratings = moods.map((m) => m.rating.toDouble()).toList();
    final mean = ratings.reduce((a, b) => a + b) / ratings.length;
    final variance = ratings
        .map((r) => (r - mean) * (r - mean))
        .reduce((a, b) => a + b) / ratings.length;
    
    // Normalize variance (max theoretical variance for 1-5 scale is 4.0)
    return (variance / 4.0).clamp(0.0, 1.0);
  }

  /// Fallback rule-based prediction when ML model unavailable
  double _ruleBasedPrediction(
    UserModel user,
    List<TaskModel> recentTasks,
    List<MoodModel> recentMoods,
    Map<String, dynamic> activityData,
  ) {
    debugPrint('[MLRelapsePredictor] Using rule-based prediction (ML model unavailable)');
    double riskScore = 0.0;

    // Factor 1: Task completion (40% weight)
    final completedTasks = recentTasks.where((t) => t.completed).length;
    final completionRate = recentTasks.isEmpty ? 0.5 : completedTasks / recentTasks.length;
    riskScore += (1.0 - completionRate) * 0.4;

    // Factor 2: Mood trend (30% weight)
    final avgMood = recentMoods.isEmpty
        ? 3.0
        : recentMoods.map((m) => m.rating).reduce((a, b) => a + b) / recentMoods.length;
    riskScore += (1.0 - avgMood / 5.0) * 0.3;

    // Factor 3: Usage patterns (30% weight)
    final avgSessions = activityData['avgDailySessions'] as double? ?? 0.0;
    if (avgSessions > 10) {
      riskScore += 0.3;
    } else if (avgSessions > 5) {
      riskScore += 0.15;
    }

    debugPrint('[MLRelapsePredictor] Rule-based risk score: ${(riskScore * 100).toStringAsFixed(1)}%');
    return riskScore.clamp(0.0, 1.0);
  }

  /// Get risk category from score
  String getRiskCategory(double riskScore) {
    if (riskScore < 0.3) return 'Low';
    if (riskScore < 0.6) return 'Medium';
    if (riskScore < 0.8) return 'High';
    return 'Critical';
  }

  /// Get personalized recommendation based on risk and features
  String getRecommendation(double riskScore, List<double> features) {
    if (riskScore < 0.3) {
      return 'Great progress! Keep maintaining your healthy habits.';
    }

    // Identify weakest area (lowest feature value = highest concern)
    if (features.isEmpty) {
      return 'Stay focused on your recovery plan and reach out if you need support.';
    }

    final weakestIndex = features.indexOf(features.reduce((a, b) => a < b ? a : b));
    
    switch (weakestIndex) {
      case 0:
        return 'Focus on completing your daily recovery tasks consistently.';
      case 1:
        return 'Your mood has been low. Consider mindfulness or reaching out for support.';
      case 2:
        return 'Recent setback detected. Review your triggers and coping strategies.';
      case 3:
        return 'Your streak is at risk. Recommit to your recovery goals today.';
      case 4:
        return 'High app usage detected. Consider setting screen time limits.';
      case 5:
        return 'Long sessions detected. Try breaking activities into shorter intervals.';
      case 6:
        return 'You\'ve been inactive. Re-engage with your recovery plan today.';
      case 7:
        return 'Mood instability detected. Practice stress management techniques.';
      case 8:
        return 'Weekend patterns differ significantly. Maintain consistency across all days.';
      case 9:
        return 'Your routine seems irregular. Try establishing consistent daily patterns.';
      default:
        return 'Stay focused on your recovery plan and reach out if you need support.';
    }
  }

  /// Check if ML model is available
  bool get isMLAvailable => _isInitialized;

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    debugPrint('[MLRelapsePredictor] Resources disposed');
  }
}

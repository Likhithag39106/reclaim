import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/mood_model.dart';
import '../services/ml_relapse_predictor.dart';
import '../services/firestore_service.dart';

class MLPredictionProvider extends ChangeNotifier {
  final MLRelapsePredictor _predictor = MLRelapsePredictor();
  final FirestoreService _firestoreService = FirestoreService();

  double? _relapseRisk;
  String? _riskCategory;
  String? _recommendation;
  List<double>? _features;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastPredictionTime;

  double? get relapseRisk => _relapseRisk;
  String? get riskCategory => _riskCategory;
  String? get recommendation => _recommendation;
  List<double>? get features => _features;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastPredictionTime => _lastPredictionTime;
  bool get isMLAvailable => _predictor.isMLAvailable;

  /// Initialize ML predictor
  Future<void> initialize() async {
    try {
      await _predictor.initialize();
      debugPrint('[MLPredictionProvider] Initialized successfully');
    } catch (e) {
      debugPrint('[MLPredictionProvider] Initialization error: $e');
      _error = 'Failed to initialize ML model';
      notifyListeners();
    }
  }

  /// Run relapse risk prediction
  Future<void> predictRelapseRisk({
    required UserModel user,
    required List<TaskModel>? recentTasks,
    required List<MoodModel>? recentMoods,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get activity data
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      
      // Fetch recent data if not provided
      final tasks = recentTasks ?? await _firestoreService.getUserTasks(user.uid);
      final moods = recentMoods ?? await _firestoreService.getUserMoods(user.uid);

      // Filter to last 7 days
      final recentTasksList = tasks.where((t) {
        final created = t.createdAt;
        return created != null && created.isAfter(weekAgo);
      }).toList();

      final recentMoodsList = moods.where((m) {
        return m.createdAt.isAfter(weekAgo);
      }).toList();

      // Calculate activity metrics
      final activityData = _calculateActivityMetrics(recentTasksList, recentMoodsList);

      // Run prediction
      final riskScore = await _predictor.predictRelapseRisk(
        user: user,
        recentTasks: recentTasksList,
        recentMoods: recentMoodsList,
        activityData: activityData,
      );

      // Features are extracted internally by predictor
      // We'll pass the raw score instead
      _features = null; // Features not exposed publicly

      _relapseRisk = riskScore;
      _riskCategory = _predictor.getRiskCategory(riskScore);
      
      // Simple recommendation based on risk level
      if (riskScore < 0.3) {
        _recommendation = 'Great job! Keep maintaining your recovery routine.';
      } else if (riskScore < 0.6) {
        _recommendation = 'Stay vigilant. Focus on completing daily tasks and maintaining good mood.';
      } else if (riskScore < 0.8) {
        _recommendation = 'High risk detected. Reach out to support network and review your recovery plan.';
      } else {
        _recommendation = 'Critical risk. Please contact your support network immediately.';
      }
      
      _lastPredictionTime = DateTime.now();
      _error = null;

      debugPrint('[MLPredictionProvider] Prediction complete:');
      debugPrint('  Risk: ${(riskScore * 100).toStringAsFixed(1)}%');
      debugPrint('  Category: $_riskCategory');
      debugPrint('  Recommendation: $_recommendation');
    } catch (e) {
      debugPrint('[MLPredictionProvider] Prediction error: $e');
      _error = 'Failed to predict relapse risk: $e';
      _relapseRisk = null;
      _riskCategory = null;
      _recommendation = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Calculate activity metrics for prediction
  Map<String, dynamic> _calculateActivityMetrics(
    List<TaskModel> tasks,
    List<MoodModel> moods,
  ) {
    // Calculate average daily sessions (using tasks as proxy)
    final sessionsPerDay = <String, int>{};
    for (final task in tasks) {
      final date = task.createdAt;
      if (date != null) {
        final dateKey = '${date.year}-${date.month}-${date.day}';
        sessionsPerDay[dateKey] = (sessionsPerDay[dateKey] ?? 0) + 1;
      }
    }

    final avgDailySessions = sessionsPerDay.isEmpty
        ? 0.0
        : sessionsPerDay.values.reduce((a, b) => a + b) / sessionsPerDay.length;

    // Calculate average session duration (estimated)
    final avgSessionDuration = avgDailySessions * 5.0; // Rough estimate: 5 min per task

    // Calculate days inactive (days with no tasks)
    final now = DateTime.now();
    int daysInactive = 0;
    for (int i = 0; i < 7; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final dateKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
      if (!sessionsPerDay.containsKey(dateKey)) {
        daysInactive++;
      }
    }

    // Calculate weekend vs weekday ratio
    double weekdaySessions = 0;
    double weekendSessions = 0;
    int weekdayCount = 0;
    int weekendCount = 0;

    for (final entry in sessionsPerDay.entries) {
      final parts = entry.key.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        weekendSessions += entry.value;
        weekendCount++;
      } else {
        weekdaySessions += entry.value;
        weekdayCount++;
      }
    }

    final avgWeekday = weekdayCount > 0 ? weekdaySessions / weekdayCount : 1.0;
    final avgWeekend = weekendCount > 0 ? weekendSessions / weekendCount : 1.0;
    final weekendRatio = avgWeekday > 0 ? avgWeekend / avgWeekday : 1.0;

    // Calculate time irregularity (simplified)
    final timeIrregularity = sessionsPerDay.isEmpty ? 0.3 : 
        (sessionsPerDay.values.toList()..sort()).last / 
        (sessionsPerDay.values.reduce((a, b) => a + b) / sessionsPerDay.length) - 1.0;

    return {
      'avgDailySessions': avgDailySessions,
      'avgSessionDuration': avgSessionDuration,
      'daysInactive': daysInactive,
      'weekendRatio': weekendRatio,
      'timeIrregularity': timeIrregularity.clamp(0.0, 1.0),
    };
  }

  /// Get risk level color
  Color getRiskColor() {
    if (_relapseRisk == null) return Colors.grey;
    if (_relapseRisk! < 0.3) return Colors.green;
    if (_relapseRisk! < 0.6) return Colors.orange;
    if (_relapseRisk! < 0.8) return Colors.deepOrange;
    return Colors.red;
  }

  /// Check if prediction is stale (older than 6 hours)
  bool get isPredictionStale {
    if (_lastPredictionTime == null) return true;
    return DateTime.now().difference(_lastPredictionTime!).inHours >= 6;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _predictor.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import '../models/analytics_model.dart';
import '../services/firestore_service.dart';

class AnalyticsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  AnalyticsModel? _analytics;
  bool _isLoading = false;
  String? _error;

  AnalyticsModel? get analytics => _analytics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAnalytics(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      _analytics = await _firestoreService.getAnalytics(uid);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateAnalytics({
    required String uid,
    required int totalTasksCompleted,
    required int currentStreak,
    required double moodAverage,
    required Map<String, int> tasksCompletedByAddiction,
    required double screenTimeReduction,
  }) async {
    try {
      final updatedAnalytics = AnalyticsModel(
        uid: uid,
        totalTasksCompleted: totalTasksCompleted,
        currentStreak: currentStreak,
        moodAverage: moodAverage,
        tasksCompletedByAddiction: tasksCompletedByAddiction,
        screenTimeReduction: screenTimeReduction,
        lastUpdated: DateTime.now(),
      );

      await _firestoreService.updateAnalytics(uid, updatedAnalytics);
      _analytics = updatedAnalytics;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
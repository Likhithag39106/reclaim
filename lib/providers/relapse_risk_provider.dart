import 'package:flutter/material.dart';
import '../models/relapse_risk_model.dart';
import '../models/mood_model.dart';
import '../services/firestore_service.dart';
import '../services/ml_relapse_service.dart';

class RelapseRiskProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final MLRelapseService _mlService = MLRelapseService();

  RelapseRiskModel? _latestRisk;
  bool _isLoading = false;
  String? _error;

  RelapseRiskModel? get latestRisk => _latestRisk;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadLatestRelapseRisk(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      _latestRisk = await _firestoreService.getLatestRelapseRisk(uid);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> calculateAndSaveRelapseRisk({
    required String uid,
    required List<MoodModel> recentMoods,
    required int missedTasks,
    required double avgScreenTime,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final riskModel = await _mlService.predictRelapseRisk(
        uid: uid,
        recentMoods: recentMoods,
        missedTasks: missedTasks,
        avgScreenTime: avgScreenTime,
      );

      await _firestoreService.saveRelapseRisk(riskModel);
      _latestRisk = riskModel;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
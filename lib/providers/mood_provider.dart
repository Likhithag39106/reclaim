import 'package:flutter/foundation.dart';
import '../models/mood_model.dart';
import '../services/firestore_service.dart';

class MoodProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<MoodModel> _moods = [];
  List<MoodModel> _weeklyMoods = [];
  bool _isLoading = false;
  String? _error;

  List<MoodModel> get moods => _moods;
  List<MoodModel> get weeklyMoods => _weeklyMoods;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Log a new mood
  Future<bool> logMood({
    required String uid,
    required int rating,
    required String mood,
    String? note,
    List<String>? triggers,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final moodModel = MoodModel(
        uid: uid,
        rating: rating,
        mood: mood,
        note: note,
        triggers: triggers ?? [],
        createdAt: DateTime.now(),
      );

      await _firestoreService.logMood(moodModel);
      
      // Reload moods
      await loadUserMoods(uid);
      await loadWeeklyMoods(uid);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[MoodProvider] logMood error: $e');
      return false;
    }
  }

  // Load all user moods
  Future<void> loadUserMoods(String uid) async {
    try {
      _moods = await _firestoreService.getUserMoods(uid);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('[MoodProvider] loadUserMoods error: $e');
    }
  }

  // Load weekly moods
  Future<void> loadWeeklyMoods(String uid) async {
    try {
      _weeklyMoods = await _firestoreService.getWeeklyMoods(uid);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('[MoodProvider] loadWeeklyMoods error: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
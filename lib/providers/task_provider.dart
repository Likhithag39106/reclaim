import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../services/firestore_service.dart';

class TaskProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<TaskModel>? _allTasks;
  List<TaskModel>? _todaysTasks;
  bool _isLoading = false;
  String? _error;
  int _streak = 0;

  List<TaskModel>? get allTasks => _allTasks;
  List<TaskModel>? get todaysTasks => _todaysTasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get streak => _streak;

  // Update task completion state in Firestore
  Future<bool> setTaskCompleted({
    required String uid,
    required String taskId,
    required bool completed,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(taskId)
          .update({
        'completed': completed,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Refresh local cache / lists
      try {
        await loadUserTasks(uid);
        await loadTodaysTasks(uid);
      } catch (_) {
        // ignore reload errors
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('setTaskCompleted error: $e');
      return false;
    }
  }

  Future<bool> createTask({
    required String uid,
    required String title,
    required String description,
    required String addiction,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final task = TaskModel(
        uid: uid,
        title: title,
        description: description,
        addiction: addiction,
        completed: false,
        createdAt: DateTime.now(),
        treeGrowthPoints: 0,
      );

      await _firestoreService.createTask(task);
      await loadTodaysTasks(uid);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[TaskProvider] createTask error: $e');
      return false;
    }
  }

  // Load all user tasks
  Future<void> loadUserTasks(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      _allTasks = await _firestoreService.getUserTasks(uid);
      _calculateStreak();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[TaskProvider] loadUserTasks error: $e');
    }
  }

  // Load today's tasks
  Future<void> loadTodaysTasks(String uid) async {
    try {
      _todaysTasks = await _firestoreService.getTodaysTasks(uid);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('[TaskProvider] loadTodaysTasks error: $e');
    }
  }

  // Complete a task (keeps existing API)
  Future<bool> completeTask({
    required String uid,
    required String taskId,
    String? proofImageUrl,
  }) async {
    try {
      await _firestoreService.completeTask(uid, taskId, proofImageUrl);
      await loadTodaysTasks(uid);
      await loadUserTasks(uid);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[TaskProvider] completeTask error: $e');
      return false;
    }
  }

  // Calculate streak
  void _calculateStreak() {
    if (_allTasks == null || _allTasks!.isEmpty) {
      _streak = 0;
      return;
    }

    int currentStreak = 0;
    DateTime currentDate = DateTime.now();

    // consider only tasks with a non-null completedAt
    final completedTasks = _allTasks!
        .where((task) => task.completed && task.completedAt != null)
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

    for (var task in completedTasks) {
      final taskDate = DateTime(
        task.completedAt!.year,
        task.completedAt!.month,
        task.completedAt!.day,
      );
      final checkDate = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      );

      if (taskDate == checkDate) {
        currentStreak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    _streak = currentStreak;
  }

  // Complete task with optional photo upload
  Future<bool> completeTaskWithPhoto({
    required String uid,
    required String taskId,
    required File? photoFile,
  }) async {
    try {
      String? imageUrl;
      if (photoFile != null) {
        imageUrl = await _firestoreService.uploadTaskPhoto(file: photoFile, uid: uid);
      }
      
      await _firestoreService.completeTask(uid, taskId, imageUrl);
      await loadTodaysTasks(uid);
      await loadUserTasks(uid);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[TaskProvider] completeTaskWithPhoto error: $e');
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
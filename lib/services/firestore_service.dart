import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/mood_model.dart';
import '../models/analytics_model.dart';
import '../models/recovery_plan_model.dart';
import '../models/relapse_risk_model.dart';
import '../models/tree_model.dart';

class FirestoreService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory storage for local testing
  final Map<String, UserModel> _localUsers = {};
  final Map<String, List<TaskModel>> _localTasks = {};
  final Map<String, List<MoodModel>> _localMoods = {};
  final Map<String, TreeModel> _localTrees = {};

  // ============ USER OPERATIONS ============
  Future<void> createUser(UserModel user) async {
    try {
      debugPrint('[FirestoreService] Creating user in Firestore: ${user.uid}');

      await _firestore.collection('users').doc(user.uid).set(user.toFirestore());

      // Initialize tree in Firestore
      final tree = TreeModel(
        uid: user.uid,
        growthLevel: 0,
        totalGrowthPoints: 0,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );
      await _firestore.collection('trees').doc(user.uid).set(tree.toFirestore());

      // Initialize empty task/mood collections are implicit; keep local mirrors
      _localUsers[user.uid] = user;
      _localTrees[user.uid] = tree;
      _localTasks[user.uid] = [];
      _localMoods[user.uid] = [];

      debugPrint('[FirestoreService] User and tree created successfully in Firestore');
    } catch (e) {
      debugPrint('[FirestoreService] createUser error: $e');
      // Fallback to local to avoid blocking UX
      _localUsers[user.uid] = user;
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      debugPrint('[FirestoreService] Getting user from Firestore: $uid');
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final user = UserModel.fromFirestore(data, uid);
      _localUsers[uid] = user; // cache
      return user;
    } catch (e) {
      debugPrint('[FirestoreService] getUser error: $e');
      return _localUsers[uid];
    }
  }

  // ============ TASK OPERATIONS ============
  // Now returns the created TaskModel with generated id so providers can update UI immediately.
  Future<TaskModel> createTask(TaskModel task) async {
    try {
      debugPrint('[FirestoreService] Creating task in Firestore: ${task.title}');

      final createdAt = task.createdAt ?? DateTime.now();
      final doc = await _firestore
          .collection('users')
          .doc(task.uid)
          .collection('tasks')
          .add({
        'title': task.title,
        'description': task.description,
        'addiction': task.addiction,
        'completed': task.completed,
          'createdAt': Timestamp.fromDate(createdAt),
          'completedAt': task.completedAt != null ? Timestamp.fromDate(task.completedAt!) : null,
        'proofImageUrl': task.proofImageUrl,
        'treeGrowthPoints': task.treeGrowthPoints,
          'updatedAt': task.updatedAt != null ? Timestamp.fromDate(task.updatedAt!) : FieldValue.serverTimestamp(),
      });

      final taskWithId = TaskModel(
        id: doc.id,
        uid: task.uid,
        title: task.title,
        description: task.description,
        addiction: task.addiction,
        completed: task.completed,
        createdAt: createdAt,
        completedAt: task.completedAt,
        proofImageUrl: task.proofImageUrl,
        treeGrowthPoints: task.treeGrowthPoints,
        updatedAt: task.updatedAt,
      );
      _localTasks[task.uid] ??= [];
      _localTasks[task.uid]!.add(taskWithId);
      return taskWithId;
    } catch (e) {
      debugPrint('[FirestoreService] createTask error: $e');
      // fallback local
      _localTasks[task.uid] ??= [];
      final local = TaskModel(
        id: task.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        uid: task.uid,
        title: task.title,
        description: task.description,
        addiction: task.addiction,
        completed: task.completed,
        createdAt: task.createdAt ?? DateTime.now(),
        completedAt: task.completedAt,
        proofImageUrl: task.proofImageUrl,
        treeGrowthPoints: task.treeGrowthPoints,
        updatedAt: task.updatedAt,
      );
      _localTasks[task.uid]!.add(local);
      return local;
    }
  }

  Future<List<TaskModel>> getUserTasks(String uid) async {
    try {
      debugPrint('[FirestoreService] Getting user tasks from Firestore for $uid');
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .get();

      final tasks = snapshot.docs.map((d) => TaskModel.fromMap(d.data(), id: d.id)).toList();
      _localTasks[uid] = tasks;
      return tasks;
    } catch (e) {
      debugPrint('[FirestoreService] getUserTasks error: $e');
      return List<TaskModel>.from(_localTasks[uid] ?? []);
    }
  }

  /// Backfill completedAt timestamps for completed tasks missing this field.
  /// Returns the number of tasks updated.
  Future<int> backfillCompletedAt(String uid) async {
    try {
      debugPrint('[FirestoreService] Backfilling completedAt for user $uid');
      final query = await _firestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .where('completed', isEqualTo: true)
          .get();

      int updated = 0;
      for (final doc in query.docs) {
        final data = doc.data();
        if (data['completedAt'] == null) {
          final Timestamp? u = data['updatedAt'] as Timestamp?;
          final Timestamp? c = data['createdAt'] as Timestamp?;
          final Timestamp ts = u ?? c ?? Timestamp.now();
          await doc.reference.update({'completedAt': ts});
          updated++;
        }
      }
      debugPrint('[FirestoreService] Backfill completed: $updated tasks updated');
      return updated;
    } catch (e) {
      debugPrint('[FirestoreService] backfillCompletedAt error: $e');
      return 0;
    }
  }

  // ============ ANALYTICS / LOGIN EVENTS ============

  /// Record a login event for the user (one document per login).
  Future<void> logLogin(String uid) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('analytics')
          .doc('logins')
          .collection('events')
          .add({'at': FieldValue.serverTimestamp()});
      debugPrint('[FirestoreService] Logged login for $uid');
    } catch (e) {
      debugPrint('[FirestoreService] logLogin error: $e');
    }
  }

  /// Fetch recent login timestamps within the last [days].
  Future<List<DateTime>> getRecentLogins(String uid, {int days = 30}) async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(Duration(days: days)));
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('analytics')
          .doc('logins')
          .collection('events')
          .where('at', isGreaterThanOrEqualTo: cutoff)
          .orderBy('at', descending: true)
          .get();

      return snapshot.docs
          .map((d) => (d['at'] as Timestamp?)?.toDate())
          .whereType<DateTime>()
          .toList();
    } catch (e) {
      debugPrint('[FirestoreService] getRecentLogins error: $e');
      return [];
    }
  }

  Future<List<TaskModel>> getTodaysTasks(String uid) async {
    try {
      debugPrint('[FirestoreService] Getting todays tasks from Firestore for $uid');
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .where('createdAt', isLessThan: endOfDay)
          .orderBy('createdAt', descending: true)
          .get();

      final tasks = snapshot.docs.map((d) => TaskModel.fromMap(d.data(), id: d.id)).toList();
      return tasks;
    } catch (e) {
      debugPrint('[FirestoreService] getTodaysTasks error: $e');
      final tasks = _localTasks[uid] ?? [];
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      return tasks.where((task) {
        final c = task.createdAt;
        if (c == null) return false;
        return !c.isBefore(startOfDay) && c.isBefore(endOfDay);
      }).toList();
    }
  }

  Future<void> completeTask(String uid, String taskId, String? proofImageUrl) async {
    try {
      debugPrint('[FirestoreService] Completing task in Firestore: $taskId');
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(taskId)
          .update({
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
        'proofImageUrl': proofImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // mirror local cache
      final tasks = _localTasks[uid];
      if (tasks != null) {
        final taskIndex = tasks.indexWhere((t) => t.id == taskId);
        if (taskIndex != -1) {
          final task = tasks[taskIndex];
          tasks[taskIndex] = TaskModel(
            id: task.id,
            uid: task.uid,
            title: task.title,
            description: task.description,
            addiction: task.addiction,
            completed: true,
            createdAt: task.createdAt ?? DateTime.now(),
            completedAt: DateTime.now(),
            proofImageUrl: proofImageUrl ?? task.proofImageUrl,
            treeGrowthPoints: task.treeGrowthPoints,
            updatedAt: DateTime.now(),
          );
        }
      }

      await _addTreeGrowth(uid, 10);
    } catch (e) {
      debugPrint('[FirestoreService] completeTask error: $e');
      // best-effort local update
      final tasks = _localTasks[uid];
      if (tasks != null) {
        final taskIndex = tasks.indexWhere((t) => t.id == taskId);
        if (taskIndex != -1) {
          final task = tasks[taskIndex];
          tasks[taskIndex] = TaskModel(
            id: task.id,
            uid: task.uid,
            title: task.title,
            description: task.description,
            addiction: task.addiction,
            completed: true,
            createdAt: task.createdAt ?? DateTime.now(),
            completedAt: DateTime.now(),
            proofImageUrl: proofImageUrl ?? task.proofImageUrl,
            treeGrowthPoints: task.treeGrowthPoints,
            updatedAt: DateTime.now(),
          );
        }
      }
      await _addTreeGrowth(uid, 10);
    }
  }

  /// Uploads an image file to Firebase Storage and returns the download URL.
  Future<String> uploadTaskPhoto({required File file, required String uid}) async {
    try {
      final path = 'users/$uid/task_proofs/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(path);
      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();
      debugPrint('[FirestoreService] uploaded photo url=$url');
      return url;
    } catch (e) {
      debugPrint('[FirestoreService] uploadTaskPhoto error: $e');
      rethrow;
    }
  }

  // ============ MOOD OPERATIONS ============
  Future<void> logMood(MoodModel mood) async {
    try {
      debugPrint('[FirestoreService] Logging mood in Firestore: ${mood.rating}');
      await _firestore
          .collection('users')
          .doc(mood.uid)
          .collection('moods')
          .add(mood.toMap());

      _localMoods[mood.uid] ??= [];
      _localMoods[mood.uid]!.add(mood);
    } catch (e) {
      debugPrint('[FirestoreService] logMood error: $e');
      _localMoods[mood.uid] ??= [];
      _localMoods[mood.uid]!.add(mood);
    }
  }

  Future<List<MoodModel>> getUserMoods(String uid) async {
    try {
      debugPrint('[FirestoreService] Getting user moods from Firestore for $uid');
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('moods')
          .orderBy('createdAt', descending: true)
          .get();
      final moods = snapshot.docs.map((d) => MoodModel.fromMap(d.data(), d.id)).toList();
      _localMoods[uid] = moods;
      return moods;
    } catch (e) {
      debugPrint('[FirestoreService] getUserMoods error: $e');
      return List<MoodModel>.from(_localMoods[uid] ?? []);
    }
  }

  Future<List<MoodModel>> getWeeklyMoods(String uid) async {
    try {
      debugPrint('[FirestoreService] Getting weekly moods from Firestore for $uid');
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('moods')
          .where('createdAt', isGreaterThanOrEqualTo: weekAgo)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((d) => MoodModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      debugPrint('[FirestoreService] getWeeklyMoods error: $e');
      final moods = _localMoods[uid] ?? [];
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      return moods.where((mood) => mood.createdAt.isAfter(weekAgo)).toList();
    }
  }

  // ============ ANALYTICS OPERATIONS ============
  Future<void> updateAnalytics(String uid, AnalyticsModel analytics) async {
    try {
      debugPrint('[FirestoreService] Updating analytics in Firestore');
      await _firestore.collection('users').doc(uid).collection('analytics').doc('latest').set(analytics.toFirestore());
    } catch (e) {
      debugPrint('[FirestoreService] updateAnalytics error: $e');
    }
  }

  Future<AnalyticsModel?> getAnalytics(String uid) async {
    try {
      debugPrint('[FirestoreService] Getting analytics from Firestore');
      final doc = await _firestore.collection('users').doc(uid).collection('analytics').doc('latest').get();
      if (!doc.exists || doc.data() == null) return null;
      return AnalyticsModel.fromFirestore(doc.data()!);
    } catch (e) {
      debugPrint('[FirestoreService] getAnalytics error: $e');
      return null;
    }
  }

  // ============ RECOVERY PLAN OPERATIONS ============
  Future<void> saveRecoveryPlan(RecoveryPlanModel plan) async {
    try {
      debugPrint('[FirestoreService] Saving recovery plan in Firestore');
      final collection = _firestore
          .collection('users')
          .doc(plan.uid)
          .collection('recoveryPlans');

      if (plan.id != null && plan.id!.isNotEmpty) {
        await collection.doc(plan.id).set(plan.toMap(), SetOptions(merge: true));
      } else {
        await collection.add(plan.toMap());
      }
    } catch (e) {
      debugPrint('[FirestoreService] saveRecoveryPlan error: $e');
    }
  }

  Future<List<RecoveryPlanModel>> getUserRecoveryPlans(String uid) async {
    try {
      debugPrint('[FirestoreService] Getting recovery plans from Firestore');
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('recoveryPlans')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => RecoveryPlanModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('[FirestoreService] getUserRecoveryPlans error: $e');
      return [];
    }
  }

  // ============ RELAPSE RISK OPERATIONS ============
  Future<void> saveRelapseRisk(RelapseRiskModel risk) async {
    try {
      debugPrint('[FirestoreService] Saving relapse risk in Firestore');
        await _firestore
          .collection('users')
          .doc(risk.uid)
          .collection('relapseRisks')
          .add(risk.toFirestore());
    } catch (e) {
      debugPrint('[FirestoreService] saveRelapseRisk error: $e');
    }
  }

  Future<RelapseRiskModel?> getLatestRelapseRisk(String uid) async {
    try {
      debugPrint('[FirestoreService] Getting relapse risk from Firestore');
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('relapseRisks')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final first = snapshot.docs.first;
      return RelapseRiskModel.fromFirestore(first.data(), first.id);
    } catch (e) {
      debugPrint('[FirestoreService] getLatestRelapseRisk error: $e');
      return null;
    }
  }

  // ============ TREE OPERATIONS ============
  Future<TreeModel?> getTree(String uid) async {
    try {
      debugPrint('[FirestoreService] Getting tree from Firestore');
      final doc = await _firestore.collection('trees').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final tree = TreeModel.fromFirestore(doc.data()!);
        _localTrees[uid] = tree;
        return tree;
      }

      // create default if missing
      final tree = TreeModel(
        uid: uid,
        growthLevel: 0,
        totalGrowthPoints: 0,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );
      await _firestore.collection('trees').doc(uid).set(tree.toFirestore());
      _localTrees[uid] = tree;
      return tree;
    } catch (e) {
      debugPrint('[FirestoreService] getTree error: $e');
      return _localTrees[uid];
    }
  }

  Future<void> _addTreeGrowth(String uid, int points) async {
    try {
      debugPrint('[FirestoreService] Adding tree growth: $points points');

      final tree = await getTree(uid) ?? TreeModel(
        uid: uid,
        growthLevel: 0,
        totalGrowthPoints: 0,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      final newPoints = tree.totalGrowthPoints + points;
      // Each 500 points grows one stage; keep stages bounded to avoid runaway values
      final growthLevel = (newPoints ~/ 500).clamp(0, 100);

      final updated = TreeModel(
        uid: tree.uid,
        growthLevel: growthLevel,
        totalGrowthPoints: newPoints,
        createdAt: tree.createdAt,
        lastUpdated: DateTime.now(),
      );

      await _firestore.collection('trees').doc(uid).set(updated.toFirestore());
      _localTrees[uid] = updated;
    } catch (e) {
      debugPrint('[FirestoreService] _addTreeGrowth error: $e');
    }
  }
}
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recovery_plan_model.dart';
import '../models/task_model.dart';
import '../models/mood_model.dart';
import 'ai_api_client.dart';

/// AI-Based Personalized Recovery Plan Service
/// 
/// This service uses machine learning to generate personalized recovery plans
/// based on user behavioral data instead of fixed IF-ELSE rules.
/// 
/// How it works:
/// 1. Extract user features (usage, tasks, moods, relapses)
/// 2. Normalize features using trained scaler parameters
/// 3. Run ML model inference to predict severity level
/// 4. Generate personalized recovery plan based on ML prediction
/// 
/// Models used:
/// - recovery_plan_classifier.tflite: Trained ML model for severity classification
/// - Supports: Logistic Regression, Decision Tree, Random Forest (converted to TFLite)
class AIRecoveryPlanService {
  static final AIRecoveryPlanService _instance = AIRecoveryPlanService._internal();
  factory AIRecoveryPlanService() => _instance;
  AIRecoveryPlanService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Python API client (preferred for inference)
  final AiApiClient _apiClient = AiApiClient();
  bool _apiAvailable = false;
  
  // ML Model components (fallback)
  Interpreter? _interpreter;
  Map<String, dynamic>? _scalerParams;
  Map<String, dynamic>? _classMapping;
  bool _isInitialized = false;

  /// Initialize the AI model
  /// 
  /// Checks Python API availability and loads TFLite model as fallback
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[AIRecoveryPlan] Initializing AI model...');

      // Check if Python API is available
      try {
        _apiAvailable = await _apiClient.health().timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );
        if (_apiAvailable) {
          debugPrint('[AIRecoveryPlan] ✓ Python API available');
        } else {
          debugPrint('[AIRecoveryPlan] ⚠ Python API not healthy, using TFLite fallback');
        }
      } catch (e) {
        _apiAvailable = false;
        debugPrint('[AIRecoveryPlan] ⚠ Python API unreachable: $e');
      }

      // Load TFLite model as fallback
      try {
        _interpreter = await Interpreter.fromAsset('models/recovery_plan_classifier.tflite');
        debugPrint('[AIRecoveryPlan] ✓ TFLite model loaded');

        // Load scaler parameters
        final scalerJson = await rootBundle.loadString('assets/models/scaler_params.json');
        _scalerParams = jsonDecode(scalerJson);
        debugPrint('[AIRecoveryPlan] ✓ Scaler params loaded: ${_scalerParams!['feature_names'].length} features');

        // Load class mapping
        final classJson = await rootBundle.loadString('assets/models/class_mapping.json');
        _classMapping = jsonDecode(classJson);
        debugPrint('[AIRecoveryPlan] ✓ Class mapping loaded: ${_classMapping!['classes']}');
      } catch (e) {
        debugPrint('[AIRecoveryPlan] ⚠ TFLite initialization failed: $e');
      }

      _isInitialized = true;
      debugPrint('[AIRecoveryPlan] ✓ Initialization complete');
    } catch (e) {
      _isInitialized = false;
      debugPrint('[AIRecoveryPlan] ⚠ Initialization failed: $e');
      throw Exception('AI model initialization failed: $e');
    }
  }

  /// Generate AI-powered personalized recovery plan
  /// 
  /// Args:
  ///   uid: User ID
  ///   addiction: Type of addiction
  /// 
  /// Returns:
  ///   RecoveryPlanModel with AI-predicted severity and personalized goals
  Future<RecoveryPlanModel> generateAIPlan(String uid, String addiction) async {
    try {
      debugPrint('[AIRecoveryPlan] Generating AI plan for user: $uid');

      // Step 1: Extract user features
      final features = await _extractUserFeatures(uid);
      debugPrint('[AIRecoveryPlan] ✓ Features extracted: ${features.length} features');

      // Step 2: Try Python API first, fall back to TFLite
      Map<String, dynamic> prediction;
      String predictionSource;
      
      if (_apiAvailable) {
        try {
          prediction = await _predictWithPythonAPI(features, addiction);
          predictionSource = 'Python API (TensorFlow)';
          debugPrint('[AIRecoveryPlan] ✓ Using Python API prediction');
        } catch (apiError) {
          debugPrint('[AIRecoveryPlan] ⚠ API failed: $apiError, falling back to TFLite');
          prediction = await _predictSeverity(features);
          predictionSource = 'TFLite (local)';
          _apiAvailable = false; // Mark API as unavailable for this session
        }
      } else {
        prediction = await _predictSeverity(features);
        predictionSource = 'TFLite (local)';
      }

      final severity = prediction['severity'];
      final confidence = prediction['confidence'];
      final probabilities = (prediction['probabilities'] as List<double>? ?? []);
      final apiGoals = prediction['api_goals'] as List<String>?;
      final apiTips = prediction['api_tips'] as List<String>?;

      debugPrint('[AIRecoveryPlan] ✓ ML Prediction ($predictionSource): $severity (confidence: ${(confidence * 100).toStringAsFixed(1)}%)');

      // Step 3: Generate personalized plan based on ML prediction
      final plan = _generatePersonalizedPlan(
        uid: uid,
        addiction: addiction,
        severity: severity,
        confidence: confidence,
        probabilities: probabilities,
        features: features,
        apiGoals: apiGoals,
        apiTips: apiTips,
      );

      // Step 4: Save to Firestore
      try {
        final docRef = await _firestore
            .collection('users')
            .doc(uid)
            .collection('recoveryPlans')
            .add(plan.toMap());

        return plan.copyWith(id: docRef.id);
      } catch (firestoreError) {
        debugPrint('[AIRecoveryPlan] Firestore save failed: $firestoreError');
        final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
        return plan.copyWith(id: localId);
      }
    } catch (e) {
      debugPrint('[AIRecoveryPlan] Error generating AI plan: $e');
      rethrow;
    }
  }

  /// Extract behavioral features from user data
  /// 
  /// Features extracted (16 total):
  /// - Usage patterns (5): session duration, frequency, timing
  /// - Task completion (3): completion rate, streak, speed
  /// - Mood tracking (3): average, variance, triggers
  /// - Relapse history (3): count, recency, frequency
  /// - Engagement (2): login rate, active days
  Future<List<double>> _extractUserFeatures(String uid) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Feature 1-6: Usage patterns
    final usageFeatures = await _extractUsageFeatures(uid, thirtyDaysAgo, now);

    // Feature 7-9: Task completion
    final taskFeatures = await _extractTaskFeatures(uid, thirtyDaysAgo, now);

    // Feature 10-12: Mood tracking
    final moodFeatures = await _extractMoodFeatures(uid, thirtyDaysAgo, now);

    // Feature 13-15: Relapse history
    final relapseFeatures = await _extractRelapseFeatures(uid, thirtyDaysAgo, now);

    // Feature 16-17: Engagement
    final engagementFeatures = await _extractEngagementFeatures(uid, thirtyDaysAgo, now);

    // Combine all features
    final features = [
      ...usageFeatures,
      ...taskFeatures,
      ...moodFeatures,
      ...relapseFeatures,
      ...engagementFeatures,
    ];

    debugPrint('[AIRecoveryPlan] Features: ${features.map((f) => f.toStringAsFixed(2)).join(", ")}');

    return features;
  }

  /// Extract app usage pattern features
  Future<List<double>> _extractUsageFeatures(String uid, DateTime start, DateTime end) async {
    try {
      final sessions = await _firestore
          .collection('users')
          .doc(uid)
          .collection('activity')
          .where('sessionStart', isGreaterThanOrEqualTo: start)
          .where('sessionStart', isLessThanOrEqualTo: end)
          .get();

      if (sessions.docs.isEmpty) {
        return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];  // 6 features
      }

      final durations = sessions.docs
          .map((doc) => (doc.data()['duration'] as int? ?? 0) / 60.0)
          .toList();

      final avgSessionDuration = durations.reduce((a, b) => a + b) / durations.length;
      final maxSessionDuration = durations.reduce((a, b) => a > b ? a : b);

      // Sessions per day
      final uniqueDays = sessions.docs
          .map((doc) => (doc.data()['sessionStart'] as Timestamp).toDate())
          .map((date) => '${date.year}-${date.month}-${date.day}')
          .toSet()
          .length;
      final sessionsPerDay = sessions.docs.length / (uniqueDays > 0 ? uniqueDays : 1);

      // Late night sessions (10 PM - 2 AM)
      final lateNightSessions = sessions.docs
          .where((doc) {
            final hour = (doc.data()['sessionStart'] as Timestamp).toDate().hour;
            return hour >= 22 || hour <= 2;
          })
          .length
          .toDouble();

      // Weekend session ratio
      final weekendSessions = sessions.docs
          .where((doc) {
            final weekday = (doc.data()['sessionStart'] as Timestamp).toDate().weekday;
            return weekday == 6 || weekday == 7;  // Saturday or Sunday
          })
          .length;
      final weekendRatio = weekendSessions / sessions.docs.length;

      return [
        avgSessionDuration,        // Feature 1
        sessionsPerDay,            // Feature 2
        maxSessionDuration,        // Feature 3
        lateNightSessions,         // Feature 4
        weekendRatio,              // Feature 5
        sessions.docs.length.toDouble(),  // Feature 6: total sessions
      ];
    } catch (e) {
      debugPrint('[AIRecoveryPlan] Usage feature extraction failed: $e');
      return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    }
  }

  /// Extract task completion features
  Future<List<double>> _extractTaskFeatures(String uid, DateTime start, DateTime end) async {
    try {
      final tasks = await _firestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      if (tasks.docs.isEmpty) {
        return [0.0, 0.0, 0.0];
      }

      final taskModels = tasks.docs.map((doc) => TaskModel.fromMap(doc.data(), id: doc.id)).toList();

      // Completion rate
      final completedCount = taskModels.where((t) => t.completed).length;
      final completionRate = completedCount / taskModels.length;

      // Current streak (consecutive days)
      final streak = _calculateStreak(taskModels);

      // Average completion time (in hours)
      final completionTimes = taskModels
          .where((t) => t.completed && t.createdAt != null && t.completedAt != null)
          .map((t) => t.completedAt!.difference(t.createdAt!).inHours.toDouble())
          .toList();
      final avgCompletionTime = completionTimes.isEmpty
          ? 0.0
          : completionTimes.reduce((a, b) => a + b) / completionTimes.length;

      return [
        completionRate,            // Feature 7
        streak.toDouble(),         // Feature 8
        avgCompletionTime,         // Feature 9
      ];
    } catch (e) {
      debugPrint('[AIRecoveryPlan] Task feature extraction failed: $e');
      return [0.0, 0.0, 0.0];
    }
  }

  /// Calculate consecutive day streak
  int _calculateStreak(List<TaskModel> tasks) {
    final completedDates = tasks
        .where((t) => t.completed && t.completedAt != null)
        .map((t) => t.completedAt!)
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));  // Sort descending

    if (completedDates.isEmpty) return 0;

    int streak = 1;
    for (int i = 0; i < completedDates.length - 1; i++) {
      final diff = completedDates[i].difference(completedDates[i + 1]).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  /// Extract mood tracking features
  Future<List<double>> _extractMoodFeatures(String uid, DateTime start, DateTime end) async {
    try {
      final moods = await _firestore
          .collection('users')
          .doc(uid)
          .collection('moods')
          .where('createdAt', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('createdAt', isLessThanOrEqualTo: end.toIso8601String())
          .get();

      if (moods.docs.isEmpty) {
        return [3.0, 0.0, 0.0];  // Neutral defaults
      }

      final moodModels = moods.docs.map((doc) => MoodModel.fromMap(doc.data(), doc.id)).toList();

      // Average mood rating (1-5 scale)
      final avgMood = moodModels.map((m) => m.rating).reduce((a, b) => a + b) / moodModels.length;

      // Mood variance (stability indicator)
      final mean = avgMood;
      final variance = moodModels
          .map((m) => (m.rating - mean) * (m.rating - mean))
          .reduce((a, b) => a + b) / moodModels.length;

      // Trigger count
      final triggerCount = moodModels
          .map((m) => m.triggers.length)
          .reduce((a, b) => a + b)
          .toDouble();

      return [
        avgMood,                   // Feature 10
        variance,                  // Feature 11
        triggerCount,              // Feature 12
      ];
    } catch (e) {
      debugPrint('[AIRecoveryPlan] Mood feature extraction failed: $e');
      return [3.0, 0.0, 0.0];
    }
  }

  /// Extract relapse history features
  Future<List<double>> _extractRelapseFeatures(String uid, DateTime start, DateTime end) async {
    try {
      final relapses = await _firestore
          .collection('users')
          .doc(uid)
          .collection('relapses')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final relapseCount = relapses.docs.length.toDouble();

      // Days since last relapse
      double daysSinceLastRelapse = 365.0;  // Default
      if (relapses.docs.isNotEmpty) {
        final timestamps = relapses.docs
            .map((doc) => (doc.data()['timestamp'] as Timestamp).toDate())
            .toList()
          ..sort((a, b) => b.compareTo(a));
        daysSinceLastRelapse = DateTime.now().difference(timestamps.first).inDays.toDouble();
      }

      // Relapse frequency (per 30 days)
      final relapseFrequency = relapseCount / 30.0;

      return [
        relapseCount,              // Feature 13
        daysSinceLastRelapse,      // Feature 14
        relapseFrequency,          // Feature 15
      ];
    } catch (e) {
      debugPrint('[AIRecoveryPlan] Relapse feature extraction failed: $e');
      return [0.0, 365.0, 0.0];
    }
  }

  /// Extract engagement features
  Future<List<double>> _extractEngagementFeatures(String uid, DateTime start, DateTime end) async {
    try {
      final logins = await _firestore
          .collection('users')
          .doc(uid)
          .collection('analytics')
          .doc('logins')
          .collection('events')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      // Unique active days
      final uniqueDays = logins.docs
          .map((doc) => (doc.data()['timestamp'] as Timestamp).toDate())
          .map((date) => '${date.year}-${date.month}-${date.day}')
          .toSet()
          .length
          .toDouble();

      // Engagement rate
      final totalDays = end.difference(start).inDays;
      final engagementRate = uniqueDays / (totalDays > 0 ? totalDays : 1);

      return [
        engagementRate,            // Feature 16
        uniqueDays,                // Feature 17 (optional, may need to adjust based on model)
      ];
    } catch (e) {
      debugPrint('[AIRecoveryPlan] Engagement feature extraction failed: $e');
      return [0.0, 0.0];
    }
  }

  /// Predict severity level using ML model
  /// 
  /// Args:
  ///   features: Extracted user features (normalized)
  /// 
  /// Predict severity using Python API (TensorFlow backend)
  /// 
  /// Args:
  ///   features: Extracted user features (17 features total)
  ///   addiction: Type of addiction
  /// 
  /// Returns:
  ///   Map with 'severity', 'confidence', and 'probabilities'
  Future<Map<String, dynamic>> _predictWithPythonAPI(
    List<double> features,
    String addiction,
  ) async {
    // Map extracted features to API format
    // Features: [0-5: usage, 6-8: tasks, 9-11: mood, 12-14: relapse, 15-16: engagement]
    
    final dailyUsageMinutes = features.isNotEmpty ? features[0] * 60 : 0.0; // Convert hours to minutes
    final taskCompletionRate = features.length > 6 ? features[6].clamp(0, 1) : 0.5;
    final avgMoodScore = features.length > 9 ? features[9].clamp(0, 10) : 5.0;
    final relapseCount = features.length > 12 ? features[12].toInt().abs() : 0;

    debugPrint('[AIRecoveryPlan] API Request: addiction=$addiction, usage=${dailyUsageMinutes.toStringAsFixed(1)}min, mood=${avgMoodScore.toStringAsFixed(1)}, tasks=${taskCompletionRate.toStringAsFixed(2)}, relapses=$relapseCount');

    final request = RecoveryPlanRequest(
      addictionType: addiction.toLowerCase(),
      dailyUsage: dailyUsageMinutes.toDouble(),
      moodScore: avgMoodScore.toDouble(),
      taskCompletionRate: taskCompletionRate.toDouble(),
      relapseCount: relapseCount,
    );

    final response = await _apiClient.getRecoveryPlan(request);

    debugPrint('[AIRecoveryPlan] API Response: risk=${response.riskLevel}, confidence=${(response.confidence * 100).toStringAsFixed(1)}%, source=${response.source}');

    // Map risk level to severity
    final severityMapping = {
      'low': SeverityLevel.low,
      'medium': SeverityLevel.medium,
      'high': SeverityLevel.high,
    };

    final severity = severityMapping[response.riskLevel] ?? SeverityLevel.medium;

    // Generate probabilities based on confidence
    final probabilities = severity == SeverityLevel.low
        ? [response.confidence, (1 - response.confidence) / 2, (1 - response.confidence) / 2]
        : severity == SeverityLevel.medium
            ? [(1 - response.confidence) / 2, response.confidence, (1 - response.confidence) / 2]
            : [(1 - response.confidence) / 2, (1 - response.confidence) / 2, response.confidence];

    return {
      'severity': severity,
      'confidence': response.confidence,
      'probabilities': probabilities,
      'api_goals': response.goals,
      'api_tips': response.tips,
      'api_source': response.source,
    };
  }

  /// Predict severity using local TFLite model (fallback)
  /// 
  /// Args:
  ///   features: Normalized feature vector
  /// 
  /// Returns:
  ///   Map with 'severity' (SeverityLevel) and 'confidence' (double)
  Future<Map<String, dynamic>> _predictSeverity(List<double> features) async {
    if (!_isInitialized || _interpreter == null) {
      throw StateError('AI model not initialized');
    }

    try {
      // Normalize features using trained scaler
      final normalizedFeatures = _normalizeFeatures(features);

      // Prepare input tensor [1, num_features]
      final input = Float32List.fromList(normalizedFeatures);
      final inputTensor = [input];

      // Prepare output tensor [1, 3] for 3 classes (low, medium, high)
      final output = List.filled(3, 0.0).reshape([1, 3]);

      // Run ML inference
      _interpreter!.run(inputTensor, output);

      // Get predicted class and confidence
      final probabilities = output[0] as List<double>;
      final predictedClassIndex = probabilities.indexOf(probabilities.reduce((a, b) => a > b ? a : b));
      final confidence = probabilities[predictedClassIndex];

      // Map index to severity level
      final severityMapping = {
        0: SeverityLevel.low,
        1: SeverityLevel.medium,
        2: SeverityLevel.high,
      };

      final severity = severityMapping[predictedClassIndex]!;

      debugPrint('[AIRecoveryPlan] ML Probabilities: ${probabilities.map((p) => p.toStringAsFixed(3)).join(", ")}');

      return {
        'severity': severity,
        'confidence': confidence,
        'probabilities': probabilities,
      };
    } catch (e) {
      debugPrint('[AIRecoveryPlan] ML prediction failed: $e');
      throw Exception('ML prediction failed: $e');
    }
  }

  /// Normalize features using trained scaler parameters
  /// 
  /// Formula: (x - mean) / scale
  List<double> _normalizeFeatures(List<double> features) {
    if (_scalerParams == null) return features;

    final means = (_scalerParams!['mean'] as List).cast<double>();
    final scales = (_scalerParams!['scale'] as List).cast<double>();

    final normalized = <double>[];
    for (int i = 0; i < features.length && i < means.length; i++) {
      final normalizedValue = (features[i] - means[i]) / scales[i];
      normalized.add(normalizedValue);
    }

    // Pad with zeros if needed
    while (normalized.length < means.length) {
      normalized.add(0.0);
    }

    return normalized;
  }

  /// Generate personalized recovery plan based on ML prediction
  RecoveryPlanModel _generatePersonalizedPlan({
    required String uid,
    required String addiction,
    required SeverityLevel severity,
    required double confidence,
    required List<double> probabilities,
    required List<double> features,
    List<String>? apiGoals,
    List<String>? apiTips,
  }) {
    // Extract key metrics from features for personalization
    final completionRate = features.length > 6 ? features[6] : 0.5;
    final avgMood = features.length > 9 ? features[9] : 3.0;
    final relapseCount = features.length > 12 ? features[12].toInt() : 0;

    // Build probability map
    Map<String, double> probMap;
    if (probabilities.isNotEmpty && probabilities.length >= 3) {
      probMap = {
        'low': probabilities[0],
        'medium': probabilities[1],
        'high': probabilities[2],
      };
    } else {
      final remaining = (1 - confidence).clamp(0.0, 1.0);
      final other = remaining / 2;
      probMap = {
        'low': severity == SeverityLevel.low ? confidence : other,
        'medium': severity == SeverityLevel.medium ? confidence : other,
        'high': severity == SeverityLevel.high ? confidence : other,
      };
    }

    // Use API goals/tips if available, otherwise generate locally
    final dailyGoals = apiGoals != null && apiGoals.isNotEmpty
        ? apiGoals.take(5).map((goal) => RecoveryGoal(
            id: DateTime.now().millisecondsSinceEpoch.toString() + goal.hashCode.toString(),
            description: goal,
            completed: false,
            points: 10,
          )).toList()
        : _generateAIGoals(severity, completionRate, avgMood, relapseCount);

    return RecoveryPlanModel(
      uid: uid,
      addiction: addiction,
      title: _getAIPlanTitle(addiction, severity, confidence),
      description: _getAIPlanDescription(severity, confidence, apiTips),
      severity: severity,
      status: RecoveryPlanStatus.active,
      dailyGoals: dailyGoals,
      milestones: _generateAIMilestones(severity),
      alternativeActivities: _generateAlternativeActivities(addiction),
      timeRestrictions: {
        ..._generateTimeRestrictions(severity),
        'severity_prediction': severity.name,
        'prediction_confidence': probMap,
        'used_fallback': false,
        if (apiGoals != null) 'api_powered': true,
      },
      createdAt: DateTime.now(),
    );
  }

  String _getAIPlanTitle(String addiction, SeverityLevel severity, double confidence) {
    final confidenceText = confidence > 0.85 ? 'Highly Personalized' : 'AI-Personalized';
    final severityText = severity == SeverityLevel.high
        ? 'Intensive'
        : severity == SeverityLevel.medium
            ? 'Structured'
            : 'Supportive';
    return '$confidenceText $severityText Plan - $addiction';
  }

  String _getAIPlanDescription(SeverityLevel severity, double confidence, List<String>? apiTips) {
    final baseDesc = severity == SeverityLevel.high
        ? 'An AI-powered intensive recovery program with daily commitment and professional support.'
        : severity == SeverityLevel.medium
            ? 'An AI-tailored structured program with balanced goals and accountability.'
            : 'An AI-optimized gentle approach focusing on sustainable habit building.';

    final confidenceText = 'This plan was generated by machine learning based on your unique behavioral patterns (${(confidence * 100).toStringAsFixed(0)}% confidence).';
    
    // Add first tip if available from API
    if (apiTips != null && apiTips.isNotEmpty) {
      return '$baseDesc\n\n$confidenceText\n\n💡 ${apiTips.first}';
    }
    
    return '$baseDesc\n\n$confidenceText';
  }

  /// Generate AI-personalized goals based on user metrics
  List<RecoveryGoal> _generateAIGoals(
    SeverityLevel severity,
    double completionRate,
    double avgMood,
    int relapseCount,
  ) {
    final goals = <RecoveryGoal>[];

    // Universal goals
    goals.add(const RecoveryGoal(
      id: 'morning_intention',
      description: 'Start your day with a positive intention',
      points: 10,
    ));

    goals.add(const RecoveryGoal(
      id: 'mood_checkin',
      description: 'Log your mood and emotional state',
      points: 10,
    ));

    // Personalized based on metrics
    if (completionRate < 0.5) {
      // Low completion rate → easier goals
      goals.add(const RecoveryGoal(
        id: 'small_win',
        description: 'Complete one small recovery task',
        points: 20,
      ));
    } else {
      // Good completion → more challenging goals
      goals.add(const RecoveryGoal(
        id: 'multiple_tasks',
        description: 'Complete 3 recovery activities',
        points: 25,
      ));
    }

    if (avgMood < 3.0) {
      // Low mood → focus on emotional support
      goals.add(const RecoveryGoal(
        id: 'self_care',
        description: 'Practice self-care or relaxation for 15 minutes',
        points: 15,
      ));
      goals.add(const RecoveryGoal(
        id: 'support_connection',
        description: 'Connect with a supportive person',
        points: 15,
      ));
    }

    if (relapseCount > 0) {
      // Recent relapses → stricter monitoring
      goals.add(const RecoveryGoal(
        id: 'trigger_awareness',
        description: 'Identify and log triggers or cravings',
        points: 15,
      ));
      goals.add(const RecoveryGoal(
        id: 'accountability',
        description: 'Check in with accountability partner',
        points: 20,
      ));
    }

    // Severity-specific goals
    switch (severity) {
      case SeverityLevel.high:
        goals.add(const RecoveryGoal(
          id: 'professional_support',
          description: 'Attend therapy or support group',
          points: 30,
        ));
        break;
      case SeverityLevel.medium:
        goals.add(const RecoveryGoal(
          id: 'alternative_activity',
          description: 'Engage in 2 healthy alternative activities',
          points: 20,
        ));
        break;
      case SeverityLevel.low:
        goals.add(const RecoveryGoal(
          id: 'progress_reflection',
          description: 'Reflect on your progress and celebrate wins',
          points: 15,
        ));
        break;
    }

    return goals;
  }

  List<RecoveryMilestone> _generateAIMilestones(SeverityLevel severity) {
    // Same as rule-based for now, could be personalized further
    return [
      const RecoveryMilestone(
        id: 'week_1',
        title: '7 Days Strong',
        description: 'Complete your first week of recovery',
        targetDays: 7,
        rewardPoints: 100,
      ),
      const RecoveryMilestone(
        id: 'week_2',
        title: '14 Days Achievement',
        description: 'Two weeks of consistent progress',
        targetDays: 14,
        rewardPoints: 200,
      ),
      const RecoveryMilestone(
        id: 'month_1',
        title: '30 Days Milestone',
        description: 'One full month of recovery journey',
        targetDays: 30,
        rewardPoints: 500,
      ),
    ];
  }

  List<AlternativeActivity> _generateAlternativeActivities(String addiction) {
    return [
      const AlternativeActivity(
        id: '1',
        title: 'Physical Activity',
        description: 'Go for a 20-minute walk or exercise',
        durationMinutes: 20,
        categories: ['physical'],
      ),
      const AlternativeActivity(
        id: '2',
        title: 'Social Connection',
        description: 'Call a friend or family member',
        durationMinutes: 15,
        categories: ['social'],
      ),
      const AlternativeActivity(
        id: '3',
        title: 'Mindfulness',
        description: 'Practice mindfulness or meditation',
        durationMinutes: 10,
        categories: ['mental'],
      ),
      const AlternativeActivity(
        id: '4',
        title: 'Creative Engagement',
        description: 'Engage in a hobby or creative activity',
        durationMinutes: 30,
        categories: ['mental', 'physical'],
      ),
      const AlternativeActivity(
        id: '5',
        title: 'Relaxation',
        description: 'Read a book or listen to music',
        durationMinutes: 30,
        categories: ['mental'],
      ),
    ];
  }

  Map<String, dynamic> _generateTimeRestrictions(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.high:
        return {
          'maxDailyMinutes': 30,
          'noUsageAfter': '21:00',
          'requireGoalsFirst': true,
          'restrictions': [
            'No usage after 9 PM',
            'Maximum 30 minutes per session',
            'No usage before completing daily goals',
          ],
        };
      case SeverityLevel.medium:
        return {
          'maxDailyMinutes': 60,
          'noUsageAfter': '22:00',
          'requireGoalsFirst': false,
          'restrictions': [
            'No usage after 10 PM',
            'Maximum 60 minutes per session',
            'Complete at least 2 goals before usage',
          ],
        };
      case SeverityLevel.low:
        return {
          'maxDailyMinutes': 120,
          'noUsageAfter': '23:00',
          'requireGoalsFirst': false,
          'restrictions': [
            'Be mindful of evening usage',
            'Set reasonable time limits',
            'Complete morning check-in before usage',
          ],
        };
    }
  }}
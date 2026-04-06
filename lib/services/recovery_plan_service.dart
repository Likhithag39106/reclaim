import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/recovery_plan_model.dart';
import 'behavior_analysis_service.dart';

/// Service for generating and managing personalized recovery plans
class RecoveryPlanService {
  static final RecoveryPlanService _instance = RecoveryPlanService._internal();
  factory RecoveryPlanService() => _instance;
  RecoveryPlanService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BehaviorAnalysisService _behaviorService = BehaviorAnalysisService();

  /// Generate a new recovery plan based on behavior analysis
  Future<RecoveryPlanModel> generatePlan(String uid, String addiction) async {
    try {
      // Analyze user behavior
      final analysis = await _behaviorService.analyzeBehavior(uid, addiction);

      // Generate plan based on severity
      final plan = RecoveryPlanModel(
        uid: uid,
        addiction: addiction,
        title: _getPlanTitle(addiction, analysis.severity),
        description: _getPlanDescription(addiction, analysis.severity),
        severity: analysis.severity,
        status: RecoveryPlanStatus.active,
        dailyGoals: _generateDailyGoals(addiction, analysis.severity),
        milestones: _generateMilestones(addiction, analysis.severity),
        alternativeActivities: _generateAlternativeActivities(addiction),
        timeRestrictions: _generateTimeRestrictions(analysis.severity),
        createdAt: DateTime.now(),
      );

      // Try to save to Firestore, fallback to local-only mode if permission denied
      try {
        final docRef = await _firestore
            .collection('users')
            .doc(uid)
            .collection('recoveryPlans')
            .add(plan.toMap());

        return plan.copyWith(id: docRef.id);
      } catch (firestoreError) {
        debugPrint('[RecoveryPlanService] Firestore save failed (using local mode): $firestoreError');
        // Generate local ID and return plan for local-only usage
        final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
        return plan.copyWith(id: localId);
      }
    } catch (e) {
      debugPrint('[RecoveryPlanService] Error generating plan: $e');
      rethrow;
    }
  }

  String _getPlanTitle(String addiction, SeverityLevel severity) {
    final severityText = severity == SeverityLevel.high 
        ? 'Intensive' 
        : severity == SeverityLevel.medium 
            ? 'Standard' 
            : 'Gentle';
    return '$severityText Recovery Plan - $addiction';
  }

  String _getPlanDescription(String addiction, SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return 'A gentle, sustainable approach to maintaining healthy habits. '
            'Focus on reinforcing positive behaviors and building long-term resilience.';
      case SeverityLevel.medium:
        return 'A structured recovery program with daily goals and accountability. '
            'Designed to help you break unhealthy patterns and establish new routines.';
      case SeverityLevel.high:
        return 'An intensive recovery program requiring daily commitment. '
            'Includes strict guidelines, frequent check-ins, and professional support recommendations.';
    }
  }

  List<RecoveryGoal> _generateDailyGoals(String addiction, SeverityLevel severity) {
    final baseGoals = <RecoveryGoal>[];

    // Universal goals
    baseGoals.add(const RecoveryGoal(
      id: 'morning_intention',
      description: 'Set a positive intention for the day',
      points: 10,
    ));

    baseGoals.add(const RecoveryGoal(
      id: 'mood_checkin',
      description: 'Track your mood and feelings',
      points: 10,
    ));

    // Severity-specific goals
    switch (severity) {
      case SeverityLevel.low:
        baseGoals.addAll([
          const RecoveryGoal(
            id: 'alternative_activity',
            description: 'Complete one alternative healthy activity',
            points: 15,
          ),
          const RecoveryGoal(
            id: 'reflection',
            description: 'Reflect on your progress for 5 minutes',
            points: 10,
          ),
        ]);
        break;

      case SeverityLevel.medium:
        baseGoals.addAll([
          const RecoveryGoal(
            id: 'time_limit',
            description: 'Stay within daily time restrictions',
            points: 20,
          ),
          const RecoveryGoal(
            id: 'alternative_activity',
            description: 'Complete two alternative activities',
            points: 15,
          ),
          const RecoveryGoal(
            id: 'trigger_log',
            description: 'Log any triggers or cravings',
            points: 10,
          ),
          const RecoveryGoal(
            id: 'support_connection',
            description: 'Connect with a support person',
            points: 15,
          ),
        ]);
        break;

      case SeverityLevel.high:
        baseGoals.addAll([
          const RecoveryGoal(
            id: 'strict_time_limit',
            description: 'Strictly follow time restrictions',
            points: 25,
          ),
          const RecoveryGoal(
            id: 'multiple_alternatives',
            description: 'Complete at least three alternative activities',
            points: 20,
          ),
          const RecoveryGoal(
            id: 'detailed_trigger_log',
            description: 'Maintain detailed trigger journal',
            points: 15,
          ),
          const RecoveryGoal(
            id: 'daily_support',
            description: 'Check in with support network',
            points: 20,
          ),
          const RecoveryGoal(
            id: 'coping_practice',
            description: 'Practice coping strategies',
            points: 15,
          ),
        ]);
        break;
    }

    baseGoals.add(const RecoveryGoal(
      id: 'evening_gratitude',
      description: 'Write down three things you\'re grateful for',
      points: 10,
    ));

    return baseGoals;
  }

  List<RecoveryMilestone> _generateMilestones(String addiction, SeverityLevel severity) {
    return [
      const RecoveryMilestone(
        id: 'first_week',
        title: 'First Week Complete',
        description: 'You\'ve completed your first 7 days!',
        targetDays: 7,
        rewardPoints: 100,
      ),
      const RecoveryMilestone(
        id: 'two_weeks',
        title: 'Two Week Warrior',
        description: '14 days of commitment and progress',
        targetDays: 14,
        rewardPoints: 200,
      ),
      const RecoveryMilestone(
        id: 'one_month',
        title: 'One Month Milestone',
        description: 'A full month of dedication!',
        targetDays: 30,
        rewardPoints: 500,
      ),
      const RecoveryMilestone(
        id: 'three_months',
        title: '90-Day Champion',
        description: 'Three months of transformation',
        targetDays: 90,
        rewardPoints: 1000,
      ),
      const RecoveryMilestone(
        id: 'six_months',
        title: 'Half-Year Hero',
        description: 'Six months of sustained recovery',
        targetDays: 180,
        rewardPoints: 2000,
      ),
      const RecoveryMilestone(
        id: 'one_year',
        title: 'One Year Anniversary',
        description: 'A full year of freedom!',
        targetDays: 365,
        rewardPoints: 5000,
      ),
    ];
  }

  List<AlternativeActivity> _generateAlternativeActivities(String addiction) {
    return [
      // Physical activities
      const AlternativeActivity(
        id: 'walk',
        title: 'Take a Walk',
        description: 'Go for a 15-minute walk outdoors',
        durationMinutes: 15,
        categories: ['physical', 'outdoor'],
      ),
      const AlternativeActivity(
        id: 'exercise',
        title: 'Quick Exercise',
        description: 'Do 10 minutes of stretching or light exercise',
        durationMinutes: 10,
        categories: ['physical', 'health'],
      ),
      const AlternativeActivity(
        id: 'breathing',
        title: 'Deep Breathing',
        description: 'Practice 5 minutes of deep breathing exercises',
        durationMinutes: 5,
        categories: ['mental', 'relaxation'],
      ),

      // Mental activities
      const AlternativeActivity(
        id: 'meditation',
        title: 'Meditation',
        description: 'Guided meditation session',
        durationMinutes: 10,
        categories: ['mental', 'mindfulness'],
      ),
      const AlternativeActivity(
        id: 'journaling',
        title: 'Journaling',
        description: 'Write about your thoughts and feelings',
        durationMinutes: 15,
        categories: ['mental', 'reflection'],
      ),
      const AlternativeActivity(
        id: 'reading',
        title: 'Read',
        description: 'Read a book or article',
        durationMinutes: 20,
        categories: ['mental', 'education'],
      ),

      // Social activities
      const AlternativeActivity(
        id: 'call_friend',
        title: 'Call a Friend',
        description: 'Connect with someone you care about',
        durationMinutes: 15,
        categories: ['social', 'connection'],
      ),
      const AlternativeActivity(
        id: 'family_time',
        title: 'Quality Time',
        description: 'Spend time with family or loved ones',
        durationMinutes: 30,
        categories: ['social', 'family'],
      ),

      // Creative activities
      const AlternativeActivity(
        id: 'art',
        title: 'Creative Expression',
        description: 'Draw, paint, or do any creative activity',
        durationMinutes: 20,
        categories: ['creative', 'mental'],
      ),
      const AlternativeActivity(
        id: 'music',
        title: 'Listen to Music',
        description: 'Enjoy your favorite calming music',
        durationMinutes: 15,
        categories: ['creative', 'relaxation'],
      ),

      // Productive activities
      const AlternativeActivity(
        id: 'organize',
        title: 'Organize Space',
        description: 'Tidy up your living or work space',
        durationMinutes: 20,
        categories: ['productive', 'physical'],
      ),
      const AlternativeActivity(
        id: 'hobby',
        title: 'Pursue a Hobby',
        description: 'Engage in a constructive hobby',
        durationMinutes: 30,
        categories: ['productive', 'creative'],
      ),
    ];
  }

  Map<String, dynamic> _generateTimeRestrictions(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return {
          'maxDailyMinutes': 90,
          'maxSessionMinutes': 30,
          'cooldownMinutes': 15,
          'enforcementLevel': 'suggestion',
        };
      case SeverityLevel.medium:
        return {
          'maxDailyMinutes': 60,
          'maxSessionMinutes': 20,
          'cooldownMinutes': 30,
          'enforcementLevel': 'warning',
        };
      case SeverityLevel.high:
        return {
          'maxDailyMinutes': 30,
          'maxSessionMinutes': 10,
          'cooldownMinutes': 60,
          'enforcementLevel': 'strict',
        };
    }
  }

  /// Adapt existing plan based on progress and relapses
  Future<RecoveryPlanModel> adaptPlan(RecoveryPlanModel currentPlan) async {
    try {
      // Re-analyze behavior
      final analysis = await _behaviorService.analyzeBehavior(
        currentPlan.uid,
        currentPlan.addiction,
      );

      // Determine if severity has changed
      var newSeverity = currentPlan.severity;
      final progressRate = currentPlan.completionPercentage;
      final relapseImpact = currentPlan.relapseCount * 15; // Each relapse adds 15 points

      // Adjust severity based on progress
      if (analysis.severityScore - relapseImpact < 30 && progressRate > 80) {
        // User is improving
        if (currentPlan.severity == SeverityLevel.high) {
          newSeverity = SeverityLevel.medium;
        } else if (currentPlan.severity == SeverityLevel.medium && progressRate > 90) {
          newSeverity = SeverityLevel.low;
        }
      } else if (analysis.severityScore + relapseImpact > 70 || currentPlan.relapseCount >= 3) {
        // User needs more support
        if (currentPlan.severity == SeverityLevel.low) {
          newSeverity = SeverityLevel.medium;
        } else if (currentPlan.severity == SeverityLevel.medium) {
          newSeverity = SeverityLevel.high;
        }
      }

      // Generate new goals and restrictions if severity changed
      final updatedPlan = newSeverity != currentPlan.severity
          ? currentPlan.copyWith(
              severity: newSeverity,
              dailyGoals: _generateDailyGoals(currentPlan.addiction, newSeverity),
              timeRestrictions: _generateTimeRestrictions(newSeverity),
              lastAdaptedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          : currentPlan.copyWith(
              lastAdaptedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

      // Update in Firestore
      if (currentPlan.id != null) {
        await _firestore
            .collection('users')
            .doc(currentPlan.uid)
            .collection('recoveryPlans')
            .doc(currentPlan.id)
            .update(updatedPlan.toMap());
      }

      debugPrint('[RecoveryPlanService] Plan adapted: ${currentPlan.severity.name} → ${newSeverity.name}');
      return updatedPlan;
    } catch (e) {
      debugPrint('[RecoveryPlanService] Error adapting plan: $e');
      rethrow;
    }
  }

  /// Mark a goal as completed
  Future<RecoveryPlanModel> completeGoal(RecoveryPlanModel plan, String goalId) async {
    final updatedGoals = plan.dailyGoals.map((goal) {
      if (goal.id == goalId) {
        return goal.copyWith(
          completed: true,
          completedAt: DateTime.now(),
        );
      }
      return goal;
    }).toList();

    final completedGoal = updatedGoals.firstWhere((g) => g.id == goalId);
    final newPoints = plan.totalPoints + completedGoal.points;

    final updatedPlan = plan.copyWith(
      dailyGoals: updatedGoals,
      totalPoints: newPoints,
      updatedAt: DateTime.now(),
    );

    // Try to update in Firestore (but continue if it fails)
    try {
      if (plan.id != null) {
        await _firestore
            .collection('users')
            .doc(plan.uid)
            .collection('recoveryPlans')
            .doc(plan.id)
            .update(updatedPlan.toMap());
        debugPrint('[RecoveryPlanService] Goal completed and saved to Firestore');
      }
    } catch (e) {
      debugPrint('[RecoveryPlanService] Firestore update failed (working locally): $e');
    }

    // Add tree growth points for completing recovery goals (also resilient)
    await _addTreeGrowth(plan.uid, completedGoal.points);

    return updatedPlan;
  }

  /// Add tree growth points (mirrors FirestoreService implementation)
  Future<void> _addTreeGrowth(String uid, int points) async {
    try {
      debugPrint('[RecoveryPlanService] Adding tree growth: $points points for recovery goal');

      final treeDoc = await _firestore.collection('trees').doc(uid).get();
      
      final currentPoints = treeDoc.exists 
          ? (treeDoc.data()?['totalGrowthPoints'] as int? ?? 0)
          : 0;
      
      final newPoints = currentPoints + points;
      // Each 500 points grows one stage; keep stages bounded to avoid runaway values
      final growthLevel = (newPoints ~/ 500).clamp(0, 100);

      final createdAtValue = treeDoc.exists && treeDoc.data() != null
          ? treeDoc.data()!['createdAt']
          : Timestamp.now();

      await _firestore.collection('trees').doc(uid).set({
        'uid': uid,
        'growthLevel': growthLevel,
        'totalGrowthPoints': newPoints,
        'createdAt': createdAtValue,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));

      debugPrint('[RecoveryPlanService] Tree growth updated: $newPoints total points (level $growthLevel)');
    } catch (e) {
      debugPrint('[RecoveryPlanService] _addTreeGrowth error: $e');
    }
  }

  /// Record a relapse
  Future<RecoveryPlanModel> recordRelapse(RecoveryPlanModel plan) async {
    try {
      final updatedPlan = plan.copyWith(
        relapseCount: plan.relapseCount + 1,
        lastRelapseDate: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Update in Firestore
      if (plan.id != null) {
        await _firestore
            .collection('users')
            .doc(plan.uid)
            .collection('recoveryPlans')
            .doc(plan.id)
            .update(updatedPlan.toMap());
      }

      // Trigger plan adaptation if needed
      if (updatedPlan.relapseCount >= 2) {
        return await adaptPlan(updatedPlan);
      }

      return updatedPlan;
    } catch (e) {
      debugPrint('[RecoveryPlanService] Error recording relapse: $e');
      rethrow;
    }
  }

  /// Update plan status
  Future<void> updatePlanStatus(
    String uid,
    String planId,
    RecoveryPlanStatus status,
  ) async {
    try {
      final updates = <String, dynamic>{
        'status': status.name,
        'updatedAt': Timestamp.now(),
      };

      if (status == RecoveryPlanStatus.completed) {
        updates['completedAt'] = Timestamp.now();
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('recoveryPlans')
          .doc(planId)
          .update(updates);

      debugPrint('[RecoveryPlanService] Plan status updated to ${status.name}');
    } catch (e) {
      debugPrint('[RecoveryPlanService] Error updating plan status: $e');
      rethrow;
    }
  }

  /// Get active recovery plan for user
  Future<RecoveryPlanModel?> getActivePlan(String uid, String addiction) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('recoveryPlans')
          .where('addiction', isEqualTo: addiction)
          .where('status', isEqualTo: RecoveryPlanStatus.active.name)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return RecoveryPlanModel.fromMap({...doc.data(), 'id': doc.id});
    } catch (e) {
      debugPrint('[RecoveryPlanService] Error getting active plan: $e');
      return null;
    }
  }

  /// Get all recovery plans for user
  Future<List<RecoveryPlanModel>> getAllPlans(String uid) async {
    try {
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
      debugPrint('[RecoveryPlanService] Error getting all plans: $e');
      return [];
    }
  }
}

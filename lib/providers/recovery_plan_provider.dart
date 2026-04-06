import 'package:flutter/foundation.dart';
import '../models/recovery_plan_model.dart';
import '../services/recovery_plan_service.dart';
import '../services/ai_recovery_plan_service.dart';
import '../services/behavior_analysis_service.dart';

class RecoveryPlanProvider extends ChangeNotifier {
  final RecoveryPlanService _planService = RecoveryPlanService();
  final AIRecoveryPlanService _aiService = AIRecoveryPlanService();
  final BehaviorAnalysisService _behaviorService = BehaviorAnalysisService();
  
  bool _isAIInitialized = false;

  List<RecoveryPlanModel> _plans = [];
  RecoveryPlanModel? _activePlan;
  BehaviorAnalysisResult? _latestAnalysis;
  bool _isLoading = false;
  String? _error;

  List<RecoveryPlanModel> get plans => _plans;
  RecoveryPlanModel? get activePlan => _activePlan;
  BehaviorAnalysisResult? get latestAnalysis => _latestAnalysis;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all recovery plans for user
  Future<void> loadRecoveryPlans(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      _plans = await _planService.getAllPlans(uid);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('[RecoveryPlanProvider] Error loading plans: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load active recovery plan for specific addiction
  Future<void> loadActivePlan(String uid, String addiction) async {
    _isLoading = true;
    notifyListeners();

    try {
      _activePlan = await _planService.getActivePlan(uid, addiction);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('[RecoveryPlanProvider] Error loading active plan: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Run behavior analysis and store results
  Future<void> analyzeBehavior(String uid, String addiction) async {
    _isLoading = true;
    notifyListeners();

    try {
      _latestAnalysis = await _behaviorService.analyzeBehavior(uid, addiction);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('[RecoveryPlanProvider] Error analyzing behavior: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Initialize AI service (call once on app start)
  Future<void> initializeAI() async {
    if (_isAIInitialized) return;
    
    try {
      await _aiService.initialize();
      _isAIInitialized = true;
      debugPrint('[RecoveryPlanProvider] ✓ AI service initialized');
    } catch (e) {
      debugPrint('[RecoveryPlanProvider] ⚠ AI initialization failed: $e');
      _isAIInitialized = false;
    }
  }

  /// Generate new recovery plan using AI (preferred) or rule-based (fallback)
  Future<bool> generateRecoveryPlan(String uid, String addiction) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize AI if not already done
      if (!_isAIInitialized) {
        await initializeAI();
      }

      // Try AI service first, fall back to rule-based
      RecoveryPlanModel plan;
      if (_isAIInitialized) {
        try {
          plan = await _aiService.generateAIPlan(uid, addiction);
          debugPrint('[RecoveryPlanProvider] ✓ AI plan generated');
        } catch (aiError) {
          debugPrint('[RecoveryPlanProvider] ⚠ AI failed, using rule-based: $aiError');
          plan = await _planService.generatePlan(uid, addiction);
        }
      } else {
        plan = await _planService.generatePlan(uid, addiction);
        debugPrint('[RecoveryPlanProvider] Using rule-based plan (AI not available)');
      }
      
      _activePlan = plan;
      await loadRecoveryPlans(uid); // Refresh full list
      _error = null;
      
      debugPrint('[RecoveryPlanProvider] Recovery plan generated successfully');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[RecoveryPlanProvider] Error generating plan: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Complete a goal in the recovery plan
  Future<bool> completeGoal(String goalId) async {
    if (_activePlan == null) return false;

    try {
      final updatedPlan = await _planService.completeGoal(_activePlan!, goalId);
      _activePlan = updatedPlan;
      
      // Update in plans list
      final index = _plans.indexWhere((p) => p.id == updatedPlan.id);
      if (index != -1) {
        _plans[index] = updatedPlan;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[RecoveryPlanProvider] Error completing goal: $e');
      return false;
    }
  }

  /// Record a relapse
  Future<bool> recordRelapse() async {
    if (_activePlan == null) return false;

    try {
      final updatedPlan = await _planService.recordRelapse(_activePlan!);
      _activePlan = updatedPlan;
      
      // Update in plans list
      final index = _plans.indexWhere((p) => p.id == updatedPlan.id);
      if (index != -1) {
        _plans[index] = updatedPlan;
      }
      
      notifyListeners();
      debugPrint('[RecoveryPlanProvider] Relapse recorded');
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[RecoveryPlanProvider] Error recording relapse: $e');
      return false;
    }
  }

  /// Adapt current plan based on progress
  Future<bool> adaptPlan() async {
    if (_activePlan == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final adaptedPlan = await _planService.adaptPlan(_activePlan!);
      _activePlan = adaptedPlan;
      
      // Update in plans list
      final index = _plans.indexWhere((p) => p.id == adaptedPlan.id);
      if (index != -1) {
        _plans[index] = adaptedPlan;
      }
      
      _error = null;
      debugPrint('[RecoveryPlanProvider] Plan adapted successfully');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[RecoveryPlanProvider] Error adapting plan: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update plan status (pause/resume/complete)
  Future<bool> updatePlanStatus(
    String uid,
    String planId,
    RecoveryPlanStatus status,
  ) async {
    try {
      await _planService.updatePlanStatus(uid, planId, status);
      
      if (_activePlan?.id == planId) {
        _activePlan = _activePlan!.copyWith(status: status);
      }
      
      // Update in plans list
      final index = _plans.indexWhere((p) => p.id == planId);
      if (index != -1) {
        _plans[index] = _plans[index].copyWith(status: status);
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[RecoveryPlanProvider] Error updating plan status: $e');
      return false;
    }
  }

  /// Check if plan needs adaptation and trigger if necessary
  Future<void> checkAndAdaptIfNeeded() async {
    if (_activePlan != null && _activePlan!.needsAdaptation) {
      debugPrint('[RecoveryPlanProvider] Plan needs adaptation, triggering...');
      await adaptPlan();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
import 'package:flutter/foundation.dart';
import '../models/recovery_plan_model.dart';
import '../services/ai_recovery_plan_service.dart';

/// Provider for AI-powered recovery plan generation
/// This replaces rule-based planning with machine learning predictions
class AIRecoveryPlanProvider extends ChangeNotifier {
  final AIRecoveryPlanService _aiService = AIRecoveryPlanService();

  RecoveryPlanModel? _currentPlan;
  Map<String, double>? _predictionConfidence;
  String? _predictedSeverity;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // Getters
  RecoveryPlanModel? get currentPlan => _currentPlan;
  Map<String, double>? get predictionConfidence => _predictionConfidence;
  String? get predictedSeverity => _predictedSeverity;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize the AI service and load TFLite model
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _aiService.initialize();
      _isInitialized = true;
      _error = null;
      debugPrint('[AIRecoveryPlanProvider] AI service initialized successfully');
    } catch (e) {
      _error = 'Failed to initialize AI service: $e';
      debugPrint('[AIRecoveryPlanProvider] Initialization error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Generate AI-powered recovery plan
  Future<bool> generateAIPlan(String uid, String addiction) async {
    if (!_isInitialized) {
      await initialize();
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Generate plan using AI (no fallback)
      final plan = await _aiService.generateAIPlan(uid, addiction);

      _currentPlan = plan;

      // Extract prediction metadata from timeRestrictions
      final metadata = plan.timeRestrictions;
      if (metadata != null) {
        if (metadata.containsKey('severity_prediction')) {
          _predictedSeverity = metadata['severity_prediction'] as String?;
        }

        if (metadata.containsKey('prediction_confidence')) {
          final confidence = metadata['prediction_confidence'];
          if (confidence is Map) {
            _predictionConfidence = Map<String, double>.from(
              confidence.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
            );
          }
        }
      }

      debugPrint('[AIRecoveryPlanProvider] AI plan generated successfully');
      debugPrint('[AIRecoveryPlanProvider] Predicted severity: $_predictedSeverity');
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to generate AI plan: $e';
      debugPrint('[AIRecoveryPlanProvider] Error generating plan: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get confidence score for a specific severity level
  double getConfidenceForSeverity(String severity) {
    if (_predictionConfidence == null) return 0.0;
    return _predictionConfidence![severity.toLowerCase()] ?? 0.0;
  }

  /// Check if AI model is using fallback (rule-based)
  bool isUsingFallback() {
    return false; // Fallback removed by request
  }

  /// Get human-readable prediction summary
  String getPredictionSummary() {
    if (_predictedSeverity == null) return 'No prediction available';
    
    final confidence = getConfidenceForSeverity(_predictedSeverity!);
    final percentage = (confidence * 100).toStringAsFixed(1);
    
    return 'Severity: ${_predictedSeverity!.toUpperCase()} ($percentage% confidence)';
  }

  /// Clear current plan
  void clearPlan() {
    _currentPlan = null;
    _predictionConfidence = null;
    _predictedSeverity = null;
    _error = null;
    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    super.dispose();
  }
}

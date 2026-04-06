import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class RecoveryPlanRequest {
  RecoveryPlanRequest({
    required this.addictionType,
    required this.dailyUsage,
    required this.moodScore,
    required this.taskCompletionRate,
    required this.relapseCount,
  });

  final String addictionType;
  final double dailyUsage;
  final double moodScore; // 0-10
  final double taskCompletionRate; // 0.0-1.0
  final int relapseCount;

  Map<String, dynamic> toJson() => {
        'addiction_type': addictionType,
        'daily_usage': dailyUsage,
        'mood_score': moodScore,
        'task_completion_rate': taskCompletionRate,
        'relapse_count': relapseCount,
      };
}

class RecoveryPlanResponse {
  RecoveryPlanResponse({
    required this.riskLevel,
    required this.confidence,
    required this.goals,
    required this.tips,
    required this.source,
    required this.modelVersion,
  });

  final String riskLevel; // low|medium|high
  final double confidence; // 0.0-1.0
  final List<String> goals;
  final List<String> tips;
  final String source; // ai|fallback
  final String modelVersion;

  factory RecoveryPlanResponse.fromJson(Map<String, dynamic> json) {
    return RecoveryPlanResponse(
      riskLevel: json['risk_level'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      goals: List<String>.from(json['goals'] as List),
      tips: List<String>.from(json['tips'] as List),
      source: json['source'] as String,
      modelVersion: json['model_version'] as String,
    );
  }
}

class AiApiClient {
  AiApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  static String get _defaultBaseUrl {
    // Android emulator needs 10.0.2.2 to reach host; others use localhost.
    final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    return 'http://$host:8000';
  }

  Future<bool> health() async {
    final resp = await _client.get(Uri.parse('$_baseUrl/health'));
    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['status'] == 'healthy';
  }

  Future<RecoveryPlanResponse> getRecoveryPlan(RecoveryPlanRequest request) async {
    final resp = await _client.post(
      Uri.parse('$_baseUrl/get_recovery_plan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (resp.statusCode != 200) {
      throw Exception('API error ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return RecoveryPlanResponse.fromJson(data);
  }
}

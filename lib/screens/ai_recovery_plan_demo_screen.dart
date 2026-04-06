import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_recovery_plan_provider.dart';
import '../providers/user_provider.dart';

/// Demo screen to test AI-powered recovery plan generation
class AIRecoveryPlanDemoScreen extends StatefulWidget {
  const AIRecoveryPlanDemoScreen({super.key});

  @override
  State<AIRecoveryPlanDemoScreen> createState() => _AIRecoveryPlanDemoScreenState();
}

class _AIRecoveryPlanDemoScreenState extends State<AIRecoveryPlanDemoScreen> {
  String _selectedAddiction = 'Alcohol';
  final List<String> _addictions = [
    'Alcohol',
    'Smoking',
    'Gambling',
    'Social Media',
    'Gaming',
    'Shopping',
    'Substance',
  ];

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AIRecoveryPlanProvider>();
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Recovery Plan Generator'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Initialization Status
            _buildStatusCard(aiProvider),
            const SizedBox(height: 16),

            // Addiction Selection
            _buildAddictionSelector(),
            const SizedBox(height: 16),

            // Generate Button
            _buildGenerateButton(aiProvider, userProvider),
            const SizedBox(height: 24),

            // Results
            if (aiProvider.currentPlan != null) ...[
              _buildResultsCard(aiProvider),
              const SizedBox(height: 16),
              _buildGoalsList(aiProvider),
            ],

            // Error Display
            if (aiProvider.error != null)
              _buildErrorCard(aiProvider.error!),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(AIRecoveryPlanProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  provider.isInitialized ? Icons.check_circle : Icons.pending,
                  color: provider.isInitialized ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Service Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              provider.isInitialized
                  ? '✓ AI model loaded and ready'
                  : provider.isLoading
                      ? 'Loading AI model...'
                      : 'Initializing...',
              style: TextStyle(
                color: provider.isInitialized ? Colors.green : Colors.grey,
              ),
            ),
            if (provider.isUsingFallback())
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'ℹ️ Using rule-based fallback (TFLite not available)',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddictionSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Addiction Type',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedAddiction,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _addictions.map((addiction) {
                return DropdownMenuItem(
                  value: addiction,
                  child: Text(addiction),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedAddiction = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton(
    AIRecoveryPlanProvider aiProvider,
    UserProvider userProvider,
  ) {
    return ElevatedButton.icon(
      onPressed: aiProvider.isLoading
          ? null
          : () async {
              final uid = userProvider.user?.uid;
              if (uid == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please log in first')),
                );
                return;
              }

              final success = await aiProvider.generateAIPlan(uid, _selectedAddiction);
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ AI Recovery Plan Generated!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
      icon: aiProvider.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.psychology),
      label: Text(
        aiProvider.isLoading
            ? 'Generating AI Plan...'
            : 'Generate AI Recovery Plan',
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildResultsCard(AIRecoveryPlanProvider provider) {
    final plan = provider.currentPlan!;
    
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'AI Prediction Results',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Severity
            _buildInfoRow(
              'Predicted Severity',
              provider.predictedSeverity?.toUpperCase() ?? 'N/A',
              _getSeverityColor(provider.predictedSeverity),
            ),
            const SizedBox(height: 8),
            
            // Confidence
            _buildInfoRow(
              'Confidence Score',
              provider.getPredictionSummary(),
              Colors.black87,
            ),
            const SizedBox(height: 8),
            
            // Goals Count
            _buildInfoRow(
              'Personalized Goals',
              '${plan.dailyGoals.length} goals',
              Colors.black87,
            ),
            const SizedBox(height: 8),
            
            // Confidence breakdown
            if (provider.predictionConfidence != null) ...[
              const SizedBox(height: 16),
              Text(
                'Confidence Breakdown:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...provider.predictionConfidence!.entries.map((entry) {
                final percentage = (entry.value * 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${entry.key.toUpperCase()}:'),
                      Text('$percentage%'),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsList(AIRecoveryPlanProvider provider) {
    final plan = provider.currentPlan!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personalized Goals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...plan.dailyGoals.asMap().entries.map((entry) {
              final index = entry.key;
              final goal = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.description,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${goal.points} points',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(String? severity) {
    if (severity == null) return Colors.grey;
    switch (severity.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

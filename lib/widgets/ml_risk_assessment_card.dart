import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ml_prediction_provider.dart';
import '../providers/user_provider.dart';
import '../providers/task_provider.dart';
import '../providers/mood_provider.dart';

class MLRiskAssessmentCard extends StatefulWidget {
  const MLRiskAssessmentCard({super.key});

  @override
  State<MLRiskAssessmentCard> createState() => _MLRiskAssessmentCardState();
}

class _MLRiskAssessmentCardState extends State<MLRiskAssessmentCard> {
  bool _isAnalyzing = false;

  Future<void> _runPrediction() async {
    if (_isAnalyzing) return;

    setState(() => _isAnalyzing = true);

    final mlProvider = Provider.of<MLPredictionProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final moodProvider = Provider.of<MoodProvider>(context, listen: false);

    final user = userProvider.user;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first')),
        );
        setState(() => _isAnalyzing = false);
      }
      return;
    }

    await mlProvider.predictRelapseRisk(
      user: user,
      recentTasks: taskProvider.allTasks,
      recentMoods: moodProvider.moods,
    );

    setState(() => _isAnalyzing = false);

    if (mounted && mlProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mlProvider.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MLPredictionProvider>(
      builder: (context, mlProvider, _) {
        final hasData = mlProvider.relapseRisk != null;
        final isStale = mlProvider.isPredictionStale;
        
        return Card(
          elevation: 4,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          color: Theme.of(context).primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Relapse Risk Assessment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (mlProvider.isMLAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 14, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              'ML',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Risk Display
                if (!hasData) ...[
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No risk assessment available yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Analyze Risk" to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Risk Score Display
                  Center(
                    child: Column(
                      children: [
                        // Circular Progress Indicator
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: mlProvider.relapseRisk!,
                                strokeWidth: 12,
                                backgroundColor: Colors.grey[200],
                                color: mlProvider.getRiskColor(),
                              ),
                              Center(
                                child: Text(
                                  '${(mlProvider.relapseRisk! * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: mlProvider.getRiskColor(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Risk Category
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: mlProvider.getRiskColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: mlProvider.getRiskColor(),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '${mlProvider.riskCategory} Risk',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: mlProvider.getRiskColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Recommendation
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mlProvider.recommendation ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Last Updated
                  if (mlProvider.lastPredictionTime != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: isStale ? Colors.orange : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Last updated: ${_formatTime(mlProvider.lastPredictionTime!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isStale ? Colors.orange : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (isStale) ...[
                          const SizedBox(width: 8),
                          const Text(
                            '(Update recommended)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],

                const SizedBox(height: 20),

                // Analyze Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing || mlProvider.isLoading
                        ? null
                        : _runPrediction,
                    icon: _isAnalyzing || mlProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics),
                    label: Text(
                      _isAnalyzing || mlProvider.isLoading
                          ? 'Analyzing...'
                          : hasData
                              ? 'Refresh Analysis'
                              : 'Analyze Risk',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                // Error Display
                if (mlProvider.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mlProvider.error!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[900],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => mlProvider.clearError(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recovery_plan_provider.dart';
import '../providers/tree_provider.dart';
import '../providers/user_provider.dart';
import '../models/recovery_plan_model.dart';

class RecoveryPlanScreen extends StatefulWidget {
  const RecoveryPlanScreen({super.key});

  @override
  State<RecoveryPlanScreen> createState() => _RecoveryPlanScreenState();
}

class _RecoveryPlanScreenState extends State<RecoveryPlanScreen> {
  String? _selectedAddiction;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userProvider = context.read<UserProvider>();
    final recoveryProvider = context.read<RecoveryPlanProvider>();
    
    if (userProvider.user != null) {
      await recoveryProvider.loadRecoveryPlans(userProvider.user!.uid);
      
      // Load active plan for first addiction if exists
      if (userProvider.user!.addictions.isNotEmpty) {
        _selectedAddiction = userProvider.user!.addictions.first;
        await recoveryProvider.loadActivePlan(
          userProvider.user!.uid,
          _selectedAddiction!,
        );
      }
    }
  }

  Future<void> _generateNewPlan() async {
    if (_selectedAddiction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an addiction type first')),
      );
      return;
    }

    final userProvider = context.read<UserProvider>();
    final recoveryProvider = context.read<RecoveryPlanProvider>();

    if (userProvider.user == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Run behavior analysis first
    await recoveryProvider.analyzeBehavior(
      userProvider.user!.uid,
      _selectedAddiction!,
    );

    // Generate plan
    final success = await recoveryProvider.generateRecoveryPlan(
      userProvider.user!.uid,
      _selectedAddiction!,
    );

    if (mounted) Navigator.of(context).pop(); // Close loading dialog

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovery plan generated successfully!')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(recoveryProvider.error ?? 'Failed to generate plan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer2<RecoveryPlanProvider, UserProvider>(
        builder: (context, recoveryProvider, userProvider, _) {
          if (recoveryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final activePlan = recoveryProvider.activePlan;

          if (activePlan == null) {
            return _buildNoPlanView(userProvider);
          }

          return _buildPlanView(activePlan, recoveryProvider, userProvider);
        },
      ),
    );
  }

  Widget _buildNoPlanView(UserProvider userProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.healing, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'No Active Recovery Plan',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create a personalized recovery plan based on your behavior analysis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            // Addiction selector
            if (userProvider.user != null && userProvider.user!.addictions.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedAddiction,
                decoration: const InputDecoration(
                  labelText: 'Select Addiction Type',
                  border: OutlineInputBorder(),
                ),
                items: userProvider.user!.addictions.map((addiction) {
                  return DropdownMenuItem(
                    value: addiction,
                    child: Text(addiction),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAddiction = value;
                  });
                },
              ),
            
            const SizedBox(height: 24),
            
            ElevatedButton.icon(
              onPressed: _generateNewPlan,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Recovery Plan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanView(
    RecoveryPlanModel plan,
    RecoveryPlanProvider provider,
    UserProvider userProvider,
  ) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPlanHeader(plan),
          const SizedBox(height: 24),
          _buildSeverityIndicator(plan),
          const SizedBox(height: 24),
          _buildProgressCard(plan),
          const SizedBox(height: 24),
          _buildDailyGoals(plan, provider),
          const SizedBox(height: 24),
          _buildMilestones(plan),
          const SizedBox(height: 24),
          _buildAlternativeActivities(plan),
          const SizedBox(height: 24),
          _buildTimeRestrictions(plan),
          const SizedBox(height: 24),
          _buildPlanControls(plan, provider, userProvider),
        ],
      ),
    );
  }

  Widget _buildPlanHeader(RecoveryPlanModel plan) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.spa, size: 32, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        plan.addiction,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(plan.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              plan.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text('Day ${plan.currentDay}'),
                const Spacer(),
                const Icon(Icons.emoji_events, size: 16),
                const SizedBox(width: 8),
                Text('${plan.totalPoints} points'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(RecoveryPlanStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case RecoveryPlanStatus.active:
        color = Colors.green;
        label = 'Active';
        break;
      case RecoveryPlanStatus.paused:
        color = Colors.orange;
        label = 'Paused';
        break;
      case RecoveryPlanStatus.completed:
        color = Colors.blue;
        label = 'Completed';
        break;
      case RecoveryPlanStatus.abandoned:
        color = Colors.red;
        label = 'Abandoned';
        break;
    }
    
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }

  Widget _buildSeverityIndicator(RecoveryPlanModel plan) {
    Color color;
    String label;
    IconData icon;
    
    switch (plan.severity) {
      case SeverityLevel.low:
        color = Colors.green;
        label = 'Low Severity - Gentle Approach';
        icon = Icons.sentiment_satisfied;
        break;
      case SeverityLevel.medium:
        color = Colors.orange;
        label = 'Medium Severity - Standard Program';
        icon = Icons.sentiment_neutral;
        break;
      case SeverityLevel.high:
        color = Colors.red;
        label = 'High Severity - Intensive Support';
        icon = Icons.sentiment_dissatisfied;
        break;
    }
    
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Plan adapts automatically based on your progress',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(RecoveryPlanModel plan) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: plan.completionPercentage / 100,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                plan.completionPercentage >= 100 ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${plan.completionPercentage.toStringAsFixed(0)}% Complete',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (plan.relapseCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('${plan.relapseCount} relapse${plan.relapseCount > 1 ? 's' : ''} recorded'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDailyGoals(RecoveryPlanModel plan, RecoveryPlanProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Goals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...plan.dailyGoals.map((goal) => CheckboxListTile(
              title: Text(goal.description),
              subtitle: Text('${goal.points} points'),
              value: goal.completed,
              onChanged: goal.completed
                  ? null
                  : (value) async {
                      if (value == true) {
                        final userProvider = context.read<UserProvider>();
                        final treeProvider = context.read<TreeProvider>();
                        
                        await provider.completeGoal(goal.id);
                        
                        // Reload tree to show updated points
                        if (userProvider.user != null) {
                          await treeProvider.loadTree(userProvider.user!.uid);
                        }
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Goal completed! +${goal.points} points 🌱')),
                          );
                        }
                      }
                    },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestones(RecoveryPlanModel plan) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Milestones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...plan.milestones.map((milestone) => ListTile(
              leading: Icon(
                milestone.achieved ? Icons.check_circle : Icons.radio_button_unchecked,
                color: milestone.achieved ? Colors.green : Colors.grey,
              ),
              title: Text(milestone.title),
              subtitle: Text('Day ${milestone.targetDays} • ${milestone.rewardPoints} points'),
              trailing: milestone.achieved
                  ? const Icon(Icons.emoji_events, color: Colors.amber)
                  : null,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativeActivities(RecoveryPlanModel plan) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alternative Activities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Try these when you feel an urge',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: plan.alternativeActivities.map((activity) => ActionChip(
                avatar: const Icon(Icons.lightbulb_outline, size: 18),
                label: Text(activity.title),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(activity.title),
                      content: Text('${activity.description}\n\nDuration: ${activity.durationMinutes} minutes'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRestrictions(RecoveryPlanModel plan) {
    if (plan.timeRestrictions == null) return const SizedBox.shrink();

    final restrictions = plan.timeRestrictions!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Time Restrictions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Daily Limit'),
              trailing: Text('${restrictions['maxDailyMinutes']} min'),
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Session Limit'),
              trailing: Text('${restrictions['maxSessionMinutes']} min'),
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_empty),
              title: const Text('Cooldown Period'),
              trailing: Text('${restrictions['cooldownMinutes']} min'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanControls(
    RecoveryPlanModel plan,
    RecoveryPlanProvider provider,
    UserProvider userProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Plan Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (plan.status == RecoveryPlanStatus.active) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  await provider.updatePlanStatus(
                    userProvider.user!.uid,
                    plan.id!,
                    RecoveryPlanStatus.paused,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Plan paused')),
                    );
                  }
                },
                icon: const Icon(Icons.pause),
                label: const Text('Pause Plan'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Record Relapse'),
                      content: const Text('This will be recorded in your plan. Are you sure?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirmed == true) {
                    await provider.recordRelapse();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Relapse recorded. Don\'t give up - recovery is a journey.'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.report_problem),
                label: const Text('Record Relapse'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ] else if (plan.status == RecoveryPlanStatus.paused) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  await provider.updatePlanStatus(
                    userProvider.user!.uid,
                    plan.id!,
                    RecoveryPlanStatus.active,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Plan resumed')),
                    );
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume Plan'),
              ),
            ],
            
            const SizedBox(height: 8),
            
            if (plan.needsAdaptation)
              ElevatedButton.icon(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );
                  
                  await provider.adaptPlan();
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Plan adapted based on your progress!')),
                    );
                  }
                },
                icon: const Icon(Icons.autorenew),
                label: const Text('Adapt Plan'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              ),
          ],
        ),
      ),
    );
  }
}

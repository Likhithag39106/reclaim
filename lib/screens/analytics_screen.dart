import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/user_provider.dart';
import '../providers/task_provider.dart';
import '../providers/mood_provider.dart';
import '../models/task_model.dart';
import '../models/mood_model.dart';
import '../services/firestore_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<DateTime> _loginEvents = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<UserProvider>().user;
      if (user != null) {
        await context.read<TaskProvider>().loadUserTasks(user.uid);
        await context.read<MoodProvider>().loadWeeklyMoods(user.uid);
      }
    });
  }

  Future<void> _loadData() async {
    final user = context.read<UserProvider>().user;
    if (user != null) {
      await context.read<TaskProvider>().loadUserTasks(user.uid);
      await context.read<MoodProvider>().loadWeeklyMoods(user.uid);
      _loginEvents = await _firestoreService.getRecentLogins(user.uid, days: 30);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () async {
            final user = context.read<UserProvider>().user;
            if (user == null) return;
            final repaired = await _firestoreService.backfillCompletedAt(user.uid);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Repaired $repaired tasks with missing timestamps')),
            );
            await _loadData();
          },
          child: const Text('Analytics'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Consumer<TaskProvider>(
              builder: (_, taskProvider, __) {
                final all = taskProvider.allTasks ?? <TaskModel>[];
                final completed = all.where((t) => t.completed).length;
                final weekAgo = DateTime.now().subtract(const Duration(days: 7));
                final thisWeek = all
                    .where((t) => t.createdAt != null && t.createdAt!.isAfter(weekAgo) && t.completed)
                    .length;
                final success = all.isEmpty ? 0.0 : (completed / all.length * 100);

                return Row(
                  children: [
                    Expanded(child: _statCard('Total Completions', '$completed', Colors.blue)),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard('This Week', '$thisWeek', Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard('Success Rate', '${success.toStringAsFixed(0)}%', Colors.purple)),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            const Text('30-Day Trend', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Consumer<TaskProvider>(
              builder: (_, taskProvider, __) => _thirtyDayChart(
                taskProvider.allTasks ?? <TaskModel>[],
                _loginEvents,
              ),
            ),
            const SizedBox(height: 24),

            const Text('Weekly Mood Trend', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Consumer<MoodProvider>(
              builder: (_, moodProvider, __) => _moodChart(moodProvider.weeklyMoods),
            ),
            const SizedBox(height: 24),

            const Text('Achievements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Consumer<TaskProvider>(
              builder: (_, taskProvider, __) => _achievements(taskProvider.streak),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _thirtyDayChart(List<TaskModel> tasks, List<DateTime> loginEvents) {
    debugPrint('[Analytics] 30-day chart: ${tasks.length} total tasks');
    
    final completedTasks = tasks.where((t) => t.completed).toList();
    debugPrint('[Analytics] Completed tasks: ${completedTasks.length}');
    for (final t in completedTasks) {
      debugPrint('[Analytics] Task: ${t.title}, completed: ${t.completed}, completedAt: ${t.completedAt}');
    }
    
    final Map<DateTime, int> perDay = {};
    for (final t in tasks) {
      if (!t.completed) continue;
      DateTime? when = t.completedAt ?? t.updatedAt ?? t.createdAt;
      if (when == null) continue;
      final d = DateTime(when.year, when.month, when.day);
      perDay[d] = (perDay[d] ?? 0) + 1;
      debugPrint('[Analytics] Mapped task to date: $d (source: '
          '${t.completedAt != null ? 'completedAt' : t.updatedAt != null ? 'updatedAt' : 'createdAt'})');
    }

    // Add login events so daily logins count toward the trend
    for (final e in loginEvents) {
      final d = DateTime(e.year, e.month, e.day);
      perDay[d] = (perDay[d] ?? 0) + 1;
      debugPrint('[Analytics] Mapped login to date: $d');
    }
    
    debugPrint('[Analytics] Completed tasks by day: ${perDay.length} days have data');
    for (final entry in perDay.entries) {
      debugPrint('[Analytics]   ${entry.key}: ${entry.value} tasks');
    }

    final now = DateTime.now();
    final spots = <FlSpot>[];
    for (int i = 29; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final count = perDay[d] ?? 0;
      spots.add(FlSpot((29 - i).toDouble(), count.toDouble()));
    }
    
    debugPrint('[Analytics] 30-day spots: ${spots.map((s) => '(${s.x},${s.y})').join(', ')}');

    double maxY = 1;
    if (spots.isNotEmpty) {
      final maxVal = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      maxY = (maxVal > 0 ? maxVal : 1) + 1;
    }

    // Check if there's any data
    final hasData = spots.any((s) => s.y > 0);
    if (!hasData) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No task data yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete tasks to see your 30-day trend',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey[300]!, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 5,
                    getTitlesWidget: (value, _) {
                      final intIndex = value.toInt().clamp(0, 29);
                      final d = now.subtract(Duration(days: (29 - intIndex)));
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('${d.month}/${d.day}', style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 29,
              minY: 0,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.green,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [Colors.green.withValues(alpha: 0.25), Colors.green.withValues(alpha: 0.0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _moodChart(List<MoodModel> moods) {
    debugPrint('[Analytics] Mood chart data: ${moods.length} moods');
    for (final m in moods) {
      debugPrint('[Analytics] Mood: ${m.mood} (rating: ${m.rating}) at ${m.createdAt.weekday}');
    }
    
    if (moods.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text('No mood data yet', style: TextStyle(color: Colors.grey[600]))),
        ),
      );
    }

    final Map<int, List<int>> byDay = {};
    for (final m in moods) {
      final key = m.createdAt.weekday;
      byDay[key] = [...?byDay[key], m.rating];
    }
    
    debugPrint('[Analytics] By day: $byDay');

    final spots = <FlSpot>[];
    for (int i = 1; i <= 7; i++) {
      final vals = byDay[i];
      final avg = vals == null || vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
      spots.add(FlSpot((i - 1).toDouble(), avg));
      debugPrint('[Analytics] Day $i: avg = $avg, vals = $vals');
    }
    
    debugPrint('[Analytics] Spots: ${spots.map((s) => '(${s.x},${s.y})').join(', ')}');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey[300]!, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, _) {
                      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      final i = value.toInt();
                      return i >= 0 && i < days.length
                          ? Text(days[i], style: const TextStyle(fontSize: 10))
                          : const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 40,
                    getTitlesWidget: (value, _) {
                      const emojis = ['😤', '😔', '😐', '😌', '😊'];
                      final vi = value.toInt();
                      return (vi >= 1 && vi <= 5) ? Text(emojis[vi - 1]) : const Text('');
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: 6,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [Colors.blue.withValues(alpha: 0.25), Colors.blue.withValues(alpha: 0.0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _achievements(int streak) {
    final items = [
      {'emoji': '🌸', 'title': 'Week Strong', 'days': 7, 'ok': streak >= 7},
      {'emoji': '🌳', 'title': 'Month Warrior', 'days': 30, 'ok': streak >= 30},
      {'emoji': '🌲', 'title': 'Forest Guardian', 'days': 90, 'ok': streak >= 90},
    ];

    return Row(
      children: items.map((a) {
        final ok = a['ok'] as bool;
        return Expanded(
          child: Card(
            color: ok ? Colors.green[50] : Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(a['emoji'] as String, style: TextStyle(fontSize: 32, color: ok ? null : Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    a['title'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: ok ? Colors.green[900] : Colors.grey[600]),
                  ),
                  Text('${a['days']} days', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
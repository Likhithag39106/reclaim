import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/task_provider.dart';
import '../providers/mood_provider.dart';
import '../services/firestore_service.dart';
import '../models/tree_model.dart';
import '../widgets/mood_tracker_widget.dart';
import '../widgets/tree_widget.dart';
import '../routes.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  TreeModel? _tree;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final userProvider = context.read<UserProvider>();
    if (userProvider.user != null) {
      final uid = userProvider.user!.uid;
      
      // Load tasks
      context.read<TaskProvider>().loadTodaysTasks(uid);
      
      // Load moods
      context.read<MoodProvider>().loadWeeklyMoods(uid);
      
      // Load tree
      final tree = await _firestoreService.getTree(uid);
      if (mounted) {
        setState(() {
          _tree = tree;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reclaim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.pushNamed(context, Routes.analytics);
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.pushNamed(context, Routes.notificationSettings);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await context.read<UserProvider>().logout();
              if (!mounted) return;
              navigator.pushReplacementNamed(Routes.login);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Message
              Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  return Text(
                    'Welcome back, ${userProvider.user?.displayName ?? "User"}! 🌟',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Let\'s make today count',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Tree Widget
              if (_tree != null) TreeWidget(tree: _tree!),
              const SizedBox(height: 16),

              // Mood Tracker
              const MoodTrackerWidget(),
              const SizedBox(height: 16),

              // Recovery Plan Card
              Card(
                elevation: 4,
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, Routes.recoveryPlan);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.healing, size: 40, color: Colors.purple),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recovery Plan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Personalized recovery with daily goals',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Today's Tasks
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today\'s Tasks',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.tasks);
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Consumer<TaskProvider>(
                builder: (context, taskProvider, _) {
                  final tasks = taskProvider.todaysTasks ?? [];
                  
                  if (taskProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (tasks.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.task_alt, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'No tasks for today',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: tasks.take(3).map((task) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            task.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: task.completed ? Colors.green : Colors.grey,
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.completed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(task.addiction),
                          trailing: task.completed
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.check),
                                  onPressed: () async {
                                    final userProvider = context.read<UserProvider>();
                                    if (task.id != null) {
                                      await context.read<TaskProvider>().completeTask(
                                        uid: userProvider.user!.uid,
                                        taskId: task.id!,
                                      );
                                      _loadData(); // Reload tree
                                    }
                                  },
                                ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, Routes.tasks);
        },
        icon: const Icon(Icons.add_task),
        label: const Text('Add Task'),
      ),
    );
  }
}
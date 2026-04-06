import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tree_provider.dart';
import '../providers/user_provider.dart';
import '../providers/task_provider.dart';
import '../data/addiction_tasks.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  // Removed unused _selectedAddiction field

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      if (userProvider.user != null) {
        context.read<TaskProvider>().loadUserTasks(userProvider.user!.uid);
        context.read<TaskProvider>().loadTodaysTasks(userProvider.user!.uid);
      }
    });
  }

  List<Map<String, String>> _pickRandomTasks(List<Map<String, String>> pool, int count) {
    if (pool.isEmpty) return [];
    final rnd = Random();
    final copy = List<Map<String, String>>.from(pool);
    copy.shuffle(rnd);
    if (copy.length <= count) return copy;
    return copy.sublist(0, count);
  }

  Future<void> _showAddTaskSheet() async {
    final userProvider = context.read<UserProvider>();
    final taskProvider = context.read<TaskProvider>();
    if (userProvider.user == null) return;
    final userAddictions = userProvider.user!.addictions;

    // grouped tasks per addiction
    final Map<String, List<Map<String, String>>> grouped = {};
    for (final a in userAddictions) {
      grouped[a] = AddictionTasks.getTasksForAddiction(a);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 6,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const Text('Add Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Choose tasks tailored to your addictions', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      child: Column(
                        children: grouped.entries.map((entry) {
                          final addiction = entry.key;
                          final tasks = entry.value;
                          final suggestions = _pickRandomTasks(tasks, 3);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(addiction, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                ...suggestions.map((task) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.green.shade200, width: 2),
                                        ),
                                        child: const Icon(Icons.circle_outlined, size: 16, color: Colors.green),
                                      ),
                                      title: Text(task['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                                      subtitle: task['description'] != null ? Text(task['description']!, style: const TextStyle(fontSize: 13)) : null,
                                      trailing: IconButton(
                                        icon: const Icon(Icons.add_circle, color: Colors.green),
                                        onPressed: () async {
                                          final navigator = Navigator.of(ctx);
                                          final messenger = ScaffoldMessenger.of(ctx);

                                          final success = await taskProvider.createTask(
                                            uid: userProvider.user!.uid,
                                            title: task['title'] ?? '',
                                            description: task['description'] ?? '',
                                            addiction: addiction,
                                          );

                                          if (!mounted) return;

                                          if (success) {
                                            // refresh all tasks so UI shows the new task immediately
                                            await taskProvider.loadUserTasks(userProvider.user!.uid);
                                            await taskProvider.loadTodaysTasks(userProvider.user!.uid);

                                            navigator.pop();
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text('Task added successfully! 🌱'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } else {
                                            messenger.showSnackBar(
                                              const SnackBar(content: Text('Could not add task'), backgroundColor: Colors.red),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
      ),
      body: Consumer2<UserProvider, TaskProvider>(
        builder: (context, userProvider, taskProvider, _) {
          if (taskProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final userAddictions = userProvider.user?.addictions ?? [];
          final allTasks = taskProvider.allTasks ?? [];

          if (allTasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No tasks yet', style: TextStyle(fontSize: 20, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('Tap + to add your first task', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(12)),
                          child: const Text('🔥', style: TextStyle(fontSize: 32)),
                        ),
                        const SizedBox(width: 16),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${taskProvider.streak} Days Streak', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('Keep going!', style: TextStyle(color: Colors.grey[600])),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...userAddictions.map((addiction) {
                  final addictionTasks = allTasks.where((t) => t.addiction == addiction).toList();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(addiction, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('${addictionTasks.where((t) => t.completed).length}/${addictionTasks.length}',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    ]),
                    const SizedBox(height: 8),
                    if (addictionTasks.isEmpty)
                      Card(
                        child: Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('No tasks yet. Add your first task!', style: TextStyle(color: Colors.grey[600])))),
                      )
                    else
                      ...addictionTasks.map((task) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Checkbox(
                              value: task.completed,
                              onChanged: (checked) async {
                                if (task.id == null) return;
                                final messenger = ScaffoldMessenger.of(context);
                                final treeProvider = context.read<TreeProvider>();
                                try {
                                  final success = await taskProvider.setTaskCompleted(
                                    uid: userProvider.user!.uid,
                                    taskId: task.id!,
                                    completed: checked == true,
                                  );
                                  if (!mounted) return;
                                  if (success) {
                                    // reload tasks so strike-through updates
                                    await taskProvider.loadUserTasks(userProvider.user!.uid);
                                    await taskProvider.loadTodaysTasks(userProvider.user!.uid);
                                    
                                    // reload tree to show updated points
                                    await treeProvider.loadTree(userProvider.user!.uid);

                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(checked == true ? 'Task completed! 🌱' : 'Marked incomplete'),
                                        backgroundColor: checked == true ? Colors.green : Colors.orange,
                                      ),
                                    );
                                  } else {
                                    messenger.showSnackBar(const SnackBar(content: Text('Could not update task')));
                                  }
                                } catch (e) {
                                  messenger.showSnackBar(const SnackBar(content: Text('Could not update task')));
                                }
                              },
                            ),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                decoration: task.completed ? TextDecoration.lineThrough : null,
                                fontWeight: FontWeight.w500,
                                color: task.completed ? Colors.grey[700] : null,
                              ),
                            ),
                            subtitle: Text(task.description),
                            trailing: task.completed ? const Icon(Icons.verified, color: Colors.green) : null,
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                  ]);
                }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
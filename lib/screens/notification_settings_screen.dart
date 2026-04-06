import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import '../models/notification_model.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userProvider = context.read<UserProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    
    if (userProvider.user != null) {
      await notificationProvider.loadSettings(userProvider.user!.uid);
    }
  }

  Future<void> _updateSetting(NotificationSettings Function(NotificationSettings) update) async {
    final userProvider = context.read<UserProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    
    if (userProvider.user == null) return;

    final newSettings = update(notificationProvider.settings);
    await notificationProvider.saveSettings(userProvider.user!.uid, newSettings);
  }

  Future<void> _selectTime(BuildContext ctx, String currentTime, Function(String) onSelected) async {
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final picked = await showTimePicker(
      context: ctx,
      initialTime: initialTime,
    );

    if (picked != null) {
      final timeString = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onSelected(timeString);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          final settings = provider.settings;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Master switch
              Card(
                child: SwitchListTile(
                  title: const Text('Enable Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Receive app notifications'),
                  value: settings.enabled,
                  onChanged: (value) {
                    _updateSetting((s) => s.copyWith(enabled: value));
                  },
                ),
              ),

              const SizedBox(height: 24),
              const Text('Notification Types', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // Notification types
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Daily Reminders'),
                      subtitle: const Text('Task completion reminders'),
                      value: settings.dailyReminders,
                      onChanged: settings.enabled
                          ? (value) => _updateSetting((s) => s.copyWith(dailyReminders: value))
                          : null,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Mood Check-Ins'),
                      subtitle: const Text('Prompts to track your mood'),
                      value: settings.moodCheckIns,
                      onChanged: settings.enabled
                          ? (value) => _updateSetting((s) => s.copyWith(moodCheckIns: value))
                          : null,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Milestones & Achievements'),
                      subtitle: const Text('Celebrate your progress'),
                      value: settings.milestones,
                      onChanged: settings.enabled
                          ? (value) => _updateSetting((s) => s.copyWith(milestones: value))
                          : null,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Encouragement'),
                      subtitle: const Text('Motivational messages'),
                      value: settings.encouragement,
                      onChanged: settings.enabled
                          ? (value) => _updateSetting((s) => s.copyWith(encouragement: value))
                          : null,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Risk Alerts'),
                      subtitle: const Text('Excessive usage warnings'),
                      value: settings.riskAlerts,
                      onChanged: settings.enabled
                          ? (value) => _updateSetting((s) => s.copyWith(riskAlerts: value))
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text('Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // Schedule settings
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Reminder Time'),
                      subtitle: Text(settings.reminderTime),
                      trailing: const Icon(Icons.access_time),
                      enabled: settings.enabled && settings.dailyReminders,
                      onTap: settings.enabled && settings.dailyReminders
                          ? () {
                              _selectTime(context, settings.reminderTime, (time) {
                                _updateSetting((s) => s.copyWith(reminderTime: time));
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text('Do Not Disturb', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // Do Not Disturb
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Enable Do Not Disturb'),
                      subtitle: const Text('Silence notifications during specific hours'),
                      value: settings.doNotDisturbEnabled,
                      onChanged: settings.enabled
                          ? (value) => _updateSetting((s) => s.copyWith(doNotDisturbEnabled: value))
                          : null,
                    ),
                    if (settings.doNotDisturbEnabled) ...[
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Start Time'),
                        subtitle: Text(settings.doNotDisturbStart ?? '22:00'),
                        trailing: const Icon(Icons.bedtime),
                        enabled: settings.enabled,
                        onTap: settings.enabled
                            ? () {
                                _selectTime(context, settings.doNotDisturbStart ?? '22:00', (time) {
                                  _updateSetting((s) => s.copyWith(doNotDisturbStart: time));
                                });
                              }
                            : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('End Time'),
                        subtitle: Text(settings.doNotDisturbEnd ?? '07:00'),
                        trailing: const Icon(Icons.wb_sunny),
                        enabled: settings.enabled,
                        onTap: settings.enabled
                            ? () {
                                _selectTime(context, settings.doNotDisturbEnd ?? '07:00', (time) {
                                  _updateSetting((s) => s.copyWith(doNotDisturbEnd: time));
                                });
                              }
                            : null,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Test notification button
              ElevatedButton.icon(
                onPressed: settings.enabled
                    ? () async {
                        final userProvider = context.read<UserProvider>();
                        if (userProvider.user != null) {
                          await provider.runHabitAnalysis(userProvider.user!.uid);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Running behavior analysis...')),
                            );
                          }
                        }
                      }
                    : null,
                icon: const Icon(Icons.psychology),
                label: const Text('Run Habit Analysis Now'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 8),
              
              Text(
                'Habit analysis checks your usage patterns and sends relevant notifications',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

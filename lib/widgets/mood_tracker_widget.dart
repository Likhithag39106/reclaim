import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/mood_provider.dart';

class MoodTrackerWidget extends StatefulWidget {
  const MoodTrackerWidget({super.key});

  @override
  State<MoodTrackerWidget> createState() => _MoodTrackerWidgetState();
}

class _MoodTrackerWidgetState extends State<MoodTrackerWidget> {
  int? _selectedMood;
  String? _selectedMoodName;
  final TextEditingController _noteController = TextEditingController();

  final List<Map<String, dynamic>> _moods = [
    {'emoji': '😊', 'label': 'Happy', 'value': 5, 'color': Colors.green},
    {'emoji': '😌', 'label': 'Calm', 'value': 4, 'color': Colors.lightGreen},
    {'emoji': '😐', 'label': 'Neutral', 'value': 3, 'color': Colors.grey},
    {'emoji': '😔', 'label': 'Sad', 'value': 2, 'color': Colors.orange},
    {'emoji': '😤', 'label': 'Stressed', 'value': 1, 'color': Colors.red},
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitMood() async {
    if (_selectedMood == null || _selectedMoodName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mood')),
      );
      return;
    }

    final userProvider = context.read<UserProvider>();
    if (userProvider.user == null) return;

    final success = await context.read<MoodProvider>().logMood(
      uid: userProvider.user!.uid,
      rating: _selectedMood!,
      mood: _selectedMoodName!,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _selectedMood = null;
        _selectedMoodName = null;
        _noteController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mood logged successfully! 🌱'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'How are you feeling?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _moods.map((mood) {
                final isSelected = _selectedMood == mood['value'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMood = mood['value'] as int;
                      _selectedMoodName = (mood['label'] as String).toLowerCase();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? (mood['color'] as Color).withValues(alpha: 0.2) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? mood['color'] as Color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          mood['emoji'] as String,
                          style: TextStyle(
                            fontSize: isSelected ? 32 : 28,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mood['label'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitMood,
                child: const Text('Log Mood'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
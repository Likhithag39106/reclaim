import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';

/// Usage:
/// - Place the widget where you want the "complete with photo" button:
///   CompleteTaskWithPhotoButton(taskId: 'abc123', uid: user.uid)
/// - Or call CompleteTaskWithPhotoButton.show(context, taskId, uid)
class CompleteTaskWithPhotoButton extends StatelessWidget {
  final String taskId;
  final String uid;
  final IconData icon;
  final String tooltip;

  const CompleteTaskWithPhotoButton({
    super.key,
    required this.taskId,
    required this.uid,
    this.icon = Icons.check,
    this.tooltip = 'Complete',
  });

  static Future<void> show(BuildContext context, String taskId, String uid) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: CompleteTaskWithPhotoButton(taskId: taskId, uid: uid),
      ),
    );
  }

  Future<File?> _pickImage(BuildContext ctx, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      // ignore, will show feedback to user
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Could not pick image')));
      return null;
    }
  }

  Future<void> _handleComplete(BuildContext context, File? file) async {
    Navigator.of(context).pop(); // close the bottom sheet first
    final taskProvider = context.read<TaskProvider>();
    final messenger = ScaffoldMessenger.of(context);

    // show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await taskProvider.completeTaskWithPhoto(
      uid: uid,
      taskId: taskId,
      photoFile: file,
    );

    if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // close progress

    messenger.showSnackBar(
      SnackBar(content: Text(success ? 'Task completed' : 'Failed to complete task')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.camera_alt),
          title: const Text('Take Photo'),
          onTap: () async {
            final file = await _pickImage(context, ImageSource.camera);
            await _handleComplete(context, file);
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('Choose From Gallery'),
          onTap: () async {
            final file = await _pickImage(context, ImageSource.gallery);
            await _handleComplete(context, file);
          },
        ),
        ListTile(
          leading: const Icon(Icons.check),
          title: const Text('Complete Without Photo'),
          onTap: () async {
            await _handleComplete(context, null);
          },
        ),
      ],
    );
  }
}
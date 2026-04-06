import 'package:flutter/material.dart';

class DashboardPlaceholder extends StatelessWidget {
  const DashboardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.logout)),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Welcome, User!', style: TextStyle(fontSize: 22)),
            SizedBox(height: 12),
            Text('Today\'s tasks will appear here.'),
          ],
        ),
      ),
    );
  }
}
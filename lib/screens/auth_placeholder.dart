import 'package:flutter/material.dart';
import '../routes.dart';

class AuthPlaceholder extends StatelessWidget {
  const AuthPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auth (placeholder)')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Authentication screens will be implemented here.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed(Routes.dashboard);
            },
            child: const Text('Go to Dashboard (dev)'),
          ),
        ]),
      ),
    );
  }
}
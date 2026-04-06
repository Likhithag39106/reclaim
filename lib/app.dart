import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'routes.dart';
import 'providers/user_provider.dart';
import 'providers/task_provider.dart';
import 'providers/mood_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/recovery_plan_provider.dart';
import 'providers/ai_recovery_plan_provider.dart';
import 'providers/relapse_risk_provider.dart';
import 'providers/tree_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/ml_prediction_provider.dart';
import 'theme/app_theme.dart';

class ReclaimApp extends StatelessWidget {
  const ReclaimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => TreeProvider()),
        ChangeNotifierProvider(create: (_) => MoodProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => RecoveryPlanProvider()..initializeAI()),
        ChangeNotifierProvider(create: (_) => AIRecoveryPlanProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => RelapseRiskProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => MLPredictionProvider()..initialize()),
      ],
      child: MaterialApp(
        title: 'Reclaim',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: Routes.splash,
        routes: Routes.routes,
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/task_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/recovery_plan_screen.dart';
import 'screens/ai_recovery_plan_demo_screen.dart';

class Routes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String tasks = '/tasks';
  static const String analytics = '/analytics';
  static const String notificationSettings = '/notification-settings';
  static const String recoveryPlan = '/recovery-plan';
  static const String aiRecoveryPlanDemo = '/ai-recovery-plan-demo';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        login: (context) => const LoginScreen(),
        signup: (context) => const SignupScreen(),
        dashboard: (context) => const DashboardScreen(),
        tasks: (context) => const TaskScreen(),
        analytics: (context) => const AnalyticsScreen(),
        notificationSettings: (context) => const NotificationSettingsScreen(),
        recoveryPlan: (context) => const RecoveryPlanScreen(),
        aiRecoveryPlanDemo: (context) => const AIRecoveryPlanDemoScreen(),
      };
}
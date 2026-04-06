import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for tracking user behavior patterns and activity
class UserActivityService {
  static final UserActivityService _instance = UserActivityService._internal();
  factory UserActivityService() => _instance;
  UserActivityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  DateTime? _sessionStart;
  int _screenViewCount = 0;
  final Map<String, int> _screenDurations = {};
  String? _currentScreen;
  DateTime? _currentScreenStart;

  /// Start tracking a session
  void startSession() {
    _sessionStart = DateTime.now();
    _screenViewCount = 0;
    _screenDurations.clear();
    debugPrint('[UserActivityService] Session started');
  }

  /// End tracking session and save data
  Future<void> endSession(String uid) async {
    if (_sessionStart == null) return;

    final duration = DateTime.now().difference(_sessionStart!);
    
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('activity')
          .add({
        'sessionStart': Timestamp.fromDate(_sessionStart!),
        'sessionEnd': Timestamp.now(),
        'duration': duration.inSeconds,
        'screenViews': _screenViewCount,
        'screenDurations': _screenDurations,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[UserActivityService] Session ended: ${duration.inMinutes} minutes');
    } catch (e) {
      debugPrint('[UserActivityService] Error saving session: $e');
    }

    _sessionStart = null;
  }

  /// Track screen view
  void trackScreenView(String screenName) {
    // Save previous screen duration
    if (_currentScreen != null && _currentScreenStart != null) {
      final duration = DateTime.now().difference(_currentScreenStart!);
      _screenDurations[_currentScreen!] = 
          (_screenDurations[_currentScreen!] ?? 0) + duration.inSeconds;
    }

    _currentScreen = screenName;
    _currentScreenStart = DateTime.now();
    _screenViewCount++;

    debugPrint('[UserActivityService] Screen view: $screenName');
  }

  /// Get average session duration over last N days
  Future<Duration> getAverageSessionDuration(String uid, {int days = 7}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('activity')
          .where('sessionStart', isGreaterThan: Timestamp.fromDate(cutoff))
          .get();

      if (snapshot.docs.isEmpty) {
        return Duration.zero;
      }

      int totalSeconds = 0;
      for (final doc in snapshot.docs) {
        totalSeconds += (doc.data()['duration'] as int? ?? 0);
      }

      return Duration(seconds: totalSeconds ~/ snapshot.docs.length);
    } catch (e) {
      debugPrint('[UserActivityService] Error getting average duration: $e');
      return Duration.zero;
    }
  }

  /// Get total session count over last N days
  Future<int> getSessionCount(String uid, {int days = 7}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('activity')
          .where('sessionStart', isGreaterThan: Timestamp.fromDate(cutoff))
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('[UserActivityService] Error getting session count: $e');
      return 0;
    }
  }

  /// Detect if user is showing excessive app usage
  Future<bool> detectExcessiveUsage(String uid) async {
    final avgDuration = await getAverageSessionDuration(uid, days: 3);
    final sessionCount = await getSessionCount(uid, days: 1);

    // Trigger if average session > 30 minutes or more than 10 sessions per day
    final excessive = avgDuration.inMinutes > 30 || sessionCount > 10;

    if (excessive) {
      debugPrint('[UserActivityService] Excessive usage detected');
    }

    return excessive;
  }

  /// Get usage pattern insights
  Future<Map<String, dynamic>> getUsageInsights(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('activity')
          .orderBy('sessionStart', descending: true)
          .limit(30)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'averageDuration': 0,
          'totalSessions': 0,
          'mostUsedScreen': null,
          'usagePattern': 'insufficient_data',
        };
      }

      int totalDuration = 0;
      final Map<String, int> screenTotals = {};

      for (final doc in snapshot.docs) {
        totalDuration += (doc.data()['duration'] as int? ?? 0);
        final durations = doc.data()['screenDurations'] as Map<String, dynamic>?;
        
        if (durations != null) {
          durations.forEach((screen, duration) {
            screenTotals[screen] = (screenTotals[screen] ?? 0) + (duration as int);
          });
        }
      }

      String? mostUsedScreen;
      int maxDuration = 0;
      screenTotals.forEach((screen, duration) {
        if (duration > maxDuration) {
          maxDuration = duration;
          mostUsedScreen = screen;
        }
      });

      final avgDuration = totalDuration ~/ snapshot.docs.length;
      String pattern = 'normal';
      
      if (avgDuration > 1800) {
        pattern = 'heavy'; // > 30 min average
      } else if (avgDuration > 900) {
        pattern = 'moderate'; // 15-30 min
      } else {
        pattern = 'light'; // < 15 min
      }

      return {
        'averageDuration': avgDuration,
        'totalSessions': snapshot.docs.length,
        'mostUsedScreen': mostUsedScreen,
        'usagePattern': pattern,
      };
    } catch (e) {
      debugPrint('[UserActivityService] Error getting insights: $e');
      return {
        'averageDuration': 0,
        'totalSessions': 0,
        'mostUsedScreen': null,
        'usagePattern': 'error',
      };
    }
  }
}

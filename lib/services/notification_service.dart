import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'api_client.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _lastNotificationKey = 'last_notification_time';
  static const String _notificationChannelId = 'immunization_channel';
  static const String _notificationChannelName = 'Immunization Notifications';

  // Initialize notification service
  static Future<void> initialize() async {
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();
  }

  // Create notification channel for Android
  static Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: 'Notifications for immunization schedules and updates',
      importance: Importance.max, // Changed to MAX for expandable notifications
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');

    // Handle daily check notification
    if (response.payload == 'daily_check') {
      // Run the daily check when notification is tapped
      checkForNewNotificationsDaily();
    }
    // Handle other notification types
    else if (response.payload?.startsWith('immunization_today_') == true ||
        response.payload?.startsWith('immunization_tomorrow_') == true) {
      // Extract baby_id from payload
      final babyId = response.payload?.split('_').last;
      if (babyId != null) {
        debugPrint('Navigate to child record for baby_id: $babyId');
        // TODO: Navigate to child record screen with baby_id
      }
    }
  }

  // Show notification with expandable text support
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: 'Notifications for immunization schedules',
      importance: Importance.max, // MAX for expandable notifications
      priority: Priority.max, // MAX priority for expandable notifications
      showWhen: true,
      icon: '@mipmap/launcher_icon',
      styleInformation: BigTextStyleInformation(
        body, // Full body text for expandable notifications
        contentTitle: title,
        summaryText: 'Ebakunado Notification',
      ),
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Show scheduled notification with expandable text support
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: 'Scheduled immunization notifications',
      importance: Importance.max, // MAX for expandable notifications
      priority: Priority.max, // MAX priority for expandable notifications
      styleInformation: BigTextStyleInformation(
        body, // Full body text for expandable notifications
        contentTitle: title,
        summaryText: 'Ebakunado Scheduled Notification',
      ),
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // Cancel notification
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Get last notification time
  static Future<DateTime> getLastNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastNotificationKey);
    if (timestamp != null) {
      return DateTime.parse(timestamp);
    }
    return DateTime.now().subtract(const Duration(days: 1));
  }

  // Save last notification time
  static Future<void> saveLastNotificationTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastNotificationKey, time.toIso8601String());
  }

  // Check for new notifications (legacy method - kept for backward compatibility)
  static Future<void> checkForNewNotifications() async {
    // Redirect to the new daily check method
    await checkForNewNotificationsDaily();
  }

  // Request notification permissions
  static Future<bool> requestPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    return true; // iOS permissions are handled in initialization
  }

  // Check if notification already sent today
  static Future<bool> _isNotificationAlreadySent(
    SupabaseClient supabase,
    String babyId,
    String userId,
    String type,
    String date,
  ) async {
    try {
      debugPrint(
        'Checking notification_logs for baby_id: $babyId, user_id: $userId, type: $type, date: $date',
      );
      final response = await supabase
          .from('notification_logs')
          .select('id')
          .eq('baby_id', babyId)
          .eq('user_id', userId)
          .eq('type', type)
          .eq('notification_date', date)
          .limit(1);

      debugPrint('notification_logs query result: ${response.toString()}');
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking notification log: $e');
      return false; // If error, allow notification to be sent
    }
  }

  // Schedule daily notification check at 12:00 AM Philippines time
  static Future<void> scheduleDailyNotificationCheck() async {
    try {
      // Cancel any existing daily notification
      await cancelNotification(999999); // Use a specific ID for daily check

      // Schedule for 12:00 AM Philippines time
      final now = tz.TZDateTime.now(tz.getLocation('Asia/Manila'));
      var scheduledDate = tz.TZDateTime(
        tz.getLocation('Asia/Manila'),
        now.year,
        now.month,
        now.day,
        0, // 12:00 AM
        0,
      );

      // If it's already past 12:00 AM today, schedule for tomorrow
      if (now.isAfter(scheduledDate)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notifications.zonedSchedule(
        999999, // Specific ID for daily check
        'Daily Notification Check',
        'Checking for immunization schedules',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _notificationChannelId,
            _notificationChannelName,
            channelDescription: 'Daily check for immunization notifications',
            importance: Importance.max,
            priority: Priority.max,
            showWhen: false,
            styleInformation: BigTextStyleInformation(
              'Checking for immunization schedules',
              contentTitle: 'Daily Notification Check',
              summaryText: 'Ebakunado Background Check',
            ),
            enableVibration: false,
            playSound: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: false,
            presentSound: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exact,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_check',
      );

      debugPrint('Daily notification check scheduled for: $scheduledDate');
    } catch (e) {
      debugPrint('Error scheduling daily notification check: $e');
    }
  }

  // Check if user is logged in (use API session check like AuthProvider)
  static Future<bool> _isUserLoggedIn() async {
    try {
      // Use the same method as AuthProvider - check API session
      final response = await ApiClient.instance.getDashboardSummary();

      if (response.statusCode == 200 && response.data != null) {
        // Parse JSON string if needed
        Map<String, dynamic> data;
        if (response.data is String) {
          data = json.decode(response.data);
        } else {
          data = response.data;
        }

        // Check if response indicates user is logged in
        final isLoggedIn = data['status'] == 'success';
        debugPrint('API session check result: $isLoggedIn');
        return isLoggedIn;
      }

      debugPrint('API session check failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('Error checking user login status via API: $e');
      return false;
    }
  }

  // Get current user ID from profile provider or API
  static Future<String?> _getCurrentUserId() async {
    try {
      // First try to get from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile_data');

      if (profileJson != null) {
        final profileData = Map<String, dynamic>.from(
          json.decode(profileJson) as Map,
        );
        final userId = profileData['user_id'] as String?;
        debugPrint('Retrieved user_id from profile: $userId');
        return userId;
      }

      // If not in SharedPreferences, try to get from API response
      debugPrint('No profile data in SharedPreferences, trying API...');
      final response = await ApiClient.instance.getDashboardSummary();

      if (response.statusCode == 200 && response.data != null) {
        Map<String, dynamic> data;
        if (response.data is String) {
          data = json.decode(response.data);
        } else {
          data = response.data;
        }

        if (data['status'] == 'success' && data['data'] != null) {
          final userData = data['data'];
          if (userData is Map<String, dynamic> && userData['user_id'] != null) {
            final userId = userData['user_id'] as String?;
            debugPrint('Retrieved user_id from API: $userId');
            return userId;
          }
        }
      }

      debugPrint('No user_id found in API response either');
      return null;
    } catch (e) {
      debugPrint('Error getting current user ID: $e');
      return null;
    }
  }

  // Main daily notification check - matches PHP cron logic
  static Future<void> checkForNewNotificationsDaily() async {
    debugPrint('=== Starting Daily Notification Check ===');

    try {
      // Check if user is logged in
      final isLoggedIn = await _isUserLoggedIn();
      debugPrint('User logged in status: $isLoggedIn');
      if (!isLoggedIn) {
        debugPrint('User not logged in, skipping daily check');
        return;
      }

      // Get current user ID
      final currentUserId = await _getCurrentUserId();
      debugPrint('Current user ID: $currentUserId');
      if (currentUserId == null) {
        debugPrint('No current user ID found, skipping daily check');
        return;
      }

      debugPrint('Checking notifications for user: $currentUserId');

      // Try API method first (more reliable)
      final apiSuccess = await _checkNotificationsViaAPI();
      debugPrint('API method success: $apiSuccess');
      if (!apiSuccess) {
        debugPrint(
          'API method failed, falling back to Supabase direct queries',
        );
        // Fallback to direct Supabase queries
        await _checkTodayImmunizations(currentUserId);
        await _checkTomorrowImmunizations(currentUserId);
      } else {
        debugPrint('API method succeeded - notifications sent via API');
      }

      debugPrint('=== Daily Notification Check Completed ===');
    } catch (e) {
      debugPrint('Error in daily notification check: $e');
    }
  }

  // Check notifications via API endpoint (more reliable than direct Supabase)
  static Future<bool> _checkNotificationsViaAPI() async {
    try {
      debugPrint('Checking notifications via API endpoint');
      final response = await ApiClient.instance.getDailyNotifications();

      // Parse response
      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      debugPrint('API Response Status: ${response.statusCode}');
      debugPrint('API Response Data: ${responseData.toString()}');

      if (responseData['status'] == 'success') {
        final data = responseData['data'];

        // Process today's notifications
        final todayNotifications = data['today'] as List<dynamic>? ?? [];
        for (final notification in todayNotifications) {
          await showNotification(
            title: 'Immunization Due Today',
            body: notification['message'],
            payload: 'immunization_today_${notification['baby_id']}',
          );
          debugPrint(
            'Sent today notification via API: ${notification['message']}',
          );
        }

        // Process tomorrow's notifications
        final tomorrowNotifications = data['tomorrow'] as List<dynamic>? ?? [];
        for (final notification in tomorrowNotifications) {
          await showNotification(
            title: 'Immunization Due Tomorrow',
            body: notification['message'],
            payload: 'immunization_tomorrow_${notification['baby_id']}',
          );
          debugPrint(
            'Sent tomorrow notification via API: ${notification['message']}',
          );
        }

        debugPrint(
          'Successfully processed ${todayNotifications.length} today, ${tomorrowNotifications.length} tomorrow notifications via API',
        );
        return true;
      } else {
        debugPrint('API returned error: ${responseData['message']}');
        return false;
      }
    } catch (e) {
      debugPrint('Error checking notifications via API: $e');
      return false;
    }
  }

  // Check today's immunizations (same as PHP cron)
  static Future<void> _checkTodayImmunizations(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final today = DateTime.now().toIso8601String().split('T')[0];

      debugPrint('Checking today\'s immunizations for date: $today');
      debugPrint('User ID: $userId');

      // Query same as PHP cron: immunization_records JOIN child_health_records
      final todayImmunizations = await supabase
          .from('immunization_records')
          .select('*, child_health_records!inner(*)')
          .eq('child_health_records.user_id', userId)
          .eq('schedule_date', today)
          .eq('status', 'scheduled');

      debugPrint('Found ${todayImmunizations.length} today\'s immunizations');
      debugPrint('Query result: ${todayImmunizations.toString()}');

      for (final immunization in todayImmunizations) {
        final child = immunization['child_health_records'];
        final childName = '${child['child_fname']} ${child['child_lname']}';
        final message =
            '$childName has ${immunization['vaccine_name']} scheduled today';

        // Check if notification already sent (by PHP cron or previously)
        final alreadyNotified = await _isNotificationAlreadySent(
          supabase,
          immunization['baby_id'],
          userId,
          'schedule_same_day', // Match PHP cron type
          today,
        );

        debugPrint(
          'Notification already sent for baby ${immunization['baby_id']}: $alreadyNotified',
        );

        if (!alreadyNotified) {
          await showNotification(
            title: 'Immunization Due Today',
            body: message,
            payload: 'immunization_today_${immunization['baby_id']}',
          );

          debugPrint('Sent today notification: $message');
        } else {
          debugPrint('Notification already sent for today, skipping');
        }
      }
    } catch (e) {
      debugPrint('Error checking today immunizations: $e');
    }
  }

  // Check tomorrow's immunizations (same as PHP cron)
  static Future<void> _checkTomorrowImmunizations(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final today = DateTime.now().toIso8601String().split('T')[0];
      final tomorrow = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String()
          .split('T')[0];

      debugPrint('Checking tomorrow\'s immunizations for date: $tomorrow');

      // Query same as PHP cron
      final tomorrowImmunizations = await supabase
          .from('immunization_records')
          .select('*, child_health_records!inner(*)')
          .eq('child_health_records.user_id', userId)
          .eq('schedule_date', tomorrow)
          .eq('status', 'scheduled');

      debugPrint(
        'Found ${tomorrowImmunizations.length} tomorrow\'s immunizations',
      );

      for (final immunization in tomorrowImmunizations) {
        final child = immunization['child_health_records'];
        final childName = '${child['child_fname']} ${child['child_lname']}';
        final message =
            '$childName has ${immunization['vaccine_name']} scheduled tomorrow';

        // Check if notification already sent
        final alreadyNotified = await _isNotificationAlreadySent(
          supabase,
          immunization['baby_id'],
          userId,
          'schedule_reminder', // Match PHP cron type
          today, // PHP cron logs with today's date
        );

        if (!alreadyNotified) {
          await showNotification(
            title: 'Immunization Due Tomorrow',
            body: message,
            payload: 'immunization_tomorrow_${immunization['baby_id']}',
          );

          debugPrint('Sent tomorrow notification: $message');
        }
      }
    } catch (e) {
      debugPrint('Error checking tomorrow immunizations: $e');
    }
  }
}

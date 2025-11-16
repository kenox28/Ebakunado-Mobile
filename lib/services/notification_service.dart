import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
// import 'package:timezone/data/latest.dart' as tz_data;  // Not needed for now (WorkManager disabled)
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:workmanager/workmanager.dart';  // Temporarily disabled due to compatibility issues
import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'api_client.dart';
import '../models/child.dart';
import '../models/user_profile.dart';

// Top-level function for background notification handler
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('Background notification received: ${response.payload}');
  // The actual handling will be done when the app is opened
  // For true background execution, we'd need workmanager or similar
}

class _DailyCheckSlot {
  const _DailyCheckSlot({
    required this.notificationId,
    required this.nativeRequestCode,
    required this.time,
    required this.isDefault,
  });

  final int notificationId;
  final int nativeRequestCode;
  final TimeOfDay time;
  final bool isDefault;
}

// Legacy daily summary model removed (unused)

@pragma('vm:entry-point')
Future<void> alarmBackgroundDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();

  final channel = MethodChannel('com.ebakunado/alarm_background');

  channel.setMethodCallHandler((call) async {
    if (call.method == 'handleDailyAlarm') {
      final args = Map<String, dynamic>.from(
        (call.arguments as Map?) ?? <String, dynamic>{},
      );
      final requestCode = args['requestCode'] is int
          ? args['requestCode'] as int
          : int.tryParse('${args['requestCode']}') ?? -1;
      final title = (args['title'] as String?)?.trim();
      final body = (args['body'] as String?)?.trim();

      try {
        await NotificationService.handleDailyAlarmInBackground(
          requestCode: requestCode,
          slotTitle: title?.isEmpty == true ? null : title,
          slotBody: body?.isEmpty == true ? null : body,
        );
      } catch (e, stackTrace) {
        debugPrint('❌ Error handling background alarm: $e');
        debugPrint('Stack: $stackTrace');
      } finally {
        try {
          await channel.invokeMethod('alarmComplete');
        } catch (completionError) {
          debugPrint(
            '⚠️ Failed to notify native side about completion: '
            '$completionError',
          );
        }
      }
    }
    return null;
  });

  try {
    await channel.invokeMethod('backgroundReady');
  } catch (e) {
    debugPrint('⚠️ Background ready handshake failed: $e');
  }

  final completer = Completer<void>();
  await completer.future;
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _alarmChannel = MethodChannel(
    'com.ebakunado/alarms',
  );
  static final DateFormat _time12hFormatter = DateFormat('yyyy-MM-dd hh:mm a');

  static const String _lastNotificationKey = 'last_notification_time';
  static const String _notificationChannelId = 'immunization_channel';
  static const String _notificationChannelName = 'Immunization Notifications';
  static const String _customNotificationTimeKey = 'custom_notification_time';
  static const String _lastNotificationCheckKey =
      'last_notification_check_time';
  static const String _childrenSummaryCacheKey = 'children_summary_cache';
  static const String _childrenSummaryCacheTsKey = 'children_summary_cache_ts';
  static bool _notificationsPluginInitialized = false;

  static Future<void> _ensureNotificationsInitialized({
    required bool background,
  }) async {
    if (_notificationsPluginInitialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initializedResult = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    debugPrint(
      '📱 Notification service initialization result: '
      '$initializedResult (background: $background)',
    );

    _notificationsPluginInitialized = true;

    await _createNotificationChannel();
  }

  static const int _dailyCheckMorningId = 999990;
  static const int _dailyCheckEveningId = 999991;
  static const int _dailyCheckCustomId = 999999;

  static const int _dailyCheckMorningRequestCode = 910990;
  static const int _dailyCheckEveningRequestCode = 910991;
  static const int _dailyCheckCustomRequestCode = 910999;

  static const List<_DailyCheckSlot> _defaultDailyCheckSlots = [
    _DailyCheckSlot(
      notificationId: _dailyCheckMorningId,
      nativeRequestCode: _dailyCheckMorningRequestCode,
      time: TimeOfDay(hour: 8, minute: 0),
      isDefault: true,
    ),
    _DailyCheckSlot(
      notificationId: _dailyCheckEveningId,
      nativeRequestCode: _dailyCheckEveningRequestCode,
      time: TimeOfDay(hour: 23, minute: 59),
      isDefault: true,
    ),
  ];

  static Future<void> _scheduleNativeBackupNotification({
    required int id,
    required tz.TZDateTime scheduleTime,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      final triggerAtMillis = scheduleTime.millisecondsSinceEpoch;
      final args = {
        'id': id,
        'triggerAtMillis': triggerAtMillis,
        'title': title,
        'body': body,
        'channelId': _notificationChannelId,
      };
      if (payload != null) {
        args['payload'] = payload;
      }

      await _alarmChannel.invokeMethod('scheduleNativeNotification', args);
      debugPrint(
        '✅ Native alarm scheduled (fallback) for notification $id at $scheduleTime',
      );
    } catch (e) {
      debugPrint('⚠️ Error scheduling native alarm fallback: $e');
    }
  }

  static Future<void> _cancelNativeNotification(int id) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _alarmChannel.invokeMethod('cancelNativeNotification', {'id': id});
      debugPrint('🛑 Native alarm cancelled for notification $id');
    } catch (e) {
      debugPrint('⚠️ Error cancelling native alarm $id: $e');
    }
  }

  static Future<void> _cancelNativeNotificationsRange(
    int startId,
    int endId,
  ) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _alarmChannel.invokeMethod('cancelNativeNotificationsRange', {
        'startId': startId,
        'endId': endId,
      });
      debugPrint('🛑 Native alarms cancelled for IDs $startId-$endId');
    } catch (e) {
      debugPrint('⚠️ Error cancelling native alarm range $startId-$endId: $e');
    }
  }

  // Initialize notification service
  static Future<void> initialize() async {
    await _ensureNotificationsInitialized(background: false);

    // Do not show generic fallback banners

    // Request permissions on Android
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('📱 Notification permission requested: $granted');

        final areEnabled = await androidPlugin.areNotificationsEnabled();
        debugPrint('📱 Notifications enabled: $areEnabled');
      }
    }

    // WorkManager initialization - Temporarily disabled due to compatibility issues
    // await _initializeWorkManager();

    // Ensure the app appears in Android "Alarms & reminders" settings by
    // scheduling a silent exact alarm far in the future (kept pending).
    if (Platform.isAndroid) {
      await _ensureAppVisibleInExactAlarmSettings();
    }
  }

  // Initialize local timezone using platform channel to get device timezone ID
  static Future<void> initializeTimezone() async {
    try {
      // Ask native for the device timezone ID (e.g., "Asia/Manila")
      final String deviceTz =
          await _alarmChannel.invokeMethod<String>('getDeviceTimeZone') ??
          'UTC';
      tz.setLocalLocation(tz.getLocation(deviceTz));
      debugPrint('🕒 Timezone set to device local: $deviceTz');
    } catch (e) {
      debugPrint('⚠️ Failed to set device timezone, defaulting to UTC: $e');
      // Fallback to UTC if something fails
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
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

  // Note: native fallback notification saving removed (unused)

  static Future<void> _scheduleNativeAlarm(
    tz.TZDateTime target,
    int hour,
    int minute,
  ) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _alarmChannel.invokeMethod('scheduleNativeAlarm', {
        'epochMillis': target.millisecondsSinceEpoch,
        'hour': hour,
        'minute': minute,
      });
    } catch (e) {
      debugPrint('⚠️ Error scheduling native alarm: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  static Future<void> _scheduleNativeDailyCheckAlarms(
    List<_DailyCheckSlot> slots, {
    String? summaryTitle,
    String? summaryBody,
  }) async {
    if (!Platform.isAndroid || slots.isEmpty) {
      return;
    }

    try {
      final args = slots.map((slot) {
        final nextTrigger = _nextInstanceOfTime(slot.time);
        final map = <String, dynamic>{
          'requestCode': slot.nativeRequestCode,
          'hour': slot.time.hour,
          'minute': slot.time.minute,
          'epochMillis': nextTrigger.millisecondsSinceEpoch,
        };
        if (summaryTitle != null && summaryTitle.isNotEmpty) {
          map['title'] = summaryTitle;
        }
        if (summaryBody != null && summaryBody.isNotEmpty) {
          map['body'] = summaryBody;
        }
        return map;
      }).toList();

      await _alarmChannel.invokeMethod('scheduleDailyCheckAlarms', {
        'slots': args,
      });
    } catch (e) {
      debugPrint('⚠️ Error scheduling native daily check alarms: $e');
    }
  }

  static Future<void> _cancelNativeDailyCheckAlarms() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _alarmChannel.invokeMethod('cancelDailyCheckAlarms');
    } catch (e) {
      debugPrint('⚠️ Error cancelling native daily check alarms: $e');
    }
  }

  // Schedule a silent exact alarm far in the future so the app shows up under
  // Settings > Apps > Special app access > Alarms & reminders (Android 12+).
  // Keep it pending (do not cancel) so the OS lists the app.
  static Future<void> _ensureAppVisibleInExactAlarmSettings() async {
    try {
      // Avoid duplicating if already pending
      final pending = await _notifications.pendingNotificationRequests();
      if (pending.any((n) => n.id == 999996)) {
        return;
      }

      final location = tz.getLocation('Asia/Manila');
      final nowTz = tz.TZDateTime.now(location);
      final futureTime = nowTz.add(const Duration(days: 180));

      await _notifications.zonedSchedule(
        999996,
        'Alarms & reminders visibility',
        'Keeps Ebakunado visible in Alarms & reminders settings',
        futureTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _notificationChannelId,
            _notificationChannelName,
            importance: Importance.low,
            priority: Priority.low,
            showWhen: false,
            enableVibration: false,
            playSound: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: false,
            presentSound: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'visibility_alarm',
      );
      debugPrint(
        '✅ Scheduled visibility alarm to appear in Alarms & reminders',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to schedule visibility alarm: $e');
    }
  }

  // Open the Exact Alarms settings screen via platform channel request intent
  static Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _alarmChannel.invokeMethod('requestScheduleExactAlarms');
      debugPrint('📱 Opened Exact Alarms settings request intent');
    } catch (e) {
      debugPrint('❌ Error requesting exact alarm permission: $e');
    }
  }

  // Handle notification tap and receive (for scheduled notifications)
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    _handleNotificationResponse(response);
  }

  // Handle notification response (both tap and receive)
  static Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    // Handle daily check notification
    if (response.payload == 'daily_check') {
      debugPrint(
        '🔔 Daily check notification triggered - running notification check',
      );
      // Run the daily check when notification is received or tapped
      // This will work even when app is closed (for scheduled notifications)
      await _triggerDailyNotificationCheck();
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

  // Trigger daily notification check (called when daily_check notification fires)
  static Future<void> _triggerDailyNotificationCheck() async {
    debugPrint(
      '🔄 Triggering daily notification check (cache-first, no banner)',
    );
    try {
      // Try cached children_summary (works even without auth)
      final cached = await _loadChildrenSummaryCache();
      if (cached != null) {
        try {
          final childrenSummary = ChildrenSummaryResponse.fromJson(cached);
          await checkNotificationsFromDashboardData(childrenSummary);
          await scheduleUpcomingImmunizationNotifications(childrenSummary);
          // Update last check time
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _lastNotificationCheckKey,
            DateTime.now().toIso8601String(),
          );
          debugPrint('✅ Daily check completed using cache');
          return;
        } catch (e) {
          debugPrint('⚠️ Cache parse/use failed: $e');
        }
      }

      // Fallback: if user is logged in, fetch live once
      if (await _isUserLoggedIn()) {
        try {
          final response = await ApiClient.instance.getDashboardSummary();
          if (response.statusCode == 200 && response.data != null) {
            Map<String, dynamic> data;
            if (response.data is String) {
              data = json.decode(response.data);
            } else {
              data = response.data;
            }
            if (data['children_summary'] != null) {
              final childrenSummary = ChildrenSummaryResponse.fromJson(
                data['children_summary'],
              );
              // Save to cache for future headless runs
              try {
                await _saveChildrenSummaryCache(
                  Map<String, dynamic>.from(data['children_summary']),
                );
              } catch (_) {}
              await checkNotificationsFromDashboardData(childrenSummary);
              await scheduleUpcomingImmunizationNotifications(childrenSummary);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                _lastNotificationCheckKey,
                DateTime.now().toIso8601String(),
              );
              debugPrint('✅ Daily check completed using live data');
              return;
            }
          }
        } catch (e) {
          debugPrint('❌ Error fetching live data during daily check: $e');
        }
      } else {
        debugPrint('ℹ️ Not logged in and no cache available; skipping.');
      }
    } catch (e) {
      debugPrint('❌ Error triggering daily notification check: $e');
    }
  }

  // Legacy method - redirects to daily check
  static Future<void> checkForNewNotificationsDaily() async {
    await _triggerDailyNotificationCheck();
  }

  // Show scheduled immunization notification (called by WorkManager)
  static Future<void> showScheduledImmunizationNotification({
    required String babyId,
    required String childName,
    required String vaccine,
    required bool isToday,
  }) async {
    try {
      final title = isToday
          ? 'Immunization Due Today'
          : 'Immunization Due Tomorrow';
      final dayText = isToday ? 'today' : 'tomorrow';
      final message = '$childName has $vaccine scheduled $dayText';

      final androidDetails = AndroidNotificationDetails(
        _notificationChannelId,
        _notificationChannelName,
        channelDescription: 'Scheduled immunization notifications',
        importance: Importance.max,
        priority: Priority.max,
        // Avoid fullscreen popups that can interfere with foreground app state
        styleInformation: BigTextStyleInformation(
          message,
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

      // Generate a unique ID based on babyId and date
      final notificationId = babyId.hashCode % 100000 + 50000;

      await _notifications.show(
        notificationId,
        title,
        message,
        details,
        payload: isToday
            ? 'immunization_today_$babyId'
            : 'immunization_tomorrow_$babyId',
      );

      debugPrint('✅ Scheduled notification shown: $childName - $vaccine');
    } catch (e) {
      debugPrint('❌ Error showing scheduled notification: $e');
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

  // Prime native (Kotlin) with per-child notifications to show at alarm time,
  // avoiding background Flutter work. Stores two JSON arrays and a cache date.
  static Future<void> primeNativeDailyNotificationsCache(
    ChildrenSummaryResponse childrenSummary,
  ) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final todayString = today.toIso8601String().split('T')[0];
      final tomorrowString = tomorrow.toIso8601String().split('T')[0];

      final List<Map<String, dynamic>> todayList = [];
      final List<Map<String, dynamic>> tomorrowList = [];

      for (final item in childrenSummary.items) {
        final info = _getEffectiveUpcomingInfo(item);
        if (info == null) continue;
        final dateOnly = (info['date'] as String).split('T')[0];
        final isCatchUp = info['isCatchUp'] as bool;
        if (dateOnly == todayString) {
          final body = _buildScheduleMessage(
            item: item,
            isCatchUp: isCatchUp,
            scheduleText: 'scheduled today',
          );
          todayList.add({
            'id': item.babyId,
            'title': isCatchUp
                ? 'Catch-up Immunization Today'
                : 'Immunization Due Today',
            'body': body,
            'payload': 'immunization_today_${item.babyId}',
          });
        } else if (dateOnly == tomorrowString) {
          final body = _buildScheduleMessage(
            item: item,
            isCatchUp: isCatchUp,
            scheduleText: 'scheduled tomorrow',
          );
          tomorrowList.add({
            'id': item.babyId,
            'title': isCatchUp
                ? 'Catch-up Immunization Tomorrow'
                : 'Immunization Due Tomorrow',
            'body': body,
            'payload': 'immunization_tomorrow_${item.babyId}',
          });
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('native_cache_date', todayString);
      await prefs.setString(
        'native_today_notifications',
        json.encode(todayList),
      );
      await prefs.setString(
        'native_tomorrow_notifications',
        json.encode(tomorrowList),
      );
      debugPrint(
        '💾 Primed native cache: ${todayList.length} today, ${tomorrowList.length} tomorrow',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to prime native daily notifications cache: $e');
    }
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
      // Request notification permission
      final granted = await androidPlugin.requestNotificationsPermission();

      // Check if notifications are enabled
      final notificationsEnabled = await androidPlugin
          .areNotificationsEnabled();
      debugPrint(
        'Notification permission: $granted, Notifications enabled: $notificationsEnabled',
      );

      if (notificationsEnabled == false) {
        debugPrint(
          '⚠️ Notifications may not be enabled. Please enable in system settings.',
        );
      }

      return granted ?? false;
    }

    return true; // iOS permissions are handled in initialization
  }

  // Check if battery optimization is disabled for this app
  // Battery optimization can prevent notifications from firing when app is closed
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) {
      return true; // Not applicable on iOS
    }

    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Error checking battery optimization status: $e');
      return false;
    }
  }

  // Request battery optimization exemption
  // This is critical for notifications to work when app is closed
  static Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) {
      return true; // Not applicable on iOS
    }

    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      if (status.isGranted) {
        debugPrint('✅ Battery optimization exemption granted');
        return true;
      } else if (status.isPermanentlyDenied) {
        debugPrint('⚠️ Battery optimization exemption permanently denied');
        debugPrint('   User needs to enable it manually in settings');
        // Open battery optimization settings
        await AppSettings.openAppSettings(
          type: AppSettingsType.batteryOptimization,
        );
        return false;
      } else {
        debugPrint('❌ Battery optimization exemption denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error requesting battery optimization exemption: $e');
      return false;
    }
  }

  // Open app settings page (helper method)
  static Future<void> openAppSettings() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      debugPrint('📱 Opening app settings...');
      await AppSettings.openAppSettings();
      debugPrint('✅ App settings opened');
    } catch (e) {
      debugPrint('❌ Error opening app settings: $e');
      // Fallback: just log instructions
      debugPrint('   Please manually go to: Settings > Apps > Ebakunado');
    }
  }

  // Query if notifications are enabled (Android)
  static Future<bool> areNotificationsEnabled() async {
    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin == null) return true; // iOS or unavailable
      final enabled = await androidPlugin.areNotificationsEnabled();
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  // Query if exact alarms are allowed (Android 12+)
  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    try {
      final can = await _alarmChannel.invokeMethod<bool>(
        'canScheduleExactAlarms',
      );
      return can ?? false;
    } catch (_) {
      return false;
    }
  }

  // Open system app notification settings for Ebakunado
  static Future<void> openSystemNotificationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _alarmChannel.invokeMethod('openSystemNotificationSettings');
    } catch (e) {
      debugPrint('⚠️ Failed to open system notification settings: $e');
    }
  }

  // Open system battery/app details settings for Ebakunado
  static Future<void> openSystemBatterySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _alarmChannel.invokeMethod('openSystemBatterySettings');
    } catch (e) {
      debugPrint('⚠️ Failed to open system battery settings: $e');
    }
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

  // Get custom notification time (default: 12:00 AM)
  static Future<TimeOfDay> getCustomNotificationTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeString = prefs.getString(_customNotificationTimeKey);
      if (timeString != null) {
        final parts = timeString.split(':');
        if (parts.length == 2) {
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting custom notification time: $e');
    }
    // Default to 12:00 AM
    return const TimeOfDay(hour: 0, minute: 0);
  }

  // Save custom notification time
  static Future<void> setCustomNotificationTime(TimeOfDay time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _customNotificationTimeKey,
        '${time.hour}:${time.minute}',
      );
      // Log in 12-hour local format for clarity
      final nowLocal = DateTime.now();
      final displayTime = _time12hFormatter.format(
        DateTime(
          nowLocal.year,
          nowLocal.month,
          nowLocal.day,
          time.hour,
          time.minute,
        ),
      );
      debugPrint('Custom notification time saved: $displayTime (local 12h)');

      // Reschedule with new time
      await scheduleDailyNotificationCheck();
    } catch (e) {
      debugPrint('Error saving custom notification time: $e');
    }
  }

  // Legacy daily summary defaults removed (unused)

  // Cache helpers for children_summary
  static Future<void> _saveChildrenSummaryCache(
    Map<String, dynamic> childrenSummary,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _childrenSummaryCacheKey,
        json.encode(childrenSummary),
      );
      await prefs.setInt(
        _childrenSummaryCacheTsKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('💾 children_summary cached');
    } catch (e) {
      debugPrint('⚠️ Failed to cache children_summary: $e');
    }
  }

  static Future<Map<String, dynamic>?> _loadChildrenSummaryCache({
    int maxAgeHours = 72,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_childrenSummaryCacheKey);
      if (raw == null) return null;
      final tsMs = prefs.getInt(_childrenSummaryCacheTsKey);
      if (tsMs != null && maxAgeHours > 0) {
        final ageHrs = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(tsMs))
            .inHours;
        if (ageHrs > maxAgeHours) {
          debugPrint('⚠️ children_summary cache too old ($ageHrs h), ignoring');
          return null;
        }
      }
      final parsed = json.decode(raw);
      if (parsed is Map) {
        return Map<String, dynamic>.from(parsed);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Failed to load children_summary cache: $e');
      return null;
    }
  }

  // Legacy daily summary builder removed (unused)

  // Legacy summary formatter removed (unused)

  static Map<String, dynamic>? _getEffectiveUpcomingInfo(
    ChildSummaryItem item,
  ) {
    String? dateIso = item.upcomingDate;
    bool isCatchUp = item.nextIsCatchUp;
    String? vaccine = item.upcomingVaccine;

    if ((dateIso == null || dateIso.isEmpty) && item.closestMissed != null) {
      final fallbackDate = item.closestMissed?.catchUpDate;
      if (fallbackDate != null && fallbackDate.isNotEmpty) {
        dateIso = fallbackDate;
        isCatchUp = true;
        if (vaccine == null || vaccine.isEmpty) {
          vaccine = item.closestMissed?.vaccineName ?? '';
        }
      }
    }

    if (dateIso == null || dateIso.isEmpty) {
      return null;
    }

    return {'date': dateIso, 'isCatchUp': isCatchUp, 'vaccine': vaccine ?? ''};
  }

  static String _buildScheduleMessage({
    required ChildSummaryItem item,
    required bool isCatchUp,
    required String scheduleText,
  }) {
    final vaccine = item.upcomingVaccine?.isNotEmpty == true
        ? item.upcomingVaccine!
        : item.closestMissed?.vaccineName ?? 'scheduled vaccine';

    if (isCatchUp) {
      return '${item.name} has a catch-up immunization ($vaccine) $scheduleText';
    }

    return '${item.name} has $vaccine $scheduleText';
  }

  // Schedule daily notification check at custom time (default: 12:00 AM) Philippines time
  // This will trigger a check for notifications at the set time every day
  static Future<void> scheduleDailyNotificationCheck() async {
    try {
      await _ensureNotificationsInitialized(background: false);
      for (final id in [
        _dailyCheckMorningId,
        _dailyCheckEveningId,
        _dailyCheckCustomId,
      ]) {
        await cancelNotification(id);
        await _cancelNativeNotification(id);
      }

      await _cancelNativeDailyCheckAlarms();

      final customTime = await getCustomNotificationTime();
      final customSlot = _DailyCheckSlot(
        notificationId: _dailyCheckCustomId,
        nativeRequestCode: _dailyCheckCustomRequestCode,
        time: customTime,
        isDefault: false,
      );

      final slots = [..._defaultDailyCheckSlots, customSlot];

      final displayTimes = slots
          .map((slot) => _formatTimeOfDay(slot.time))
          .toList();
      debugPrint('📝 Daily checks configured for ${displayTimes.join(', ')}');

      tz.TZDateTime? earliestScheduled;

      // Compute the next times (without scheduling local notifications)
      for (final slot in slots) {
        final scheduledDate = _nextInstanceOfTime(slot.time);
        if (earliestScheduled == null ||
            scheduledDate.isBefore(earliestScheduled)) {
          earliestScheduled = scheduledDate;
        }
        final formattedLocal = _time12hFormatter.format(
          scheduledDate.toLocal(),
        );
        debugPrint(
          '✅ Daily check alarm time (no pre-baked notification) for '
          '${slot.isDefault ? 'default' : 'custom'} slot at $formattedLocal',
        );
      }

      if (earliestScheduled != null) {
        final prefs = await SharedPreferences.getInstance();
        final localEarliest = DateTime.fromMillisecondsSinceEpoch(
          earliestScheduled.millisecondsSinceEpoch,
        ).toLocal();
        await prefs.setString(
          _lastNotificationCheckKey,
          localEarliest.toIso8601String(),
        );
      }

      await _scheduleNativeDailyCheckAlarms(
        slots,
        // Do not provide pre-baked content; background will compute fresh at fire time
        summaryTitle: null,
        summaryBody: null,
      );

      debugPrint(
        '✅ Daily check alarms scheduled for ${displayTimes.join(', ')}',
      );
      debugPrint(
        '   These checks will run daily even when the app is closed (requires exact alarm permission on Android 12+).',
      );
    } catch (e) {
      debugPrint('❌ Error scheduling daily notification check: $e');
    }
  }

  // Recompute summary at alarm time and only send real due notifications.
  // (merged into the earlier definition)

  static Future<void> handleDailyAlarmInBackground({
    required int requestCode,
    String? slotTitle,
    String? slotBody,
  }) async {
    debugPrint('🛎️ Handling background daily alarm for slot $requestCode');

    try {
      await _ensureNotificationsInitialized(background: true);
    } catch (e) {
      debugPrint('⚠️ Background initialization error: $e');
    }

    try {
      await initializeTimezone();
    } catch (e) {
      debugPrint('⚠️ Background timezone initialization failed: $e');
    }

    try {
      await _triggerDailyNotificationCheck();
    } catch (e) {
      debugPrint('❌ Error performing background daily check: $e');
    }

    // Slightly delay re-scheduling to avoid re-entrancy at exact alarm time
    try {
      await Future.delayed(const Duration(seconds: 3));
      await scheduleDailyNotificationCheck();
    } catch (e) {
      debugPrint('❌ Error re-scheduling daily checks in background: $e');
    }

    if (slotTitle != null || slotBody != null) {
      debugPrint('   Previous summary title: ${slotTitle ?? '-'}');
    }
  }

  // Check for missed notifications when app opens
  // This checks if notifications were scheduled but not shown (e.g., due to doze mode)
  static Future<void> checkForMissedNotifications() async {
    debugPrint('=== Checking for Missed Notifications ===');

    try {
      // Check if user is logged in
      final isLoggedIn = await _isUserLoggedIn();
      if (!isLoggedIn) {
        debugPrint('User not logged in, skipping missed notification check');
        return;
      }

      // Get the last time we checked for notifications
      final prefs = await SharedPreferences.getInstance();
      final lastCheckString = prefs.getString(_lastNotificationCheckKey);

      if (lastCheckString == null) {
        debugPrint(
          'No previous notification check found, skipping missed notification check',
        );
        return;
      }

      final lastCheckTime = DateTime.parse(lastCheckString).toLocal();
      final now = DateTime.now().toLocal();
      final hoursSinceLastCheck = now.difference(lastCheckTime).inHours;

      debugPrint('Last notification check: $lastCheckTime');
      debugPrint('Current time: $now');
      debugPrint('Hours since last check: $hoursSinceLastCheck');

      // If more than 1 hour has passed since the scheduled check time, check for missed notifications
      // This handles cases where the app was closed and notifications didn't fire
      if (hoursSinceLastCheck >= 1) {
        debugPrint(
          '⚠️ Potential missed notifications detected (${hoursSinceLastCheck} hours since last check)',
        );
        debugPrint('Checking for notifications that should have been shown...');

        // Try to get dashboard data and check for notifications
        try {
          // Use API to get current dashboard data
          final response = await ApiClient.instance.getDashboardSummary();

          if (response.statusCode == 200 && response.data != null) {
            Map<String, dynamic> data;
            if (response.data is String) {
              data = json.decode(response.data);
            } else {
              data = response.data;
            }

            // Parse children summary
            if (data['children_summary'] != null) {
              final childrenSummary = ChildrenSummaryResponse.fromJson(
                data['children_summary'],
              );

              // Get user ID
              final userId = await _getCurrentUserId();

              // Check for notifications that should have been shown
              // This will show notifications if there are immunizations due today/tomorrow
              await checkNotificationsFromDashboardData(
                childrenSummary,
                userId: userId,
              );

              // Also re-schedule upcoming notifications to ensure they're set for the future
              await scheduleUpcomingImmunizationNotifications(
                childrenSummary,
                userId: userId,
              );

              // Update last check time
              await prefs.setString(
                _lastNotificationCheckKey,
                now.toLocal().toIso8601String(),
              );

              debugPrint('✅ Missed notification check completed');
              debugPrint(
                '   Notifications have been checked and scheduled for future dates',
              );
            }
          }
        } catch (e) {
          debugPrint('❌ Error checking for missed notifications: $e');
        }
      } else {
        debugPrint(
          '✅ Last check was recent (${hoursSinceLastCheck} hours ago), no missed notifications',
        );
      }
    } catch (e) {
      debugPrint('❌ Error in checkForMissedNotifications: $e');
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
      // First try to get from SharedPreferences (user profile data)
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile_data');

      if (profileJson != null) {
        try {
          final profileData = Map<String, dynamic>.from(
            json.decode(profileJson) as Map,
          );
          final userId = profileData['user_id'] as String?;
          if (userId != null && userId.isNotEmpty) {
            debugPrint('Retrieved user_id from SharedPreferences: $userId');
            return userId;
          }
        } catch (e) {
          debugPrint('Error parsing profile data from SharedPreferences: $e');
        }
      }

      // Try to get from profile API
      debugPrint('No profile data in SharedPreferences, trying profile API...');
      try {
        final profileResponse = await ApiClient.instance.getProfileData();

        Map<String, dynamic> responseData;
        if (profileResponse.data is String) {
          responseData = json.decode(profileResponse.data);
        } else {
          responseData = profileResponse.data;
        }

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final profile = UserProfile.fromJson(responseData['data']);
          if (profile.userId.isNotEmpty) {
            debugPrint('Retrieved user_id from profile API: ${profile.userId}');
            return profile.userId;
          }
        }
      } catch (e) {
        debugPrint('Error getting user_id from profile API: $e');
      }

      // Try to get from Supabase session (last resort)
      try {
        final supabase = Supabase.instance.client;
        final session = supabase.auth.currentSession;
        if (session != null && session.user.id.isNotEmpty) {
          debugPrint(
            'Retrieved user_id from Supabase session: ${session.user.id}',
          );
          return session.user.id;
        }
      } catch (e) {
        debugPrint('Error getting user_id from Supabase session: $e');
      }

      debugPrint('No user_id found in any source');
      return null;
    } catch (e) {
      debugPrint('Error getting current user ID: $e');
      return null;
    }
  }

  // Schedule notifications in advance for upcoming immunizations
  // This ensures notifications fire even when app is closed
  static Future<void> scheduleUpcomingImmunizationNotifications(
    ChildrenSummaryResponse childrenSummary, {
    String? userId,
  }) async {
    debugPrint('=== Scheduling Upcoming Immunization Notifications ===');
    // Prime native cache for alarm-time notifications
    await primeNativeDailyNotificationsCache(childrenSummary);

    try {
      // Check if user is logged in
      final isLoggedIn = await _isUserLoggedIn();
      if (!isLoggedIn) {
        debugPrint('User not logged in, skipping notification scheduling');
        return;
      }

      // Get user ID
      String? currentUserId = userId;
      if (currentUserId == null || currentUserId.isEmpty) {
        currentUserId = await _getCurrentUserId();
      }

      // Get custom notification time
      final customTime = await getCustomNotificationTime();
      final notificationHour = customTime.hour;
      final notificationMinute = customTime.minute;

      // Get today and next 7 days for scheduling
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Clear old scheduled notifications (keep ID 999999 for daily check)
      // We'll use IDs 100000+ for immunization notifications
      await _cancelNativeNotificationsRange(100000, 100099);
      for (int i = 100000; i < 100100; i++) {
        await cancelNotification(i);
      }

      int notificationId = 100000;
      int scheduledCount = 0;
      tz.TZDateTime? fallbackScheduleTime;
      final List<String> fallbackMessages = [];

      // Process all upcoming immunizations and schedule notifications
      for (final item in childrenSummary.items) {
        final info = _getEffectiveUpcomingInfo(item);
        if (info == null) {
          debugPrint('Skipping ${item.name}: no upcoming or catch-up date');
          continue;
        }

        final String dateIso = info['date'] as String;
        final bool isCatchUp = info['isCatchUp'] as bool;
        final String vaccine = (info['vaccine'] as String).trim();

        debugPrint(
          'Processing ${item.name}: date=$dateIso catchUp=$isCatchUp vaccine=$vaccine',
        );

        try {
          final upcomingDate = DateTime.parse(dateIso);
          final daysUntil = upcomingDate.difference(today).inDays;

          debugPrint(
            'Processing ${item.name}: date=$dateIso catchUp=$isCatchUp daysUntil=$daysUntil',
          );

          if (daysUntil >= 0 && daysUntil <= 7) {
            final notificationDate = tz.TZDateTime(
              tz.local,
              upcomingDate.year,
              upcomingDate.month,
              upcomingDate.day,
              notificationHour,
              notificationMinute,
            );

            final nowTz = tz.TZDateTime.now(tz.local);

            final scheduleTime =
                (daysUntil == 0 && nowTz.isAfter(notificationDate))
                ? nowTz.add(const Duration(minutes: 3))
                : notificationDate;

            final title = isCatchUp
                ? 'Catch-up Immunization Today'
                : 'Immunization Due Today';
            final scheduleText = isCatchUp
                ? 'scheduled for today'
                : 'scheduled today';
            final message = _buildScheduleMessage(
              item: item,
              isCatchUp: isCatchUp,
              scheduleText: scheduleText,
            );

            final androidDetails = AndroidNotificationDetails(
              _notificationChannelId,
              _notificationChannelName,
              channelDescription: 'Scheduled immunization notifications',
              importance: Importance.max,
              priority: Priority.max,
              // Avoid fullscreen popups that can interfere with foreground app state
              styleInformation: BigTextStyleInformation(
                message,
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

            try {
              await _notifications.zonedSchedule(
                notificationId,
                title,
                message,
                scheduleTime,
                details,
                payload: 'immunization_today_${item.babyId}',
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              );

              scheduledCount++;
              final formattedWhen = _time12hFormatter.format(
                scheduleTime.toLocal(),
              );
              debugPrint(
                '✅ Scheduled #$notificationId at $formattedWhen (catchUp=$isCatchUp)',
              );

              await _scheduleNativeBackupNotification(
                id: notificationId,
                scheduleTime: scheduleTime,
                title: title,
                body: message,
                payload: 'immunization_today_${item.babyId}',
              );

              notificationId++;

              fallbackMessages.add(message);
              if (fallbackScheduleTime == null ||
                  scheduleTime.isBefore(fallbackScheduleTime)) {
                fallbackScheduleTime = scheduleTime;
              }
            } catch (scheduleError) {
              debugPrint(
                '❌ Error scheduling notification for ${item.name}: $scheduleError',
              );
            }
          }
        } catch (e) {
          debugPrint('Error scheduling notification for ${item.name}: $e');
        }
      }

      if (scheduledCount > 0) {
        debugPrint(
          '✅ Successfully scheduled $scheduledCount immunization notifications',
        );
        debugPrint(
          '📅 These notifications will fire at ${notificationHour.toString().padLeft(2, '0')}:${notificationMinute.toString().padLeft(2, '0')} on their respective dates',
        );
        debugPrint(
          '⚠️ Note: Notifications work even when app is closed, but Android may delay them in doze mode',
        );
      } else {
        debugPrint(
          '⚠️ No notifications scheduled - check if you have immunizations due today or tomorrow',
        );
      }

      final targetFallbackTime = fallbackScheduleTime;
      if (fallbackMessages.isNotEmpty && targetFallbackTime != null) {
        await _scheduleNativeAlarm(
          targetFallbackTime,
          notificationHour,
          notificationMinute,
        );
      } else {
        // No generic fallback notification
      }
    } catch (e) {
      debugPrint('❌ Error scheduling upcoming immunization notifications: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  // Check notifications from dashboard data (new improved method)
  // Uses existing dashboard data instead of separate API calls
  // userId is optional - if not provided, will try to get it automatically
  static Future<void> checkNotificationsFromDashboardData(
    ChildrenSummaryResponse childrenSummary, {
    String? userId,
  }) async {
    debugPrint('=== Checking Notifications from Dashboard Data ===');
    // Also prime the native cache so alarms can show correct content without Flutter
    await primeNativeDailyNotificationsCache(childrenSummary);

    try {
      // Check if user is logged in
      final isLoggedIn = await _isUserLoggedIn();
      debugPrint('User logged in status: $isLoggedIn');
      if (!isLoggedIn) {
        debugPrint('User not logged in, skipping notification check');
        return;
      }

      // Get current user ID (optional - for duplicate check)
      // Use provided userId, or try to get it automatically
      String? currentUserId = userId;

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('No userId provided, trying to get it automatically...');
        currentUserId = await _getCurrentUserId();
      } else {
        debugPrint('Using provided userId: $currentUserId');
      }

      debugPrint('Current user ID: $currentUserId');

      // If no user_id found, we can still send notifications
      // The dashboard API already filters by logged-in user, so it's safe
      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint(
          'Warning: No user_id found, will skip duplicate check but still send notifications',
        );
      }

      // Get today and tomorrow dates
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final todayString = today.toIso8601String().split('T')[0];
      final tomorrowString = tomorrow.toIso8601String().split('T')[0];

      debugPrint(
        'Checking notifications for today: $todayString, tomorrow: $tomorrowString',
      );
      debugPrint(
        'Total items in childrenSummary: ${childrenSummary.items.length}',
      );

      // Filter children for today and tomorrow immunizations
      final todayItems = <Map<String, dynamic>>[];
      final tomorrowItems = <Map<String, dynamic>>[];

      for (final item in childrenSummary.items) {
        final info = _getEffectiveUpcomingInfo(item);
        if (info == null) {
          debugPrint(
            'Skipping ${item.name} in daily check: no upcoming/catch-up',
          );
          continue;
        }

        final upcomingDateString = (info['date'] as String).split('T')[0];
        final isCatchUp = info['isCatchUp'] as bool;
        debugPrint(
          'Daily check ${item.name}: date=$upcomingDateString catchUp=$isCatchUp',
        );

        if (upcomingDateString == todayString) {
          todayItems.add({'item': item, 'isCatchUp': isCatchUp});
        } else if (upcomingDateString == tomorrowString) {
          tomorrowItems.add({'item': item, 'isCatchUp': isCatchUp});
        }
      }

      for (final entry in todayItems) {
        final ChildSummaryItem item = entry['item'] as ChildSummaryItem;
        final bool isCatchUp = entry['isCatchUp'] as bool;
        final message = _buildScheduleMessage(
          item: item,
          isCatchUp: isCatchUp,
          scheduleText: 'scheduled today',
        );

        bool alreadyNotified = false;
        if (currentUserId != null) {
          alreadyNotified = await _isNotificationAlreadySent(
            Supabase.instance.client,
            item.babyId,
            currentUserId,
            isCatchUp ? 'catch_up_same_day' : 'schedule_same_day',
            todayString,
          );
        }

        if (!alreadyNotified) {
          await showNotification(
            title: isCatchUp
                ? 'Catch-up Immunization Today'
                : 'Immunization Due Today',
            body: message,
            payload: 'immunization_today_${item.babyId}',
          );
        }
      }

      for (final entry in tomorrowItems) {
        final ChildSummaryItem item = entry['item'] as ChildSummaryItem;
        final bool isCatchUp = entry['isCatchUp'] as bool;
        final message = _buildScheduleMessage(
          item: item,
          isCatchUp: isCatchUp,
          scheduleText: 'scheduled tomorrow',
        );

        bool alreadyNotified = false;
        if (currentUserId != null) {
          alreadyNotified = await _isNotificationAlreadySent(
            Supabase.instance.client,
            item.babyId,
            currentUserId,
            isCatchUp ? 'catch_up_reminder' : 'schedule_reminder',
            todayString,
          );
        }

        if (!alreadyNotified) {
          await showNotification(
            title: isCatchUp
                ? 'Catch-up Immunization Tomorrow'
                : 'Immunization Due Tomorrow',
            body: message,
            payload: 'immunization_tomorrow_${item.babyId}',
          );
        }
      }

      debugPrint(
        '=== Notification Check Completed: ${todayItems.length} today, ${tomorrowItems.length} tomorrow ===',
      );
    } catch (e) {
      debugPrint('Error checking notifications from dashboard data: $e');
    }
  }

  // Legacy API-based notification helpers removed (unused)
}

import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final granted = await NotificationService.requestPermissions();
    setState(() {
      _permissionsGranted = granted;
    });
  }

  Future<void> _testApiNotifications() async {
    try {
      // Test the API method specifically
      await NotificationService.checkForNewNotificationsDaily();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ API notification check completed - check debug logs',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Permission Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _permissionsGranted ? Icons.check_circle : Icons.warning,
                      color: _permissionsGranted
                          ? AppConstants.successGreen
                          : AppConstants.errorRed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _permissionsGranted
                            ? 'Notification permissions granted'
                            : 'Notification permissions not granted',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (!_permissionsGranted)
                      ElevatedButton(
                        onPressed: _checkPermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.mediumGreen,
                        ),
                        child: const Text('Request'),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Test Buttons
            Text(
              'Test Notifications',
              style: AppConstants.headingStyle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _testApiNotifications,
              icon: const Icon(Icons.api),
              label: const Text('Test API Notifications'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 24),

            // Info Card
            Card(
              color: AppConstants.secondaryGray,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: AppConstants.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppConstants.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Immediate notifications show right away\n'
                      '• Scheduled notifications appear at the specified time\n'
                      '• Daily 12:00 AM check for immunization schedules (Philippines time)\n'
                      '• Uses PHP API endpoint first (more reliable)\n'
                      '• Falls back to direct Supabase queries if API fails\n'
                      '• Checks notification_logs to prevent duplicates with PHP cron\n'
                      '• Only runs when user is logged in\n'
                      '• Notifications work even when the app is closed\n'
                      '• Notifications are expandable - tap to read full text\n'
                      '• Only shows today and tomorrow immunizations (matches PHP cron)\n'
                      '• Fixed: Now works immediately after login (no restart required)',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

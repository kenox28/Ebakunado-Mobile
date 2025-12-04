import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import '../widgets/app_drawer.dart';

class AppNotificationSettingsScreen extends StatefulWidget {
  const AppNotificationSettingsScreen({super.key});

  @override
  State<AppNotificationSettingsScreen> createState() => _AppNotificationSettingsScreenState();
}

class _AppNotificationSettingsScreenState extends State<AppNotificationSettingsScreen> {
  bool _loading = true;
  bool _notificationsEnabled = false;
  bool _batteryUnrestricted = false;
  TimeOfDay? _customTime;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final custom = await NotificationService.getCustomNotificationTime();
    final notifEnabled = await NotificationService.areNotificationsEnabled();
    final batteryOk = await NotificationService.isBatteryOptimizationDisabled();
    if (!mounted) return;
    setState(() {
      _customTime = custom;
      _notificationsEnabled = notifEnabled;
      _batteryUnrestricted = batteryOk;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Notification Settings'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'To receive notifications when the app is closed, enable the items below.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('Daily Check Time'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Custom Time'),
                    subtitle: Text(_customTime != null ? _formatTime(_customTime!) : 'Not set'),
                    trailing: const Icon(Icons.edit),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _customTime ?? const TimeOfDay(hour: 0, minute: 0),
                      );
                      if (picked != null) {
                        await NotificationService.setCustomNotificationTime(picked);
                        if (!mounted) return;
                        setState(() => _customTime = picked);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Daily checks run at 8:00 AM, 11:59 PM, and ${_formatTime(picked)}.',
                            ),
                            backgroundColor: AppConstants.successGreen,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('Permissions & Device Settings'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Notifications'),
                        subtitle: Text(_notificationsEnabled ? 'Allowed' : 'Blocked'),
                        value: _notificationsEnabled,
                        onChanged: null,
                        secondary: const Icon(Icons.notifications),
                      ),
                      ListTile(
                        title: const Text('Open phone notification settings'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () async {
                          await NotificationService.openSystemNotificationSettings();
                          await _load();
                        },
                      ),
                      const Divider(height: 0),
                      SwitchListTile(
                        title: const Text('Battery optimization'),
                        subtitle: Text(_batteryUnrestricted ? 'Unrestricted' : 'Restricted'),
                        value: _batteryUnrestricted,
                        onChanged: null,
                        secondary: const Icon(Icons.battery_saver),
                      ),
                      ListTile(
                        title: const Text('Open phone battery settings'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () async {
                          await NotificationService.openSystemBatterySettings();
                          await _load();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _formatTime(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return TimeOfDay.fromDateTime(dt).format(context);
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}



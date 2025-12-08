import 'package:flutter/material.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import '../widgets/app_drawer.dart';

class AppNotificationSettingsScreen extends StatefulWidget {
  const AppNotificationSettingsScreen({super.key});

  @override
  State<AppNotificationSettingsScreen> createState() =>
      _AppNotificationSettingsScreenState();
}

class _AppNotificationSettingsScreenState
    extends State<AppNotificationSettingsScreen> {
  bool _loading = true;
  bool _notificationsEnabled = false;
  bool _batteryUnrestricted = false;
  bool _storagePermissionGranted = false;
  bool _manageStoragePermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notifEnabled = await NotificationService.areNotificationsEnabled();
    final batteryOk = await NotificationService.isBatteryOptimizationDisabled();

    // Check storage permissions
    bool storageGranted = false;
    bool manageStorageGranted = false;

    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.status;
      storageGranted = storageStatus.isGranted;

      final manageStorageStatus = await Permission.manageExternalStorage.status;
      manageStorageGranted = manageStorageStatus.isGranted;
    } else {
      // iOS doesn't need these permissions
      storageGranted = true;
      manageStorageGranted = true;
    }

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = notifEnabled;
      _batteryUnrestricted = batteryOk;
      _storagePermissionGranted = storageGranted;
      _manageStoragePermissionGranted = manageStorageGranted;
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
                _buildSectionTitle('Daily Check Times'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: AppConstants.primaryGreen,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Automatic Daily Checks',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildTimeItem('Morning Check', '8:00 AM'),
                                  const SizedBox(height: 8),
                                  _buildTimeItem('Evening Check', '11:59 PM'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: AppConstants.primaryGreen,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'The app automatically checks for upcoming immunizations at these times every day, even when the app is closed.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('Permissions & Device Settings'),
                Card(
                  child: Column(
                    children: [
                      _buildPermissionTile(
                        icon: Icons.notifications,
                        title: 'Notifications',
                        subtitle: _notificationsEnabled ? 'Allowed' : 'Blocked',
                        value: _notificationsEnabled,
                        onTap: () async {
                          await NotificationService.openSystemNotificationSettings();
                          await _load();
                        },
                      ),
                      const Divider(height: 0),
                      _buildPermissionTile(
                        icon: Icons.battery_saver,
                        title: 'Battery optimization',
                        subtitle: _batteryUnrestricted
                            ? 'Unrestricted'
                            : 'Restricted',
                        value: _batteryUnrestricted,
                        onTap: () async {
                          await NotificationService.openSystemBatterySettings();
                          await _load();
                        },
                      ),
                      if (Platform.isAndroid) ...[
                        const Divider(height: 0),
                        _buildPermissionTile(
                          icon: Icons.folder,
                          title: 'Storage Access',
                          subtitle: _storagePermissionGranted
                              ? 'Granted'
                              : 'Denied',
                          value: _storagePermissionGranted,
                          onTap: () async {
                            if (!_storagePermissionGranted) {
                              final status = await Permission.storage.request();
                              if (status.isPermanentlyDenied) {
                                await openAppSettings();
                              }
                            }
                            await _load();
                          },
                        ),
                        const Divider(height: 0),
                        _buildPermissionTile(
                          icon: Icons.storage,
                          title: 'All Files Access',
                          subtitle: _manageStoragePermissionGranted
                              ? 'Granted'
                              : 'Denied',
                          value: _manageStoragePermissionGranted,
                          onTap: () async {
                            if (!_manageStoragePermissionGranted) {
                              final status = await Permission
                                  .manageExternalStorage
                                  .request();
                              if (status.isPermanentlyDenied) {
                                await openAppSettings();
                              }
                            }
                            await _load();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTimeItem(String label, String time) {
    return Row(
      children: [
        Icon(Icons.check_circle, size: 16, color: AppConstants.successGreen),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        Text(
          time,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppConstants.primaryGreen,
          ),
        ),
      ],
    );
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

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required VoidCallback onTap,
  }) {
    Color statusColor = value ? AppConstants.successGreen : Colors.orange;
    IconData statusIcon = value ? Icons.check_circle : Icons.warning;

    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title),
      subtitle: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 4),
          Text(
            subtitle,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

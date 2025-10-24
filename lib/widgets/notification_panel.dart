import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification.dart';
import '../utils/constants.dart';

class NotificationPanel extends StatelessWidget {
  final ScrollController scrollController;

  const NotificationPanel({super.key, required this.scrollController});

  String _mapActionUrlToRoute(String? actionUrl) {
    if (actionUrl == null) return AppConstants.homeRoute;

    switch (actionUrl) {
      case './home.php':
        return AppConstants.homeRoute;
      case './Request.php':
        return AppConstants.requestChildRoute;
      case './approved_requests.php':
        return AppConstants.approvedRequestsRoute;
      default:
        if (actionUrl.startsWith('./upcoming_schedule.php')) {
          final uri = Uri.parse(actionUrl);
          final babyId = uri.queryParameters['baby_id'];
          return babyId != null
              ? '${AppConstants.upcomingScheduleRoute}?baby_id=$babyId'
              : AppConstants.upcomingScheduleRoute;
        }
        return AppConstants.homeRoute;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        return Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: AppConstants.headingStyle.copyWith(fontSize: 20),
                  ),
                  if (notificationProvider.unreadCount > 0)
                    TextButton(
                      onPressed: () async {
                        await notificationProvider.markAllAsRead();
                      },
                      child: const Text('Mark all read'),
                    ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Notifications List
            Expanded(
              child: notificationProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : notificationProvider.notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No notifications',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: notificationProvider.notifications.length,
                      itemBuilder: (context, index) {
                        final notification =
                            notificationProvider.notifications[index];
                        return _NotificationTile(
                          notification: notification,
                          onTap: () async {
                            // Mark as read if unread
                            if (notification.unread) {
                              await notificationProvider.markAsRead(
                                notification.id,
                              );
                            }

                            // Navigate to the appropriate route
                            final route = _mapActionUrlToRoute(
                              notification.actionUrl,
                            );
                            if (context.mounted) {
                              Navigator.pop(context); // Close the panel
                              Navigator.pushNamed(context, route);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  Color _getPriorityColor() {
    switch (notification.priority.toLowerCase()) {
      case 'high':
        return AppConstants.errorRed;
      case 'medium':
        return AppConstants.warningOrange;
      case 'low':
      default:
        return AppConstants.successGreen;
    }
  }

  IconData _getNotificationIcon() {
    switch (notification.type.toLowerCase()) {
      case 'immunization':
        return Icons.vaccines;
      case 'appointment':
        return Icons.schedule;
      case 'reminder':
        return Icons.alarm;
      case 'chr':
        return Icons.description;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: notification.unread ? Colors.blue.shade50 : Colors.white,
        border: Border(left: BorderSide(color: _getPriorityColor(), width: 4)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPriorityColor().withValues(alpha: 0.1),
          child: Icon(_getNotificationIcon(), color: _getPriorityColor()),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.unread
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 4),
            Text(
              notification.timestamp,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: notification.unread
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppConstants.primaryGreen,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

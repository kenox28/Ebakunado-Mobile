import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../models/notification.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  int _totalCount = 0;
  bool _isLoading = false;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  int get totalCount => _totalCount;
  bool get isLoading => _isLoading;

  Future<void> loadNotifications() async {
    _setLoading(true);

    try {
      final response = await ApiClient.instance.getNotifications();
      final notificationResponse = NotificationResponse.fromJson(response.data);

      if (notificationResponse.status == 'success') {
        _notifications = notificationResponse.notifications;
        _unreadCount = notificationResponse.unreadCount;
        _totalCount = notificationResponse.totalCount;
        notifyListeners();
      }
    } on DioException catch (e) {
      debugPrint('Failed to load notifications: $e');
      // Don't throw error for notifications, just log it
    } catch (e) {
      if (e is AuthExpiredException) {
        rethrow; // Let auth provider handle this
      }
      debugPrint('Failed to load notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await ApiClient.instance.markNotificationRead(notificationId);

      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && _notifications[index].unread) {
        _notifications[index] = NotificationItem(
          id: _notifications[index].id,
          type: _notifications[index].type,
          priority: _notifications[index].priority,
          title: _notifications[index].title,
          message: _notifications[index].message,
          actionUrl: _notifications[index].actionUrl,
          timestamp: _notifications[index].timestamp,
          unread: false,
          icon: _notifications[index].icon,
          babyId: _notifications[index].babyId,
        );

        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await ApiClient.instance.markAllNotificationsRead();

      // Update local state
      _notifications = _notifications
          .map(
            (notification) => NotificationItem(
              id: notification.id,
              type: notification.type,
              priority: notification.priority,
              title: notification.title,
              message: notification.message,
              actionUrl: notification.actionUrl,
              timestamp: notification.timestamp,
              unread: false,
              icon: notification.icon,
              babyId: notification.babyId,
            ),
          )
          .toList();

      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

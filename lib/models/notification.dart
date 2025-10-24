class NotificationItem {
  final String id;
  final String type;
  final String priority;
  final String title;
  final String message;
  final String? actionUrl;
  final String timestamp;
  final bool unread;
  final String? icon;
  final String? babyId;

  NotificationItem({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.message,
    this.actionUrl,
    required this.timestamp,
    required this.unread,
    this.icon,
    this.babyId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? '',
      priority: json['priority'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      actionUrl: json['action_url'],
      timestamp: json['timestamp'] ?? '',
      unread: json['unread'] == true || json['unread'] == 1,
      icon: json['icon'],
      babyId: json['baby_id'],
    );
  }
}

class NotificationResponse {
  final String status;
  final List<NotificationItem> notifications;
  final int unreadCount;
  final int totalCount;

  NotificationResponse({
    required this.status,
    required this.notifications,
    required this.unreadCount,
    required this.totalCount,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final notificationsList = data['notifications'] as List<dynamic>? ?? [];

    return NotificationResponse(
      status: json['status'] ?? '',
      notifications: notificationsList
          .map((item) => NotificationItem.fromJson(item))
          .toList(),
      unreadCount: data['unread_count'] ?? 0,
      totalCount: data['total_count'] ?? 0,
    );
  }
}

class DailyNotificationEntry {
  final String babyId;
  final String childName;
  final String vaccineName;
  final int? doseNumber;
  final String? guidelineDate;
  final String? batchScheduleDate;
  final String? targetDate;
  final String? dateSource;
  final String message;
  final String type;

  const DailyNotificationEntry({
    required this.babyId,
    required this.childName,
    required this.vaccineName,
    required this.message,
    required this.type,
    this.doseNumber,
    this.guidelineDate,
    this.batchScheduleDate,
    this.targetDate,
    this.dateSource,
  });

  factory DailyNotificationEntry.fromJson(Map<String, dynamic> json) {
    return DailyNotificationEntry(
      babyId: json['baby_id']?.toString() ?? '',
      childName: json['child_name']?.toString() ?? 'Unknown Child',
      vaccineName: json['vaccine_name']?.toString() ?? 'Vaccine',
      doseNumber: json['dose_number'] is int
          ? json['dose_number'] as int
          : int.tryParse(json['dose_number']?.toString() ?? ''),
      guidelineDate: json['guideline_date']?.toString(),
      batchScheduleDate: json['batch_schedule_date']?.toString(),
      targetDate: json['target_date']?.toString(),
      dateSource: json['date_source']?.toString(),
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'today',
    );
  }
}

class DailyNotificationsPayload {
  final List<DailyNotificationEntry> today;
  final List<DailyNotificationEntry> tomorrow;
  final List<DailyNotificationEntry> missed;

  const DailyNotificationsPayload({
    required this.today,
    required this.tomorrow,
    required this.missed,
  });

  bool get hasAnyNotifications =>
      today.isNotEmpty || tomorrow.isNotEmpty || missed.isNotEmpty;

  factory DailyNotificationsPayload.fromJson(Map<String, dynamic> json) {
    List<dynamic> toList(dynamic value) {
      if (value is List) return value;
      return const [];
    }

    return DailyNotificationsPayload(
      today: toList(json['today'])
          .map((item) => DailyNotificationEntry.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      tomorrow: toList(json['tomorrow'])
          .map((item) => DailyNotificationEntry.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      missed: toList(json['missed'])
          .map((item) => DailyNotificationEntry.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }
}


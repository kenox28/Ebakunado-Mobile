class ClosestMissed {
  final String vaccineName;
  final String doseNumber;
  final String? scheduleDate;
  final String? catchUpDate;
  final String status;

  ClosestMissed({
    required this.vaccineName,
    required this.doseNumber,
    this.scheduleDate,
    this.catchUpDate,
    required this.status,
  });

  factory ClosestMissed.fromJson(Map<String, dynamic> json) {
    return ClosestMissed(
      vaccineName: json['vaccine_name'] ?? '',
      doseNumber: json['dose_number']?.toString() ?? '',
      scheduleDate: json['schedule_date'],
      catchUpDate: json['catch_up_date'],
      status: json['status'] ?? '',
    );
  }
}

class ChildSummaryItem {
  final String babyId;
  final String name;
  final String? upcomingDate;
  final String? upcomingVaccine;
  final bool nextIsCatchUp;
  final int missedCount;
  final ClosestMissed? closestMissed;
  final String? qrCode;

  ChildSummaryItem({
    required this.babyId,
    required this.name,
    this.upcomingDate,
    this.upcomingVaccine,
    required this.nextIsCatchUp,
    required this.missedCount,
    this.closestMissed,
    this.qrCode,
  });

  factory ChildSummaryItem.fromJson(Map<String, dynamic> json) {
    return ChildSummaryItem(
      babyId: json['baby_id']?.toString() ?? '',
      name: json['name'] ?? '',
      upcomingDate: json['upcoming_date'],
      upcomingVaccine: json['upcoming_vaccine'],
      nextIsCatchUp: json['next_is_catch_up'] == true,
      missedCount: json['missed_count'] ?? 0,
      closestMissed: json['closest_missed'] != null
          ? ClosestMissed.fromJson(json['closest_missed'])
          : null,
      qrCode: json['qr_code'],
    );
  }
}

class ChildrenSummaryResponse {
  final String status;
  final int upcomingCount;
  final int missedCount;
  final List<ChildSummaryItem> items;

  ChildrenSummaryResponse({
    required this.status,
    required this.upcomingCount,
    required this.missedCount,
    required this.items,
  });

  factory ChildrenSummaryResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final itemsList = data['items'] as List<dynamic>? ?? [];

    return ChildrenSummaryResponse(
      status: json['status'] ?? '',
      upcomingCount: data['upcoming_count'] ?? 0,
      missedCount: data['missed_count'] ?? 0,
      items: itemsList.map((item) => ChildSummaryItem.fromJson(item)).toList(),
    );
  }
}

class AcceptedChild {
  final String babyId;
  final String name;
  final String age;
  final int weeksOld;
  final String gender;
  final String status;
  final String? vaccine;
  final String? dose;
  final String? scheduleDate;
  final int takenCount;
  final int missedCount;
  final int scheduledCount;

  AcceptedChild({
    required this.babyId,
    required this.name,
    required this.age,
    required this.weeksOld,
    required this.gender,
    required this.status,
    this.vaccine,
    this.dose,
    this.scheduleDate,
    required this.takenCount,
    required this.missedCount,
    required this.scheduledCount,
  });

  factory AcceptedChild.fromJson(Map<String, dynamic> json) {
    return AcceptedChild(
      babyId: json['baby_id']?.toString() ?? '',
      name: json['name'] ?? '',
      age: json['age']?.toString() ?? '',
      weeksOld: json['weeks_old'] ?? 0,
      gender: json['gender'] ?? '',
      status: json['status'] ?? '',
      vaccine: json['vaccine'],
      dose: json['dose'],
      scheduleDate: json['schedule_date'],
      takenCount: json['taken_count'] ?? 0,
      missedCount: json['missed_count'] ?? 0,
      scheduledCount: json['scheduled_count'] ?? 0,
    );
  }
}

class DashboardSummary {
  final int totalChildren;
  final int approvedChrDocuments;
  final int pendingChrRequests;
  final int upcomingScheduleToday;

  DashboardSummary({
    required this.totalChildren,
    required this.approvedChrDocuments,
    required this.pendingChrRequests,
    required this.upcomingScheduleToday,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};

    return DashboardSummary(
      totalChildren: data['total_children'] ?? 0,
      approvedChrDocuments: data['approved_chr_documents'] ?? 0,
      pendingChrRequests: data['pending_chr_requests'] ?? 0,
      upcomingScheduleToday: data['upcoming_schedule_today'] ?? 0,
    );
  }
}

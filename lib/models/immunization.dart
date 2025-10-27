class ImmunizationItem {
  final int id;
  final String babyId;
  final String childName;
  final String vaccineName;
  final int doseNumber;
  final String scheduleDate;
  final String? catchUpDate;
  final String? dateGiven;
  final String status;

  ImmunizationItem({
    required this.id,
    required this.babyId,
    required this.childName,
    required this.vaccineName,
    required this.doseNumber,
    required this.scheduleDate,
    this.catchUpDate,
    this.dateGiven,
    required this.status,
  });

  factory ImmunizationItem.fromJson(Map<String, dynamic> json) {
    return ImmunizationItem(
      id: json['id'] ?? 0,
      babyId: json['baby_id'] ?? '',
      childName: json['child_name'] ?? '',
      vaccineName: json['vaccine_name'] ?? '',
      doseNumber: json['dose_number'] ?? 0,
      scheduleDate: json['schedule_date'] ?? '',
      catchUpDate: json['catch_up_date'],
      dateGiven: json['date_given'],
      status: json['status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baby_id': babyId,
      'child_name': childName,
      'vaccine_name': vaccineName,
      'dose_number': doseNumber,
      'schedule_date': scheduleDate,
      'catch_up_date': catchUpDate,
      'date_given': dateGiven,
      'status': status,
    };
  }

  // Helper methods for filtering
  bool get isScheduled => status == 'scheduled';
  bool get isTaken => status == 'taken';
  bool get isMissed => status == 'missed';
  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';

  // Helper to check if this is an upcoming immunization
  bool get isUpcoming {
    if (!isScheduled) return false;

    try {
      final scheduleDateTime = DateTime.parse(scheduleDate);
      final today = DateTime.now();
      return scheduleDateTime.isAfter(today) ||
          scheduleDateTime.isAtSameMomentAs(
            DateTime(today.year, today.month, today.day),
          );
    } catch (e) {
      return false;
    }
  }

  // Helper to format dose display
  String get doseDisplay => 'Dose $doseNumber';

  // Helper to format vaccine with dose
  String get vaccineWithDose => '$vaccineName ($doseDisplay)';
}

class ImmunizationScheduleResponse {
  final String status;
  final List<ImmunizationItem> data;

  ImmunizationScheduleResponse({required this.status, required this.data});

  factory ImmunizationScheduleResponse.fromJson(Map<String, dynamic> json) {
    return ImmunizationScheduleResponse(
      status: json['status'] ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => ImmunizationItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  // Helper to filter by baby ID
  List<ImmunizationItem> getForBaby(String babyId) {
    return data.where((item) => item.babyId == babyId).toList();
  }

  // Helper to get upcoming immunizations for a baby
  List<ImmunizationItem> getUpcomingForBaby(String babyId) {
    return getForBaby(babyId).where((item) => item.isUpcoming).toList()
      ..sort((a, b) => a.scheduleDate.compareTo(b.scheduleDate));
  }

  // Helper to get taken immunizations for a baby
  List<ImmunizationItem> getTakenForBaby(String babyId) {
    return getForBaby(babyId).where((item) => item.isTaken).toList()
      ..sort((a, b) => a.scheduleDate.compareTo(b.scheduleDate));
  }

  // Helper to get missed immunizations for a baby
  List<ImmunizationItem> getMissedForBaby(String babyId) {
    return getForBaby(babyId).where((item) => item.isMissed).toList()
      ..sort((a, b) => a.scheduleDate.compareTo(b.scheduleDate));
  }
}

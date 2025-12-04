import '../utils/vaccine_catalog.dart';

class ImmunizationItem {
  final int id;
  final String babyId;
  final String childName;
  final String vaccineName;
  final int doseNumber;
  final String scheduleDate;
  final String? batchScheduleDate;
  final String? catchUpDate;
  final String? dateGiven;
  final String status;
  final String originalVaccineName;
  final VaccineDoseInfo doseInfo;
  final bool isSuppressed;
  final double? height;
  final double? weight;
  final String? muac;
  final String? remarks;
  final String? nextScheduleDate;

  ImmunizationItem({
    required this.id,
    required this.babyId,
    required this.childName,
    required this.vaccineName,
    required this.doseNumber,
    required this.scheduleDate,
    this.batchScheduleDate,
    this.catchUpDate,
    this.dateGiven,
    required this.status,
    required this.originalVaccineName,
    required this.doseInfo,
    this.isSuppressed = false,
    this.height,
    this.weight,
    this.muac,
    this.remarks,
    this.nextScheduleDate,
  });

  factory ImmunizationItem.fromJson(Map<String, dynamic> json) {
    final rawName = json['vaccine_name']?.toString() ?? '';
    final normalizedName = VaccineCatalog.normalizeIncomingName(rawName);
    final doseInfo = VaccineCatalog.describeDose(normalizedName ?? rawName);

    // Parse numeric fields - handle both string and numeric types
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed;
      }
      return null;
    }

    return ImmunizationItem(
      id: json['id'] ?? 0,
      babyId: json['baby_id'] ?? '',
      childName: json['child_name'] ?? '',
      vaccineName: normalizedName ?? rawName,
      doseNumber: json['dose_number'] ?? 0,
      scheduleDate: json['schedule_date'] ?? '',
      batchScheduleDate: json['batch_schedule_date']?.toString(),
      catchUpDate: json['catch_up_date'],
      dateGiven: json['date_given'],
      status: json['status'] ?? '',
      originalVaccineName: rawName,
      doseInfo: doseInfo,
      isSuppressed:
          normalizedName == null &&
          VaccineCatalog.shouldIgnoreLegacyName(rawName),
      height: parseDouble(json['height']),
      weight: parseDouble(json['weight']),
      muac: json['muac']?.toString(),
      remarks: json['remarks']?.toString(),
      nextScheduleDate: json['next_schedule_date']?.toString(),
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
      'batch_schedule_date': batchScheduleDate,
      'catch_up_date': catchUpDate,
      'date_given': dateGiven,
      'status': status,
      'original_vaccine_name': originalVaccineName,
      'height': height,
      'weight': weight,
      'muac': muac,
      'remarks': remarks,
      'next_schedule_date': nextScheduleDate,
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
  String get doseDisplay {
    if (doseInfo.seriesDose != null) {
      final total = doseInfo.totalDoses;
      if (total > 0) {
        return 'Dose ${doseInfo.seriesDose} of $total';
      }
      return 'Dose ${doseInfo.seriesDose}';
    }
    return doseNumber > 0 ? 'Dose $doseNumber' : 'Dose';
  }

  // Helper to format vaccine with dose
  String get vaccineWithDose => doseInfo.seriesWithDose;

  bool get shouldDisplay => !isSuppressed;
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
              .where((item) => item.shouldDisplay)
              .toList() ??
          [],
    );
  }

  // Helper to filter by baby ID
  List<ImmunizationItem> getForBaby(String babyId) {
    return data
        .where((item) => item.babyId == babyId && item.shouldDisplay)
        .toList();
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

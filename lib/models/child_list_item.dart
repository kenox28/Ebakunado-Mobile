class ChildListItem {
  final String id;
  final String babyId;
  final String name;
  final int age;
  final double weeksOld;
  final String gender;
  final String vaccine;
  final String dose;
  final String scheduleDate;
  final String status;
  final int takenCount;
  final int missedCount;
  final int scheduledCount;

  ChildListItem({
    required this.id,
    required this.babyId,
    required this.name,
    required this.age,
    required this.weeksOld,
    required this.gender,
    required this.vaccine,
    required this.dose,
    required this.scheduleDate,
    required this.status,
    required this.takenCount,
    required this.missedCount,
    required this.scheduledCount,
  });

  factory ChildListItem.fromJson(Map<String, dynamic> json) {
    return ChildListItem(
      id: json['id']?.toString() ?? '',
      babyId: json['baby_id'] ?? '',
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      weeksOld: (json['weeks_old'] ?? 0.0).toDouble(),
      gender: json['gender'] ?? '',
      vaccine: json['vaccine'] ?? '',
      dose: json['dose']?.toString() ?? '',
      scheduleDate: json['schedule_date'] ?? '',
      status: json['status'] ?? '',
      takenCount: json['taken_count'] ?? 0,
      missedCount: json['missed_count'] ?? 0,
      scheduledCount: json['scheduled_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baby_id': babyId,
      'name': name,
      'age': age,
      'weeks_old': weeksOld,
      'gender': gender,
      'vaccine': vaccine,
      'dose': dose,
      'schedule_date': scheduleDate,
      'status': status,
      'taken_count': takenCount,
      'missed_count': missedCount,
      'scheduled_count': scheduledCount,
    };
  }

  // Helper method to format age display
  String get ageDisplay {
    if (age > 0) {
      return '$age years';
    } else if (weeksOld > 0) {
      return '${weeksOld.toStringAsFixed(1)} weeks';
    } else {
      return '';
    }
  }

  // Helper method to check if child is pending
  bool get isPending => status == 'pending';

  // Helper method to check if child is accepted
  bool get isAccepted => status == 'accepted';
}

class AcceptedChildResponse {
  final String status;
  final List<ChildListItem> data;

  AcceptedChildResponse({required this.status, required this.data});

  factory AcceptedChildResponse.fromJson(Map<String, dynamic> json) {
    return AcceptedChildResponse(
      status: json['status'] ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => ChildListItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

import 'dart:io';

class ChildRegistrationForm {
  final String childFname;
  final String childLname;
  final DateTime birthDate;
  final String? placeOfBirth;
  final String address;
  final double? birthWeight;
  final double? birthHeight;
  final String? bloodType;
  final String? allergies;
  final String gender; // 'Male' or 'Female'
  final String motherName;
  final String? fatherName;
  final DateTime? lmp;
  final String? familyPlanning;
  final String? deliveryType;
  final String? birthOrder;
  final String? birthAttendant;
  final String? birthAttendantOthers;
  final File? babysCard;
  final List<String> vaccinesReceived;

  ChildRegistrationForm({
    required this.childFname,
    required this.childLname,
    required this.birthDate,
    this.placeOfBirth,
    required this.address,
    this.birthWeight,
    this.birthHeight,
    this.bloodType,
    this.allergies,
    required this.gender,
    required this.motherName,
    this.fatherName,
    this.lmp,
    this.familyPlanning,
    this.deliveryType,
    this.birthOrder,
    this.birthAttendant,
    this.birthAttendantOthers,
    this.babysCard,
    required this.vaccinesReceived,
  });

  Map<String, dynamic> toFormData() {
    final Map<String, dynamic> formData = {
      'child_fname': childFname,
      'child_lname': childLname,
      'child_birth_date': birthDate.toIso8601String().split(
        'T',
      )[0], // YYYY-MM-DD format
      'place_of_birth': placeOfBirth ?? '',
      'address': address,
      'birth_weight': birthWeight?.toString() ?? '',
      'birth_height': birthHeight?.toString() ?? '',
      'blood_type': bloodType ?? '',
      'allergies': allergies ?? '',
      'child_gender': gender,
      'mother_name': motherName,
      'father_name': fatherName ?? '',
      'lmp': lmp?.toIso8601String().split('T')[0] ?? '',
      'family_planning': familyPlanning ?? '',
      'delivery_type': deliveryType ?? '',
      'birth_order': birthOrder ?? '',
      'birth_attendant': birthAttendant ?? '',
      'birth_attendant_others': birthAttendantOthers ?? '',
      'vaccines_received': vaccinesReceived.join(','),
    };

    return formData;
  }
}

class ClaimChildRequest {
  final String familyCode;

  ClaimChildRequest({required this.familyCode});

  Map<String, dynamic> toFormData() {
    return {'family_code': familyCode};
  }
}

class AddChildResponse {
  final bool success;
  final String message;
  final String? babyId;
  final String? childName;
  final int? vaccinesTransferred;
  final int? vaccinesScheduled;
  final int? totalRecordsCreated;
  final String? uploadStatus;

  AddChildResponse({
    required this.success,
    required this.message,
    this.babyId,
    this.childName,
    this.vaccinesTransferred,
    this.vaccinesScheduled,
    this.totalRecordsCreated,
    this.uploadStatus,
  });

  factory AddChildResponse.fromJson(Map<String, dynamic> json) {
    // Robust success detection
    final statusRaw = json['status'];
    bool success = false;

    if (statusRaw == true || statusRaw == 1) {
      success = true;
    } else if (statusRaw is String) {
      final statusLower = statusRaw.trim().toLowerCase();
      success = statusLower == 'success' || statusLower == 'ok';
    }

    // Fallback: if we have meaningful data, consider it successful
    if (!success &&
        (json['baby_id'] != null || (json['total_records_created'] ?? 0) > 0)) {
      success = true;
    }

    return AddChildResponse(
      success: success,
      message: json['message'] ?? '',
      babyId: json['baby_id'],
      childName: json['child_name'],
      vaccinesTransferred: json['vaccines_transferred'],
      vaccinesScheduled: json['vaccines_scheduled'],
      totalRecordsCreated: json['total_records_created'],
      uploadStatus: json['upload_status'],
    );
  }
}

class ClaimChildResponse {
  final bool success;
  final String message;
  final String? babyId;
  final String? childName;

  ClaimChildResponse({
    required this.success,
    required this.message,
    this.babyId,
    this.childName,
  });

  factory ClaimChildResponse.fromJson(Map<String, dynamic> json) {
    // Robust success detection
    final statusRaw = json['status'];
    bool success = false;

    if (statusRaw == true || statusRaw == 1) {
      success = true;
    } else if (statusRaw is String) {
      final statusLower = statusRaw.trim().toLowerCase();
      success = statusLower == 'success' || statusLower == 'ok';
    }

    // Fallback: if we have baby_id, consider it successful
    if (!success && json['baby_id'] != null) {
      success = true;
    }

    return ClaimChildResponse(
      success: success,
      message: json['message'] ?? '',
      babyId: json['baby_id'],
      childName: json['child_name'],
    );
  }
}

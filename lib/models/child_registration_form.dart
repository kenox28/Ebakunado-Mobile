import '../utils/vaccine_catalog.dart';

class ChildRegistrationRequest {
  final String childFname;
  final String childLname;
  final String childGender;
  final String childBirthDate;
  final String childAddress;
  final String? placeOfBirth;
  final String? motherName;
  final String? fatherName;
  final String? birthWeight;
  final String? birthHeight;
  final String? birthAttendant;
  final String? birthAttendantOthers;
  final String? deliveryType;
  final String? birthOrder;
  final String? bloodType;
  final String? allergies;
  final String? lpm;
  final String? familyPlanning;
  final String? dateNewbornScreening;
  final String? placeNewbornScreening;
  final List<String> vaccinesReceived;

  const ChildRegistrationRequest({
    required this.childFname,
    required this.childLname,
    required this.childGender,
    required this.childBirthDate,
    required this.childAddress,
    this.placeOfBirth,
    this.motherName,
    this.fatherName,
    this.birthWeight,
    this.birthHeight,
    this.birthAttendant,
    this.birthAttendantOthers,
    this.deliveryType,
    this.birthOrder,
    this.bloodType,
    this.allergies,
    this.lpm,
    this.familyPlanning,
    this.dateNewbornScreening,
    this.placeNewbornScreening,
    this.vaccinesReceived = const [],
  });

  Map<String, dynamic> toFormMap() {
    final map = <String, dynamic>{
      'child_fname': childFname,
      'child_lname': childLname,
      'child_gender': childGender,
      'child_birth_date': childBirthDate,
      'child_address': childAddress,
    };

    void addIfPresent(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        map[key] = value.trim();
      }
    }

    addIfPresent('place_of_birth', placeOfBirth);
    addIfPresent('mother_name', motherName);
    addIfPresent('father_name', fatherName);
    addIfPresent('birth_weight', birthWeight);
    addIfPresent('birth_height', birthHeight);
    addIfPresent('birth_attendant', birthAttendant);
    addIfPresent('birth_attendant_others', birthAttendantOthers);
    addIfPresent('delivery_type', deliveryType);
    addIfPresent('birth_order', birthOrder);
    addIfPresent('blood_type', bloodType);
    addIfPresent('allergies', allergies);
    addIfPresent('lpm', lpm);
    addIfPresent('family_planning', familyPlanning);
    addIfPresent('date_newbornScreening', dateNewbornScreening);
    addIfPresent('placeNewbornScreening', placeNewbornScreening);

    final normalizedVaccines = VaccineCatalog.normalizeOutgoingSelections(
      vaccinesReceived,
    );
    if (normalizedVaccines.isNotEmpty) {
      map['vaccines_received[]'] = normalizedVaccines;
    }

    return map;
  }
}

class ChildRegistrationResult {
  final String status;
  final String message;
  final String? uploadStatus;
  final Map<String, dynamic>? cloudinaryInfo;
  final String? babyId;
  final String? childName;
  final int vaccinesTransferred;
  final int vaccinesScheduled;
  final int totalRecordsCreated;
  final String? qrUploadStatus; // 'success', 'failed', or 'skipped'
  final String? qrUploadError; // Error message if QR upload failed

  const ChildRegistrationResult({
    required this.status,
    required this.message,
    this.uploadStatus,
    this.cloudinaryInfo,
    this.babyId,
    this.childName,
    this.vaccinesTransferred = 0,
    this.vaccinesScheduled = 0,
    this.totalRecordsCreated = 0,
    this.qrUploadStatus,
    this.qrUploadError,
  });

  bool get isSuccess => status.toLowerCase() == 'success';
  bool get qrUploadSuccessful => qrUploadStatus == 'success';
  bool get qrUploadFailed => qrUploadStatus == 'failed';
  bool get qrUploadSkipped => qrUploadStatus == 'skipped';

  factory ChildRegistrationResult.fromJson(Map<String, dynamic> json) {
    int _parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? 0;
    }

    return ChildRegistrationResult(
      status: json['status']?.toString() ?? 'error',
      message: json['message']?.toString() ?? 'Unknown error',
      uploadStatus: json['upload_status']?.toString(),
      cloudinaryInfo: json['cloudinary_info'] is Map<String, dynamic>
          ? json['cloudinary_info'] as Map<String, dynamic>
          : null,
      babyId: json['baby_id']?.toString(),
      childName: json['child_name']?.toString(),
      vaccinesTransferred: _parseInt(json['vaccines_transferred']),
      vaccinesScheduled: _parseInt(json['vaccines_scheduled']),
      totalRecordsCreated: _parseInt(json['total_records_created']),
      qrUploadStatus: json['qr_upload_status']?.toString(),
      qrUploadError: json['qr_upload_error']?.toString(),
    );
  }
}

class ClaimChildResult {
  final String status;
  final String message;
  final String? childName;
  final String? babyId;

  const ClaimChildResult({
    required this.status,
    required this.message,
    this.childName,
    this.babyId,
  });

  bool get isSuccess => status.toLowerCase() == 'success';

  factory ClaimChildResult.fromJson(Map<String, dynamic> json) {
    return ClaimChildResult(
      status: json['status']?.toString() ?? 'error',
      message: json['message']?.toString() ?? 'Unknown error',
      childName: json['child_name']?.toString(),
      babyId: json['baby_id']?.toString(),
    );
  }
}

class ImmunizationApproval {
  final int id;
  final String babyId;
  final String childName;
  final String vaccineName;
  final String status; // 'pending', 'approved', 'rejected'
  final String? certificateUrl; // URL to download certificate
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final String requestType; // 'immunization_record', 'certificate'

  ImmunizationApproval({
    required this.id,
    required this.babyId,
    required this.childName,
    required this.vaccineName,
    required this.status,
    this.certificateUrl,
    required this.requestedAt,
    this.approvedAt,
    required this.requestType,
  });

  factory ImmunizationApproval.fromJson(Map<String, dynamic> json) {
    return ImmunizationApproval(
      id: json['id'] ?? 0,
      babyId: json['baby_id'] ?? '',
      childName: json['child_name'] ?? '',
      vaccineName: json['vaccine_name'] ?? '',
      status: json['status'] ?? 'pending',
      certificateUrl: json['certificate_url'],
      requestedAt:
          DateTime.tryParse(json['requested_at'] ?? '') ?? DateTime.now(),
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'])
          : null,
      requestType: json['request_type'] ?? 'immunization_record',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baby_id': babyId,
      'child_name': childName,
      'vaccine_name': vaccineName,
      'status': status,
      'certificate_url': certificateUrl,
      'requested_at': requestedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'request_type': requestType,
    };
  }

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get hasCertificate =>
      certificateUrl != null && certificateUrl!.isNotEmpty;

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'PENDING';
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }

  String get formattedRequestedAt {
    return '${_getMonthName(requestedAt.month)} ${requestedAt.day.toString().padLeft(2, '0')}, ${requestedAt.year} ${requestedAt.hour.toString().padLeft(2, '0')}:${requestedAt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedApprovedAt {
    if (approvedAt == null) return '';
    return '${_getMonthName(approvedAt!.month)} ${approvedAt!.day.toString().padLeft(2, '0')}, ${approvedAt!.year} ${approvedAt!.hour.toString().padLeft(2, '0')}:${approvedAt!.minute.toString().padLeft(2, '0')}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  // Generate filename for download
  String getFileName() {
    final cleanChildName = childName
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w\-_]'), '');
    final timestamp = approvedAt != null
        ? '${approvedAt!.year}${approvedAt!.month.toString().padLeft(2, '0')}${approvedAt!.day.toString().padLeft(2, '0')}_${approvedAt!.hour.toString().padLeft(2, '0')}${approvedAt!.minute.toString().padLeft(2, '0')}'
        : '${requestedAt.year}${requestedAt.month.toString().padLeft(2, '0')}${requestedAt.day.toString().padLeft(2, '0')}_${requestedAt.hour.toString().padLeft(2, '0')}${requestedAt.minute.toString().padLeft(2, '0')}';

    if (cleanChildName.isNotEmpty) {
      return 'Immunization_${requestType}_${cleanChildName}_$timestamp.pdf';
    } else {
      return 'Immunization_Certificate_$timestamp.pdf';
    }
  }
}

class ImmunizationApprovalsResponse {
  final String status;
  final List<ImmunizationApproval> data;
  final String? message;

  ImmunizationApprovalsResponse({
    required this.status,
    required this.data,
    this.message,
  });

  factory ImmunizationApprovalsResponse.fromJson(Map<String, dynamic> json) {
    return ImmunizationApprovalsResponse(
      status: json['status'] ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => ImmunizationApproval.fromJson(item))
              .toList() ??
          [],
      message: json['message'],
    );
  }
}

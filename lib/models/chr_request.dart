class ChrRequest {
  final String id;
  final String userId;
  final String babyId;
  final String requestType; // 'transfer' or 'school'
  final String status; // 'pendingCHR', 'approved', 'rejected'
  final String? docUrl;
  final String createdAt;
  final String? approvedAt;

  ChrRequest({
    required this.id,
    required this.userId,
    required this.babyId,
    required this.requestType,
    required this.status,
    this.docUrl,
    required this.createdAt,
    this.approvedAt,
  });

  factory ChrRequest.fromJson(Map<String, dynamic> json) {
    return ChrRequest(
      id: json['id']?.toString() ?? '',
      userId: json['user_id'] ?? '',
      babyId: json['baby_id'] ?? '',
      requestType: json['request_type'] ?? '',
      status: json['status'] ?? '',
      docUrl: json['doc_url'],
      createdAt: json['created_at'] ?? '',
      approvedAt: json['approved_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'baby_id': babyId,
      'request_type': requestType,
      'status': status,
      'doc_url': docUrl,
      'created_at': createdAt,
      'approved_at': approvedAt,
    };
  }

  // Helper methods for status
  bool get isPending => status == 'pendingCHR';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  // Helper method for request type display
  String get requestTypeDisplay {
    switch (requestType) {
      case 'transfer':
        return 'Transfer Request';
      case 'school':
        return 'School Request';
      default:
        return requestType;
    }
  }

  // Helper method for status display
  String get statusDisplay {
    switch (status) {
      case 'pendingCHR':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }
}

class ChrRequestResponse {
  final String status;
  final List<ChrRequest> data;

  ChrRequestResponse({required this.status, required this.data});

  factory ChrRequestResponse.fromJson(Map<String, dynamic> json) {
    return ChrRequestResponse(
      status: json['status'] ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => ChrRequest.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class ChrDocStatusResponse {
  final String status;
  final String chrStatus; // 'none', 'pending', 'approved', 'new_records'
  final ChrRequest? latestRequest;
  final bool hasNewerRecords;

  ChrDocStatusResponse({
    required this.status,
    required this.chrStatus,
    this.latestRequest,
    required this.hasNewerRecords,
  });

  factory ChrDocStatusResponse.fromJson(Map<String, dynamic> json) {
    return ChrDocStatusResponse(
      status: json['status'] ?? '',
      chrStatus: json['chr_status'] ?? 'none',
      latestRequest: json['latest_request'] != null
          ? ChrRequest.fromJson(json['latest_request'])
          : null,
      hasNewerRecords: json['has_newer_records'] ?? false,
    );
  }
}

class ChrStatusItem {
  final String babyId;
  final String childFname;
  final String childLname;
  final String chrStatus;
  final Map<String, dynamic>? latestRequest;
  final bool hasNewerRecords;

  ChrStatusItem({
    required this.babyId,
    required this.childFname,
    required this.childLname,
    required this.chrStatus,
    this.latestRequest,
    required this.hasNewerRecords,
  });

  factory ChrStatusItem.fromJson(Map<String, dynamic> json) {
    return ChrStatusItem(
      babyId: json['baby_id'] ?? '',
      childFname: json['child_fname'] ?? '',
      childLname: json['child_lname'] ?? '',
      chrStatus: json['chr_status'] ?? 'none',
      latestRequest: json['latest_request'],
      hasNewerRecords: json['has_newer_records'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baby_id': babyId,
      'child_fname': childFname,
      'child_lname': childLname,
      'chr_status': chrStatus,
      'latest_request': latestRequest,
      'has_newer_records': hasNewerRecords,
    };
  }

  // Helper method to get full name
  String get fullName {
    final fname = childFname.trim();
    final lname = childLname.trim();
    if (fname.isEmpty && lname.isEmpty) return '';
    if (fname.isEmpty) return lname;
    if (lname.isEmpty) return fname;
    return '$fname $lname';
  }

  // Helper methods for CHR status
  bool get isNone => chrStatus == 'none';
  bool get isPending => chrStatus == 'pending';
  bool get isApproved => chrStatus == 'approved';
  bool get hasNewRecords => chrStatus == 'new_records';
}

class ChildListResponse {
  final String status;
  final List<ChrStatusItem> data;

  ChildListResponse({required this.status, required this.data});

  factory ChildListResponse.fromJson(Map<String, dynamic> json) {
    return ChildListResponse(
      status: json['status'] ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => ChrStatusItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

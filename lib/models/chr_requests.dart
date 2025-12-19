class ChrRequest {
  final int id;
  final String babyId;
  final String childName;
  final String requestType; // 'transfer' or 'school'
  final String status; // 'approved'
  final String docUrl; // Cloudinary URL
  final DateTime generatedAt;
  final DateTime createdAt;

  ChrRequest({
    required this.id,
    required this.babyId,
    required this.childName,
    required this.requestType,
    required this.status,
    required this.docUrl,
    required this.generatedAt,
    required this.createdAt,
  });

  factory ChrRequest.fromJson(Map<String, dynamic> json) {
    return ChrRequest(
      id: json['id'] ?? 0,
      babyId: json['baby_id'] ?? '',
      childName: json['child_name'] ?? '',
      requestType: json['request_type'] ?? '',
      status: json['status'] ?? '',
      docUrl: json['doc_url'] ?? '',
      generatedAt:
          DateTime.tryParse(json['approved_at'] ?? json['generated_at'] ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baby_id': babyId,
      'child_name': childName,
      'request_type': requestType,
      'status': status,
      'doc_url': docUrl,
      'approved_at': generatedAt.toIso8601String(),
      'generated_at': generatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper methods
  bool get isApproved => status == 'approved';

  String get requestTypeDisplay {
    switch (requestType) {
      case 'transfer':
        return 'TRANSFER';
      case 'school':
        return 'SCHOOL';
      default:
        return requestType.toUpperCase();
    }
  }

  String get formattedGeneratedAt {
    return '${_getMonthName(generatedAt.month)} ${generatedAt.day.toString().padLeft(2, '0')}, ${generatedAt.year} ${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';
  }
  
  // Keep for backward compatibility
  @Deprecated('Use formattedGeneratedAt instead')
  String get formattedApprovedAt => formattedGeneratedAt;

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
    final timestamp =
        '${generatedAt.year}${generatedAt.month.toString().padLeft(2, '0')}${generatedAt.day.toString().padLeft(2, '0')}_${generatedAt.hour.toString().padLeft(2, '0')}${generatedAt.minute.toString().padLeft(2, '0')}';

    if (cleanChildName.isNotEmpty) {
      return 'CHR_${requestType}_${cleanChildName}_$timestamp.pdf';
    } else {
      return 'CHR_Document_$timestamp.pdf';
    }
  }
}

class ChrRequestsResponse {
  final String status;
  final List<ChrRequest> data;

  ChrRequestsResponse({required this.status, required this.data});

  factory ChrRequestsResponse.fromJson(Map<String, dynamic> json) {
    return ChrRequestsResponse(
      status: json['status'] ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => ChrRequest.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class DownloadResult {
  final bool success;
  final String? errorMessage;
  final String? filePath;

  DownloadResult({required this.success, this.errorMessage, this.filePath});

  factory DownloadResult.success(String filePath) {
    return DownloadResult(success: true, filePath: filePath);
  }

  factory DownloadResult.failure(String errorMessage) {
    return DownloadResult(success: false, errorMessage: errorMessage);
  }
}

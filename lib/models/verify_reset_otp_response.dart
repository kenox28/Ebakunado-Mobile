class VerifyResetOtpResponse {
  final bool success;
  final String message;

  VerifyResetOtpResponse({required this.success, required this.message});

  factory VerifyResetOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyResetOtpResponse(
      success: json['status'] == 'success',
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'success': success, 'message': message};
  }
}


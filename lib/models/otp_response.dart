class OtpResponse {
  final bool success;
  final String message;
  final String? verifiedPhone;
  final int? expiresIn;

  OtpResponse({
    required this.success,
    required this.message,
    this.verifiedPhone,
    this.expiresIn,
  });

  factory OtpResponse.fromJson(Map<String, dynamic> json) {
    return OtpResponse(
      success: json['status'] == 'success',
      message: json['message'] ?? '',
      verifiedPhone: json['verified_phone'],
      expiresIn: json['expires_in'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'verified_phone': verifiedPhone,
      'expires_in': expiresIn,
    };
  }
}

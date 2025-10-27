class ForgotPasswordResponse {
  final bool success;
  final String message;
  final String? userType;
  final String? contactType; // 'email' or 'phone'
  final int? expiresIn;

  ForgotPasswordResponse({
    required this.success,
    required this.message,
    this.userType,
    this.contactType,
    this.expiresIn,
  });

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResponse(
      success: json['status'] == 'success',
      message: json['message'] ?? '',
      userType: json['user_type'],
      contactType: json['contact_type'],
      expiresIn: json['expires_in'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'user_type': userType,
      'contact_type': contactType,
      'expires_in': expiresIn,
    };
  }
}


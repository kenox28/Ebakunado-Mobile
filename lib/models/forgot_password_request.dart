class ForgotPasswordRequest {
  final String emailPhone;

  ForgotPasswordRequest({required this.emailPhone});

  Map<String, dynamic> toJson() {
    return {'email_phone': emailPhone};
  }

  factory ForgotPasswordRequest.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordRequest(emailPhone: json['email_phone'] ?? '');
  }
}


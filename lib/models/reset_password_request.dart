class ResetPasswordRequest {
  final String newPassword;
  final String confirmPassword;

  ResetPasswordRequest({
    required this.newPassword,
    required this.confirmPassword,
  });

  Map<String, dynamic> toJson() {
    return {'new_password': newPassword, 'confirm_password': confirmPassword};
  }

  factory ResetPasswordRequest.fromJson(Map<String, dynamic> json) {
    return ResetPasswordRequest(
      newPassword: json['new_password'] ?? '',
      confirmPassword: json['confirm_password'] ?? '',
    );
  }
}


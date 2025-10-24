import 'user.dart';

class LoginResponse {
  final String status;
  final String message;
  final String? userType;
  final String? redirectUrl;
  final User? user;

  LoginResponse({
    required this.status,
    required this.message,
    this.userType,
    this.redirectUrl,
    this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      userType: json['user_type'],
      redirectUrl: json['redirect_url'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  bool get isSuccess => status == 'success' || status == 'already_logged_in';
  bool get isAlreadyLoggedIn => status == 'already_logged_in';
}

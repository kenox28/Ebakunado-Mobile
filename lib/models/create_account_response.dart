class CreateAccountResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? debug;

  CreateAccountResponse({
    required this.success,
    required this.message,
    this.debug,
  });

  factory CreateAccountResponse.fromJson(Map<String, dynamic> json) {
    return CreateAccountResponse(
      success: json['status'] == 'success',
      message: json['message'] ?? '',
      debug: json['debug'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'success': success, 'message': message, 'debug': debug};
  }
}

class VerifyResetOtpRequest {
  final String otp;

  VerifyResetOtpRequest({required this.otp});

  Map<String, dynamic> toJson() {
    return {'otp': otp};
  }

  factory VerifyResetOtpRequest.fromJson(Map<String, dynamic> json) {
    return VerifyResetOtpRequest(otp: json['otp'] ?? '');
  }
}


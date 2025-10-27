class OtpVerification {
  final String otp;

  OtpVerification({required this.otp});

  Map<String, dynamic> toJson() {
    return {'otp': otp};
  }

  factory OtpVerification.fromJson(Map<String, dynamic> json) {
    return OtpVerification(otp: json['otp'] ?? '');
  }
}

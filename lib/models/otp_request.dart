class OtpRequest {
  final String phoneNumber;

  OtpRequest({required this.phoneNumber});

  Map<String, dynamic> toJson() {
    return {'phone_number': phoneNumber};
  }

  factory OtpRequest.fromJson(Map<String, dynamic> json) {
    return OtpRequest(phoneNumber: json['phone_number'] ?? '');
  }
}

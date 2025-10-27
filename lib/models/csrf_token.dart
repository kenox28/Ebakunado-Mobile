class CsrfToken {
  final String csrfToken;

  CsrfToken({required this.csrfToken});

  factory CsrfToken.fromJson(Map<String, dynamic> json) {
    return CsrfToken(csrfToken: json['csrf_token'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'csrf_token': csrfToken};
  }
}

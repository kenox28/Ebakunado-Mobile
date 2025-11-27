class CreateAccountRequest {
  final String fname;
  final String lname;
  final String email;
  final String number; // Changed from phoneNumber to number
  final String gender;
  final String province;
  final String cityMunicipality;
  final String barangay;
  final String purok;
  final String password;
  final String confirmPassword;
  final String csrfToken;
  final bool mobileAppRequest;
  final bool skipOtp;
  final bool agreedToTerms;

  CreateAccountRequest({
    required this.fname,
    required this.lname,
    required this.email,
    required this.number,
    required this.gender,
    required this.province,
    required this.cityMunicipality,
    required this.barangay,
    required this.purok,
    required this.password,
    required this.confirmPassword,
    required this.csrfToken,
    this.mobileAppRequest = true,
    this.skipOtp = false,
    this.agreedToTerms = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'fname': fname,
      'lname': lname,
      'email': email,
      'number': number, // Changed from phone_number to number
      'gender': gender,
      'province': province,
      'city_municipality': cityMunicipality,
      'barangay': barangay,
      'purok': purok,
      'password': password,
      'confirm_password': confirmPassword,
      'csrf_token': csrfToken,
      'mobile_app_request': mobileAppRequest.toString(),
      'skip_otp': skipOtp.toString(),
      'agree_terms': agreedToTerms ? 'yes' : 'no',
    };
  }

  factory CreateAccountRequest.fromJson(Map<String, dynamic> json) {
    return CreateAccountRequest(
      fname: json['fname'] ?? '',
      lname: json['lname'] ?? '',
      email: json['email'] ?? '',
      number: json['number'] ?? '',
      gender: json['gender'] ?? '',
      province: json['province'] ?? '',
      cityMunicipality: json['city_municipality'] ?? '',
      barangay: json['barangay'] ?? '',
      purok: json['purok'] ?? '',
      password: json['password'] ?? '',
      confirmPassword: json['confirm_password'] ?? '',
      csrfToken: json['csrf_token'] ?? '',
      mobileAppRequest: json['mobile_app_request'] == 'true',
      skipOtp: json['skip_otp'] == 'true',
      agreedToTerms: json['agree_terms'] == 'yes',
    );
  }
}

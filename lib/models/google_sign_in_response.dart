/// Response model for Google Sign-In/Sign-Up endpoints
///
/// Used by:
/// - google_signup_flutter.php
/// - google_login_flutter.php
class GoogleSignInResponse {
  final String status;
  final String message;
  final String? token;
  final int? tokenExpiresIn;
  final GoogleUser? user;

  GoogleSignInResponse({
    required this.status,
    required this.message,
    this.token,
    this.tokenExpiresIn,
    this.user,
  });

  factory GoogleSignInResponse.fromJson(Map<String, dynamic> json) {
    return GoogleSignInResponse(
      status: json['status'] ?? 'error',
      message: json['message'] ?? '',
      token: json['token'],
      tokenExpiresIn: json['token_expires_in'],
      user: json['user'] != null ? GoogleUser.fromJson(json['user']) : null,
    );
  }

  /// Account created successfully (new user)
  bool get isSuccess => status == 'success';

  /// Account already exists (returning user logged in)
  bool get isExists => status == 'exists';

  /// Error occurred
  bool get isError => status == 'error';

  /// User is authenticated (either new signup or existing login)
  bool get isAuthenticated => isSuccess || isExists;
}

/// User data returned from Google Sign-In endpoints
class GoogleUser {
  final String userId;
  final String fname;
  final String lname;
  final String email;
  final String? phoneNumber;
  final String? profileImg;

  GoogleUser({
    required this.userId,
    required this.fname,
    required this.lname,
    required this.email,
    this.phoneNumber,
    this.profileImg,
  });

  factory GoogleUser.fromJson(Map<String, dynamic> json) {
    return GoogleUser(
      userId: json['user_id'] ?? '',
      fname: json['fname'] ?? '',
      lname: json['lname'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'],
      profileImg: json['profileimg'] ?? json['profileImg'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'fname': fname,
      'lname': lname,
      'email': email,
      'phone_number': phoneNumber,
      'profileImg': profileImg,
    };
  }

  String get fullName => '$fname $lname'.trim();
}

/// Request model for Google Sign-Up (new users need to provide profile info)
class GoogleSignUpRequest {
  final String credential; // Google ID Token
  final String phoneNumber;
  final String gender;
  final String province;
  final String cityMunicipality;
  final String barangay;
  final String? purok;

  GoogleSignUpRequest({
    required this.credential,
    required this.phoneNumber,
    required this.gender,
    required this.province,
    required this.cityMunicipality,
    required this.barangay,
    this.purok,
  });

  Map<String, dynamic> toJson() {
    return {
      'credential': credential,
      'phone_number': phoneNumber,
      'gender': gender,
      'province': province,
      'city_municipality': cityMunicipality,
      'barangay': barangay,
      if (purok != null && purok!.isNotEmpty) 'purok': purok,
    };
  }
}

/// Request model for Google Login (only needs credential)
class GoogleLoginRequest {
  final String credential; // Google ID Token

  GoogleLoginRequest({required this.credential});

  Map<String, dynamic> toJson() {
    return {'credential': credential};
  }
}

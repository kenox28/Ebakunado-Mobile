class UserProfile {
  final String userId;
  final String fname;
  final String lname;
  final String email;
  final String? phoneNumber;
  final String? gender;
  final String? relationship; // 'Parents' or 'Guardian'
  final String? place;
  final String? philhealthNo;
  final String? nhts;
  final String? profileImg;
  final String role;
  final DateTime createdAt;
  final DateTime updated;

  UserProfile({
    required this.userId,
    required this.fname,
    required this.lname,
    required this.email,
    this.phoneNumber,
    this.gender,
    this.relationship,
    this.place,
    this.philhealthNo,
    this.nhts,
    this.profileImg,
    required this.role,
    required this.createdAt,
    required this.updated,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] ?? '',
      fname: json['fname'] ?? '',
      lname: json['lname'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'],
      gender: json['gender'],
      relationship: json['relationship'],
      place: json['place'],
      philhealthNo: json['philhealth_no'],
      nhts: json['nhts'],
      profileImg: json['profileimg'],
      role: json['role'] ?? 'user',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updated: DateTime.tryParse(json['updated'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'fname': fname,
      'lname': lname,
      'email': email,
      'phone_number': phoneNumber,
      'gender': gender,
      'relationship': relationship,
      'place': place,
      'philhealth_no': philhealthNo,
      'nhts': nhts,
      'profileimg': profileImg,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  String get fullName => '$fname $lname';
  String get displayName => fullName.trim().isEmpty ? email : fullName;
}

class ProfileUpdateRequest {
  final String fname;
  final String lname;
  final String email;
  final String? phoneNumber;
  final String? gender;
  final String? place;
  final String? philhealthNo;
  final String? nhts;
  final String? currentPassword;
  final String? newPassword;
  final String? confirmPassword;

  ProfileUpdateRequest({
    required this.fname,
    required this.lname,
    required this.email,
    this.phoneNumber,
    this.gender,
    this.place,
    this.philhealthNo,
    this.nhts,
    this.currentPassword,
    this.newPassword,
    this.confirmPassword,
  });

  Map<String, dynamic> toFormData() {
    final Map<String, dynamic> formData = {
      'fname': fname,
      'lname': lname,
      'email': email,
      'phone_number': phoneNumber ?? '',
      'gender': gender ?? '',
      'place': place ?? '',
      'philhealth_no': philhealthNo ?? '',
      'nhts': nhts ?? '',
    };

    // Only include password fields if they're provided
    if (currentPassword != null && currentPassword!.isNotEmpty) {
      formData['current_password'] = currentPassword;
    }
    if (newPassword != null && newPassword!.isNotEmpty) {
      formData['new_password'] = newPassword;
    }
    if (confirmPassword != null && confirmPassword!.isNotEmpty) {
      formData['confirm_password'] = confirmPassword;
    }

    return formData;
  }
}

class ProfileDataResponse {
  final bool success;
  final String message;
  final UserProfile? profile;

  ProfileDataResponse({
    required this.success,
    required this.message,
    this.profile,
  });

  factory ProfileDataResponse.fromJson(Map<String, dynamic> json) {
    return ProfileDataResponse(
      success: json['status'] == 'success',
      message: json['message'] ?? '',
      profile: json['data'] != null ? UserProfile.fromJson(json['data']) : null,
    );
  }
}

class ProfileUpdateResponse {
  final bool success;
  final String message;

  ProfileUpdateResponse({required this.success, required this.message});

  factory ProfileUpdateResponse.fromJson(Map<String, dynamic> json) {
    return ProfileUpdateResponse(
      success: json['status'] == 'success',
      message: json['message'] ?? '',
    );
  }
}

class PhotoUploadResponse {
  final bool success;
  final String message;
  final String? imageUrl;

  PhotoUploadResponse({
    required this.success,
    required this.message,
    this.imageUrl,
  });

  factory PhotoUploadResponse.fromJson(Map<String, dynamic> json) {
    return PhotoUploadResponse(
      success: json['status'] == 'success',
      message: json['message'] ?? '',
      imageUrl: json['image_url'],
    );
  }
}

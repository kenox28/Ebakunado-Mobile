class User {
  final String fname;
  final String lname;
  final String email;
  final String? profileImg;

  User({
    required this.fname,
    required this.lname,
    required this.email,
    this.profileImg,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      fname: json['fname'] ?? '',
      lname: json['lname'] ?? '',
      email: json['email'] ?? '',
      profileImg: json['profileimg'] ?? json['profileImg'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fname': fname,
      'lname': lname,
      'email': email,
      'profileImg': profileImg,
    };
  }

  String get fullName => '$fname $lname';
}

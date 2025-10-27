class LocationData {
  final String province;
  final String? cityMunicipality;
  final String? barangay;
  final String? purok;

  LocationData({
    required this.province,
    this.cityMunicipality,
    this.barangay,
    this.purok,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      province: json['province'] ?? '',
      cityMunicipality: json['city_municipality'] ?? json['city'],
      barangay: json['barangay'],
      purok: json['purok'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'province': province,
      'city_municipality': cityMunicipality,
      'barangay': barangay,
      'purok': purok,
    };
  }

  LocationData copyWith({
    String? province,
    String? cityMunicipality,
    String? barangay,
    String? purok,
  }) {
    return LocationData(
      province: province ?? this.province,
      cityMunicipality: cityMunicipality ?? this.cityMunicipality,
      barangay: barangay ?? this.barangay,
      purok: purok ?? this.purok,
    );
  }
}

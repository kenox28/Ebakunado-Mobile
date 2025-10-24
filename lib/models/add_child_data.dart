class AddChildData {
  final String childFname;
  final String childLname;
  final String childGender;
  final String childBirthDate;
  final String placeOfBirth;
  final String motherName;
  final String fatherName;
  final String address;
  final String birthWeight;
  final String birthHeight;
  final String birthAttendant;
  final String deliveryType;
  final String birthOrder;
  final String familyNumber;
  final String philhealthNo;
  final String nhts;
  final String bloodType;
  final String allergies;
  final String lpm;
  final String familyPlanning;
  final bool exclusiveBreastfeeding1mo;
  final bool exclusiveBreastfeeding2mo;
  final bool exclusiveBreastfeeding3mo;
  final bool exclusiveBreastfeeding4mo;
  final bool exclusiveBreastfeeding5mo;
  final bool exclusiveBreastfeeding6mo;
  final String complementaryFeeding6mo;
  final String complementaryFeeding7mo;
  final String complementaryFeeding8mo;
  final String motherTdDose1Date;
  final String motherTdDose2Date;
  final String motherTdDose3Date;
  final String motherTdDose4Date;
  final String motherTdDose5Date;

  AddChildData({
    required this.childFname,
    required this.childLname,
    required this.childGender,
    required this.childBirthDate,
    required this.placeOfBirth,
    required this.motherName,
    required this.fatherName,
    required this.address,
    required this.birthWeight,
    required this.birthHeight,
    required this.birthAttendant,
    required this.deliveryType,
    required this.birthOrder,
    required this.familyNumber,
    required this.philhealthNo,
    required this.nhts,
    required this.bloodType,
    required this.allergies,
    required this.lpm,
    required this.familyPlanning,
    required this.exclusiveBreastfeeding1mo,
    required this.exclusiveBreastfeeding2mo,
    required this.exclusiveBreastfeeding3mo,
    required this.exclusiveBreastfeeding4mo,
    required this.exclusiveBreastfeeding5mo,
    required this.exclusiveBreastfeeding6mo,
    required this.complementaryFeeding6mo,
    required this.complementaryFeeding7mo,
    required this.complementaryFeeding8mo,
    required this.motherTdDose1Date,
    required this.motherTdDose2Date,
    required this.motherTdDose3Date,
    required this.motherTdDose4Date,
    required this.motherTdDose5Date,
  });

  Map<String, dynamic> toJson() {
    return {
      'child_fname': childFname,
      'child_lname': childLname,
      'child_gender': childGender,
      'child_birth_date': childBirthDate,
      'place_of_birth': placeOfBirth,
      'mother_name': motherName,
      'father_name': fatherName,
      'address': address,
      'birth_weight': birthWeight,
      'birth_height': birthHeight,
      'birth_attendant': birthAttendant,
      'delivery_type': deliveryType,
      'birth_order': birthOrder,
      'family_number': familyNumber,
      'philhealth_no': philhealthNo,
      'nhts': nhts,
      'blood_type': bloodType,
      'allergies': allergies,
      'lpm': lpm,
      'family_planning': familyPlanning,
      'exclusive_breastfeeding_1mo': exclusiveBreastfeeding1mo,
      'exclusive_breastfeeding_2mo': exclusiveBreastfeeding2mo,
      'exclusive_breastfeeding_3mo': exclusiveBreastfeeding3mo,
      'exclusive_breastfeeding_4mo': exclusiveBreastfeeding4mo,
      'exclusive_breastfeeding_5mo': exclusiveBreastfeeding5mo,
      'exclusive_breastfeeding_6mo': exclusiveBreastfeeding6mo,
      'complementary_feeding_6mo': complementaryFeeding6mo,
      'complementary_feeding_7mo': complementaryFeeding7mo,
      'complementary_feeding_8mo': complementaryFeeding8mo,
      'mother_td_dose1_date': motherTdDose1Date,
      'mother_td_dose2_date': motherTdDose2Date,
      'mother_td_dose3_date': motherTdDose3Date,
      'mother_td_dose4_date': motherTdDose4Date,
      'mother_td_dose5_date': motherTdDose5Date,
    };
  }
}

class AddChildResponse {
  final String status;
  final String message;
  final String? babyId;

  AddChildResponse({required this.status, required this.message, this.babyId});

  factory AddChildResponse.fromJson(Map<String, dynamic> json) {
    return AddChildResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      babyId: json['baby_id'],
    );
  }
}

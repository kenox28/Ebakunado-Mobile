class ChildDetail {
  final int id;
  final String babyId;
  final String userId;
  final String name;
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
  final int age;
  final double weeksOld;
  final String status;
  final String qrCode;
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

  ChildDetail({
    required this.id,
    required this.babyId,
    required this.userId,
    required this.name,
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
    required this.age,
    required this.weeksOld,
    required this.status,
    required this.qrCode,
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

  factory ChildDetail.fromJson(Map<String, dynamic> json) {
    return ChildDetail(
      id: json['id'] ?? 0,
      babyId: json['baby_id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      childFname: json['child_fname'] ?? '',
      childLname: json['child_lname'] ?? '',
      childGender: json['child_gender'] ?? '',
      childBirthDate: json['child_birth_date'] ?? '',
      placeOfBirth: json['place_of_birth'] ?? '',
      motherName: json['mother_name'] ?? '',
      fatherName: json['father_name'] ?? '',
      address: json['address'] ?? '',
      birthWeight: json['birth_weight']?.toString() ?? '',
      birthHeight: json['birth_height']?.toString() ?? '',
      birthAttendant: json['birth_attendant'] ?? '',
      deliveryType: json['delivery_type'] ?? '',
      birthOrder: json['birth_order'] ?? '',
      familyNumber: json['family_number'] ?? '',
      philhealthNo: json['philhealth_no'] ?? '',
      nhts: json['nhts'] ?? '',
      age: json['age'] ?? 0,
      weeksOld: (json['weeks_old'] ?? 0.0).toDouble(),
      status: json['status'] ?? '',
      qrCode: json['qr_code'] ?? '',
      bloodType: json['blood_type'] ?? '',
      allergies: json['allergies'] ?? '',
      lpm: json['lpm'] ?? '',
      familyPlanning: json['family_planning'] ?? '',
      exclusiveBreastfeeding1mo: json['exclusive_breastfeeding_1mo'] ?? false,
      exclusiveBreastfeeding2mo: json['exclusive_breastfeeding_2mo'] ?? false,
      exclusiveBreastfeeding3mo: json['exclusive_breastfeeding_3mo'] ?? false,
      exclusiveBreastfeeding4mo: json['exclusive_breastfeeding_4mo'] ?? false,
      exclusiveBreastfeeding5mo: json['exclusive_breastfeeding_5mo'] ?? false,
      exclusiveBreastfeeding6mo: json['exclusive_breastfeeding_6mo'] ?? false,
      complementaryFeeding6mo: json['complementary_feeding_6mo'] ?? '',
      complementaryFeeding7mo: json['complementary_feeding_7mo'] ?? '',
      complementaryFeeding8mo: json['complementary_feeding_8mo'] ?? '',
      motherTdDose1Date: json['mother_td_dose1_date'] ?? '',
      motherTdDose2Date: json['mother_td_dose2_date'] ?? '',
      motherTdDose3Date: json['mother_td_dose3_date'] ?? '',
      motherTdDose4Date: json['mother_td_dose4_date'] ?? '',
      motherTdDose5Date: json['mother_td_dose5_date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baby_id': babyId,
      'user_id': userId,
      'name': name,
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
      'age': age,
      'weeks_old': weeksOld,
      'status': status,
      'qr_code': qrCode,
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

class ChildDetailResponse {
  final String status;
  final List<ChildDetail> data;

  ChildDetailResponse({required this.status, required this.data});

  factory ChildDetailResponse.fromJson(Map<String, dynamic> json) {
    return ChildDetailResponse(
      status: json['status'] ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => ChildDetail.fromJson(item))
              .toList() ??
          [],
    );
  }
}

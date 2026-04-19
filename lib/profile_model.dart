class ProfileModel {
  final String fullName;
  final int age;
  final String gender;
  final String stateLiving;
  final String height;
  final String countryOfBirth;
  final String vietnamBirthProvince;
  final String occupation;
  final String highestEducation;
  final String haveChildren;
  final String maritalStatus;
  final String annualIncome;
  final String religion;
  final String residentStatus;
  final String smoking;
  final String drinking;
  final double maxDistance;
  final String relationshipGoal;
  final String currentLocation;
  final String promptQuestion;
  final String promptAnswer;
  final List<String> photoUrls;

  const ProfileModel({
    this.fullName = '',
    this.age = 18,
    this.gender = '',
    this.stateLiving = '',
    this.height = '',
    this.countryOfBirth = '',
    this.vietnamBirthProvince = '',
    this.occupation = '',
    this.highestEducation = '',
    this.haveChildren = '',
    this.maritalStatus = '',
    this.annualIncome = '',
    this.religion = '',
    this.residentStatus = '',
    this.smoking = '',
    this.drinking = '',
    this.maxDistance = 50,
    this.relationshipGoal = '',
    this.currentLocation = '',
    this.promptQuestion = '',
    this.promptAnswer = '',
    this.photoUrls = const [],
  });

  ProfileModel copyWith({
    String? fullName,
    int? age,
    String? gender,
    String? stateLiving,
    String? height,
    String? countryOfBirth,
    String? vietnamBirthProvince,
    String? occupation,
    String? highestEducation,
    String? haveChildren,
    String? maritalStatus,
    String? annualIncome,
    String? religion,
    String? residentStatus,
    String? smoking,
    String? drinking,
    double? maxDistance,
    String? relationshipGoal,
    String? currentLocation,
    String? promptQuestion,
    String? promptAnswer,
    List<String>? photoUrls,
  }) {
    return ProfileModel(
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      stateLiving: stateLiving ?? this.stateLiving,
      height: height ?? this.height,
      countryOfBirth: countryOfBirth ?? this.countryOfBirth,
      vietnamBirthProvince:
          vietnamBirthProvince ?? this.vietnamBirthProvince,
      occupation: occupation ?? this.occupation,
      highestEducation: highestEducation ?? this.highestEducation,
      haveChildren: haveChildren ?? this.haveChildren,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      annualIncome: annualIncome ?? this.annualIncome,
      religion: religion ?? this.religion,
      residentStatus: residentStatus ?? this.residentStatus,
      smoking: smoking ?? this.smoking,
      drinking: drinking ?? this.drinking,
      maxDistance: maxDistance ?? this.maxDistance,
      relationshipGoal: relationshipGoal ?? this.relationshipGoal,
      currentLocation: currentLocation ?? this.currentLocation,
      promptQuestion: promptQuestion ?? this.promptQuestion,
      promptAnswer: promptAnswer ?? this.promptAnswer,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'age': age,
      'gender': gender,
      'stateLiving': stateLiving,
      'height': height,
      'countryOfBirth': countryOfBirth,
      'vietnamBirthProvince': vietnamBirthProvince,
      'occupation': occupation,
      'highestEducation': highestEducation,
      'haveChildren': haveChildren,
      'maritalStatus': maritalStatus,
      'annualIncome': annualIncome,
      'religion': religion,
      'residentStatus': residentStatus,
      'smoking': smoking,
      'drinking': drinking,
      'maxDistance': maxDistance,
      'relationshipGoal': relationshipGoal,
      'currentLocation': currentLocation,
      'promptQuestion': promptQuestion,
      'promptAnswer': promptAnswer,
      'photoUrls': photoUrls,
    };
  }

  factory ProfileModel.fromMap(Map<String, dynamic>? map) {
    final data = map ?? <String, dynamic>{};
    return ProfileModel(
      fullName: (data['fullName'] ?? '') as String,
      age: (data['age'] ?? 18) as int,
      gender: (data['gender'] ?? '') as String,
      stateLiving: (data['stateLiving'] ?? '') as String,
      height: (data['height'] ?? '') as String,
      countryOfBirth: (data['countryOfBirth'] ?? '') as String,
      vietnamBirthProvince: (data['vietnamBirthProvince'] ?? '') as String,
      occupation: (data['occupation'] ?? '') as String,
      highestEducation: (data['highestEducation'] ?? '') as String,
      haveChildren: (data['haveChildren'] ?? '') as String,
      maritalStatus: (data['maritalStatus'] ?? '') as String,
      annualIncome: (data['annualIncome'] ?? '') as String,
      religion: (data['religion'] ?? '') as String,
      residentStatus: (data['residentStatus'] ?? '') as String,
      smoking: (data['smoking'] ?? '') as String,
      drinking: (data['drinking'] ?? '') as String,
      maxDistance: ((data['maxDistance'] ?? 50) as num).toDouble(),
      relationshipGoal: (data['relationshipGoal'] ?? '') as String,
      currentLocation: (data['currentLocation'] ?? '') as String,
      promptQuestion: (data['promptQuestion'] ?? '') as String,
      promptAnswer: (data['promptAnswer'] ?? '') as String,
      photoUrls: List<String>.from(data['photoUrls'] ?? const []),
    );
  }
}
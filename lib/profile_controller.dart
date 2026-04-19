import 'package:flutter/foundation.dart';
import 'profile_model.dart';
import 'profile_repository.dart';

class ProfileController extends ChangeNotifier {
  final ProfileRepository repository;

  ProfileController({
    required this.repository,
  });

  ProfileModel _profile = const ProfileModel();
  ProfileModel get profile => _profile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      _profile = await repository.loadProfile();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> save(ProfileModel newProfile) async {
    _profile = newProfile;
    notifyListeners();
    await repository.saveProfile(_profile);
  }

  Future<void> updateFullName(String value) async {
    _profile = _profile.copyWith(fullName: value);
    notifyListeners();
    await repository.updateField('fullName', value);
  }

  Future<void> updateAge(int value) async {
    _profile = _profile.copyWith(age: value);
    notifyListeners();
    await repository.updateField('age', value);
  }

  Future<void> updateGender(String value) async {
    _profile = _profile.copyWith(gender: value);
    notifyListeners();
    await repository.updateField('gender', value);
  }

  Future<void> updateStateLiving(String value) async {
    _profile = _profile.copyWith(stateLiving: value);
    notifyListeners();
    await repository.updateField('stateLiving', value);
  }

  Future<void> updateHeight(String value) async {
    _profile = _profile.copyWith(height: value);
    notifyListeners();
    await repository.updateField('height', value);
  }

  Future<void> updateCountryOfBirth(String value) async {
    _profile = _profile.copyWith(countryOfBirth: value);
    notifyListeners();
    await repository.updateField('countryOfBirth', value);
  }

  Future<void> updateVietnamBirthProvince(String value) async {
    _profile = _profile.copyWith(vietnamBirthProvince: value);
    notifyListeners();
    await repository.updateField('vietnamBirthProvince', value);
  }

  Future<void> updateOccupation(String value) async {
    _profile = _profile.copyWith(occupation: value);
    notifyListeners();
    await repository.updateField('occupation', value);
  }

  Future<void> updateHighestEducation(String value) async {
    _profile = _profile.copyWith(highestEducation: value);
    notifyListeners();
    await repository.updateField('highestEducation', value);
  }

  Future<void> updateHaveChildren(String value) async {
    _profile = _profile.copyWith(haveChildren: value);
    notifyListeners();
    await repository.updateField('haveChildren', value);
  }

  Future<void> updateMaritalStatus(String value) async {
    _profile = _profile.copyWith(maritalStatus: value);
    notifyListeners();
    await repository.updateField('maritalStatus', value);
  }

  Future<void> updateAnnualIncome(String value) async {
    _profile = _profile.copyWith(annualIncome: value);
    notifyListeners();
    await repository.updateField('annualIncome', value);
  }

  Future<void> updateReligion(String value) async {
    _profile = _profile.copyWith(religion: value);
    notifyListeners();
    await repository.updateField('religion', value);
  }

  Future<void> updateResidentStatus(String value) async {
    _profile = _profile.copyWith(residentStatus: value);
    notifyListeners();
    await repository.updateField('residentStatus', value);
  }

  Future<void> updateSmoking(String value) async {
    _profile = _profile.copyWith(smoking: value);
    notifyListeners();
    await repository.updateField('smoking', value);
  }

  Future<void> updateDrinking(String value) async {
    _profile = _profile.copyWith(drinking: value);
    notifyListeners();
    await repository.updateField('drinking', value);
  }

  Future<void> updateMaxDistance(double value) async {
    _profile = _profile.copyWith(maxDistance: value);
    notifyListeners();
    await repository.updateField('maxDistance', value);
  }

  Future<void> updateRelationshipGoal(String value) async {
    _profile = _profile.copyWith(relationshipGoal: value);
    notifyListeners();
    await repository.updateField('relationshipGoal', value);
  }

  Future<void> updateCurrentLocation(String value) async {
    _profile = _profile.copyWith(currentLocation: value);
    notifyListeners();
    await repository.updateField('currentLocation', value);
  }

  Future<void> updatePrompt({
    required String question,
    required String answer,
  }) async {
    _profile = _profile.copyWith(
      promptQuestion: question,
      promptAnswer: answer,
    );
    notifyListeners();
    await repository.saveProfile(_profile);
  }

  Future<void> updatePhotoUrls(List<String> value) async {
    _profile = _profile.copyWith(photoUrls: value);
    notifyListeners();
    await repository.updateField('photoUrls', value);
  }
}
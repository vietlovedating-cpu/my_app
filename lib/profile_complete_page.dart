import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'prompt_intro_page.dart';

class ProfileCompletePage extends StatefulWidget {
  final String languageCode;
  final String selectedCountry;
  final String selectedState;
  final String firstName;
  final String address;
  final String gender;
  final String datingPreference;
  final int age;
  final int minAgePreference;
  final int maxAgePreference;
  final String maritalStatus;
  final List<String> relationshipGoals;
  final List<String> photoUrls;
  final String highestEducation;
  final String occupation;
  final String annualIncome;
  final int heightCm;
  final String countryOfBirth;
  final String vietnamBirthProvince;
  final String religion;
  final String residentStatus;
  final int maxDistanceKm;
  final String smoking;
  final String drinking;

  const ProfileCompletePage({
    super.key,
    required this.languageCode,
    required this.selectedCountry,
    required this.selectedState,
    required this.firstName,
    required this.address,
    required this.gender,
    required this.datingPreference,
    required this.age,
    required this.minAgePreference,
    required this.maxAgePreference,
    required this.maritalStatus,
    required this.relationshipGoals,
    required this.photoUrls,
    required this.highestEducation,
    required this.occupation,
    required this.annualIncome,
    required this.heightCm,
    required this.countryOfBirth,
    required this.vietnamBirthProvince,
    required this.religion,
    required this.residentStatus,
    required this.maxDistanceKm,
    required this.smoking,
    required this.drinking,
  });

  @override
  State<ProfileCompletePage> createState() => _ProfileCompletePageState();
}

class _ProfileCompletePageState extends State<ProfileCompletePage>
    with SingleTickerProviderStateMixin {
  bool isSaving = false;
  late final AnimationController _heartController;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.92,
      upperBound: 1.08,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _finishProfile() async {
    if (isSaving) return;

    final isVi = widget.languageCode == 'vi';
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Không tìm thấy người dùng' : 'User not found',
          ),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
  'uid': user.uid,
  'email': user.email ?? '',

  /// Basic
  'firstName': widget.firstName,
  'genderLower': widget.gender.trim().toLowerCase(),
  'datingPreference': widget.datingPreference,
  'datingPreferenceLower': widget.datingPreference.trim().toLowerCase(),
  'age': widget.age,
  'minAgePreference': widget.minAgePreference,
  'maxAgePreference': widget.maxAgePreference,

  /// Status / goals
  'maritalStatus': widget.maritalStatus,
  'maritalStatusLower': widget.maritalStatus.trim().toLowerCase(),
  'relationshipGoals': widget.relationshipGoals,
  'relationshipGoal':
      widget.relationshipGoals.isNotEmpty ? widget.relationshipGoals.first : '',

  /// Photos
  'photos': widget.photoUrls,
  'photoUrls': widget.photoUrls,
  'mainPhotoUrl': widget.photoUrls.isNotEmpty ? widget.photoUrls.first : '',

  /// Education / work / income
  'highestEducation': widget.highestEducation,
  'highestDegree': widget.highestEducation,
  'occupation': widget.occupation,
  'jobTitle': widget.occupation,
  'annualIncome': widget.annualIncome,

  /// Profile details
  'heightCm': widget.heightCm,
  'height': '${widget.heightCm} cm',

  'countryOfBirth': widget.countryOfBirth,
  'countryOfBirthLower': widget.countryOfBirth.trim().toLowerCase(),

  'vietnamBirthProvince': widget.vietnamBirthProvince,
  'vietnamBirthProvinceLower':
      widget.vietnamBirthProvince.trim().toLowerCase(),

  /// HomePage đang đọc cityOfBirth
  'cityOfBirth': widget.vietnamBirthProvince,

  'religion': widget.religion,
  'religionLower': widget.religion.trim().toLowerCase(),

  'residentStatus': widget.residentStatus,
  'residentStatusLower': widget.residentStatus.trim().toLowerCase(),

  'maxDistanceKm': widget.maxDistanceKm,

  'smoking': widget.smoking,
  'smokingLower': widget.smoking.trim().toLowerCase(),

  'drinking': widget.drinking,
  'drinkingLower': widget.drinking.trim().toLowerCase(),

  /// Online + flags
  'isOnline': true,
  'profileCompleted': true,
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PromptIntroPage(languageCode: widget.languageCode),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Lỗi khi lưu dữ liệu: $e' : 'Error saving data: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget _floatingCircle({
    required double size,
    required double top,
    required double left,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.languageCode == 'vi';

    return Scaffold(
      backgroundColor: const Color(0xFFF8DCE5),
      body: SafeArea(
        child: Stack(
          children: [
            _floatingCircle(
              size: 90,
              top: 30,
              left: 20,
              color: Colors.white.withOpacity(0.25),
            ),
            _floatingCircle(
              size: 55,
              top: 110,
              left: 280,
              color: Colors.pink.withOpacity(0.18),
            ),
            _floatingCircle(
              size: 70,
              top: 520,
              left: 30,
              color: Colors.white.withOpacity(0.22),
            ),
            _floatingCircle(
              size: 40,
              top: 620,
              left: 300,
              color: Colors.pink.withOpacity(0.16),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  ScaleTransition(
                    scale: _heartController,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withOpacity(0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.pink,
                        size: 62,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 26,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.93),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.auto_awesome, color: Colors.pink),
                            SizedBox(width: 6),
                            Icon(Icons.favorite, color: Colors.pink),
                            SizedBox(width: 6),
                            Icon(Icons.auto_awesome, color: Colors.pink),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          isVi
                              ? 'Chúc mừng bạn đã hoàn thành hồ sơ!'
                              : 'Congratulations, your profile is complete!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isVi
                              ? 'Nhấn “Tiếp theo” để bắt đầu khám phá người phù hợp với bạn.'
                              : 'Tap “Next” to start discovering people who match you.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.45,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _finishProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isVi ? 'Tiếp theo →' : 'Next →',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'marital_status_page.dart';


class AgeRangePage extends StatefulWidget {
  final String languageCode;
  final String selectedCountry;
  final String selectedState;
  final String firstName;
  final String address;
  final String gender;
  final String datingPreference;
  final int age;

  final int? initialMinAge;
  final int? initialMaxAge;
  final String? initialMaritalStatus;
  final List<String> relationshipGoals;
  final List<String>? initialPhotoUrls;
  final bool isEditingFromHome;

  const AgeRangePage({
    super.key,
    required this.languageCode,
    required this.selectedCountry,
    required this.selectedState,
    required this.firstName,
    required this.address,
    required this.gender,
    required this.datingPreference,
    required this.age,
    this.initialMinAge,
    this.initialMaxAge,
    this.initialMaritalStatus,
    required this.relationshipGoals,
    this.initialPhotoUrls,
    this.isEditingFromHome = false,
  });

  @override
  State<AgeRangePage> createState() => _AgeRangePageState();
}

class _AgeRangePageState extends State<AgeRangePage> {
  double minAge = 18.0;
  double maxAge = 35.0;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    minAge = (widget.initialMinAge ?? 18).toDouble();
    maxAge = (widget.initialMaxAge ?? 35).toDouble();

    if (minAge > maxAge) {
      minAge = 18.0;
      maxAge = 35.0;
    }
  }

  Future<void> _goNext() async {
  final isVi = widget.languageCode == 'vi';
  final user = FirebaseAuth.instance.currentUser;

  if (minAge > maxAge) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi
              ? 'Tuổi tối thiểu không được lớn hơn tuổi tối đa'
              : 'Minimum age cannot be greater than maximum age',
        ),
      ),
    );
    return;
  }

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi
              ? 'Không tìm thấy tài khoản'
              : 'User account not found',
        ),
      ),
    );
    return;
  }


  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'minAgePreference': minAge.round(),
      'maxAgePreference': maxAge.round(),
      'onboardingStep': 'marital_status',
      'ageRangeUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaritalStatusPage(
          languageCode: widget.languageCode,
          selectedCountry: widget.selectedCountry,
          selectedState: widget.selectedState,
          firstName: widget.firstName,
          address: widget.address,
          gender: widget.gender,
          datingPreference: widget.datingPreference,
          age: widget.age,
          minAgePreference: minAge.round(),
          maxAgePreference: maxAge.round(),
          initialMaritalStatus: widget.initialMaritalStatus,
          relationshipGoals: widget.relationshipGoals,
          initialPhotoUrls: widget.initialPhotoUrls ?? [],
          isEditingFromHome: widget.isEditingFromHome,
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    setState(() {
      isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi
              ? 'Không thể lưu độ tuổi mong muốn. Vui lòng thử lại.'
              : 'Unable to save preferred age range. Please try again.',
        ),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final isVi = widget.languageCode == 'vi';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      appBar: AppBar(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        title: Text(isVi ? 'Độ tuổi mong muốn' : 'Preferred Age Range'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                isVi
                    ? 'Bạn muốn hẹn hò với người bao nhiêu tuổi?'
                    : 'What age range are you looking to date?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isVi
                      ? 'Tuổi tối thiểu: ${minAge.round()}'
                      : 'Min age: ${minAge.round()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.pink,
                  inactiveTrackColor: Colors.pink.shade100,
                  thumbColor: Colors.pink,
                  overlayColor: Colors.pink.withOpacity(0.2),
                  trackHeight: 5.0,
                ),
                child: Slider(
                  value: minAge,
                  min: 18,
                  max: 80,
                  divisions: 62,
                  label: minAge.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      minAge = value;
                      if (minAge > maxAge) {
                        maxAge = minAge;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isVi
                      ? 'Tuổi tối đa: ${maxAge.round()}'
                      : 'Max age: ${maxAge.round()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.pink,
                  inactiveTrackColor: Colors.pink.shade100,
                  thumbColor: Colors.pink,
                  overlayColor: Colors.pink.withOpacity(0.2),
                  trackHeight: 5.0,
                ),
                child: Slider(
                  value: maxAge,
                  min: 18,
                  max: 80,
                  divisions: 62,
                  label: maxAge.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      maxAge = value;
                      if (maxAge < minAge) {
                        minAge = maxAge;
                      }
                    });
                  },
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                 onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSaving
    ? const SizedBox(
        width: 23,
        height: 23,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: Colors.white,
        ),
      )
    : Text(
        isVi ? 'Tiếp theo →' : 'Next →',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
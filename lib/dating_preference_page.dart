import 'package:flutter/material.dart';
import 'age_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatingPreferencePage extends StatefulWidget {
  final String languageCode;
  final String selectedCountry;
  final String selectedState;
  final String firstName;
  final String address;
  final String gender;

  final String? initialDatingPreference;
  final int? initialAge;
  final int? initialMinAge;
  final int? initialMaxAge;
  final bool isEditingFromHome;

  const DatingPreferencePage({
    super.key,
    required this.languageCode,
    required this.selectedCountry,
    required this.selectedState,
    required this.firstName,
    required this.address,
    required this.gender,
    this.initialDatingPreference,
    this.initialAge,
    this.initialMinAge,
    this.initialMaxAge,
    this.isEditingFromHome = false,
  });

  @override
  State<DatingPreferencePage> createState() =>
      _DatingPreferencePageState();
}

class _DatingPreferencePageState extends State<DatingPreferencePage> {
  String? selectedPreference;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    selectedPreference = widget.initialDatingPreference;
  }
  Future<void> _saveAndContinue() async {
  final isVi = widget.languageCode == 'vi';
  final user = FirebaseAuth.instance.currentUser;

  if (selectedPreference == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi
              ? 'Vui lòng chọn đối tượng hẹn hò'
              : 'Please choose who you want to date',
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
      'datingPreference': selectedPreference,
      'onboardingStep': 'age',
      'datingPreferenceUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgePage(
          languageCode: widget.languageCode,
          selectedCountry: widget.selectedCountry,
          selectedState: widget.selectedState,
          firstName: widget.firstName,
          address: widget.address,
          gender: widget.gender,
          datingPreference: selectedPreference!,
          initialAge: widget.initialAge,
          initialMinAge: widget.initialMinAge,
          initialMaxAge: widget.initialMaxAge,
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
              ? 'Không thể lưu lựa chọn. Vui lòng thử lại.'
              : 'Unable to save your preference. Please try again.',
        ),
      ),
    );
  }
}

  Widget _buildOptionButton({
    required String label,
    required String value,
    required String? selectedValue,
    required VoidCallback onTap,
  }) {
    final bool isSelected = selectedValue == value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color.fromARGB(255, 233, 140, 171)
                      .withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? const Color.fromARGB(255, 233, 140, 171)
              : Colors.white,
          foregroundColor: isSelected
              ? Colors.white
              : const Color.fromARGB(255, 233, 30, 99),
          side: BorderSide(
            color: isSelected
                ? const Color.fromARGB(255, 233, 140, 171)
                : const Color.fromARGB(255, 233, 170, 190),
            width: isSelected ? 1.8 : 1.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? const Color.fromARGB(255, 12, 12, 12)
                : const Color.fromARGB(255, 233, 30, 99),
            letterSpacing: 0.2,
            shadows: isSelected
                ? [
                    const Shadow(
                      blurRadius: 6,
                      color: Colors.black26,
                      offset: Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.languageCode == 'vi';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        title: Text(isVi ? 'Đối tượng hẹn hò' : 'Dating Preference'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              /// CARD TITLE
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      isVi
                          ? 'Bạn muốn hẹn hò với ai?'
                          : 'Who do you want to date?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D1F26),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isVi
                          ? 'Chọn đối tượng bạn muốn tìm hiểu'
                          : 'Choose who you would like to date',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 34),

              _buildOptionButton(
                label: isVi ? 'Nữ' : 'Female',
                value: 'female',
                selectedValue: selectedPreference,
                onTap: () {
                  setState(() {
                    selectedPreference = 'female';
                  });
                },
              ),

              const SizedBox(height: 16),

              _buildOptionButton(
                label: isVi ? 'Nam' : 'Male',
                value: 'male',
                selectedValue: selectedPreference,
                onTap: () {
                  setState(() {
                    selectedPreference = 'male';
                  });
                },
              ),

              const SizedBox(height: 16),

              _buildOptionButton(
                label: isVi ? 'Khác' : 'Other',
                value: 'other',
                selectedValue: selectedPreference,
                onTap: () {
                  setState(() {
                    selectedPreference = 'other';
                  });
                },
              ),

              const Spacer(),

              /// NEXT BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
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
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
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
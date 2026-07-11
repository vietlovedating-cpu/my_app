import 'package:flutter/material.dart';
import 'drinking_page.dart';

class SmokingPage extends StatefulWidget {
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

  const SmokingPage({
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
  });

  @override
  State<SmokingPage> createState() => _SmokingPageState();
}

class _SmokingPageState extends State<SmokingPage> {
  String? selectedSmoking;

  void _goNext() {
    final isVi = widget.languageCode == 'vi';

    if (selectedSmoking == null || selectedSmoking!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Vui lòng chọn 1 đáp án' : 'Please choose an option',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrinkingPage(
          languageCode: widget.languageCode,
          selectedCountry: widget.selectedCountry,
          selectedState: widget.selectedState,
          firstName: widget.firstName,
          address: widget.address,
          gender: widget.gender,
          datingPreference: widget.datingPreference,
          age: widget.age,
          minAgePreference: widget.minAgePreference,
          maxAgePreference: widget.maxAgePreference,
          maritalStatus: widget.maritalStatus,
          relationshipGoals: widget.relationshipGoals,
          photoUrls: widget.photoUrls,
          highestEducation: widget.highestEducation,
          occupation: widget.occupation,
          annualIncome: widget.annualIncome,
          heightCm: widget.heightCm,
          countryOfBirth: widget.countryOfBirth,
          vietnamBirthProvince: widget.vietnamBirthProvince,
          religion: widget.religion,
          residentStatus: widget.residentStatus,
          maxDistanceKm: widget.maxDistanceKm,
          smoking: selectedSmoking!, // key: yes / no / sometimes
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFEAF2)
              : const Color(0xFFFFF7FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.pink : const Color(0xFFFFD6E7),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.pink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: Colors.pink,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.languageCode == 'vi';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        title: Text(isVi ? 'Hút thuốc' : 'Smoking'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVi ? 'Bạn có hút thuốc không?' : 'Do you smoke?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isVi
                    ? 'Chọn đáp án phù hợp nhất với bạn'
                    : 'Choose the option that best describes you',
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),

              _buildOptionCard(
                title: isVi ? 'Có' : 'Yes',
                isSelected: selectedSmoking == 'yes',
                icon: Icons.smoking_rooms,
                onTap: () {
                  setState(() {
                    selectedSmoking = 'yes';
                  });
                },
              ),
              _buildOptionCard(
                title: isVi ? 'Không' : 'No',
                isSelected: selectedSmoking == 'no',
                icon: Icons.smoke_free,
                onTap: () {
                  setState(() {
                    selectedSmoking = 'no';
                  });
                },
              ),
              _buildOptionCard(
                title: isVi ? 'Thỉnh thoảng' : 'Sometimes',
                isSelected: selectedSmoking == 'sometimes',
                icon: Icons.access_time,
                onTap: () {
                  setState(() {
                    selectedSmoking = 'sometimes';
                  });
                },
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isVi ? 'Tiếp theo' : 'Next',
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
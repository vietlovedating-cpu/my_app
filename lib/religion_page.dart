import 'package:flutter/material.dart';
import 'resident_status_page.dart';

class ReligionPage extends StatefulWidget {
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

  const ReligionPage({
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
  });

  @override
  State<ReligionPage> createState() => _ReligionPageState();
}

class _ReligionPageState extends State<ReligionPage> {
  String? selectedReligion; // lưu KEY để match Firebase

  static const List<Map<String, String>> religions = [
    {'key': 'buddhist', 'en': 'Buddhist', 'vi': 'Phật giáo'},
    {'key': 'catholic', 'en': 'Catholic', 'vi': 'Công giáo'},
    {'key': 'christian', 'en': 'Christian', 'vi': 'Cơ đốc giáo'},
    {'key': 'hindu', 'en': 'Hindu', 'vi': 'Ấn Độ giáo'},
    {'key': 'muslim', 'en': 'Muslim', 'vi': 'Hồi giáo'},
    {'key': 'jewish', 'en': 'Jewish', 'vi': 'Do Thái giáo'},
    {'key': 'sikh', 'en': 'Sikh', 'vi': 'Đạo Sikh'},
    {'key': 'taoist', 'en': 'Taoist', 'vi': 'Đạo giáo'},
    {'key': 'no_religion', 'en': 'No religion', 'vi': 'Không tôn giáo'},
    {
      'key': 'prefer_not_to_say',
      'en': 'Prefer not to say',
      'vi': 'Không muốn trả lời',
    },
  ];

  bool get isVi => widget.languageCode == 'vi';

  void _goNext() {
    if (selectedReligion == null || selectedReligion!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Vui lòng chọn tôn giáo' : 'Please select religion',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResidentStatusPage(
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
          religion: selectedReligion!, // truyền KEY sang page sau
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        title: Text(isVi ? 'Tôn giáo' : 'Religion'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVi ? 'Tôn giáo của bạn là gì?' : 'What is your religion?',
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD6E7)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedReligion,
                    isExpanded: true,
                    hint: Text(isVi ? 'Chọn tôn giáo' : 'Select religion'),
                    items: religions.map((item) {
                      return DropdownMenuItem<String>(
                        value: item['key'], // lưu key
                        child: Text(
                          isVi ? item['vi'] ?? '' : item['en'] ?? '',
                        ), // hiện theo ngôn ngữ user
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedReligion = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
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
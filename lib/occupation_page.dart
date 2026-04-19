import 'package:flutter/material.dart';
import 'annual_income_page.dart';

class OccupationPage extends StatefulWidget {
  final String languageCode;
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

  const OccupationPage({
    super.key,
    required this.languageCode,
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
  });

  @override
  State<OccupationPage> createState() => _OccupationPageState();
}

class _OccupationPageState extends State<OccupationPage> {
  String? selectedOccupation;
  final TextEditingController _otherOccupationController =
      TextEditingController();

  static const List<Map<String, String>> occupations = [
    {'key': 'education', 'en': 'Education', 'vi': 'Giáo dục'},
    {'key': 'healthcare', 'en': 'Healthcare', 'vi': 'Y tế'},
    {'key': 'engineering', 'en': 'Engineering', 'vi': 'Kỹ sư'},
    {'key': 'it', 'en': 'IT', 'vi': 'Công nghệ thông tin'},
    {'key': 'business', 'en': 'Business', 'vi': 'Kinh doanh'},
    {'key': 'finance', 'en': 'Finance', 'vi': 'Tài chính'},
    {'key': 'marketing', 'en': 'Marketing', 'vi': 'Marketing'},
    {'key': 'law', 'en': 'Law', 'vi': 'Luật'},
    {'key': 'hospitality', 'en': 'Hospitality', 'vi': 'Nhà hàng - khách sạn'},
    {'key': 'construction', 'en': 'Construction', 'vi': 'Xây dựng'},
    {'key': 'trades', 'en': 'Trades', 'vi': 'Thợ nghề'},
    {'key': 'government', 'en': 'Government', 'vi': 'Chính phủ'},
    {'key': 'student', 'en': 'Student', 'vi': 'Sinh viên'},
    {'key': 'self_employed', 'en': 'Self-employed', 'vi': 'Tự kinh doanh'},
    {'key': 'unemployed', 'en': 'Unemployed', 'vi': 'Thất nghiệp'},
    {'key': 'other', 'en': 'Other', 'vi': 'Khác'},
  ];

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) {
    return isVi ? vi : en;
  }

  void _goNext() {
    if (selectedOccupation == null || selectedOccupation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('Vui lòng chọn công việc', 'Please select your occupation'),
          ),
        ),
      );
      return;
    }

    String occupationToSave = selectedOccupation!;

    if (selectedOccupation == 'other') {
      final customText = _otherOccupationController.text.trim();

      if (customText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr('Vui lòng nhập công việc', 'Please enter your occupation'),
            ),
          ),
        );
        return;
      }

      occupationToSave = customText;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnualIncomePage(
          languageCode: widget.languageCode,
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
          occupation: occupationToSave,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _otherOccupationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5F8),
      appBar: AppBar(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(isVi ? 'Công việc' : 'Occupation'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                isVi ? 'Công việc của bạn là gì?' : 'What is your occupation?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 28),
              DropdownButtonFormField<String>(
                value: selectedOccupation,
                isExpanded: true,
                hint: Text(
                  isVi ? 'Chọn công việc' : 'Select occupation',
                ),
                items: occupations.map((item) {
                  return DropdownMenuItem<String>(
                    value: item['key'],
                    child: Text(
                      isVi ? item['vi'] ?? '' : item['en'] ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedOccupation = value;
                    if (selectedOccupation != 'other') {
                      _otherOccupationController.clear();
                    }
                  });
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFD6E7),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xFFE91E63),
                      width: 1.5,
                    ),
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              if (selectedOccupation == 'other') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _otherOccupationController,
                  decoration: InputDecoration(
                    hintText: isVi
                        ? 'Nhập công việc của bạn'
                        : 'Enter your occupation',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFFFD6E7),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFE91E63),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isVi ? 'Tiếp theo' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
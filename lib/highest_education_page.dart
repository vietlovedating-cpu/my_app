import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'occupation_page.dart';

class HighestEducationPage extends StatefulWidget {
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

  const HighestEducationPage({
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
  });

  @override
  State<HighestEducationPage> createState() =>
      _HighestEducationPageState();
}

class _HighestEducationPageState extends State<HighestEducationPage> {
  String? selectedEducation; // ✅ lưu KEY

  // ✅ DATA LOCAL (KHÔNG dùng app_data.dart)
  static const List<Map<String, String>> educations = [
    {'key': 'high_school', 'en': 'High School', 'vi': 'Trung học'},
    {'key': 'trade', 'en': 'Trade Certificate', 'vi': 'Chứng chỉ nghề'},
    {'key': 'diploma', 'en': 'Diploma', 'vi': 'Cao đẳng'},
    {'key': 'bachelor', 'en': 'Bachelor Degree', 'vi': 'Đại học'},
    {'key': 'postgraduate', 'en': 'Postgraduate', 'vi': 'Nghiên cứu sinh'},
    {'key': 'master', 'en': 'Master Degree', 'vi': 'Thạc sĩ'},
    {'key': 'phd', 'en': 'Doctorate / PhD', 'vi': 'Tiến sĩ'},
    {
      'key': 'prefer_not_to_say',
      'en': 'Prefer not to say',
      'vi': 'Không muốn chia sẻ'
    },
  ];

  bool get isVi => widget.languageCode == 'vi';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5F8),

      appBar: AppBar(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(isVi ? 'Bằng cấp cao nhất' : 'Highest Education'),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              Text(
                isVi
                    ? 'Bằng cấp cao nhất của bạn là gì?'
                    : 'What is your highest level of education?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 28),

              DropdownButtonFormField<String>(
                value: selectedEducation,
                isExpanded: true,
                hint: Text(
                  isVi ? 'Chọn bằng cấp' : 'Select education',
                ),

                items: educations.map((item) {
                  return DropdownMenuItem<String>(
                    value: item['key'], // ✅ lưu key
                    child: Text(
                      isVi ? item['vi']! : item['en']!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),

                onChanged: (value) {
                  setState(() {
                    selectedEducation = value;
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

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,

                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedEducation == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isVi
                                ? 'Vui lòng chọn bằng cấp'
                                : 'Please select your education',
                          ),
                        ),
                      );
                      return;
                    }
final user = FirebaseAuth.instance.currentUser;

if (user != null) {
  await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
    'highestEducation': selectedEducation,

    // 👇 CÁI QUAN TRỌNG
    'onboardingStep': 'occupation',

  }, SetOptions(merge: true));
}
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OccupationPage(
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
                          highestEducation: selectedEducation!, // ✅ KEY
                        ),
                      ),
                    );
                  },

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
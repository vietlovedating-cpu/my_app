import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'have_children_page.dart';

class MaritalStatusPage extends StatefulWidget {
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
  final String? initialMaritalStatus;

  /// thêm dòng này để nhận từ AgeRangePage
  final List<String> relationshipGoals;

  /// dùng khi edit lại từ home
  final List<String>? initialRelationshipGoals;

  final List<String> initialPhotoUrls;
  final bool isEditingFromHome;

  const MaritalStatusPage({
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
    this.initialMaritalStatus,

    /// thêm dòng này
    this.relationshipGoals = const [],

    this.initialRelationshipGoals,
    this.initialPhotoUrls = const [],
    this.isEditingFromHome = false,
  });

  @override
  State<MaritalStatusPage> createState() => _MaritalStatusPageState();
}

class _MaritalStatusPageState extends State<MaritalStatusPage> {
  String? selectedMaritalStatus;
bool isSaving = false;
  @override
  void initState() {
    super.initState();
    selectedMaritalStatus = widget.initialMaritalStatus;
  }

  List<Map<String, String>> get _options => [
        {'value': 'single', 'vi': 'Độc thân', 'en': 'Single'},
        {'value': 'divorced', 'vi': 'Ly hôn', 'en': 'Divorced'},
        {'value': 'widowed', 'vi': 'Góa', 'en': 'Widowed'},
        {'value': 'separated', 'vi': 'Ly thân', 'en': 'Separated'},
        {'value': 'other', 'vi': 'Khác', 'en': 'Other'},
      ];

  Future<void> _goNext() async {
  final isVi = widget.languageCode == 'vi';
  final user = FirebaseAuth.instance.currentUser;

  if (selectedMaritalStatus == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi
              ? 'Vui lòng chọn tình trạng hôn nhân'
              : 'Please select your marital status',
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
      'maritalStatus': selectedMaritalStatus,
      'onboardingStep': 'have_children',
      'maritalStatusUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HaveChildrenPage(
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
          maritalStatus: selectedMaritalStatus!,
          initialRelationshipGoals:
              widget.initialRelationshipGoals ?? widget.relationshipGoals,
          initialPhotoUrls: widget.initialPhotoUrls,
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
              ? 'Không thể lưu tình trạng hôn nhân. Vui lòng thử lại.'
              : 'Unable to save marital status. Please try again.',
        ),
      ),
    );
  }
}

  Widget _buildOptionCard({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFE4EF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.pink : const Color(0xFFFFD6E7),
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
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
              isSelected ? Icons.favorite : Icons.favorite_border,
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
      backgroundColor: const Color(0xFFF8F4F6),
      appBar: AppBar(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        title: Text(
          isVi ? 'Tình trạng hôn nhân' : 'Marital Status',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text(
                isVi
                    ? 'Tình trạng hôn nhân của bạn là gì?'
                    : 'What is your marital status?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isVi
                    ? 'Chọn đáp án phù hợp nhất với bạn'
                    : 'Choose the option that best describes you',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 26),
              Expanded(
                child: ListView(
                  children: _options.map((option) {
                    final value = option['value']!;
                    return _buildOptionCard(
                      title: isVi ? option['vi']! : option['en']!,
                      isSelected: selectedMaritalStatus == value,
                      onTap: () {
                        setState(() {
                          selectedMaritalStatus = value;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
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
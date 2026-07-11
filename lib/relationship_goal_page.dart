import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'photo_intro_page.dart';

class RelationshipGoalPage extends StatefulWidget {
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
  final String haveChildren;

  final List<String>? initialRelationshipGoals;
  final List<String> initialPhotoUrls;
  final bool isEditingFromHome;

  const RelationshipGoalPage({
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
    required this.haveChildren,
    this.initialRelationshipGoals,
    this.initialPhotoUrls = const [],
    this.isEditingFromHome = false,
  });

  @override
  State<RelationshipGoalPage> createState() =>
      _RelationshipGoalPageState();
}

class _RelationshipGoalPageState extends State<RelationshipGoalPage> {
  List<String> selectedRelationshipGoals = [];

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    selectedRelationshipGoals =
        List<String>.from(widget.initialRelationshipGoals ?? []);
  }

  // Dùng KEY cố định để lưu vào Firebase.
  List<Map<String, String>> get _options => [
        {
          'value': 'serious_relationship',
          'vi': 'Mối quan hệ nghiêm túc',
          'en': 'Serious relationship',
        },
        {
          'value': 'long_term_partner',
          'vi': 'Bạn đời lâu dài',
          'en': 'Long-term partner',
        },
        {
          'value': 'friendship_first',
          'vi': 'Bắt đầu từ tình bạn',
          'en': 'Friendship first',
        },
        {
          'value': 'chat_and_get_to_know',
          'vi': 'Trò chuyện và tìm hiểu',
          'en': 'Chat and get to know each other',
        },
      ];

  void _toggleOption(String value) {
    setState(() {
      if (selectedRelationshipGoals.contains(value)) {
        selectedRelationshipGoals.remove(value);
      } else {
        selectedRelationshipGoals.add(value);
      }
    });
  }

  Future<void> _goNext() async {
    final isVi = widget.languageCode == 'vi';

    if (selectedRelationshipGoals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Vui lòng chọn ít nhất 1 kiểu mối quan hệ bạn muốn tìm'
                : 'Please select at least 1 relationship goal',
          ),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Không tìm thấy tài khoản đăng nhập'
                : 'No signed-in account was found',
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
        // Lưu danh sách KEY vào Firebase.
        'relationshipGoals':
            List<String>.from(selectedRelationshipGoals),

        // Lưu thêm dữ liệu hiện tại để tránh mất nếu user thoát onboarding.
        'selectedCountry': widget.selectedCountry,
        'country': widget.selectedCountry,
        'selectedState': widget.selectedState,
        'selectedStateKey': widget.selectedState,
        'address': widget.address,
        'firstName': widget.firstName,
        'gender': widget.gender,
        'datingPreference': widget.datingPreference,
        'age': widget.age,
        'minAgePreference': widget.minAgePreference,
        'maxAgePreference': widget.maxAgePreference,
        'maritalStatus': widget.maritalStatus,
        'haveChildren': widget.haveChildren,

        // Đánh dấu user đã hoàn thành trang relationship goal.
        'onboardingStep': 'relationship_goal_completed',

        // Thời gian cập nhật.
        'relationshipGoalsUpdatedAt':
            FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoIntroPage(
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
            haveChildren: widget.haveChildren,

            // Truyền KEY list sang trang tiếp theo.
            relationshipGoals:
                List<String>.from(selectedRelationshipGoals),

            initialPhotoUrls: widget.initialPhotoUrls,
            isEditingFromHome: widget.isEditingFromHome,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Lỗi lưu relationship goals: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Không thể lưu dữ liệu. Vui lòng thử lại.'
                : 'Unable to save your information. Please try again.',
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

  Widget _buildOptionCard({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isSaving ? null : onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFE4EF)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.pink
                : const Color(0xFFFFD6E7),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.circle_outlined,
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
          isVi
              ? 'Mối quan hệ mong muốn'
              : 'Relationship Goal',
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
                    ? 'Bạn muốn tìm mối quan hệ nào?'
                    : 'What kind of relationship are you looking for?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isVi
                    ? 'Bạn có thể chọn nhiều đáp án'
                    : 'You can select multiple options',
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
                      title: isVi
                          ? option['vi']!
                          : option['en']!,
                      isSelected: selectedRelationshipGoals
                          .contains(value),
                      onTap: () => _toggleOption(value),
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
                    disabledBackgroundColor:
                        Colors.pink.shade200,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
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
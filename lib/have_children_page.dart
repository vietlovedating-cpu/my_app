import 'package:flutter/material.dart';
import 'relationship_goal_page.dart';

class HaveChildrenPage extends StatefulWidget {
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
  final List<String>? initialRelationshipGoals;

  final List<String> initialPhotoUrls;
  final bool isEditingFromHome;

  final String? initialHaveChildren;

  const HaveChildrenPage({
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

    this.relationshipGoals = const [],
    this.initialRelationshipGoals,
    this.initialPhotoUrls = const [],
    this.isEditingFromHome = false,
    this.initialHaveChildren,
  });

  @override
  State<HaveChildrenPage> createState() => _HaveChildrenPageState();
}

class _HaveChildrenPageState extends State<HaveChildrenPage> {
  String? selectedOption;

  @override
  void initState() {
    super.initState();
    selectedOption = widget.initialHaveChildren;
  }

  List<Map<String, String>> get _options => [
        {'value': 'no', 'vi': 'Chưa có', 'en': 'No'},
        {'value': 'yes', 'vi': 'Có con', 'en': 'Have children'},
        {'value': 'want', 'vi': 'Muốn có', 'en': 'Want children'},
        {'value': 'not_sure', 'vi': 'Chưa chắc', 'en': 'Not sure'},
      ];

  void _goNext() {
    final isVi = widget.languageCode == 'vi';

    if (selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Vui lòng chọn một đáp án'
                : 'Please select an option',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RelationshipGoalPage(
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

          // 👇 truyền thêm field mới
          haveChildren: selectedOption!,

          initialRelationshipGoals:
              widget.initialRelationshipGoals ?? widget.relationshipGoals,
          initialPhotoUrls: widget.initialPhotoUrls,
          isEditingFromHome: widget.isEditingFromHome,
        ),
      ),
    );
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
          isVi ? 'Con cái' : 'Children',
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
                    ? 'Bạn có con chưa?'
                    : 'Do you have children?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                isVi
                    ? 'Chọn câu trả lời phù hợp nhất'
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
                      isSelected: selectedOption == value,
                      onTap: () {
                        setState(() {
                          selectedOption = value;
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
                  child: Text(
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
import 'package:flutter/material.dart';
import 'dating_preference_page.dart';


class GenderPage extends StatefulWidget {
  final String languageCode;
  final String selectedState;
  final String firstName;
  final String address;

  final String? initialGender;
  final String? initialDatingPreference;
  final int? initialAge;
  final int? initialMinAge;
  final int? initialMaxAge;
  final bool isEditingFromHome;

  const GenderPage({
    super.key,
    required this.languageCode,
    required this.selectedState,
    required this.firstName,
    required this.address,
    this.initialGender,
    this.initialDatingPreference,
    this.initialAge,
    this.initialMinAge,
    this.initialMaxAge,
    this.isEditingFromHome = false,
  });

  @override
  State<GenderPage> createState() => _GenderPageState();
}

class _GenderPageState extends State<GenderPage> {
  String? selectedGender;

  @override
  void initState() {
    super.initState();
    selectedGender = widget.initialGender;
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
                ? Color.fromARGB(255, 0, 0, 0)
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
        title: Text(isVi ? 'Giới tính' : 'Gender'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

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
                          ? 'Giới tính của bạn là gì?'
                          : 'What is your gender?',
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
                          ? 'Hãy chọn 1 đáp án phù hợp nhất'
                          : 'Choose the option that fits you best',
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
                selectedValue: selectedGender,
                onTap: () {
                  setState(() {
                    selectedGender = 'female';
                  });
                },
              ),

              const SizedBox(height: 16),

              _buildOptionButton(
                label: isVi ? 'Nam' : 'Male',
                value: 'male',
                selectedValue: selectedGender,
                onTap: () {
                  setState(() {
                    selectedGender = 'male';
                  });
                },
              ),

              const SizedBox(height: 16),

              _buildOptionButton(
                label: isVi ? 'Khác' : 'Other',
                value: 'other',
                selectedValue: selectedGender,
                onTap: () {
                  setState(() {
                    selectedGender = 'other';
                  });
                },
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedGender == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          content: Text(
                            isVi
                                ? 'Vui lòng chọn giới tính'
                                : 'Please choose your gender',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DatingPreferencePage(
                          languageCode: widget.languageCode,
                          selectedState: widget.selectedState,
                          firstName: widget.firstName,
                          address: widget.address,
                          gender: selectedGender!,
                          initialDatingPreference:
                              widget.initialDatingPreference,
                          initialAge: widget.initialAge,
                          initialMinAge: widget.initialMinAge,
                          initialMaxAge: widget.initialMaxAge,
                          isEditingFromHome: widget.isEditingFromHome,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
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
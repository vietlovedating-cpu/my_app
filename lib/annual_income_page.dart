import 'package:flutter/material.dart';
import 'height_page.dart';

class AnnualIncomePage extends StatefulWidget {
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

  const AnnualIncomePage({
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
  });

  @override
  State<AnnualIncomePage> createState() => _AnnualIncomePageState();
}

class _AnnualIncomePageState extends State<AnnualIncomePage> {
  String? selectedIncome; // ✅ lưu KEY

  // ✅ DATA LOCAL (KHÔNG dùng app_data.dart)
  static const List<Map<String, String>> incomes = [
    {'key': 'under_40k', 'en': 'Below 40,000 AUD', 'vi': 'Dưới 40,000 AUD'},
    {'key': '40_59k', 'en': '40,000 - 59,999 AUD', 'vi': '40,000 - 59,999 AUD'},
    {'key': '60_79k', 'en': '60,000 - 79,999 AUD', 'vi': '60,000 - 79,999 AUD'},
    {'key': '80_99k', 'en': '80,000 - 99,999 AUD', 'vi': '80,000 - 99,999 AUD'},
    {'key': '100_119k', 'en': '100,000 - 119,999 AUD', 'vi': '100,000 - 119,999 AUD'},
    {'key': '120_149k', 'en': '120,000 - 149,999 AUD', 'vi': '120,000 - 149,999 AUD'},
    {'key': '150_plus', 'en': '150,000+ AUD', 'vi': '150,000+ AUD'},
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
        title: Text(isVi ? 'Thu nhập hằng năm' : 'Annual Income'),
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
                    ? 'Thu nhập hằng năm của bạn là bao nhiêu?'
                    : 'What is your annual income?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 28),

              DropdownButtonFormField<String>(
                value: selectedIncome,
                isExpanded: true,

                hint: Text(
                  isVi ? 'Chọn thu nhập' : 'Select income',
                ),

                items: incomes.map((item) {
                  return DropdownMenuItem<String>(
                    value: item['key'], // ✅ KEY
                    child: Text(
                      isVi ? item['vi']! : item['en']!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),

                onChanged: (value) {
                  setState(() {
                    selectedIncome = value;
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
                  onPressed: () {
                    if (selectedIncome == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isVi
                                ? 'Vui lòng chọn thu nhập'
                                : 'Please select your income',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HeightPage(
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
                          annualIncome: selectedIncome!, // ✅ KEY
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
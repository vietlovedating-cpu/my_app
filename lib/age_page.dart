import 'package:flutter/material.dart';
import 'age_range_page.dart';

class AgePage extends StatefulWidget {
  final String languageCode;
  final String selectedState;
  final String firstName;
  final String address;
  final String gender;
  final String datingPreference;

  final int? initialAge;
  final int? initialMinAge;
  final int? initialMaxAge;

  final String? initialMaritalStatus;
  final List<String> relationshipGoals;
  final List<String> initialPhotoUrls;
  final bool isEditingFromHome;

  const AgePage({
    super.key,
    required this.languageCode,
    required this.selectedState,
    required this.firstName,
    required this.address,
    required this.gender,
    required this.datingPreference,
    this.initialAge,
    this.initialMinAge,
    this.initialMaxAge,
    this.initialMaritalStatus,
    this.relationshipGoals = const [],
    this.initialPhotoUrls = const [],
    this.isEditingFromHome = false,
  });

  @override
  State<AgePage> createState() => _AgePageState();
}

class _AgePageState extends State<AgePage> {
  double selectedAge = 25.0;

  @override
  void initState() {
    super.initState();
    selectedAge = (widget.initialAge ?? 25).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.languageCode == 'vi';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      appBar: AppBar(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        title: Text(isVi ? 'Tuổi của bạn' : 'Your Age'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                isVi ? 'Bạn bao nhiêu tuổi?' : 'How old are you?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${selectedAge.round()}',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.pink,
                    inactiveTrackColor: Colors.pink.shade100,
                    thumbColor: Colors.pink,
                    overlayColor: Colors.pink.withOpacity(0.2),
                    trackHeight: 5.0,
                  ),
                  child: Slider(
                    value: selectedAge,
                    min: 18,
                    max: 80,
                    divisions: 62,
                    label: selectedAge.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        selectedAge = value;
                      });
                    },
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AgeRangePage(
                          languageCode: widget.languageCode,
                          selectedState: widget.selectedState,
                          firstName: widget.firstName,
                          address: widget.address,
                          gender: widget.gender,
                          datingPreference: widget.datingPreference,
                          age: selectedAge.round(),
                          initialMinAge: widget.initialMinAge,
                          initialMaxAge: widget.initialMaxAge,
                          initialMaritalStatus: widget.initialMaritalStatus,
                          relationshipGoals: widget.relationshipGoals,
                          initialPhotoUrls: widget.initialPhotoUrls,
                          isEditingFromHome: widget.isEditingFromHome,
                        ),
                      ),
                    );
                  },
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
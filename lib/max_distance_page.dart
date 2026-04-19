import 'package:flutter/material.dart';
import 'smoking_page.dart';

class MaxDistancePage extends StatefulWidget {
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
  final String occupation;
  final String annualIncome;
  final int heightCm;
  final String countryOfBirth;
  final String vietnamBirthProvince;
  final String religion;
  final String residentStatus;

  const MaxDistancePage({
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
    required this.occupation,
    required this.annualIncome,
    required this.heightCm,
    required this.countryOfBirth,
    required this.vietnamBirthProvince,
    required this.religion,
    required this.residentStatus,
  });

  @override
  State<MaxDistancePage> createState() => _MaxDistancePageState();
}

class _MaxDistancePageState extends State<MaxDistancePage> {
  double distanceKm = 30;

  void _goNext() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmokingPage(
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
          occupation: widget.occupation,
          annualIncome: widget.annualIncome,
          heightCm: widget.heightCm,
          countryOfBirth: widget.countryOfBirth,
          vietnamBirthProvince: widget.vietnamBirthProvince,
          religion: widget.religion,
          residentStatus: widget.residentStatus,
          maxDistanceKm: distanceKm.round(),
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
        title: Text(isVi ? 'Khoảng cách' : 'Distance'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVi
                    ? 'Khoảng cách tối đa bạn muốn tìm là bao nhiêu?'
                    : 'What is the maximum distance you want to match within?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isVi
                    ? 'Chọn khoảng cách phù hợp để tìm người gần bạn.'
                    : 'Choose the distance that works best for your matches.',
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFD6E7),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Colors.pink,
                      size: 50,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${distanceKm.round()} km',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.pink,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 11,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 20,
                        ),
                        activeTrackColor: Colors.pink,
                        inactiveTrackColor: const Color(0xFFFFD6E7),
                        thumbColor: Colors.pink,
                        overlayColor: Colors.pinkAccent.withOpacity(0.18),
                      ),
                      child: Slider(
                        min: 1,
                        max: 200,
                        divisions: 199,
                        value: distanceKm,
                        label: '${distanceKm.round()} km',
                        onChanged: (value) {
                          setState(() {
                            distanceKm = value;
                          });
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          '1 km',
                          style: TextStyle(color: Colors.black54),
                        ),
                        Text(
                          '200 km',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

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
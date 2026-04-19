import 'package:flutter/material.dart';
import 'religion_page.dart';

class VietnamBirthProvincePage extends StatefulWidget {
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

  const VietnamBirthProvincePage({
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
  });

  @override
  State<VietnamBirthProvincePage> createState() =>
      _VietnamBirthProvincePageState();
}

class _VietnamBirthProvincePageState extends State<VietnamBirthProvincePage> {
  String? selectedProvince;

  static const List<String> vietnamProvinces = [
    'An Giang',
    'Ba Ria - Vung Tau',
    'Bac Giang',
    'Bac Kan',
    'Bac Lieu',
    'Bac Ninh',
    'Ben Tre',
    'Binh Dinh',
    'Binh Duong',
    'Binh Phuoc',
    'Binh Thuan',
    'Ca Mau',
    'Can Tho',
    'Cao Bang',
    'Da Nang',
    'Dak Lak',
    'Dak Nong',
    'Dien Bien',
    'Dong Nai',
    'Dong Thap',
    'Gia Lai',
    'Ha Giang',
    'Ha Nam',
    'Ha Noi',
    'Ha Tinh',
    'Hai Duong',
    'Hai Phong',
    'Hau Giang',
    'Ho Chi Minh City',
    'Hoa Binh',
    'Hung Yen',
    'Khanh Hoa',
    'Kien Giang',
    'Kon Tum',
    'Lai Chau',
    'Lam Dong',
    'Lang Son',
    'Lao Cai',
    'Long An',
    'Nam Dinh',
    'Nghe An',
    'Ninh Binh',
    'Ninh Thuan',
    'Phu Tho',
    'Phu Yen',
    'Quang Binh',
    'Quang Nam',
    'Quang Ngai',
    'Quang Ninh',
    'Quang Tri',
    'Soc Trang',
    'Son La',
    'Tay Ninh',
    'Thai Binh',
    'Thai Nguyen',
    'Thanh Hoa',
    'Thua Thien Hue',
    'Tien Giang',
    'Tra Vinh',
    'Tuyen Quang',
    'Vinh Long',
    'Vinh Phuc',
    'Yen Bai',
  ];

  void _goNext() {
    final isVi = widget.languageCode == 'vi';

    if (selectedProvince == null || selectedProvince!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Vui lòng chọn tỉnh/thành phố'
                : 'Please select a province/city',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReligionPage(
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
          vietnamBirthProvince: selectedProvince!,
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
        elevation: 0,
        title: Text(
          isVi ? 'Nơi sinh tại Việt Nam' : 'Birth Province in Vietnam',
        ),
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
                    ? 'Bạn sinh ra ở tỉnh/thành nào của Việt Nam?'
                    : 'Which province/city in Vietnam were you born in?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 30),
              DropdownButtonFormField<String>(
                value: selectedProvince,
                isExpanded: true,
                hint: Text(
                  isVi ? 'Chọn tỉnh/thành' : 'Select province/city',
                ),
                items: vietnamProvinces.map((province) {
                  return DropdownMenuItem<String>(
                    value: province,
                    child: Text(
                      province,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedProvince = value;
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
                height: 52,
                child: ElevatedButton(
                  onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
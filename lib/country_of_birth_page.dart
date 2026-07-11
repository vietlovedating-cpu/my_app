import 'package:flutter/material.dart';
import 'religion_page.dart';
import 'vietnam_birth_province_page.dart';

class CountryOfBirthPage extends StatefulWidget {
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
  final String annualIncome;
  final int heightCm;

  const CountryOfBirthPage({
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
    required this.annualIncome,
    required this.heightCm,
  });

  @override
  State<CountryOfBirthPage> createState() => _CountryOfBirthPageState();
}

class _CountryOfBirthPageState extends State<CountryOfBirthPage> {
  String? selectedCountry;

  static const List<String> countries = [
    'Afghanistan',
    'Albania',
    'Algeria',
    'Andorra',
    'Angola',
    'Argentina',
    'Armenia',
    'Australia',
    'Austria',
    'Azerbaijan',
    'Bahrain',
    'Bangladesh',
    'Belarus',
    'Belgium',
    'Belize',
    'Benin',
    'Bhutan',
    'Bolivia',
    'Bosnia and Herzegovina',
    'Botswana',
    'Brazil',
    'Brunei',
    'Bulgaria',
    'Burkina Faso',
    'Burundi',
    'Cambodia',
    'Cameroon',
    'Canada',
    'Chad',
    'Chile',
    'China',
    'Colombia',
    'Congo',
    'Costa Rica',
    'Croatia',
    'Cuba',
    'Cyprus',
    'Czech Republic',
    'Denmark',
    'Dominican Republic',
    'Ecuador',
    'Egypt',
    'El Salvador',
    'Estonia',
    'Ethiopia',
    'Fiji',
    'Finland',
    'France',
    'Georgia',
    'Germany',
    'Ghana',
    'Greece',
    'Guatemala',
    'Haiti',
    'Honduras',
    'Hong Kong',
    'Hungary',
    'Iceland',
    'India',
    'Indonesia',
    'Iran',
    'Iraq',
    'Ireland',
    'Israel',
    'Italy',
    'Jamaica',
    'Japan',
    'Jordan',
    'Kazakhstan',
    'Kenya',
    'Kuwait',
    'Kyrgyzstan',
    'Laos',
    'Latvia',
    'Lebanon',
    'Libya',
    'Lithuania',
    'Luxembourg',
    'Macau',
    'Madagascar',
    'Malaysia',
    'Maldives',
    'Mali',
    'Malta',
    'Mexico',
    'Moldova',
    'Mongolia',
    'Morocco',
    'Myanmar',
    'Nepal',
    'Netherlands',
    'New Zealand',
    'Nigeria',
    'North Korea',
    'Norway',
    'Oman',
    'Pakistan',
    'Panama',
    'Paraguay',
    'Peru',
    'Philippines',
    'Poland',
    'Portugal',
    'Qatar',
    'Romania',
    'Russia',
    'Saudi Arabia',
    'Serbia',
    'Singapore',
    'Slovakia',
    'Slovenia',
    'Somalia',
    'South Africa',
    'South Korea',
    'Spain',
    'Sri Lanka',
    'Sudan',
    'Sweden',
    'Switzerland',
    'Syria',
    'Taiwan',
    'Tajikistan',
    'Tanzania',
    'Thailand',
    'Tunisia',
    'Turkey',
    'Turkmenistan',
    'Uganda',
    'Ukraine',
    'United Arab Emirates',
    'United Kingdom',
    'United States',
    'Uruguay',
    'Uzbekistan',
    'Venezuela',
    'Vietnam',
    'Yemen',
    'Zambia',
    'Zimbabwe',
    'Other',
  ];

  void _goNext() {
    final isVi = widget.languageCode == 'vi';

    if (selectedCountry == null || selectedCountry!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Vui lòng chọn quốc gia' : 'Please select a country',
          ),
        ),
      );
      return;
    }

    final normalizedCountry = selectedCountry!.trim().toLowerCase();
    final isVietnam = normalizedCountry == 'vietnam';

    if (isVietnam) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VietnamBirthProvincePage(
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
            annualIncome: widget.annualIncome,
            heightCm: widget.heightCm,
            countryOfBirth: selectedCountry!,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReligionPage(
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
            annualIncome: widget.annualIncome,
            heightCm: widget.heightCm,
            countryOfBirth: selectedCountry!,
            vietnamBirthProvince: '',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.languageCode == 'vi';

    return Scaffold(
      backgroundColor: const Color(0xFFFDF5F8),
      appBar: AppBar(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(isVi ? 'Quốc gia sinh ra' : 'Country of Birth'),
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
                    ? 'Bạn sinh ra ở quốc gia nào?'
                    : 'Which country were you born in?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 28),
              DropdownButtonFormField<String>(
                value: selectedCountry,
                isExpanded: true,
                hint: Text(isVi ? 'Chọn quốc gia' : 'Select country'),
                items: countries.map((country) {
                  return DropdownMenuItem<String>(
                    value: country,
                    child: Text(
                      country,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCountry = value;
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
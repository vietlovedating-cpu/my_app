import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';

import 'state_question_page.dart';
import 'current_location_page.dart';

class PlaceYouCallHomePage extends StatefulWidget {
  final String languageCode;
  final String firstName;

  const PlaceYouCallHomePage({
    super.key,
    required this.languageCode,
    required this.firstName,
  });

  @override
  State<PlaceYouCallHomePage> createState() =>
      _PlaceYouCallHomePageState();
}

class _PlaceYouCallHomePageState extends State<PlaceYouCallHomePage> {
  Country? selectedCountry;
  bool isSaving = false;

  bool get isVi => widget.languageCode == 'vi';

  @override
  void initState() {
    super.initState();

    // Mặc định là Australia.
    selectedCountry = Country(
      phoneCode: '61',
      countryCode: 'AU',
      e164Sc: 0,
      geographic: true,
      level: 1,
      name: 'Australia',
      example: '412345678',
      displayName: 'Australia (AU) [+61]',
      displayNameNoCountryCode: 'Australia (AU)',
      e164Key: '61-AU-0',
    );
  }

  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      useSafeArea: true,
      countryListTheme: CountryListThemeData(
        backgroundColor: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        inputDecoration: InputDecoration(
          labelText: isVi ? 'Tìm quốc gia' : 'Search country',
          hintText: isVi
              ? 'Nhập tên quốc gia'
              : 'Enter country name',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          selectedCountry = country;
        });
      },
    );
  }

  Future<void> _continue() async {
    final country = selectedCountry;
    final user = FirebaseAuth.instance.currentUser;

    if (country == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Vui lòng chọn quốc gia'
                : 'Please select your country',
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

    setState(() {
      isSaving = true;
    });

    try {
      final bool isAustralia = country.countryCode == 'AU';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
  'selectedCountry': country.name,
  'countryCode': country.countryCode,
        'onboardingStep':
            isAustralia ? 'state_question' : 'current_location',
        'countryUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      if (isAustralia) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StateQuestionPage(
              languageCode: widget.languageCode,
              firstName: widget.firstName,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CurrentLocationPage(
  languageCode: widget.languageCode,
  selectedState: '',
  selectedCountry: country.name,
  firstName: widget.firstName,
),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Không thể lưu quốc gia. Vui lòng thử lại.'
                : 'Unable to save country. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final country = selectedCountry;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F4F6),
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          isVi ? 'Nơi bạn gọi là nhà' : 'A place you call home',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.public_rounded,
                size: 64,
                color: Colors.pink,
              ),
              const SizedBox(height: 24),
              Text(
                isVi
                    ? 'Bạn đang sống ở quốc gia nào?'
                    : 'Which country do you live in?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2A27),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isVi
                    ? 'Chọn nơi bạn hiện đang sinh sống để chúng tôi giúp bạn tìm những người phù hợp gần mình.'
                    : 'Choose where you currently live so we can help you discover suitable people nearby.',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                isVi ? 'Quốc gia' : 'Country',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _openCountryPicker,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 17,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD8C3B5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        country?.flagEmoji ?? '🌏',
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          country?.name ??
                              (isVi
                                  ? 'Chọn quốc gia'
                                  : 'Select country'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
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
                          isVi ? 'Tiếp theo' : 'Continue',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
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
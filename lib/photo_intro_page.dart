import 'package:flutter/material.dart';
import 'upload_photos_page.dart';

class PhotoIntroPage extends StatelessWidget {
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
  final List<String> relationshipGoals;
  final List<String> initialPhotoUrls;
  final bool isEditingFromHome;

  const PhotoIntroPage({
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
    required this.relationshipGoals,
    this.initialPhotoUrls = const [],
    this.isEditingFromHome = false,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = languageCode == 'vi';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      appBar: AppBar(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        title: Text(isVi ? 'Thêm ảnh của bạn' : 'Add Your Photos'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE4EF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.pink,
                  size: 54,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                isVi ? 'Tuyệt quá!' : 'Great!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isVi
                    ? 'Bạn chỉ còn một vài bước nữa thôi.\nHãy thêm khoảng 5 tấm ảnh đẹp để mọi người hiểu bạn hơn.'
                    : 'You are almost done.\nAdd around 5 nice photos so people can get to know you better.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isVi
                    ? 'Ảnh đầu tiên sẽ là ảnh đại diện chính của bạn.'
                    : 'Your first photo will be your main profile photo.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
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
                        builder: (_) => UploadPhotosPage(
                          languageCode: languageCode,
                          selectedCountry: selectedCountry,
                          selectedState: selectedState,
                          firstName: firstName,
                          address: address,
                          gender: gender,
                          datingPreference: datingPreference,
                          age: age,
                          minAgePreference: minAgePreference,
                          maxAgePreference: maxAgePreference,
                          maritalStatus: maritalStatus,
                          haveChildren: haveChildren,
                          relationshipGoals: relationshipGoals,
                          initialPhotoUrls: initialPhotoUrls,
                          isEditingFromHome: isEditingFromHome,
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
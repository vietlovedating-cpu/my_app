import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_overflow_wrapper.dart';
import 'highest_education_page.dart';

class UploadPhotosPage extends StatefulWidget {
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
  final List<String> initialPhotoUrls;
  final bool isEditingFromHome;

  const UploadPhotosPage({
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
    this.initialPhotoUrls = const [],
    this.isEditingFromHome = false,
  });

  @override
  State<UploadPhotosPage> createState() => _UploadPhotosPageState();
}

class _UploadPhotosPageState extends State<UploadPhotosPage> {
  final ImagePicker _picker = ImagePicker();

  /// 5 slot cố định
  final List<String?> existingPhotoUrls = List<String?>.filled(5, null);
  final List<XFile?> newPhotos = List<XFile?>.filled(5, null);
  final List<Uint8List?> newPhotoBytes = List<Uint8List?>.filled(5, null);

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < widget.initialPhotoUrls.length && i < 5; i++) {
      existingPhotoUrls[i] = widget.initialPhotoUrls[i];
    }
  }

  int get totalPhotos {
    int count = 0;
    for (int i = 0; i < 5; i++) {
      if ((existingPhotoUrls[i] != null && existingPhotoUrls[i]!.isNotEmpty) ||
          newPhotos[i] != null) {
        count++;
      }
    }
    return count;
  }

  Future<void> _pickPhotoForSlot(int index) async {
    final isVi = widget.languageCode == 'vi';

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      setState(() {
        newPhotos[index] = image;
        newPhotoBytes[index] = bytes;

        /// thay ảnh cũ đúng slot
        existingPhotoUrls[index] = null;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(
            isVi ? 'Đã cập nhật ảnh thành công' : 'Photo updated successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Không thể chọn ảnh: $e' : 'Could not pick image: $e',
          ),
        ),
      );
    }
  }

  void _removeExistingPhoto(int index) {
    setState(() {
      existingPhotoUrls[index] = null;
    });
  }

  void _removeNewPhoto(int index) {
    setState(() {
      newPhotos[index] = null;
      newPhotoBytes[index] = null;
    });
  }

  Future<List<String?>> _uploadNewPhotos(String uid) async {
    final List<String?> uploadedUrls = List<String?>.filled(5, null);

    for (int i = 0; i < 5; i++) {
      if (newPhotos[i] == null) continue;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${i + 1}.jpg';

      final ref = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child(uid)
          .child(fileName);

      debugPrint('UPLOAD PATH: user_photos/$uid/$fileName');

      UploadTask uploadTask;

      if (kIsWeb) {
        uploadTask = ref.putData(
          newPhotoBytes[i]!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        final file = File(newPhotos[i]!.path);
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 40),
        onTimeout: () {
          throw TimeoutException('Upload ảnh bị quá thời gian');
        },
      );

      final downloadUrl = await snapshot.ref.getDownloadURL().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Lấy link ảnh bị quá thời gian');
        },
      );

      debugPrint('UPLOAD OK URL: $downloadUrl');
      uploadedUrls[i] = downloadUrl;
    }

    return uploadedUrls;
  }

  Future<void> _savePhotoUrlsToFirestore({
    required String uid,
    required List<String> allPhotoUrls,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
  'photoUrls': allPhotoUrls,
  'photos': allPhotoUrls,
  'mainPhotoUrl': allPhotoUrls.isNotEmpty ? allPhotoUrls.first : '',
  'onboardingStep': 'highest_education',
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
  }

  Future<void> _saveProfileWhenEditingFromHome() async {
    final isVi = widget.languageCode == 'vi';
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isVi ? 'Không tìm thấy người dùng' : 'User not found'),
        ),
      );
      return;
    }

    debugPrint('CURRENT UID: ${user.uid}');
    debugPrint('CURRENT EMAIL: ${user.email}');

    if (totalPhotos < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Vui lòng chọn ít nhất 3 ảnh'
                : 'Please select at least 3 photos',
          ),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final uploadedUrls = await _uploadNewPhotos(user.uid);

      final List<String> allPhotoUrls = [];
      for (int i = 0; i < 5; i++) {
        final url = uploadedUrls[i] ?? existingPhotoUrls[i];
        if (url != null && url.isNotEmpty) {
          allPhotoUrls.add(url);
        }
      }

      await _savePhotoUrlsToFirestore(
        uid: user.uid,
        allPhotoUrls: allPhotoUrls,
      );

      if (!mounted) return;
      Navigator.pop(context, allPhotoUrls);
    } catch (e) {
      debugPrint('SAVE PHOTO ERROR: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Lỗi khi lưu ảnh: $e' : 'Error saving photos: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _goToNextStep() async {
    final isVi = widget.languageCode == 'vi';
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isVi ? 'Không tìm thấy người dùng' : 'User not found'),
        ),
      );
      return;
    }

    debugPrint('CURRENT UID: ${user.uid}');
    debugPrint('CURRENT EMAIL: ${user.email}');

    if (totalPhotos < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Vui lòng chọn ít nhất 3 ảnh'
                : 'Please select at least 3 photos',
          ),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final uploadedUrls = await _uploadNewPhotos(user.uid);

      final List<String> allPhotoUrls = [];
      for (int i = 0; i < 5; i++) {
        final url = uploadedUrls[i] ?? existingPhotoUrls[i];
        if (url != null && url.isNotEmpty) {
          allPhotoUrls.add(url);
        }
      }

      await _savePhotoUrlsToFirestore(
        uid: user.uid,
        allPhotoUrls: allPhotoUrls,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HighestEducationPage(
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
            photoUrls: allPhotoUrls,
          ),
        ),
      );
    } catch (e) {
      debugPrint('UPLOAD NEXT ERROR: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Lỗi khi tải ảnh: $e' : 'Error uploading photos: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Widget _buildPhotoImage({
    required int index,
    required bool isCircle,
  }) {
    final existingUrl = existingPhotoUrls[index];
    final newPhoto = newPhotos[index];
    final newBytes = newPhotoBytes[index];

    if (newPhoto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(isCircle ? 999 : 16),
        child: Stack(
          children: [
            Positioned.fill(
              child: InkWell(
                onTap: () => _pickPhotoForSlot(index),
                child: kIsWeb
                    ? Image.memory(
                        newBytes!,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(newPhoto.path),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => _removeNewPhoto(index),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(5),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (existingUrl != null && existingUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(isCircle ? 999 : 16),
        child: Stack(
          children: [
            Positioned.fill(
              child: InkWell(
                onTap: () => _pickPhotoForSlot(index),
                child: Image.network(
                  existingUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('IMAGE LOAD ERROR slot $index: $error');
                    debugPrint('BAD URL: $existingUrl');
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                        size: 28,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => _removeExistingPhoto(index),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(5),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _pickPhotoForSlot(index),
      borderRadius: BorderRadius.circular(isCircle ? 999 : 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFD6E7),
            width: 1.3,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.add_a_photo_outlined,
            color: Colors.pink,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSlot({
    required int index,
    required bool isCircle,
    required double size,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: _buildPhotoImage(
        index: index,
        isCircle: isCircle,
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
        title: Text(isVi ? 'Tải ảnh lên' : 'Upload Photos'),
      ),
      body: AppOverflowWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 330),
                child: Column(
                  children: [
                    Text(
                      isVi ? 'Thêm ảnh của bạn' : 'Add your photos',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isVi
                          ? 'Vui lòng thêm ít nhất 3 ảnh, tối đa 5 ảnh'
                          : 'Please add at least 3 photos, up to 5 photos',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isVi
                          ? 'Đã chọn $totalPhotos/5 ảnh'
                          : 'Selected $totalPhotos/5 photos',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.pink,
                      ),
                    ),
                    if (isSaving) ...[
                      const SizedBox(height: 8),
                      Text(
                        isVi ? 'Đang tải ảnh lên...' : 'Uploading photos...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),

                    LayoutBuilder(
  builder: (context, constraints) {
    final double spacing = 10;
    final double size = 150;

    return Column(
      children: [
        Center(
          child: _buildPhotoSlot(
            index: 0,
            isCircle: true,
            size: size,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPhotoSlot(
              index: 1,
              isCircle: false,
              size: size,
            ),
            const SizedBox(width: 10),
            _buildPhotoSlot(
              index: 2,
              isCircle: false,
              size: size,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPhotoSlot(
              index: 3,
              isCircle: false,
              size: size,
            ),
            const SizedBox(width: 10),
            _buildPhotoSlot(
              index: 4,
              isCircle: false,
              size: size,
            ),
          ],
        ),
      ],
    );
  },
),

                    const SizedBox(height: 16),
                    Text(
                      isVi
                          ? 'Ảnh đầu tiên sẽ là ảnh đại diện chính.'
                          : 'Your first photo will be your main profile photo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: 200,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (widget.isEditingFromHome) {
                                  await _saveProfileWhenEditingFromHome();
                                } else {
                                  await _goToNextStep();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.isEditingFromHome
                                    ? (isVi ? 'Lưu thay đổi' : 'Save Changes')
                                    : (isVi ? 'Tiếp theo' : 'Next'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
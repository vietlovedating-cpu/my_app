import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoVerificationPage extends StatefulWidget {
  final String languageCode;

  const PhotoVerificationPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<PhotoVerificationPage> createState() => _PhotoVerificationPageState();
}

class _PhotoVerificationPageState extends State<PhotoVerificationPage> {
  final ImagePicker _picker = ImagePicker();

  File? _selfieFile;
  bool _isUploading = false;

  bool get isVi => widget.languageCode == 'vi';

  String get _title => isVi ? 'Xác minh ảnh' : 'Verify Photo';

  Future<void> _takeSelfie() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 45,
      maxWidth: 900,
      maxHeight: 900,
      preferredCameraDevice: CameraDevice.front,
    );

    if (image == null) return;

    setState(() {
      _selfieFile = File(image.path);
    });
  }

  Future<void> _submitVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    final file = _selfieFile;

    if (user == null || file == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final uid = user.uid;
      final path =
          'photo_verifications/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = FirebaseStorage.instance.ref().child(path);

      await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await ref.getDownloadURL();
      final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .get();

final userData = userDoc.data() ?? {};

final email = (user.email ?? userData['email'] ?? '').toString();
final firstName = (userData['firstName'] ?? '').toString();
final mainPhotoUrl = (userData['mainPhotoUrl'] ?? '').toString();

      final verificationData = {
  'uid': uid,
  'email': email,
  'firstName': firstName,
  'mainPhotoUrl': mainPhotoUrl,
  'photoVerified': false,
  'photoVerificationStatus': 'pending',
  'photoVerificationImageUrl': downloadUrl,
  'photoVerificationStoragePath': path,
  'photoVerificationSubmittedAt': FieldValue.serverTimestamp(),
};

await FirebaseFirestore.instance.collection('users').doc(uid).set(
  verificationData,
  SetOptions(merge: true),
);

await FirebaseFirestore.instance
    .collection('photo_verification_requests')
    .doc(uid)
    .set(
      verificationData,
      SetOptions(merge: true),
    );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Đã gửi ảnh xác minh. VietLove sẽ xem xét sớm.'
                : 'Your verification photo has been submitted for review.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Có lỗi xảy ra: $e' : 'Something went wrong: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pink = const Color(0xFFE91E63);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFFF7FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: pink,
                    size: 54,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isVi ? 'Xác minh ảnh của bạn' : 'Verify your photo',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
  isVi
      ? 'Chụp một ảnh selfie rõ mặt bằng camera. Ảnh này chỉ được sử dụng để VietLove xem xét và xác minh hồ sơ của bạn. Ảnh xác minh sẽ không hiển thị công khai và người dùng khác sẽ không thể xem ảnh này.'
      : 'Take a clear selfie using your camera. This photo is only used by VietLove to review and verify your profile. Your verification photo will not be displayed publicly and cannot be viewed by other users.',
  textAlign: TextAlign.center,
  style: const TextStyle(
    fontSize: 15,
    height: 1.45,
    color: Color(0x99000000),
  ),
),
                  const SizedBox(height: 22),

                  if (_selfieFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.file(
                        _selfieFile!,
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 260,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEF6),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFFFC4DC),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: pink,
                            size: 46,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isVi ? 'Chưa có ảnh selfie' : 'No selfie yet',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _takeSelfie,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(
                        isVi ? 'Chụp selfie' : 'Take Selfie',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: pink,
                        side: BorderSide(color: pink),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (_selfieFile == null || _isUploading)
                          ? null
                          : _submitVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pink,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isVi ? 'Gửi xác minh' : 'Submit Verification',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
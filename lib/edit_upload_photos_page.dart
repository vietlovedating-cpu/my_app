import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditUploadPhotosPage extends StatefulWidget {
  final String languageCode;

  const EditUploadPhotosPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditUploadPhotosPage> createState() => _EditUploadPhotosPageState();
}

class _EditUploadPhotosPageState extends State<EditUploadPhotosPage> {
  final ImagePicker _picker = ImagePicker();

  final List<String?> existingPhotoUrls = List<String?>.filled(5, null);
  final List<XFile?> newPhotos = List<XFile?>.filled(5, null);
  final List<Uint8List?> newPhotoBytes = List<Uint8List?>.filled(5, null);

  bool isSaving = false;
  bool isLoading = true;

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  @override
  void initState() {
    super.initState();
    _loadExistingPhotos();
  }

  Future<void> _loadExistingPhotos() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};
      final rawPhotos = data['photoUrls'] ?? data['photos'];

      final List<String> urls = [];
      if (rawPhotos is List) {
        for (final item in rawPhotos) {
          final value = item?.toString().trim() ?? '';
          if (value.isNotEmpty) {
            urls.add(value);
          }
        }
      }

      for (int i = 0; i < urls.length && i < 5; i++) {
        existingPhotoUrls[i] = urls[i];
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  int get totalPhotos {
    int count = 0;
    for (int i = 0; i < 5; i++) {
      final hasExisting =
          existingPhotoUrls[i] != null && existingPhotoUrls[i]!.isNotEmpty;
      final hasNew = newPhotos[i] != null;
      if (hasExisting || hasNew) count++;
    }
    return count;
  }

  Future<void> _pickPhotoForSlot(int index) async {
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
        existingPhotoUrls[index] = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr('Đã cập nhật ảnh thành công', 'Photo updated successfully'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr('Không thể chọn ảnh: $e', 'Could not pick image: $e'),
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
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _savePhotos() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(_tr('Không tìm thấy người dùng', 'User not found')),
        ),
      );
      return;
    }

    if (totalPhotos < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Vui lòng chọn ít nhất 3 ảnh',
              'Please select at least 3 photos',
            ),
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
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr('Lỗi khi lưu ảnh: $e', 'Error saving photos: $e'),
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
        borderRadius: BorderRadius.circular(isCircle ? 999 : 18),
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
        borderRadius: BorderRadius.circular(isCircle ? 999 : 18),
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
      borderRadius: BorderRadius.circular(isCircle ? 999 : 18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFFD6E7),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.add_a_photo_outlined,
            color: Color(0xFFCC3D7A),
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSlot({
    required int index,
    required bool isCircle,
    required double width,
    required double height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: _buildPhotoImage(
        index: index,
        isCircle: isCircle,
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              children: [
                Text(
                  _tr('Chỉnh sửa ảnh của bạn', 'Edit your photos'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7A2E6E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tr(
                    'Vui lòng thêm ít nhất 3 ảnh, tối đa 5 ảnh',
                    'Please add at least 3 photos, up to 5 photos',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _tr('Đã chọn $totalPhotos/5 ảnh', 'Selected $totalPhotos/5 photos'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFCC3D7A),
                  ),
                ),
                if (isSaving) ...[
                  const SizedBox(height: 8),
                  Text(
                    _tr('Đang tải ảnh lên...', 'Uploading photos...'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // 1 ảnh tròn giữa
                Center(
                  child: _buildPhotoSlot(
                    index: 0,
                    isCircle: true,
                    width: 150,
                    height: 150,
                  ),
                ),
                const SizedBox(height: 14),

                // 2 ảnh hàng giữa
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPhotoSlot(
                      index: 1,
                      isCircle: false,
                      width: 150,
                      height: 150,
                    ),
                    const SizedBox(width: 10),
                    _buildPhotoSlot(
                      index: 2,
                      isCircle: false,
                      width: 150,
                      height: 150,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 2 ảnh hàng dưới
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPhotoSlot(
                      index: 3,
                      isCircle: false,
                      width: 150,
                      height: 150,
                    ),
                    const SizedBox(width: 10),
                    _buildPhotoSlot(
                      index: 4,
                      isCircle: false,
                      width: 150,
                      height: 150,
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Text(
                  _tr(
                    'Ảnh đầu tiên sẽ là ảnh đại diện chính.',
                    'Your first photo will be your main profile photo.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),

                SizedBox(
                  width: 220,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : _savePhotos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCC3D7A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                            _tr('Lưu thay đổi', 'Save Changes'),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF7A2E6E),
        centerTitle: true,
        title: Text(
          _tr('Sửa ảnh', 'Edit Photos'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A2E6E),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }
}
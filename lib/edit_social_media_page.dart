import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditSocialMediaPage extends StatefulWidget {
  final String languageCode;

  const EditSocialMediaPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditSocialMediaPage> createState() =>
      _EditSocialMediaPageState();
}

class _EditSocialMediaPageState extends State<EditSocialMediaPage> {
  final TextEditingController _facebookController =
      TextEditingController();

  final TextEditingController _instagramController =
      TextEditingController();

  final TextEditingController _tiktokController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _showSocialMedia = true;

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  @override
  void initState() {
    super.initState();
    _loadSocialMedia();
  }

  @override
  void dispose() {
    _facebookController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  Future<void> _loadSocialMedia() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data();

      if (!mounted) return;

      setState(() {
        _facebookController.text =
            (data?['facebookUrl'] ?? '').toString();

        _instagramController.text =
            (data?['instagramUrl'] ?? '').toString();

        _tiktokController.text =
            (data?['tiktokUrl'] ?? '').toString();

        _showSocialMedia =
            data?['showSocialMedia'] == null
                ? true
                : data?['showSocialMedia'] == true;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Không thể tải thông tin mạng xã hội',
              'Unable to load social media information',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _saveSocialMedia() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null || _isSaving) return;

  final facebook = _facebookController.text.trim();
  final instagram = _instagramController.text.trim();
  final tiktok = _tiktokController.text.trim();

  bool isValidLink(String value) {
    // Cho phép để trống
    if (value.isEmpty) return true;

    final uri = Uri.tryParse(value);

    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  // Chỉ kiểm tra những ô user có nhập
  if (!isValidLink(facebook) ||
      !isValidLink(instagram) ||
      !isValidLink(tiktok)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Link đã nhập phải bắt đầu bằng https://',
            'Entered links must begin with https://',
          ),
        ),
      ),
    );
    return;
  }

  setState(() {
    _isSaving = true;
  });

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'facebookUrl': facebook,
      'instagramUrl': instagram,
      'tiktokUrl': tiktok,
      'showSocialMedia': _showSocialMedia,
      'socialMediaUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Đã lưu mạng xã hội',
            'Social media saved',
          ),
        ),
      ),
    );

    Navigator.pop(context, true);
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Không thể lưu. Vui lòng thử lại.',
            'Unable to save. Please try again.',
          ),
        ),
      ),
    );
  }
}

  Widget _buildSocialField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: const Color(0xFFCC3D7A),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFFFD5E6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFFFD5E6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFCC3D7A),
            width: 1.5,
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
          _tr('Mạng xã hội', 'Social media'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A2E6E),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr(
                        'Thêm mạng xã hội của bạn',
                        'Add your social media',
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4A2C40),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tr(
                        'Các liên kết này sẽ được hiển thị ở cuối hồ sơ của bạn. Bạn có thể để trống những mục không muốn chia sẻ.',
                        'These links will appear at the bottom of your profile. You may leave any field blank.',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildSocialField(
                      controller: _facebookController,
                      label: 'Facebook',
                    hint: isVi
    ? 'Username hoặc link Facebook'
    : 'Username or Facebook link',
                      icon: Icons.facebook,
                    ),

                    const SizedBox(height: 16),

                    _buildSocialField(
                      controller: _instagramController,
                      label: 'Instagram',
                    hint: isVi
    ? 'Username hoặc link Instagram'
    : 'Username or Instagram link',
                      icon: Icons.camera_alt_outlined,
                    ),

                    const SizedBox(height: 16),

                    _buildSocialField(
                      controller: _tiktokController,
                      label: 'TikTok',
                    hint: isVi
    ? '@username hoặc link TikTok'
    : '@username or TikTok link',
                      icon: Icons.music_note_outlined,
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFD5E6),
                        ),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _showSocialMedia,
                        activeColor: const Color(0xFFCC3D7A),
                        title: Text(
                          _tr(
                            'Hiển thị trên hồ sơ',
                            'Show on my profile',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4A2C40),
                          ),
                        ),
                        subtitle: Text(
                          _tr(
                            'Người khác có thể bấm để xem mạng xã hội của bạn.',
                            'Other users can tap to view your social media.',
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _showSocialMedia = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            _isSaving ? null : _saveSocialMedia,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFCC3D7A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _tr('Lưu', 'Save'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
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
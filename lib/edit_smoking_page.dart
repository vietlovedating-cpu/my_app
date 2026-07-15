import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'utils/profile_health.dart';
class EditSmokingPage extends StatefulWidget {
  final String languageCode;

  const EditSmokingPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditSmokingPage> createState() => _EditSmokingPageState();
}

class _EditSmokingPageState extends State<EditSmokingPage> {
  String? _selectedSmoking;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get isVi => widget.languageCode == 'vi';
  String _tr(String vi, String en) => isVi ? vi : en;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};
      final value = (data['smoking'] ?? data['smoker'] ?? '').toString();

      if (value == 'yes' || value == 'no' || value == 'sometime') {
  _selectedSmoking = value;
}
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_selectedSmoking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr('Vui lòng chọn một đáp án', 'Please choose an option'),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userRef =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

// Lưu smoking
await userRef.set({
  'smoking': _selectedSmoking,
  'smoker': _selectedSmoking,
}, SetOptions(merge: true));

// Đọc lại hồ sơ mới nhất
final updatedDoc = await userRef.get();
final updatedData = updatedDoc.data() ?? <String, dynamic>{};

// Tính lại điểm hồ sơ
final healthResult = calculateProfileHealth(updatedData);

// Cập nhật điểm và trạng thái hồ sơ
await userRef.set({
  'profileScore': healthResult.score,
  'profileCompleted': healthResult.score >= 50,
}, SetOptions(merge: true));

if (!mounted) return;
Navigator.pop(context, _selectedSmoking);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(_tr('Lưu thất bại', 'Save failed')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildOptionCard({
    required String title,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFEEF5) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFCC3D7A)
                : const Color(0xFFFFD5E6),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFFCC3D7A),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4A2C40),
                ),
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: const Color(0xFFCC3D7A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        children: [
          _buildOptionCard(
            title: isVi ? 'Có' : 'Yes',
            isSelected: _selectedSmoking == 'yes',
            icon: Icons.smoking_rooms,
            onTap: () {
              setState(() {
                _selectedSmoking = 'yes';
              });
            },
          ),
          _buildOptionCard(
            title: isVi ? 'Không' : 'No',
            isSelected: _selectedSmoking == 'no',
            icon: Icons.smoke_free,
            onTap: () {
              setState(() {
                _selectedSmoking = 'no';
              });
            },
          ),
          _buildOptionCard(
  title: isVi ? 'Thỉnh thoảng' : 'Sometimes',
  isSelected: _selectedSmoking == 'sometime',
  icon: Icons.smoking_rooms_outlined,
  onTap: () {
    setState(() {
      _selectedSmoking = 'sometime';
    });
  },
),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC3D7A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
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
          _tr('Sửa hút thuốc', 'Edit smoking'),
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
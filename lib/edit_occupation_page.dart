import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditOccupationPage extends StatefulWidget {
  final String languageCode;

  const EditOccupationPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditOccupationPage> createState() => _EditOccupationPageState();
}

class _EditOccupationPageState extends State<EditOccupationPage> {
  String? _selectedKey;
  final TextEditingController _otherController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  bool get isVi => widget.languageCode == 'vi';
  String _tr(String vi, String en) => isVi ? vi : en;

  final List<Map<String, String>> _options = const [
    {'key': 'education', 'en': 'Education', 'vi': 'Giáo dục'},
    {'key': 'healthcare', 'en': 'Healthcare', 'vi': 'Y tế'},
    {'key': 'engineering', 'en': 'Engineering', 'vi': 'Kỹ sư'},
    {'key': 'it', 'en': 'IT', 'vi': 'Công nghệ thông tin'},
    {'key': 'business', 'en': 'Business', 'vi': 'Kinh doanh'},
    {'key': 'finance', 'en': 'Finance', 'vi': 'Tài chính'},
    {'key': 'marketing', 'en': 'Marketing', 'vi': 'Marketing'},
    {'key': 'law', 'en': 'Law', 'vi': 'Luật'},
    {'key': 'hospitality', 'en': 'Hospitality', 'vi': 'Nhà hàng - khách sạn'},
    {'key': 'construction', 'en': 'Construction', 'vi': 'Xây dựng'},
    {'key': 'trades', 'en': 'Trades', 'vi': 'Thợ nghề'},
    {'key': 'government', 'en': 'Government', 'vi': 'Chính phủ'},
    {'key': 'student', 'en': 'Student', 'vi': 'Sinh viên'},
    {'key': 'self_employed', 'en': 'Self-employed', 'vi': 'Tự kinh doanh'},
    {'key': 'unemployed', 'en': 'Unemployed', 'vi': 'Thất nghiệp'},
    {'key': 'other', 'en': 'Other', 'vi': 'Khác'},
  ];

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
      final occupation = (data['occupation'] ?? '').toString();
      final occupationOther = (data['occupationOther'] ?? '').toString();

      final exists = _options.any((e) => e['key'] == occupation);
      _selectedKey = exists ? occupation : null;
      _otherController.text = occupationOther;
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_selectedKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr('Vui lòng chọn công việc', 'Please choose your occupation'),
          ),
        ),
      );
      return;
    }

    final otherText = _otherController.text.trim();

    if (_selectedKey == 'other' && otherText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr('Vui lòng nhập công việc của bạn', 'Please enter your occupation'),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'occupation': _selectedKey,
        'occupationOther': _selectedKey == 'other' ? otherText : '',
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, _selectedKey);
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

  Widget _optionTile(Map<String, String> option) {
    final key = option['key']!;
    final selected = _selectedKey == key;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() {
          _selectedKey = key;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFEEF5) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFFCC3D7A)
                : const Color(0xFFFFD5E6),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isVi ? option['vi']! : option['en']!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4A2C40),
                ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
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
          Expanded(
            child: ListView(
              children: [
                ..._options.map(_optionTile),
                if (_selectedKey == 'other')
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFFD5E6)),
                    ),
                    child: TextField(
                      controller: _otherController,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: _tr(
                          'Nhập công việc của bạn',
                          'Enter your occupation',
                        ),
                        hintStyle: const TextStyle(color: Color(0xFFB58AA0)),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A2C40),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
  void dispose() {
    _otherController.dispose();
    super.dispose();
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
          _tr('Sửa công việc', 'Edit occupation'),
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
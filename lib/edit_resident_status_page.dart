import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'utils/profile_health.dart';

class EditResidentStatusPage extends StatefulWidget {
  final String languageCode;

  const EditResidentStatusPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditResidentStatusPage> createState() => _EditResidentStatusPageState();
}

class _EditResidentStatusPageState extends State<EditResidentStatusPage> {
  String? _selectedValue;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get isVi => widget.languageCode == 'vi';
  String _tr(String vi, String en) => isVi ? vi : en;

  final List<Map<String, String>> _options = const [
    {
      'value': 'australian_citizen',
      'vi': 'Công dân Úc',
      'en': 'Australian Citizen',
    },
    {
      'value': 'permanent_resident',
      'vi': 'Thường trú nhân',
      'en': 'Permanent Resident',
    },
    {
      'value': 'temporary_visa',
      'vi': 'Visa tạm trú',
      'en': 'Temporary Visa',
    },
    {
      'value': 'student_visa',
      'vi': 'Visa du học',
      'en': 'Student Visa',
    },
    {
      'value': 'working_holiday',
      'vi': 'Visa Working Holiday',
      'en': 'Working Holiday Visa',
    },
    {
      'value': 'other',
      'vi': 'Khác',
      'en': 'Other',
    },
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
      final value = (data['residentStatus'] ?? data['residencyStatus'] ?? '')
          .toString();

      if (_options.any((e) => e['value'] == value)) {
        _selectedValue = value;
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_selectedValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr('Vui lòng chọn thẻ cư trú', 'Please choose resident status'),
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

// Lưu tình trạng cư trú
await userRef.set({
  'residentStatus': _selectedValue,
  'residencyStatus': _selectedValue,
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
Navigator.pop(context, _selectedValue);
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
    final value = option['value']!;
    final selected = _selectedValue == value;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() {
          _selectedValue = value;
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
              children: _options.map(_optionTile).toList(),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF7A2E6E),
        centerTitle: true,
        title: Text(
          _tr('Sửa thẻ cư trú', 'Edit resident status'),
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
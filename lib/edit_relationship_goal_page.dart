import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'utils/profile_health.dart';

class EditRelationshipGoalPage extends StatefulWidget {
  final String languageCode;

  const EditRelationshipGoalPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditRelationshipGoalPage> createState() =>
      _EditRelationshipGoalPageState();
}

class _EditRelationshipGoalPageState
    extends State<EditRelationshipGoalPage> {
  final List<String> _selectedValues = [];

  bool _isLoading = true;
  bool _isSaving = false;

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  final List<Map<String, String>> _options = const [
    {
      'value': 'serious_relationship',
      'vi': 'Mối quan hệ nghiêm túc',
      'en': 'Serious relationship',
    },
    {
      'value': 'long_term_partner',
      'vi': 'Bạn đời lâu dài',
      'en': 'Long-term partner',
    },
    {
      'value': 'friendship_first',
      'vi': 'Bắt đầu từ tình bạn',
      'en': 'Friendship first',
    },
    {
      'value': 'chat_and_get_to_know',
      'vi': 'Trò chuyện và tìm hiểu',
      'en': 'Chat and get to know each other',
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

      final data = doc.data() ?? <String, dynamic>{};

      final savedGoals = List<String>.from(
        data['relationshipGoals'] ?? [],
      );

      _selectedValues
        ..clear()
        ..addAll(
          savedGoals.where(
            (value) => _options.any(
              (option) => option['value'] == value,
            ),
          ),
        );

      // Hỗ trợ hồ sơ cũ chỉ có relationshipGoal.
      if (_selectedValues.isEmpty) {
        final oldValue =
            (data['relationshipGoal'] ?? '').toString();

        if (_options.any(
          (option) => option['value'] == oldValue,
        )) {
          _selectedValues.add(oldValue);
        }
      }
    } catch (_) {
      // Giữ nguyên cách xử lý cũ.
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_selectedValues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Vui lòng chọn ít nhất một mục tiêu mối quan hệ',
              'Please choose at least one relationship goal',
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
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      // Lưu nhiều mục tiêu mối quan hệ.
      // Vẫn giữ relationshipGoal để không ảnh hưởng code cũ.
      await userRef.set({
        'relationshipGoal': _selectedValues.first,
        'relationshipGoals':
            List<String>.from(_selectedValues),
      }, SetOptions(merge: true));

      // Đọc lại hồ sơ mới nhất.
      final updatedDoc = await userRef.get();

      final updatedData =
          updatedDoc.data() ?? <String, dynamic>{};

      // Tính lại điểm hồ sơ — giữ nguyên.
      final healthResult =
          calculateProfileHealth(updatedData);

      // Cập nhật điểm và trạng thái hồ sơ — giữ nguyên.
      await userRef.set({
        'profileScore': healthResult.score,
        'profileCompleted': healthResult.score >= 50,
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pop(
        context,
        List<String>.from(_selectedValues),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr('Lưu thất bại', 'Save failed'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _optionTile(Map<String, String> option) {
    final value = option['value']!;

    final selected = _selectedValues.contains(value);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _isSaving
          ? null
          : () {
              setState(() {
                if (_selectedValues.contains(value)) {
                  _selectedValues.remove(value);
                } else {
                  _selectedValues.add(value);
                }
              });
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFEEF5)
              : Colors.white,
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
              selected
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              color: const Color(0xFFCC3D7A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        24,
      ),
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
                backgroundColor:
                    const Color(0xFFCC3D7A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(18),
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
          _tr(
            'Sửa mục tiêu mối quan hệ',
            'Edit relationship goal',
          ),
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
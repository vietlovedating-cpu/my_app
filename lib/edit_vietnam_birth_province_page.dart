import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditVietnamBirthProvincePage extends StatefulWidget {
  final String languageCode;

  const EditVietnamBirthProvincePage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditVietnamBirthProvincePage> createState() =>
      _EditVietnamBirthProvincePageState();
}

class _EditVietnamBirthProvincePageState
    extends State<EditVietnamBirthProvincePage> {
  String? _selectedProvince;

  bool _isLoading = true;
  bool _isSaving = false;

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  static const List<String> vietnamProvinces = [
    'An Giang',
    'Ba Ria - Vung Tau',
    'Bac Giang',
    'Bac Kan',
    'Bac Lieu',
    'Bac Ninh',
    'Ben Tre',
    'Binh Dinh',
    'Binh Duong',
    'Binh Phuoc',
    'Binh Thuan',
    'Ca Mau',
    'Can Tho',
    'Cao Bang',
    'Da Nang',
    'Dak Lak',
    'Dak Nong',
    'Dien Bien',
    'Dong Nai',
    'Dong Thap',
    'Gia Lai',
    'Ha Giang',
    'Ha Nam',
    'Ha Noi',
    'Ha Tinh',
    'Hai Duong',
    'Hai Phong',
    'Hau Giang',
    'Ho Chi Minh City',
    'Hoa Binh',
    'Hung Yen',
    'Khanh Hoa',
    'Kien Giang',
    'Kon Tum',
    'Lai Chau',
    'Lam Dong',
    'Lang Son',
    'Lao Cai',
    'Long An',
    'Nam Dinh',
    'Nghe An',
    'Ninh Binh',
    'Ninh Thuan',
    'Phu Tho',
    'Phu Yen',
    'Quang Binh',
    'Quang Nam',
    'Quang Ngai',
    'Quang Ninh',
    'Quang Tri',
    'Soc Trang',
    'Son La',
    'Tay Ninh',
    'Thai Binh',
    'Thai Nguyen',
    'Thanh Hoa',
    'Thua Thien Hue',
    'Tien Giang',
    'Tra Vinh',
    'Tuyen Quang',
    'Vinh Long',
    'Vinh Phuc',
    'Yen Bai',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentProvince();
  }

  Future<void> _loadCurrentProvince() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      final currentProvince =
          (data['vietnamBirthProvince'] ?? '')
              .toString()
              .trim();

      if (vietnamProvinces.contains(currentProvince)) {
        _selectedProvince = currentProvince;
      }
    } catch (e) {
      debugPrint('Load Vietnam birth province error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final selectedProvince = _selectedProvince?.trim() ?? '';

    if (selectedProvince.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Vui lòng chọn tỉnh/thành phố',
              'Please select a province/city',
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

      if (user == null) {
        throw Exception('User is not signed in');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'countryBorn': 'Vietnam',
        'countryOfBirth': 'Vietnam',
        'vietnamBirthProvince': selectedProvince,
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pop(context, {
        'countryBorn': 'Vietnam',
        'countryOfBirth': 'Vietnam',
        'vietnamBirthProvince': selectedProvince,
      });
    } catch (e) {
      debugPrint('Save Vietnam birth province error: $e');

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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        children: [
          Text(
            _tr(
              'Bạn sinh ra ở tỉnh/thành nào của Việt Nam?',
              'Which province/city in Vietnam were you born in?',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFFFD5E6),
              ),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedProvince,
              isExpanded: true,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _tr(
                  'Chọn tỉnh/thành',
                  'Select province/city',
                ),
              ),
              items: vietnamProvinces.map((province) {
                return DropdownMenuItem<String>(
                  value: province,
                  child: Text(
                    province,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _selectedProvince = value;
                      });
                    },
            ),
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
                disabledBackgroundColor:
                    const Color(0xFFCC3D7A).withOpacity(0.55),
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
          _tr(
            'Sửa tỉnh/thành nơi sinh',
            'Edit birth province',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A2E6E),
          ),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }
}
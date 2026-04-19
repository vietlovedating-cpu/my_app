import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditVietnamBirthCityPage extends StatefulWidget {
  final String languageCode;

  const EditVietnamBirthCityPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditVietnamBirthCityPage> createState() =>
      _EditVietnamBirthCityPageState();
}

class _EditVietnamBirthCityPageState extends State<EditVietnamBirthCityPage> {
  String? _selectedCity;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get isVi => widget.languageCode == 'vi';
  String _tr(String vi, String en) => isVi ? vi : en;

  final List<String> _cities = const [
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
      final current = (data['vietnamBirthCity'] ??
              data['vietnamBirthProvince'] ??
              data['cityOfBirth'] ??
              '')
          .toString()
          .trim();

      if (_cities.contains(current)) {
        _selectedCity = current;
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Vui lòng chọn thành phố sinh ở Việt Nam',
              'Please choose Vietnam city of birth',
            ),
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
        'vietnamBirthCity': _selectedCity,
        'vietnamBirthProvince': _selectedCity,
        'cityOfBirth': _selectedCity,
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, _selectedCity);
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFD5E6)),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedCity,
              isExpanded: true,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _tr(
                  'Chọn thành phố sinh ở Việt Nam',
                  'Choose Vietnam city of birth',
                ),
              ),
              items: _cities.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCity = value;
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
          _tr('Sửa thành phố sinh ở Việt Nam', 'Edit Vietnam city of birth'),
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
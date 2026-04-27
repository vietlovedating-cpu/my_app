import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditMaxDistancePage extends StatefulWidget {
  final String languageCode;

  const EditMaxDistancePage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditMaxDistancePage> createState() => _EditMaxDistancePageState();
}

class _EditMaxDistancePageState extends State<EditMaxDistancePage> {
  double _selectedDistance = 50;
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
      final raw = data['maxDistanceKm'] ?? data['maxDistance'];

      if (raw is int) {
        _selectedDistance = raw.toDouble();
      } else if (raw is double) {
        _selectedDistance = raw;
      } else if (raw != null) {
        _selectedDistance = double.tryParse(raw.toString()) ?? 50;
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
  'maxDistanceKm': _selectedDistance.round(),
  'maxDistance': _selectedDistance.round(),
}, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, _selectedDistance.round());
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
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFD5E6)),
            ),
            child: Column(
              children: [
                Text(
                  '${_selectedDistance.round()} km',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7A2E6E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tr(
                    'Kéo để chọn khoảng cách tối đa',
                    'Drag to choose max distance',
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A6A7B),
                  ),
                ),
                const SizedBox(height: 18),
                Slider(
                  value: _selectedDistance,
                  min: 1,
                  max: 500,
                  divisions: 499,
                  activeColor: const Color(0xFFCC3D7A),
                  inactiveColor: const Color(0xFFFFD5E6),
                  label: '${_selectedDistance.round()}',
                  onChanged: (value) {
                    setState(() => _selectedDistance = value);
                  },
                ),
              ],
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
          _tr('Sửa khoảng cách tối đa', 'Edit max distance'),
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
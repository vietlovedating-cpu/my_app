import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';

class EditLiveInPage extends StatefulWidget {
  final String languageCode;

  const EditLiveInPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditLiveInPage> createState() => _EditLiveInPageState();
}

class _EditLiveInPageState extends State<EditLiveInPage> {
  String? _selectedState;
  String? _selectedCountry;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get isVi => widget.languageCode == 'vi';
  String _tr(String vi, String en) => isVi ? vi : en;

  final List<String> _states = const [
    'New South Wales (NSW)',
    'Victoria (VIC)',
    'Queensland (QLD)',
    'South Australia (SA)',
    'Western Australia (WA)',
    'Tasmania (TAS)',
     'Other',
  ];
late final List<String> _countries;
  @override
void initState() {
  super.initState();

  _countries = CountryService()
      .getAll()
      .map((country) => country.name)
      .toList();

  _loadCurrentData();
}

  String? _matchState(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();

    for (final item in _states) {
      if (item.toLowerCase() == value) return item;
    }

    if (value == 'nsw') return 'New South Wales (NSW)';
    if (value == 'vic') return 'Victoria (VIC)';
    if (value == 'qld') return 'Queensland (QLD)';
    if (value == 'sa') return 'South Australia (SA)';
    if (value == 'wa') return 'Western Australia (WA)';
    if (value == 'tas') return 'Tasmania (TAS)';

    return null;
  }

  String _stateShortCode(String value) {
    if (value.contains('(NSW)')) return 'nsw';
    if (value.contains('(VIC)')) return 'vic';
    if (value.contains('(QLD)')) return 'qld';
    if (value.contains('(SA)')) return 'sa';
    if (value.contains('(WA)')) return 'wa';
    if (value.contains('(TAS)')) return 'tas';
    return value.toLowerCase();
  }
String _normalizeStateKey(String value) {
  final v = value.toLowerCase();

  if (v.contains('nsw')) return 'nsw';
  if (v.contains('vic')) return 'vic';
  if (v.contains('qld')) return 'qld';
  if (v.contains('sa')) return 'sa';
  if (v.contains('wa')) return 'wa';
  if (v.contains('tas')) return 'tas';

  return v;
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

    final savedCountry =
        (data['selectedCountry'] ?? '').toString().trim();

    final savedState = _matchState(
      data['selectedState'],
    );

    if (savedCountry.isNotEmpty &&
    savedCountry.toLowerCase() != 'australia') {
  _selectedState = 'Other';

  _selectedCountry = _countries.contains(savedCountry)
      ? savedCountry
      : null;
} else {
  _selectedState = savedState;
  _selectedCountry = null;
}
  } catch (_) {
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  Future<void> _save() async {
    if (_selectedState == null || _selectedState!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr('Vui lòng chọn nơi đang sống', 'Please choose where you live'),
          ),
        ),
      );
      return;
    }
if (_selectedState == 'Other' &&
    (_selectedCountry == null || _selectedCountry!.isEmpty)) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
        _tr('Vui lòng chọn quốc gia', 'Please choose your country'),
      ),
    ),
  );
  return;
}
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final stateToSave = _selectedState == 'Other'
    ? 'Other - ${_selectedCountry!}'
    : _selectedState!;

await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .set({
  'selectedState': stateToSave,
  'selectedStateLower': stateToSave.toLowerCase(),
  'selectedStateKey': _selectedState == 'Other'
      ? 'other'
      : _normalizeStateKey(_selectedState!),
 'selectedCountry': _selectedState == 'Other'
    ? _selectedCountry!
    : 'Australia',
  'onboardingStep': 'current_location',
}, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, _selectedState);
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
              value: _selectedState,
              isExpanded: true,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _tr('Chọn bang đang sống', 'Choose your state'),
              ),
              items: _states.map((item) {
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
                  _selectedState = value;
                });
              },
            ),
          ),
          if (_selectedState == 'Other') ...[
  const SizedBox(height: 16),
  Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFFFD5E6)),
    ),
    child: DropdownButtonFormField<String>(
      value: _selectedCountry,
      isExpanded: true,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: _tr('Chọn quốc gia', 'Choose your country'),
      ),
      items: _countries.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCountry = value;
        });
      },
    ),
  ),
],
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
          _tr('Sửa sống tại', 'Edit live in'),
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
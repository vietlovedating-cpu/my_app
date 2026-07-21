import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:country_state_city/country_state_city.dart' as csc;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditPlaceYouCallHomePage extends StatefulWidget {
  final String languageCode;

  const EditPlaceYouCallHomePage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditPlaceYouCallHomePage> createState() =>
      _EditPlaceYouCallHomePageState();
}

class _EditPlaceYouCallHomePageState
    extends State<EditPlaceYouCallHomePage> {
  Country? selectedCountry;

  List<csc.State> availableStates = [];
  String? selectedState;

  bool isLoading = true;
  bool isLoadingStates = false;
  bool isSaving = false;

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      final savedCountryCode =
          (data['countryCode'] ?? '').toString().trim().toUpperCase();

      final savedCountryName =
          (data['selectedCountry'] ?? '').toString().trim();

      final savedState =
          (data['selectedStateKey'] ?? data['filterState'] ?? '')
              .toString()
              .trim();

      Country? loadedCountry;

      if (savedCountryCode.isNotEmpty) {
        try {
          loadedCountry = Country.parse(savedCountryCode);
        } catch (_) {
          loadedCountry = null;
        }
      }

      if (loadedCountry == null && savedCountryName.isNotEmpty) {
        try {
          loadedCountry = Country.parse(savedCountryName);
        } catch (_) {
          loadedCountry = null;
        }
      }

      loadedCountry ??= _defaultAustraliaCountry();

      if (!mounted) return;

      setState(() {
        selectedCountry = loadedCountry;
        selectedState = savedState.isEmpty ? null : savedState;
      });

      await _loadStatesForCountry(
        loadedCountry.countryCode,
        keepSavedState: true,
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Load current location error: $e');

      if (!mounted) return;

      final defaultCountry = _defaultAustraliaCountry();

      setState(() {
        selectedCountry = defaultCountry;
        selectedState = null;
      });

      await _loadStatesForCountry(defaultCountry.countryCode);

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Country _defaultAustraliaCountry() {
    return Country(
      phoneCode: '61',
      countryCode: 'AU',
      e164Sc: 0,
      geographic: true,
      level: 1,
      name: 'Australia',
      example: '412345678',
      displayName: 'Australia (AU) [+61]',
      displayNameNoCountryCode: 'Australia (AU)',
      e164Key: '61-AU-0',
    );
  }

  Future<void> _loadStatesForCountry(
    String countryCode, {
    bool keepSavedState = false,
  }) async {
    if (!mounted) return;

    setState(() {
      isLoadingStates = true;
      availableStates = [];

      if (!keepSavedState) {
        selectedState = null;
      }
    });

    try {
      final states = await csc.getStatesOfCountry(
        countryCode.toUpperCase(),
      );

      states.sort(
        (a, b) => a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            ),
      );

      if (!mounted) return;

      setState(() {
        availableStates = states;

        final savedStateStillExists = availableStates.any(
          (state) => state.name == selectedState,
        );

        if (!savedStateStillExists) {
          selectedState = null;
        }

        isLoadingStates = false;
      });
    } catch (e) {
      debugPrint('Load states error: $e');

      if (!mounted) return;

      setState(() {
        availableStates = [];
        selectedState = null;
        isLoadingStates = false;
      });
    }
  }

  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      useSafeArea: true,
      countryListTheme: CountryListThemeData(
        backgroundColor: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        inputDecoration: InputDecoration(
          labelText: _tr(
            'Tìm quốc gia',
            'Search country',
          ),
          hintText: _tr(
            'Nhập tên quốc gia',
            'Enter country name',
          ),
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      onSelect: (Country country) async {
        setState(() {
          selectedCountry = country;
          selectedState = null;
          availableStates = [];
        });

        await _loadStatesForCountry(
          country.countryCode,
        );
      },
    );
  }

  Future<void> _save() async {
    final country = selectedCountry;
    final user = FirebaseAuth.instance.currentUser;

    if (country == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Vui lòng chọn quốc gia.',
              'Please select a country.',
            ),
          ),
        ),
      );
      return;
    }

    if (availableStates.isNotEmpty &&
        (selectedState == null || selectedState!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Vui lòng chọn bang hoặc tỉnh.',
              'Please select a state or province.',
            ),
          ),
        ),
      );
      return;
    }

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Không tìm thấy tài khoản.',
              'User account not found.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final stateToSave = selectedState?.trim() ?? '';

      final currentLocation = stateToSave.isNotEmpty
    ? '$stateToSave, ${country.name}'
    : country.name;

await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .set({
  // Quốc gia
  'selectedCountry': country.name,
  'country': country.name,
  'countryCode': country.countryCode,

  // Bang / tỉnh
  'selectedState': stateToSave,
  'selectedStateKey': stateToSave,
  'selectedStateLower': stateToSave.toLowerCase(),
  
  
  'state': stateToSave,
  'stateLiving': stateToSave,

  // Địa điểm hiển thị
  'address': stateToSave,
  'currentLocation': currentLocation,

  // Thời gian cập nhật
  'countryUpdatedAt': FieldValue.serverTimestamp(),
  'locationUpdatedAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Đã cập nhật nơi bạn đang sống.',
              'Your location has been updated.',
            ),
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Save location error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Không thể lưu thông tin. Vui lòng thử lại.',
              'Unable to save your location. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final country = selectedCountry;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F4F6),
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _tr(
            'Sửa nơi bạn gọi là nhà',
            'Edit place you call home',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        kToolbarHeight -
                        52,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.public_rounded,
                          size: 64,
                          color: Colors.pink,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _tr(
                            'Bạn đang sống ở đâu?',
                            'Where do you currently live?',
                          ),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E2A27),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _tr(
                            'Chọn quốc gia và bang hoặc tỉnh nơi bạn hiện đang sinh sống.',
                            'Choose the country and state or province where you currently live.',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 30),

                        Text(
                          _tr('Quốc gia', 'Country'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),

                        InkWell(
                          onTap: isSaving
                              ? null
                              : _openCountryPicker,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 17,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7FA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFD8C3B5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  country?.flagEmoji ?? '🌏',
                                  style: const TextStyle(
                                    fontSize: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    country?.name ??
                                        _tr(
                                          'Chọn quốc gia',
                                          'Select country',
                                        ),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        Text(
                          _tr(
                            'Bang / Tỉnh',
                            'State / Province',
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (isLoadingStates)
                          Container(
                            width: double.infinity,
                            height: 58,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7FA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFD8C3B5),
                              ),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Loading...',
                                  style: TextStyle(
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (availableStates.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 17,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              _tr(
                                'Quốc gia này không có danh sách bang hoặc tỉnh.',
                                'No state or province list is available for this country.',
                              ),
                              style: const TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                          )
                        else
                          DropdownButtonFormField<String>(
                            value: availableStates.any(
                              (state) =>
                                  state.name == selectedState,
                            )
                                ? selectedState
                                : null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: _tr(
                                'Chọn bang hoặc tỉnh',
                                'Select state or province',
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFFF7FA),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 17,
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD8C3B5),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD8C3B5),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Colors.pink,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            items: availableStates.map((state) {
                              return DropdownMenuItem<String>(
                                value: state.name,
                                child: Text(
                                  state.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: isSaving
                                ? null
                                : (value) {
                                    setState(() {
                                      selectedState = value;
                                    });
                                  },
                          ),

                        const Spacer(),
                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed:
                                isSaving || isLoadingStates
                                    ? null
                                    : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  Colors.pink.shade200,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(30),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 23,
                                    height: 23,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _tr('Lưu', 'Save'),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
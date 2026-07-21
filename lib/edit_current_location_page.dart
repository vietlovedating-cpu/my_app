import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class EditCurrentLocationPage extends StatefulWidget {
  final String languageCode;

  const EditCurrentLocationPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<EditCurrentLocationPage> createState() => _EditCurrentLocationPageState();
}

class _EditCurrentLocationPageState extends State<EditCurrentLocationPage> {
  final TextEditingController _addressController = TextEditingController();
String _selectedCountry = '';
String _selectedState = '';
String _city = '';

double? _latitude;
double? _longitude;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingLocation = false;

  bool get isVi => widget.languageCode == 'vi';
  String _tr(String vi, String en) => isVi ? vi : en;
String _normalizeAustralianState(String value) {
  final normalized = value.trim().toLowerCase();

  if (normalized == 'new south wales' ||
      normalized == 'new south wales (nsw)' ||
      normalized == 'nsw') {
    return 'NSW';
  }

  if (normalized == 'victoria' ||
      normalized == 'victoria (vic)' ||
      normalized == 'vic') {
    return 'VIC';
  }

  if (normalized == 'queensland' ||
      normalized == 'queensland (qld)' ||
      normalized == 'qld') {
    return 'QLD';
  }

  if (normalized == 'south australia' ||
      normalized == 'south australia (sa)' ||
      normalized == 'sa') {
    return 'SA';
  }

  if (normalized == 'western australia' ||
      normalized == 'western australia (wa)' ||
      normalized == 'wa') {
    return 'WA';
  }

  if (normalized == 'tasmania' ||
      normalized == 'tasmania (tas)' ||
      normalized == 'tas') {
    return 'TAS';
  }

  if (normalized == 'australian capital territory' ||
      normalized == 'australian capital territory (act)' ||
      normalized == 'act') {
    return 'ACT';
  }

  if (normalized == 'northern territory' ||
      normalized == 'northern territory (nt)' ||
      normalized == 'nt') {
    return 'NT';
  }

  return value.trim();
}
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

    final country = (data['selectedCountry'] ?? '').toString().trim();

    final state = (data['selectedState'] ??
            data['state'] ??
            data['stateLiving'] ??
            data['stateProvince'] ??
            '')
        .toString()
        .trim();

    final city = (data['suburb'] ?? data['city'] ?? '').toString().trim();

    final currentLocation =
        (data['currentLocation'] ?? data['address'] ?? '').toString().trim();

    final latValue = data['lat'];
    final lngValue = data['lng'];

    if (!mounted) return;

    setState(() {
      _selectedCountry = country;
      _selectedState = state;
      _city = city;

      _latitude = latValue is num ? latValue.toDouble() : null;
      _longitude = lngValue is num ? lngValue.toDouble() : null;

      if (currentLocation.isNotEmpty) {
        _addressController.text = currentLocation;
      } else {
        final parts = [
          city,
          state,
          country,
        ].where((value) => value.trim().isNotEmpty).toList();

        _addressController.text = parts.join(', ');
      }
    });
  } catch (e) {
    debugPrint('Unable to load current location: $e');
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

 Future<void> _getCurrentLocation() async {
  setState(() {
    _isLoadingLocation = true;
  });

  try {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Dịch vụ vị trí đang tắt. Vui lòng bật GPS.',
              'Location services are disabled. Please turn on GPS.',
            ),
          ),
        ),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Bạn đã từ chối quyền truy cập vị trí.',
              'Location permission was denied.',
            ),
          ),
        ),
      );
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy bật lại trong cài đặt.',
              'Location permission is permanently denied. Please enable it in settings.',
            ),
          ),
        ),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Không tìm thấy địa chỉ từ vị trí hiện tại.',
              'Could not find an address from your current location.',
            ),
          ),
        ),
      );
      return;
    }

    final place = placemarks.first;

    final country = (place.country ?? _selectedCountry).trim();

    final rawState = (place.administrativeArea ?? _selectedState).trim();

    final isAustralia = country.toLowerCase() == 'australia';

    final state = isAustralia
        ? _normalizeAustralianState(rawState)
        : rawState;

    // subLocality thường chính xác hơn locality đối với suburb ở Australia.
   final city = (place.locality ?? place.subLocality ?? '').trim();

    final locationParts = [
      city,
      state,
      country,
    ].where((value) => value.trim().isNotEmpty).toList();

    final locationText = locationParts.join(', ');

    if (!mounted) return;

    setState(() {
      _selectedCountry = country;
      _selectedState = state;
      _city = city;

      _latitude = position.latitude;
      _longitude = position.longitude;

      _addressController.text = locationText;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          _tr(
            'Đã tự động điền vị trí hiện tại',
            'Current location has been filled in',
          ),
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          _tr(
            'Lỗi khi lấy vị trí: $e',
            'Error while getting location: $e',
          ),
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }
}
 Future<void> _save() async {
  final enteredAddress = _addressController.text.trim();

  if (enteredAddress.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          _tr(
            'Vui lòng nhập địa chỉ hoặc dùng vị trí hiện tại',
            'Please enter an address or use your current location',
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

    String country = _selectedCountry.trim();
    String state = _selectedState.trim();
    String city = _city.trim();

    double? lat = _latitude;
    double? lng = _longitude;

    /*
     * Khi người dùng tự sửa hoặc tự nhập địa chỉ,
     * tìm lại lat/lng và tách city, state, country.
     */
    try {
      final locations = await locationFromAddress(enteredAddress);

      if (locations.isNotEmpty) {
        lat = locations.first.latitude;
        lng = locations.first.longitude;

        final placemarks = await placemarkFromCoordinates(lat, lng);

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          final detectedCountry = (place.country ?? '').trim();
          final detectedState = (place.administrativeArea ?? '').trim();

         final detectedCity =
    (place.locality ?? place.subLocality ?? '').trim();

          if (detectedCountry.isNotEmpty) {
            country = detectedCountry;
          }

          if (detectedState.isNotEmpty) {
            state = detectedState;
          }

          if (detectedCity.isNotEmpty) {
            city = detectedCity;
          }
        }
      }
    } catch (e) {
      debugPrint('Unable to geocode entered address: $e');
    }

    final isAustralia = country.toLowerCase() == 'australia';

    if (isAustralia) {
      state = _normalizeAustralianState(state);
    }

    /*
     * Trường hợp geocoding không lấy được city,
     * giữ lại city/suburb cũ thay vì xóa dữ liệu.
     */
    if (city.isEmpty) {
      city = _city.trim();
    }

    if (country.isEmpty) {
      country = _selectedCountry.trim();
    }

    if (state.isEmpty) {
      state = _selectedState.trim();
    }

    final locationParts = [
      city,
      state,
      country,
    ].where((value) => value.trim().isNotEmpty).toList();

    /*
     * Nếu tách được city/state/country thì chuẩn hóa lại.
     * Nếu không tách được thì giữ nguyên địa chỉ user nhập.
     */
    final locationText = locationParts.isNotEmpty
        ? locationParts.join(', ')
        : enteredAddress;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
    if (country.isNotEmpty) ...{
  'selectedCountry': country,
  'filterCountry': country,
},

if (state.isNotEmpty) ...{
  'selectedState': state,
  'selectedStateKey': state,
  'state': state,
  'stateLiving': state,

  // Đồng bộ filter
  'filterState': state,
  'filterStateKey': state,
},

      if (city.isNotEmpty) ...{
        'city': city,
        'cityLower': city.toLowerCase(),
        'suburb': city,
        'suburbLower': city.toLowerCase(),
      },

      'address': locationText,
      'currentLocation': locationText,

      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,

      'locationUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    

    if (!mounted) return;

    Navigator.pop(context, locationText);
  } catch (e) {
    debugPrint('Unable to save current location: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          _tr(
            'Lưu vị trí thất bại',
            'Failed to save location',
          ),
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

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    const sampleAddresses = <String>[
      'Sydney NSW, Australia',
      'Parramatta NSW, Australia',
      'Chatswood NSW, Australia',
      'Bankstown NSW, Australia',
      'Cabramatta NSW, Australia',
      'Melbourne VIC, Australia',
      'Brisbane QLD, Australia',
      'Perth WA, Australia',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              border: Border.all(color: const Color(0xFFFFD5E6)),
            ),
            child: const Center(
              child: Icon(
                Icons.location_on,
                size: 42,
                color: Color(0xFFCC3D7A),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              final query = textEditingValue.text.trim().toLowerCase();
              if (query.isEmpty) return const Iterable<String>.empty();

              return sampleAddresses.where(
                (item) => item.toLowerCase().contains(query),
              );
            },
            onSelected: (String selection) {
              _addressController.text = selection;
            },
            fieldViewBuilder: (
              context,
              textEditingController,
              focusNode,
              onFieldSubmitted,
            ) {
              textEditingController.value = _addressController.value;
              textEditingController.addListener(() {
                _addressController.value = textEditingController.value;
              });

              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.location_on),
                  hintText: _tr(
                    'Tìm theo địa chỉ...',
                    'Search by name or address...',
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFD6E7),
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
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: MediaQuery.of(context).size.width - 36,
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          title: Text(
                            option,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            _tr(
              'Cho phép truy cập vị trí để tìm người ở gần bạn',
              'Allow location access to find matches near you',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8A6A7B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              icon: _isLoadingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _isLoadingLocation
                    ? _tr('Đang lấy vị trí...', 'Getting location...')
                    : _tr('Dùng vị trí hiện tại', 'Use current location'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC3D7A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
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
          _tr('Sửa vị trí hiện tại', 'Edit current location'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A2E6E),
          ),
        ),
      ),
     body: SafeArea(
  child: SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom,
    ),
    child: _buildBody(),
  ),
),
    );
  }
}
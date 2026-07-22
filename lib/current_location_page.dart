import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'gender_page.dart';
import 'app_overflow_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_state_city/country_state_city.dart' as csc;



class CurrentLocationPage extends StatefulWidget {
  final String languageCode;
  final String selectedState;
  final String selectedCountry;
  final String firstName;

  const CurrentLocationPage({
  super.key,
  required this.languageCode,
  required this.selectedState,
  required this.selectedCountry,
  required this.firstName,
});

  @override
  State<CurrentLocationPage> createState() => _CurrentLocationPageState();
}

class _CurrentLocationPageState extends State<CurrentLocationPage> {
  late TextEditingController _addressController;
  late TextEditingController _cityController;
late TextEditingController _stateProvinceController;
  bool _isLoadingLocation = false;
  String detectedCity = '';
String detectedState = '';
String detectedCountry = '';
double? detectedLat;
double? detectedLng;
List<csc.State> _foreignStates = [];
List<csc.City> _foreignCities = [];

csc.State? _selectedForeignState;
csc.City? _selectedForeignCity;

bool _isLoadingStates = false;
bool _isLoadingCities = false;
  

 @override
void initState() {
  super.initState();

  _addressController = TextEditingController();
  _cityController = TextEditingController();
  _stateProvinceController = TextEditingController();

  _loadForeignStates();
}

  @override
void dispose() {
  _addressController.dispose();
  _cityController.dispose();
  _stateProvinceController.dispose();
  super.dispose();
}
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
Future<String?> _findSelectedCountryCode() async {
  final countries = await csc.getAllCountries();

  final selectedCountryName =
      widget.selectedCountry.trim().toLowerCase();

  for (final country in countries) {
    if (country.name.trim().toLowerCase() ==
        selectedCountryName) {
      return country.isoCode;
    }
  }

  return null;
}

Future<void> _loadForeignStates() async {
  final isAustralia =
      widget.selectedCountry.trim().toLowerCase() ==
          'australia';

  if (isAustralia) return;

  setState(() {
    _isLoadingStates = true;
  });

  try {
    final countryCode =
        await _findSelectedCountryCode();

    if (countryCode == null || countryCode.isEmpty) {
      return;
    }

    final states =
        await csc.getStatesOfCountry(countryCode);
        states.sort(
  (a, b) => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
);

    if (!mounted) return;

    setState(() {
  _foreignStates = states;
  _selectedForeignState = null;

  _foreignCities = [];
  _selectedForeignCity = null;

  if (states.isEmpty) {
    _stateProvinceController.text =
        widget.selectedCountry.trim();

    _cityController.text =
        widget.selectedCountry.trim();
  }
});
  } catch (e) {
    debugPrint('Load foreign states error: $e');
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingStates = false;
      });
    }
  }
}

Future<void> _loadForeignCities(
  csc.State selectedState,
) async {
  setState(() {
    _isLoadingCities = true;
    _foreignCities = [];
    _selectedForeignCity = null;
  });

  try {
    final cities = await csc.getStateCities(
      selectedState.countryCode,
      selectedState.isoCode,
    );
cities.sort(
  (a, b) => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
);
    if (!mounted) return;

    setState(() {
      _foreignCities = cities;
    });
  } catch (e) {
    debugPrint('Load foreign cities error: $e');
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingCities = false;
      });
    }
  }
}
  Future<void> _getCurrentLocation() async {
    final isVi = widget.languageCode == 'vi';

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVi
                  ? 'Dịch vụ vị trí đang tắt. Vui lòng bật GPS.'
                  : 'Location services are disabled. Please turn on GPS.',
            ),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVi
                  ? 'Bạn đã từ chối quyền truy cập vị trí.'
                  : 'Location permission was denied.',
            ),
          ),
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVi
                  ? 'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy bật lại trong cài đặt.'
                  : 'Location permission is permanently denied. Please enable it in settings.',
            ),
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final isAustralia =
    widget.selectedCountry.trim().toLowerCase() == 'australia';

final locality = (place.locality ?? '').trim();
final subLocality = (place.subLocality ?? '').trim();
final subAdministrativeArea =
    (place.subAdministrativeArea ?? '').trim();
final administrativeArea =
    (place.administrativeArea ?? '').trim();

detectedCountry =
    (place.country ?? widget.selectedCountry).trim();

if (isAustralia) {
  // Australia: locality thường là suburb chính xác hơn.
  detectedCity = locality.isNotEmpty
      ? locality
      : subLocality;

  // State Australia vẫn lấy từ trang trước.
  detectedState =
      _normalizeAustralianState(widget.selectedState);
} else {
  // Nước ngoài:
  // ưu tiên khu vực nhỏ hơn như Củ Chi, Thủ Đức, District 7.
  detectedCity = subLocality.isNotEmpty
      ? subLocality
      : subAdministrativeArea.isNotEmpty
          ? subAdministrativeArea
          : locality;

  detectedState = administrativeArea.isNotEmpty
      ? administrativeArea
      : detectedCountry;
}

detectedLat = position.latitude;
detectedLng = position.longitude;

        final addressParts = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ].where((part) => part != null && part.trim().isNotEmpty).toList();

        final fullAddress = addressParts.join(', ');

       setState(() {
  _cityController.text = detectedCity;
  _stateProvinceController.text = detectedState;
  _addressController.text = fullAddress;
});

if (!isAustralia) {
  final state = _foreignStates.where(
    (e) =>
        e.name.toLowerCase() ==
        detectedState.toLowerCase(),
  );

  if (state.isNotEmpty) {
    _selectedForeignState = state.first;

    await _loadForeignCities(
      _selectedForeignState!,
    );

    final city = _foreignCities.where(
      (e) =>
          e.name.toLowerCase() ==
          detectedCity.toLowerCase(),
    );

    if (city.isNotEmpty) {
      setState(() {
        _selectedForeignCity = city.first;
      });
    }
  }
}

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVi
                  ? 'Đã tự động điền địa chỉ hiện tại'
                  : 'Current address has been filled in',
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVi
                  ? 'Không tìm thấy địa chỉ từ vị trí hiện tại'
                  : 'Could not find address from current location',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Lỗi khi lấy vị trí: $e'
                : 'Error while getting location: $e',
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

  @override
  Widget build(BuildContext context) {
    final isAustralia =
    widget.selectedCountry.trim().toLowerCase() == 'australia';
    final isVi = widget.languageCode == 'vi';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      appBar: AppBar(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        title: Text(
          isVi ? 'Vị trí hiện tại' : 'Current Location',
        ),
      ),
     body: SingleChildScrollView(
  padding: const EdgeInsets.all(20),
  child: Column(
          children: [
            Text(
              isVi ? 'Chào ${widget.firstName}' : 'Hi ${widget.firstName}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.pink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
  isAustralia
      ? (isVi
          ? 'Bang bạn đã chọn: ${widget.selectedState}'
          : 'Your selected state: ${widget.selectedState}')
      : (isVi
          ? 'Quốc gia bạn đã chọn: ${widget.selectedCountry}'
          : 'Your selected country: ${widget.selectedCountry}'),
  textAlign: TextAlign.center,
  style: const TextStyle(
    fontSize: 15,
    color: Colors.black54,
  ),
),
            const SizedBox(height: 20),

            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[300],
              ),
              child: const Center(
                child: Icon(Icons.location_on, size: 40),
              ),
            ),

            const SizedBox(height: 20),

            Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      isVi ? 'Quốc gia' : 'Country',
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
    const SizedBox(height: 8),
    TextFormField(
      initialValue: widget.selectedCountry,
      enabled: false,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.public),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),

    const SizedBox(height: 18),

    if (!isAustralia) ...[
      if (_isLoadingStates)
  const LinearProgressIndicator()
else if (_foreignStates.isEmpty) ...[
  Text(
    isVi ? 'Bang hoặc tỉnh' : 'State or Province',
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
  ),
  const SizedBox(height: 8),
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.grey.shade300,
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.map_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.selectedCountry,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    ),
  ),
]else ...[
  Text(
    isVi ? 'Bang hoặc tỉnh' : 'State or Province',
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
  ),
  const SizedBox(height: 8),

  DropdownButtonFormField<csc.State>(
    value: _selectedForeignState,
    isExpanded: true,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.map_outlined),
      hintText: isVi
          ? 'Chọn bang hoặc tỉnh'
          : 'Select state or province',
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    items: _foreignStates.map((state) {
      return DropdownMenuItem<csc.State>(
        value: state,
        child: Text(
          state.name,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList(),
    onChanged: (state) async {
      if (state == null) return;

      setState(() {
        _selectedForeignState = state;
        _selectedForeignCity = null;

        _stateProvinceController.text = state.name;
        _cityController.clear();

        detectedLat = null;
        detectedLng = null;
      });

      await _loadForeignCities(state);
    },
  ),
],

const SizedBox(height: 18),

Text(
  isVi ? 'Thành phố' : 'City',
  style: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  ),
),

const SizedBox(height: 8),

if (_isLoadingCities)
  const LinearProgressIndicator()
else if (_foreignStates.isEmpty)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.grey.shade300,
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_city),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _cityController.text.trim().isNotEmpty
                ? _cityController.text.trim()
                : widget.selectedCountry,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    ),
  )
else if (_selectedForeignState == null)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.grey.shade300,
      ),
    ),
    child: Text(
      isVi
          ? 'Vui lòng chọn bang hoặc tỉnh trước'
          : 'Please select a state or province first',
      style: const TextStyle(
        color: Colors.black54,
      ),
    ),
  )
else if (_foreignCities.isEmpty)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.grey.shade300,
      ),
    ),
    child: Text(
      isVi
          ? 'Không có danh sách thành phố cho bang hoặc tỉnh này'
          : 'No city list is available for this state or province',
      style: const TextStyle(
        color: Colors.black54,
      ),
    ),
  )
else
  DropdownButtonFormField<csc.City>(
    value: _selectedForeignCity,
    isExpanded: true,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.location_city),
      hintText: isVi
          ? 'Chọn thành phố'
          : 'Select city',
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    items: _foreignCities.map((city) {
      return DropdownMenuItem<csc.City>(
        value: city,
        child: Text(
          city.name,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList(),
    onChanged: (city) {
      if (city == null) return;

      setState(() {
        _selectedForeignCity = city;
        _cityController.text = city.name;

        detectedLat = null;
        detectedLng = null;
      });
    },
  ),
    ],

    if (isAustralia) ...[
      Text(
        isVi ? 'Bang đã chọn' : 'Selected state',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        initialValue: widget.selectedState,
        enabled: false,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.map_outlined),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      const SizedBox(height: 18),

Text(
  isVi ? 'Khu vực / Suburb' : 'Suburb',
  style: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  ),
),

const SizedBox(height: 8),

TextField(
  controller: _cityController,
  decoration: InputDecoration(
    prefixIcon: const Icon(Icons.location_city),
    hintText: isVi
        ? 'Ví dụ: Wiley Park'
        : 'Example: Wiley Park',
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
    ),
  ),
),
    ],
  ],
),

            const SizedBox(height: 20),

            Text(
              isVi
                  ? 'Cho phép truy cập vị trí để tìm người ở gần bạn'
                  : 'Allow location access to find matches near you',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
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
                    ? (isVi ? 'Đang lấy vị trí...' : 'Getting location...')
                    : (isVi
                        ? 'Dùng vị trí hiện tại'
                        : 'Use current location'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                final isAustralia =
    widget.selectedCountry.trim().toLowerCase() == 'australia';

final user = FirebaseAuth.instance.currentUser;

if (user == null) {
  return;
}

if (!isAustralia) {
  final hasGpsLocation =
      detectedLat != null &&
      detectedLng != null &&
      _cityController.text.trim().isNotEmpty;

  // Quốc gia có danh sách State/Province:
  // nếu không dùng GPS thì bắt buộc chọn dropdown.
  if (!hasGpsLocation && _foreignStates.isNotEmpty) {
    if (_selectedForeignState == null ||
        _selectedForeignCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Vui lòng chọn Bang/Tỉnh và Thành phố'
                : 'Please select your State/Province and City',
          ),
        ),
      );
      return;
    }
  }

  // Ghi dữ liệu dropdown vào controller.
  if (_selectedForeignState != null) {
    _stateProvinceController.text =
        _selectedForeignState!.name;
  }

  if (_selectedForeignCity != null) {
    _cityController.text =
        _selectedForeignCity!.name;
  }

  // Quốc gia không có State/Province:
  // dùng tên quốc gia cho cả State và City.
  if (_foreignStates.isEmpty) {
    if (_stateProvinceController.text.trim().isEmpty) {
      _stateProvinceController.text =
          widget.selectedCountry.trim();
    }

    if (_cityController.text.trim().isEmpty) {
      _cityController.text =
          widget.selectedCountry.trim();
    }
  }
}

// Chỉ lấy dữ liệu sau khi đã xử lý dropdown/fallback.
final city = _cityController.text.trim();
final stateProvince =
    _stateProvinceController.text.trim();

final stateToSave = isAustralia
    ? _normalizeAustralianState(widget.selectedState)
    : stateProvince.isNotEmpty
        ? stateProvince
        : widget.selectedCountry.trim();

final cityToSave = city.isNotEmpty
    ? city
    : widget.selectedCountry.trim();

final locationText = isAustralia
    ? city.isNotEmpty
        ? '$city, $stateToSave, ${widget.selectedCountry}'
        : '$stateToSave, ${widget.selectedCountry}'
    : '$cityToSave, $stateToSave, ${widget.selectedCountry}';

// Nếu user tự nhập thay vì bấm GPS,
// app tự tìm lat/lng từ City + State + Country.
if (detectedLat == null || detectedLng == null) {
  try {
    final locations = await locationFromAddress(locationText);

    if (locations.isNotEmpty) {
      detectedLat = locations.first.latitude;
      detectedLng = locations.first.longitude;
    }
  } catch (e) {
    debugPrint('Unable to detect coordinates: $e');
  }
}
final selectedCountryCode =
    await _findSelectedCountryCode();
await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .set({
  'selectedCountry': widget.selectedCountry,
  'country': widget.selectedCountry,
  'filterCountry': widget.selectedCountry,
  'countryCode': selectedCountryCode ?? '',

  'selectedState': stateToSave,
  'selectedStateKey': stateToSave,
  'selectedStateLower': stateToSave.toLowerCase(),

  'state': stateToSave,
  'stateLiving': stateToSave,

  'filterState': stateToSave,
  'filterStateKey': stateToSave,

  'city': cityToSave,
  'cityLower': cityToSave.toLowerCase(),

  'address': locationText,
  'currentLocation': locationText,

  'suburb': cityToSave,
  'suburbLower': cityToSave.toLowerCase(),

  if (detectedLat != null) 'lat': detectedLat,
  if (detectedLng != null) 'lng': detectedLng,

  'onboardingStep': 'gender',
  'locationUpdatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GenderPage(
                        languageCode: widget.languageCode,
                        selectedCountry: widget.selectedCountry,
                        selectedState: stateToSave,
                        firstName: widget.firstName,
                        address: locationText,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isVi ? 'Tiếp theo →' : 'Next →',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
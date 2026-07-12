import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'gender_page.dart';
import 'app_overflow_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


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
  

  @override
void initState() {
  super.initState();

  _addressController = TextEditingController();
  _cityController = TextEditingController();
  _stateProvinceController = TextEditingController();
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

detectedCity = place.locality ?? '';
detectedCountry = place.country ?? widget.selectedCountry;

if (!isAustralia) {
  detectedState = place.administrativeArea ?? '';
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
              isVi
                  ? 'Bang bạn đã chọn: ${widget.selectedState}'
                  : 'Your selected state: ${widget.selectedState}',
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
      Text(
        isVi ? 'Thành phố' : 'City',
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
              ? 'Ví dụ: Ho Chi Minh City'
              : 'Example: Ho Chi Minh City',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        isVi ? 'Bang hoặc tỉnh' : 'State or Province',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _stateProvinceController,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.map_outlined),
          hintText: isVi
              ? 'Ví dụ: California'
              : 'Example: California',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
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
                 final city = _cityController.text.trim();
final stateProvince = _stateProvinceController.text.trim();
final isAustralia =
    widget.selectedCountry.trim().toLowerCase() == 'australia';
final address = isAustralia
    ? widget.selectedState
    : '$city, $stateProvince, ${widget.selectedCountry}';

                  if (address.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isVi
                              ? 'Vui lòng nhập địa chỉ hoặc dùng vị trí hiện tại'
                              : 'Please enter an address or use your current location',
                        ),
                      ),
                    );
                    return;
                  }
final user = FirebaseAuth.instance.currentUser;

if (user == null) {
  return;
}

final stateToSave = isAustralia
    ? _normalizeAustralianState(widget.selectedState)
    : stateProvince;

final cityToSave =
    city.isNotEmpty ? city : detectedCity;

// Nước khác Australia phải nhập City và State/Province.
if (!isAustralia && (city.isEmpty || stateProvince.isEmpty)) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        isVi
            ? 'Vui lòng nhập thành phố và bang hoặc tỉnh'
            : 'Please enter your city and state or province',
      ),
    ),
  );
  return;
}

final locationText = isAustralia
    ? city.isNotEmpty
        ? '$city, $stateToSave, ${widget.selectedCountry}'
        : '$stateToSave, ${widget.selectedCountry}'
    : '$city, $stateProvince, ${widget.selectedCountry}';

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

await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .set({
  'selectedCountry': widget.selectedCountry,

  'selectedState': stateToSave,
  'selectedStateKey': stateToSave,
  'state': stateToSave,
  'stateLiving': stateToSave,

  'city': cityToSave,
   'cityLower': cityToSave.toLowerCase(),
'address': locationText,
'currentLocation': locationText,

// thêm field này
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
                        selectedState: widget.selectedState,
                        firstName: widget.firstName,
                        address: address,
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
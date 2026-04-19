import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'gender_page.dart';
import 'app_overflow_wrapper.dart';

class CurrentLocationPage extends StatefulWidget {
  final String languageCode;
  final String selectedState;
  final String firstName;

  const CurrentLocationPage({
    super.key,
    required this.languageCode,
    required this.selectedState,
    required this.firstName,
  });

  @override
  State<CurrentLocationPage> createState() => _CurrentLocationPageState();
}

class _CurrentLocationPageState extends State<CurrentLocationPage> {
  late TextEditingController _addressController;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
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

            Autocomplete<String>(
  optionsBuilder: (TextEditingValue textEditingValue) {
    final query = textEditingValue.text.trim().toLowerCase();

    if (query.isEmpty) {
      return const Iterable<String>.empty();
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
        hintText: isVi
            ? 'Tìm theo địa chỉ...'
            : 'Search by name or address...',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFFFD6E7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.pink,
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
          width: MediaQuery.of(context).size.width - 40,
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
                onPressed: () {
                  final address = _addressController.text.trim();

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

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GenderPage(
                        languageCode: widget.languageCode,
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
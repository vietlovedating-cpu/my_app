import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_state_city/country_state_city.dart' as csc;
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
  State<EditCurrentLocationPage> createState() =>
      _EditCurrentLocationPageState();
}

class _EditCurrentLocationPageState
    extends State<EditCurrentLocationPage> {
  final TextEditingController _suburbController =
      TextEditingController();

  List<csc.Country> _availableCountries = [];
  List<csc.State> _availableStates = [];
  List<csc.City> _availableCities = [];

  csc.Country? _selectedCountryItem;
  csc.State? _selectedStateItem;
  csc.City? _selectedCityItem;

  String _selectedCountry = '';
  String _selectedState = '';
  String _city = '';

  double? _latitude;
  double? _longitude;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingLocation = false;
  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;
  bool _isLoadingCities = false;

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  bool get _isAustralia =>
      _selectedCountry.trim().toLowerCase() == 'australia';

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

  bool _stateMatchesSavedValue(
    csc.State state,
    String savedValue,
    bool isAustralia,
  ) {
    final saved = savedValue.trim().toLowerCase();

    if (saved.isEmpty) return false;

    if (state.name.trim().toLowerCase() == saved ||
        state.isoCode.trim().toLowerCase() == saved) {
      return true;
    }

    if (isAustralia) {
      return _normalizeAustralianState(state.name)
              .toLowerCase() ==
          _normalizeAustralianState(savedValue)
              .toLowerCase();
    }

    return false;
  }

  Future<void> _loadCountries() async {
    if (mounted) {
      setState(() {
        _isLoadingCountries = true;
      });
    }

    try {
      final countries = await csc.getAllCountries();

      countries.sort(
        (a, b) => a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            ),
      );

      if (!mounted) return;

      setState(() {
        _availableCountries = countries;
      });
    } catch (e) {
      debugPrint('Load countries error: $e');

      if (!mounted) return;

      setState(() {
        _availableCountries = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCountries = false;
        });
      }
    }
  }

  Future<void> _loadStatesForCountry(
    csc.Country country, {
    String? savedStateName,
    String? savedCityName,
  }) async {
    if (!mounted) return;

    setState(() {
      _isLoadingStates = true;
      _availableStates = [];
      _availableCities = [];
      _selectedStateItem = null;
      _selectedCityItem = null;
    });

    try {
      final states = await csc.getStatesOfCountry(
        country.isoCode.toUpperCase(),
      );

      states.sort(
        (a, b) => a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            ),
      );

      if (!mounted) return;

      final isAustralia =
          country.name.trim().toLowerCase() == 'australia';

      csc.State? matchedState;

      if (savedStateName != null &&
          savedStateName.trim().isNotEmpty) {
        for (final state in states) {
          if (_stateMatchesSavedValue(
            state,
            savedStateName,
            isAustralia,
          )) {
            matchedState = state;
            break;
          }
        }
      }

      setState(() {
        _availableStates = states;
        _selectedStateItem = matchedState;

        if (states.isEmpty) {
          _selectedState = country.name.trim();

          if (_city.trim().isEmpty) {
            _city = country.name.trim();
          }
        } else if (matchedState != null) {
          _selectedState = isAustralia
              ? _normalizeAustralianState(
                  matchedState.name,
                )
              : matchedState.name.trim();
        } else {
          _selectedState = '';
        }
      });

      if (matchedState != null && !isAustralia) {
        await _loadCitiesForState(
          matchedState,
          savedCityName: savedCityName,
        );
      }
    } catch (e) {
      debugPrint('Load states error: $e');

      if (!mounted) return;

      setState(() {
        _availableStates = [];
        _availableCities = [];
        _selectedStateItem = null;
        _selectedCityItem = null;

        _selectedState = country.name.trim();

        if (_city.trim().isEmpty) {
          _city = country.name.trim();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStates = false;
        });
      }
    }
  }

  Future<void> _loadCitiesForState(
    csc.State state, {
    String? savedCityName,
  }) async {
    if (!mounted) return;

    setState(() {
      _isLoadingCities = true;
      _availableCities = [];
      _selectedCityItem = null;
    });

    try {
      final cities = await csc.getStateCities(
        state.countryCode,
        state.isoCode,
      );

      cities.sort(
        (a, b) => a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            ),
      );

      if (!mounted) return;

      csc.City? matchedCity;

      if (savedCityName != null &&
          savedCityName.trim().isNotEmpty) {
        final saved =
            savedCityName.trim().toLowerCase();

        for (final city in cities) {
          if (city.name.trim().toLowerCase() == saved) {
            matchedCity = city;
            break;
          }
        }
      }

      setState(() {
        _availableCities = cities;
        _selectedCityItem = matchedCity;

        if (matchedCity != null) {
          _city = matchedCity.name.trim();
        }
      });
    } catch (e) {
      debugPrint('Load cities error: $e');

      if (!mounted) return;

      setState(() {
        _availableCities = [];
        _selectedCityItem = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCities = false;
        });
      }
    }
  }

  Future<void> _loadCurrentData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _loadCountries();

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      final country = (
        data['selectedCountry'] ??
        data['country'] ??
        data['filterCountry'] ??
        ''
      )
          .toString()
          .trim();

      final state = (
        data['selectedState'] ??
        data['selectedStateKey'] ??
        data['state'] ??
        data['stateLiving'] ??
        data['stateProvince'] ??
        data['filterState'] ??
        ''
      )
          .toString()
          .trim();

      final city = (
        data['suburb'] ??
        data['city'] ??
        ''
      )
          .toString()
          .trim();

      final latValue = data['lat'];
      final lngValue = data['lng'];

      csc.Country? matchedCountry;

      for (final item in _availableCountries) {
        if (item.name.trim().toLowerCase() ==
            country.toLowerCase()) {
          matchedCountry = item;
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        _selectedCountry = matchedCountry?.name ?? country;
        _selectedCountryItem = matchedCountry;

        _selectedState = state;
        _city = city;

        _suburbController.text = city;

        _latitude =
            latValue is num ? latValue.toDouble() : null;
        _longitude =
            lngValue is num ? lngValue.toDouble() : null;
      });

      if (matchedCountry != null) {
        await _loadStatesForCountry(
          matchedCountry,
          savedStateName: state,
          savedCityName: city,
        );
      }
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

  Future<void> _selectGpsResultInDropdowns({
    required String country,
    required String state,
    required String city,
  }) async {
    csc.Country? matchedCountry;

    for (final item in _availableCountries) {
      if (item.name.trim().toLowerCase() ==
          country.trim().toLowerCase()) {
        matchedCountry = item;
        break;
      }
    }

    if (matchedCountry == null) return;

    if (!mounted) return;

    setState(() {
      _selectedCountryItem = matchedCountry;
      _selectedCountry = matchedCountry!.name;
    });

    await _loadStatesForCountry(
      matchedCountry,
      savedStateName: state,
      savedCityName: city,
    );
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

      var permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
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

      if (permission ==
          LocationPermission.deniedForever) {
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

      final position =
          await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks =
          await placemarkFromCoordinates(
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

      final country = (
        place.country ??
        _selectedCountry
      )
          .trim();

      final locality =
          (place.locality ?? '').trim();

      final subLocality =
          (place.subLocality ?? '').trim();

      final subAdministrativeArea =
          (place.subAdministrativeArea ?? '').trim();

      final administrativeArea =
          (place.administrativeArea ?? '').trim();

      final isAustralia =
          country.toLowerCase() == 'australia';

      final city = isAustralia
          ? (locality.isNotEmpty
              ? locality
              : subLocality)
          : (subLocality.isNotEmpty
              ? subLocality
              : subAdministrativeArea.isNotEmpty
                  ? subAdministrativeArea
                  : locality);

      final state = isAustralia
          ? _normalizeAustralianState(
              administrativeArea.isNotEmpty
                  ? administrativeArea
                  : _selectedState,
            )
          : (administrativeArea.isNotEmpty
              ? administrativeArea
              : country);

      if (!mounted) return;

      setState(() {
        _selectedCountry = country;
        _selectedState = state;
        _city = city.isNotEmpty ? city : country;

        _suburbController.text = _city;

        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      await _selectGpsResultInDropdowns(
        country: country,
        state: state,
        city: city,
      );

      if (!mounted) return;

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
    if (_selectedCountryItem == null ||
        _selectedCountry.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Vui lòng chọn quốc gia',
              'Please select a country',
            ),
          ),
        ),
      );
      return;
    }

    final isAustralia = _isAustralia;

    if (_availableStates.isNotEmpty &&
        _selectedStateItem == null &&
        !(_latitude != null &&
            _longitude != null &&
            _selectedState.trim().isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Vui lòng chọn Bang/Tỉnh',
              'Please select a State/Province',
            ),
          ),
        ),
      );
      return;
    }

    if (isAustralia) {
      final suburb = _suburbController.text.trim();

      if (suburb.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              _tr(
                'Vui lòng nhập khu vực hoặc suburb',
                'Please enter your suburb',
              ),
            ),
          ),
        );
        return;
      }

      _city = suburb;
    } else if (_availableStates.isNotEmpty &&
        _availableCities.isNotEmpty &&
        _selectedCityItem == null &&
        !(_latitude != null &&
            _longitude != null &&
            _city.trim().isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _tr(
              'Vui lòng chọn Thành phố',
              'Please select a City',
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

      final country = _selectedCountryItem!.name.trim();
      final countryCode =
          _selectedCountryItem!.isoCode.trim().toUpperCase();

      String state;

      if (_availableStates.isEmpty) {
        state = country;
      } else if (isAustralia) {
        final rawState = _selectedStateItem?.name ??
            _selectedState;

        state = _normalizeAustralianState(rawState);
      } else {
        state = (
          _selectedStateItem?.name ??
          _selectedState
        )
            .trim();

        if (state.isEmpty) {
          state = country;
        }
      }

      String city;

      if (isAustralia) {
        city = _suburbController.text.trim();
      } else if (_availableStates.isEmpty) {
        city = _city.trim().isNotEmpty
            ? _city.trim()
            : country;
      } else {
        city = (
          _selectedCityItem?.name ??
          _city
        )
            .trim();
      }

      if (city.isEmpty) {
        city = country;
      }

      final locationText = isAustralia
          ? '$city, $state, $country'
          : _availableStates.isEmpty &&
                  city.toLowerCase() ==
                      country.toLowerCase()
              ? country
              : '$city, $state, $country';

      double? lat = _latitude;
      double? lng = _longitude;

      if (lat == null || lng == null) {
        try {
          final locations =
              await locationFromAddress(locationText);

          if (locations.isNotEmpty) {
            lat = locations.first.latitude;
            lng = locations.first.longitude;
          }
        } catch (e) {
          debugPrint(
            'Unable to detect coordinates: $e',
          );
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'selectedCountry': country,
        'country': country,
        'filterCountry': country,
        'countryCode': countryCode,

        'selectedState': state,
        'selectedStateKey': state,
        'selectedStateLower':
            state.toLowerCase(),

        'state': state,
        'stateLiving': state,

        'filterState': state,
        'filterStateKey': state,

        'city': city,
        'cityLower': city.toLowerCase(),

        'suburb': city,
        'suburbLower': city.toLowerCase(),

        'address': locationText,
        'currentLocation': locationText,

        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,

        'locationUpdatedAt':
            FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pop(context, locationText);
    } catch (e) {
      debugPrint(
        'Unable to save current location: $e',
      );

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

  Widget _messageBox(String text) {
    return Container(
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
        text,
        style: const TextStyle(
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildLocationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('Quốc gia', 'Country'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),

        if (_isLoadingCountries)
          const LinearProgressIndicator()
        else
          DropdownButtonFormField<csc.Country>(
            value: _selectedCountryItem,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.public),
              hintText:
                  _tr('Chọn quốc gia', 'Select country'),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: _availableCountries.map((country) {
              return DropdownMenuItem<csc.Country>(
                value: country,
                child: Text(
                  country.name,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (country) async {
              if (country == null) return;

              setState(() {
                _selectedCountryItem = country;
                _selectedCountry = country.name;

                _selectedStateItem = null;
                _selectedCityItem = null;

                _selectedState = '';
                _city = '';

                _suburbController.clear();

                _latitude = null;
                _longitude = null;
              });

              await _loadStatesForCountry(country);
            },
          ),

        const SizedBox(height: 18),

        Text(
          _isAustralia
              ? _tr('Bang', 'State')
              : _tr(
                  'Bang hoặc tỉnh',
                  'State or Province',
                ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),

        if (_isLoadingStates)
          const LinearProgressIndicator()
        else if (_selectedCountryItem == null)
          _messageBox(
            _tr(
              'Vui lòng chọn quốc gia trước',
              'Please select a country first',
            ),
          )
        else if (_availableStates.isEmpty)
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
                    _selectedCountry,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<csc.State>(
            value: _selectedStateItem,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon:
                  const Icon(Icons.map_outlined),
              hintText: _isAustralia
                  ? _tr('Chọn bang', 'Select state')
                  : _tr(
                      'Chọn bang hoặc tỉnh',
                      'Select state or province',
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
              ),
            ),
            items: _availableStates.map((state) {
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

              final stateToSave = _isAustralia
                  ? _normalizeAustralianState(
                      state.name,
                    )
                  : state.name.trim();

              setState(() {
                _selectedStateItem = state;
                _selectedState = stateToSave;

                _selectedCityItem = null;
                _availableCities = [];

                _city = '';
                _suburbController.clear();

                _latitude = null;
                _longitude = null;
              });

              if (!_isAustralia) {
                await _loadCitiesForState(state);
              }
            },
          ),

        const SizedBox(height: 18),

        Text(
          _isAustralia
              ? _tr('Khu vực / Suburb', 'Suburb')
              : _tr('Thành phố', 'City'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),

        if (_isAustralia)
          TextField(
            controller: _suburbController,
            decoration: InputDecoration(
              prefixIcon:
                  const Icon(Icons.location_city),
              hintText: _tr(
                'Ví dụ: Cabramatta',
                'Example: Cabramatta',
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
              ),
            ),
            onChanged: (value) {
              _city = value.trim();
              _latitude = null;
              _longitude = null;
            },
          )
        else if (_isLoadingCities)
          const LinearProgressIndicator()
        else if (_selectedCountryItem == null)
          _messageBox(
            _tr(
              'Vui lòng chọn quốc gia trước',
              'Please select a country first',
            ),
          )
        else if (_availableStates.isEmpty)
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
                    _city.trim().isNotEmpty
                        ? _city
                        : _selectedCountry,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_selectedStateItem == null)
          _messageBox(
            _tr(
              'Vui lòng chọn bang hoặc tỉnh trước',
              'Please select a state or province first',
            ),
          )
        else if (_availableCities.isEmpty)
          _messageBox(
            _tr(
              'Không có danh sách thành phố cho bang hoặc tỉnh này. Bạn có thể dùng vị trí hiện tại.',
              'No city list is available for this state or province. You can use your current location.',
            ),
          )
        else
          DropdownButtonFormField<csc.City>(
            value: _selectedCityItem,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon:
                  const Icon(Icons.location_city),
              hintText:
                  _tr('Chọn thành phố', 'Select city'),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
              ),
            ),
            items: _availableCities.map((city) {
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
                _selectedCityItem = city;
                _city = city.name.trim();

                _latitude = null;
                _longitude = null;
              });
            },
          ),
      ],
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
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFFFD5E6),
              ),
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

          _buildLocationFields(),

          const SizedBox(height: 20),

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
              onPressed: _isLoadingLocation
                  ? null
                  : _getCurrentLocation,
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
                    ? _tr(
                        'Đang lấy vị trí...',
                        'Getting location...',
                      )
                    : _tr(
                        'Dùng vị trí hiện tại',
                        'Use current location',
                      ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFCC3D7A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(18),
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
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  @override
  void dispose() {
    _suburbController.dispose();
    super.dispose();
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
            'Sửa vị trí hiện tại',
            'Edit current location',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A2E6E),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context)
                .viewInsets
                .bottom,
          ),
          child: _buildBody(),
        ),
      ),
    );
  }
}

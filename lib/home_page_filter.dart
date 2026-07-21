import 'package:flutter/material.dart';
import 'package:country_state_city/country_state_city.dart' as csc;

class HomePageFilterResult {
  final String? gender;
  final int? minAge;
  final int? maxAge;
  final String? country;
  final String? state;
  final double? distanceKm;

  final String? religion;
  final String? relationshipGoal;
  final String? maritalStatus;
  final String? height;
  final String? residentStatus;
  final String? education;
  final String? smoking;
  final String? drinking;
  final String? haveChildren;
  final String? income;
  final bool photoVerifiedOnly;
  final bool newHereOnly;

  const HomePageFilterResult({
    required this.gender,
    required this.minAge,
    required this.maxAge,
    required this.country,
    required this.state,
    required this.distanceKm,
    required this.religion,
    required this.relationshipGoal,
    required this.maritalStatus,
    required this.height,
    required this.residentStatus,
    required this.education,
    required this.smoking,
    required this.drinking,
    required this.haveChildren,
    required this.income,
    required this.photoVerifiedOnly,
    required this.newHereOnly,
  });
}

class HomePageFilterSheet extends StatefulWidget {
  final bool isVi;
  final bool isVipUser;

  final String? initialGender;
  final int? initialMinAge;
  final int? initialMaxAge;
  final String? initialCountry;
  final String? initialState;
  final String currentUserCountryCode;
  final double? initialDistanceKm;

  final String? initialReligion;
  final String? initialRelationshipGoal;
  final String? initialMaritalStatus;
  final String? initialHeight;
  final String? initialResidentStatus;
  final String? initialEducation;
  final String? initialSmoking;
  final String? initialDrinking;
  final String? initialHaveChildren;
  final String? initialIncome;
  final bool initialPhotoVerifiedOnly;
  final bool initialNewHereOnly;

  final List<String> stateOptions;
  final List<int> ageOptions;
  final List<String> countryOptions;

  final VoidCallback onTapUpgrade;
  final VoidCallback onResetToDefault;

  final String Function(String vi, String en) labelBuilder;
  final String Function(String raw, bool isVi) translateProfileValue;

  const HomePageFilterSheet({
    super.key,
    required this.isVi,
    required this.isVipUser,
    required this.initialGender,
    required this.initialMinAge,
    required this.initialMaxAge,
    required this.initialCountry,
    required this.initialState,
    required this.currentUserCountryCode,
    required this.initialDistanceKm,
    required this.initialReligion,
    required this.initialRelationshipGoal,
    required this.initialMaritalStatus,
    required this.initialHeight,
    required this.initialResidentStatus,
    required this.initialEducation,
    required this.initialSmoking,
    required this.initialDrinking,
    required this.initialHaveChildren,
    required this.initialIncome,
    required this.initialPhotoVerifiedOnly,
    required this.initialNewHereOnly,
    required this.stateOptions,
    required this.ageOptions,
    required this.countryOptions,
    required this.onTapUpgrade,
    required this.onResetToDefault,
    required this.labelBuilder,
    required this.translateProfileValue,
  });

  @override
  State<HomePageFilterSheet> createState() => _HomePageFilterSheetState();
}

class _HomePageFilterSheetState extends State<HomePageFilterSheet> {
  late String? tempGender;
  late int? tempMinAge;
  late int? tempMaxAge;
  late String? tempCountry;
  late String? tempState;
List<csc.Country> availableCountries = [];

bool isLoadingCountries = false;
List<csc.State> availableStates = [];

bool isLoadingStates = false;

late double tempDistanceKm;

  late String? tempReligion;
  late String? tempGoal;
  late String? tempMarital;
  late String? tempHeight;
  late String? tempResident;
  late String? tempEducation;
  late String? tempSmoking;
  late String? tempDrinking;
  late String? tempHaveChildren;
  late String? tempIncome;
  late bool tempPhotoVerifiedOnly;
  late bool tempNewHereOnly;

  bool get isVi => widget.isVi;

  String _label(String vi, String en) => widget.labelBuilder(vi, en);
Future<void> _loadCountries() async {
  setState(() {
    isLoadingCountries = true;
  });

  try {
    final countries = await csc.getAllCountries();

    countries.sort(
      (a, b) => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ),
    );

    if (!mounted) return;

    setState(() {
      availableCountries = countries;
      isLoadingCountries = false;
    });
  } catch (e) {
    debugPrint('Load countries error: $e');

    if (!mounted) return;

    setState(() {
      availableCountries = [];
      isLoadingCountries = false;
    });
  }
}  
Future<void> _loadStatesForCountry(
  String countryCode, {
  bool keepCurrentState = false,
}) async {
  final oldState = tempState;

  setState(() {
    isLoadingStates = true;
    availableStates = [];

    if (!keepCurrentState) {
      tempState = null;
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

      if (keepCurrentState &&
          oldState != null &&
          states.any((state) => state.name == oldState)) {
        tempState = oldState;
      } else if (keepCurrentState) {
        tempState = null;
      }

      isLoadingStates = false;
    });
  } catch (e) {
    debugPrint('Load states error: $e');

    if (!mounted) return;

    setState(() {
      availableStates = [];
      tempState = null;
      isLoadingStates = false;
    });
  }
}

  @override
  void initState() {
    super.initState();

    tempGender = widget.initialGender?.toLowerCase();
    tempMinAge = widget.initialMinAge;
    tempMaxAge = widget.initialMaxAge;
    tempCountry = widget.initialCountry;
    tempState = widget.initialState;

    tempDistanceKm = widget.initialDistanceKm ?? 200;

    tempReligion = widget.initialReligion;
    tempGoal = widget.initialRelationshipGoal;
    tempMarital = widget.initialMaritalStatus;
    tempHeight = widget.initialHeight;
    tempResident = widget.initialResidentStatus;
    tempEducation = widget.initialEducation;
    tempSmoking = widget.initialSmoking;
    tempDrinking = widget.initialDrinking;
    tempHaveChildren = widget.initialHaveChildren;
    tempIncome = widget.initialIncome;
    tempPhotoVerifiedOnly = widget.initialPhotoVerifiedOnly;
    tempNewHereOnly = widget.initialNewHereOnly;
    _loadCountries();
 _loadInitialStates();
  }
Future<void> _loadInitialStates() async {
  if (tempCountry == null || tempCountry!.isEmpty) {
    return;
  }

  final countries = await csc.getAllCountries();

  csc.Country? selectedCountry;

  for (final country in countries) {
    if (country.name == tempCountry) {
      selectedCountry = country;
      break;
    }
  }

  if (selectedCountry != null) {
    await _loadStatesForCountry(
      selectedCountry.isoCode,
      keepCurrentState: true,
    );
  }
}
  void _apply() {
    Navigator.pop(
      context,
      HomePageFilterResult(
        gender: tempGender,
        minAge: tempMinAge,
        maxAge: tempMaxAge,
        country: tempCountry,
        state: tempState,
        height: tempHeight,
        distanceKm: tempDistanceKm,
        religion: widget.isVipUser ? tempReligion : null,
        relationshipGoal: widget.isVipUser ? tempGoal : null,
        maritalStatus: widget.isVipUser ? tempMarital : null,
        residentStatus: widget.isVipUser ? tempResident : null,
        education: widget.isVipUser ? tempEducation : null,
        smoking: widget.isVipUser ? tempSmoking : null,
        drinking: widget.isVipUser ? tempDrinking : null,
        haveChildren: widget.isVipUser ? tempHaveChildren : null,
        income: widget.isVipUser ? tempIncome : null,
        photoVerifiedOnly:
    widget.isVipUser ? tempPhotoVerifiedOnly : false,
newHereOnly:
    widget.isVipUser ? tempNewHereOnly : false,
      ),
    );
  }

  void _resetLocal() {
    widget.onResetToDefault();
    Navigator.pop(context, 'reset_to_default');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _label('Bộ lọc', 'Filters'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 18),

              _sheetTitle(_label('Giới tính', 'Gender')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chipOption(
                    text: _label('Nam', 'Male'),
                    selected: tempGender == 'male',
                    onTap: () => setState(() => tempGender = 'male'),
                  ),
                  _chipOption(
                    text: _label('Nữ', 'Female'),
                    selected: tempGender == 'female',
                    onTap: () => setState(() => tempGender = 'female'),
                  ),
                  _chipOption(
                    text: _label('Khác', 'Other'),
                    selected: tempGender == 'other',
                    onTap: () => setState(() => tempGender = 'other'),
                  ),
                  _chipOption(
                    text: _label('Tất cả', 'Everyone'),
                    selected: tempGender == 'everyone',
                    onTap: () => setState(() => tempGender = 'everyone'),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              _sheetTitle(_label('Độ tuổi', 'Age range')),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: widget.ageOptions.contains(tempMinAge) ? tempMinAge : null,
                      decoration: InputDecoration(
                        labelText: _label('Từ', 'From'),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: widget.ageOptions.map((age) {
                        return DropdownMenuItem<int>(
                          value: age,
                          child: Text(age.toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          tempMinAge = value;
                          if (tempMaxAge != null &&
                              tempMinAge != null &&
                              tempMaxAge! < tempMinAge!) {
                            tempMaxAge = tempMinAge;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: widget.ageOptions.contains(tempMaxAge) ? tempMaxAge : null,
                      decoration: InputDecoration(
                        labelText: _label('Đến', 'To'),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: widget.ageOptions
                          .where((age) => tempMinAge == null || age >= tempMinAge!)
                          .map((age) {
                        return DropdownMenuItem<int>(
                          value: age,
                          child: Text(age.toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => tempMaxAge = value);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              _sheetTitle(_label('Khoảng cách tối đa', 'Max distance')),
             Slider(
  value: tempDistanceKm.clamp(5.0, 200.0),
  min: 5,
  max: 200,
  divisions: 39,
  label: '${tempDistanceKm.round()} km',
  onChanged: (value) {
    setState(() {
      tempDistanceKm = value;
    });
  },
),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${tempDistanceKm.round()} km',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),

              const SizedBox(height: 18),
              _sheetTitle(_label('Khu vực', 'Location')),
             if (isLoadingCountries)
  const LinearProgressIndicator()
else
  DropdownButtonFormField<String>(
    value: availableCountries.any(
      (country) => country.name == tempCountry,
    )
        ? tempCountry
        : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: _label(
        'Quốc gia',
        'Country',
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    items: [
      const DropdownMenuItem<String>(
        value: null,
        child: Text('All Countries'),
      ),
      ...availableCountries.map((country) {
        return DropdownMenuItem<String>(
          value: country.name,
          child: Text(
            country.name,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }),
    ],
    onChanged: (value) async {
      setState(() {
        tempCountry = value;
        tempState = null;
        availableStates = [];
      });

      if (value == null) return;

      final selectedCountry = availableCountries.firstWhere(
        (c) => c.name == value,
      );

      await _loadStatesForCountry(
        selectedCountry.isoCode,
      );
    },
  ),
const SizedBox(height: 16),
if (isLoadingStates)
  const LinearProgressIndicator()
else if (availableStates.isEmpty)
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
      _label(
        'Không có danh sách bang hoặc tỉnh cho quốc gia này',
        'No state or province list is available for this country',
      ),
      style: const TextStyle(
        color: Colors.black54,
      ),
    ),
  )
else
  DropdownButtonFormField<String>(
    value: availableStates.any(
      (state) => state.name == tempState,
    )
        ? tempState
        : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: _label(
        'Bang / Tỉnh',
        'State / Province',
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    items: [
      DropdownMenuItem<String>(
        value: null,
        child: Text(
          _label(
            'Không chọn',
            'No preference',
          ),
        ),
      ),
      ...availableStates.map((state) {
        return DropdownMenuItem<String>(
          value: state.name,
          child: Text(
            state.name,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }),
    ],
    onChanged: (value) {
      setState(() {
        tempState = value;
      });
    },
  ),

              const SizedBox(height: 18),

              if (widget.isVipUser) ...[
                _dropdownBox(
                  title: _label('Tôn giáo', 'Religion'),
                  value: tempReligion,
                  items: const [
                    '',
                    'buddhist',
                    'catholic',
                    'christian',
                    'hindu',
                    'muslim',
                    'jewish',
                    'sikh',
                    'taoist',
                    'no_religion',
                  ],
                  onChanged: (value) {
                    setState(() {
                      tempReligion = value == null || value.isEmpty ? null : value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _dropdownBox(
                  title: _label('Mục tiêu hẹn hò', 'Relationship goal'),
                  value: tempGoal,
                  items: const [
                    '',
                    'serious_relationship',
                    'long_term_partner',
                    'friendship_first',
                    'chat_and_get_to_know',
                  ],
                  onChanged: (value) {
                    setState(() {
                      tempGoal = value == null || value.isEmpty ? null : value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _dropdownBox(
                  title: _label('Tình trạng hôn nhân', 'Marital status'),
                  value: tempMarital,
                  items: const [
                    '',
                    'single',
                    'divorced',
                    'widowed',
                    'separated',
                    'never_married',
                  ],
                  onChanged: (value) {
                    setState(() {
                      tempMarital = value == null || value.isEmpty ? null : value;
                    });
                  },
                ),
                const SizedBox(height: 12),

_dropdownBox(
  title: _label('Chiều cao', 'Height'),
  value: tempHeight,
  items: const [
    '',
    '150-159 cm',
    '160-169 cm',
    '170-179 cm',
    '180+ cm',
  ],
  onChanged: (value) {
    setState(() {
      tempHeight = value == null || value.isEmpty ? null : value;
    });
  },
),
                const SizedBox(height: 12),
                _dropdownBox(
  title: _label('Thu nhập hằng năm', 'Annual Income'),
  value: tempIncome,
  items: const [
    '',
    'under_40k',
    '40_59k',
    '60_79k',
    '80_99k',
    '100_119k',
    '120_149k',
    '150_plus',
    'prefer_not_to_say',
  ],
  onChanged: (value) {
    setState(() {
      tempIncome = value == null || value.isEmpty ? null : value;
    });
  },
),
const SizedBox(height: 12),
                _dropdownBox(
                  title: _label('Tình trạng cư trú', 'Resident status'),
                  value: tempResident,
                  items: const [
                    '',
                    'australian_citizen',
                    'permanent_resident',
                    'temporary_visa',
                    'student_visa',
                    'working_holiday',
                    'other',
                  ],
                  onChanged: (value) {
                    setState(() {
                      tempResident = value == null || value.isEmpty ? null : value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _dropdownBox(
                  title: _label('Bằng cấp', 'Education'),
                  value: tempEducation,
                  items: const [
                    '',
                    'high_school',
                    'trade',
                    'diploma',
                    'bachelor',
                    'postgraduate',
                    'master',
                    'phd',
                    'prefer_not_to_say',
                  ],
                  onChanged: (value) {
                    setState(() {
                      tempEducation = value == null || value.isEmpty ? null : value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _dropdownBox(
                  title: _label('Hút thuốc', 'Smoking'),
                  value: tempSmoking,
                  items: const ['', 'yes', 'no', 'sometimes'],
                  onChanged: (value) {
                    setState(() {
                      tempSmoking = value == null || value.isEmpty ? null : value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _dropdownBox(
                  title: _label('Uống rượu,nhậu', 'Drinking'),
                  value: tempDrinking,
                  items: const ['', 'yes', 'no', 'sometimes'],
                  onChanged: (value) {
                    setState(() {
                      tempDrinking = value == null || value.isEmpty ? null : value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _dropdownBox(
                  title: _label('Có con', 'Have children'),
                  value: tempHaveChildren,
                  items: const ['', 'yes', 'no'],
                  onChanged: (value) {
                    setState(() {
                      tempHaveChildren =
                          value == null || value.isEmpty ? null : value;
                    });
                  },
                ),
                  _switchTile(
  title: _label('Ảnh đã xác minh', 'Photo Verified'),
  value: tempPhotoVerifiedOnly,
  onChanged: (value) {
    setState(() {
      tempPhotoVerifiedOnly = value;
    });
  },
),
const SizedBox(height: 12),
_switchTile(
  title: _label('Mới tham gia', 'New here'),
  value: tempNewHereOnly,
  onChanged: (value) {
    setState(() {
      tempNewHereOnly = value;
    });
  },
),
const SizedBox(height: 12),
              ] else ...[
                _vipLockedTile(_label('Tôn giáo', 'Religion')),
                _vipLockedTile(_label('Mục tiêu hẹn hò', 'Relationship goal')),
                _vipLockedTile(_label('Tình trạng hôn nhân', 'Marital status')),
                _vipLockedTile(_label('Chiều cao', 'Height')),
                _vipLockedTile(_label('Tình trạng cư trú', 'Resident status')),
                _vipLockedTile(_label('Bằng cấp', 'Education')),
                _vipLockedTile(_label('Hút thuốc', 'Smoking')),
                _vipLockedTile(_label('Uống rượu', 'Drinking')),
                _vipLockedTile(_label('Có con', 'Have children')),
                _vipLockedTile(_label('Thu nhập hằng năm', 'Annual Income')),
                 _vipLockedTile(_label('Ảnh đã xác minh', 'Photo Verified')),
                _vipLockedTile(_label('Mới tham gia', 'New here')),
              ],

              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetLocal,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE91E63),
                        side: const BorderSide(color: Color(0xFFE91E63)),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(_label('Đặt lại', 'Reset')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _label('Áp dụng', 'Apply'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vipLockedTile(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title (VIP)',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onTapUpgrade,
            child: Text(_label('Nâng cấp', 'Upgrade')),
          ),
        ],
      ),
    );
  }

  Widget _sheetTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _chipOption({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE91E63) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE91E63)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFE91E63),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
Widget _switchTile({
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      value: value,
      activeColor: const Color(0xFFE91E63),
      onChanged: onChanged,
    ),
  );
}
  Widget _dropdownBox({
    required String title,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : '',
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: title,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item.isEmpty
                ? _label('Không chọn', 'No preference')
                : widget.translateProfileValue(item, isVi),
          ),
        );
      }).toList(),
    );
  }
}
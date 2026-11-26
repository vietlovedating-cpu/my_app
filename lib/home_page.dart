import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'mini_game_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'group_page.dart';
import 'home_page_filter.dart';
import 'my_profile_page.dart';
import 'prompt_data.dart';
import 'upgrade_vip_page.dart';
import 'match_page.dart';
import 'message_page.dart';
import 'messages_list_page.dart';
import 'contact_privacy_helper.dart';
import 'buy_flower_page.dart';
import 'home_tutorial_page.dart';
import 'more_about_me_page.dart';


class HomePage extends StatefulWidget {
  final String languageCode;

  const HomePage({
    super.key,
    required this.languageCode,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  StreamSubscription<User?>? _authSub;
  Timer? _onlineTimer;
   DateTime? _lastBackPressedAt;

  bool _isProcessingAction = false;
  bool _lastSwipeSaved = false;
  int _selectedBottomIndex = 3;
Set<String> _myContactPhones = {};
Set<String> _myContactEmails = {};
bool _contactsLoaded = false;
  Map<String, dynamic>? currentUserData;
  String? _lastUid;
  final AudioPlayer _voicePromptPlayer = AudioPlayer();

bool _isVoicePromptPlaying = false;
bool _isVoicePromptLoading = false;
String? _playingVoicePromptUrl;
Future<List<Map<String, dynamic>>>? _profilesFuture;
bool _dailyDiscoverLimitReached = false;
List<Map<String, dynamic>> _discoverProfiles = [];
DocumentSnapshot<Map<String, dynamic>>? _lastDiscoverDocument;
final Map<String, Future<bool>> _discoverProfileChecks = {};
bool _isLoadingMoreDiscoverProfiles = false;
bool _hasMoreDiscoverProfiles = true;
bool _hasCheckedHomeTutorial = false;
StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    _homeTutorialSettingSub;

bool _isOpeningHomeTutorial = false;

 String? selectedGenderFilter;
int? selectedMinAgeFilter;
int? selectedMaxAgeFilter;
String? selectedCountryFilter;
String? selectedStateFilter;
double? selectedDistanceKm;

  String? selectedReligionFilter;
  String? selectedRelationshipGoalFilter;
  String? selectedMaritalStatusFilter;
  String? selectedHeightFilter;
  String? selectedResidentStatusFilter;
  String? selectedEducationFilter;
  String? selectedSmokingFilter;
  String? selectedDrinkingFilter;
  String? selectedHaveChildrenFilter;
  String? selectedIncomeFilter;

  bool selectedPhotoVerifiedOnly = false;
  bool selectedNewHereOnly = false;

  bool get isVi => widget.languageCode == 'vi';
  bool get isVipUser => _hasVipAccess(currentUserData);
  // ===========================================================
// DAILY DISCOVER LIMIT
// ===========================================================

int get _dailyDiscoverLimit => isVipUser ? 26 : 12;

DateTime _discoverResetTime() {
  final now = DateTime.now();

  final morningReset = DateTime(
    now.year,
    now.month,
    now.day,
    9,
  );

  final eveningReset = DateTime(
    now.year,
    now.month,
    now.day,
    18,
  );

  // 09:00 -> 17:59
  if (now.isAfter(morningReset) && now.isBefore(eveningReset)) {
    return morningReset;
  }

  // Sau 18:00
  if (!now.isBefore(eveningReset)) {
    return eveningReset;
  }

  // 00:00 -> 08:59
  return eveningReset.subtract(const Duration(days: 1));
}
int _dailyDiscoverShuffleSeed() {
  final uid = currentUser?.uid ?? '';
  final resetTime = _discoverResetTime();

  final seedText =
      '$uid-${resetTime.year}-${resetTime.month}-${resetTime.day}-${resetTime.hour}';

  int seed = 0;

  for (final codeUnit in seedText.codeUnits) {
    seed = ((seed * 31) + codeUnit) & 0x7fffffff;
  }

  return seed;
}

Future<int> _todayDiscoverActionCount() async {
  final user = currentUser;
  if (user == null) return 0;

  // Mặc định tính từ giờ reset 9:00 hoặc 18:00.
  DateTime countFrom = _discoverResetTime();

  // Nếu là VIP, kiểm tra thời điểm nâng cấp VIP lần đầu.
  // Không tính các lượt Free đã dùng trước khi nâng cấp.
  if (isVipUser) {
    final firstUpgradeAt = currentUserData?['vipFirstUpgradeAt'];

    if (firstUpgradeAt is Timestamp) {
      final upgradeTime = firstUpgradeAt.toDate();

      if (upgradeTime.isAfter(countFrom)) {
        countFrom = upgradeTime;
      }
    }
  }

  final snapshot = await FirebaseFirestore.instance
      .collection('swipes')
      .where('fromUserId', isEqualTo: user.uid)
      .get();

  int count = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();

    final action =
        (data['action'] ?? '').toString().trim().toLowerCase();

    if (action != 'pass' &&
        action != 'like' &&
        action != 'flower') {
      continue;
    }

    final createdAt = data['createdAt'];

    if (createdAt is! Timestamp) continue;

    final actionTime = createdAt.toDate();

    if (!actionTime.isBefore(countFrom)) {
      count++;
    }
  }

  return count;
}


Future<int> _remainingDiscoverToday() async {
  final used = await _todayDiscoverActionCount();

  final remaining = _dailyDiscoverLimit - used;

  return remaining < 0 ? 0 : remaining;
}

  final List<String> stateOptions = const [
  '',
  'New South Wales (NSW)',
  'Victoria (VIC)',
  'Queensland (QLD)',
  'South Australia (SA)',
  'Western Australia (WA)',
  'Tasmania (TAS)',
  'Australian Capital Territory (ACT)',
  'Northern Territory (NT)',
  'Other',
];
final List<String> countryOptions = const [
  'Australia',
  'Vietnam',
  'New Zealand',
  'United States',
  'Canada',
  'United Kingdom',
  'Singapore',
  'Japan',
  'South Korea',
  'China',
  'India',
  'Thailand',
  'Malaysia',
  'Philippines',
  'Indonesia',
];

  final List<int> ageOptions = List.generate(63, (index) => index + 18);

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _setOnline(true);

_onlineTimer = Timer.periodic(
  const Duration(minutes: 5),
  (_) {
    _setOnline(true);
  },
);
_voicePromptPlayer.onPlayerComplete.listen((_) {
  if (!mounted) return;

  setState(() {
    _isVoicePromptLoading = false;
    _isVoicePromptPlaying = false;
    _playingVoicePromptUrl = null;
  });
});

  _handleAuthChanged(FirebaseAuth.instance.currentUser);
  Future.delayed(const Duration(seconds: 1), () {
  if (mounted) {
    _loadMyContactsForPrivacy();
  }
});
  _updateUserLocation();

  _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
  _handleAuthChanged(user);

  if (user != null) {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _updateUserLocation();
      }
    });
  }
});
WidgetsBinding.instance.addPostFrameCallback((_) async {
  await _checkAndShowHomeTutorial();

  if (!mounted) return;

  _listenForHomeTutorialRequest();
});
}

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.languageCode != widget.languageCode) {
      if (mounted) setState(() {});
    }
  }

 @override
void dispose() {
  _onlineTimer?.cancel();
  _setOnline(false);
  WidgetsBinding.instance.removeObserver(this);
 _authSub?.cancel();
 _homeTutorialSettingSub?.cancel();
_voicePromptPlayer.dispose();
super.dispose();
}
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _setOnline(true);

    _onlineTimer?.cancel();
    _onlineTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        _setOnline(true);
      },
    );

    Future<void>(() async {
      await _reloadCurrentUserData();

      if (!mounted) return;

      setState(() {
        _startDiscoverProfilesLoad();
      });
    });
  } else if (state == AppLifecycleState.inactive ||
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached) {
    _onlineTimer?.cancel();
    _setOnline(false);
  }
}
  Future<void> _handleAuthChanged(User? user) async {
    final uid = user?.uid;

    if (_lastUid == uid) return;
    _lastUid = uid;

    if (!mounted) return;

    setState(() {
      currentUserData = null;

      _isProcessingAction = false;
      _selectedBottomIndex = 3;

      selectedGenderFilter = null;
      selectedMinAgeFilter = null;
      selectedMaxAgeFilter = null;
      selectedStateFilter = null;
      selectedCountryFilter = null;

      selectedReligionFilter = null;
      selectedRelationshipGoalFilter = null;
      selectedMaritalStatusFilter = null;
      selectedHeightFilter = null;
      selectedResidentStatusFilter = null;
      selectedEducationFilter = null;
      selectedSmokingFilter = null;
      selectedDrinkingFilter = null;
      selectedHaveChildrenFilter = null;
      selectedIncomeFilter = null;


      selectedPhotoVerifiedOnly = false;
      selectedNewHereOnly = false;
    });

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;
    if (_lastUid != user.uid) return;

    final data = doc.data() ?? {};
    final hasSavedGenderFilter =
    data.containsKey('genderPreference');

final newGenderFilter = hasSavedGenderFilter
    ? _normalizeGenderPreference(
        data['genderPreference'],
      )
    : _normalizeGenderPreference(
        data['datingPreference'],
      );

    setState(() {
      currentUserData = data;

     selectedGenderFilter = newGenderFilter;

      selectedMinAgeFilter = _parseInt(
        data['minAgePreference'] ?? data['preferredMinAge'],
      );
      selectedMaxAgeFilter = _parseInt(
        data['maxAgePreference'] ?? data['preferredMaxAge'],
      );

  final hasSavedCountryFilter =
    data.containsKey('filterCountry');

if (hasSavedCountryFilter) {
  // Đã từng Apply filter.
  // Chỉ đọc filterCountry.
  selectedCountryFilter =
      (data['filterCountry'] ?? '')
          .toString()
          .trim();
} else {
  // User cũ chưa từng lưu filter.
  selectedCountryFilter = _firstNonEmptyValue([
    data['selectedCountry'],
    data['country'],
  ]);
}

if (selectedCountryFilter == null ||
    selectedCountryFilter!.trim().isEmpty) {
  selectedCountryFilter = null;
}

if (hasSavedCountryFilter) {
  // User đã từng Apply filter.
  // Chỉ đọc state filter, không lấy state nơi đang sống.
  selectedStateFilter = _firstNonEmptyValue([
    data['filterState'],
    data['filterStateKey'],
  ]);
} else {
  // Hỗ trợ dữ liệu cũ.
  selectedStateFilter = _firstNonEmptyValue([
    data['selectedStateKey'],
    data['selectedState'],
    data['stateLiving'],
    data['state'],
  ]);
}

if (selectedStateFilter == null ||
    selectedStateFilter!.trim().isEmpty) {
  selectedStateFilter = null;
}

selectedDistanceKm =
    (data['maxDistanceKm'] as num?)?.toDouble();


      if (selectedMinAgeFilter == 0) selectedMinAgeFilter = null;
      if (selectedMaxAgeFilter == 0) selectedMaxAgeFilter = null;
      selectedReligionFilter =
    (data['filterReligion'] ?? '').toString().trim();
if (selectedReligionFilter!.isEmpty) {
  selectedReligionFilter = null;
}

selectedRelationshipGoalFilter =
    (data['filterRelationshipGoal'] ?? '').toString().trim();
if (selectedRelationshipGoalFilter!.isEmpty) {
  selectedRelationshipGoalFilter = null;
}

selectedMaritalStatusFilter =
    (data['filterMaritalStatus'] ?? '').toString().trim();
if (selectedMaritalStatusFilter!.isEmpty) {
  selectedMaritalStatusFilter = null;
}

selectedHeightFilter =
    (data['filterHeight'] ?? '').toString().trim();
if (selectedHeightFilter!.isEmpty) {
  selectedHeightFilter = null;
}

selectedResidentStatusFilter =
    (data['filterResidentStatus'] ?? '').toString().trim();
if (selectedResidentStatusFilter!.isEmpty) {
  selectedResidentStatusFilter = null;
}

selectedEducationFilter =
    (data['filterEducation'] ?? '').toString().trim();
if (selectedEducationFilter!.isEmpty) {
  selectedEducationFilter = null;
}

selectedSmokingFilter =
    (data['filterSmoking'] ?? '').toString().trim();
if (selectedSmokingFilter!.isEmpty) {
  selectedSmokingFilter = null;
}

selectedDrinkingFilter =
    (data['filterDrinking'] ?? '').toString().trim();
if (selectedDrinkingFilter!.isEmpty) {
  selectedDrinkingFilter = null;
}

selectedHaveChildrenFilter =
    (data['filterHaveChildren'] ?? '').toString().trim();
if (selectedHaveChildrenFilter!.isEmpty) {
  selectedHaveChildrenFilter = null;
}

selectedIncomeFilter =
    (data['filterIncome'] ?? '').toString().trim();
if (selectedIncomeFilter!.isEmpty) {
  selectedIncomeFilter = null;
}

selectedPhotoVerifiedOnly =
    data['filterPhotoVerifiedOnly'] == true;

selectedNewHereOnly =
    data['filterNewHereOnly'] == true;

      _startDiscoverProfilesLoad();
    });
  }

  Future<void> _reloadCurrentUserData() async {
  final user = currentUser;
  if (user == null) return;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  if (!mounted) return;

  final data = doc.data() ?? {};
  final hasSavedGenderFilter =
    data.containsKey('genderPreference');

final newGenderFilter = hasSavedGenderFilter
    ? _normalizeGenderPreference(
        data['genderPreference'],
      )
    : _normalizeGenderPreference(
        data['datingPreference'],
      );
final hasSavedCountryFilter =
    data.containsKey('filterCountry');

final newFilterCountry = hasSavedCountryFilter
    ? (data['filterCountry'] ?? '')
        .toString()
        .trim()
    : _firstNonEmptyValue([
        data['selectedCountry'],
        data['country'],
      ]);

final newFilterState = hasSavedCountryFilter
    ? _firstNonEmptyValue([
        data['filterState'],
        data['filterStateKey'],
      ])
    : _firstNonEmptyValue([
        data['selectedStateKey'],
        data['selectedState'],
        data['stateLiving'],
        data['state'],
      ]);
      final newReligionFilter =
    (data['filterReligion'] ?? '').toString().trim();

final newRelationshipGoalFilter =
    (data['filterRelationshipGoal'] ?? '').toString().trim();

final newMaritalStatusFilter =
    (data['filterMaritalStatus'] ?? '').toString().trim();

final newHeightFilter =
    (data['filterHeight'] ?? '').toString().trim();

final newResidentStatusFilter =
    (data['filterResidentStatus'] ?? '').toString().trim();

final newEducationFilter =
    (data['filterEducation'] ?? '').toString().trim();

final newSmokingFilter =
    (data['filterSmoking'] ?? '').toString().trim();

final newDrinkingFilter =
    (data['filterDrinking'] ?? '').toString().trim();

final newHaveChildrenFilter =
    (data['filterHaveChildren'] ?? '').toString().trim();

final newIncomeFilter =
    (data['filterIncome'] ?? '').toString().trim();

final newPhotoVerifiedOnly =
    data['filterPhotoVerifiedOnly'] == true;

final newNewHereOnly =
    data['filterNewHereOnly'] == true;

  setState(() {
    currentUserData = data;

    selectedGenderFilter = newGenderFilter;
    

selectedCountryFilter =
    newFilterCountry.isEmpty ? null : newFilterCountry;

selectedStateFilter =
    newFilterState.isEmpty ? null : newFilterState;
    selectedReligionFilter =
    newReligionFilter.isEmpty ? null : newReligionFilter;

selectedRelationshipGoalFilter =
    newRelationshipGoalFilter.isEmpty
        ? null
        : newRelationshipGoalFilter;

selectedMaritalStatusFilter =
    newMaritalStatusFilter.isEmpty
        ? null
        : newMaritalStatusFilter;

selectedHeightFilter =
    newHeightFilter.isEmpty ? null : newHeightFilter;

selectedResidentStatusFilter =
    newResidentStatusFilter.isEmpty
        ? null
        : newResidentStatusFilter;

selectedEducationFilter =
    newEducationFilter.isEmpty ? null : newEducationFilter;

selectedSmokingFilter =
    newSmokingFilter.isEmpty ? null : newSmokingFilter;

selectedDrinkingFilter =
    newDrinkingFilter.isEmpty ? null : newDrinkingFilter;

selectedHaveChildrenFilter =
    newHaveChildrenFilter.isEmpty
        ? null
        : newHaveChildrenFilter;

selectedIncomeFilter =
    newIncomeFilter.isEmpty ? null : newIncomeFilter;

selectedPhotoVerifiedOnly = newPhotoVerifiedOnly;
selectedNewHereOnly = newNewHereOnly;

    selectedDistanceKm =
        (data['maxDistanceKm'] as num?)?.toDouble();
  });
}
Future<void> _checkAndShowHomeTutorial() async {
  if (_hasCheckedHomeTutorial) return;

  _hasCheckedHomeTutorial = true;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final hasSeenHomeTutorial =
        userDoc.data()?['hasSeenHomeTutorial'] == true;

    if (hasSeenHomeTutorial || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeTutorialPage(
          languageCode: widget.languageCode,
        ),
      ),
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'hasSeenHomeTutorial': true,
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('Home tutorial error: $e');
  }
}
  Future<void> _setOnline(bool isOnline) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid);

final userSnap = await userRef.get();

if (!userSnap.exists) {
  return;
}

await userRef.update({
  'isOnline': isOnline,
  'lastSeen': FieldValue.serverTimestamp(),
});
  } catch (e) {
    debugPrint('Online status error: $e');
  }
}
  Future<void> _updateUserLocation() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'lat': position.latitude,
      'lng': position.longitude,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    setState(() {
      currentUserData = {
        ...(currentUserData ?? {}),
        'lat': position.latitude,
        'lng': position.longitude,
      };
    });
  } catch (e) {
    debugPrint('Location error: $e');
  }
}
void _listenForHomeTutorialRequest() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  _homeTutorialSettingSub?.cancel();

  _homeTutorialSettingSub = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .listen((snapshot) {
    final hasSeenHomeTutorial =
        snapshot.data()?['hasSeenHomeTutorial'] == true;

    // false nghĩa là user vừa bật xem lại hướng dẫn.
    if (!hasSeenHomeTutorial) {
      _showHomeTutorialWhenDiscoverIsVisible();
    }
  });
}

Future<void> _showHomeTutorialWhenDiscoverIsVisible() async {
  if (_isOpeningHomeTutorial) return;

  _isOpeningHomeTutorial = true;

  try {
    // Khi còn đang ở Settings thì chờ.
    // Vừa quay lại Discover sẽ mở Tutorial ngay.
    while (mounted) {
      final route = ModalRoute.of(context);

      if (route?.isCurrent == true) {
        _hasCheckedHomeTutorial = false;

        await _checkAndShowHomeTutorial();
        break;
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 200),
      );
    }
  } finally {
    _isOpeningHomeTutorial = false;
  }
}
  Future<void> _trackProfileView(Map<String, dynamic> targetProfile) async {
  final user = currentUser;
  if (user == null) return;

  final currentUid = user.uid;
  final targetUid =
      (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();

  if (targetUid.isEmpty || targetUid == currentUid) return;

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('viewedBy')
        .doc(currentUid)
        .set({
      'uid': currentUid,
      'firstName': (currentUserData?['firstName'] ?? '').toString().trim(),
      'age': currentUserData?['age'],
      'photoUrl': (currentUserData?['mainPhotoUrl'] ?? '').toString().trim(),
      'mainPhotoUrl': (currentUserData?['mainPhotoUrl'] ?? '').toString().trim(),
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (_) {
    // giữ im lặng để không ảnh hưởng UX
  }
}
Future<void> _loadMyContactsForPrivacy() async {
  try {
    final phones = await ContactPrivacyHelper.loadNormalizedContactPhones();
    final emails = await ContactPrivacyHelper.loadNormalizedContactEmails();

    if (!mounted) return;

    setState(() {
      _myContactPhones = phones;
      _myContactEmails = emails;
      _contactsLoaded = true;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _contactsLoaded = true;
    });
  }
}
bool _shouldHideUserBecauseInMyContacts(Map<String, dynamic> profile) {
  final hideFromContacts = profile['hideFromContacts'] == true;
  if (!hideFromContacts) return false;

  final rawPhone = (profile['phoneNumber'] ?? '').toString().trim();
  final rawEmail = (profile['email'] ?? '').toString().trim().toLowerCase();

  final normalizedPhone = ContactPrivacyHelper.normalizePhone(rawPhone);

  final phoneMatched =
      normalizedPhone.isNotEmpty && _myContactPhones.contains(normalizedPhone);

  final emailMatched =
      rawEmail.isNotEmpty && _myContactEmails.contains(rawEmail);

  return phoneMatched || emailMatched;
}
Future<Map<String, Map<String, dynamic>>> _loadLikedMeData() async {
  final user = currentUser;
  if (user == null) return {};

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('likedBy')
      .get();

  final result = <String, Map<String, dynamic>>{};

  for (final doc in snapshot.docs) {
    final uid = doc.id.toString().trim();

    if (uid.isEmpty) continue;

    result[uid] = {
      'fromUserId': uid,
      ...doc.data(),
    };
  }

  return result;
}
DateTime _nextDiscoverResetTime() {
  final now = DateTime.now();

  final morningReset = DateTime(
    now.year,
    now.month,
    now.day,
    9,
  );

  final eveningReset = DateTime(
    now.year,
    now.month,
    now.day,
    18,
  );

  if (now.isBefore(morningReset)) {
    return morningReset;
  }

  if (now.isBefore(eveningReset)) {
    return eveningReset;
  }

  return morningReset.add(const Duration(days: 1));
}

String _formatDiscoverCountdown(Duration duration) {
  if (duration.isNegative) {
    duration = Duration.zero;
  }

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  return '${twoDigits(hours)}:'
      '${twoDigits(minutes)}:'
      '${twoDigits(seconds)}';
}

Widget _buildDailyDiscoverCountdown() {
  return StreamBuilder<int>(
    stream: Stream<int>.periodic(
      const Duration(seconds: 1),
      (value) => value,
    ),
    builder: (context, snapshot) {
      final remaining =
          _nextDiscoverResetTime().difference(DateTime.now());

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDiscoverCountdown(remaining),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0xFFCC3D7A),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _label(
              'Thời gian còn lại đến lượt hồ sơ mới',
              'Time remaining until new profiles',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 18),

          if (!isVipUser) ...[
            Text(
              _label(
                'Nâng cấp VIP để xem nhiều hồ sơ hơn và khám phá thêm nhiều người phù hợp với bạn!',
                'Upgrade to VIP to view more profiles and discover more people who may be right for you!',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFCC3D7A),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedBottomIndex = 4;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC3D7A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
              ),
              child: Text(
                _label('Nâng cấp VIP ngay', 'Upgrade to VIP'),
              ),
            ),
          ],
        ],
      );
    },
  );
}

 Future<List<Map<String, dynamic>>> _loadProfiles({
  DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
}) async {
  final user = currentUser;
  if (user == null) return [];

  final currentUid = user.uid;
  Query<Map<String, dynamic>> usersQuery =
    FirebaseFirestore.instance
        .collection('users')
        .where('profileCompleted', isEqualTo: true)
        .orderBy(FieldPath.documentId)
        .limit(100);

if (startAfterDocument != null) {
  usersQuery = usersQuery.startAfterDocument(startAfterDocument);
}

 final results = await Future.wait<dynamic>([
  _loadLikedMeData(),

usersQuery.get(),

  FirebaseFirestore.instance
      .collection('swipes')
      .where('fromUserId', isEqualTo: currentUid)
      .get(),

  FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('hidden_users')
      .get(),

  FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('blocked_users')
      .get(),
   FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('guessHiddenUsers')
      .get(),    
]);

final likedMeData =
    results[0] as Map<String, Map<String, dynamic>>;

final usersSnapshot =
    results[1] as QuerySnapshot<Map<String, dynamic>>;
    if (usersSnapshot.docs.isNotEmpty) {
  _lastDiscoverDocument = usersSnapshot.docs.last;
}

_hasMoreDiscoverProfiles = usersSnapshot.docs.length == 100;

final swipesSnapshot =
    results[2] as QuerySnapshot<Map<String, dynamic>>;

final hiddenSnapshot =
    results[3] as QuerySnapshot<Map<String, dynamic>>;

final blockedSnapshot =
    results[4] as QuerySnapshot<Map<String, dynamic>>;
final guessHiddenSnapshot =
    results[5] as QuerySnapshot<Map<String, dynamic>>;    

  final swipedUserIds = swipesSnapshot.docs
      .map((doc) => (doc.data()['toUserId'] ?? '').toString().trim())
      .where((id) => id.isNotEmpty)
      .toSet();

  final hiddenUserIds = hiddenSnapshot.docs
      .map((doc) => doc.id.toString().trim())
      .where((id) => id.isNotEmpty)
      .toSet();

  final blockedUserIds = blockedSnapshot.docs
      .map((doc) => doc.id.toString().trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  final guessHiddenUserIds = <String>{};
final now = DateTime.now();

for (final doc in guessHiddenSnapshot.docs) {
  final data = doc.data();
  final hiddenUntil = data['hiddenUntil'];

  if (hiddenUntil is Timestamp &&
      hiddenUntil.toDate().isAfter(now)) {
    guessHiddenUserIds.add(
      doc.id.toString().trim(),
    );
  }
}    

  final profiles = <Map<String, dynamic>>[];

  for (final doc in usersSnapshot.docs) {
    final data = doc.data();
    final uid = (data['uid'] ?? doc.id).toString().trim();
    

    if (uid.isEmpty) continue;
if (uid == currentUid) continue;
if (swipedUserIds.contains(uid)) continue;
if (hiddenUserIds.contains(uid)) continue;
if (blockedUserIds.contains(uid)) continue;
final mainPhotoUrl = (data['mainPhotoUrl'] ?? '').toString().trim();

if (mainPhotoUrl.isEmpty) {
  continue;
}

if (data['profileCompleted'] != true) {
  print('LOAI VI profileCompleted FALSE: $uid');
  continue;
}

    // user tự tắt hồ sơ
    if (data['showMyProfile'] == false) continue;

    // user bị ẩn khỏi discover
    if (data['showOnDiscover'] == false) continue;

    // tương thích cả field cũ lẫn field mới
    if (data['accountPaused'] == true) continue;
    if (data['isPaused'] == true) continue;
    if (data['isDeleted'] == true) continue;

    final profile = {
  'docId': doc.id,
  ...data,

  // Dữ liệu lượt Like mà người này đã gửi cho mình.
  if (likedMeData.containsKey(uid))
    'incomingLike': likedMeData[uid],
};

    // ẩn nếu người này có trong danh bạ của mình
    if (_shouldHideUserBecauseInMyContacts(profile)) continue;

    if (!_matchesFilters(profile)) continue;

    profiles.add(profile);
  }

// ===========================================================
// DISCOVER ORDER
// ===========================================================

final boostedProfiles = <Map<String, dynamic>>[];
final onlineProfiles = <Map<String, dynamic>>[];
final activeDay1Profiles = <Map<String, dynamic>>[];
final activeDay2Profiles = <Map<String, dynamic>>[];
final activeDay3Profiles = <Map<String, dynamic>>[];
final normalProfiles = <Map<String, dynamic>>[];

final random = Random(_dailyDiscoverShuffleSeed());
void sortBySoftDistance(
  List<Map<String, dynamic>> list,
) {
  final myLat =
      (currentUserData?['lat'] as num?)?.toDouble();
  final myLng =
      (currentUserData?['lng'] as num?)?.toDouble();

  final preferredDistance = selectedDistanceKm;

  // Không có vị trí hoặc không chọn distance:
  // giữ nguyên cách random cũ.
  if (myLat == null ||
      myLng == null ||
      preferredDistance == null ||
      preferredDistance <= 0) {
    list.shuffle(random);
    return;
  }

  double distanceOf(Map<String, dynamic> profile) {
    final lat = (profile['lat'] as num?)?.toDouble();
    final lng = (profile['lng'] as num?)?.toDouble();

    // Profile thiếu tọa độ để xuống cuối,
    // nhưng không bị loại khỏi Country/State/VIP filter.
    if (lat == null || lng == null) {
      return double.infinity;
    }

    return _calculateDistanceKm(
      myLat,
      myLng,
      lat,
      lng,
    );
  }

  list.sort((a, b) {
    final distanceA = distanceOf(a);
    final distanceB = distanceOf(b);

    final aInside =
        distanceA <= preferredDistance;
    final bInside =
        distanceB <= preferredDistance;

    // Người nằm trong khoảng đã chọn hiện trước.
    if (aInside && !bInside) return -1;
    if (!aInside && bInside) return 1;

    // Trong cùng nhóm: gần trước, xa sau.
    return distanceA.compareTo(distanceB);
  });
}

for (final profile in profiles) {
  final boostExpiresAt = profile['boostExpiresAt'];

  final isBoosted =
      boostExpiresAt is Timestamp &&
      boostExpiresAt.toDate().isAfter(DateTime.now());

  if (isBoosted) {
    boostedProfiles.add(profile);
    continue;
  }

  if (_isOnlineRecently(profile)) {
    onlineProfiles.add(profile);
    continue;
  }

  final lastSeen = profile['lastSeen'];

  if (lastSeen is Timestamp) {
    final diff = DateTime.now().difference(lastSeen.toDate());

    if (diff <= const Duration(days: 1)) {
      activeDay1Profiles.add(profile);
      continue;
    }

    if (diff <= const Duration(days: 2)) {
      activeDay2Profiles.add(profile);
      continue;
    }

    if (diff <= const Duration(days: 3)) {
      activeDay3Profiles.add(profile);
      continue;
    }
  }

  normalProfiles.add(profile);
}

sortBySoftDistance(boostedProfiles);
sortBySoftDistance(onlineProfiles);
sortBySoftDistance(activeDay1Profiles);
sortBySoftDistance(activeDay2Profiles);
sortBySoftDistance(activeDay3Profiles);
sortBySoftDistance(normalProfiles);
final mixedProfiles = <Map<String, dynamic>>[];

// ===========================================================
// ROUND-ROBIN DISCOVER
// Boost -> Online -> Recently Active -> Normal
// ===========================================================

void addBatch(
  List<Map<String, dynamic>> source,
  int startIndex,
  int maxCount,
) {
  final remainingSlots =
      _dailyDiscoverLimit - mixedProfiles.length;

  if (remainingSlots <= 0) return;
  if (startIndex >= source.length) return;

  final availableCount = source.length - startIndex;

  final count = min(
    maxCount,
    min(availableCount, remainingSlots),
  );

  mixedProfiles.addAll(
    source.skip(startIndex).take(count),
  );
}

// Boost luôn ưu tiên trước.
addBatch(
  boostedProfiles,
  0,
  boostedProfiles.length,
);

final recentlyActiveProfiles = <Map<String, dynamic>>[
  ...activeDay1Profiles,
  ...activeDay2Profiles,
  ...activeDay3Profiles,
];

int onlineIndex = 0;
int activeIndex = 0;
int normalIndex = 0;

while (mixedProfiles.length < _dailyDiscoverLimit) {
  final before = mixedProfiles.length;

  addBatch(
    onlineProfiles,
    onlineIndex,
    5,
  );
  onlineIndex += 5;

  addBatch(
    recentlyActiveProfiles,
    activeIndex,
    5,
  );
  activeIndex += 5;

  addBatch(
    normalProfiles,
    normalIndex,
    5,
  );
  normalIndex += 5;

  // Không còn người mới để lấy.
  if (mixedProfiles.length == before) {
    break;
  }
}

return mixedProfiles;
}
Future<List<Map<String, dynamic>>> _loadPreviouslyPassedProfiles({
  required int limit,
}) async {
  final user = currentUser;
  if (user == null) return [];

  if (limit <= 0) return [];

  final currentUid = user.uid;
  final passedAgainCutoff =
    DateTime.now().subtract(const Duration(hours: 24));

  final swipesSnapshot = await FirebaseFirestore.instance
      .collection('swipes')
      .where('fromUserId', isEqualTo: currentUid)
      .get();

  // Chỉ lấy những người mà hành động HIỆN TẠI vẫn là Pass.
  // Nếu sau này user đã Like hoặc Flower người đó thì sẽ không lấy lại.
  final passedSwipeData = <String, Map<String, dynamic>>{};

  for (final doc in swipesSnapshot.docs) {
    final data = doc.data();

    final targetUid =
        (data['toUserId'] ?? '').toString().trim();

    final action =
        (data['action'] ?? '').toString().trim().toLowerCase();

    if (targetUid.isEmpty || action != 'pass') {
      continue;
    }

  // Nếu user đã Pass lại người này trong chu kỳ hôm nay,
// không hiện lại lần thứ hai trong cùng ngày.
// Người vừa Pass phải được ẩn ít nhất 24 giờ
// trước khi có thể xuất hiện lại.
final createdAt = data['createdAt'];

if (createdAt is Timestamp) {
  final actionTime = createdAt.toDate();

  if (actionTime.isAfter(passedAgainCutoff)) {
    continue;
  }
}

    passedSwipeData[targetUid] = data;
  }

  if (passedSwipeData.isEmpty) {
    return [];
  }

  final hiddenSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('hidden_users')
      .get();

  final blockedSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('blocked_users')
      .get();

  final hiddenUserIds = hiddenSnapshot.docs
      .map((doc) => doc.id.toString().trim())
      .where((id) => id.isNotEmpty)
      .toSet();

  final blockedUserIds = blockedSnapshot.docs
      .map((doc) => doc.id.toString().trim())
      .where((id) => id.isNotEmpty)
      .toSet();

  final passedProfiles = <Map<String, dynamic>>[];

// Sắp xếp theo thời gian Pass:
// Pass lâu nhất hiện trước, Pass gần nhất hiện sau.
final sortedPassedEntries = passedSwipeData.entries.toList()
  ..sort((a, b) {
    final aCreatedAt = a.value['createdAt'];
    final bCreatedAt = b.value['createdAt'];

    // Dữ liệu không có timestamp sẽ để xuống cuối.
    if (aCreatedAt is! Timestamp && bCreatedAt is! Timestamp) {
      return 0;
    }

    if (aCreatedAt is! Timestamp) {
      return 1;
    }

    if (bCreatedAt is! Timestamp) {
      return -1;
    }

    return aCreatedAt.toDate().compareTo(
          bCreatedAt.toDate(),
        );
  });

// Đọc các user song song thay vì phải đợi từng user một.
final loadedProfiles = await Future.wait(
  sortedPassedEntries.map((entry) async {
    final targetUid = entry.key;

    if (hiddenUserIds.contains(targetUid)) {
      return null;
    }

    if (blockedUserIds.contains(targetUid)) {
      return null;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .get();

    if (!userDoc.exists) {
      return null;
    }

    final data = userDoc.data() ?? {};

    final uid =
        (data['uid'] ?? userDoc.id).toString().trim();

    if (uid.isEmpty || uid == currentUid) {
      return null;
    }

    final mainPhotoUrl =
        (data['mainPhotoUrl'] ?? '').toString().trim();

    if (mainPhotoUrl.isEmpty) return null;
    if (data['profileCompleted'] != true) return null;
    if (data['showMyProfile'] == false) return null;
    if (data['showOnDiscover'] == false) return null;
    if (data['accountPaused'] == true) return null;
    if (data['isPaused'] == true) return null;
    if (data['isDeleted'] == true) return null;

    final profile = <String, dynamic>{
      'docId': userDoc.id,
      ...data,
    };

    // Giữ nguyên filter và contact privacy của HomePage.
    if (_shouldHideUserBecauseInMyContacts(profile)) {
      return null;
    }

    if (!_matchesFilters(profile)) {
      return null;
    }

    return profile;
  }),
);

passedProfiles.addAll(
  loadedProfiles.whereType<Map<String, dynamic>>(),
);

return passedProfiles;
}


// Dùng chung cho mọi lần khởi tạo / tải lại Discover.
Future<List<Map<String, dynamic>>> _startDiscoverProfilesLoad() {
  final future = _loadProfilesWithDailyLimit().then((profiles) {
    _discoverProfiles = List<Map<String, dynamic>>.from(profiles);

    // Hiển thị batch hợp lệ đầu tiên ngay;
    // phần còn thiếu tiếp tục tải nền.
    if (_discoverProfiles.isNotEmpty && _hasMoreDiscoverProfiles) {
      _loadMoreDiscoverProfiles();
    }

    return _discoverProfiles;
  });

  _profilesFuture = future;
  return future;
}

Future<List<Map<String, dynamic>>> _loadProfilesWithDailyLimit() async {
  final remaining = await _remainingDiscoverToday();

  _dailyDiscoverLimitReached = remaining <= 0;

  if (_dailyDiscoverLimitReached) {
    return [];
  }

  // Reset về batch đầu tiên khi khởi tạo hoặc tải lại Discover.
  _lastDiscoverDocument = null;
  _hasMoreDiscoverProfiles = true;

  // Chỉ tải một batch có hồ sơ phù hợp để hiển thị trước.
  // Nếu batch không có hồ sơ phù hợp, tiếp tục sang batch kế tiếp.
  while (_hasMoreDiscoverProfiles) {
    final batch = await _loadProfiles(
      startAfterDocument: _lastDiscoverDocument,
    );

    if (batch.isNotEmpty) {
      return batch.take(remaining).toList();
    }
  }

  // Chỉ dùng hồ sơ đã Pass khi đã hết hồ sơ mới.
  final passedProfiles = await _loadPreviouslyPassedProfiles(
    limit: remaining,
  );

  return passedProfiles.take(remaining).toList();
}



bool _isNewHere(Map<String, dynamic> profile) {
  final createdAt = profile['createdAt'];

  if (createdAt == null) return false;

  DateTime createdDate;

  if (createdAt is Timestamp) {
    createdDate = createdAt.toDate();
  } else if (createdAt is DateTime) {
    createdDate = createdAt;
  } else {
    return false;
  }

  final now = DateTime.now();
  final difference = now.difference(createdDate);

  return !difference.isNegative &&
      difference <= const Duration(days: 14);
}
bool _isOnlineRecently(Map<String, dynamic> profile) {
  final lastSeen = profile['lastSeen'];

  if (lastSeen is! Timestamp) {
    return false;
  }

  final difference = DateTime.now().difference(lastSeen.toDate());

  return !difference.isNegative &&
      difference <= const Duration(minutes: 15);
}

bool _isRecentlyActive(Map<String, dynamic> profile) {
  if (_isOnlineRecently(profile)) {
    return false;
  }

  final lastSeen = profile['lastSeen'];

  if (lastSeen is! Timestamp) {
    return false;
  }

  final difference = DateTime.now().difference(lastSeen.toDate());

  return !difference.isNegative &&
      difference <= const Duration(days: 3);
}

  bool _matchesFilters(Map<String, dynamic> profile) {
    
  final profileGender = _normalizeGenderPreference(profile['gender']);
  final profileAge = _parseInt(profile['age']);
 final profileCountry = _normalizeString(
  _firstNonEmptyValue([
    profile['selectedCountry'],
    profile['country'],
  ]),
);

final profileStateKey = _normalizeStateKey(
  _firstNonEmptyValue([
    profile['selectedStateKey'],
    profile['selectedState'],
    profile['state'],
    profile['stateLiving'],
    profile['livingState'],

    // Hỗ trợ dữ liệu cũ.
    profile['filterStateKey'],
    profile['filterState'],
    profile['stateProvince'],
    profile['province'],
    profile['region'],
  ]),
);


  // FREE FILTERS: gender, age, country, state, distance
  if (selectedGenderFilter != null &&
      selectedGenderFilter!.isNotEmpty &&
      selectedGenderFilter != 'everyone') {
    if (!_genderMatches(profileGender, selectedGenderFilter!)) {
      return false;
    }
  }

  if (selectedMinAgeFilter != null && profileAge < selectedMinAgeFilter!) {
    return false;
  }

  if (selectedMaxAgeFilter != null && profileAge > selectedMaxAgeFilter!) {
    return false;
  }

if (selectedCountryFilter != null &&
    selectedCountryFilter!.trim().isNotEmpty &&
    selectedCountryFilter != 'all_countries') {
  final selectedCountryKey =
      _normalizeString(selectedCountryFilter);

  if (profileCountry != selectedCountryKey) {
    return false;
  }
}


 // ❗ Nếu No preference → KHÔNG lọc state
if (selectedStateFilter == null ||
    selectedStateFilter!.trim().isEmpty ||
    selectedStateFilter == 'no_preference') {
  // skip state filter
} else {
  final selectedKey = _normalizeStateKey(selectedStateFilter!);

  if (profileStateKey != selectedKey) {
    return false;
  }
}
if (selectedDistanceKm != null &&
    selectedDistanceKm! > 0) {
  final myLat =
      (currentUserData?['lat'] as num?)?.toDouble();
  final myLng =
      (currentUserData?['lng'] as num?)?.toDouble();

  final profileLat =
      (profile['lat'] as num?)?.toDouble();
  final profileLng =
      (profile['lng'] as num?)?.toDouble();

  // Nếu thiếu tọa độ thì không kết thúc hàm.
  // Tiếp tục xuống kiểm tra các VIP filter.
  if (myLat != null &&
      myLng != null &&
      profileLat != null &&
      profileLng != null) {
    final distanceKm = _calculateDistanceKm(
      myLat,
      myLng,
      profileLat,
      profileLng,
    );

    // Không return false tại đây.
    // Distance vẫn là filter mềm / ưu tiên gần.
  }
}

  // VIP FILTERS: chỉ VIP mới lọc các mục dưới đây
  if (isVipUser) {
    if (selectedPhotoVerifiedOnly && profile['photoVerified'] != true) {
  return false;
}

if (selectedNewHereOnly && !_isNewHere(profile)) {
  return false;
}
   if (selectedReligionFilter != null &&
    selectedReligionFilter!.trim().isNotEmpty &&
    _normalizeString(profile['religion']) !=
        _normalizeString(selectedReligionFilter)) {
  return false;
}

    final relationshipGoal = _extractRelationshipGoalKey(profile);
    if (selectedRelationshipGoalFilter != null &&
        selectedRelationshipGoalFilter!.isNotEmpty &&
        relationshipGoal != selectedRelationshipGoalFilter) {
      return false;
    }

    if (selectedMaritalStatusFilter != null &&
        selectedMaritalStatusFilter!.isNotEmpty &&
        _normalizeString(profile['maritalStatus']) !=
            selectedMaritalStatusFilter) {
      return false;
    }
    if (selectedHeightFilter != null && selectedHeightFilter!.isNotEmpty) {
  final heightText = (profile['height'] ?? '').toString();
  final heightCm = int.tryParse(heightText.replaceAll(RegExp(r'[^0-9]'), ''));

  if (heightCm == null) {
    return false;
  }

  if (selectedHeightFilter == '150-159 cm' &&
      (heightCm < 150 || heightCm > 159)) {
    return false;
  }

  if (selectedHeightFilter == '160-169 cm' &&
      (heightCm < 160 || heightCm > 169)) {
    return false;
  }

  if (selectedHeightFilter == '170-179 cm' &&
      (heightCm < 170 || heightCm > 179)) {
    return false;
  }

  if (selectedHeightFilter == '180+ cm' && heightCm < 180) {
    return false;
  }
}
if (selectedIncomeFilter != null &&
    selectedIncomeFilter!.isNotEmpty &&
    _normalizeString(
          profile['annualIncome'] ?? profile['income'],
        ) !=
        _normalizeString(selectedIncomeFilter)) {
  return false;
}
    if (selectedResidentStatusFilter != null &&
        selectedResidentStatusFilter!.isNotEmpty &&
        _normalizeString(profile['residentStatus']) !=
            selectedResidentStatusFilter) {
      return false;
    }

    final profileEducation = _normalizeString(
      profile['highestEducation'] ?? profile['highestDegree'],
    );
    if (selectedEducationFilter != null &&
        selectedEducationFilter!.isNotEmpty &&
        profileEducation != selectedEducationFilter) {
      return false;
    }

    if (selectedSmokingFilter != null &&
        selectedSmokingFilter!.isNotEmpty &&
        _normalizeString(profile['smoking']) != selectedSmokingFilter) {
      return false;
    }

    if (selectedDrinkingFilter != null &&
        selectedDrinkingFilter!.isNotEmpty &&
        _normalizeString(profile['drinking']) != selectedDrinkingFilter) {
      return false;
    }

    if (selectedHaveChildrenFilter != null &&
        selectedHaveChildrenFilter!.isNotEmpty &&
        _normalizeString(profile['haveChildren']) !=
            selectedHaveChildrenFilter) {
      return false;
    }
  }

  return true;
}
Future<bool> _isDiscoverProfileStillAvailable(
  Map<String, dynamic> profile,
) async {
  final docId = (profile['docId'] ?? '').toString().trim();

  if (docId.isEmpty) return false;

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(docId)
      .get();

  if (!userDoc.exists) return false;

  final data = userDoc.data();

  if (data == null || data['isDeleted'] == true) {
    return false;
  }

  return true;
}
void _removeDiscoverProfile(
  Map<String, dynamic> targetProfile,
) {
  final targetUid =
      (targetProfile['uid'] ?? targetProfile['docId'] ?? '')
          .toString()
          .trim();

  if (targetUid.isEmpty || !mounted) return;

  _discoverProfileChecks.remove(targetUid);

  setState(() {
    _discoverProfiles.removeWhere((profile) {
      final profileUid =
          (profile['uid'] ?? profile['docId'] ?? '')
              .toString()
              .trim();

      return profileUid == targetUid;
    });
  });

  if (_discoverProfiles.length <= 5) {
    _loadMoreDiscoverProfiles();
  }
}
Future<void> _loadMoreDiscoverProfiles() async {
 if (!mounted || _isLoadingMoreDiscoverProfiles) {
  return;
}

  setState(() {
    _isLoadingMoreDiscoverProfiles = true;
  }); 

try {
  // Kiểm tra quota ngay cả khi không còn profile mới để tải.
  final initialRemaining = await _remainingDiscoverToday();

  if (!mounted) return;

  final initialLimitReached = initialRemaining <= 0;

  if (_dailyDiscoverLimitReached != initialLimitReached ||
      (initialLimitReached && _discoverProfiles.isNotEmpty)) {
    setState(() {
      _dailyDiscoverLimitReached = initialLimitReached;

      // Hết lượt thì không hiển thị các profile còn sót.
      if (initialLimitReached) {
        _discoverProfiles.clear();
      }
    });
  }

  if (initialLimitReached) return;

  while (mounted && _hasMoreDiscoverProfiles) {
      final remaining = await _remainingDiscoverToday();

      if (!mounted) return;

     final limitReached = remaining <= 0;

if (limitReached) {
  if (mounted &&
      (!_dailyDiscoverLimitReached || _discoverProfiles.isNotEmpty)) {
    setState(() {
      _dailyDiscoverLimitReached = true;
      _discoverProfiles.clear();
    });
  }

  break;
}

if (_dailyDiscoverLimitReached && mounted) {
  setState(() {
    _dailyDiscoverLimitReached = false;
  });
}

if (remaining <= _discoverProfiles.length) {
  break;
}

      final batch = await _loadProfiles(
        startAfterDocument: _lastDiscoverDocument,
      );

      if (!mounted) return;

      if (batch.isEmpty) {
        continue;
      }

      final existingIds = _discoverProfiles
          .map((profile) =>
              (profile['uid'] ?? profile['docId'] ?? '')
                  .toString()
                  .trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      final newProfiles = batch.where((profile) {
        final uid =
            (profile['uid'] ?? profile['docId'] ?? '')
                .toString()
                .trim();

        return uid.isNotEmpty && !existingIds.contains(uid);
      }).toList();

      if (newProfiles.isEmpty) {
        continue;
      }

      final availableSlots = remaining - _discoverProfiles.length;

      setState(() {
        _discoverProfiles.addAll(
          newProfiles.take(availableSlots),
        );
      });

      if (_discoverProfiles.length >= remaining) {
        break;
      }
    }
    // Chỉ tải người đã Pass khi đã hết toàn bộ hồ sơ mới.
if (mounted && !_hasMoreDiscoverProfiles) {
  final remaining = await _remainingDiscoverToday();

  if (!mounted) return;

  final availableSlots = remaining - _discoverProfiles.length;

  if (availableSlots > 0) {
    final passedProfiles = await _loadPreviouslyPassedProfiles(
      limit: availableSlots,
    );

    if (!mounted) return;

    final existingIds = _discoverProfiles
        .map((profile) =>
            (profile['uid'] ?? profile['docId'] ?? '')
                .toString()
                .trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final newPassedProfiles = passedProfiles.where((profile) {
      final uid =
          (profile['uid'] ?? profile['docId'] ?? '')
              .toString()
              .trim();

      return uid.isNotEmpty && !existingIds.contains(uid);
    }).take(availableSlots).toList();

    if (newPassedProfiles.isNotEmpty) {
      setState(() {
        _discoverProfiles.addAll(newPassedProfiles);
      });
    }
  }
}
  } catch (e) {
    debugPrint('LOAD MORE DISCOVER ERROR: $e');
    } finally {
    if (mounted) {
      setState(() {
        _isLoadingMoreDiscoverProfiles = false;
      });
    } else {
      _isLoadingMoreDiscoverProfiles = false;
    }
  }
}
Future<Map<String, dynamic>?> _getProfileIfStillEligible(
  Map<String, dynamic> cachedProfile,
) async {
  final docId = (cachedProfile['docId'] ?? '').toString().trim();

  if (docId.isEmpty) return null;

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(docId)
      .get();

  // Profile đã bị xóa.
  if (!userDoc.exists) return null;

  final data = userDoc.data();

  if (data == null) return null;

  final uid = (data['uid'] ?? userDoc.id).toString().trim();

  if (uid.isEmpty || uid == currentUser?.uid) return null;

  final mainPhotoUrl =
      (data['mainPhotoUrl'] ?? '').toString().trim();

  if (mainPhotoUrl.isEmpty) return null;
  if (data['profileCompleted'] != true) return null;
  if (data['showMyProfile'] == false) return null;
  if (data['showOnDiscover'] == false) return null;
  if (data['accountPaused'] == true) return null;
  if (data['isPaused'] == true) return null;
  if (data['isDeleted'] == true) return null;

  final profile = <String, dynamic>{
    'docId': userDoc.id,
    ...data,
    if (cachedProfile.containsKey('incomingLike'))
      'incomingLike': cachedProfile['incomingLike'],
  };

  // Giữ nguyên kiểm tra danh bạ và bộ lọc hiện tại.
  if (_shouldHideUserBecauseInMyContacts(profile)) {
    return null;
  }

  if (!_matchesFilters(profile)) {
    return null;
  }

  return profile;
}
 Future<void> _handlePass({
  required Map<String, dynamic> targetProfile,
}) async {
  await _saveSwipe(
    targetProfile: targetProfile,
    action: 'pass',
  );

  if (!mounted) return;

_removeDiscoverProfile(targetProfile);
}
  Future<void> _createContentLikeMessagesAfterMatch({
  required Map<String, dynamic> targetProfile,
  required String currentComment,
  required String currentContentType,
  required int currentContentIndex,
  required String currentContentText,
}) async {
  final user = currentUser;
  if (user == null) return;

  final currentUid = user.uid;

  final targetUid =
      (targetProfile['uid'] ?? targetProfile['docId'] ?? '')
          .toString()
          .trim();

  if (targetUid.isEmpty || targetUid == currentUid) return;

  final chatId = _chatIdFor(currentUid, targetUid);
  final firestore = FirebaseFirestore.instance;

  // Lấy lượt Like trước đó của User A dành cho User B.
  final reverseSwipeId = '${targetUid}_$currentUid';

  final reverseSwipeDoc = await firestore
      .collection('swipes')
      .doc(reverseSwipeId)
      .get();

  final reverseData = reverseSwipeDoc.data() ?? {};

  final reverseAction =
      (reverseData['action'] ?? '').toString().trim().toLowerCase();

  final reverseContentType =
      (reverseData['likedContentType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

  final reverseContentIndex =
      reverseData['likedContentIndex'];

  final reverseContentText =
      (reverseData['likedContentText'] ?? '')
          .toString()
          .trim();

  final reverseComment =
      (reverseData['likeComment'] ?? '')
          .toString()
          .trim();

  final messagesRef = firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages');

  // Tin nhắn/ngữ cảnh của User A, người Like trước.
  if (reverseAction == 'like' &&
      (reverseContentType == 'photo' ||
          reverseContentType == 'prompt')) {
    await messagesRef.doc('content_like_$targetUid').set({
      'senderId': targetUid,
      'receiverId': currentUid,
      'text': reverseComment,
      'type': 'content_like',
      'likedContentType': reverseContentType,
      'likedContentIndex': reverseContentIndex,
      'likedContentText': reverseContentText,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    }, SetOptions(merge: true));
  }

  // Tin nhắn/comment hiện tại của User B.
  if (currentContentType == 'photo' ||
      currentContentType == 'prompt') {
    await messagesRef.doc('content_like_$currentUid').set({
      'senderId': currentUid,
      'receiverId': targetUid,
      'text': currentComment.trim(),
      'type': 'content_like',
      'likedContentType': currentContentType,
      'likedContentIndex': currentContentIndex,
      'likedContentText': currentContentText,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    }, SetOptions(merge: true));
  }

  final previewText = currentComment.trim().isNotEmpty
      ? currentComment.trim()
      : reverseComment;

  await firestore.collection('chats').doc(chatId).set({
    'lastMessage': previewText,
    'lastMessageType': 'content_like',
    'lastSenderId': currentComment.trim().isNotEmpty
        ? currentUid
        : targetUid,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> _handleContentLike({
  required Map<String, dynamic> targetProfile,
  required String contentType,
  required int contentIndex,
  required String contentText,
}) async {
  if (_isProcessingAction) return;

  // Bấm tim trên ảnh hoặc prompt: Like ngay, không mở popup bình luận.
  final didMatch = await _saveSwipe(
    targetProfile: targetProfile,
    action: 'like',
    likedContentType: contentType,
    likedContentIndex: contentIndex,
    likedContentText: contentText,
    likeComment: '',
  );

  if (!mounted || !_lastSwipeSaved) return;

  if (didMatch) {
    await _showMatchDialog(targetProfile);
  }

  if (!mounted) return;
  _removeDiscoverProfile(targetProfile);
}

Future<void> _saveBreakTheIceAnswer({
  required Map<String, dynamic> targetProfile,
  required String answer,
}) async {
  final user = currentUser;
  if (user == null) return;

  final targetUid =
      (targetProfile['uid'] ?? targetProfile['docId'] ?? '')
          .toString()
          .trim();

  if (targetUid.isEmpty) return;

  final ids = [user.uid, targetUid]..sort();
  final pairId = ids.join('_');

  await FirebaseFirestore.instance
      .collection('breakTheIce')
      .doc(pairId)
      .set({
    'userIds': ids,

    'answers': {
      user.uid: answer,
    },

    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
 Future<void> _handleLike({
  required Map<String, dynamic> targetProfile,
}) async {
  final didMatch = await _saveSwipe(
    targetProfile: targetProfile,
    action: 'like',
  );

    if (!mounted) return;

if (_lastSwipeSaved && didMatch) {
  await _showMatchDialog(targetProfile);
}

  if (!mounted) return;

    _removeDiscoverProfile(targetProfile);
}
  Future<bool> _handleFlower({
    required Map<String, dynamic> targetProfile,
  }) async {
    final user = currentUser;
    if (user == null) return false;

    final canSend = await _canSendFlower();
    if (!canSend && mounted) {
      await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(isVi ? 'Hết lượt tặng hoa' : 'No flowers left'),
            content: Text(
              isVi
                  ? 'Bạn đã dùng hết 7 lượt flower miễn phí. Hãy mua VIP hoặc mua thêm \$0.99 cho 1 flower.'
                  : 'You have used all 7 free flowers. Please buy VIP or purchase 1 extra flower for \$0.99.',
            ),
            actions: [
  TextButton(
    onPressed: () => Navigator.pop(context),
    child: Text(isVi ? 'Để sau' : 'Later'),
  ),

  TextButton(
    onPressed: () {
      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UpgradeVipPage(
            languageCode: widget.languageCode,
            onPurchaseSuccess: () async {
              await _reloadCurrentUserData();
            },
          ),
        ),
      );
    },
    child: Text(
      isVi ? 'Nâng cấp VIP' : 'Upgrade VIP',
      style: const TextStyle(
        color: Color(0xFFCC3D7A),
        fontWeight: FontWeight.w700,
      ),
    ),
  ),

  ElevatedButton(
    onPressed: () async {
      Navigator.pop(context);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BuyFlowerPage(
            languageCode: widget.languageCode,
            autoBuyProductId: 'flower_1',
          ),
        ),
      );

      await _reloadCurrentUserData();
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFCC3D7A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    child: Text(
      isVi ? 'Mua flower' : 'Buy flower',
      style: const TextStyle(color: Colors.white),
    ),
  ),
],
          );
        },
      );
      return false;
    }

    final controller = TextEditingController();
  final sentCount = await _sentFlowerCount();

final freeRemaining = (7 - sentCount).clamp(0, 7);

final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .get();

final purchasedRemaining =
    _parseInt(userDoc.data()?['flowerBalance']);

final remaining = freeRemaining + purchasedRemaining;

    final result = await showDialog<String?>(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            isVi
                ? ''
                : '',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
  isVi
     ? 'Bạn còn: $remaining'
: 'remaining: $remaining',
  style: const TextStyle(
    fontWeight: FontWeight.w600,
    color: Color(0xFFCC3D7A),
  ),
),
    const SizedBox(height: 12),
    TextField(
      controller: controller,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: isVi
            ? 'Nhập lời nhắn của bạn...'
            : 'Write your message...',
        filled: true,
        fillColor: const Color(0xFFFFF3F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFFFD5E6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFCC3D7A),
            width: 1.3,
          ),
        ),
      ),
    ),
  ],
),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(isVi ? 'Huỷ' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
  final text = controller.text.trim();

  if (text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi
              ? 'Vui lòng nhập lời nhắn trước khi gửi hoa.'
              : 'Please write a message before sending a flower.',
        ),
      ),
    );
    return;
  }

  Navigator.pop(context, text);
},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC3D7A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isVi ? 'Gửi' : 'Send',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (result == null) {
      if (mounted) setState(() {});
      return false;
    }

    final canUseFlower = await _consumePurchasedFlowerIfNeeded();

if (!canUseFlower) {
  if (!mounted) return false;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        isVi
            ? 'Bạn không còn flower. Vui lòng mua thêm flower.'
            : 'You have no flowers left. Please purchase more flowers.',
      ),
    ),
  );
  return false;
}

await _saveSwipe(
  targetProfile: targetProfile,
  action: 'flower',
  flowerMessage: result,
);

    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi ? 'Đã gửi flower thành công.' : 'Flower sent successfully.',
        ),
      ),
    );

        _removeDiscoverProfile(targetProfile);
    return true;
  }

 Future<bool> _saveSwipe({
  required Map<String, dynamic> targetProfile,
  required String action,
  String? flowerMessage,

  // Dùng cho Like trực tiếp ảnh hoặc prompt.
  String? likedContentType,
  int? likedContentIndex,
  String? likedContentText,
  String? likeComment,
}) async {
       _lastSwipeSaved = false;

    final user = currentUser;
    if (user == null || _isProcessingAction) return false;

    final currentUid = user.uid;
    final targetUid =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();

    if (targetUid.isEmpty) return false;
    if (targetUid == currentUid) return false;

    setState(() {
      _isProcessingAction = true;
    });

    bool didMatch = false;

try {
  final docId = '${currentUid}_$targetUid';

      await FirebaseFirestore.instance.collection('swipes').doc(docId).set({
  'fromUserId': currentUid,
  'toUserId': targetUid,
  'action': action,
  'flowerMessage': flowerMessage ?? '',

  // Thông tin ảnh hoặc prompt được Like.
  'likedContentType': likedContentType ?? '',
  'likedContentIndex': likedContentIndex,
  'likedContentText': likedContentText ?? '',
  'likeComment': likeComment ?? '',

  'createdAt': FieldValue.serverTimestamp(),
});
      if (action == 'pass') {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('passedUsers')
      .doc(targetUid)
      .set({
    'uid': targetUid,
    'firstName': (targetProfile['firstName'] ?? '').toString().trim(),
    'age': targetProfile['age'],
    'photoUrl': (targetProfile['mainPhotoUrl'] ?? targetProfile['photoUrl'] ?? '')
        .toString()
        .trim(),
    'mainPhotoUrl':
        (targetProfile['mainPhotoUrl'] ?? targetProfile['photoUrl'] ?? '')
            .toString()
            .trim(),
    'timestamp': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
if (action == 'like') {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(targetUid)
      .collection('likedBy')
      .doc(currentUid)
      .set({
    // Giữ nguyên dữ liệu Like hiện tại.
    'uid': currentUid,
    'firstName': (currentUserData?['firstName'] ?? '').toString().trim(),
    'age': currentUserData?['age'],
    'photoUrl': (currentUserData?['mainPhotoUrl'] ?? '').toString().trim(),
    'mainPhotoUrl':
        (currentUserData?['mainPhotoUrl'] ?? '').toString().trim(),

    // Like thường sẽ để trống các field này.
    // Like ảnh hoặc prompt sẽ lưu đầy đủ.
    'likedContentType': likedContentType ?? '',
    'likedContentIndex': likedContentIndex,
    'likedContentText': likedContentText ?? '',
    'likeComment': likeComment ?? '',

    'timestamp': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
      if (action == 'flower' && flowerMessage != null) {
        await _createFlowerChat(
          targetProfile: targetProfile,
          message: flowerMessage,
        );
      }

      if (action == 'like') {
        final reverseId = '${targetUid}_$currentUid';
        final reverseDoc = await FirebaseFirestore.instance
            .collection('swipes')
            .doc(reverseId)
            .get();

        final reverseData = reverseDoc.data();
        final reverseAction =
            (reverseData?['action'] ?? '').toString().trim().toLowerCase();

        if (reverseAction == 'like') {
  didMatch = true;

  await _createMatch(
    targetProfile: targetProfile,
  );

  final reverseContentType =
      (reverseData?['likedContentType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

  final currentIsContentLike =
      likedContentType == 'photo' ||
      likedContentType == 'prompt';

  final reverseIsContentLike =
      reverseContentType == 'photo' ||
      reverseContentType == 'prompt';

  // Chỉ tạo message nếu ít nhất một người
  // Like ảnh hoặc prompt.
  if (currentIsContentLike || reverseIsContentLike) {
    await _createContentLikeMessagesAfterMatch(
      targetProfile: targetProfile,
      currentComment: likeComment ?? '',
      currentContentType: likedContentType ?? '',
      currentContentIndex: likedContentIndex ?? -1,
      currentContentText: likedContentText ?? '',
    );
  }

  await _sendMatchNotification(targetProfile);
}
      }
      _lastSwipeSaved = true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Có lỗi xảy ra: $e' : 'Something went wrong: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }

    return didMatch;
  }

  Future<int> _sentFlowerCount() async {
  final user = currentUser;
  if (user == null) return 0;

  final snapshot = await FirebaseFirestore.instance
      .collection('swipes')
      .where('fromUserId', isEqualTo: user.uid)
      .where('action', isEqualTo: 'flower')
      .get();

  return snapshot.docs.length;
}

int _flowerBalance() {
  return _parseInt(currentUserData?['flowerBalance']);
}

Future<bool> _canSendFlower() async {
  final user = currentUser;
  if (user == null) return false;

  if (isVipUser) return true;

  final sentCount = await _sentFlowerCount();

  if (sentCount < 7) return true;

  return _flowerBalance() > 0;
}

Future<bool> _consumePurchasedFlowerIfNeeded() async {
  final user = currentUser;
  if (user == null) return false;

  if (isVipUser) return true;

  final sentCount = await _sentFlowerCount();

  // Free user vẫn còn trong 7 flower miễn phí
  if (sentCount < 7) return true;

  final userRef =
      FirebaseFirestore.instance.collection('users').doc(user.uid);

  bool success = false;

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    final doc = await transaction.get(userRef);
    final data = doc.data() ?? {};

    final balance = _parseInt(data['flowerBalance']);

    if (balance <= 0) {
      success = false;
      return;
    }

    transaction.set(
      userRef,
      {
        'flowerBalance': FieldValue.increment(-1),
        'lastFlowerUsedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    success = true;
  });

  if (success) {
    await _reloadCurrentUserData();
  }

  return success;
}

  Future<void> _createFlowerChat({
    required Map<String, dynamic> targetProfile,
    required String message,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final fromUid = user.uid;
    final toUid =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();

    if (toUid.isEmpty || toUid == fromUid) return;

    final chatId = _chatIdFor(fromUid, toUid);

    final fromName = _firstNonEmpty(currentUserData ?? {}, ['firstName']);
    final toName = _firstNonEmpty(targetProfile, ['firstName']);

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'chatId': chatId,
      'participants': [fromUid, toUid],
      'lastMessage': message,
      'lastMessageType': 'flower',
      'lastSenderId': fromUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'participantNames': {
        fromUid: fromName,
        toUid: toName,
      },
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': fromUid,
      'receiverId': toUid,
      'text': message,
      'type': 'flower',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> _createMatch({
  required Map<String, dynamic> targetProfile,
}) async {
  final user = currentUser;
  if (user == null) return;

  final currentUid = user.uid;
  final targetUid =
      (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();

  if (targetUid.isEmpty || targetUid == currentUid) return;

  final matchId = _chatIdFor(currentUid, targetUid);

  final currentName = _firstNonEmpty(currentUserData ?? {}, ['firstName']);
  final targetName = _firstNonEmpty(targetProfile, ['firstName']);

  final currentPhotoList = _extractPhotos(currentUserData ?? {});
  final targetPhotoList = _extractPhotos(targetProfile);

  final currentPhoto = currentPhotoList.isNotEmpty
      ? currentPhotoList.first
      : (currentUserData?['mainPhotoUrl'] ?? '').toString().trim();

  final targetPhoto = targetPhotoList.isNotEmpty
      ? targetPhotoList.first
      : (targetProfile['mainPhotoUrl'] ?? '').toString().trim();

  final firestore = FirebaseFirestore.instance;

  await firestore.collection('matches').doc(matchId).set({
    'matchId': matchId,
    'chatId': matchId,
    'users': [currentUid, targetUid],
    'userIds': [currentUid, targetUid],
    'createdAt': FieldValue.serverTimestamp(),
    'lastMessage': '',
    'lastMessageAt': FieldValue.serverTimestamp(),
    'participantNames': {
      currentUid: currentName,
      targetUid: targetName,
    },
    'participantPhotos': {
      currentUid: currentPhoto,
      targetUid: targetPhoto,
    },
  }, SetOptions(merge: true));

  await firestore.collection('chats').doc(matchId).set({
    'chatId': matchId,
    'participants': [currentUid, targetUid],
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'lastMessage': '',
    'lastMessageType': 'match',
    'lastSenderId': '',
    'participantNames': {
      currentUid: currentName,
      targetUid: targetName,
    },
    'participantPhotos': {
      currentUid: currentPhoto,
      targetUid: targetPhoto,
    },
  }, SetOptions(merge: true));
}
Future<void> _sendMatchNotification(
  Map<String, dynamic> targetProfile,
) async {
  try {
    final targetUid =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? '')
            .toString()
            .trim();

    if (targetUid.isEmpty) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .get();

    final token = doc.data()?['fcmToken'];

    print('SEND MATCH NOTIFICATION TOKEN: $token');
  } catch (e) {
    print('sendMatchNotification error: $e');
  }
}

  String _chatIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  Future<void> _showMatchDialog(Map<String, dynamic> targetProfile) async {
    final currentPhoto = _extractPhotos(currentUserData ?? {}).isNotEmpty
        ? _extractPhotos(currentUserData ?? {}).first
        : (currentUserData?['mainPhotoUrl'] ?? '').toString().trim();

    final targetPhoto = _extractPhotos(targetProfile).isNotEmpty
        ? _extractPhotos(targetProfile).first
        : (targetProfile['mainPhotoUrl'] ?? '').toString().trim();

    final targetName = _capitalizeName(
      (targetProfile['firstName'] ?? '').toString(),
    );

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMatchPhoto(currentPhoto),
                    const SizedBox(width: 16),
                    _buildMatchPhoto(targetPhoto),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '🎉🎉 You’re connected with $targetName 🎉🎉',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF3B6CB7),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isVi
                      ? '$targetName và bạn đã có duyên với nhau 💘💘💘'
                      : 'Looks like you and $targetName share a mutual interest 💘💘💘',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3B6CB7),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(
                            color: Color(0xFF3B6CB7),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size.fromHeight(54),
                        ),
                        child: Text(isVi ? 'Để sau' : 'Later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
  child: ElevatedButton(
    onPressed: () {
      final targetUid =
          (targetProfile['uid'] ?? targetProfile['docId'] ?? '')
              .toString()
              .trim();

      if (targetUid.isEmpty) return;

      final chatId = _chatIdFor(currentUser!.uid, targetUid);
      final otherName = _capitalizeName(
        (targetProfile['firstName'] ?? '').toString(),
      );

      final otherPhotos = _extractPhotos(targetProfile);
      final otherPhoto = otherPhotos.isNotEmpty
          ? otherPhotos.first
          : (targetProfile['mainPhotoUrl'] ?? '').toString().trim();

      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MessagePage(
            languageCode: widget.languageCode,
            chatId: chatId,
            otherUserId: targetUid,
            otherUserName: otherName.isNotEmpty ? otherName : 'User',
            otherUserPhotoUrl: otherPhoto,
          ),
        ),
      );
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF5C6BC0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      minimumSize: const Size.fromHeight(54),
    ),
    child: Text(
      isVi ? 'Nhắn tin' : 'Message',
      style: const TextStyle(color: Colors.white),
    ),
  ),
),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
Future<void> _openSocial({
  required String value,
  required String platform,
}) async {
  String input = value.trim();

  if (input.isEmpty) return;

  String url;

  if (input.startsWith('http://') ||
      input.startsWith('https://')) {
    url = input;
  } else {
    final username = input
        .replaceAll('@', '')
        .replaceAll('facebook.com/', '')
        .replaceAll('www.facebook.com/', '')
        .replaceAll('instagram.com/', '')
        .replaceAll('www.instagram.com/', '')
        .replaceAll('tiktok.com/', '')
        .replaceAll('www.tiktok.com/', '')
        .trim();

    if (platform == 'facebook') {
      url = 'https://www.facebook.com/$username';
    } else if (platform == 'instagram') {
      url = 'https://www.instagram.com/$username';
    } else {
      url = 'https://www.tiktok.com/@$username';
    }
  }

  final uri = Uri.tryParse(url);

  if (uri == null) return;

  final opened = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );

  if (!opened && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi
              ? 'Không thể mở liên kết này.'
              : 'Unable to open this link.',
        ),
      ),
    );
  }
}
  Widget _buildMatchPhoto(String imageUrl) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade200,
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const Icon(Icons.person, size: 56, color: Colors.grey);
                },
              )
            : const Icon(Icons.person, size: 56, color: Colors.grey),
      ),
    );
  }

 Future<void> _openFilterSheet() async {
  await _reloadCurrentUserData();

  if (!mounted) return;
  debugPrint(
  'VIP FILTER DEBUG: '
  'isVipUser=$isVipUser, '
  'now=${DateTime.now()}, '
  'vipExpiresAt=${currentUserData?['vipExpiresAt']}',
);

  final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return HomePageFilterSheet(
          isVi: isVi,
          isVipUser: isVipUser,
          initialGender: selectedGenderFilter,
          initialMinAge: selectedMinAgeFilter,
          initialMaxAge: selectedMaxAgeFilter,
          initialCountry: selectedCountryFilter,
          initialState: selectedStateFilter,
          currentUserCountryCode:
    (currentUserData?['countryCode'] ?? 'AU')
        .toString()
        .trim()
        .toUpperCase(),
          initialDistanceKm: selectedDistanceKm,
          initialReligion: selectedReligionFilter,
          initialRelationshipGoal: selectedRelationshipGoalFilter,
          initialMaritalStatus: selectedMaritalStatusFilter,
          initialHeight: selectedHeightFilter,
          initialResidentStatus: selectedResidentStatusFilter,
          initialEducation: selectedEducationFilter,
          initialSmoking: selectedSmokingFilter,
          initialDrinking: selectedDrinkingFilter,
          initialHaveChildren: selectedHaveChildrenFilter,
          initialIncome: selectedIncomeFilter,
          initialPhotoVerifiedOnly: selectedPhotoVerifiedOnly,
          initialNewHereOnly: selectedNewHereOnly,
          stateOptions: stateOptions,
          ageOptions: ageOptions,
          countryOptions: countryOptions,
          labelBuilder: _label,
          translateProfileValue: _translateProfileValue,
          onTapUpgrade: () {
            Navigator.pop(context);
            setState(() {
              _selectedBottomIndex = 4;
            });
          },
          onResetToDefault: () {
            setState(() {
              selectedCountryFilter =
    (currentUserData?['selectedCountry'] ??
            currentUserData?['country'] ??
            '')
        .toString()
        .trim();

if (selectedCountryFilter!.isEmpty) {
  selectedCountryFilter = null;
}
              selectedGenderFilter = _normalizeGenderPreference(
                currentUserData?['datingPreference'] ??
                    currentUserData?['genderPreference'],
                    
              );
              selectedMinAgeFilter = _parseInt(
                currentUserData?['minAgePreference'] ??
                    currentUserData?['preferredMinAge'],
              );
              selectedMaxAgeFilter = _parseInt(
                currentUserData?['maxAgePreference'] ??
                    currentUserData?['preferredMaxAge'],
              );
             selectedStateFilter =
    (currentUserData?['selectedStateKey'] ??
            currentUserData?['selectedState'] ??
            currentUserData?['stateLiving'] ??
            currentUserData?['state'] ??
            '')
        .toString()
        .trim();

if (selectedStateFilter!.isEmpty) {
  selectedStateFilter = null;
}

              
              if (selectedMinAgeFilter == 0) selectedMinAgeFilter = null;
              if (selectedMaxAgeFilter == 0) selectedMaxAgeFilter = null;
              selectedReligionFilter = null;
              selectedRelationshipGoalFilter = null;
              selectedMaritalStatusFilter = null;
              selectedHeightFilter = null;
              selectedResidentStatusFilter = null;
              selectedEducationFilter = null;
              selectedSmokingFilter = null;
              selectedDrinkingFilter = null;
              selectedHaveChildrenFilter = null;
              selectedIncomeFilter = null;


              selectedPhotoVerifiedOnly = false;
              selectedNewHereOnly = false;
            });
          },
        );
      },
    );

    if (!mounted || result == null) return;

   if (result == 'reset_to_default') {
  final user = currentUser;

  if (user != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'genderPreference': selectedGenderFilter,
      'minAgePreference': selectedMinAgeFilter,
      'maxAgePreference': selectedMaxAgeFilter,
      'filterCountry': selectedCountryFilter,
      'filterState': selectedStateFilter,
      'filterStateKey': selectedStateFilter == null
          ? null
          : _normalizeStateKey(selectedStateFilter),
      'maxDistanceKm': selectedDistanceKm,

      'filterReligion': null,
      'filterRelationshipGoal': null,
      'filterMaritalStatus': null,
      'filterHeight': null,
      'filterResidentStatus': null,
      'filterEducation': null,
      'filterSmoking': null,
      'filterDrinking': null,
      'filterHaveChildren': null,
      'filterIncome': null,
      'filterPhotoVerifiedOnly': false,
      'filterNewHereOnly': false,
    }, SetOptions(merge: true));
  }

  if (!mounted) return;

  setState(() {
   _startDiscoverProfilesLoad();
  });

  return;
}

    if (result is HomePageFilterResult) {
      setState(() {
        
        selectedGenderFilter = result.gender;
        selectedMinAgeFilter = result.minAge;
        selectedMaxAgeFilter = result.maxAge;
        selectedCountryFilter =
    (result.country == null || result.country!.trim().isEmpty)
        ? null
        : result.country;
        selectedStateFilter =
    (result.state == null || result.state!.trim().isEmpty)
        ? null
        : result.state;
        selectedDistanceKm = result.distanceKm;
        

        if (isVipUser) {
          selectedReligionFilter = result.religion;
          selectedRelationshipGoalFilter = result.relationshipGoal;
          selectedMaritalStatusFilter = result.maritalStatus;
          selectedHeightFilter = result.height;
          selectedResidentStatusFilter = result.residentStatus;
          selectedEducationFilter = result.education;
          selectedSmokingFilter = result.smoking;
          selectedDrinkingFilter = result.drinking;
          selectedHaveChildrenFilter = result.haveChildren;
          selectedIncomeFilter = result.income;
          selectedPhotoVerifiedOnly = result.photoVerifiedOnly;
          selectedNewHereOnly = result.newHereOnly;
        } else {
          selectedReligionFilter = null;
          selectedRelationshipGoalFilter = null;
          selectedMaritalStatusFilter = null;
          selectedHeightFilter = null;
          selectedResidentStatusFilter = null;
          selectedEducationFilter = null;
          selectedSmokingFilter = null;
          selectedDrinkingFilter = null;
          selectedHaveChildrenFilter = null;
          selectedIncomeFilter = null;

          selectedPhotoVerifiedOnly = false;
          selectedNewHereOnly = false;
        }
            });
            final user = currentUser;

if (user != null) {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .set({
    'genderPreference': selectedGenderFilter,
    'minAgePreference': selectedMinAgeFilter,
    'maxAgePreference': selectedMaxAgeFilter,
    'filterCountry': selectedCountryFilter,

    // 👉 STATE FILTER (đã sửa)
    'filterState': selectedStateFilter,
    'filterStateKey': selectedStateFilter == null
        ? null
        : _normalizeStateKey(selectedStateFilter),

    'maxDistanceKm': selectedDistanceKm,
    'filterReligion': selectedReligionFilter,
'filterRelationshipGoal': selectedRelationshipGoalFilter,
'filterMaritalStatus': selectedMaritalStatusFilter,
'filterHeight': selectedHeightFilter,
'filterResidentStatus': selectedResidentStatusFilter,
'filterEducation': selectedEducationFilter,
'filterSmoking': selectedSmokingFilter,
'filterDrinking': selectedDrinkingFilter,
'filterHaveChildren': selectedHaveChildrenFilter,
'filterIncome': selectedIncomeFilter,
'filterPhotoVerifiedOnly': selectedPhotoVerifiedOnly,
'filterNewHereOnly': selectedNewHereOnly,
  }, SetOptions(merge: true));
}

      if (!mounted) return;

      setState(() {
       _startDiscoverProfilesLoad();
      });
    }
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
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedBottomIndex = 4;
              });
            },
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
          border: Border.all(
            color: const Color(0xFFE91E63),
          ),
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
                : _translateProfileValue(item, isVi),
          ),
        );
      }).toList(),
    );
  }

  String _label(String vi, String en) => isVi ? vi : en;

  bool _hasVipAccess(Map<String, dynamic>? data) {
  if (data == null) return false;

  final vipExpiresAt = data['vipExpiresAt'];

  if (vipExpiresAt is! Timestamp) {
    return false;
  }

  return vipExpiresAt.toDate().isAfter(DateTime.now());
}
List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return [];
}

  String _normalizeString(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }
  String _firstNonEmptyValue(List<dynamic> values) {
  for (final value in values) {
    final result = (value ?? '').toString().trim();

    if (result.isNotEmpty &&
        result.toLowerCase() != 'null' &&
        result.toLowerCase() != 'nan') {
      return result;
    }
  }

  return '';
}
String _normalizeStateKey(dynamic value) {
  final v = _normalizeString(value);

  if (v.contains('vic') || v.contains('victoria')) return 'vic';
  if (v.contains('nsw') || v.contains('new south wales')) return 'nsw';
  if (v.contains('qld') || v.contains('queensland')) return 'qld';
  if (v.contains('sa') || v.contains('south australia')) return 'sa';
  if (v.contains('wa') || v.contains('western australia')) return 'wa';
  if (v.contains('tas') || v.contains('tasmania')) return 'tas';
  if (v.contains('act') || v.contains('australian capital territory')) return 'act';
  if (v.contains('nt') || v.contains('northern territory')) return 'nt';
  if (v.startsWith('other -')) return v;

  return v;
}
  int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
double _calculateDistanceKm(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusKm = 6371.0;

  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) *
          cos(_degToRad(lat2)) *
          sin(dLng / 2) *
          sin(dLng / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double degree) {
  return degree * pi / 180;
}
  String _normalizeGenderPreference(dynamic value) {
    final raw = _normalizeString(value);

    if (raw == 'male' || raw == 'man' || raw == 'nam') return 'male';
    if (raw == 'female' || raw == 'woman' || raw == 'nu' || raw == 'nữ') {
      return 'female';
    }
    if (raw == 'other' || raw == 'khác') return 'other';
    if (raw == 'everyone' ||
        raw == 'all' ||
        raw == 'both' ||
        raw == 'tất cả') {
      return 'everyone';
    }

    return raw;
  }

  bool _genderMatches(String profileGender, String preference) {
    final pg = _normalizeGenderPreference(profileGender);
    final pf = _normalizeGenderPreference(preference);

    if (pf == 'everyone') return true;
    return pg == pf;
  }

  
String _capitalizeName(String text) {
  final value = text.trim();
  if (value.isEmpty) return '';

  return value
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}


  List<String> _extractPhotos(Map<String, dynamic> profile) {
    final List<String> result = [];

    final main = (profile['mainPhotoUrl'] ?? '').toString().trim();
    if (main.isNotEmpty && !result.contains(main)) {
      result.add(main);
    }

    final sources = [
      profile['photos'],
      profile['photoUrls'],
      profile['images'],
    ];

    for (final src in sources) {
      if (src is List) {
        for (final item in src) {
          final url = item?.toString().trim() ?? '';
          if (url.isNotEmpty && !result.contains(url)) {
            result.add(url);
          }
        }
      }
    }

    return result;
  }

  PromptOption? _findPromptOptionById(String id) {
    try {
      return kPromptOptions.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  int? _readAnswerIndex(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString().trim());
  }

  String _pickPromptAnswerFromOption({
    required PromptOption option,
    required int answerIndex,
    required bool isVi,
  }) {
    final list = isVi ? option.aiSuggestionsVi : option.aiSuggestionsEn;

    if (answerIndex >= 0 && answerIndex < list.length) {
      return list[answerIndex];
    }

    return '';
  }

  List<Map<String, String>> _extractPrompts(
  Map<String, dynamic> profile,
  bool isVi,
) {
  final List<Map<String, String>> prompts = [];

  void addPrompt({
    required String question,
    required String answer,
  }) {
    final q = question.trim();
    final a = answer.trim();

    if (q.isNotEmpty || a.isNotEmpty) {
      prompts.add({
        'question': q,
        'answer': a,
      });
    }
  }

  final dynamic profilePrompts = profile['profilePrompts'];
  if (profilePrompts is List) {
    for (final item in profilePrompts) {
      if (item is Map) {
        final promptId =
            (item['id'] ?? item['promptId'] ?? '').toString().trim();
        final answerIndex = _readAnswerIndex(
          item['answerIndex'] ?? item['selectedAnswerIndex'],
        );

        final option =
            promptId.isNotEmpty ? _findPromptOptionById(promptId) : null;

        if (option != null && answerIndex != null) {
          addPrompt(
            question: isVi ? option.questionVi : option.questionEn,
            answer: _pickPromptAnswerFromOption(
              option: option,
              answerIndex: answerIndex,
              isVi: isVi,
            ),
          );
          continue;
        }

        final question = isVi
            ? (item['questionVi'] ?? item['question'] ?? '')
                .toString()
                .trim()
            : (item['questionEn'] ?? item['question'] ?? '')
                .toString()
                .trim();

        final answerVi = (item['answerVi'] ?? '').toString().trim();
        final answerEn = (item['answerEn'] ?? '').toString().trim();
        final answerRaw = (item['answer'] ?? '').toString().trim();

        final finalAnswer = isVi
            ? (answerVi.isNotEmpty
                ? answerVi
                : (answerRaw.isNotEmpty ? answerRaw : answerEn))
            : (answerEn.isNotEmpty
                ? answerEn
                : (answerRaw.isNotEmpty ? answerRaw : answerVi));

        addPrompt(question: question, answer: finalAnswer);
      }
    }
  }

  final dynamic rawPrompts = profile['prompts'];
  if (rawPrompts is List) {
    for (final item in rawPrompts) {
      if (item is Map) {
        final promptId =
            (item['id'] ?? item['promptId'] ?? '').toString().trim();
        final answerIndex = _readAnswerIndex(
          item['answerIndex'] ?? item['selectedAnswerIndex'],
        );

        final option =
            promptId.isNotEmpty ? _findPromptOptionById(promptId) : null;

        if (option != null && answerIndex != null) {
          addPrompt(
            question: isVi ? option.questionVi : option.questionEn,
            answer: _pickPromptAnswerFromOption(
              option: option,
              answerIndex: answerIndex,
              isVi: isVi,
            ),
          );
          continue;
        }

        final question = isVi
            ? (item['questionVi'] ?? item['question'] ?? '')
                .toString()
                .trim()
            : (item['questionEn'] ?? item['question'] ?? '')
                .toString()
                .trim();

        final answerVi = (item['answerVi'] ?? '').toString().trim();
        final answerEn = (item['answerEn'] ?? '').toString().trim();
        final answerRaw = (item['answer'] ?? '').toString().trim();

        final finalAnswer = isVi
            ? (answerVi.isNotEmpty
                ? answerVi
                : (answerRaw.isNotEmpty ? answerRaw : answerEn))
            : (answerEn.isNotEmpty
                ? answerEn
                : (answerRaw.isNotEmpty ? answerRaw : answerVi));

        addPrompt(question: question, answer: finalAnswer);
      }
    }
  }

  for (int i = 1; i <= 5; i++) {
    final promptId = (profile['promptId$i'] ?? '').toString().trim();
    final answerIndex = _readAnswerIndex(profile['promptAnswerIndex$i']);

    final option =
        promptId.isNotEmpty ? _findPromptOptionById(promptId) : null;

    if (option != null && answerIndex != null) {
      addPrompt(
        question: isVi ? option.questionVi : option.questionEn,
        answer: _pickPromptAnswerFromOption(
          option: option,
          answerIndex: answerIndex,
          isVi: isVi,
        ),
      );
      continue;
    }

    final q = isVi
        ? (profile['promptQuestionVi$i'] ?? profile['promptQuestion$i'] ?? '')
            .toString()
            .trim()
        : (profile['promptQuestionEn$i'] ?? profile['promptQuestion$i'] ?? '')
            .toString()
            .trim();

    final answerVi = (profile['promptAnswerVi$i'] ?? '').toString().trim();
    final answerEn = (profile['promptAnswerEn$i'] ?? '').toString().trim();
    final answerRaw = (profile['promptAnswer$i'] ?? '').toString().trim();

    final a = isVi
        ? (answerVi.isNotEmpty
            ? answerVi
            : (answerRaw.isNotEmpty ? answerRaw : answerEn))
        : (answerEn.isNotEmpty
            ? answerEn
            : (answerRaw.isNotEmpty ? answerRaw : answerVi));

    addPrompt(question: q, answer: a);
  }

  if (prompts.isEmpty) {
    final promptId = (profile['promptId'] ?? '').toString().trim();
    final answerIndex = _readAnswerIndex(profile['promptAnswerIndex']);

    final option =
        promptId.isNotEmpty ? _findPromptOptionById(promptId) : null;

    if (option != null && answerIndex != null) {
      addPrompt(
        question: isVi ? option.questionVi : option.questionEn,
        answer: _pickPromptAnswerFromOption(
          option: option,
          answerIndex: answerIndex,
          isVi: isVi,
        ),
      );
    } else {
      final q = isVi
          ? (profile['promptQuestionVi'] ?? profile['promptQuestion'] ?? '')
              .toString()
              .trim()
          : (profile['promptQuestionEn'] ?? profile['promptQuestion'] ?? '')
              .toString()
              .trim();

      final answerVi = (profile['promptAnswerVi'] ?? '').toString().trim();
      final answerEn = (profile['promptAnswerEn'] ?? '').toString().trim();
      final answerRaw = (profile['promptAnswer'] ?? '').toString().trim();

      final a = isVi
          ? (answerVi.isNotEmpty
              ? answerVi
              : (answerRaw.isNotEmpty ? answerRaw : answerEn))
          : (answerEn.isNotEmpty
              ? answerEn
              : (answerRaw.isNotEmpty ? answerRaw : answerVi));

      addPrompt(question: q, answer: a);
    }
  }

  if (prompts.length > 5) {
    return prompts.take(5).toList();
  }

  return prompts;
}

 String _livingStateDisplay(Map<String, dynamic> profile) {
  String firstNonEmpty(List<dynamic> values) {
    for (final item in values) {
      final value = (item ?? '').toString().trim();
      final lowerValue = value.toLowerCase();

      if (value.isNotEmpty &&
          lowerValue != 'other' &&
          lowerValue != 'no_preference') {
        return value;
      }
    }

    return '';
  }

  String shortState(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized.contains('new south wales') ||
        normalized == 'nsw') {
      return 'NSW';
    }

    if (normalized.contains('victoria') ||
        normalized == 'vic') {
      return 'VIC';
    }

    if (normalized.contains('queensland') ||
        normalized == 'qld') {
      return 'QLD';
    }

    if (normalized.contains('south australia') ||
        normalized == 'sa') {
      return 'SA';
    }

    if (normalized.contains('western australia') ||
        normalized == 'wa') {
      return 'WA';
    }

    if (normalized.contains('tasmania') ||
        normalized == 'tas') {
      return 'TAS';
    }

    if (normalized.contains('australian capital territory') ||
        normalized == 'act') {
      return 'ACT';
    }

    if (normalized.contains('northern territory') ||
        normalized == 'nt') {
      return 'NT';
    }

    return value.trim();
  }

  final city = firstNonEmpty([
    profile['city'],
    profile['suburb'],
    profile['locality'],
  ]);

  final rawState = firstNonEmpty([
    profile['selectedState'],
    profile['selectedStateKey'],
    profile['state'],
    profile['livingState'],
    profile['stateLiving'],
    profile['province'],
    profile['region'],
  ]);

  final country = firstNonEmpty([
    profile['selectedCountry'],
    profile['country'],
  ]);

  final state = shortState(rawState);

  final parts = <String>[];

  void addPart(String value) {
    final cleanValue = value.trim();

    if (cleanValue.isEmpty) return;

    final alreadyExists = parts.any(
      (item) => item.toLowerCase() == cleanValue.toLowerCase(),
    );

    if (!alreadyExists) {
      parts.add(cleanValue);
    }
  }

  addPart(city);
  addPart(state);
  addPart(country);

  return parts.join(', ');
}

  String _buildBornDisplay(Map<String, dynamic> profile, bool isVi) {
    final country = (profile['countryOfBirth'] ?? '').toString().trim();
    final city = (profile['cityOfBirth'] ??
            profile['birthCity'] ??
            profile['vietnamBirthCity'] ??
            profile['vietnamBirthProvince'] ??
            '')
        .toString()
        .trim();

    final normalizedCountry = country.toLowerCase();
    final vietnamValues = ['vietnam', 'việt nam'];

    if (vietnamValues.contains(normalizedCountry)) {
      final countryText = isVi ? 'Việt Nam' : 'Vietnam';
      if (city.isNotEmpty) {
        return '$countryText • $city';
      }
      return countryText;
    }

    return _translateProfileValue(country, isVi);
  }

  String _extractRelationshipGoalKey(Map<String, dynamic> profile) {
    final dynamic raw =
        profile['relationshipGoal'] ?? profile['relationshipGoals'];

    if (raw is List && raw.isNotEmpty) {
      return _normalizeString(raw.first);
    }

    return _normalizeString(raw);
  }
List<String> _extractRelationshipGoalKeys(
  Map<String, dynamic> profile,
) {
  final dynamic raw =
      profile['relationshipGoals'] ?? profile['relationshipGoal'];

  if (raw is List) {
    return raw
        .map((item) => _normalizeString(item))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  final value = _normalizeString(raw);

  if (value.isEmpty) {
    return [];
  }

  return [value];
}
int _mostCompatibleScore(Map<String, dynamic> profile) {
  int score = 0;

  final myGender = _normalizeGenderPreference(
    currentUserData?['gender'],
  );

  final myPreference = _normalizeGenderPreference(
    currentUserData?['datingPreference'] ??
        currentUserData?['genderPreference'],
  );

  final profileGender = _normalizeGenderPreference(
    profile['gender'],
  );

  final profilePreference = _normalizeGenderPreference(
    profile['datingPreference'] ??
        profile['genderPreference'],
  );

  // Hai bên đều đúng giới tính đang tìm
  final iLikeThem =
      myPreference == 'everyone' ||
      myPreference == profileGender;

  final theyLikeMe =
      profilePreference == 'everyone' ||
      profilePreference == myGender;

  if (iLikeThem && theyLikeMe) {
    score += 100;
  } else {
    // Không tương thích hai chiều thì không cộng điểm.
    return 0;
  }

  // Tuổi của người này nằm trong độ tuổi mình muốn
  final profileAge = _parseInt(profile['age']);

  if (selectedMinAgeFilter != null &&
      selectedMaxAgeFilter != null &&
      profileAge >= selectedMinAgeFilter! &&
      profileAge <= selectedMaxAgeFilter!) {
    score += 30;
  }

  // Tuổi của mình nằm trong độ tuổi người kia muốn
  final myAge = _parseInt(currentUserData?['age']);

  final theirMinAge = _parseInt(
    profile['minAgePreference'] ??
        profile['preferredMinAge'],
  );

  final theirMaxAge = _parseInt(
    profile['maxAgePreference'] ??
        profile['preferredMaxAge'],
  );

  if (myAge > 0 &&
      theirMinAge > 0 &&
      theirMaxAge > 0 &&
      myAge >= theirMinAge &&
      myAge <= theirMaxAge) {
    score += 30;
  }

  // Cùng mục tiêu mối quan hệ
  final myGoals = _extractRelationshipGoalKeys(
    currentUserData ?? {},
  ).toSet();

  final theirGoals =
      _extractRelationshipGoalKeys(profile).toSet();

  if (myGoals.isNotEmpty &&
      theirGoals.isNotEmpty &&
      myGoals.intersection(theirGoals).isNotEmpty) {
    score += 40;
  }

  // Cùng khu vực/bang
  final myState = _normalizeStateKey(
    currentUserData?['selectedStateKey'] ??
        currentUserData?['selectedState'] ??
        currentUserData?['state'] ??
        '',
  );

  final theirState = _normalizeStateKey(
    profile['selectedStateKey'] ??
        profile['selectedState'] ??
        profile['state'] ??
        '',
  );

  if (myState.isNotEmpty &&
      theirState.isNotEmpty &&
      myState == theirState) {
    score += 25;
  }

  // Đã xác minh ảnh
  if (profile['photoVerified'] == true) {
    score += 20;
  }

  // Đang online hoặc mới hoạt động
  if (_isOnlineRecently(profile)) {
    score += 20;
  } else if (_isRecentlyActive(profile)) {
    score += 10;
  }

  // Profile có nhiều ảnh
  final photos = _extractPhotos(profile);

  if (photos.length >= 3) {
    score += 15;
  } else if (photos.length >= 2) {
    score += 8;
  }

  return score;
}
  String _translateProfileValue(String raw, bool isVi) {
    final value = _normalizeString(raw);

    const viMap = {
      'single': 'Độc thân',
      'divorced': 'Ly hôn',
      'widowed': 'Góa',
      'separated': 'Ly thân',
      'never_married': 'Chưa từng kết hôn',
      'yes': 'Có',
      'no': 'Không',
      'sometimes': 'Thỉnh thoảng',
      'socially': 'Xã giao',
      'prefer_not_to_say': 'Không muốn chia sẻ',
      'serious_relationship': 'Mối quan hệ nghiêm túc',
      'long_term_partner': 'Bạn đời lâu dài',
      'friendship_first': 'Bắt đầu từ tình bạn',
      'chat_and_get_to_know': 'Trò chuyện và tìm hiểu',
      'citizen': 'Công dân',
      'permanent_resident': 'Thường trú nhân',
      'temporary_visa': 'Visa tạm trú',
      'student_visa': 'Visa du học',
      'working_holiday': 'Visa Working Holiday',
      'other': 'Khác',
      'buddhist': 'Phật giáo',
      'catholic': 'Công giáo',
      'christian': 'Cơ đốc giáo',
      'hindu': 'Ấn Độ giáo',
      'muslim': 'Hồi giáo',
      'jewish': 'Do Thái giáo',
      'sikh': 'Đạo Sikh',
      'taoist': 'Đạo giáo',
      'no_religion': 'Không tôn giáo',
      'education': 'Giáo dục',
      'healthcare': 'Y tế',
      'engineering': 'Kỹ sư',
      'it': 'Công nghệ thông tin',
      'business': 'Kinh doanh',
      'finance': 'Tài chính',
      'marketing': 'Marketing',
      'law': 'Luật',
      'hospitality': 'Nhà hàng - khách sạn',
      'construction': 'Xây dựng',
      'trades': 'Thợ nghề',
      'government': 'Chính phủ',
      'student': 'Sinh viên',
      'self_employed': 'Tự kinh doanh',
      'unemployed': 'Thất nghiệp',
      'female': 'Nữ',
      'male': 'Nam',
      'high_school': 'Trung học',
      'trade': 'Chứng chỉ nghề',
      'diploma': 'Cao đẳng',
      'bachelor': 'Đại học',
      'postgraduate': 'Sau đại học',
      'master': 'Thạc sĩ',
      'phd': 'Tiến sĩ',
      'under_40k': 'Dưới 40,000',
      '40_59k': '40,000 - 59,999',
      '60_79k': '60,000 - 79,999',
      '80_99k': '80,000 - 99,999',
      '100_119k': '100,000 - 119,999',
      '120_149k': '120,000 - 149,999',
      '150_plus': '150,000+',
      'want': 'Muốn có',
      'not_sure': 'Chưa chắc',
    };

    const enMap = {
      'độc thân': 'Single',
      'ly hôn': 'Divorced',
      'góa': 'Widowed',
      'ly thân': 'Separated',
      'chưa từng kết hôn': 'Never married',
      'có': 'Yes',
      'không': 'No',
      'thỉnh thoảng': 'Sometimes',
      'xã giao': 'Socially',
      'không muốn chia sẻ': 'Prefer not to say',
      'mối quan hệ nghiêm túc': 'Serious relationship',
      'bạn đời lâu dài': 'Long-term partner',
      'bắt đầu từ tình bạn': 'Friendship first',
      'trò chuyện và tìm hiểu': 'Chat and get to know each other',
      'Công dân': 'Citizen',
      'thường trú nhân': 'Permanent Resident',
      'visa tạm trú': 'Temporary Visa',
      'visa du học': 'Student Visa',
      'visa working holiday': 'Working Holiday Visa',
      'khác': 'Other',
      'phật giáo': 'Buddhist',
      'công giáo': 'Catholic',
      'cơ đốc giáo': 'Christian',
      'ấn độ giáo': 'Hindu',
      'hồi giáo': 'Muslim',
      'do thái giáo': 'Jewish',
      'đạo sikh': 'Sikh',
      'đạo giáo': 'Taoist',
      'không tôn giáo': 'No religion',
      'giáo dục': 'Education',
      'y tế': 'Healthcare',
      'kỹ sư': 'Engineering',
      'công nghệ thông tin': 'IT',
      'kinh doanh': 'Business',
      'tài chính': 'Finance',
      'marketing': 'Marketing',
      'luật': 'Law',
      'nhà hàng - khách sạn': 'Hospitality',
      'xây dựng': 'Construction',
      'thợ nghề': 'Trades',
      'chính phủ': 'Government',
      'sinh viên': 'Student',
      'tự kinh doanh': 'Self-employed',
      'thất nghiệp': 'Unemployed',
      'nữ': 'Female',
      'nam': 'Male',
      'trung học': 'High School',
      'chứng chỉ nghề': 'Trade Certificate',
      'cao đẳng': 'Diploma',
      'đại học': 'Bachelor Degree',
      'sau đại học': 'Postgraduate',
      'thạc sĩ': 'Master Degree',
      'tiến sĩ': 'Doctorate / PhD',
      'dưới 40,000 aud': 'Below 40,000',
      'muốn có': 'Want children',
      'chưa chắc': 'Not sure',
    };

    if (raw.trim().isEmpty) return '';
    return isVi ? (viMap[value] ?? raw) : (enMap[value] ?? raw);
  }

  String _firstNonEmpty(Map<String, dynamic> profile, List<String> keys) {
    for (final key in keys) {
      final value = (profile[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }
  Widget _buildContentLikeButton({
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.white,
    shape: const CircleBorder(),
    elevation: 4,
    child: InkWell(
      onTap: _isProcessingAction ? null : onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFFFD5E6),
          ),
        ),
        child: _isProcessingAction
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFCC3D7A),
                ),
              )
            : const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFCC3D7A),
                size: 25,
              ),
      ),
    ),
  );
}
Widget _buildSmallBadge({
  required IconData icon,
  required String text,
  required Color bgColor,
  required Color borderColor,
  required Color textColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: textColor,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
      ],
    ),
  );
}
  Widget _buildOnlineDot(bool isOnline) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
        boxShadow: [
          BoxShadow(
            color: (isOnline
                    ? const Color(0xFF2ECC71)
                    : const Color(0xFFE74C3C))
                .withOpacity(0.35),
            blurRadius: 10,
            spreadRadius: 1.2,
          ),
        ],
      ),
    );
  }

 Widget _buildMainCirclePhoto(String imageUrl) {
  return Container(
    width: 200,
    height: 200,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.grey.shade200,
      border: Border.all(
        color: Colors.white,
        width: 5,
      ),
      gradient: const LinearGradient(
        colors: [
          Color(0xFFFFE4EF),
          Color(0xFFFFF6FA),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFCC3D7A).withOpacity(0.18),
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: imageUrl.trim().isEmpty
          ? null
          : () {
              _openPhotoFullScreen(imageUrl);
            },
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: 200,
                height: 200,
                memCacheWidth: 600,
                placeholder: (context, url) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFCC3D7A),
                    ),
                  );
                },
                errorWidget: (context, url, error) {
                  return const Center(
                    child: Icon(
                      Icons.person,
                      size: 70,
                      color: Colors.grey,
                    ),
                  );
                },
              )
            : const Center(
                child: Icon(
                  Icons.person,
                  size: 70,
                  color: Colors.grey,
                ),
              ),
      ),
    ),
  );
}

Future<void> _openPhotoFullScreen(String imageUrl) async {
  if (imageUrl.trim().isEmpty) return;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        );
                      },
                      errorWidget: (context, url, error) {
                        return const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 80,
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  String _contentLikeDocumentId({
    required String ownerId,
    required String contentType,
    required String contentKey,
    required String likerId,
  }) => '${ownerId}_${contentType}_${contentKey}_$likerId';

  Future<void> _addContentThumbsUp({
    required Map<String, dynamic> targetProfile,
    required String contentType,
    required String contentKey,
    required String contentText,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final ownerId =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();
    if (ownerId.isEmpty || ownerId == user.uid) return;

    final ref = FirebaseFirestore.instance.collection('content_likes').doc(
      _contentLikeDocumentId(
        ownerId: ownerId,
        contentType: contentType,
        contentKey: contentKey,
        likerId: user.uid,
      ),
    );

    try {
      var removedLike = false;
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        removedLike = false;
        final existingLike = await transaction.get(ref);
        if (existingLike.exists) {
          transaction.delete(ref);
          removedLike = true;
        } else {
          transaction.set(ref, {
            'ownerId': ownerId,
            'likerId': user.uid,
            'likerName': (currentUserData?['firstName'] ?? '').toString().trim(),
            'likerPhotoUrl': (currentUserData?['mainPhotoUrl'] ?? '').toString().trim(),
            'contentType': contentType,
            'contentKey': contentKey,
            'contentText': contentText,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });

      if (removedLike && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_label('Đã bỏ thích.', 'Like removed.')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isVi ? 'Không thể cập nhật lượt thích.' : 'Could not update your Like.')),
        );
      }
      debugPrint('Content thumbs-up toggle error: $e');
    }
  }
  Future<void> _sendContentComment({
    required Map<String, dynamic> targetProfile,
    required String contentType,
    required String contentKey,
    required String contentText,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final ownerId = (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();
    if (ownerId.isEmpty || ownerId == user.uid) return;

    final controller = TextEditingController();
    final comment = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        bool canSend = false;
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVi ? 'Gửi bình luận' : 'Send a comment',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8A2F6A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 4,
                    minLines: 2,
                    maxLength: 500,
                    onChanged: (value) => setSheetState(() {
                      canSend = value.trim().isNotEmpty;
                    }),
                    decoration: InputDecoration(
                      hintText: isVi
                          ? 'Viết bình luận của bạn...'
                          : 'Write your comment...',
                      filled: true,
                      fillColor: const Color(0xFFFFF5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFFFD5E6)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFFFD5E6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(isVi ? 'Hủy' : 'Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: canSend
                              ? () => Navigator.pop(
                                    sheetContext,
                                    controller.text.trim(),
                                  )
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCC3D7A),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(isVi ? 'Gửi' : 'Send'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // The sheet's reverse transition keeps its TextField mounted briefly
    // after the route future completes. Dispose only after that transition.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();

    if (comment == null || comment.trim().isEmpty || !mounted) return;

    final chatId = _chatIdFor(user.uid, ownerId);
    final firestore = FirebaseFirestore.instance;
    final chatRef = firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final senderName = (currentUserData?['firstName'] ?? '').toString().trim();
    final ownerName = (targetProfile['firstName'] ?? '').toString().trim();
    try {
      final batch = firestore.batch();
      batch.set(chatRef, {
        'chatId': chatId,
        'participants': [user.uid, ownerId],
        'participantNames': {user.uid: senderName, ownerId: ownerName},
        'lastMessage': comment.trim(),
        'lastMessageType': 'text',
        'lastSenderId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(messageRef, {
        'senderId': user.uid,
        'receiverId': ownerId,
        'text': comment.trim(),
        'type': 'text',
        'contentType': contentType,
        'contentKey': contentKey,
        'contentText': contentText,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isVi ? 'Đã gửi bình luận.' : 'Comment sent.')),
        );
      }
    } catch (e) {
      debugPrint('Send content comment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isVi ? 'Không thể gửi bình luận.' : 'Could not send comment.')),
        );
      }
    }
  }

  Widget _buildContentEngagementRow({
    required Map<String, dynamic> targetProfile,
    required String contentType,
    required String contentKey,
    required String contentText,
  }) {
    final ownerId = (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();
    final userId = currentUser?.uid ?? '';
    if (ownerId.isEmpty || ownerId == userId) return const SizedBox.shrink();
    final likeRef = FirebaseFirestore.instance.collection('content_likes').doc(
      _contentLikeDocumentId(
        ownerId: ownerId,
        contentType: contentType,
        contentKey: contentKey,
        likerId: userId,
      ),
    );
    final likesQuery = FirebaseFirestore.instance.collection('content_likes')
        .where('ownerId', isEqualTo: ownerId)
        .where('contentType', isEqualTo: contentType)
        .where('contentKey', isEqualTo: contentKey);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: likesQuery.snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                final liked = snapshot.data?.docs.any((d) => d.id == likeRef.id) ?? false;
                return OutlinedButton.icon(
                  onPressed: () => _addContentThumbsUp(
                    targetProfile: targetProfile,
                    contentType: contentType,
                    contentKey: contentKey,
                    contentText: contentText,
                  ),
                  icon: Icon(
                    liked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                    size: 18,
                  ),
                  label: Text(
                    '${liked ? (isVi ? 'Bỏ thích' : 'Unlike') : (isVi ? 'Thích' : 'Thumbs Up')}${count > 0 ? ' ($count)' : ''}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFCC3D7A),
                    backgroundColor: liked ? const Color(0xFFFFE4EF) : Colors.transparent,
                    side: const BorderSide(color: Color(0xFFFFD5E6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _sendContentComment(
                targetProfile: targetProfile,
                contentType: contentType,
                contentKey: contentKey,
                contentText: contentText,
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text(isVi ? 'Bình luận' : 'Comment'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFCC3D7A),
                side: const BorderSide(color: Color(0xFFFFD5E6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePostsForDiscover(Map<String, dynamic> profile) {
    final ownerId = (profile['uid'] ?? profile['docId'] ?? '').toString().trim();
    if (ownerId.isEmpty) return const SizedBox.shrink();

    // My Profile stores each user's posts under users/{uid}/posts.
    // Read that same location here so Discover displays the exact same posts,
    // including uploaded post photos.
    final postsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('posts');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: postsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('LOAD DISCOVER PROFILE POSTS ERROR: ${snapshot.error}');
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final posts = [...snapshot.data!.docs];
        posts.sort((a, b) {
          final at = a.data()['createdAt'];
          final bt = b.data()['createdAt'];
          final ad = at is Timestamp ? at.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          final bd = bt is Timestamp ? bt.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
        if (posts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVi ? 'Bài viết' : 'Posts',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF8A2F6A),
              ),
            ),
            const SizedBox(height: 10),
            ...posts.map((doc) {
              final data = doc.data();
              final content = (data['content'] ?? '').toString().trim();
              final feeling = (data['feeling'] ?? '').toString().trim();
              final imageUrl = (data['imageUrl'] ?? '').toString().trim();
              if (content.isEmpty && feeling.isEmpty && imageUrl.isEmpty) {
                return const SizedBox.shrink();
              }
              final displayText = [
                if (feeling.isNotEmpty) feeling,
                if (content.isNotEmpty) content,
              ].join('\n\n');

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD5E6)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCC3D7A).withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (displayText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          displayText,
                          style: const TextStyle(fontSize: 15.5, height: 1.5),
                        ),
                      ),
                    if (imageUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () => _openPhotoFullScreen(imageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            width: double.infinity,
                            height: 310,
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: double.infinity,
                              height: 310,
                              fit: BoxFit.cover,
                              memCacheWidth: 1000,
                              placeholder: (_, __) => const SizedBox(
                                height: 310,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFCC3D7A),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    _buildContentEngagementRow(
                      targetProfile: profile,
                      contentType: 'post',
                      contentKey: doc.id,
                      contentText: displayText.isNotEmpty ? displayText : imageUrl,
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildDiscoverAvatar(
    String imageUrl,
    Map<String, dynamic> profile,
  ) {
    return Center(
      child: SizedBox(
        width: 270,
        height: 270,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
                border: Border.all(color: const Color(0xFFFFC9DE), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCC3D7A).withOpacity(0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: GestureDetector(
                  onTap: () => _openPhotoFullScreen(imageUrl),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: 270,
                    height: 270,
                    memCacheWidth: 720,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Color(0xFFCC3D7A)),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.person, size: 80, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: _buildAvatarAction(
                icon: Icons.tune_rounded,
                label: _label('Bộ lọc', 'Filter'),
                onTap: _openFilterSheet,
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: _buildAvatarAction(
                icon: Icons.flag_outlined,
                label: _label('Báo cáo', 'Report'),
                onTap: () => _showSafetyActionsSheet(profile),
                isReport: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingPassButton(Map<String, dynamic> profile) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _isProcessingAction
            ? null
            : () => _handlePass(targetProfile: profile),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: _isProcessingAction
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFCC3D7A),
                    ),
                  )
                : const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFCC3D7A),
                    size: 30,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isReport = false,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.96),
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: isReport ? Colors.red.shade700 : const Color(0xFFCC3D7A),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isReport ? Colors.red.shade700 : const Color(0xFFCC3D7A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  MoreAboutMePage _createMoreAboutMePage(Map<String, dynamic> profile) {
    final isVi = widget.languageCode == 'vi';
    final age = (profile['age'] ?? '').toString().trim();
    final livingState = _livingStateDisplay(profile);
    final bornDisplay = _buildBornDisplay(profile, isVi);

    String translated(List<String> keys) {
      return _translateProfileValue(_firstNonEmpty(profile, keys), isVi);
    }

    final gender = translated(['gender', 'selectedGender', 'userGender']);
    final religion = translated(['religion']);
    final highestDegree = translated(['highestDegree', 'highestEducation']);
    final occupation = translated(['jobTitle', 'occupation']);
    final annualIncome = translated(['annualIncome', 'income', 'yearlyIncome']);
    final height = _firstNonEmpty(profile, ['height', 'heightCm']);
    final haveChildren = translated([
      'haveChildren', 'children', 'childrenStatus', 'hasChildren',
    ]);
    final maritalStatus = translated(['maritalStatus']);
    final relationshipGoalsText = _extractRelationshipGoalKeys(profile)
        .map((goal) => _translateProfileValue(goal, isVi))
        .where((goal) => goal.trim().isNotEmpty)
        .join(', ');
    final residentStatus = translated(['residentStatus']);
    final drinking = translated(['drinking']);
    final smoking = translated(['smoking']);
    final aboutMe = (profile['aboutMe'] ?? profile['bio'] ?? '').toString().trim();

    final details = <MoreAboutMeDetail>[
      if (age.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.cake_outlined, label: _label('Tuổi', 'Age'), value: age),
      if (livingState.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.location_on_outlined, label: _label('Nơi sống', 'Location'), value: livingState),
      if (bornDisplay.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.public_rounded, label: _label('Nơi sinh', 'Place of birth'), value: bornDisplay),
      if (gender.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.person_outline_rounded, label: _label('Giới tính', 'Gender'), value: gender),
      if (religion.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.auto_awesome_outlined, label: _label('Tôn giáo', 'Religion'), value: religion),
      if (height.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.height_rounded, label: _label('Chiều cao', 'Height'), value: height),
      if (highestDegree.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.school_outlined, label: _label('Bằng cấp', 'Education'), value: highestDegree),
      if (occupation.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.work_outline_rounded, label: _label('Nghề nghiệp', 'Occupation'), value: occupation),
      if (annualIncome.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.payments_outlined, label: _label('Thu nhập năm', 'Annual income'), value: annualIncome),
      if (maritalStatus.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.favorite_outline_rounded, label: _label('Tình trạng hôn nhân', 'Marital status'), value: maritalStatus),
      if (haveChildren.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.child_care_outlined, label: _label('Con cái', 'Children'), value: haveChildren),
      if (relationshipGoalsText.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.favorite_border_rounded, label: _label('Mục tiêu hẹn hò', 'Relationship goals'), value: relationshipGoalsText),
      if (residentStatus.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.verified_user_outlined, label: _label('Tình trạng cư trú', 'Resident status'), value: residentStatus),
      if (drinking.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.wine_bar_outlined, label: _label('Uống rượu', 'Drinking'), value: drinking),
      if (smoking.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.smoke_free_outlined, label: _label('Hút thuốc', 'Smoking'), value: smoking),
    ];

    final photos = _extractPhotos(profile);
    final avatarUrl = photos.isNotEmpty
        ? photos.first
        : (profile['mainPhotoUrl'] ?? profile['photoUrl'] ?? '').toString().trim();

    return MoreAboutMePage(
      profile: profile,
      languageCode: widget.languageCode,
      aboutMe: aboutMe,
      details: details,
      avatarUrl: avatarUrl,
      location: livingState,
      onLike: () async {
        await _handleLike(targetProfile: profile);
        if (mounted) Navigator.of(context).pop();
      },
      onPass: () async {
        await _handlePass(targetProfile: profile);
        if (mounted) Navigator.of(context).pop();
      },
      onSendMessage: () async {
        final sent = await _handleFlower(targetProfile: profile);
        if (!sent || !mounted) return;

        // Flower sent successfully: return to Discover.
        // _handleFlower has already removed this profile from the Discover queue.
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildDiscoverMoreAboutMe(Map<String, dynamic> profile, bool isVi) {
    final age = (profile['age'] ?? '').toString().trim();
    final livingState = _livingStateDisplay(profile);
    final bornDisplay = _buildBornDisplay(profile, isVi);

    String translated(List<String> keys) {
      final raw = _firstNonEmpty(profile, keys);
      return _translateProfileValue(raw, isVi);
    }

    final gender = translated(['gender', 'selectedGender', 'userGender']);
    final religion = translated(['religion']);
    final highestDegree = translated(['highestDegree', 'highestEducation']);
    final occupation = translated(['jobTitle', 'occupation']);
    final annualIncome = translated(['annualIncome', 'income', 'yearlyIncome']);
    final height = _firstNonEmpty(profile, ['height', 'heightCm']);
    final haveChildren = translated([
      'haveChildren', 'children', 'childrenStatus', 'hasChildren',
    ]);
    final maritalStatus = translated(['maritalStatus']);
    final relationshipGoalsText = _extractRelationshipGoalKeys(profile)
        .map((goal) => _translateProfileValue(goal, isVi))
        .where((goal) => goal.trim().isNotEmpty)
        .join(', ');
    final residentStatus = translated(['residentStatus']);
    final drinking = translated(['drinking']);
    final smoking = translated(['smoking']);
    final aboutMe = (profile['aboutMe'] ?? profile['bio'] ?? '').toString().trim();

    final details = <MoreAboutMeDetail>[
      if (age.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.cake_outlined, label: _label('Tuổi', 'Age'), value: age),
      if (livingState.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.location_on_outlined, label: _label('Nơi sống', 'Location'), value: livingState),
      if (bornDisplay.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.public_rounded, label: _label('Nơi sinh', 'Place of birth'), value: bornDisplay),
      if (gender.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.person_outline_rounded, label: _label('Giới tính', 'Gender'), value: gender),
      if (religion.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.auto_awesome_outlined, label: _label('Tôn giáo', 'Religion'), value: religion),
      if (height.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.height_rounded, label: _label('Chiều cao', 'Height'), value: height),
      if (highestDegree.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.school_outlined, label: _label('Bằng cấp', 'Education'), value: highestDegree),
      if (occupation.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.work_outline_rounded, label: _label('Nghề nghiệp', 'Occupation'), value: occupation),
      if (annualIncome.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.payments_outlined, label: _label('Thu nhập năm', 'Annual income'), value: annualIncome),
      if (maritalStatus.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.favorite_outline_rounded, label: _label('Tình trạng hôn nhân', 'Marital status'), value: maritalStatus),
      if (haveChildren.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.child_care_outlined, label: _label('Con cái', 'Children'), value: haveChildren),
      if (relationshipGoalsText.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.favorite_border_rounded, label: _label('Mục tiêu hẹn hò', 'Relationship goals'), value: relationshipGoalsText),
      if (residentStatus.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.verified_user_outlined, label: _label('Tình trạng cư trú', 'Resident status'), value: residentStatus),
      if (drinking.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.wine_bar_outlined, label: _label('Uống rượu', 'Drinking'), value: drinking),
      if (smoking.isNotEmpty)
        MoreAboutMeDetail(icon: Icons.smoke_free_outlined, label: _label('Hút thuốc', 'Smoking'), value: smoking),
    ];

    final photos = _extractPhotos(profile);
    final avatarUrl = photos.isNotEmpty
        ? photos.first
        : (profile['mainPhotoUrl'] ?? profile['photoUrl'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14, bottom: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                  builder: (_) => _createMoreAboutMePage(profile),
                  ),
                );
              },
              icon: const Icon(Icons.person_search_rounded, size: 25),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _label('Thêm về tôi', 'More About Me'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _label('Chạm để xem thêm về tôi', 'Tap to learn more about me'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFCC3D7A),
                side: const BorderSide(color: Color(0xFFFFB8D2), width: 1.5),
                backgroundColor: const Color(0xFFFFF7FA),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                minimumSize: const Size(double.infinity, 76),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoBlock({
    required String imageUrl,
    required Map<String, dynamic> targetProfile,
    required int photoIndex,
  }) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.grey.shade200,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCC3D7A).withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: GestureDetector(
                  onTap: () => _openPhotoFullScreen(imageUrl),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 300,
                    memCacheWidth: 900,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Color(0xFFCC3D7A)),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.person, size: 70, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: _buildContentLikeButton(
                onTap: () => _handleContentLike(
                  targetProfile: targetProfile,
                  contentType: 'photo',
                  contentIndex: photoIndex,
                  contentText: imageUrl,
                ),
              ),
            ),
          ],
        ),
        _buildContentEngagementRow(
          targetProfile: targetProfile,
          contentType: 'photo',
          contentKey: photoIndex.toString(),
          contentText: imageUrl,
        ),
      ],
    );
  }

Widget _buildIncomingLikeCard({
  required Map<String, dynamic> profile,
}) {
  final rawIncomingLike = profile['incomingLike'];

  if (rawIncomingLike is! Map) {
    return const SizedBox.shrink();
  }

  final incomingLike =
      Map<String, dynamic>.from(rawIncomingLike);

  final contentType =
      (incomingLike['likedContentType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

  final contentText =
      (incomingLike['likedContentText'] ?? '')
          .toString()
          .trim();

  final comment =
      (incomingLike['likeComment'] ?? '')
          .toString()
          .trim();

  // Like thường không hiện khung đặc biệt.
  if (contentType.isEmpty) {
    return const SizedBox.shrink();
  }

  // Chỉ nhận Like ảnh hoặc prompt.
  if (contentType != 'photo' &&
      contentType != 'prompt') {
    return const SizedBox.shrink();
  }

  final firstName = _capitalizeName(
    (profile['firstName'] ?? '').toString(),
  );

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5F9),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: const Color(0xFFFFC9DE),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFCC3D7A).withOpacity(0.08),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFCC3D7A),
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                contentType == 'photo'
                    ? (isVi
                        ? '$firstName đã thích ảnh của bạn'
                        : '$firstName liked your photo')
                    : (isVi
                        ? '$firstName đã thích câu trả lời của bạn'
                        : '$firstName liked your prompt'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8B2E63),
                ),
              ),
            ),
          ],
        ),

        if (contentText.isNotEmpty) ...[
          const SizedBox(height: 14),

          if (contentType == 'photo')
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: contentText,
                width: 86,
                height: 86,
                fit: BoxFit.cover,
                memCacheWidth: 300,
                placeholder: (_, __) {
                  return Container(
                    width: 86,
                    height: 86,
                    alignment: Alignment.center,
                    color: Colors.grey.shade200,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFCC3D7A),
                      ),
                    ),
                  );
                },
                errorWidget: (_, __, ___) {
                  return Container(
                    width: 86,
                    height: 86,
                    alignment: Alignment.center,
                    color: Colors.grey.shade200,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),

          if (contentType == 'prompt')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFFD5E6),
                ),
              ),
              child: Text(
                contentText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: Color(0xFF444444),
                ),
              ),
            ),
        ],

        if (comment.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '“$comment”',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: Color(0xFF6D3152),
                height: 1.45,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
String _formatVoicePromptDuration(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;

  final minutes =
      (safeSeconds ~/ 60).toString().padLeft(2, '0');

  final remainingSeconds =
      (safeSeconds % 60).toString().padLeft(2, '0');

  return '$minutes:$remainingSeconds';
}

Widget _buildVoicePromptCard({
  required String audioUrl,
  required int durationSeconds,
}) {
  final isPlaying =
      _isVoicePromptPlaying &&
      _playingVoicePromptUrl == audioUrl;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFFFF3F8),
        ],
      ),
      border: Border.all(
        color: const Color(0xFFFFD5E6),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFCC3D7A).withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4EF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Color(0xFFE91E63),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _label(
                  'Hãy nghe tôi nói để hiểu rõ tôi hơn',
                  'Listen to me to get to know me better',
                ),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8B2E63),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            InkWell(
              onTap: _isVoicePromptLoading
    ? null
    : () async {
                try {
                  if (isPlaying) {
                    await _voicePromptPlayer.pause();

                    if (!mounted) return;

                    setState(() {
                      _isVoicePromptPlaying = false;
                      _playingVoicePromptUrl = null;
                    });

                    return;
                  }
if (!mounted) return;

setState(() {
  _isVoicePromptLoading = true;
});
                  await _voicePromptPlayer.stop();

                  await _voicePromptPlayer.play(
                    UrlSource(audioUrl),
                  );

                  if (!mounted) return;

                  setState(() {
  _isVoicePromptLoading = false;
  _isVoicePromptPlaying = true;
  _playingVoicePromptUrl = audioUrl;
});
              } catch (e) {
  debugPrint(
    'PLAY HOME VOICE PROMPT ERROR: $e',
  );

  if (!mounted) return;

  setState(() {
    _isVoicePromptLoading = false;
    _isVoicePromptPlaying = false;
    _playingVoicePromptUrl = null;
  });
}
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE91E63),
                ),
                child: _isVoicePromptLoading
    ? const SizedBox(
        width: 23,
        height: 23,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white,
        ),
      )
    : Icon(
        isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded,
        color: Colors.white,
        size: 30,
      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 Text(
  _isVoicePromptLoading
      ? _label('Đang tải...', 'Loading...')
      : isPlaying
          ? _label('Đang phát', 'Playing')
          : _label(
              'Bấm để nghe',
              'Tap to listen',
            ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4A2C40),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatVoicePromptDuration(
                      durationSeconds,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9A6380),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
Widget _buildSocialMediaSection({
  required String facebookUrl,
  required String instagramUrl,
  required String tiktokUrl,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: const Color(0xFFFFD5E6),
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFCC3D7A).withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _label('Mạng xã hội', 'Social media'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A2E6E),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            if (facebookUrl.isNotEmpty)
              InkWell(
                onTap: () => _openSocial(
                  value: facebookUrl,
                  platform: 'facebook',
                ),
                borderRadius: BorderRadius.circular(30),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFF1877F2),
                  child: Icon(
                    Icons.facebook,
                    color: Colors.white,
                  ),
                ),
              ),
            if (instagramUrl.isNotEmpty)
              InkWell(
                onTap: () => _openSocial(
                  value: instagramUrl,
                  platform: 'instagram',
                ),
                borderRadius: BorderRadius.circular(30),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.purple,
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                  ),
                ),
              ),
            if (tiktokUrl.isNotEmpty)
              InkWell(
                onTap: () => _openSocial(
                  value: tiktokUrl,
                  platform: 'tiktok',
                ),
                borderRadius: BorderRadius.circular(30),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.black,
                  child: Icon(
                    Icons.music_note,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
  Widget _buildPromptCard({
    required String question,
    required String answer,
    Map<String, dynamic>? targetProfile,
    int? promptIndex,
  }) {
    if (question.trim().isEmpty && answer.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final promptContent = [
      if (question.trim().isNotEmpty) question.trim(),
      if (answer.trim().isNotEmpty) answer.trim(),
    ].join('\n');

    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 70, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFFFF3F8)],
                ),
                border: Border.all(color: const Color(0xFFFFD5E6), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCC3D7A).withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (question.trim().isNotEmpty)
                    Text(question, style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900,
                      color: Color(0xFF8B2E63), height: 1.35,
                    )),
                  if (question.trim().isNotEmpty && answer.trim().isNotEmpty)
                    const SizedBox(height: 10),
                  if (answer.trim().isNotEmpty)
                    Text(answer, style: const TextStyle(
                      fontSize: 15.8, fontWeight: FontWeight.w600,
                      color: Color(0xFF444444), height: 1.55,
                    )),
                ],
              ),
            ),
            if (targetProfile != null && promptIndex != null)
              Positioned(
                right: 14,
                bottom: 14,
                child: _buildContentLikeButton(
                  onTap: () => _handleContentLike(
                    targetProfile: targetProfile,
                    contentType: 'prompt',
                    contentIndex: promptIndex,
                    contentText: promptContent,
                  ),
                ),
              ),
          ],
        ),
        if (targetProfile != null && promptIndex != null)
          _buildContentEngagementRow(
            targetProfile: targetProfile,
            contentType: 'prompt',
            contentKey: promptIndex.toString(),
            contentText: promptContent,
          ),
      ],
    );
  }

Widget _buildInfoSlide({
    required List<_InfoItem> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 162),
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFAFD),
            Color(0xFFFFE8F2),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFCFE1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC3D7A).withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
     child: Column(
  children: items
      .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.97),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        item.icon,
                        color: const Color(0xFFCC3D7A),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 12.8,
                              color: Color(0xFF9A6380),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.text,
                            style: const TextStyle(
                              fontSize: 16.2,
                              color: Color(0xFF383838),
                              fontWeight: FontWeight.w800,
                              height: 1.38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildHorizontalCareerSlider({
    required bool isVi,
    required String highestDegree,
    required String occupation,
    required String annualIncome,
  }) {
    final items = [
      if (highestDegree.isNotEmpty)
        _HorizontalInfoItem(
          icon: Icons.school_outlined,
          label: _label('Bằng cấp', 'Degree'),
          text: highestDegree,
        ),
      if (occupation.isNotEmpty)
        _HorizontalInfoItem(
          icon: Icons.work_outline_rounded,
          label: _label('Nghề nghiệp', 'Occupation'),
          text: occupation,
        ),
      if (annualIncome.isNotEmpty)
        _HorizontalInfoItem(
          icon: Icons.payments_outlined,
          label: _label('Thu nhập năm', 'Annual income'),
          text: annualIncome,
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = items[index];

          return Container(
            width: 230,
            margin: const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFAFD),
                  Color(0xFFFFE8F2),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFCFE1),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFCC3D7A).withOpacity(0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.97),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    item.icon,
                    color: const Color(0xFFCC3D7A),
                    size: 25,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9A6380),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.25,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      item.text,
                      style: const TextStyle(
                        fontSize: 16.2,
                        color: Color(0xFF383838),
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderPage({
    required String title,
  }) {
    return Container(
      color: Color.fromARGB(255, 255, 221, 234),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7A2E6E),
          ),
        ),
      ),
    );
  }

  String _bottomTitle(int index, bool isVi) {
    switch (index) {
      case 1:
        return isVi ? 'Tin nhắn' : 'Messages';
      case 2:
        return isVi ? 'Match' : 'Match';
      case 3:
        return isVi ? 'Vietlove' : 'Vietlove';
      case 4:
        return isVi ? 'Nâng cấp' : 'Upgrade';
      case 5:
        return isVi ? 'Hồ sơ của tôi' : 'My Profile';
      default:
        return isVi ? 'Kết nối Vietlove' : 'VietLove Connections';
    }
  }

  Widget _buildActionCircleButton({
    required VoidCallback? onTap,
    required IconData icon,
    required Color iconColor,
    required double size,
    Color backgroundColor = const Color.fromARGB(255, 255, 221, 234),
  }) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.14),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            color: iconColor,
            size: size * 0.42,
          ),
        ),
      ),
    );
  }

 Widget _buildFloatingActionBar(Map<String, dynamic> profile) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionCircleButton(
          onTap: _isProcessingAction
              ? null
              : () => _handlePass(targetProfile: profile),
          icon: Icons.close_rounded,
          iconColor: Colors.grey.shade700,
          size: 64,
          backgroundColor: Colors.white,
        ),

        const SizedBox(width: 28),

        _buildActionCircleButton(
          onTap: _isProcessingAction
              ? null
              : () => _handleLike(targetProfile: profile),
          icon: Icons.favorite_rounded,
          iconColor: const Color(0xFFCC3D7A),
          size: 72,
          backgroundColor: const Color(0xFFFFDDEA),
        ),

        const SizedBox(width: 28),

        _buildActionCircleButton(
          onTap: _isProcessingAction
              ? null
              : () => _handleFlower(targetProfile: profile),
          icon: Icons.local_florist_rounded,
          iconColor: const Color(0xFFCC3D7A),
          size: 64,
          backgroundColor: Colors.white,
        ),
      ],
    ),
  );
}
Widget _buildBreakTheIceCard({
  required Map<String, dynamic> targetProfile,
}) {
  final isVi = widget.languageCode == 'vi';

 final question = isVi
    ? 'Buổi hẹn đầu tiên lý tưởng của bạn là gì?'
    : 'What sounds like a perfect first date?';

final options = [
  {
    'key': 'coffee',
    'label': isVi ? '☕ Cà phê' : '☕ Coffee',
  },
  {
    'key': 'dinner',
    'label': isVi ? '🍽️ Ăn tối' : '🍽️ Dinner',
  },
  {
  'key': 'road_trip',
  'label': isVi ? '🚗 Đi road trip' : '🚗 Road trip',
},
{
  'key': 'netflix',
  'label': '📺 Netflix',
},
  {
    'key': 'beach',
    'label': isVi ? '🏖️ Đi biển' : '🏖️ Beach',
  },
  {
    'key': 'dog_walk',
    'label': isVi ? '🐶 Dắt cún đi dạo' : '🐶 Dog walk',
  },
];
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: const Color(0xFFFFD6E7),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVi ? '🧊 Phá băng' : '🧊 Break the Ice',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF7A2E6E),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),

        const SizedBox(height: 14),

        Wrap(
          spacing: 8,
          runSpacing: 8,
         children: options.map((option) {
  return InkWell(
    borderRadius: BorderRadius.circular(22),
    onTap: () async {
      await _saveBreakTheIceAnswer(
        targetProfile: targetProfile,
        answer: option['key']!,
      );

      await _handleLike(
        targetProfile: targetProfile,
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFFC8DC),
        ),
      ),
      child: Text(
        option['label']!,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}).toList(),
        ),

        const SizedBox(height: 10),

        Text(
          isVi
              ? 'Chọn một câu trả lời đồng nghĩa với việc gửi lượt thích 💕'
              : 'Choosing an answer will send a Like 💕',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    ),
  );
}
  Widget _buildHomeProfile(Map<String, dynamic> profile, bool isVi) {
    final photos = _extractPhotos(profile);
    final prompts = _extractPrompts(profile, isVi);
    final firstName = _capitalizeName((profile['firstName'] ?? '').toString());
    final displayName = firstName.isEmpty ? _label('Người dùng', 'User') : firstName;
    final age = _parseInt(profile['age']);
    final locationDisplay = _livingStateDisplay(profile);
    final lastSeenValue = profile['lastSeen'];
    final lastSeenAt = lastSeenValue is Timestamp
        ? lastSeenValue.toDate()
        : (lastSeenValue is DateTime ? lastSeenValue : null);
    final lastSeenAge = lastSeenAt == null
        ? null
        : DateTime.now().difference(lastSeenAt);
    final hasRecentHeartbeat = lastSeenAge != null &&
        !lastSeenAge.isNegative &&
        lastSeenAge <= const Duration(minutes: 15);
    final onlineNow = profile['isOnline'] == true && hasRecentHeartbeat;
    final recentlyActive = !onlineNow &&
        lastSeenAge != null &&
        !lastSeenAge.isNegative &&
        lastSeenAge <= const Duration(days: 3);
    final verified = profile['photoVerified'] == true;
    final avatar = photos.isNotEmpty
        ? photos.first
        : (profile['mainPhotoUrl'] ?? profile['photoUrl'] ?? '').toString().trim();

    // Main avatar is photo 1. The remaining photos and prompts are
    // displayed alternately: prompt 1, photo 2, prompt 2, photo 3, ...
    final alternatingContent = <Widget>[];
    final contentCount = max(photos.length - 1, prompts.length);
    for (var index = 0; index < contentCount; index++) {
      if (index < prompts.length) {
        final prompt = prompts[index];
        if ((prompt['question'] ?? '').trim().isNotEmpty ||
            (prompt['answer'] ?? '').trim().isNotEmpty) {
          alternatingContent.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildPromptCard(
                question: prompt['question'] ?? '',
                answer: prompt['answer'] ?? '',
                targetProfile: profile,
                promptIndex: index,
              ),
            ),
          );
        }
      }

      final photoIndex = index + 1;
      if (photoIndex < photos.length) {
        alternatingContent.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _buildPhotoBlock(
              imageUrl: photos[photoIndex],
              targetProfile: profile,
              photoIndex: photoIndex,
            ),
          ),
        );
      }
    }

    return RefreshIndicator(
      color: Colors.pink,
      onRefresh: () async {
        await _handleAuthChanged(currentUser);
        await _loadMyContactsForPrivacy();
        if (mounted) setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 112, 14, 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (avatar.isNotEmpty) _buildDiscoverAvatar(avatar, profile),
            const SizedBox(height: 14),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 7,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8A2F6A),
                    ),
                  ),
                  if (verified)
                    Tooltip(
                      message: isVi ? 'Ảnh đã xác minh' : 'Photo verified',
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 0,
                              top: 2,
                              child: Icon(
                                Icons.photo_camera_rounded,
                                color: Color(0xFF2196F3),
                                size: 19,
                              ),
                            ),
                            Positioned(
                              right: -1,
                              bottom: 0,
                              child: Icon(
                                Icons.check_circle,
                                color: Color(0xFF2196F3),
                                size: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (age != null && age > 0)
                    Text(
                      '$age ${isVi ? 'tuổi' : 'years old'}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF555555),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (locationDisplay.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: Color(0xFFCC3D7A),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          locationDisplay,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF555555),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (onlineNow || recentlyActive) ...[
              const SizedBox(height: 7),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onlineNow)
                      _buildOnlineDot(true)
                    else
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    const SizedBox(width: 5),
                    Text(
                      onlineNow
                          ? (isVi ? 'Đang online' : 'Online')
                          : (isVi ? 'Hoạt động gần đây' : 'Recently active'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF269B65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_isNewHere(profile)) ...[
              const SizedBox(height: 8),
              Center(
                child: _buildSmallBadge(
                  icon: Icons.auto_awesome_rounded,
                  text: isVi ? 'Mới tham gia' : 'New here',
                  bgColor: const Color(0xFFFFF0F7),
                  borderColor: const Color(0xFFE91E63),
                  textColor: const Color(0xFFE91E63),
                ),
              ),
            ],
            _buildDiscoverMoreAboutMe(profile, isVi),
            const SizedBox(height: 18),
            _buildProfilePostsForDiscover(profile),
            if (alternatingContent.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...alternatingContent,
            ],
            if (profile['showSocialMedia'] == true &&
                [
                  profile['facebookUrl'],
                  profile['instagramUrl'],
                  profile['tiktokUrl'],
                ].any((value) => value != null && value.toString().trim().isNotEmpty)) ...[
              const SizedBox(height: 12),
              _buildSocialMediaSection(
                facebookUrl: (profile['facebookUrl'] ?? '').toString().trim(),
                instagramUrl: (profile['instagramUrl'] ?? '').toString().trim(),
                tiktokUrl: (profile['tiktokUrl'] ?? '').toString().trim(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessingAction
                    ? null
                    : () => _handlePass(targetProfile: profile),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(_label('Hồ sơ tiếp theo', 'Next profile')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC3D7A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSafetyActionsSheet(Map<String, dynamic> profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _label('Tùy chọn an toàn', 'Safety options'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined, color: Colors.red),
                  title: Text(_label('Báo cáo người này', 'Report this user')),
                  subtitle: Text(
                    _label(
                      'Báo cáo và ẩn hồ sơ này khỏi HomePage',
                      'Report and hide this profile from HomePage',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportSheet(profile);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.block, color: Colors.black87),
                  title: Text(_label('Chặn người này', 'Block this user')),
                  subtitle: Text(
                    _label(
                      'Chặn và ẩn hồ sơ này ngay',
                      'Block and hide this profile immediately',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showBlockSheet(profile);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReportSheet(Map<String, dynamic> profile) {
    final reasonController = TextEditingController();
    String selectedReason = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label('Báo cáo người này', 'Report this user'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _label(
                      'Hãy chọn lý do và có thể viết thêm giải thích.',
                      'Please choose a reason and optionally add an explanation.',
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _reportReasonTile(
                    title: _label('Spam', 'Spam'),
                    selected: selectedReason,
                    onTap: (value) => setModalState(() => selectedReason = value),
                  ),
                  _reportReasonTile(
                    title: _label('Tài khoản giả', 'Fake profile'),
                    selected: selectedReason,
                    onTap: (value) => setModalState(() => selectedReason = value),
                  ),
                 
_reportReasonTile(
  title: _label(
    'Vấn đề an toàn trẻ em',
    'Child safety concern',
  ),
  selected: selectedReason,
  onTap: (value) => setModalState(() => selectedReason = value),
),

                  _reportReasonTile(
                    title: _label('Quấy rối', 'Harassment'),
                    selected: selectedReason,
                    onTap: (value) => setModalState(() => selectedReason = value),
                  ),
                  _reportReasonTile(
                    title: _label('Lý do khác', 'Other'),
                    selected: selectedReason,
                    onTap: (value) => setModalState(() => selectedReason = value),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: _label(
                        'Viết thêm giải thích của bạn.',
                        'Write your explanation.',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedReason.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _submitReport(
                                targetProfile: profile,
                                reason: selectedReason,
                                explanation: reasonController.text.trim(),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(
                        _label('Gửi báo cáo', 'Submit report'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _reportReasonTile({
    required String title,
    required String selected,
    required ValueChanged<String> onTap,
  }) {
    final isSelected = selected == title;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: const Color(0xFFE91E63),
      ),
      title: Text(title),
      onTap: () => onTap(title),
    );
  }

  void _showBlockSheet(Map<String, dynamic> profile) {
    final explanationController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _label('Chặn người này', 'Block this user'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _label(
                  'Bạn có thể viết thêm lý do nếu muốn.',
                  'You can add an explanation if you want.',
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: explanationController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _label(
                    'Viết thêm giải thích của bạn.',
                    'Write your explanation.',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _submitBlock(
                      targetProfile: profile,
                      explanation: explanationController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    _label('Chặn người này', 'Block this user'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitReport({
    required Map<String, dynamic> targetProfile,
    required String reason,
    required String explanation,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final currentUid = user.uid;
    final targetUid =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();

    if (targetUid.isEmpty || targetUid == currentUid) return;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'fromUserId': currentUid,
        'toUserId': targetUid,
        'reason': reason,
        'explanation': explanation,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('hidden_users')
          .doc(targetUid)
          .set({
        'uid': targetUid,
        'reason': reason,
        'explanation': explanation,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Đã gửi báo cáo và ẩn hồ sơ này.',
              'Report submitted and profile hidden.',
            ),
          ),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Có lỗi khi gửi báo cáo: $e',
              'Error submitting report: $e',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _submitBlock({
    required Map<String, dynamic> targetProfile,
    required String explanation,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final currentUid = user.uid;
    final targetUid =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();

    if (targetUid.isEmpty || targetUid == currentUid) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('blocked_users')
          .doc(targetUid)
          .set({
        'uid': targetUid,
        'explanation': explanation,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('hidden_users')
          .doc(targetUid)
          .set({
        'uid': targetUid,
        'explanation': explanation,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Đã chặn và ẩn hồ sơ này.',
              'User blocked and profile hidden.',
            ),
          ),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Có lỗi khi chặn người này: $e',
              'Error blocking user: $e',
            ),
          ),
        ),
      );
    }
  }


  Widget _buildBody() {
    if (_selectedBottomIndex == 0) {
     return FutureBuilder<List<Map<String, dynamic>>>(
 future: _profilesFuture ??= _startDiscoverProfilesLoad(),
        builder: (context, snapshot) {
       if (snapshot.connectionState == ConnectionState.waiting) {
  return Stack(
    fit: StackFit.expand,
    children: [
      Positioned(
        top: 86,
        left: 16,
        child: _buildAvatarAction(
          icon: Icons.tune_rounded,
          label: _label('Bộ lọc', 'Filter'),
          onTap: _openFilterSheet,
        ),
      ),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFE84D91),
                size: 48,
              ),
              const SizedBox(height: 18),
              const Text(
                'VietLove',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE84D91),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _label(
                  'Đang tìm thêm người phù hợp...',
                  'Finding more people for you...',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE84D91),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _label(
                  'Chờ một chút nhé! VietLove đang tìm những hồ sơ phù hợp hơn với bạn',
                  'Just a moment! VietLove is finding more suitable profiles for you',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 22),
              const CircularProgressIndicator(
                color: Color(0xFFE84D91),
              ),
            ],
          ),
        ),
      ),

    ],
  );
}

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _label(
                    'Có lỗi khi tải hồ sơ.',
                    'Error loading profiles',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }

          final profiles = _discoverProfiles;
return Stack(
  fit: StackFit.expand,
  children: [
    if (_isLoadingMoreDiscoverProfiles)
      Positioned(
        top: 86,
        left: 16,
        child: _buildAvatarAction(
          icon: Icons.tune_rounded,
          label: _label('Bộ lọc', 'Filter'),
          onTap: _openFilterSheet,
        ),
      ),
    // NỘI DUNG PROFILE / KHÔNG CÓ PROFILE
   if (profiles.isEmpty)
  _isLoadingMoreDiscoverProfiles
      ? Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFE84D91),
                  size: 48,
                ),
                const SizedBox(height: 18),
                Text(
                  _label(
                    'Đang tìm thêm người phù hợp với bạn...',
                    'Finding more people for you...',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE84D91),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _label(
                    'VietLove đang tìm thêm hồ sơ. Bạn chờ một chút nhé! ',
                    'VietLove is looking for more profiles. Just a moment! ',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 22),
                const CircularProgressIndicator(
                  color: Color(0xFFE84D91),
                ),
              ],
            ),
          ),
        )
      : Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(
                    _dailyDiscoverLimitReached
                        ? 'Bạn đã xem hết hồ sơ trong lượt này 😊\nHồ sơ mới sẽ được mở lại vào lượt tiếp theo.'
                        : 'Không có hồ sơ nào phù hợp với bộ lọc hiện tại.\nHãy thử thay đổi bộ lọc nhé. ❤️',
                    _dailyDiscoverLimitReached
                        ? 'You have reached the limit for this session 😊\nNew profiles will be available in the next session.'
                        : 'No profiles match your current filters.\nTry adjusting your filters. ❤️',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_dailyDiscoverLimitReached) ...[
                  const SizedBox(height: 24),
                  _buildDailyDiscoverCountdown(),
                ] else ...[
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openFilterSheet,
                      icon: const Icon(Icons.tune_rounded, size: 20),
                      label: Text(
                        _label('Điều chỉnh bộ lọc', 'Adjust filters'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE84D91),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        )
else
      FutureBuilder<bool>(
  future: _discoverProfileChecks.putIfAbsent(
    (profiles.first['docId'] ?? '').toString(),
    () => _isDiscoverProfileStillAvailable(profiles.first),
  ),
  builder: (context, checkSnapshot) {
    if (checkSnapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.pink),
      );
    }
if (checkSnapshot.hasError) {
  return Center(
    child: Text(
      _label(
        'Không thể kiểm tra hồ sơ. Vui lòng thử lại.',
        'Unable to verify profile. Please try again.',
      ),
    ),
  );
}
    if (checkSnapshot.data != true) {
      final invalidProfile = profiles.first;
      final invalidId =
          (invalidProfile['docId'] ?? '').toString();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _discoverProfiles.isEmpty) return;

        final currentId =
            (_discoverProfiles.first['docId'] ?? '').toString();

        if (currentId == invalidId) {
          _discoverProfileChecks.remove(invalidId);
          _removeDiscoverProfile(invalidProfile);
        }
      });

      return const SizedBox.shrink();
    }

    return _buildHomeProfile(profiles.first, isVi);
  },
),
    if (profiles.isNotEmpty)
      Positioned(
        left: 16,
        bottom: 18,
        child: _buildFloatingPassButton(profiles.first),
      ),

  ],
);
   
        },
      );
    }

    if (_selectedBottomIndex == 1) {
  return MessagesListPage(
    languageCode: widget.languageCode,
  );
}

    if (_selectedBottomIndex == 2) {
  return MatchPage(languageCode: widget.languageCode);
}
 if (_selectedBottomIndex == 3) {
  return MiniGamePage(
    languageCode: widget.languageCode,
    onConnectTap: () {
      setState(() {
        _selectedBottomIndex = 0;
      });
    },
  );
}

    if (_selectedBottomIndex == 4) {
      return UpgradeVipPage(
  languageCode: widget.languageCode,
  onPurchaseSuccess: () async {
    await _reloadCurrentUserData();
    if (!mounted) return;

    setState(() {
      _selectedBottomIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _label(
            'VIP đã được mở khóa. Bạn có thể dùng bộ lọc nâng cao ngay bây giờ.',
            'VIP has been unlocked. You can now use advanced filters.',
          ),
        ),
      ),
    );
  },
);
    }

    return MyProfilePage(languageCode: widget.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.languageCode == 'vi';

    
return PopScope(
  canPop: _selectedBottomIndex == 0 && !Platform.isAndroid,
  onPopInvoked: (didPop) {
    if (didPop) return;

    // Giữ nguyên hành vi: tab khác quay về Home.
    if (_selectedBottomIndex != 0) {
      setState(() {
        _selectedBottomIndex = 0;
      });
      return;
    }

    // Chỉ xử lý nhấn Back hai lần trên Android tại Home.
    if (Platform.isAndroid) {
      final now = DateTime.now();
      final lastPressed = _lastBackPressedAt;

      if (lastPressed == null ||
          now.difference(lastPressed) >
              const Duration(seconds: 2)) {
        _lastBackPressedAt = now;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                _label(
                  'Nhấn Back lần nữa để thoát ứng dụng',
                  'Press back again to exit',
                ),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        return;
      }

      SystemNavigator.pop();
    }
  },
  child: Scaffold(

      extendBodyBehindAppBar: _selectedBottomIndex == 0,
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
  automaticallyImplyLeading: false,
  backgroundColor:
      _selectedBottomIndex == 0 ? Colors.transparent : Colors.white,
  elevation: 0,
  foregroundColor: const Color(0xFF7A2E6E),
  centerTitle: true,
  title: Text(
    _bottomTitle(_selectedBottomIndex, isVi),
    style: const TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 22,
      color: Color(0xFF7A2E6E),
      letterSpacing: 0.2,
    ),
  ),
 actions: null,
),
    body: Container(
  decoration: _selectedBottomIndex == 0
      ? const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFDDEA),
              Color(0xFFFFEFF5),
              Color(0xFFFFFFFF),
            ],
          ),
        )
      : null,
  child: _selectedBottomIndex == 0
      ? Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/cherry_lixi.png',
                  width: MediaQuery.of(context).size.width,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topLeft,
                ),
              ),
            ),

            _buildBody(),
          ],
        )
      : _buildBody(),
),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomIndex,
      onTap: (index) async {
  // Từ tab Games hoặc Me quay về Home:
  // reload lại flowerBalance và dữ liệu user.
  if ((_selectedBottomIndex == 3 ||
        _selectedBottomIndex == 4 ||
        _selectedBottomIndex == 5) &&
    index == 0) {
    await _reloadCurrentUserData();

    if (!mounted) return;

    setState(() {
      _selectedBottomIndex = 0;
      _startDiscoverProfilesLoad();
    });

    return;
  }

  setState(() {
    _selectedBottomIndex = index;
  });
},
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF5C6BC0),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: _label('Home', 'Home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.message),
            label: _label('Message', 'Message'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite),
            label: _label('Match', 'Match'),
          ),
          BottomNavigationBarItem(
  icon: const Icon(Icons.sports_esports_rounded),
  label: _label('Activities', 'Activities'),
),
          BottomNavigationBarItem(
            icon: const Icon(Icons.workspace_premium),
            label: _label('Upgrade', 'Upgrade'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: _label('Me', 'Me'),
          ),
        ],
      ),
     ),
);
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String text;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.text,
  });
}

class _HorizontalInfoItem {
  final IconData icon;
  final String label;
  final String text;

  const _HorizontalInfoItem({
    required this.icon,
    required this.label,
    required this.text,
  });
}

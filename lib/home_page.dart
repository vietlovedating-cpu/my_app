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

  bool _isProcessingAction = false;
  int _selectedBottomIndex = 0;
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

int get _dailyDiscoverLimit => isVipUser ? 20 : 10;

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

  final resetTime = _discoverResetTime();

  // Chỉ dùng query đã có sẵn theo fromUserId,
  // tránh phải tạo thêm Firestore composite index.
  final snapshot = await FirebaseFirestore.instance
      .collection('swipes')
      .where('fromUserId', isEqualTo: user.uid)
      .get();

  int count = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();

    final action =
        (data['action'] ?? '').toString().trim().toLowerCase();

    // Chỉ tính những hành động Discover thật sự.
    if (action != 'pass' &&
        action != 'like' &&
        action != 'flower') {
      continue;
    }

    final createdAt = data['createdAt'];

    if (createdAt is! Timestamp) {
      continue;
    }

    final actionTime = createdAt.toDate();

    if (!actionTime.isBefore(resetTime)) {
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
        _profilesFuture = _loadProfilesWithDailyLimit();
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
      _selectedBottomIndex = 0;

      selectedGenderFilter = null;
      selectedMinAgeFilter = null;
      selectedMaxAgeFilter = null;
      selectedStateFilter = null;

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

    setState(() {
      currentUserData = data;

      selectedGenderFilter = _normalizeGenderPreference(
        data['datingPreference'] ?? data['genderPreference'],
      );

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

      _profilesFuture = _loadProfilesWithDailyLimit();
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

  setState(() {
    currentUserData = data;

selectedCountryFilter =
    newFilterCountry.isEmpty ? null : newFilterCountry;

selectedStateFilter =
    newFilterState.isEmpty ? null : newFilterState;

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
        ],
      );
    },
  );
}
  Future<List<Map<String, dynamic>>> _loadProfiles() async {
  final user = currentUser;
  if (user == null) return [];

  final currentUid = user.uid;

 final results = await Future.wait<dynamic>([
  _loadLikedMeData(),

  FirebaseFirestore.instance
      .collection('users')
      .get(),

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

boostedProfiles.shuffle(random);
onlineProfiles.shuffle(random);
activeDay1Profiles.shuffle(random);
activeDay2Profiles.shuffle(random);
activeDay3Profiles.shuffle(random);
normalProfiles.shuffle(random);
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
Future<List<Map<String, dynamic>>> _loadProfilesWithDailyLimit() async {
  // Tính số lượt còn lại trong chu kỳ hiện tại.
  final remaining = await _remainingDiscoverToday();

  _dailyDiscoverLimitReached = remaining <= 0;

  if (_dailyDiscoverLimitReached) {
    return [];
  }

  // Giữ nguyên toàn bộ logic tải, lọc và sắp xếp người mới.
 final newProfiles = await _loadProfiles();

final result = <Map<String, dynamic>>[];

// Luôn ưu tiên người mới trước.
result.addAll(newProfiles);

// Nếu chưa đủ quota thì bổ sung người đã Pass.
if (result.length < remaining) {
  final neededPassedProfiles =
      remaining - result.length;

  final passedProfiles =
      await _loadPreviouslyPassedProfiles(
    limit: neededPassedProfiles,
  );

  result.addAll(passedProfiles);
}
// Chỉ trả đúng số lượng còn lại hôm nay.
return result.take(remaining).toList();
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

  if (selectedDistanceKm != null) {
    final myLat = (currentUserData?['lat'] as num?)?.toDouble();
    final myLng = (currentUserData?['lng'] as num?)?.toDouble();

    final profileLat = (profile['lat'] as num?)?.toDouble();
    final profileLng = (profile['lng'] as num?)?.toDouble();

    if (myLat == null ||
        myLng == null ||
        profileLat == null ||
        profileLng == null) {
      return true;
    }if (selectedDistanceKm != null && selectedDistanceKm! > 0) {
  final myLat = (currentUserData?['lat'] as num?)?.toDouble();
  final myLng = (currentUserData?['lng'] as num?)?.toDouble();

  final profileLat = (profile['lat'] as num?)?.toDouble();
  final profileLng = (profile['lng'] as num?)?.toDouble();

  if (myLat == null ||
      myLng == null ||
      profileLat == null ||
      profileLng == null) {
    return true;
  }

  final distanceKm = _calculateDistanceKm(
    myLat,
    myLng,
    profileLat,
    profileLng,
  );

  // Không return false ở đây nữa.
}

    final distanceKm = _calculateDistanceKm(
      myLat,
      myLng,
      profileLat,
      profileLng,
    );

    
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
        selectedReligionFilter!.isNotEmpty &&
        _normalizeString(profile['religion']) != selectedReligionFilter) {
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

  Future<void> _handlePass({
  required Map<String, dynamic> targetProfile,
}) async {
  await _saveSwipe(
    targetProfile: targetProfile,
    action: 'pass',
  );

  if (!mounted) return;

  setState(() {
   _profilesFuture = _loadProfilesWithDailyLimit();
  });
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

  final commentController = TextEditingController();

  final result = await showDialog<String?>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(
          isVi ? 'Gửi lời nhắn cùng lượt thích' : 'Send a message with your like',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: commentController,
          maxLines: 4,
          maxLength: 250,
          decoration: InputDecoration(
            hintText: isVi
                ? 'Viết lời nhắn hoặc để trống...'
                : 'Write a message or leave it blank...',
            filled: true,
            fillColor: const Color(0xFFFFF3F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFFFD5E6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFCC3D7A),
                width: 1.3,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(
              isVi ? 'Huỷ' : 'Cancel',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                commentController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCC3D7A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              isVi ? 'Gửi Like' : 'Send Like',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );

 if (result == null || !mounted) {
  // Đợi dialog đóng hoàn toàn rồi mới dispose controller.
  await Future<void>.delayed(
    const Duration(milliseconds: 300),
  );
  commentController.dispose();
  return;
}

// Navigator.pop có animation.
// Không lưu Like và setState trong lúc dialog vẫn đang được tháo khỏi widget tree.
await Future<void>.delayed(
  const Duration(milliseconds: 300),
);

commentController.dispose();

if (!mounted) return;

final didMatch = await _saveSwipe(
  targetProfile: targetProfile,
  action: 'like',
  likedContentType: contentType,
  likedContentIndex: contentIndex,
  likedContentText: contentText,
  likeComment: result,
);

  if (!mounted) return;

  if (didMatch) {

  await _showMatchDialog(targetProfile);
}

  if (mounted) {
  setState(() {
  _profilesFuture = _loadProfilesWithDailyLimit();
  });
}
}
 Future<void> _handleLike({
  required Map<String, dynamic> targetProfile,
}) async {
  final didMatch = await _saveSwipe(
    targetProfile: targetProfile,
    action: 'like',
  );

  if (!mounted) return;

  if (didMatch) {
    await _showMatchDialog(targetProfile);
  }

  if (!mounted) return;

  setState(() {
   _profilesFuture = _loadProfilesWithDailyLimit();
  });
}
  Future<void> _handleFlower({
    required Map<String, dynamic> targetProfile,
  }) async {
    final user = currentUser;
    if (user == null) return;

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
      return;
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
                ? 'Viết vài lời cho người bạn thích nhé!'
                : 'Write a few words to someone you like!',
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
     ? '🌹 Bạn còn: $remaining hoa'
: '🌹 Flowers remaining: $remaining',
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
      return;
    }

    final canUseFlower = await _consumePurchasedFlowerIfNeeded();

if (!canUseFlower) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        isVi
            ? 'Bạn không còn flower. Vui lòng mua thêm flower.'
            : 'You have no flowers left. Please purchase more flowers.',
      ),
    ),
  );
  return;
}

await _saveSwipe(
  targetProfile: targetProfile,
  action: 'flower',
  flowerMessage: result,
);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi ? 'Đã gửi flower thành công.' : 'Flower sent successfully.',
        ),
      ),
    );

    setState(() {
 _profilesFuture = _loadProfilesWithDailyLimit();
});
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
                  '🎉🎉 It’s a Match with $targetName 🎉🎉',
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
                      : 'You and $targetName liked each other 💘💘💘',
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
      setState(() {});
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
  }, SetOptions(merge: true));
}

      if (!mounted) return;

      setState(() {
        _profilesFuture = _loadProfilesWithDailyLimit();
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
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
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
      'australian_citizen': 'Công dân Úc',
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
      'công dân úc': 'Australian Citizen',
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
      border: Border.all(color: Colors.white, width: 5),
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
    child: ClipOval(
      child: imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 600,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.pink),
              ),
              errorWidget: (context, url, error) {
                return const Center(
                  child: Icon(Icons.person, size: 74, color: Colors.grey),
                );
              },
            )
          : const Center(
              child: Icon(Icons.person, size: 74, color: Colors.grey),
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
  Widget _buildPhotoBlock({
  required String imageUrl,
  required Map<String, dynamic> targetProfile,
  required int photoIndex,
}) {
  return Stack(
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
  onTap: () {
    _openPhotoFullScreen(imageUrl);
  },
  child: CachedNetworkImage(
    imageUrl: imageUrl,
    fit: BoxFit.cover,
    width: double.infinity,
    height: 300,
    memCacheWidth: 900,
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
  ),
),
        ),
      ),

      Positioned(
        right: 16,
        bottom: 16,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 5,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _isProcessingAction
                ? null
                : () {
                    _handleContentLike(
                      targetProfile: targetProfile,
                      contentType: 'photo',
                      contentIndex: photoIndex,
                      contentText: imageUrl,
                    );
                  },
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD5E6),
                ),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFCC3D7A),
                size: 27,
              ),
            ),
          ),
        ),
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

  // Chỉ dùng khi prompt nằm trên Discover.
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

  return Stack(
    children: [
      Container(
        width: double.infinity,

        // Chừa thêm khoảng trống bên phải cho nút tim,
        // các phần layout khác giữ nguyên.
        padding: const EdgeInsets.fromLTRB(20, 20, 70, 20),
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
            if (question.trim().isNotEmpty)
              Text(
                question,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8B2E63),
                  height: 1.35,
                  letterSpacing: 0.1,
                ),
              ),
            if (question.trim().isNotEmpty &&
                answer.trim().isNotEmpty)
              const SizedBox(height: 10),
            if (answer.trim().isNotEmpty)
              Text(
                answer,
                style: const TextStyle(
                  fontSize: 15.8,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF444444),
                  height: 1.55,
                ),
              ),
          ],
        ),
      ),

      // Chỉ hiện khi đã truyền profile và số thứ tự prompt.
      if (targetProfile != null && promptIndex != null)
        Positioned(
          right: 14,
          bottom: 14,
          child: _buildContentLikeButton(
            onTap: () {
              _handleContentLike(
                targetProfile: targetProfile,
                contentType: 'prompt',
                contentIndex: promptIndex,
                contentText: promptContent,
              );
            },
          ),
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
        return isVi ? 'Games' : 'Games';
      case 4:
        return isVi ? 'Nâng cấp' : 'Upgrade';
      case 5:
        return isVi ? 'Hồ sơ của tôi' : 'My Profile';
      default:
        return isVi ? 'Khám phá' : 'Discover';
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
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionCircleButton(
            onTap: _isProcessingAction
                ? null
                : () => _handlePass(targetProfile: profile),
            icon: Icons.close_rounded,
            iconColor: Colors.black87,
            size: 64,
          ),
          _buildActionCircleButton(
            onTap: _isProcessingAction
                ? null
                : () => _handleFlower(targetProfile: profile),
            icon: Icons.local_florist_rounded,
            iconColor: Colors.white,
            size: 72,
            backgroundColor: const Color(0xFFFFD54F),
          ),
          _buildActionCircleButton(
            onTap: _isProcessingAction
                ? null
                : () => _handleLike(targetProfile: profile),
            icon: Icons.favorite_rounded,
            iconColor: Colors.white,
            size: 64,
            backgroundColor: const Color(0xFFE91E63),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeProfile(Map<String, dynamic> profile, bool isVi) {
    final photos = _extractPhotos(profile);
    final prompts = _extractPrompts(profile, isVi);
    final facebookUrl =
    (profile['facebookUrl'] ?? '').toString().trim();

final instagramUrl =
    (profile['instagramUrl'] ?? '').toString().trim();

final tiktokUrl =
    (profile['tiktokUrl'] ?? '').toString().trim();

final showSocialMedia =
    profile['showSocialMedia'] == true;

    String getPhoto(int index) {
      if (index < 0 || index >= photos.length) return '';
      return photos[index];
    }

    Map<String, String> getPrompt(int index) {
      if (index < 0 || index >= prompts.length) {
        return {'question': '', 'answer': ''};
      }
      return prompts[index];
    }

    final String firstName =
        _capitalizeName((profile['firstName'] ?? '').toString());
    final String displayName =
        firstName.isEmpty ? _label('Người dùng', 'User') : firstName;

    final String age = (profile['age'] ?? '').toString().trim();
    
String distanceText = '';

final myLat = (currentUserData?['lat'] as num?)?.toDouble();
final myLng = (currentUserData?['lng'] as num?)?.toDouble();
final profileLat = (profile['lat'] as num?)?.toDouble();
final profileLng = (profile['lng'] as num?)?.toDouble();

if (myLat != null && myLng != null && profileLat != null && profileLng != null) {
  final distanceKm = _calculateDistanceKm(
    myLat,
    myLng,
    profileLat,
    profileLng,
  );

  distanceText = isVi
      ? '${distanceKm.toStringAsFixed(0)} km xa'
      : '${distanceKm.toStringAsFixed(0)} km away';
}
    final String genderRaw = _firstNonEmpty(profile, [
  'gender',
  'selectedGender',
  'userGender',
]);

final String gender = _translateProfileValue(genderRaw, isVi);

    final String livingState = _livingStateDisplay(profile);
    final String bornDisplay = _buildBornDisplay(profile, isVi);
    final String religion = _translateProfileValue(
      _firstNonEmpty(profile, ['religion']),
      isVi,
    );

    final String highestDegree = _translateProfileValue(
      _firstNonEmpty(profile, ['highestDegree', 'highestEducation']),
      isVi,
    );

    final String occupation = _translateProfileValue(
      _firstNonEmpty(profile, ['jobTitle', 'occupation']),
      isVi,
    );

    final String annualIncome = _translateProfileValue(
      _firstNonEmpty(profile, ['annualIncome', 'income', 'yearlyIncome']),
      isVi,
    );

    final String height = _firstNonEmpty(profile, ['height', 'heightCm']);
final String haveChildren = _translateProfileValue(
  _firstNonEmpty(profile, [
    'haveChildren',
    'children',
    'childrenStatus',
    'hasChildren',
  ]),
  isVi,
);
    final String maritalStatus = _translateProfileValue(
      _firstNonEmpty(profile, ['maritalStatus']),
      isVi,
    );

    final String childrenText = _translateProfileValue(
  (profile['haveChildren'] ?? '').toString(),
  isVi,
);

String relationshipGoal = _extractRelationshipGoalKey(profile);
relationshipGoal = _translateProfileValue(relationshipGoal, isVi);

    final String residentStatus = _translateProfileValue(
      _firstNonEmpty(profile, ['residentStatus']),
      isVi,
    );

    final String drinking = _translateProfileValue(
      _firstNonEmpty(profile, ['drinking']),
      isVi,
    );

    final String smoking = _translateProfileValue(
      _firstNonEmpty(profile, ['smoking']),
      isVi,
    );

    return Stack(
      children: [
        RefreshIndicator(
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
                _buildIncomingLikeCard(
  profile: profile,
),
                Center(
                  child: _buildMainCirclePhoto(
                    getPhoto(0).isNotEmpty
                        ? getPhoto(0)
                        : (profile['mainPhotoUrl'] ?? '').toString().trim(),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Color(0xFF8A2F6A),
            height: 1.1,
            letterSpacing: 0.2,
          ),
        ),
      ),
      if (_isOnlineRecently(profile)) ...[
  const SizedBox(width: 10),
  _buildOnlineDot(true),
],
    ],
  ),
),
                const SizedBox(height: 22),
                                if (_isNewHere(profile) || profile['photoVerified'] == true) ...[
  const SizedBox(height: 8),
  Center(
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_isNewHere(profile))
          _buildSmallBadge(
            icon: Icons.auto_awesome_rounded,
            text: isVi ? 'Mới tham gia' : 'New here',
            bgColor: const Color(0xFFFFF0F7),
            borderColor: const Color(0xFFE91E63),
            textColor: const Color(0xFFE91E63),
          ),
        if (profile['photoVerified'] == true)
          _buildSmallBadge(
            icon: Icons.verified_rounded,
            text: isVi ? 'Ảnh đã xác minh' : 'Photo Verified',
            bgColor: const Color(0xFFE8F4FF),
            borderColor: const Color(0xFF2196F3),
            textColor: const Color(0xFF1976D2),
          ),
      ],
    ),
  ),
],
                const SizedBox(height: 14),
              _buildInfoSlide(
  items: [
    if (_isRecentlyActive(profile))
      _InfoItem(
        icon: Icons.access_time_rounded,
        label: _label('Hoạt động', 'Activity'),
        text: _label(
          'Online gần đây',
          'Recently online',
        ),
      ),

    if (age.isNotEmpty)
      _InfoItem(
        icon: Icons.cake_outlined,
        label: _label('Tuổi', 'Age'),
        text: age,
      ),
  
      if (distanceText.isNotEmpty)
  _InfoItem(
    icon: Icons.location_on_outlined,
    label: _label('Khoảng cách', 'Distance'),
    text: distanceText,
  ),
  if (livingState.isNotEmpty)
  _InfoItem(
    icon: Icons.location_on_outlined,
    label: _label('Khu vực', 'Location'),
    text: livingState,
  ),

    if (gender.isNotEmpty)
      _InfoItem(
        icon: Icons.person_outline_rounded,
        label: _label('Giới tính', 'Gender'),
        text: gender,
      ),
  ],
),
                if (getPhoto(1).isNotEmpty) ...[
                  const SizedBox(height: 18),
                 _buildPhotoBlock(
  imageUrl: getPhoto(1),
  targetProfile: profile,
  photoIndex: 1,
),
                ],
                if (getPrompt(0)['question']!.isNotEmpty ||
                    getPrompt(0)['answer']!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildPromptCard(
  question: getPrompt(0)['question'] ?? '',
  answer: getPrompt(0)['answer'] ?? '',
  targetProfile: profile,
  promptIndex: 0,
),
if ((profile['voicePromptAudioUrl'] ?? '')
    .toString()
    .trim()
    .isNotEmpty)
  const SizedBox(height: 16),

if ((profile['voicePromptAudioUrl'] ?? '')
    .toString()
    .trim()
    .isNotEmpty)
  _buildVoicePromptCard(
    audioUrl: (profile['voicePromptAudioUrl'] ?? '')
        .toString()
        .trim(),
    durationSeconds:
        profile['voicePromptDuration'] is int
            ? profile['voicePromptDuration'] as int
            : int.tryParse(
                  (profile['voicePromptDuration'] ?? '0')
                      .toString(),
                ) ??
                0,
  ),
                ],
                _buildInfoSlide(
                  items: [
                    if (bornDisplay.isNotEmpty)
                      _InfoItem(
                        icon: Icons.public,
                        label: _label('Nơi sinh', 'Born'),
                        text: bornDisplay,
                      ),
                    if (religion.isNotEmpty)
                      _InfoItem(
                        icon: Icons.auto_awesome_outlined,
                        label: _label('Tôn giáo', 'Religion'),
                        text: religion,
                      ),
                      if (height.isNotEmpty)
  _InfoItem(
    icon: Icons.height_rounded,
    label: _label('Chiều cao', 'Height'),
    text: height,
  ),

                  ],
                ),
                if (getPhoto(2).isNotEmpty) ...[
                  const SizedBox(height: 18),
                 _buildPhotoBlock(
  imageUrl: getPhoto(2),
  targetProfile: profile,
  photoIndex: 2,
),
                ],
                if (getPrompt(1)['question']!.isNotEmpty ||
                    getPrompt(1)['answer']!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildPromptCard(
  question: getPrompt(1)['question'] ?? '',
  answer: getPrompt(1)['answer'] ?? '',
  targetProfile: profile,
  promptIndex: 1,
),
                ],
                _buildHorizontalCareerSlider(
                  isVi: isVi,
                  highestDegree: highestDegree,
                  occupation: occupation,
                  annualIncome: annualIncome,
                ),
                if (getPhoto(3).isNotEmpty) ...[
                  const SizedBox(height: 18),
                 _buildPhotoBlock(
  imageUrl: getPhoto(3),
  targetProfile: profile,
  photoIndex: 3,
),
                ],
                if (getPrompt(2)['question']!.isNotEmpty ||
                    getPrompt(2)['answer']!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                 _buildPromptCard(
  question: getPrompt(2)['question'] ?? '',
  answer: getPrompt(2)['answer'] ?? '',
  targetProfile: profile,
  promptIndex: 2,
),
                ],
                _buildInfoSlide(
  items: [
    if (maritalStatus.isNotEmpty)
      _InfoItem(
        icon: Icons.favorite_outline_rounded,
        label: _label('Tình trạng hôn nhân', 'Marital status'),
        text: maritalStatus,
      ),

   if ((profile['haveChildren'] ?? '').toString().trim().isNotEmpty)
  _InfoItem(
    icon: Icons.child_care_outlined,
    label: _label('Con cái', 'Children'),
    text: _translateProfileValue(
      (profile['haveChildren'] ?? '').toString(),
      isVi,
    ),
  ),

  ],
),
if (_extractRelationshipGoalKeys(profile).isNotEmpty)
  Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xFFFFD6E7),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _label(
            '💕 Mục tiêu hẹn hò',
            '💕 Relationship goals',
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _extractRelationshipGoalKeys(profile).map((goal) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDF4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _translateProfileValue(goal, isVi),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9C2859),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  ),
                if (getPhoto(4).isNotEmpty) ...[
                  const SizedBox(height: 18),
                 _buildPhotoBlock(
  imageUrl: getPhoto(4),
  targetProfile: profile,
  photoIndex: 4,
),
                ],
                if (getPrompt(3)['question']!.isNotEmpty ||
                    getPrompt(3)['answer']!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                 _buildPromptCard(
  question: getPrompt(3)['question'] ?? '',
  answer: getPrompt(3)['answer'] ?? '',
  targetProfile: profile,
  promptIndex: 3,
),
                ],
                _buildInfoSlide(
                  items: [
                    if (residentStatus.isNotEmpty)
                      _InfoItem(
                        icon: Icons.verified_user_outlined,
                        label: _label('Tình trạng cư trú', 'Resident status'),
                        text: residentStatus,
                      ),
                    if (drinking.isNotEmpty)
                      _InfoItem(
                        icon: Icons.wine_bar_outlined,
                        label: _label('Uống rượu', 'Drink'),
                        text: drinking,
                      ),
                    if (smoking.isNotEmpty)
                      _InfoItem(
                        icon: Icons.smoke_free_outlined,
                        label: _label('Hút thuốc', 'Smoke'),
                        text: smoking,
                      ),
                  ],
                ),
                if (getPrompt(4)['question']!.isNotEmpty ||
                    getPrompt(4)['answer']!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                 _buildPromptCard(
  question: getPrompt(4)['question'] ?? '',
  answer: getPrompt(4)['answer'] ?? '',
  targetProfile: profile,
  promptIndex: 4,
),
                ],
                const SizedBox(height: 22),

if (showSocialMedia &&
    (facebookUrl.isNotEmpty ||
        instagramUrl.isNotEmpty ||
        tiktokUrl.isNotEmpty))
  _buildSocialMediaSection(
    facebookUrl: facebookUrl,
    instagramUrl: instagramUrl,
    tiktokUrl: tiktokUrl,
  ),

const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        Positioned(
          top: 118,
          right: 18,
          child: Material(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showSafetyActionsSheet(profile),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 18,
          child: _buildFloatingActionBar(profile),
        ),
      ],
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
                      'Nội dung không phù hợp',
                      'Inappropriate content',
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
 future: _profilesFuture ??= _loadProfilesWithDailyLimit(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.pink),
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

          final profiles = snapshot.data ?? [];

         if (profiles.isEmpty) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _label(
  _dailyDiscoverLimitReached
      ? isVipUser
          ? 'Bạn đã xem hết hồ sơ trong lượt này 😊\nHồ sơ mới sẽ được mở lại vào lượt tiếp theo.'
          : 'Bạn đã xem hết hồ sơ trong lượt này 😊\nHồ sơ mới sẽ được mở lại vào lượt tiếp theo.'
      : 'Không có hồ sơ nào phù hợp với bộ lọc hiện tại.\nHãy thử thay đổi bộ lọc nhé. ❤️',
  _dailyDiscoverLimitReached
      ? isVipUser
          ? 'You have reached the limit for this session 😊\nNew profiles will be available in the next session.'
          : 'You have reached the limit for this session 😊\nNew profiles will be available in the next session.'
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
          ],
        ],
      ),
    ),
  );
}

return _buildHomeProfile(profiles.first, isVi);
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
  canPop: _selectedBottomIndex == 0,
  onPopInvoked: (didPop) {
    if (didPop) return;

    if (_selectedBottomIndex != 0) {
      setState(() {
        _selectedBottomIndex = 0;
      });
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
  actions: _selectedBottomIndex == 0
      ? [
          Container(
            margin: const EdgeInsets.only(right: 10),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFFB83280),
                  size: 22,
                ),
              ),
              onPressed: _openFilterSheet,
            ),
          ),
        ]
      : null,
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
        child: _buildBody(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomIndex,
      onTap: (index) async {
  // Từ tab Games hoặc Me quay về Home:
  // reload lại flowerBalance và dữ liệu user.
  if ((_selectedBottomIndex == 3 ||
          _selectedBottomIndex == 5) &&
      index == 0) {
    await _reloadCurrentUserData();

    if (!mounted) return;

    setState(() {
      _selectedBottomIndex = 0;
      _profilesFuture = _loadProfilesWithDailyLimit();
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
  label: _label('Games', 'Games'),
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

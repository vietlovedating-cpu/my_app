import 'dart:async';

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


class HomePage extends StatefulWidget {
  final String languageCode;

  const HomePage({
    super.key,
    required this.languageCode,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  StreamSubscription<User?>? _authSub;

  bool _isProcessingAction = false;
  int _selectedBottomIndex = 0;
Set<String> _myContactPhones = {};
Set<String> _myContactEmails = {};
bool _contactsLoaded = false;
  Map<String, dynamic>? currentUserData;
  String? _lastUid;

  String? selectedGenderFilter;
  int? selectedMinAgeFilter;
  int? selectedMaxAgeFilter;
  String? selectedStateFilter;

  String? selectedReligionFilter;
  String? selectedRelationshipGoalFilter;
  String? selectedMaritalStatusFilter;
  String? selectedResidentStatusFilter;
  String? selectedEducationFilter;
  String? selectedSmokingFilter;
  String? selectedDrinkingFilter;
  String? selectedHaveChildrenFilter;

  bool get isVi => widget.languageCode == 'vi';
  bool get isVipUser => _hasVipAccess(currentUserData);

  final List<String> stateOptions = const [
    '',
    'nsw',
    'vic',
    'qld',
    'wa',
    'sa',
    'tas',
    'act',
    'nt',
  ];

  final List<int> ageOptions = List.generate(63, (index) => index + 18);

  @override
void initState() {
  super.initState();
  _handleAuthChanged(FirebaseAuth.instance.currentUser);
  _loadMyContactsForPrivacy();
  _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
    _handleAuthChanged(user);
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
    _authSub?.cancel();
    super.dispose();
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
      selectedResidentStatusFilter = null;
      selectedEducationFilter = null;
      selectedSmokingFilter = null;
      selectedDrinkingFilter = null;
      selectedHaveChildrenFilter = null;
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

      selectedStateFilter = _normalizeString(
        data['selectedState'] ?? data['state'],
      );

      if (selectedMinAgeFilter == 0) selectedMinAgeFilter = null;
      if (selectedMaxAgeFilter == 0) selectedMaxAgeFilter = null;
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

    setState(() {
      currentUserData = data;
    });
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
  Future<List<Map<String, dynamic>>> _loadProfiles() async {
  final user = currentUser;
  if (user == null) return [];

  final currentUid = user.uid;

  final usersSnapshot =
      await FirebaseFirestore.instance.collection('users').get();

  final swipesSnapshot = await FirebaseFirestore.instance
      .collection('swipes')
      .where('fromUserId', isEqualTo: currentUid)
      .get();

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

  final profiles = <Map<String, dynamic>>[];

  for (final doc in usersSnapshot.docs) {
    final data = doc.data();
    final uid = (data['uid'] ?? doc.id).toString().trim();

    if (uid.isEmpty) continue;
    if (uid == currentUid) continue;
    if (swipedUserIds.contains(uid)) continue;
    if (hiddenUserIds.contains(uid)) continue;
    if (blockedUserIds.contains(uid)) continue;
    if (data['profileCompleted'] != true) continue;

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
    };

    // ẩn nếu người này có trong danh bạ của mình
    if (_shouldHideUserBecauseInMyContacts(profile)) continue;

    if (!_matchesFilters(profile)) continue;
    profiles.add(profile);
  }

  return profiles;
}
Future<List<Map<String, dynamic>>> _loadTopPicks() async {
  final profiles = await _loadProfiles();

  int scoreProfile(Map<String, dynamic> profile) {
    int score = 0;

    final profileState = _normalizeString(
      profile['selectedState'] ?? profile['state'],
    );

    final myState = _normalizeString(
      currentUserData?['selectedState'] ?? currentUserData?['state'],
    );

    final profileAge = _parseInt(profile['age']);

    if (myState.isNotEmpty && profileState == myState) {
      score += 30;
    }

    if (selectedMinAgeFilter != null && selectedMaxAgeFilter != null) {
      if (profileAge >= selectedMinAgeFilter! &&
          profileAge <= selectedMaxAgeFilter!) {
        score += 25;
      }
    }

    final photos = _extractPhotos(profile);
    if (photos.length >= 3) {
      score += 20;
    } else if (photos.length >= 2) {
      score += 10;
    }

    if (profile['isOnline'] == true) {
      score += 10;
    }

    final relationshipGoal = _extractRelationshipGoalKey(profile);
    final myGoal = _normalizeString(
      currentUserData?['relationshipGoal'] ??
          currentUserData?['relationshipGoals'],
    );

    if (myGoal.isNotEmpty && relationshipGoal == myGoal) {
      score += 15;
    }

    return score;
  }

  profiles.sort((a, b) => scoreProfile(b).compareTo(scoreProfile(a)));

  return profiles.take(6).toList();
}
  bool _matchesFilters(Map<String, dynamic> profile) {
    final profileGender = _normalizeGenderPreference(profile['gender']);
    final profileAge = _parseInt(profile['age']);
    final profileState = _normalizeString(
      profile['selectedState'] ?? profile['state'],
    );

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

    if (selectedStateFilter != null &&
        selectedStateFilter!.isNotEmpty &&
        profileState != selectedStateFilter) {
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

    return true;
  }

  Future<void> _handlePass({
    required Map<String, dynamic> targetProfile,
  }) async {
    await _saveSwipe(
      targetProfile: targetProfile,
      action: 'pass',
    );
    if (mounted) setState(() {});
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

    setState(() {});
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
                  ? 'Bạn đã dùng hết 3 lượt flower miễn phí. Hãy mua VIP hoặc mua thêm \$1.99 cho 1 flower.'
                  : 'You have used all 3 free flowers. Please buy VIP or purchase 1 extra flower for \$1.99.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isVi ? 'Để sau' : 'Later'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedBottomIndex = 4;
                  });
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
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  isVi ? 'Nhập lời nhắn của bạn...' : 'Write your message...',
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(isVi ? 'Huỷ' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
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

    setState(() {});
  }

  Future<bool> _saveSwipe({
    required Map<String, dynamic> targetProfile,
    required String action,
    String? flowerMessage,
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
        'createdAt': FieldValue.serverTimestamp(),
      });
if (action == 'like') {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(targetUid)
      .collection('likedBy')
      .doc(currentUid)
      .set({
    'uid': currentUid,
    'firstName': (currentUserData?['firstName'] ?? '').toString().trim(),
    'age': currentUserData?['age'],
    'photoUrl': (currentUserData?['mainPhotoUrl'] ?? '').toString().trim(),
    'mainPhotoUrl': (currentUserData?['mainPhotoUrl'] ?? '').toString().trim(),
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
          await _createMatch(targetProfile: targetProfile);
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

  Future<bool> _canSendFlower() async {
    final user = currentUser;
    if (user == null) return false;
    if (isVipUser) return true;

    final snapshot = await FirebaseFirestore.instance
        .collection('swipes')
        .where('fromUserId', isEqualTo: user.uid)
        .where('action', isEqualTo: 'flower')
        .get();

    return snapshot.docs.length < 3;
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
          initialState: selectedStateFilter,
          initialReligion: selectedReligionFilter,
          initialRelationshipGoal: selectedRelationshipGoalFilter,
          initialMaritalStatus: selectedMaritalStatusFilter,
          initialResidentStatus: selectedResidentStatusFilter,
          initialEducation: selectedEducationFilter,
          initialSmoking: selectedSmokingFilter,
          initialDrinking: selectedDrinkingFilter,
          initialHaveChildren: selectedHaveChildrenFilter,
          stateOptions: stateOptions,
          ageOptions: ageOptions,
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
              selectedStateFilter = _normalizeString(
                currentUserData?['selectedState'] ?? currentUserData?['state'],
              );
              if (selectedMinAgeFilter == 0) selectedMinAgeFilter = null;
              if (selectedMaxAgeFilter == 0) selectedMaxAgeFilter = null;
              selectedReligionFilter = null;
              selectedRelationshipGoalFilter = null;
              selectedMaritalStatusFilter = null;
              selectedResidentStatusFilter = null;
              selectedEducationFilter = null;
              selectedSmokingFilter = null;
              selectedDrinkingFilter = null;
              selectedHaveChildrenFilter = null;
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
        selectedStateFilter = result.state;

        if (isVipUser) {
          selectedReligionFilter = result.religion;
          selectedRelationshipGoalFilter = result.relationshipGoal;
          selectedMaritalStatusFilter = result.maritalStatus;
          selectedResidentStatusFilter = result.residentStatus;
          selectedEducationFilter = result.education;
          selectedSmokingFilter = result.smoking;
          selectedDrinkingFilter = result.drinking;
          selectedHaveChildrenFilter = result.haveChildren;
        } else {
          selectedReligionFilter = null;
          selectedRelationshipGoalFilter = null;
          selectedMaritalStatusFilter = null;
          selectedResidentStatusFilter = null;
          selectedEducationFilter = null;
          selectedSmokingFilter = null;
          selectedDrinkingFilter = null;
          selectedHaveChildrenFilter = null;
        }
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

    final isVip = data['isVip'];
    final vipUnlocked = data['vipUnlocked'];
    final membership = _normalizeString(data['membership']);
    final plan = _normalizeString(data['plan']);
    final subscription = _normalizeString(data['subscriptionType']);

    return isVip == true ||
        vipUnlocked == true ||
        membership == 'vip' ||
        plan == 'vip' ||
        subscription == 'vip' ||
        membership == 'premium' ||
        plan == 'premium' ||
        subscription == 'premium';
  }

  String _normalizeString(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString()) ?? 0;
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
    final candidates = [
      profile['selectedState'],
      profile['state'],
      profile['livingState'],
      profile['stateLiving'],
    ];

    for (final item in candidates) {
      final value = (item ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }

    final address = (profile['address'] ?? '').toString().trim();
    if (address.isNotEmpty) return address;

    return '';
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
      'under_40k': 'Dưới 40,000 AUD',
      '40_59k': '40,000 - 59,999 AUD',
      '60_79k': '60,000 - 79,999 AUD',
      '80_99k': '80,000 - 99,999 AUD',
      '100_119k': '100,000 - 119,999 AUD',
      '120_149k': '120,000 - 149,999 AUD',
      '150_plus': '150,000+ AUD',
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
      'dưới 40,000 aud': 'Below 40,000 AUD',
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
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.pink),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
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

  Widget _buildPhotoBlock(String imageUrl) {
    return Container(
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
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.pink),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.grey,
                    ),
                  );
                },
              )
            : const Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
      ),
    );
  }

  Widget _buildPromptCard({
    required String question,
    required String answer,
  }) {
    if (question.trim().isEmpty && answer.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
          if (question.trim().isNotEmpty && answer.trim().isNotEmpty)
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
        return isVi ? 'Nhóm' : 'Group';
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
    final bool isOnline = profile['isOnline'] == true;

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

    final String maritalStatus = _translateProfileValue(
      _firstNonEmpty(profile, ['maritalStatus']),
      isVi,
    );

    final String haveChildren = _translateProfileValue(
      _firstNonEmpty(profile, ['haveChildren', 'hasChildren', 'childrenStatus']),
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
                      const SizedBox(width: 10),
                      _buildOnlineDot(isOnline),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
               _buildInfoSlide(
  items: [
    if (age.isNotEmpty)
      _InfoItem(
        icon: Icons.cake_outlined,
        label: _label('Tuổi', 'Age'),
        text: age,
      ),
    if (gender.isNotEmpty)
      _InfoItem(
        icon: Icons.person_outline_rounded,
        label: _label('Giới tính', 'Gender'),
        text: gender,
      ),
    if (livingState.isNotEmpty)
      _InfoItem(
        icon: Icons.location_on_outlined,
        label: _label('Bang đang sống', 'State living'),
        text: livingState,
      ),
  ],
),
                if (getPhoto(1).isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _buildPhotoBlock(getPhoto(1)),
                ],
                if (getPrompt(0)['question']!.isNotEmpty ||
                    getPrompt(0)['answer']!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildPromptCard(
                    question: getPrompt(0)['question']!,
                    answer: getPrompt(0)['answer']!,
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
                  ],
                ),
                if (getPhoto(2).isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _buildPhotoBlock(getPhoto(2)),
                ],
                if (getPrompt(1)['question']!.isNotEmpty ||
                    getPrompt(1)['answer']!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildPromptCard(
                    question: getPrompt(1)['question']!,
                    answer: getPrompt(1)['answer']!,
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
                  _buildPhotoBlock(getPhoto(3)),
                ],
                if (getPrompt(2)['question']!.isNotEmpty ||
                    getPrompt(2)['answer']!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildPromptCard(
                    question: getPrompt(2)['question']!,
                    answer: getPrompt(2)['answer']!,
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
                    if (haveChildren.isNotEmpty)
                      _InfoItem(
                        icon: Icons.child_care_outlined,
                        label: _label('Có con', 'Have children'),
                        text: haveChildren,
                      ),
                    if (relationshipGoal.isNotEmpty)
                      _InfoItem(
                        icon: Icons.flag_circle_outlined,
                        label: _label('Mục tiêu hẹn hò', 'Relationship goal'),
                        text: relationshipGoal,
                      ),
                  ],
                ),
                if (getPhoto(4).isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _buildPhotoBlock(getPhoto(4)),
                ],
                if (getPrompt(3)['question']!.isNotEmpty ||
                    getPrompt(3)['answer']!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildPromptCard(
                    question: getPrompt(3)['question']!,
                    answer: getPrompt(3)['answer']!,
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
                    question: getPrompt(4)['question']!,
                    answer: getPrompt(4)['answer']!,
                  ),
                ],
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
        future: _loadProfiles(),
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
                child: Text(
                  _label(
                    'Hiện chưa còn hồ sơ nào để xem.',
                    'No more profiles to show.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
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
      return GroupPage(languageCode: widget.languageCode);
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

    return Scaffold(
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
        onTap: (index) {
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
            icon: const Icon(Icons.groups),
            label: _label('Group', 'Group'),
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

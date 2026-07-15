import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'view_other_profile_page.dart';

class GuessGamePage extends StatefulWidget {
  final String languageCode;

  const GuessGamePage({
    super.key,
    required this.languageCode,
  });

  @override
  State<GuessGamePage> createState() => _GuessGamePageState();
}

class _GuessGamePageState extends State<GuessGamePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSubmitting = false;

  String? _errorMessage;

  List<Map<String, dynamic>> _candidates = [];

  String _correctUserId = '';
  String? _selectedUserId;

  int _attemptsUsed = 0;

  bool _completed = false;
  bool _won = false;

  bool get isVi => widget.languageCode == 'vi';

  User? get currentUser => FirebaseAuth.instance.currentUser;

  String _tr(String vi, String en) {
    return isVi ? vi : en;
  }

  @override
  void initState() {
    super.initState();

    _loadOrCreateGuessGame();
  }

  // ============================================================
  // DATE KEY
  // Mỗi ngày dùng một document riêng.
  // Ví dụ: 2026-07-15
  // ============================================================

  String _todayKey() {
    final now = DateTime.now();

    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  DocumentReference<Map<String, dynamic>> _todayGameRef(
    String currentUid,
  ) {
    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('guessGameDaily')
        .doc(_todayKey());
  }

  // ============================================================
  // LOAD OR CREATE GAME
  // ============================================================

  Future<void> _loadOrCreateGuessGame() async {
    final user = currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _tr(
          'Không tìm thấy tài khoản.',
          'Account not found.',
        );
      });

      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final gameRef = _todayGameRef(user.uid);
      final existingGameDoc = await gameRef.get();

      if (existingGameDoc.exists) {
        final existingData = existingGameDoc.data() ?? {};

        final attemptsUsed = _parseInt(
          existingData['attemptsUsed'],
        );

        final completed =
            existingData['completed'] == true;

        /*
        Nếu user chưa đoán lần nào, kiểm tra lại dữ liệu mới nhất.

        Mục đích:
        - Không dùng người mà user vừa Pass/Like/Flower.
        - Không dùng tài khoản vừa xóa, pause hoặc block.
        */
        if (attemptsUsed == 0 && !completed) {
          final stillValid = await _validateExistingGame(
            existingData,
          );

          if (!stillValid) {
            await _deleteUnstartedGame(
              gameRef: gameRef,
              gameData: existingData,
            );

            await _createNewGame(
              currentUid: user.uid,
            );

            return;
          }
        }

        await _loadExistingGame(existingData);
        return;
      }

      await _createNewGame(
        currentUid: user.uid,
      );
    } catch (e) {
      debugPrint('GUESS GAME LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _tr(
          'Không thể tải trò chơi. Vui lòng thử lại.',
          'Unable to load the game. Please try again.',
        );
      });
    }
  }

  // ============================================================
  // VALIDATE EXISTING GAME
  // Chỉ chạy khi attemptsUsed == 0
  // ============================================================

  Future<bool> _validateExistingGame(
    Map<String, dynamic> gameData,
  ) async {
    final user = currentUser;
    if (user == null) return false;

    final candidateIds = _stringList(
      gameData['candidateUserIds'],
    );

    final correctUserId =
        (gameData['correctUserId'] ?? '')
            .toString()
            .trim();

    if (candidateIds.length != 4) {
      return false;
    }

    if (correctUserId.isEmpty ||
        !candidateIds.contains(correctUserId)) {
      return false;
    }

    final swipedUserIds =
        await _loadMySwipedUserIds(user.uid);

    /*
    Nếu bất kỳ candidate nào đã có trong swipes,
    bộ game cũ không còn phù hợp.
    */
    if (candidateIds.any(swipedUserIds.contains)) {
      return false;
    }

    final blockedIds = await _loadBlockedUserIds(
      user.uid,
    );

    if (candidateIds.any(blockedIds.contains)) {
      return false;
    }

    for (final candidateId in candidateIds) {
      final candidateDoc = await _firestore
          .collection('users')
          .doc(candidateId)
          .get();

      if (!candidateDoc.exists) {
        return false;
      }

      final profile = {
        'docId': candidateDoc.id,
        ...(candidateDoc.data() ?? {}),
      };

      if (!_isProfileAvailable(profile)) {
        return false;
      }
    }

    /*
    Kiểm tra người đúng vẫn còn trong likedBy.
    */
    final correctLikeDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('likedBy')
        .doc(correctUserId)
        .get();

    if (!correctLikeDoc.exists) {
      return false;
    }

    return true;
  }

  // ============================================================
  // DELETE GAME CHƯA BẮT ĐẦU
  // Chỉ xóa khi attemptsUsed == 0
  // ============================================================

  Future<void> _deleteUnstartedGame({
    required DocumentReference<Map<String, dynamic>> gameRef,
    required Map<String, dynamic> gameData,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final candidateIds = _stringList(
      gameData['candidateUserIds'],
    );

    final batch = _firestore.batch();

    batch.delete(gameRef);

    /*
    Xóa temporary hidden cũ để game mới tạo lại.
    Chỉ xóa nếu hidden document thuộc đúng game hôm nay.
    */
    for (final candidateId in candidateIds) {
      final hiddenRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('guessHiddenUsers')
          .doc(candidateId);

      batch.delete(hiddenRef);
    }

    await batch.commit();
  }

  // ============================================================
  // LOAD EXISTING GAME
  // ============================================================

  Future<void> _loadExistingGame(
    Map<String, dynamic> gameData,
  ) async {
    final candidateIds = _stringList(
      gameData['candidateUserIds'],
    );

    final loadedCandidates =
        await _loadProfilesByIds(candidateIds);

    /*
    Giữ đúng thứ tự candidate đã lưu trong Firestore.
    Không shuffle lại mỗi lần mở app.
    */
    final profileByUid = <String, Map<String, dynamic>>{};

    for (final profile in loadedCandidates) {
      final uid = _profileUid(profile);

      if (uid.isNotEmpty) {
        profileByUid[uid] = profile;
      }
    }

    final orderedCandidates = <Map<String, dynamic>>[];

    for (final uid in candidateIds) {
      final profile = profileByUid[uid];

      if (profile != null) {
        orderedCandidates.add(profile);
      }
    }

    if (!mounted) return;

    setState(() {
      _candidates = orderedCandidates;

      _correctUserId =
          (gameData['correctUserId'] ?? '')
              .toString()
              .trim();

      _attemptsUsed = _parseInt(
        gameData['attemptsUsed'],
      );

      _completed = gameData['completed'] == true;
      _won = gameData['won'] == true;

      _selectedUserId =
          (gameData['lastSelectedUserId'] ?? '')
                  .toString()
                  .trim()
                  .isEmpty
              ? null
              : (gameData['lastSelectedUserId'] ?? '')
                  .toString()
                  .trim();

      _isLoading = false;
    });
  }

  // ============================================================
  // CREATE NEW GAME
  // ============================================================

  Future<void> _createNewGame({
    required String currentUid,
  }) async {
    /*
    Luôn đọc lại toàn bộ dữ liệu mới nhất khi tạo game.
    */
    final results = await Future.wait<dynamic>([
      // 0: Những người đã Like current user.
      _firestore
          .collection('users')
          .doc(currentUid)
          .collection('likedBy')
          .get(),

      // 1: Những người current user đã swipe.
      _firestore
          .collection('swipes')
          .where(
            'fromUserId',
            isEqualTo: currentUid,
          )
          .get(),

      // 2: Tất cả user để chọn 3 người giả.
      _firestore.collection('users').get(),

      // 3: Những người bị block.
      _firestore
          .collection('users')
          .doc(currentUid)
          .collection('blocked_users')
          .get(),

      // 4: Những người bị hidden.
      _firestore
          .collection('users')
          .doc(currentUid)
          .collection('hidden_users')
          .get(),

      // 5: Những người đang được game Guess khác ẩn.
      _firestore
          .collection('users')
          .doc(currentUid)
          .collection('guessHiddenUsers')
          .get(),

      // 6: Dữ liệu current user để kiểm tra preference.
      _firestore
          .collection('users')
          .doc(currentUid)
          .get(),
    ]);

    final likedBySnapshot =
        results[0]
            as QuerySnapshot<Map<String, dynamic>>;

    final swipesSnapshot =
        results[1]
            as QuerySnapshot<Map<String, dynamic>>;

    final usersSnapshot =
        results[2]
            as QuerySnapshot<Map<String, dynamic>>;

    final blockedSnapshot =
        results[3]
            as QuerySnapshot<Map<String, dynamic>>;

    final hiddenSnapshot =
        results[4]
            as QuerySnapshot<Map<String, dynamic>>;

    final guessHiddenSnapshot =
        results[5]
            as QuerySnapshot<Map<String, dynamic>>;

    final currentUserDoc =
        results[6]
            as DocumentSnapshot<Map<String, dynamic>>;

    final currentUserData =
        currentUserDoc.data() ?? {};

    // ==========================================================
    // USERS ĐÃ SWIPE
    // Pass, Like, Flower, Like photo, Like prompt đều nằm ở đây.
    // ==========================================================

    final swipedUserIds = swipesSnapshot.docs
        .map(
          (doc) => (doc.data()['toUserId'] ?? '')
              .toString()
              .trim(),
        )
        .where((uid) => uid.isNotEmpty)
        .toSet();

    final blockedUserIds = blockedSnapshot.docs
        .map((doc) => doc.id.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet();

    final hiddenUserIds = hiddenSnapshot.docs
        .map((doc) => doc.id.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet();

    // ==========================================================
    // ACTIVE GUESS HIDDEN USERS
    // Chỉ loại những người có hiddenUntil còn hiệu lực.
    // ==========================================================

    final activeGuessHiddenIds = <String>{};
    final now = DateTime.now();

    for (final doc in guessHiddenSnapshot.docs) {
      final data = doc.data();
      final hiddenUntil = data['hiddenUntil'];

      if (hiddenUntil is Timestamp &&
          hiddenUntil.toDate().isAfter(now)) {
        activeGuessHiddenIds.add(doc.id);
      }
    }

    // ==========================================================
    // LOAD TẤT CẢ PROFILE VÀO MAP
    // ==========================================================

    final allProfilesByUid =
        <String, Map<String, dynamic>>{};

    for (final userDoc in usersSnapshot.docs) {
  final profile = <String, dynamic>{
    'docId': userDoc.id,
    ...userDoc.data(),
  };

  final documentUid = userDoc.id.trim();

  if (documentUid.isEmpty) continue;

  // Map theo document ID chuẩn của Firebase.
  allProfilesByUid[documentUid] = profile;

  // Tương thích dữ liệu cũ nếu bên trong user document có field uid.
  final fieldUid =
      (userDoc.data()['uid'] ?? '').toString().trim();

  if (fieldUid.isNotEmpty) {
    allProfilesByUid[fieldUid] = profile;
  }
}

    // ==========================================================
    // NHỮNG NGƯỜI ĐÃ LIKE CURRENT USER
    // ==========================================================

    final allLikerIds = likedBySnapshot.docs
        .map((doc) => doc.id.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet();

    final validRealLikers =
        <Map<String, dynamic>>[];

    for (final likedByDoc in likedBySnapshot.docs) {
      final likerUid = likedByDoc.id.trim();
      debugPrint('GUESS CHECK LIKER: $likerUid');

      if (likerUid.isEmpty) continue;
      if (likerUid == currentUid) continue;

      /*
      Người current user đã Pass/Like/Flower rồi
      không được đưa vào Guess.
      */
      if (swipedUserIds.contains(likerUid)) {
        continue;
      }

      if (blockedUserIds.contains(likerUid)) {
        continue;
      }

      if (hiddenUserIds.contains(likerUid)) {
        continue;
      }

      if (activeGuessHiddenIds.contains(likerUid)) {
        continue;
      }

    final profile = allProfilesByUid[likerUid];

if (profile == null) {
  debugPrint(
    'LOAI $likerUid: KHONG TIM THAY TRONG users, '
    'mapContains=${allProfilesByUid.containsKey(likerUid)}',
  );
  continue;
}

debugPrint(
  'TIM THAY PROFILE $likerUid: '
  'docId=${profile['docId']}, uid=${profile['uid']}',
);

    if (!_isProfileAvailable(profile)) {
  debugPrint(
    'LOAI $likerUid: PROFILE KHONG AVAILABLE '
    'profileCompleted=${profile['profileCompleted']}, '
    'mainPhotoUrl=${(profile['mainPhotoUrl'] ?? '').toString().isNotEmpty}, '
    'showMyProfile=${profile['showMyProfile']}, '
    'showOnDiscover=${profile['showOnDiscover']}, '
    'accountPaused=${profile['accountPaused']}, '
    'isPaused=${profile['isPaused']}, '
    'isDeleted=${profile['isDeleted']}',
  );
  continue;
}

     if (!_isMutuallyCompatible(
  myProfile: currentUserData,
  otherProfile: profile,
)) {
  debugPrint(
  'LOAI $likerUid: KHONG TUONG THICH '
  'myGender=${currentUserData['gender']}, '
  'myDatingPreference=${currentUserData['datingPreference']}, '
  'myGenderPreference=${currentUserData['genderPreference']}, '
  'myFinalPreference=${currentUserData['datingPreference'] ?? currentUserData['genderPreference']}, '
  'theirGender=${profile['gender']}, '
  'theirDatingPreference=${profile['datingPreference']}, '
  'theirGenderPreference=${profile['genderPreference']}, '
  'theirFinalPreference=${profile['datingPreference'] ?? profile['genderPreference']}',
);
  continue;
}
debugPrint('GIU LAI LIKER: $likerUid');
      validRealLikers.add(profile);
    }

    /*
    Không có người Like thật thì không tạo game giả.
    */
    debugPrint(
  'GUESS DEBUG: likedBy=${likedBySnapshot.docs.length}, '
  'validRealLikers=${validRealLikers.length}',
);
    if (validRealLikers.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _candidates = [];
        _errorMessage = null;
      });

      return;
    }

    final random = Random();

    validRealLikers.shuffle(random);

    final correctProfile = validRealLikers.first;
    final correctUserId = _profileUid(
      correctProfile,
    );

    // ==========================================================
    // CHỌN 3 NGƯỜI GIẢ
    // Người giả không được là bất kỳ người nào trong likedBy.
    // Như vậy chỉ có đúng 1 người thực sự Like user.
    // ==========================================================

    final fakeCandidates =
        <Map<String, dynamic>>[];

    for (final profile in allProfilesByUid.values) {
      final uid = _profileUid(profile);

      if (uid.isEmpty) continue;
      if (uid == currentUid) continue;
      if (uid == correctUserId) continue;

      /*
      Không dùng bất kỳ người nào đã Like current user
      làm người giả.
      */
      if (allLikerIds.contains(uid)) {
        continue;
      }

      if (swipedUserIds.contains(uid)) {
        continue;
      }

      if (blockedUserIds.contains(uid)) {
        continue;
      }

      if (hiddenUserIds.contains(uid)) {
        continue;
      }

      if (activeGuessHiddenIds.contains(uid)) {
        continue;
      }

      if (!_isProfileAvailable(profile)) {
        continue;
      }

      if (!_isMutuallyCompatible(
        myProfile: currentUserData,
        otherProfile: profile,
      )) {
        continue;
      }

      fakeCandidates.add(profile);
    }

    fakeCandidates.shuffle(random);
debugPrint(
  'GUESS DEBUG: fakeCandidates=${fakeCandidates.length}',
);
    if (fakeCandidates.length < 3) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _candidates = [];
        _errorMessage = _tr(
          'Hiện chưa có đủ hồ sơ phù hợp để tạo trò chơi.',
          'There are not enough suitable profiles to create the game.',
        );
      });

      return;
    }

    final selectedCandidates =
        <Map<String, dynamic>>[
      correctProfile,
      ...fakeCandidates.take(3),
    ];

    selectedCandidates.shuffle(random);

    final candidateIds = selectedCandidates
        .map(_profileUid)
        .where((uid) => uid.isNotEmpty)
        .toList();

    if (candidateIds.length != 4) {
      throw Exception(
        'Guess game requires exactly 4 candidates.',
      );
    }

    // ==========================================================
    // ẨN CẢ 4 KHỎI DISCOVER TRONG 3 NGÀY
    // ==========================================================

    final hiddenUntil = DateTime.now().add(
      const Duration(days: 3),
    );

    final gameRef = _todayGameRef(currentUid);

    final batch = _firestore.batch();

    batch.set(gameRef, {
      'dateKey': _todayKey(),
      'correctUserId': correctUserId,
      'candidateUserIds': candidateIds,
      'attemptsUsed': 0,
      'completed': false,
      'won': false,
      'wrongUserIds': <String>[],
      'lastSelectedUserId': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'hiddenUntil': Timestamp.fromDate(
        hiddenUntil,
      ),
    });

    for (final candidateId in candidateIds) {
      final guessHiddenRef = _firestore
          .collection('users')
          .doc(currentUid)
          .collection('guessHiddenUsers')
          .doc(candidateId);

      batch.set(
        guessHiddenRef,
        {
          'userId': candidateId,
          'source': 'guess_game',
          'guessDateKey': _todayKey(),
          'hiddenUntil': Timestamp.fromDate(
            hiddenUntil,
          ),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    if (!mounted) return;

    setState(() {
      _candidates = selectedCandidates;
      _correctUserId = correctUserId;

      _attemptsUsed = 0;
      _completed = false;
      _won = false;
      _selectedUserId = null;

      _isLoading = false;
      _errorMessage = null;
    });
  }

  // ============================================================
  // HANDLE GUESS
  // ============================================================

  Future<void> _handleGuess(
    Map<String, dynamic> selectedProfile,
  ) async {
    if (_isSubmitting) return;
    if (_completed) return;

    final user = currentUser;
    if (user == null) return;

    final selectedUid = _profileUid(
      selectedProfile,
    );

    if (selectedUid.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _selectedUserId = selectedUid;
    });

    try {
      final gameRef = _todayGameRef(user.uid);

      final gameDoc = await gameRef.get();

      if (!gameDoc.exists) {
        throw Exception('Guess game not found.');
      }

      final gameData = gameDoc.data() ?? {};

      final latestAttemptsUsed = _parseInt(
        gameData['attemptsUsed'],
      );

      final latestCompleted =
          gameData['completed'] == true;

      final latestCorrectUserId =
          (gameData['correctUserId'] ?? '')
              .toString()
              .trim();

      if (latestCompleted) {
        await _loadExistingGame(gameData);
        return;
      }

      final isCorrect =
          selectedUid == latestCorrectUserId;

      final nextAttemptsUsed =
          latestAttemptsUsed + 1;

      if (isCorrect) {
        await gameRef.set({
          'attemptsUsed': nextAttemptsUsed,
          'completed': true,
          'won': true,
          'revealedUserId': selectedUid,
          'lastSelectedUserId': selectedUid,
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;

        setState(() {
          _attemptsUsed = nextAttemptsUsed;
          _completed = true;
          _won = true;
          _selectedUserId = selectedUid;
          _isSubmitting = false;
        });

        await _showCorrectDialog(
          selectedProfile,
        );

        return;
      }

      // ========================================================
      // ĐOÁN SAI
      // ========================================================

      final wrongUserIds = _stringList(
        gameData['wrongUserIds'],
      );

      if (!wrongUserIds.contains(selectedUid)) {
        wrongUserIds.add(selectedUid);
      }

      final noAttemptsLeft =
          nextAttemptsUsed >= 2;

      await gameRef.set({
        'attemptsUsed': nextAttemptsUsed,
        'completed': noAttemptsLeft,
        'won': false,
        'wrongUserIds': wrongUserIds,
        'lastSelectedUserId': selectedUid,
        'updatedAt': FieldValue.serverTimestamp(),
        if (noAttemptsLeft)
          'completedAt':
              FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _attemptsUsed = nextAttemptsUsed;
        _completed = noAttemptsLeft;
        _won = false;
        _selectedUserId = selectedUid;
        _isSubmitting = false;
      });

      if (noAttemptsLeft) {
        await _showNoAttemptsDialog();
      } else {
        await _showOneAttemptLeftDialog();
      }
    } catch (e) {
      debugPrint('GUESS SUBMIT ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Có lỗi xảy ra. Vui lòng thử lại.',
              'Something went wrong. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  // ============================================================
  // DIALOGS
  // ============================================================

  Future<void> _showCorrectDialog(
    Map<String, dynamic> profile,
  ) async {
    final firstName = _capitalizeName(
      (profile['firstName'] ?? '')
          .toString(),
    );

    final photoUrl = _mainPhotoUrl(profile);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              22,
              26,
              22,
              22,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogPhoto(photoUrl),
                const SizedBox(height: 18),
                Text(
                  _tr(
                    '🎉 Chính xác!',
                    '🎉 Correct!',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7A2E6E),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _tr(
                    '$firstName đã thích bạn ❤️',
                    '$firstName liked you ❤️',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFCC3D7A),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);

                      _openProfile(profile);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFCC3D7A),
                      minimumSize:
                          const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(17),
                      ),
                    ),
                    child: Text(
                      _tr(
                        'Xem hồ sơ',
                        'View profile',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOneAttemptLeftDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: const Icon(
            Icons.sentiment_dissatisfied_rounded,
            color: Color(0xFF7A55D6),
            size: 46,
          ),
          title: Text(
            _tr(
              'Chưa chính xác',
              'Not quite',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF7A2E6E),
            ),
          ),
          content: Text(
            _tr(
              'Bạn còn 1 lần đoán nữa.',
              'You have 1 guess remaining.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          actionsAlignment:
              MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF7A55D6),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _tr(
                  'Đoán lại',
                  'Guess again',
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showNoAttemptsDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: const Icon(
            Icons.schedule_rounded,
            color: Color(0xFFCC3D7A),
            size: 48,
          ),
          title: Text(
            _tr(
              'Hết lượt đoán hôm nay',
              'No guesses left today',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF7A2E6E),
            ),
          ),
          content: Text(
            _tr(
              'Tiếc quá, bạn chưa đoán đúng.\nHẹn gặp lại bạn vào ngày mai ❤️',
              'You did not guess correctly.\nSee you again tomorrow ❤️',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          actionsAlignment:
              MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFCC3D7A),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _tr(
                  'Đã hiểu',
                  'Got it',
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // OPEN PROFILE
  // ============================================================

  void _openProfile(
    Map<String, dynamic> profile,
  ) {
    final uid = _profileUid(profile);

    if (uid.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewOtherProfilePage(
          userId: uid,
          languageCode: widget.languageCode,
        ),
      ),
    );
  }

  // ============================================================
  // LOAD HELPERS
  // ============================================================

  Future<Set<String>> _loadMySwipedUserIds(
    String currentUid,
  ) async {
    final snapshot = await _firestore
        .collection('swipes')
        .where(
          'fromUserId',
          isEqualTo: currentUid,
        )
        .get();

    return snapshot.docs
        .map(
          (doc) => (doc.data()['toUserId'] ?? '')
              .toString()
              .trim(),
        )
        .where((uid) => uid.isNotEmpty)
        .toSet();
  }

  Future<Set<String>> _loadBlockedUserIds(
    String currentUid,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(currentUid)
        .collection('blocked_users')
        .get();

    return snapshot.docs
        .map((doc) => doc.id.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet();
  }

  Future<List<Map<String, dynamic>>>
      _loadProfilesByIds(
    List<String> userIds,
  ) async {
    final loaded = await Future.wait(
      userIds.map((uid) async {
        final doc = await _firestore
            .collection('users')
            .doc(uid)
            .get();

        if (!doc.exists) {
          return null;
        }

        return <String, dynamic>{
          'docId': doc.id,
          ...(doc.data() ?? {}),
        };
      }),
    );

    return loaded
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  // ============================================================
  // PROFILE VALIDATION
  // ============================================================

  bool _isProfileAvailable(
    Map<String, dynamic> profile,
  ) {
    final uid = _profileUid(profile);

    if (uid.isEmpty) return false;

    if (_mainPhotoUrl(profile).isEmpty) {
      return false;
    }

    if (profile['profileCompleted'] != true) {
      return false;
    }

    if (profile['showMyProfile'] == false) {
      return false;
    }

    if (profile['showOnDiscover'] == false) {
      return false;
    }

    if (profile['accountPaused'] == true) {
      return false;
    }

    if (profile['isPaused'] == true) {
      return false;
    }

    if (profile['isDeleted'] == true) {
      return false;
    }

    return true;
  }

  bool _isMutuallyCompatible({
    required Map<String, dynamic> myProfile,
    required Map<String, dynamic> otherProfile,
  }) {
    final myGender = _normalizeGender(
      myProfile['gender'],
    );

    final myPreference = _normalizeGender(
      myProfile['datingPreference'] ??
          myProfile['genderPreference'],
    );

    final otherGender = _normalizeGender(
      otherProfile['gender'],
    );

    final otherPreference = _normalizeGender(
      otherProfile['datingPreference'] ??
          otherProfile['genderPreference'],
    );

    final iLikeTheirGender =
        myPreference == 'everyone' ||
            myPreference == otherGender;

    final theyLikeMyGender =
        otherPreference == 'everyone' ||
            otherPreference == myGender;

    if (!iLikeTheirGender ||
        !theyLikeMyGender) {
      return false;
    }

    final myAge = _parseInt(
      myProfile['age'],
    );

    final otherAge = _parseInt(
      otherProfile['age'],
    );

    final myMinAge = _parseInt(
      myProfile['minAgePreference'] ??
          myProfile['preferredMinAge'],
    );

    final myMaxAge = _parseInt(
      myProfile['maxAgePreference'] ??
          myProfile['preferredMaxAge'],
    );

    final otherMinAge = _parseInt(
      otherProfile['minAgePreference'] ??
          otherProfile['preferredMinAge'],
    );

    final otherMaxAge = _parseInt(
      otherProfile['maxAgePreference'] ??
          otherProfile['preferredMaxAge'],
    );

    if (myMinAge > 0 &&
        otherAge < myMinAge) {
      return false;
    }

    if (myMaxAge > 0 &&
        otherAge > myMaxAge) {
      return false;
    }

    if (otherMinAge > 0 &&
        myAge < otherMinAge) {
      return false;
    }

    if (otherMaxAge > 0 &&
        myAge > otherMaxAge) {
      return false;
    }

    return true;
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor:
            const Color(0xFF7A2E6E),
        centerTitle: true,
        title: Text(
          _tr(
            'Đoán ai thích bạn',
            'Guess Who Likes You',
          ),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A2E6E),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFCC3D7A),
        onRefresh: _loadOrCreateGuessGame,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFCC3D7A),
        ),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 110),
          const Icon(
            Icons.error_outline_rounded,
            size: 66,
            color: Color(0xFFCC3D7A),
          ),
          const SizedBox(height: 18),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: ElevatedButton(
              onPressed: _loadOrCreateGuessGame,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFCC3D7A),
              ),
              child: Text(
                _tr(
                  'Thử lại',
                  'Try again',
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_candidates.isEmpty) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 100),
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFE5F0),
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              size: 48,
              color: Color(0xFFCC3D7A),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            _tr(
              'Chưa có lượt Guess mới hôm nay',
              'No new Guess game today',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7A2E6E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _tr(
              'Người bí ẩn của bạn vẫn chưa xuất hiện.\nHãy quay lại sau nhé ❤️',
              'Your mystery person has not appeared yet.\nPlease come back later ❤️',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      );
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        18,
        22,
        18,
        34,
      ),
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 22),

        if (!_completed)
          _buildAttemptsCard(),

        if (_completed) ...[
          _buildCompletedCard(),
          const SizedBox(height: 18),
        ],

        GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount: _candidates.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            return _buildCandidateCard(
              _candidates[index],
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8E54E9),
            Color(0xFF6550C9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6550C9)
                .withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.18),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 35,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _tr(
              '🎉 Có một người đã thích bạn!',
              '🎉 Someone has liked you!',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _tr(
              'Bạn có đoán được là ai không?',
              'Can you guess who it is?',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptsCard() {
    final remaining =
        max(0, 2 - _attemptsUsed);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFC9DE),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.casino_rounded,
            color: Color(0xFFCC3D7A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _tr(
                'Bạn còn $remaining lượt đoán',
                '$remaining guesses remaining',
              ),
              style: const TextStyle(
                color: Color(0xFF8B2E63),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _won
            ? const Color(0xFFE8F8EE)
            : const Color(0xFFFFEDF4),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: _won
              ? const Color(0xFF78C795)
              : const Color(0xFFFFC9DE),
        ),
      ),
      child: Text(
        _won
            ? _tr(
                '🎉 Bạn đã đoán chính xác!',
                '🎉 You guessed correctly!',
              )
            : _tr(
                'Hẹn gặp lại bạn vào ngày mai ❤️',
                'See you again tomorrow ❤️',
              ),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _won
              ? const Color(0xFF267B45)
              : const Color(0xFF9C2859),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildCandidateCard(
    Map<String, dynamic> profile,
  ) {
    final uid = _profileUid(profile);

    final firstName = _capitalizeName(
      (profile['firstName'] ?? '')
          .toString(),
    );

    final age =
        (profile['age'] ?? '')
            .toString()
            .trim();

    final state = _stateDisplay(profile);
    final photoUrl = _mainPhotoUrl(profile);

    final isCorrectCandidate =
        uid == _correctUserId;

    final shouldRevealCorrect =
        _completed && _won && isCorrectCandidate;

    final wasWrongSelection =
        _selectedUserId == uid &&
            !_won;

    final disabled =
        _completed || _isSubmitting;

    return GestureDetector(
      onTap: disabled
          ? shouldRevealCorrect
              ? () => _openProfile(profile)
              : null
          : () => _handleGuess(profile),
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: shouldRevealCorrect
                ? const Color(0xFF43A566)
                : wasWrongSelection
                    ? const Color(0xFFE57373)
                    : const Color(0xFFE6DDF6),
            width: shouldRevealCorrect ||
                    wasWrongSelection
                ? 3
                : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(18),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) {
                                return _photoPlaceholder();
                              },
                            )
                          : _photoPlaceholder(),
                    ),
                  ),

                  if (wasWrongSelection)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              Colors.black.withOpacity(0.30),
                          borderRadius:
                              BorderRadius.circular(18),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 58,
                          ),
                        ),
                      ),
                    ),

                  if (shouldRevealCorrect)
                    Positioned(
                      top: 9,
                      right: 9,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration:
                            const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF43A566),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            Text(
              [
                if (firstName.isNotEmpty)
                  firstName,
                if (age.isNotEmpty) age,
              ].join(', '),
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF5A3474),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              state.isEmpty
                  ? _tr(
                      'Không rõ khu vực',
                      'Location unavailable',
                    )
                  : state,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
               color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

            if (shouldRevealCorrect) ...[
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFE8F8EE),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Text(
                  _tr(
                    'Xem hồ sơ',
                    'View profile',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF267B45),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: const Color(0xFFF0E8F8),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 72,
        color: Color(0xFFB69ACB),
      ),
    );
  }

  Widget _buildDialogPhoto(
    String photoUrl,
  ) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade200,
        border: Border.all(
          color: const Color(0xFFCC3D7A),
          width: 4,
        ),
      ),
      child: ClipOval(
        child: photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) {
                  return const Icon(
                    Icons.person,
                    size: 58,
                    color: Colors.grey,
                  );
                },
              )
            : const Icon(
                Icons.person,
                size: 58,
                color: Colors.grey,
              ),
      ),
    );
  }

  // ============================================================
  // GENERAL HELPERS
  // ============================================================

  String _profileUid(
    Map<String, dynamic> profile,
  ) {
    return (profile['uid'] ??
            profile['docId'] ??
            '')
        .toString()
        .trim();
  }

  String _mainPhotoUrl(
    Map<String, dynamic> profile,
  ) {
    final mainPhoto =
        (profile['mainPhotoUrl'] ?? '')
            .toString()
            .trim();

    if (mainPhoto.isNotEmpty) {
      return mainPhoto;
    }

    final photos = profile['photos'];

    if (photos is List) {
      for (final item in photos) {
        final url =
            (item ?? '').toString().trim();

        if (url.isNotEmpty) {
          return url;
        }
      }
    }

    return '';
  }

  String _stateDisplay(
    Map<String, dynamic> profile,
  ) {
    final rawState = (
      profile['selectedState'] ??
      profile['selectedStateKey'] ??
      profile['state'] ??
      profile['stateProvince'] ??
      profile['province'] ??
      ''
    )
        .toString()
        .trim();

    if (rawState.isEmpty) {
      return '';
    }

    final normalized =
        rawState.toLowerCase();

    if (normalized.contains(
          'new south wales',
        ) ||
        normalized == 'nsw') {
      return 'NSW';
    }

    if (normalized.contains('victoria') ||
        normalized == 'vic') {
      return 'VIC';
    }

    if (normalized.contains(
          'queensland',
        ) ||
        normalized == 'qld') {
      return 'QLD';
    }

    if (normalized.contains(
          'south australia',
        ) ||
        normalized == 'sa') {
      return 'SA';
    }

    if (normalized.contains(
          'western australia',
        ) ||
        normalized == 'wa') {
      return 'WA';
    }

    if (normalized.contains('tasmania') ||
        normalized == 'tas') {
      return 'TAS';
    }

    if (normalized.contains(
          'australian capital territory',
        ) ||
        normalized == 'act') {
      return 'ACT';
    }

    if (normalized.contains(
          'northern territory',
        ) ||
        normalized == 'nt') {
      return 'NT';
    }

    return rawState;
  }

  String _normalizeGender(dynamic value) {
    final raw = (value ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (raw == 'male' ||
        raw == 'man' ||
        raw == 'nam') {
      return 'male';
    }

    if (raw == 'female' ||
        raw == 'woman' ||
        raw == 'nữ' ||
        raw == 'nu') {
      return 'female';
    }

    if (raw == 'everyone' ||
        raw == 'all' ||
        raw == 'both' ||
        raw == 'tất cả') {
      return 'everyone';
    }

    if (raw == 'other' ||
        raw == 'khác') {
      return 'other';
    }

    return raw;
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .map(
          (item) =>
              (item ?? '').toString().trim(),
        )
        .where((item) => item.isNotEmpty)
        .toList();
  }

  int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          (value ?? '').toString(),
        ) ??
        0;
  }

  String _capitalizeName(String value) {
    final cleanValue = value.trim();

    if (cleanValue.isEmpty) {
      return _tr(
        'Người dùng',
        'User',
      );
    }

    return cleanValue[0].toUpperCase() +
        cleanValue.substring(1).toLowerCase();
  }
}
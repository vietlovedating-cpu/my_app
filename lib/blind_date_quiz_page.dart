import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'view_other_profile_page.dart';

class BlindDateQuizPage extends StatefulWidget {
  final String languageCode;

  const BlindDateQuizPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<BlindDateQuizPage> createState() => _BlindDateQuizPageState();
}

class _BlindDateQuizPageState extends State<BlindDateQuizPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PageController _pageController = PageController();

  bool _isLoading = true;
  bool _isSavingAnswer = false;
  bool _isFindingMatch = false;
  bool _isProcessingReward = false;

  String? _errorMessage;

  List<_BlindDateQuestion> _todayQuestions = [];
  final Map<String, String> _answers = {};
  int _currentQuestionIndex = 0;

  bool _completedToday = false;
  bool _searchFinished = false;

  Map<String, dynamic>? _matchedProfile;
  int _sameAnswerCount = 0;
  int _compatibilityPercent = 0;

  String _rewardStatus = '';
  int _rewardFlowerAmount = 0;
  int _flowerBalance = 0;

  bool get isVi => widget.languageCode == 'vi';
  User? get currentUser => FirebaseAuth.instance.currentUser;

  bool get _hasPendingReward {
    return _rewardStatus == 'pending' && _rewardFlowerAmount > 0;
  }

  String _tr(String vi, String en) => isVi ? vi : en;

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATE + DAILY QUESTIONS
  // ============================================================

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _todayKey() => _dateKey(DateTime.now());

  int _dailySeed(String dateKey) {
    var hash = 17;
    for (final codeUnit in dateKey.codeUnits) {
      hash = 37 * hash + codeUnit;
    }
    return hash.abs();
  }

  List<_BlindDateQuestion> _buildTodayQuestions() {
    final questions = List<_BlindDateQuestion>.from(_questionBank);
    questions.shuffle(Random(_dailySeed(_todayKey())));
    return questions.take(7).toList();
  }

  String _questionSetId(List<_BlindDateQuestion> questions) {
    return questions.map((q) => q.id).join('|');
  }

  DocumentReference<Map<String, dynamic>> _todayAnswerRef(String uid) {
    return _firestore
        .collection('blindDateQuizDaily')
        .doc(_todayKey())
        .collection('answers')
        .doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _todayResultRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('blindDateQuizResults')
        .doc(_todayKey());
  }

  // ============================================================
  // LOAD TODAY
  // ============================================================

  Future<void> _loadTodayData() async {
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
      final questions = _buildTodayQuestions();
      final results = await Future.wait<dynamic>([
        _todayAnswerRef(user.uid).get(),
        _todayResultRef(user.uid).get(),
        _firestore.collection('users').doc(user.uid).get(),
      ]);

      final answerDoc =
          results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final resultDoc =
          results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final userDoc =
          results[2] as DocumentSnapshot<Map<String, dynamic>>;

      final savedAnswers = <String, String>{};
      final answerData = answerDoc.data() ?? {};
      final rawAnswers = answerData['answers'];

      if (rawAnswers is Map) {
        for (final entry in rawAnswers.entries) {
          final key = entry.key.toString().trim();
          final value = (entry.value ?? '').toString().trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            savedAnswers[key] = value;
          }
        }
      }

      final completedToday =
          answerData['completed'] == true && savedAnswers.length >= 7;

      Map<String, dynamic>? matchedProfile;
      int sameAnswerCount = 0;
      int compatibilityPercent = 0;
      String rewardStatus = '';
      int rewardFlowerAmount = 0;
      bool searchFinished = false;

      if (resultDoc.exists) {
        final resultData = resultDoc.data() ?? {};
        final matchedUserId =
            (resultData['matchedUserId'] ?? '').toString().trim();

        sameAnswerCount = _parseInt(resultData['sameAnswerCount']);
        compatibilityPercent =
            _parseInt(resultData['compatibilityPercent']);
        rewardStatus =
            (resultData['rewardStatus'] ?? '').toString().trim();
        rewardFlowerAmount =
            _parseInt(resultData['rewardFlowerAmount']);
        searchFinished = resultData['searchFinished'] == true;

        if (matchedUserId.isNotEmpty) {
          final profileDoc = await _firestore
              .collection('users')
              .doc(matchedUserId)
              .get();

          if (profileDoc.exists) {
            matchedProfile = <String, dynamic>{
              'docId': profileDoc.id,
              ...(profileDoc.data() ?? {}),
            };
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _todayQuestions = questions;
        _answers
          ..clear()
          ..addAll(savedAnswers);

        _completedToday = completedToday;
        _searchFinished = searchFinished;
        _matchedProfile = matchedProfile;
        _sameAnswerCount = sameAnswerCount;
        _compatibilityPercent = compatibilityPercent;
        _rewardStatus = rewardStatus;
        _rewardFlowerAmount = rewardFlowerAmount;
        _flowerBalance = _parseInt((userDoc.data() ?? {})['flowerBalance']);

        _currentQuestionIndex = _firstUnansweredQuestionIndex();
        _isLoading = false;
      });

      if (_completedToday && !resultDoc.exists) {
        await _findBestMatch();
      }
    } catch (e) {
      debugPrint('LOAD BLIND DATE QUIZ ERROR: $e');

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _tr(
          'Không thể tải Blind Date Quiz. Vui lòng thử lại.',
          'Unable to load Blind Date Quiz. Please try again.',
        );
      });
    }
  }

  int _firstUnansweredQuestionIndex() {
    for (var i = 0; i < _todayQuestions.length; i++) {
      if (!_answers.containsKey(_todayQuestions[i].id)) {
        return i;
      }
    }
    return max(0, _todayQuestions.length - 1);
  }

  // ============================================================
  // ANSWERS
  // ============================================================

  Future<void> _selectAnswer({
    required _BlindDateQuestion question,
    required String value,
  }) async {
    if (_isSavingAnswer || _completedToday) return;

    final user = currentUser;
    if (user == null) return;

    setState(() {
      _isSavingAnswer = true;
      _answers[question.id] = value;
    });

    try {
      final isComplete = _answers.length >= 7;
      final questionSetId = _questionSetId(_todayQuestions);

      await _todayAnswerRef(user.uid).set({
        'userId': user.uid,
        'dateKey': _todayKey(),
        'questionSetId': questionSetId,
        'questionIds': _todayQuestions.map((q) => q.id).toList(),
        'answers': _answers,
        'completed': isComplete,
        if (isComplete) 'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _isSavingAnswer = false;
        _completedToday = isComplete;
      });

      if (isComplete) {
        await _findBestMatch();
        return;
      }

      final nextIndex = min(
        _currentQuestionIndex + 1,
        _todayQuestions.length - 1,
      );

      setState(() {
        _currentQuestionIndex = nextIndex;
      });

      await Future<void>.delayed(const Duration(milliseconds: 180));

      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e) {
      debugPrint('SAVE BLIND DATE ANSWER ERROR: $e');

      if (!mounted) return;
      setState(() {
        _isSavingAnswer = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Không thể lưu câu trả lời. Vui lòng thử lại.',
              'Unable to save your answer. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  // ============================================================
  // FIND EXACTLY ONE BEST MATCH
  // ============================================================

  Future<void> _findBestMatch() async {
    if (_isFindingMatch) return;

    final user = currentUser;
    if (user == null || _answers.length < 7) return;

    setState(() {
      _isFindingMatch = true;
      _errorMessage = null;
    });

    try {
      final existingResult = await _todayResultRef(user.uid).get();

if (existingResult.exists) {
  final data = existingResult.data() ?? {};

  final matchedUserId =
      (data['matchedUserId'] ?? '').toString().trim();

if (matchedUserId.isNotEmpty) {
  if (mounted) {
    setState(() {
      _isFindingMatch = false;
    });
  }

  await _loadTodayData();
  return;
}

  await existingResult.reference.delete();
}

      final currentUserDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final myProfile = currentUserDoc.data() ?? {};

      final exclusions = await _loadExcludedUserIds(user.uid);

      final answerSnapshot = await _firestore
          .collection('blindDateQuizDaily')
          .doc(_todayKey())
          .collection('answers')
          .where('completed', isEqualTo: true)
          .get();

     final rankedAnswerCandidates =
    <Map<String, dynamic>>[];
      final currentQuestionSetId = _questionSetId(_todayQuestions);
debugPrint(
  'BLIND DATE CURRENT=${user.uid} '
  'ANSWERS=${answerSnapshot.docs.map((doc) => doc.id).toList()} '
  'EXCLUSIONS=$exclusions',
);
      for (final answerDoc in answerSnapshot.docs) {
        final candidateUid = answerDoc.id.trim();
        if (candidateUid.isEmpty || candidateUid == user.uid) continue;
       if (exclusions.contains(candidateUid)) {
  debugPrint(
    'BLIND DATE LOAI $candidateUid: NAM TRONG EXCLUSIONS',
  );
  continue;
}

        final answerData = answerDoc.data();
        final candidateQuestionSetId =
            (answerData['questionSetId'] ?? '').toString().trim();

        if (candidateQuestionSetId != currentQuestionSetId) continue;

       final candidateAnswers = <String, String>{};
final rawCandidateAnswers = answerData['answers'];

if (rawCandidateAnswers is Map) {
  for (final entry in rawCandidateAnswers.entries) {
    final key = entry.key.toString().trim();
    final value =
        (entry.value ?? '').toString().trim();

    if (key.isNotEmpty && value.isNotEmpty) {
      candidateAnswers[key] = value;
    }
  }
}


if (candidateAnswers.length < 7) {
  continue;
}

var sameCount = 0;

for (final question in _todayQuestions) {
  if (_answers[question.id] ==
      candidateAnswers[question.id]) {
    sameCount++;
  }
}

rankedAnswerCandidates.add({
  'userId': candidateUid,
  'sameAnswerCount': sameCount,
});
      }
rankedAnswerCandidates.sort((a, b) {
  final aScore =
      (a['sameAnswerCount'] as int?) ?? 0;

  final bScore =
      (b['sameAnswerCount'] as int?) ?? 0;

  return bScore.compareTo(aScore);
});
     _MatchedCandidate? bestCandidate;

for (final rankedCandidate in rankedAnswerCandidates) {
  final candidateUid =
      (rankedCandidate['userId'] ?? '')
          .toString()
          .trim();

  final sameAnswerCount =
      (rankedCandidate['sameAnswerCount'] as int?) ?? 0;

  if (candidateUid.isEmpty) {
    continue;
  }

  final profileDoc = await _firestore
      .collection('users')
      .doc(candidateUid)
      .get();

  if (!profileDoc.exists) {
    continue;
  }

  final profile = <String, dynamic>{
    'docId': profileDoc.id,
    ...(profileDoc.data() ?? {}),
  };

 if (!_isProfileAvailable(profile)) {
  debugPrint(
    'BLIND DATE LOAI $candidateUid: PROFILE KHONG AVAILABLE '
    'profileCompleted=${profile['profileCompleted']}, '
    'mainPhoto=${_mainPhotoUrl(profile).isNotEmpty}, '
    'showMyProfile=${profile['showMyProfile']}, '
    'showOnDiscover=${profile['showOnDiscover']}, '
    'accountPaused=${profile['accountPaused']}, '
    'isPaused=${profile['isPaused']}, '
    'isDeleted=${profile['isDeleted']}',
  );
  continue;
}

 if (!_isMutuallyCompatible(
  myProfile: myProfile,
  otherProfile: profile,
)) {
  debugPrint(
    'BLIND DATE LOAI $candidateUid: KHONG TUONG THICH '
    'myGender=${myProfile['gender']}, '
    'myPreference=${myProfile['datingPreference'] ?? myProfile['genderPreference']}, '
    'myAge=${myProfile['age']}, '
    'myMin=${myProfile['minAgePreference'] ?? myProfile['preferredMinAge']}, '
    'myMax=${myProfile['maxAgePreference'] ?? myProfile['preferredMaxAge']}, '
    'otherGender=${profile['gender']}, '
    'otherPreference=${profile['datingPreference'] ?? profile['genderPreference']}, '
    'otherAge=${profile['age']}, '
    'otherMin=${profile['minAgePreference'] ?? profile['preferredMinAge']}, '
    'otherMax=${profile['maxAgePreference'] ?? profile['preferredMaxAge']}',
  );
  continue;
}

 if (sameAnswerCount >= 5) {
  bestCandidate = _MatchedCandidate(
    profile: profile,
    sameAnswerCount: sameAnswerCount,
    lastSeen: _timestampToDate(
      profile['lastSeen'],
    ),
    photoCount: _photoCount(profile),
  );

  break;
}
}

      final resultData = <String, dynamic>{
        'dateKey': _todayKey(),
        'questionSetId': currentQuestionSetId,
        'searchFinished': true,
        'totalQuestions': 7,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (bestCandidate == null) {
        resultData.addAll({
          'matchedUserId': '',
          'sameAnswerCount': 0,
          'compatibilityPercent': 0,
          'rewardFlowerAmount': 0,
          'rewardStatus': 'not_available',
        });
      } else {
        final compatibilityPercent =
            ((bestCandidate.sameAnswerCount / 7) * 100).round();

        resultData.addAll({
          'matchedUserId': _profileUid(bestCandidate.profile),
          'sameAnswerCount': bestCandidate.sameAnswerCount,
          'compatibilityPercent': compatibilityPercent,

          // Giống Lucky Spin: chỉ tạo phần thưởng đang chờ.
          // Chưa cộng Flower vào flowerBalance.
          'rewardFlowerAmount': 1,
          'rewardStatus': 'pending',
          'rewardCreatedAt': FieldValue.serverTimestamp(),
        });
      }

      await _todayResultRef(user.uid).set(
        resultData,
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _searchFinished = true;
        _matchedProfile = bestCandidate?.profile;
        _sameAnswerCount = bestCandidate?.sameAnswerCount ?? 0;
        _compatibilityPercent = bestCandidate == null
            ? 0
            : ((bestCandidate.sameAnswerCount / 7) * 100).round();
        _rewardFlowerAmount = bestCandidate == null ? 0 : 1;
        _rewardStatus = bestCandidate == null
            ? 'not_available'
            : 'pending';
        _isFindingMatch = false;
      });
    } catch (e) {
      debugPrint('FIND BLIND DATE MATCH ERROR: $e');

      if (!mounted) return;
      setState(() {
        _isFindingMatch = false;
        _errorMessage = _tr(
          'Không thể tìm Blind Date Match. Vui lòng thử lại.',
          'Unable to find your Blind Date Match. Please try again.',
        );
      });
    }
  }

  // ============================================================
  // EXCLUSIONS
  // Pass, Like, Flower, Match, Hidden, Blocked, Reported...
  // ============================================================

  Future<Set<String>> _loadExcludedUserIds(String currentUid) async {
    final excluded = <String>{currentUid};

    final results = await Future.wait<dynamic>([
      _firestore
          .collection('swipes')
          .where('fromUserId', isEqualTo: currentUid)
          .get(),
      _firestore
          .collection('swipes')
          .where('toUserId', isEqualTo: currentUid)
          .get(),
      _firestore
          .collection('users')
          .doc(currentUid)
          .collection('hidden_users')
          .get(),
      _firestore
          .collection('users')
          .doc(currentUid)
          .collection('blocked_users')
          .get(),
      _firestore
          .collection('users')
          .doc(currentUid)
          .collection('reported_users')
          .get(),
      _firestore
          .collection('matches')
          .where('userIds', arrayContains: currentUid)
          .get(),
      _firestore
          .collection('matches')
          .where('users', arrayContains: currentUid)
          .get(),
    ]);

    final sentSwipes =
        results[0] as QuerySnapshot<Map<String, dynamic>>;
    final receivedSwipes =
        results[1] as QuerySnapshot<Map<String, dynamic>>;
    final hidden =
        results[2] as QuerySnapshot<Map<String, dynamic>>;
    final blocked =
        results[3] as QuerySnapshot<Map<String, dynamic>>;
    final reported =
        results[4] as QuerySnapshot<Map<String, dynamic>>;
    final matchesByUserIds =
        results[5] as QuerySnapshot<Map<String, dynamic>>;
    final matchesByUsers =
        results[6] as QuerySnapshot<Map<String, dynamic>>;

    for (final doc in sentSwipes.docs) {
      final uid = (doc.data()['toUserId'] ?? '').toString().trim();
      if (uid.isNotEmpty) excluded.add(uid);
    }

    for (final doc in receivedSwipes.docs) {
      final uid = (doc.data()['fromUserId'] ?? '').toString().trim();
      if (uid.isNotEmpty) excluded.add(uid);
    }

    excluded.addAll(hidden.docs.map((doc) => doc.id.trim()));
    excluded.addAll(blocked.docs.map((doc) => doc.id.trim()));
    excluded.addAll(reported.docs.map((doc) => doc.id.trim()));

    void addMatchUsers(QuerySnapshot<Map<String, dynamic>> snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        for (final field in ['userIds', 'users', 'members']) {
          final value = data[field];
          if (value is List) {
            for (final item in value) {
              final uid = (item ?? '').toString().trim();
              if (uid.isNotEmpty) excluded.add(uid);
            }
          }
        }

        for (final field in [
          'user1Id',
          'user2Id',
          'fromUserId',
          'toUserId',
        ]) {
          final uid = (data[field] ?? '').toString().trim();
          if (uid.isNotEmpty) excluded.add(uid);
        }
      }
    }

    addMatchUsers(matchesByUserIds);
    addMatchUsers(matchesByUsers);

    return excluded.where((uid) => uid.isNotEmpty).toSet();
  }

  // ============================================================
  // FLOWER REWARD - SAME STRUCTURE AS LUCKY SPIN
  // ============================================================

  Future<void> _claimPendingReward() async {
    if (_isProcessingReward || !_hasPendingReward) return;

    final user = currentUser;
    if (user == null) return;

    setState(() {
      _isProcessingReward = true;
    });

    try {
      final result = await _firestore.runTransaction<_ClaimRewardResult>(
        (transaction) async {
          final userRef = _firestore.collection('users').doc(user.uid);
          final resultRef = _todayResultRef(user.uid);

          final userSnapshot = await transaction.get(userRef);
          final resultSnapshot = await transaction.get(resultRef);

          final userData = userSnapshot.data() ?? {};
          final resultData = resultSnapshot.data() ?? {};

          final rewardStatus =
              (resultData['rewardStatus'] ?? '').toString().trim();
          final rewardAmount =
              _parseInt(resultData['rewardFlowerAmount']);

          if (rewardStatus != 'pending' || rewardAmount != 1) {
            throw const _RewardAlreadyProcessedException();
          }

          final oldPurchasedBalance = _parseInt(userData['flowerBalance']);

          final sentFlowerSnapshot = await _firestore
              .collection('swipes')
              .where('fromUserId', isEqualTo: user.uid)
              .where('action', isEqualTo: 'flower')
              .get();

          final sentFlowerCount = sentFlowerSnapshot.docs.length;
          final freeFlowersRemaining = (7 - sentFlowerCount).clamp(0, 7);

          final previousTotalFlowers =
              freeFlowersRemaining + oldPurchasedBalance;
          final newPurchasedBalance = oldPurchasedBalance + rewardAmount;
          final totalAvailableFlowers =
              freeFlowersRemaining + newPurchasedBalance;

          transaction.set(
            userRef,
            {
              'flowerBalance': FieldValue.increment(rewardAmount),
              'blindDateLastClaimedFlowers': rewardAmount,
              'blindDateLastClaimedAt': FieldValue.serverTimestamp(),
              'blindDateUpdatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          transaction.set(
            resultRef,
            {
              'rewardStatus': 'claimed',
              'rewardClaimedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          return _ClaimRewardResult(
            previousTotalFlowers: previousTotalFlowers,
            flowersWon: rewardAmount,
            totalAvailableFlowers: totalAvailableFlowers,
          );
        },
      );

      if (!mounted) return;

      setState(() {
        _rewardStatus = 'claimed';
        _flowerBalance = result.totalAvailableFlowers;
        _isProcessingReward = false;
      });

      await _showClaimedRewardDialog(result);
    } on _RewardAlreadyProcessedException {
      if (!mounted) return;
      setState(() {
        _isProcessingReward = false;
      });
      await _loadTodayData();
    } catch (e) {
      debugPrint('CLAIM BLIND DATE REWARD ERROR: $e');

      if (!mounted) return;
      setState(() {
        _isProcessingReward = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Không thể nhận phần thưởng. Vui lòng thử lại.',
              'Unable to claim the reward. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _declinePendingReward() async {
    if (_isProcessingReward || !_hasPendingReward) return;

    final user = currentUser;
    if (user == null) return;

    setState(() {
      _isProcessingReward = true;
    });

    try {
      final resultRef = _todayResultRef(user.uid);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(resultRef);
        final data = snapshot.data() ?? {};

        final rewardStatus =
            (data['rewardStatus'] ?? '').toString().trim();

        if (rewardStatus != 'pending') {
          throw const _RewardAlreadyProcessedException();
        }

        transaction.set(
          resultRef,
          {
            'rewardStatus': 'declined',
            'rewardDeclinedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;
      setState(() {
        _rewardStatus = 'declined';
        _isProcessingReward = false;
      });
    } catch (e) {
      debugPrint('DECLINE BLIND DATE REWARD ERROR: $e');

      if (!mounted) return;
      setState(() {
        _isProcessingReward = false;
      });

      await _loadTodayData();
    }
  }

  Future<void> _showClaimedRewardDialog(_ClaimRewardResult result) async {
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
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFE5F0),
                  ),
                  child: const Icon(
                    Icons.local_florist_rounded,
                    color: Color(0xFFCC3D7A),
                    size: 46,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _tr(
                    '🎉 Bạn đã nhận Flower!',
                    '🎉 You claimed your Flower!',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF7A2E6E),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                _buildRewardCalculationRow(
                  label: _tr(
                    'Số Flower bạn đang có',
                    'Flowers you currently have',
                  ),
                  value: '${result.previousTotalFlowers}',
                ),
                const SizedBox(height: 10),
                _buildRewardCalculationRow(
                  label: _tr(
                    'Flower bạn vừa nhận',
                    'Flower received',
                  ),
                  value: '+${result.flowersWon}',
                  valueColor: const Color(0xFFCC3D7A),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1),
                ),
                _buildRewardCalculationRow(
                  label: _tr(
                    'Tổng Flower của bạn',
                    'Your total Flowers',
                  ),
                  value: '${result.totalAvailableFlowers}',
                  valueColor: const Color(0xFF267B45),
                  large: true,
                ),
                const SizedBox(height: 16),
                Text(
                  _tr(
                    'Hãy dùng Flower này để gửi lời nhắn cho Blind Date Match của bạn hôm nay ❤️',
                    'Use this Flower to send a message to your Blind Date Match today ❤️',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _openMatchedProfile();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCC3D7A),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: Text(
                      _tr('Xem hồ sơ', 'View profile'),
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

  Widget _buildRewardCalculationRow({
    required String label,
    required String value,
    Color valueColor = const Color(0xFF7A2E6E),
    bool large = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: large ? 16 : 14,
              fontWeight: large ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: large ? 23 : 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE VALIDATION + COMPATIBILITY
  // ============================================================

  bool _isProfileAvailable(Map<String, dynamic> profile) {
    final uid = _profileUid(profile);
    if (uid.isEmpty) return false;
    if (_mainPhotoUrl(profile).isEmpty) return false;
    if (profile['profileCompleted'] != true) return false;
    if (profile['showMyProfile'] == false) return false;
    if (profile['showOnDiscover'] == false) return false;
    if (profile['accountPaused'] == true) return false;
    if (profile['isPaused'] == true) return false;
    if (profile['isDeleted'] == true) return false;
    return true;
  }

  bool _isMutuallyCompatible({
    required Map<String, dynamic> myProfile,
    required Map<String, dynamic> otherProfile,
  }) {
    final myGender = _normalizeGender(myProfile['gender']);
    final myPreference = _normalizeGender(
      myProfile['datingPreference'] ?? myProfile['genderPreference'],
    );
    final otherGender = _normalizeGender(otherProfile['gender']);
    final otherPreference = _normalizeGender(
      otherProfile['datingPreference'] ?? otherProfile['genderPreference'],
    );

    final iLikeTheirGender =
        myPreference == 'everyone' || myPreference == otherGender;
    final theyLikeMyGender =
        otherPreference == 'everyone' || otherPreference == myGender;

    if (!iLikeTheirGender || !theyLikeMyGender) return false;

    final myAge = _parseInt(myProfile['age']);
    final otherAge = _parseInt(otherProfile['age']);

    final myMinAge = _parseInt(
      myProfile['minAgePreference'] ?? myProfile['preferredMinAge'],
    );
    final myMaxAge = _parseInt(
      myProfile['maxAgePreference'] ?? myProfile['preferredMaxAge'],
    );
    final otherMinAge = _parseInt(
      otherProfile['minAgePreference'] ?? otherProfile['preferredMinAge'],
    );
    final otherMaxAge = _parseInt(
      otherProfile['maxAgePreference'] ?? otherProfile['preferredMaxAge'],
    );

    if (myMinAge > 0 && otherAge < myMinAge) return false;
    if (myMaxAge > 0 && otherAge > myMaxAge) return false;
    if (otherMinAge > 0 && myAge < otherMinAge) return false;
    if (otherMaxAge > 0 && myAge > otherMaxAge) return false;

    return true;
  }

  // ============================================================
  // UI
  // ============================================================

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
          _tr('Blind Date Quiz', 'Blind Date Quiz'),
          style: const TextStyle(
            color: Color(0xFF7A2E6E),
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFCC3D7A),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFFCC3D7A),
              onRefresh: _loadTodayData,
              child: _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null && !_completedToday) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline_rounded,
            size: 62,
            color: Color(0xFFCC3D7A),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: _loadTodayData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC3D7A),
              ),
              child: Text(
                _tr('Thử lại', 'Try again'),
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

    if (!_completedToday) {
      return _buildQuiz();
    }

    if (_isFindingMatch) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 145),
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFCC3D7A),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            _tr(
              'Đang tìm người có câu trả lời giống bạn nhất...',
              'Finding the person whose answers are most similar to yours...',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7A2E6E),
              fontSize: 17,
              height: 1.45,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }

    if (_matchedProfile == null && _searchFinished) {
      return _buildNoMatchToday();
    }

    return _buildMatchResult();
  }

  Widget _buildQuiz() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
      children: [
        _buildIntroCard(),
        const SizedBox(height: 18),
        _buildProgressCard(),
        const SizedBox(height: 18),
        SizedBox(
          height: 410,
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todayQuestions.length,
            itemBuilder: (context, index) {
              return _buildQuestionCard(_todayQuestions[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIntroCard() {
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
            Color(0xFFCC3D7A),
          ],
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            _tr(
              'Tìm Blind Date Match hôm nay',
              'Find today\'s Blind Date Match',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
           _tr(
  'Mỗi ngày bạn sẽ nhận 7 câu hỏi mới. Mỗi câu chỉ có 2 lựa chọn và bạn chỉ cần nhấn để trả lời. Sau khi hoàn thành, VietLove Dating sẽ tìm đúng 1 người có câu trả lời giống bạn nhất. Nếu tìm được, bạn có thể xem hồ sơ của người đó và chọn nhận 1 Flower để gửi lời nhắn. Sang ngày mới, trò chơi sẽ tự động reset với 7 câu hỏi khác.',
  'Every day you will receive 7 new questions. Each question has only 2 choices, and you simply tap your answer. After you finish, VietLove Dating will find the one person whose answers are most similar to yours. If a match is found, you can view their profile and choose to claim 1 Flower to send them a message. The game automatically resets the next day with 7 new questions.',
),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.94),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final answered = _answers.length.clamp(0, 7);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD1E1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.quiz_rounded,
                color: Color(0xFFCC3D7A),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tr(
                    'Đã trả lời $answered / 7 câu',
                    '$answered / 7 answered',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF7A2E6E),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: answered / 7,
              minHeight: 9,
              backgroundColor: const Color(0xFFFFE5F0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFCC3D7A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(_BlindDateQuestion question, int index) {
    final selectedValue = _answers[question.id];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFEADFF2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              _tr(
                'Câu ${index + 1} / 7',
                'Question ${index + 1} / 7',
              ),
              style: const TextStyle(
                color: Color(0xFFCC3D7A),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isVi ? question.vi : question.en,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF5A3474),
                fontSize: 22,
                height: 1.35,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            _buildAnswerOption(
              text: isVi ? question.optionAVi : question.optionAEn,
              value: 'a',
              selectedValue: selectedValue,
              onTap: () => _selectAnswer(question: question, value: 'a'),
            ),
            const SizedBox(height: 14),
            _buildAnswerOption(
              text: isVi ? question.optionBVi : question.optionBEn,
              value: 'b',
              selectedValue: selectedValue,
              onTap: () => _selectAnswer(question: question, value: 'b'),
            ),
            const Spacer(),
            if (_isSavingAnswer)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0xFFCC3D7A),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerOption({
    required String text,
    required String value,
    required String? selectedValue,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedValue == value;

    return InkWell(
      onTap: _isSavingAnswer ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFE5F0) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFCC3D7A)
                : const Color(0xFFE6DDE2),
            width: isSelected ? 2 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? const Color(0xFF9C2859)
                      : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFCC3D7A),
              ),
          ],
        ),
      ),
    );
  }

 Widget _buildNoMatchToday() {
  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(26),
    children: [
      const SizedBox(height: 80),

      Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFFFE5F0),
        ),
        child: const Icon(
          Icons.search_rounded,
          color: Color(0xFFCC3D7A),
          size: 49,
        ),
      ),

      const SizedBox(height: 22),

      Text(
        _tr(
          'Bạn đã hoàn thành Blind Date Quiz hôm nay! ❤️',
          'You completed today\'s Blind Date Quiz! ❤️',
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF7A2E6E),
          fontSize: 23,
          fontWeight: FontWeight.w900,
        ),
      ),

      const SizedBox(height: 12),

      Text(
        _tr(
          'Hiện chưa tìm thấy người phù hợp. Những người chơi khác vẫn đang hoàn thành 7 câu hỏi hôm nay. Hãy quay lại sau hoặc nhấn Kiểm tra lại để xem đã có ai có câu trả lời giống bạn chưa.',
          'No suitable match has been found yet. Other members are still completing today\'s 7 questions. Come back later or tap Check Again to see if someone now has similar answers.',
        ),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),

      const SizedBox(height: 24),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed:
              _isFindingMatch ? null : _findBestMatch,
          icon: _isFindingMatch
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                ),
          label: Text(
            _isFindingMatch
                ? _tr(
                    'Đang kiểm tra...',
                    'Checking...',
                  )
                : _tr(
                    'Kiểm tra lại',
                    'Check Again',
                  ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                const Color(0xFFCC3D7A),
            disabledBackgroundColor:
                const Color(0xFFCC3D7A)
                    .withOpacity(0.55),
            minimumSize:
                const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    ],
  );
}
  Widget _buildMatchResult() {
    final profile = _matchedProfile!;
    final firstName = _capitalizeName(
      (profile['firstName'] ?? '').toString(),
    );
    final age = (profile['age'] ?? '').toString().trim();
    final photoUrl = _mainPhotoUrl(profile);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
      children: [
        Text(
          _tr(
            '❤️ Blind Date Match hôm nay',
            '❤️ Today\'s Blind Date Match',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF7A2E6E),
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFD1E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: double.infinity,
                  height: 330,
                  child: photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _photoPlaceholder(),
                        )
                      : _photoPlaceholder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                [
                  if (firstName.isNotEmpty) firstName,
                  if (age.isNotEmpty) age,
                ].join(', '),
                style: const TextStyle(
                  color: Color(0xFF5A3474),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _tr(
                  'Hai bạn giống nhau $_sameAnswerCount / 7 câu trả lời',
                  'You matched on $_sameAnswerCount / 7 answers',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFCC3D7A),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$_compatibilityPercent% ${_tr('tương thích', 'compatible')}',
                style: const TextStyle(
                  color: Color(0xFF267B45),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openMatchedProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A55D6),
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: Text(
                    _tr('Xem hồ sơ', 'View profile'),
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
        if (_hasPendingReward) ...[
          const SizedBox(height: 18),
          _buildPendingRewardCard(),
        ],
        if (_rewardStatus == 'claimed') ...[
          const SizedBox(height: 18),
          _buildRewardProcessedCard(
            icon: Icons.check_circle_rounded,
            title: _tr(
              'Bạn đã nhận 1 Flower hôm nay',
              'You claimed 1 Flower today',
            ),
            message: _tr(
              'Hãy dùng Flower này để gửi lời nhắn cho Blind Date Match của bạn ❤️',
              'Use this Flower to message your Blind Date Match ❤️',
            ),
            color: const Color(0xFF267B45),
            background: const Color(0xFFE8F8EE),
          ),
        ],
        if (_rewardStatus == 'declined') ...[
          const SizedBox(height: 18),
          _buildRewardProcessedCard(
            icon: Icons.close_rounded,
            title: _tr(
              'Bạn đã chọn không nhận Flower',
              'You declined the Flower',
            ),
           message: _tr(
  'Bạn đã từ chối nhận Flower miễn phí hôm nay.\n\nBạn vẫn có thể xem hồ sơ, gửi Like hoặc gửi Flower nếu bạn đang có Flower trong tài khoản.\n\nHãy quay lại vào ngày mai để tham gia Blind Date Quiz mới ❤️',
  'You declined today\'s free Flower.\n\nYou can still view the profile, send a Like, or send a Flower if you already have Flowers in your account.\n\nCome back tomorrow for a new Blind Date Quiz ❤️',
),
            color: const Color(0xFF8B2E63),
            background: const Color(0xFFFFEDF4),
          ),
        ],
      ],
    );
  }

  Widget _buildPendingRewardCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFC9DE)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.local_florist_rounded,
            color: Color(0xFFCC3D7A),
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            _tr(
              '🎁 Bạn được tặng 1 Flower!',
              '🎁 You have been offered 1 Flower!',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7A2E6E),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _tr(
              'Bạn có muốn nhận Flower này không? Chỉ khi bạn bấm Nhận, Flower mới được cộng vào số dư của bạn. Hãy dùng Flower này để gửi lời nhắn cho Blind Date Match hôm nay.',
              'Would you like to claim this Flower? It will only be added to your balance after you tap Claim. Use it to send a message to today\'s Blind Date Match.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessingReward
                      ? null
                      : _declinePendingReward,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _tr('Không nhận', 'Decline'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _isProcessingReward ? null : _claimPendingReward,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC3D7A),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isProcessingReward
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _tr('Nhận 1 Flower', 'Claim 1 Flower'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardProcessedCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    required Color background,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: const Color(0xFFF0E8F8),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 78,
        color: Color(0xFFB69ACB),
      ),
    );
  }

  void _openMatchedProfile() {
    final profile = _matchedProfile;
    if (profile == null) return;

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
  // HELPERS
  // ============================================================

  String _profileUid(Map<String, dynamic> profile) {
    return (profile['uid'] ?? profile['docId'] ?? '').toString().trim();
  }

  String _mainPhotoUrl(Map<String, dynamic> profile) {
    final mainPhoto =
        (profile['mainPhotoUrl'] ?? '').toString().trim();
    if (mainPhoto.isNotEmpty) return mainPhoto;

    final photos = profile['photos'];
    if (photos is List) {
      for (final item in photos) {
        final url = (item ?? '').toString().trim();
        if (url.isNotEmpty) return url;
      }
    }
    return '';
  }

  int _photoCount(Map<String, dynamic> profile) {
    final urls = <String>{};
    final mainPhoto = _mainPhotoUrl(profile);
    if (mainPhoto.isNotEmpty) urls.add(mainPhoto);

    final photos = profile['photos'];
    if (photos is List) {
      for (final item in photos) {
        final url = (item ?? '').toString().trim();
        if (url.isNotEmpty) urls.add(url);
      }
    }
    return urls.length;
  }

  String _normalizeGender(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();

    if (raw == 'male' || raw == 'man' || raw == 'nam') return 'male';
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
    if (raw == 'other' || raw == 'khác') return 'other';
    return raw;
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _capitalizeName(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return _tr('Người dùng', 'User');
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }
}

// ================================================================
// MODELS
// ================================================================

class _MatchedCandidate {
  final Map<String, dynamic> profile;
  final int sameAnswerCount;
  final DateTime? lastSeen;
  final int photoCount;

  const _MatchedCandidate({
    required this.profile,
    required this.sameAnswerCount,
    required this.lastSeen,
    required this.photoCount,
  });
}

class _ClaimRewardResult {
  final int previousTotalFlowers;
  final int flowersWon;
  final int totalAvailableFlowers;

  const _ClaimRewardResult({
    required this.previousTotalFlowers,
    required this.flowersWon,
    required this.totalAvailableFlowers,
  });
}

class _RewardAlreadyProcessedException implements Exception {
  const _RewardAlreadyProcessedException();
}

class _BlindDateQuestion {
  final String id;
  final String vi;
  final String en;
  final String optionAVi;
  final String optionAEn;
  final String optionBVi;
  final String optionBEn;

  const _BlindDateQuestion({
    required this.id,
    required this.vi,
    required this.en,
    required this.optionAVi,
    required this.optionAEn,
    required this.optionBVi,
    required this.optionBEn,
  });
}

// Không dùng lại các field đã có trong Home/Profile như religion,
// smoking, drinking, income, height, education, relationship goal...
const List<_BlindDateQuestion> _questionBank = [
  _BlindDateQuestion(
    id: 'date_coffee_dinner',
    vi: 'Bạn thích buổi hẹn đầu tiên nào hơn?',
    en: 'Which first date would you prefer?',
    optionAVi: '☕ Uống cà phê',
    optionAEn: '☕ Coffee',
    optionBVi: '🍽 Đi ăn tối',
    optionBEn: '🍽 Dinner',
  ),
  _BlindDateQuestion(
    id: 'weekend_home_out',
    vi: 'Cuối tuần lý tưởng của bạn là gì?',
    en: 'What is your ideal weekend?',
    optionAVi: '🏠 Ở nhà thư giãn',
    optionAEn: '🏠 Relax at home',
    optionBVi: '🚗 Ra ngoài khám phá',
    optionBEn: '🚗 Go out and explore',
  ),
  _BlindDateQuestion(
    id: 'beach_mountain',
    vi: 'Bạn thích đi đâu hơn?',
    en: 'Where would you rather go?',
    optionAVi: '🏖 Biển',
    optionAEn: '🏖 Beach',
    optionBVi: '⛰ Núi',
    optionBEn: '⛰ Mountains',
  ),
  _BlindDateQuestion(
    id: 'early_night',
    vi: 'Bạn thường thích nhịp sống nào hơn?',
    en: 'Which lifestyle rhythm suits you better?',
    optionAVi: '🌅 Dậy sớm',
    optionAEn: '🌅 Early bird',
    optionBVi: '🌙 Thức khuya',
    optionBEn: '🌙 Night owl',
  ),
  _BlindDateQuestion(
    id: 'plan_spontaneous',
    vi: 'Khi đi chơi, bạn thích kiểu nào hơn?',
    en: 'When going out, what do you prefer?',
    optionAVi: '📅 Lên kế hoạch trước',
    optionAEn: '📅 Plan ahead',
    optionBVi: '✨ Quyết định ngẫu hứng',
    optionBEn: '✨ Be spontaneous',
  ),
  _BlindDateQuestion(
    id: 'talk_wait_conflict',
    vi: 'Khi có mâu thuẫn, bạn thường làm gì?',
    en: 'What do you usually do during a disagreement?',
    optionAVi: '💬 Nói chuyện ngay',
    optionAEn: '💬 Talk immediately',
    optionBVi: '🕒 Bình tĩnh rồi nói',
    optionBEn: '🕒 Cool down first',
  ),
  _BlindDateQuestion(
    id: 'romantic_fun',
    vi: 'Bạn thích mối quan hệ mang cảm giác nào hơn?',
    en: 'What feeling do you prefer in a relationship?',
    optionAVi: '❤️ Lãng mạn',
    optionAEn: '❤️ Romantic',
    optionBVi: '😄 Vui vẻ, thoải mái',
    optionBEn: '😄 Fun and relaxed',
  ),
  _BlindDateQuestion(
    id: 'movie_walk',
    vi: 'Buổi tối lý tưởng của bạn là gì?',
    en: 'What is your ideal evening?',
    optionAVi: '🎬 Xem phim',
    optionAEn: '🎬 Watch a movie',
    optionBVi: '🌆 Đi dạo',
    optionBEn: '🌆 Go for a walk',
  ),
  _BlindDateQuestion(
    id: 'text_call',
    vi: 'Bạn thích giữ liên lạc bằng cách nào hơn?',
    en: 'How do you prefer to stay in touch?',
    optionAVi: '💬 Nhắn tin',
    optionAEn: '💬 Texting',
    optionBVi: '📞 Gọi điện',
    optionBEn: '📞 Phone calls',
  ),
  _BlindDateQuestion(
    id: 'cook_eatout',
    vi: 'Bạn thích bữa ăn nào hơn?',
    en: 'Which meal experience do you prefer?',
    optionAVi: '🍳 Cùng nhau nấu ăn',
    optionAEn: '🍳 Cook together',
    optionBVi: '🍜 Đi ăn ngoài',
    optionBEn: '🍜 Eat out',
  ),
  _BlindDateQuestion(
    id: 'dog_cat',
    vi: 'Bạn thích thú cưng nào hơn?',
    en: 'Which pet do you prefer?',
    optionAVi: '🐶 Chó',
    optionAEn: '🐶 Dogs',
    optionBVi: '🐱 Mèo',
    optionBEn: '🐱 Cats',
  ),
  _BlindDateQuestion(
    id: 'city_quiet',
    vi: 'Bạn thích sống ở đâu hơn?',
    en: 'Where would you rather live?',
    optionAVi: '🌃 Thành phố nhộn nhịp',
    optionAEn: '🌃 Busy city',
    optionBVi: '🌿 Khu vực yên tĩnh',
    optionBEn: '🌿 Quiet area',
  ),
  _BlindDateQuestion(
    id: 'surprise_plan',
    vi: 'Bạn thích điều gì hơn từ người mình yêu?',
    en: 'What do you prefer from your partner?',
    optionAVi: '🎁 Một điều bất ngờ',
    optionAEn: '🎁 A surprise',
    optionBVi: '🗓 Một kế hoạch rõ ràng',
    optionBEn: '🗓 A clear plan',
  ),
  _BlindDateQuestion(
    id: 'sunrise_sunset',
    vi: 'Bạn thích khoảnh khắc nào hơn?',
    en: 'Which moment do you prefer?',
    optionAVi: '🌅 Bình minh',
    optionAEn: '🌅 Sunrise',
    optionBVi: '🌇 Hoàng hôn',
    optionBEn: '🌇 Sunset',
  ),
  _BlindDateQuestion(
    id: 'karaoke_cinema',
    vi: 'Bạn thích hoạt động giải trí nào hơn?',
    en: 'Which entertainment activity do you prefer?',
    optionAVi: '🎤 Karaoke',
    optionAEn: '🎤 Karaoke',
    optionBVi: '🍿 Đi xem phim',
    optionBEn: '🍿 Cinema',
  ),
  _BlindDateQuestion(
    id: 'roadtrip_fly',
    vi: 'Bạn thích kiểu du lịch nào hơn?',
    en: 'Which travel style do you prefer?',
    optionAVi: '🚗 Road trip',
    optionAEn: '🚗 Road trip',
    optionBVi: '✈️ Đi máy bay',
    optionBEn: '✈️ Flying',
  ),
  _BlindDateQuestion(
    id: 'photos_moment',
    vi: 'Khi đi chơi, bạn thường thích điều gì hơn?',
    en: 'When going out, what do you prefer?',
    optionAVi: '📸 Chụp nhiều ảnh',
    optionAEn: '📸 Take lots of photos',
    optionBVi: '✨ Tận hưởng khoảnh khắc',
    optionBEn: '✨ Enjoy the moment',
  ),
  _BlindDateQuestion(
    id: 'lead_share',
    vi: 'Khi lên kế hoạch hẹn hò, bạn thích kiểu nào?',
    en: 'How do you prefer to plan dates?',
    optionAVi: '🙋 Một người chủ động',
    optionAEn: '🙋 One person leads',
    optionBVi: '🤝 Cùng nhau quyết định',
    optionBEn: '🤝 Decide together',
  ),
  _BlindDateQuestion(
    id: 'talk_listen',
    vi: 'Trong cuộc trò chuyện, bạn thường là người nào?',
    en: 'Who are you usually in a conversation?',
    optionAVi: '🗣 Nói nhiều hơn',
    optionAEn: '🗣 Talk more',
    optionBVi: '👂 Lắng nghe nhiều hơn',
    optionBEn: '👂 Listen more',
  ),
  _BlindDateQuestion(
    id: 'small_big_group',
    vi: 'Bạn thích gặp gỡ theo kiểu nào hơn?',
    en: 'What kind of social setting do you prefer?',
    optionAVi: '👥 Nhóm nhỏ',
    optionAEn: '👥 Small group',
    optionBVi: '🎉 Nhóm đông người',
    optionBEn: '🎉 Big group',
  ),
  _BlindDateQuestion(
    id: 'sweet_savoury',
    vi: 'Bạn thích món nào hơn?',
    en: 'Which do you prefer?',
    optionAVi: '🍰 Đồ ngọt',
    optionAEn: '🍰 Sweet food',
    optionBVi: '🍜 Đồ mặn',
    optionBEn: '🍜 Savoury food',
  ),
  _BlindDateQuestion(
    id: 'coffee_tea',
    vi: 'Bạn chọn thức uống nào?',
    en: 'Which drink would you choose?',
    optionAVi: '☕ Cà phê',
    optionAEn: '☕ Coffee',
    optionBVi: '🍵 Trà',
    optionBEn: '🍵 Tea',
  ),
  _BlindDateQuestion(
    id: 'hotpot_bbq',
    vi: 'Bạn thích món nào hơn?',
    en: 'Which would you rather eat?',
    optionAVi: '🍲 Lẩu',
    optionAEn: '🍲 Hotpot',
    optionBVi: '🥩 BBQ',
    optionBEn: '🥩 BBQ',
  ),
  _BlindDateQuestion(
    id: 'comedy_horror',
    vi: 'Bạn thích thể loại phim nào hơn?',
    en: 'Which movie genre do you prefer?',
    optionAVi: '😂 Phim hài',
    optionAEn: '😂 Comedy',
    optionBVi: '👻 Phim kinh dị',
    optionBEn: '👻 Horror',
  ),
  _BlindDateQuestion(
    id: 'music_podcast',
    vi: 'Khi lái xe, bạn thích nghe gì hơn?',
    en: 'What do you prefer listening to while driving?',
    optionAVi: '🎵 Âm nhạc',
    optionAEn: '🎵 Music',
    optionBVi: '🎙 Podcast',
    optionBEn: '🎙 Podcasts',
  ),
  _BlindDateQuestion(
    id: 'gift_experience',
    vi: 'Bạn thích món quà nào hơn?',
    en: 'Which gift would you prefer?',
    optionAVi: '🎁 Một món đồ',
    optionAEn: '🎁 A physical gift',
    optionBVi: '🎫 Một trải nghiệm',
    optionBEn: '🎫 An experience',
  ),
  _BlindDateQuestion(
    id: 'quiet_chatty_partner',
    vi: 'Bạn dễ bị thu hút bởi người nào hơn?',
    en: 'Who are you more attracted to?',
    optionAVi: '🤫 Trầm tính',
    optionAEn: '🤫 Quiet',
    optionBVi: '😄 Hoạt bát',
    optionBEn: '😄 Outgoing',
  ),
  _BlindDateQuestion(
    id: 'fashion_comfort',
    vi: 'Khi ra ngoài, bạn ưu tiên điều gì hơn?',
    en: 'When going out, what matters more?',
    optionAVi: '✨ Ăn mặc đẹp',
    optionAEn: '✨ Dress stylishly',
    optionBVi: '👕 Thoải mái',
    optionBEn: '👕 Be comfortable',
  ),
  _BlindDateQuestion(
    id: 'museum_market',
    vi: 'Bạn thích đi đâu vào cuối tuần?',
    en: 'Where would you rather go on a weekend?',
    optionAVi: '🖼 Bảo tàng',
    optionAEn: '🖼 Museum',
    optionBVi: '🛍 Chợ cuối tuần',
    optionBEn: '🛍 Weekend market',
  ),
  _BlindDateQuestion(
    id: 'picnic_restaurant',
    vi: 'Bạn thích bữa hẹn nào hơn?',
    en: 'Which date meal do you prefer?',
    optionAVi: '🧺 Picnic',
    optionAEn: '🧺 Picnic',
    optionBVi: '🍽 Nhà hàng',
    optionBEn: '🍽 Restaurant',
  ),
  _BlindDateQuestion(
    id: 'rain_sun',
    vi: 'Bạn thích thời tiết nào hơn?',
    en: 'Which weather do you prefer?',
    optionAVi: '🌧 Trời mưa',
    optionAEn: '🌧 Rainy weather',
    optionBVi: '☀️ Trời nắng',
    optionBEn: '☀️ Sunny weather',
  ),
  _BlindDateQuestion(
    id: 'book_series',
    vi: 'Bạn thích thư giãn bằng cách nào hơn?',
    en: 'How do you prefer to relax?',
    optionAVi: '📚 Đọc sách',
    optionAEn: '📚 Read a book',
    optionBVi: '📺 Xem phim bộ',
    optionBEn: '📺 Watch a series',
  ),
  _BlindDateQuestion(
    id: 'save_spend',
    vi: 'Khi có một khoản tiền dư, bạn thường muốn làm gì?',
    en: 'What would you rather do with extra money?',
    optionAVi: '💰 Tiết kiệm',
    optionAEn: '💰 Save it',
    optionBVi: '✨ Tận hưởng một trải nghiệm',
    optionBEn: '✨ Enjoy an experience',
  ),
  _BlindDateQuestion(
    id: 'party_dinner',
    vi: 'Bạn thích buổi gặp nào hơn?',
    en: 'Which gathering do you prefer?',
    optionAVi: '🎉 Một bữa tiệc',
    optionAEn: '🎉 A party',
    optionBVi: '🍽 Bữa tối yên tĩnh',
    optionBEn: '🍽 A quiet dinner',
  ),
  _BlindDateQuestion(
    id: 'message_first_wait',
    vi: 'Sau buổi hẹn đầu, bạn thường thích điều gì?',
    en: 'After a first date, what do you prefer?',
    optionAVi: '💬 Chủ động nhắn trước',
    optionAEn: '💬 Message first',
    optionBVi: '⏳ Chờ người kia nhắn',
    optionBEn: '⏳ Wait for them',
  ),
  _BlindDateQuestion(
    id: 'public_private_affection',
    vi: 'Bạn thích thể hiện tình cảm theo cách nào hơn?',
    en: 'How do you prefer to show affection?',
    optionAVi: '🤝 Thoải mái nơi công cộng',
    optionAEn: '🤝 Comfortable in public',
    optionBVi: '🏠 Riêng tư hơn',
    optionBEn: '🏠 More private',
  ),
  _BlindDateQuestion(
    id: 'daily_space',
    vi: 'Khi đang tìm hiểu nhau, bạn thích liên lạc thế nào?',
    en: 'When getting to know someone, how much contact do you prefer?',
    optionAVi: '💞 Nói chuyện mỗi ngày',
    optionAEn: '💞 Talk every day',
    optionBVi: '🌿 Có không gian riêng',
    optionBEn: '🌿 Have personal space',
  ),
  _BlindDateQuestion(
    id: 'same_different_hobbies',
    vi: 'Bạn thích hai người có sở thích thế nào?',
    en: 'What kind of hobbies should a couple have?',
    optionAVi: '❤️ Nhiều sở thích giống nhau',
    optionAEn: '❤️ Many shared hobbies',
    optionBVi: '✨ Mỗi người một sở thích',
    optionBEn: '✨ Different hobbies',
  ),
  _BlindDateQuestion(
    id: 'adventure_relax_trip',
    vi: 'Kỳ nghỉ lý tưởng của bạn là gì?',
    en: 'What is your ideal holiday?',
    optionAVi: '🧗 Phiêu lưu',
    optionAEn: '🧗 Adventure',
    optionBVi: '🏝 Nghỉ dưỡng',
    optionBEn: '🏝 Relaxing resort',
  ),
  _BlindDateQuestion(
    id: 'dance_sit',
    vi: 'Ở một buổi tiệc, bạn thường thích gì hơn?',
    en: 'At a party, what do you prefer?',
    optionAVi: '💃 Nhảy và vui chơi',
    optionAEn: '💃 Dance and have fun',
    optionBVi: '🪑 Ngồi nói chuyện',
    optionBEn: '🪑 Sit and talk',
  ),
  _BlindDateQuestion(
    id: 'window_aisle',
    vi: 'Khi đi máy bay, bạn chọn chỗ nào?',
    en: 'Which plane seat do you choose?',
    optionAVi: '🪟 Ghế cửa sổ',
    optionAEn: '🪟 Window seat',
    optionBVi: '🚶 Ghế lối đi',
    optionBEn: '🚶 Aisle seat',
  ),
  _BlindDateQuestion(
    id: 'winter_summer',
    vi: 'Bạn thích mùa nào hơn?',
    en: 'Which season do you prefer?',
    optionAVi: '❄️ Mùa đông',
    optionAEn: '❄️ Winter',
    optionBVi: '☀️ Mùa hè',
    optionBEn: '☀️ Summer',
  ),
  _BlindDateQuestion(
    id: 'flowers_chocolate',
    vi: 'Bạn thích món quà lãng mạn nào hơn?',
    en: 'Which romantic gift do you prefer?',
    optionAVi: '🌸 Hoa',
    optionAEn: '🌸 Flowers',
    optionBVi: '🍫 Chocolate',
    optionBEn: '🍫 Chocolate',
  ),
  _BlindDateQuestion(
    id: 'voice_text_goodnight',
    vi: 'Bạn thích nhận điều gì trước khi ngủ?',
    en: 'What would you prefer before bed?',
    optionAVi: '🎙 Tin nhắn thoại',
    optionAEn: '🎙 A voice message',
    optionBVi: '💬 Tin nhắn chúc ngủ ngon',
    optionBEn: '💬 A goodnight text',
  ),
  _BlindDateQuestion(
    id: 'double_single_date',
    vi: 'Bạn thích kiểu hẹn nào hơn?',
    en: 'Which date style do you prefer?',
    optionAVi: '👫 Hẹn đôi cùng bạn bè',
    optionAEn: '👫 Double date',
    optionBVi: '❤️ Chỉ hai người',
    optionBEn: '❤️ Just the two of us',
  ),
  _BlindDateQuestion(
    id: 'photo_memory',
    vi: 'Sau một chuyến đi, bạn thích lưu lại điều gì hơn?',
    en: 'After a trip, what do you prefer to keep?',
    optionAVi: '📸 Nhiều ảnh đẹp',
    optionAEn: '📸 Lots of photos',
    optionBVi: '💭 Những kỷ niệm riêng',
    optionBEn: '💭 Personal memories',
  ),
  _BlindDateQuestion(
    id: 'morning_night_date',
    vi: 'Bạn thích hẹn hò vào lúc nào hơn?',
    en: 'When do you prefer going on dates?',
    optionAVi: '☀️ Ban ngày',
    optionAEn: '☀️ Daytime',
    optionBVi: '🌙 Buổi tối',
    optionBEn: '🌙 Evening',
  ),
  _BlindDateQuestion(
    id: 'handmade_bought',
    vi: 'Bạn thích món quà nào hơn?',
    en: 'Which gift do you prefer?',
    optionAVi: '🧶 Quà tự làm',
    optionAEn: '🧶 Handmade gift',
    optionBVi: '🛍 Quà được mua',
    optionBEn: '🛍 Store-bought gift',
  ),
  _BlindDateQuestion(
    id: 'deep_fun_chat',
    vi: 'Bạn thích cuộc trò chuyện nào hơn?',
    en: 'Which conversation do you prefer?',
    optionAVi: '💭 Sâu sắc',
    optionAEn: '💭 Deep and meaningful',
    optionBVi: '😂 Vui nhộn',
    optionBEn: '😂 Light and funny',
  ),
  _BlindDateQuestion(
    id: 'schedule_free_day',
    vi: 'Ngày nghỉ của bạn thường như thế nào?',
    en: 'What is your day off usually like?',
    optionAVi: '🗓 Có kế hoạch',
    optionAEn: '🗓 Planned',
    optionBVi: '🌿 Tự do tùy hứng',
    optionBEn: '🌿 Go with the flow',
  ),
  _BlindDateQuestion(
    id: 'concert_home_music',
    vi: 'Bạn thích nghe nhạc theo cách nào hơn?',
    en: 'How do you prefer listening to music?',
    optionAVi: '🎤 Đi concert',
    optionAEn: '🎤 Go to a concert',
    optionBVi: '🎧 Nghe ở nhà',
    optionBEn: '🎧 Listen at home',
  ),
  _BlindDateQuestion(
    id: 'boardgame_video',
    vi: 'Bạn thích chơi gì hơn?',
    en: 'Which game do you prefer?',
    optionAVi: '🎲 Board game',
    optionAEn: '🎲 Board games',
    optionBVi: '🎮 Video game',
    optionBEn: '🎮 Video games',
  ),
  _BlindDateQuestion(
    id: 'explore_repeat_place',
    vi: 'Khi đi ăn, bạn thích kiểu nào hơn?',
    en: 'When eating out, what do you prefer?',
    optionAVi: '🗺 Thử nơi mới',
    optionAEn: '🗺 Try somewhere new',
    optionBVi: '❤️ Quay lại nơi yêu thích',
    optionBEn: '❤️ Return to a favourite place',
  ),
  _BlindDateQuestion(
    id: 'busy_relaxed_day',
    vi: 'Bạn thích một ngày như thế nào hơn?',
    en: 'What kind of day do you prefer?',
    optionAVi: '⚡ Bận rộn, nhiều hoạt động',
    optionAEn: '⚡ Busy and active',
    optionBVi: '🌿 Chậm rãi, thư giãn',
    optionBEn: '🌿 Slow and relaxed',
  ),
  _BlindDateQuestion(
    id: 'joke_serious',
    vi: 'Bạn dễ bị thu hút bởi điều gì hơn?',
    en: 'What attracts you more?',
    optionAVi: '😂 Khiếu hài hước',
    optionAEn: '😂 A good sense of humour',
    optionBVi: '🧠 Sự nghiêm túc, sâu sắc',
    optionBEn: '🧠 Serious and thoughtful',
  ),
  _BlindDateQuestion(
    id: 'first_last_minute',
    vi: 'Bạn thường chuẩn bị cho buổi hẹn thế nào?',
    en: 'How do you usually prepare for a date?',
    optionAVi: '⏰ Chuẩn bị sớm',
    optionAEn: '⏰ Prepare early',
    optionBVi: '🏃 Gần giờ mới chuẩn bị',
    optionBEn: '🏃 Get ready at the last minute',
  ),
    _BlindDateQuestion(
    id: 'apology_words_actions',
    vi: 'Khi xin lỗi, bạn đánh giá cao điều gì hơn?',
    en: 'When someone apologises, what matters more to you?',
    optionAVi: '💬 Lời xin lỗi chân thành',
    optionAEn: '💬 Sincere words',
    optionBVi: '🤝 Hành động thay đổi',
    optionBEn: '🤝 Changed behaviour',
  ),

  _BlindDateQuestion(
    id: 'date_activity_conversation',
    vi: 'Trong một buổi hẹn, bạn thích điều gì hơn?',
    en: 'What do you prefer on a date?',
    optionAVi: '🎳 Cùng tham gia hoạt động',
    optionAEn: '🎳 Doing an activity together',
    optionBVi: '💬 Ngồi nói chuyện thật lâu',
    optionBEn: '💬 Having a long conversation',
  ),

  _BlindDateQuestion(
    id: 'bad_day_comfort_space',
    vi: 'Khi có một ngày không vui, bạn muốn người yêu làm gì?',
    en: 'After a difficult day, what would you want from your partner?',
    optionAVi: '🫂 Ở bên và an ủi',
    optionAEn: '🫂 Stay and comfort me',
    optionBVi: '🌿 Cho tôi không gian riêng',
    optionBEn: '🌿 Give me some space',
  ),

  _BlindDateQuestion(
    id: 'birthday_party_quiet',
    vi: 'Bạn muốn tổ chức sinh nhật theo cách nào hơn?',
    en: 'How would you prefer to celebrate your birthday?',
    optionAVi: '🎉 Tiệc cùng nhiều người',
    optionAEn: '🎉 A party with many people',
    optionBVi: '🥂 Một buổi tối riêng tư',
    optionBEn: '🥂 A quiet private evening',
  ),

  _BlindDateQuestion(
    id: 'compliment_appearance_personality',
    vi: 'Bạn thích nhận lời khen nào hơn?',
    en: 'Which compliment would you rather receive?',
    optionAVi: '✨ Ngoại hình của bạn rất đẹp',
    optionAEn: '✨ You look amazing',
    optionBVi: '💛 Tính cách của bạn thật tuyệt',
    optionBEn: '💛 You have a wonderful personality',
  ),

  _BlindDateQuestion(
    id: 'first_date_pay_split',
    vi: 'Trong buổi hẹn đầu, bạn thích cách thanh toán nào hơn?',
    en: 'How would you prefer to pay on a first date?',
    optionAVi: '💳 Một người mời',
    optionAEn: '💳 One person pays',
    optionBVi: '🤝 Cùng chia sẻ',
    optionBEn: '🤝 Split the bill',
  ),

  _BlindDateQuestion(
    id: 'holiday_family_couple',
    vi: 'Trong kỳ nghỉ dài, bạn muốn dành nhiều thời gian hơn cho ai?',
    en: 'During a long holiday, who would you prefer to spend more time with?',
    optionAVi: '👨‍👩‍👧‍👦 Gia đình và bạn bè',
    optionAEn: '👨‍👩‍👧‍👦 Family and friends',
    optionBVi: '❤️ Người yêu',
    optionBEn: '❤️ My partner',
  ),

  _BlindDateQuestion(
    id: 'decision_logic_feeling',
    vi: 'Khi đưa ra quyết định quan trọng, bạn thường dựa vào điều gì?',
    en: 'When making an important decision, what do you rely on more?',
    optionAVi: '🧠 Lý trí',
    optionAEn: '🧠 Logic',
    optionBVi: '❤️ Cảm xúc',
    optionBEn: '❤️ Feelings',
  ),

  _BlindDateQuestion(
    id: 'home_clean_relaxed',
    vi: 'Bạn thích không gian sống theo kiểu nào hơn?',
    en: 'What kind of home environment do you prefer?',
    optionAVi: '🧹 Gọn gàng, ngăn nắp',
    optionAEn: '🧹 Clean and organised',
    optionBVi: '🛋 Thoải mái, tự nhiên',
    optionBEn: '🛋 Relaxed and casual',
  ),

  _BlindDateQuestion(
    id: 'weeknight_social_rest',
    vi: 'Sau một ngày làm việc, bạn thích làm gì hơn?',
    en: 'After a workday, what would you rather do?',
    optionAVi: '🍹 Gặp bạn bè',
    optionAEn: '🍹 Meet friends',
    optionBVi: '🏠 Về nhà nghỉ ngơi',
    optionBEn: '🏠 Relax at home',
  ),

  _BlindDateQuestion(
    id: 'relationship_private_share',
    vi: 'Bạn thích chia sẻ chuyện tình cảm với người khác không?',
    en: 'How do you feel about sharing relationship details with others?',
    optionAVi: '🔒 Giữ riêng tư',
    optionAEn: '🔒 Keep it private',
    optionBVi: '👭 Chia sẻ với người thân',
    optionBEn: '👭 Share with close people',
  ),

  _BlindDateQuestion(
    id: 'date_repeat_new',
    vi: 'Bạn thích các buổi hẹn theo kiểu nào hơn?',
    en: 'What kind of dates do you prefer?',
    optionAVi: '❤️ Quay lại nơi quen thuộc',
    optionAEn: '❤️ Return to favourite places',
    optionBVi: '✨ Luôn thử điều mới',
    optionBEn: '✨ Always try something new',
  ),

  _BlindDateQuestion(
    id: 'problem_advice_listen',
    vi: 'Khi bạn kể một vấn đề, bạn muốn người kia làm gì?',
    en: 'When you share a problem, what do you want your partner to do?',
    optionAVi: '💡 Đưa ra lời khuyên',
    optionAEn: '💡 Give advice',
    optionBVi: '👂 Chỉ cần lắng nghe',
    optionBEn: '👂 Simply listen',
  ),

  _BlindDateQuestion(
    id: 'arrival_early_ontime',
    vi: 'Khi đi hẹn, bạn thường đến vào lúc nào?',
    en: 'When meeting someone, when do you usually arrive?',
    optionAVi: '⏰ Đến sớm',
    optionAEn: '⏰ Arrive early',
    optionBVi: '🕐 Đến đúng giờ',
    optionBEn: '🕐 Arrive right on time',
  ),

  _BlindDateQuestion(
    id: 'phone_date_photos',
    vi: 'Trong buổi hẹn, bạn thích sử dụng điện thoại thế nào?',
    en: 'How do you prefer to use your phone during a date?',
    optionAVi: '📵 Cất điện thoại để trò chuyện',
    optionAEn: '📵 Put it away and talk',
    optionBVi: '📸 Dùng để chụp lại kỷ niệm',
    optionBEn: '📸 Use it to capture memories',
  ),

  _BlindDateQuestion(
    id: 'small_gesture_big_surprise',
    vi: 'Điều gì khiến bạn vui hơn trong tình yêu?',
    en: 'What would make you happier in a relationship?',
    optionAVi: '💌 Những quan tâm nhỏ mỗi ngày',
    optionAEn: '💌 Small daily gestures',
    optionBVi: '🎁 Một bất ngờ thật lớn',
    optionBEn: '🎁 One big surprise',
  ),

  _BlindDateQuestion(
    id: 'weekend_schedule_free',
    vi: 'Bạn thích cuối tuần được sắp xếp như thế nào?',
    en: 'How do you prefer your weekend to be organised?',
    optionAVi: '📋 Có lịch trình rõ ràng',
    optionAEn: '📋 Have a clear schedule',
    optionBVi: '☁️ Để mọi thứ tự nhiên',
    optionBEn: '☁️ Let things happen naturally',
  ),

  _BlindDateQuestion(
    id: 'partner_similarity_balance',
    vi: 'Bạn thích người yêu giống hay khác mình?',
    en: 'Would you prefer a partner who is similar to you or different?',
    optionAVi: '🪞 Giống mình nhiều hơn',
    optionAEn: '🪞 Mostly similar to me',
    optionBVi: '🧩 Khác để bù trừ cho nhau',
    optionBEn: '🧩 Different and complementary',
  ),

  _BlindDateQuestion(
    id: 'celebrate_anniversary_simple',
    vi: 'Bạn thích kỷ niệm ngày đặc biệt theo cách nào?',
    en: 'How would you prefer to celebrate a special anniversary?',
    optionAVi: '🌹 Chuẩn bị thật đặc biệt',
    optionAEn: '🌹 Make it very special',
    optionBVi: '🍜 Đơn giản nhưng ấm áp',
    optionBEn: '🍜 Keep it simple and meaningful',
  ),

  _BlindDateQuestion(
    id: 'meet_friends_early_later',
    vi: 'Khi mới tìm hiểu, bạn muốn gặp bạn bè của người ấy lúc nào?',
    en: 'When dating someone new, when would you want to meet their friends?',
    optionAVi: '👋 Khá sớm',
    optionAEn: '👋 Fairly early',
    optionBVi: '⏳ Khi mối quan hệ nghiêm túc hơn',
    optionBEn: '⏳ When the relationship is more serious',
  ),

  _BlindDateQuestion(
    id: 'message_style_short_long',
    vi: 'Bạn thích kiểu nhắn tin nào hơn?',
    en: 'What kind of texting style do you prefer?',
    optionAVi: '⚡ Ngắn gọn nhưng thường xuyên',
    optionAEn: '⚡ Short but frequent messages',
    optionBVi: '📝 Tin nhắn dài và sâu sắc',
    optionBEn: '📝 Long and meaningful messages',
  ),

  _BlindDateQuestion(
    id: 'couple_activity_sport_art',
    vi: 'Bạn muốn cùng người yêu tham gia hoạt động nào hơn?',
    en: 'Which activity would you rather do with your partner?',
    optionAVi: '🏸 Thể thao',
    optionAEn: '🏸 Sports',
    optionBVi: '🎨 Nghệ thuật hoặc sáng tạo',
    optionBEn: '🎨 Art or creative activities',
  ),

  _BlindDateQuestion(
    id: 'weather_stay_out',
    vi: 'Khi thời tiết xấu, bạn thích làm gì hơn?',
    en: 'When the weather is bad, what would you rather do?',
    optionAVi: '🛋 Ở nhà cùng nhau',
    optionAEn: '🛋 Stay home together',
    optionBVi: '☔ Vẫn ra ngoài khám phá',
    optionBEn: '☔ Still go out and explore',
  ),

  _BlindDateQuestion(
    id: 'learn_partner_hobby',
    vi: 'Nếu người yêu có sở thích khác bạn, bạn sẽ làm gì?',
    en: 'If your partner has a different hobby, what would you do?',
    optionAVi: '🌱 Thử học cùng họ',
    optionAEn: '🌱 Try learning it with them',
    optionBVi: '🙌 Ủng hộ nhưng giữ sở thích riêng',
    optionBEn: '🙌 Support them but keep separate hobbies',
  ),

  _BlindDateQuestion(
    id: 'conversation_deep_playful',
    vi: 'Bạn thích cuộc trò chuyện nào hơn?',
    en: 'What kind of conversation do you prefer?',
    optionAVi: '🌌 Sâu sắc về cuộc sống',
    optionAEn: '🌌 Deep conversations about life',
    optionBVi: '😄 Vui vẻ và trêu đùa',
    optionBEn: '😄 Playful and funny conversations',
  ),

  _BlindDateQuestion(
    id: 'support_presence_solution',
    vi: 'Khi người yêu gặp khó khăn, bạn thường muốn giúp thế nào?',
    en: 'When your partner is struggling, how would you prefer to help?',
    optionAVi: '🫶 Ở bên động viên',
    optionAEn: '🫶 Be there emotionally',
    optionBVi: '🛠 Cùng tìm cách giải quyết',
    optionBEn: '🛠 Help find a solution',
  ),

  _BlindDateQuestion(
    id: 'memory_photo_souvenir',
    vi: 'Sau một chuyến đi, bạn thích giữ lại điều gì hơn?',
    en: 'After a trip, what would you rather keep as a memory?',
    optionAVi: '📷 Những bức ảnh',
    optionAEn: '📷 Photos',
    optionBVi: '🎁 Một món quà lưu niệm',
    optionBEn: '🎁 A souvenir',
  ),

  _BlindDateQuestion(
    id: 'new_place_local_food',
    vi: 'Khi đến một nơi mới, bạn muốn làm gì trước?',
    en: 'When visiting a new place, what would you want to do first?',
    optionAVi: '🗺 Tham quan địa điểm nổi tiếng',
    optionAEn: '🗺 Visit a famous attraction',
    optionBVi: '🍲 Thử món ăn địa phương',
    optionBEn: '🍲 Try the local food',
  ),

  _BlindDateQuestion(
    id: 'relationship_independent_together',
    vi: 'Trong một mối quan hệ, bạn thích cách sống nào hơn?',
    en: 'In a relationship, which lifestyle do you prefer?',
    optionAVi: '🌿 Mỗi người vẫn độc lập',
    optionAEn: '🌿 Both remain independent',
    optionBVi: '💞 Làm hầu hết mọi việc cùng nhau',
    optionBEn: '💞 Do most things together',
  ),

  _BlindDateQuestion(
    id: 'future_discuss_early_natural',
    vi: 'Khi mới hẹn hò, bạn thích nói về tương lai lúc nào?',
    en: 'When dating someone new, when do you prefer to discuss the future?',
    optionAVi: '🗣 Nói rõ khá sớm',
    optionAEn: '🗣 Discuss it fairly early',
    optionBVi: '🌱 Để mối quan hệ phát triển tự nhiên',
    optionBEn: '🌱 Let the relationship develop naturally',
  ),
];

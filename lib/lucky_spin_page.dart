import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LuckySpinPage extends StatefulWidget {
  final String languageCode;

  const LuckySpinPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<LuckySpinPage> createState() => _LuckySpinPageState();
}

class _LuckySpinPageState extends State<LuckySpinPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random.secure();
  final ScrollController _scrollController = ScrollController();

  late final AnimationController _spinController;
  Animation<double>? _spinAnimation;

  bool _isLoading = true;
  bool _isSpinning = false;
  bool _isProcessingReward = false;

  double _currentRotation = 0;

  int _spinsUsedToday = 0;
  int _flowerBalance = 0;

  String? _lastResultKey;

  // Phần thưởng đang chờ user bấm Nhận hoặc Không nhận.
  String? _pendingRewardId;
  String? _pendingRewardKey;
  int _pendingFlowers = 0;

  bool get isVi => widget.languageCode == 'vi';

  User? get currentUser => FirebaseAuth.instance.currentUser;

  int get _spinsRemaining {
    final remaining = 3 - _spinsUsedToday;
    return remaining < 0 ? 0 : remaining;
  }

  bool get _hasPendingReward {
    return _pendingRewardId != null &&
        _pendingRewardId!.isNotEmpty &&
        _pendingFlowers > 0;
  }

  String _tr(String vi, String en) {
    return isVi ? vi : en;
  }

  final List<_WheelItem> _wheelItems = const [
    _WheelItem(
      key: 'one_flower',
      vi: '1 Flower',
      en: '1 Flower',
      icon: Icons.local_florist_rounded,
      color: Color(0xFFFF7E9D),
    ),
    _WheelItem(
      key: 'five_flowers',
      vi: '5 Flowers',
      en: '5 Flowers',
      icon: Icons.local_florist_rounded,
      color: Color(0xFFFFC857),
    ),
    _WheelItem(
      key: 'ten_flowers',
      vi: '10 Flowers',
      en: '10 Flowers',
      icon: Icons.local_florist_rounded,
      color: Color(0xFF50B8E7),
    ),
    _WheelItem(
      key: 'one_week_vip',
      vi: '1 tuần VIP',
      en: '1 Week VIP',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFF8E6CE8),
    ),
    _WheelItem(
      key: 'try_again',
      vi: 'Thử lại',
      en: 'Try Again',
      icon: Icons.replay_rounded,
      color: Color(0xFF58C78B),
    ),
    _WheelItem(
      key: 'better_luck',
      vi: 'Không Trúng',
      en: 'No Prize',
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: Color(0xFFFF886D),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4300),
    );

    _spinController.addListener(() {
      final animation = _spinAnimation;

      if (animation == null || !mounted) return;

      setState(() {
        _currentRotation = animation.value;
      });
    });

    _loadSpinData();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(
          (value ?? '').toString(),
        ) ??
        0;
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadSpinData() async {
    final user = currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final now = DateTime.now();
      final todayKey = _dateKey(now);

      final userRef = _firestore
          .collection('users')
          .doc(user.uid);

      final userDoc = await userRef.get();
      final data = userDoc.data() ?? {};

      final savedDateKey =
          (data['luckySpinDateKey'] ?? '').toString().trim();

      var spinsUsedToday = _parseInt(
        data['luckySpinSpinsUsedToday'],
      );

      if (savedDateKey != todayKey) {
        spinsUsedToday = 0;

        await userRef.set({
          'luckySpinDateKey': todayKey,
          'luckySpinSpinsUsedToday': 0,
          'luckySpinUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final pendingStatus =
          (data['luckySpinPendingRewardStatus'] ?? '')
              .toString()
              .trim();

      final pendingRewardId =
          (data['luckySpinPendingRewardId'] ?? '')
              .toString()
              .trim();

      final pendingRewardKey =
          (data['luckySpinPendingRewardKey'] ?? '')
              .toString()
              .trim();

      final pendingFlowers = _parseInt(
        data['luckySpinPendingFlowers'],
      );

      final hasPendingReward =
          pendingStatus == 'pending' &&
          pendingRewardId.isNotEmpty &&
          pendingFlowers > 0;

      if (!mounted) return;

      setState(() {
        _spinsUsedToday = spinsUsedToday;
        _flowerBalance = _parseInt(
          data['flowerBalance'],
        );

        final savedResult =
            (data['luckySpinLastResult'] ?? '')
                .toString()
                .trim();

        _lastResultKey =
            savedResult.isEmpty ? null : savedResult;

        _pendingRewardId =
            hasPendingReward ? pendingRewardId : null;

        _pendingRewardKey =
            hasPendingReward ? pendingRewardKey : null;

        _pendingFlowers =
            hasPendingReward ? pendingFlowers : 0;

        _isLoading = false;
      });

      if (_hasPendingReward) {
        await _scrollToResult();
      }
    } catch (e) {
      debugPrint('LOAD LUCKY SPIN ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Không thể tải vòng quay. Vui lòng thử lại.',
              'Unable to load the wheel. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  // ============================================================
  // SPIN
  // ============================================================

  Future<void> _startSpin() async {
    if (_isLoading ||
        _isSpinning ||
        _isProcessingReward) {
      return;
    }

    if (_hasPendingReward) {
      await _scrollToResult();
      return;
    }

    if (_spinsRemaining <= 0) {
      await _scrollToResult();
      return;
    }

    final user = currentUser;
    if (user == null) return;

    setState(() {
      _isSpinning = true;
    });

    try {
      final spinResult = await _firestore
          .runTransaction<_SpinTransactionResult>(
        (transaction) async {
          final userRef = _firestore
              .collection('users')
              .doc(user.uid);

          final snapshot = await transaction.get(userRef);
          final data = snapshot.data() ?? {};

          // Không được quay tiếp khi phần thưởng cũ chưa xử lý.
          final savedPendingStatus =
              (data['luckySpinPendingRewardStatus'] ?? '')
                  .toString()
                  .trim();

          final savedPendingFlowers = _parseInt(
            data['luckySpinPendingFlowers'],
          );

          if (savedPendingStatus == 'pending' &&
              savedPendingFlowers > 0) {
            throw const _PendingRewardException();
          }

          final now = DateTime.now();
          final todayKey = _dateKey(now);

          final savedDateKey =
              (data['luckySpinDateKey'] ?? '')
                  .toString()
                  .trim();

          var spinsUsedToday = _parseInt(
            data['luckySpinSpinsUsedToday'],
          );

          if (savedDateKey != todayKey) {
            spinsUsedToday = 0;
          }

          if (spinsUsedToday >= 3) {
            throw const _NoSpinsLeftException();
          }

          final spinNumber = spinsUsedToday + 1;

          // Dùng cả field mới và field cũ để tương thích dữ liệu cũ.
          final firstRewardAlreadyUsed =
              data['luckySpinFirstRewardOffered'] == true ||
              data['luckySpinFirstRewardClaimed'] == true;

          final nextRewardDate = _timestampToDate(
            data['luckySpinNextRewardDate'],
          );

          var winningSpinNumber = _parseInt(
            data['luckySpinWinningSpinNumber'],
          );

          if (winningSpinNumber < 1 ||
              winningSpinNumber > 3) {
            winningSpinNumber = 1 + _random.nextInt(3);
          }

          String resultKey;
          int flowersWon = 0;

          DateTime? newNextRewardDate;
          int? newWinningSpinNumber;

          // ====================================================
          // LẦN ĐẦU TIÊN:
          // Lượt 2 được đề nghị nhận 5 Flowers.
          // Dù nhận hay từ chối, 5 Flowers không xuất hiện lại.
          // ====================================================

          if (!firstRewardAlreadyUsed &&
              spinNumber == 2) {
            resultKey = 'five_flowers';
            flowersWon = 5;

            final randomDays =
                7 + _random.nextInt(6);

            newNextRewardDate =
                _startOfDay(now).add(
              Duration(days: randomDays),
            );

            newWinningSpinNumber =
                1 + _random.nextInt(3);
          } else {
            // ==================================================
            // SAU LẦN ĐẦU:
            // Chỉ có thể trúng đúng 1 Flower.
            // ==================================================

            final today = _startOfDay(now);

            final savedRewardDay =
                nextRewardDate == null
                    ? null
                    : _startOfDay(nextRewardDate);

            final isRewardDay =
                firstRewardAlreadyUsed &&
                savedRewardDay != null &&
                !today.isBefore(savedRewardDay);

            if (isRewardDay &&
                spinNumber == winningSpinNumber) {
              resultKey = 'one_flower';
              flowersWon = 1;

              final randomDays =
                  7 + _random.nextInt(6);

              newNextRewardDate = today.add(
                Duration(days: randomDays),
              );

              newWinningSpinNumber =
                  1 + _random.nextInt(3);
            } else {
              resultKey = _random.nextBool()
                  ? 'try_again'
                  : 'better_luck';
            }
          }

          final pendingRewardId =
              flowersWon > 0
                  ? '$todayKey-$spinNumber'
                  : '';

          final updateData = <String, dynamic>{
            'luckySpinDateKey': todayKey,
            'luckySpinSpinsUsedToday': spinNumber,
            'luckySpinLastResult': resultKey,
            'luckySpinLastSpinAt':
                FieldValue.serverTimestamp(),
            'luckySpinUpdatedAt':
                FieldValue.serverTimestamp(),
          };

          // Lần thưởng 5 Flowers đã được sử dụng.
          if (resultKey == 'five_flowers') {
            updateData['luckySpinFirstRewardOffered'] =
                true;

            updateData['luckySpinFirstRewardOfferedAt'] =
                FieldValue.serverTimestamp();
          }

          // Khi trúng chỉ lưu phần thưởng chờ nhận.
          // Chưa cộng vào flowerBalance.
          if (flowersWon > 0) {
            updateData['luckySpinPendingRewardId'] =
                pendingRewardId;

            updateData['luckySpinPendingRewardKey'] =
                resultKey;

            updateData['luckySpinPendingFlowers'] =
                flowersWon;

            updateData['luckySpinPendingRewardStatus'] =
                'pending';

            updateData['luckySpinPendingRewardCreatedAt'] =
                FieldValue.serverTimestamp();
          }

          if (newNextRewardDate != null) {
            updateData['luckySpinNextRewardDate'] =
                Timestamp.fromDate(newNextRewardDate);
          }

          if (newWinningSpinNumber != null) {
            updateData['luckySpinWinningSpinNumber'] =
                newWinningSpinNumber;
          }

          transaction.set(
            userRef,
            updateData,
            SetOptions(merge: true),
          );

          return _SpinTransactionResult(
            resultKey: resultKey,
            spinNumber: spinNumber,
            flowersWon: flowersWon,
            pendingRewardId:
                pendingRewardId.isEmpty
                    ? null
                    : pendingRewardId,
          );
        },
      );

      await _animateWheelToResult(
        spinResult.resultKey,
      );

      if (!mounted) return;

      setState(() {
        _spinsUsedToday = spinResult.spinNumber;
        _lastResultKey = spinResult.resultKey;

        if (spinResult.flowersWon > 0) {
          _pendingRewardId =
              spinResult.pendingRewardId;

          _pendingRewardKey =
              spinResult.resultKey;

          _pendingFlowers =
              spinResult.flowersWon;
        }

        _isSpinning = false;
      });

      await _scrollToResult();
    } on _PendingRewardException {
      if (!mounted) return;

      setState(() {
        _isSpinning = false;
      });

      await _loadSpinData();
      await _scrollToResult();
    } on _NoSpinsLeftException {
      if (!mounted) return;

      setState(() {
        _spinsUsedToday = 3;
        _isSpinning = false;
      });

      await _scrollToResult();
    } catch (e) {
      debugPrint('LUCKY SPIN ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isSpinning = false;
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
Future<int> _sentFlowerCount() async {
  final user = currentUser;
  if (user == null) return 0;

  final snapshot = await _firestore
      .collection('swipes')
      .where('fromUserId', isEqualTo: user.uid)
      .where('action', isEqualTo: 'flower')
      .get();

  return snapshot.docs.length;
}
  // ============================================================
  // CLAIM REWARD
  // ============================================================

  Future<void> _claimPendingReward() async {
    if (_isProcessingReward || !_hasPendingReward) {
      return;
    }

    final user = currentUser;
    final expectedRewardId = _pendingRewardId;

    if (user == null ||
        expectedRewardId == null ||
        expectedRewardId.isEmpty) {
      return;
    }

    setState(() {
      _isProcessingReward = true;
    });

    try {
      final claimedResult =
          await _firestore
              .runTransaction<_ClaimRewardResult>(
        (transaction) async {
          final userRef = _firestore
              .collection('users')
              .doc(user.uid);

          final snapshot =
              await transaction.get(userRef);

          final data = snapshot.data() ?? {};

          final pendingRewardId =
              (data['luckySpinPendingRewardId'] ?? '')
                  .toString()
                  .trim();

          final pendingStatus =
              (data['luckySpinPendingRewardStatus'] ?? '')
                  .toString()
                  .trim();

          final pendingFlowers = _parseInt(
            data['luckySpinPendingFlowers'],
          );

          if (pendingRewardId != expectedRewardId ||
              pendingStatus != 'pending' ||
              pendingFlowers <= 0) {
            throw const _RewardAlreadyProcessedException();
          }

         final oldPurchasedBalance = _parseInt(
  data['flowerBalance'],
);

final sentFlowerSnapshot = await _firestore
    .collection('swipes')
    .where('fromUserId', isEqualTo: user.uid)
    .where('action', isEqualTo: 'flower')
    .get();

final sentFlowerCount = sentFlowerSnapshot.docs.length;

final freeFlowersRemaining =
    (7 - sentFlowerCount).clamp(0, 7);

final previousTotalFlowers =
    freeFlowersRemaining + oldPurchasedBalance;

final newPurchasedBalance =
    oldPurchasedBalance + pendingFlowers;

final totalAvailableFlowers =
    freeFlowersRemaining + newPurchasedBalance;

          transaction.set(
            userRef,
            {
              'flowerBalance':
                  FieldValue.increment(pendingFlowers),

              'luckySpinPendingRewardStatus':
                  'claimed',

              'luckySpinPendingRewardClaimedAt':
                  FieldValue.serverTimestamp(),

              'luckySpinPendingFlowers': 0,
              'luckySpinPendingRewardKey': '',
              'luckySpinPendingRewardId': '',

              'luckySpinLastClaimedFlowers':
                  pendingFlowers,

              'luckySpinLastClaimedAt':
                  FieldValue.serverTimestamp(),

              'luckySpinUpdatedAt':
                  FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

        return _ClaimRewardResult(
  previousTotalFlowers: previousTotalFlowers,
  flowersWon: pendingFlowers,
  totalAvailableFlowers: totalAvailableFlowers,
);
        },
      );

      if (!mounted) return;

    setState(() {
  _flowerBalance =
      claimedResult.totalAvailableFlowers;

        _pendingRewardId = null;
        _pendingRewardKey = null;
        _pendingFlowers = 0;

        _isProcessingReward = false;
      });

      await _showClaimedRewardDialog(
        claimedResult,
      );
    } on _RewardAlreadyProcessedException {
      if (!mounted) return;

      setState(() {
        _isProcessingReward = false;
      });

      await _loadSpinData();
    } catch (e) {
      debugPrint('CLAIM SPIN REWARD ERROR: $e');

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

  // ============================================================
  // DECLINE REWARD
  // ============================================================

  Future<void> _declinePendingReward() async {
    if (_isProcessingReward || !_hasPendingReward) {
      return;
    }

    final user = currentUser;
    final expectedRewardId = _pendingRewardId;

    if (user == null ||
        expectedRewardId == null ||
        expectedRewardId.isEmpty) {
      return;
    }

    setState(() {
      _isProcessingReward = true;
    });

    try {
      final userRef = _firestore
          .collection('users')
          .doc(user.uid);

      await _firestore.runTransaction(
        (transaction) async {
          final snapshot =
              await transaction.get(userRef);

          final data = snapshot.data() ?? {};

          final pendingRewardId =
              (data['luckySpinPendingRewardId'] ?? '')
                  .toString()
                  .trim();

          final pendingStatus =
              (data['luckySpinPendingRewardStatus'] ?? '')
                  .toString()
                  .trim();

          if (pendingRewardId != expectedRewardId ||
              pendingStatus != 'pending') {
            throw const _RewardAlreadyProcessedException();
          }

          transaction.set(
            userRef,
            {
              'luckySpinPendingRewardStatus':
                  'declined',

              'luckySpinPendingRewardDeclinedAt':
                  FieldValue.serverTimestamp(),

              'luckySpinPendingFlowers': 0,
              'luckySpinPendingRewardKey': '',
              'luckySpinPendingRewardId': '',

              'luckySpinUpdatedAt':
                  FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        },
      );

      if (!mounted) return;

      setState(() {
        _pendingRewardId = null;
        _pendingRewardKey = null;
        _pendingFlowers = 0;
        _isProcessingReward = false;
      });
    } catch (e) {
      debugPrint('DECLINE SPIN REWARD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isProcessingReward = false;
      });

      await _loadSpinData();
    }
  }

  // ============================================================
  // CLAIMED POPUP
  // Chỉ hiện sau khi user bấm Nhận.
  // ============================================================

  Future<void> _showClaimedRewardDialog(
    _ClaimRewardResult result,
  ) async {
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
                Container(
                  width: 86,
                  height: 86,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFE5F0),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Color(0xFFCC3D7A),
                    size: 45,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _tr(
                    '🎉 Chúc mừng bạn!',
                    '🎉 Congratulations!',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF7A2E6E),
                    fontSize: 25,
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
                    'Flower bạn vừa trúng',
                    'Flowers won',
                  ),
                  value: '+${result.flowersWon}',
                  valueColor: const Color(0xFFCC3D7A),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 14,
                  ),
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

                const SizedBox(height: 23),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFCC3D7A),
                      minimumSize:
                          const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(17),
                      ),
                    ),
                    child: Text(
                      _tr(
                        'Cảm ơn',
                        'Thank you',
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
              fontWeight:
                  large ? FontWeight.w900 : FontWeight.w700,
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
  // WHEEL ANIMATION
  // ============================================================

  Future<void> _animateWheelToResult(
    String resultKey,
  ) async {
    final selectedIndex = _wheelItems.indexWhere(
      (item) => item.key == resultKey,
    );

    if (selectedIndex < 0) {
      throw Exception(
        'Wheel result not found: $resultKey',
      );
    }

    final sectionAngle =
        (2 * pi) / _wheelItems.length;

    final selectedCenter =
        selectedIndex * sectionAngle +
        sectionAngle / 2;

    // Dừng lệch nhẹ nhưng vẫn nằm trong đúng ô.
    final maxOffset =
        sectionAngle * 0.20;

    final randomOffset =
        (_random.nextDouble() * 2 - 1) *
        maxOffset;

    final selectedStopAngle =
        selectedCenter + randomOffset;

    final normalizedCurrent =
        _currentRotation % (2 * pi);

    final correction =
        (2 * pi - selectedStopAngle) -
        normalizedCurrent;

    final extraTurns =
        7 + _random.nextInt(3);

    final targetRotation =
        _currentRotation +
        extraTurns * 2 * pi +
        correction;

    _spinAnimation = Tween<double>(
      begin: _currentRotation,
      end: targetRotation,
    ).animate(
      CurvedAnimation(
        parent: _spinController,
        curve: Curves.easeOutCubic,
      ),
    );

    _spinController.reset();

    await _spinController.forward();
  }

  Future<void> _scrollToResult() async {
    await Future<void>.delayed(
      const Duration(milliseconds: 250),
    );

    if (!mounted ||
        !_scrollController.hasClients) {
      return;
    }

    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
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
        title: const Text(
          'Lucky Spin',
          style: TextStyle(
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
              onRefresh: _loadSpinData,
              child: ListView(
                controller: _scrollController,
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  18,
                  22,
                  18,
                  34,
                ),
                children: [
                  Text(
                    _tr(
                      'Vòng quay may mắn',
                      'Lucky Reward Wheel',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF7A2E6E),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tr(
                      'Bạn có 3 lượt quay mỗi ngày.',
                      'You have 3 spins every day.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildStatusRow(),

                  const SizedBox(height: 28),

                  _buildWheel(),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isSpinning ||
                                  _isProcessingReward ||
                                  _hasPendingReward ||
                                  _spinsRemaining <= 0
                              ? null
                              : _startSpin,
                      icon: _isSpinning
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.casino_rounded,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isSpinning
                            ? _tr(
                                'Đang quay...',
                                'Spinning...',
                              )
                            : _hasPendingReward
                                ? _tr(
                                    'Hãy nhận phần thưởng',
                                    'Claim your reward',
                                  )
                                : _spinsRemaining > 0
                                    ? _tr(
                                        'QUAY NGAY',
                                        'SPIN NOW',
                                      )
                                    : _tr(
                                        'Hết lượt hôm nay',
                                        'No spins left today',
                                      ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFCC3D7A),
                        disabledBackgroundColor:
                            const Color(0xFFCC3D7A)
                                .withOpacity(0.48),
                        minimumSize:
                            const Size.fromHeight(58),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),

                  if (_lastResultKey != null) ...[
                    const SizedBox(height: 18),
                    _buildLastResultCard(),
                  ],

                  if (_spinsRemaining <= 0 &&
                      !_hasPendingReward) ...[
                    const SizedBox(height: 18),
                    _buildNoSpinsCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusRow() {
  return _buildStatusCard(
    icon: Icons.casino_rounded,
    label: _tr(
      'Lượt còn lại',
      'Spins left',
    ),
    value: '$_spinsRemaining / 3',
  );
}

  Widget _buildStatusCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD1E1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC3D7A)
                .withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFFCC3D7A),
            size: 27,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF7A2E6E),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheel() {
    return Center(
      child: SizedBox(
        width: 345,
        height: 375,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 28,
              child: Transform.rotate(
                angle: _currentRotation,
                child: SizedBox(
                  width: 330,
                  height: 330,
                  child: CustomPaint(
                    painter: _LuckyWheelPainter(
                      items: _wheelItems,
                      isVi: isVi,
                    ),
                  ),
                ),
              ),
            ),

            // Mũi tên lớn để dễ nhìn ô được chọn.
            const Positioned(
              top: -8,
              child: Icon(
                Icons.arrow_drop_down_rounded,
                color: Color(0xFF7A2E6E),
                size: 86,
              ),
            ),

            Positioned(
              top: 148,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap:
                      _isSpinning ||
                              _isProcessingReward ||
                              _hasPendingReward ||
                              _spinsRemaining <= 0
                          ? null
                          : _startSpin,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF6A9A),
                          Color(0xFFCC3D7A),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white,
                        width: 6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withOpacity(0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _isSpinning
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'SPIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastResultCard() {
    final resultItem = _wheelItems.firstWhere(
      (item) => item.key == _lastResultKey,
      orElse: () => _wheelItems.last,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: resultItem.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: resultItem.color.withOpacity(0.45),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                resultItem.icon,
                color: resultItem.color,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _tr(
                    'Kết quả gần nhất: ${resultItem.vi}',
                    'Latest result: ${resultItem.en}',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF6A3152),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          if (_hasPendingReward) ...[
            const SizedBox(height: 18),

            Text(
              _tr(
                '🎉 Chúc mừng!\nBạn đã trúng $_pendingFlowers Flower${_pendingFlowers > 1 ? 's' : ''}!',
                '🎉 Congratulations!\nYou won $_pendingFlowers Flower${_pendingFlowers > 1 ? 's' : ''}!',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFCC3D7A),
                fontSize: 20,
                height: 1.4,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              _tr(
                'Bạn có muốn nhận phần thưởng này không?',
                'Would you like to claim this reward?',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 15,
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
                      foregroundColor:
                          Colors.grey.shade700,
                      side: BorderSide(
                        color: Colors.grey.shade400,
                      ),
                      minimumSize:
                          const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _tr(
                        'Không nhận',
                        'Decline',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessingReward
                        ? null
                        : _claimPendingReward,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFCC3D7A),
                      minimumSize:
                          const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                    ),
                    child: _isProcessingReward
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _tr(
                              'Nhận',
                              'Claim',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              _tr(
                'Bạn còn $_spinsRemaining lượt quay hôm nay.',
                'You have $_spinsRemaining spins left today.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoSpinsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFC9DE),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: Color(0xFFCC3D7A),
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            _tr(
              'Bạn đã sử dụng hết 3 lượt quay hôm nay.',
              'You have used all 3 spins today.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8B2E63),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _tr(
              'Hãy quay lại vào ngày mai ❤️',
              'Please come back tomorrow ❤️',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// MODELS
// ================================================================

class _WheelItem {
  final String key;
  final String vi;
  final String en;
  final IconData icon;
  final Color color;

  const _WheelItem({
    required this.key,
    required this.vi,
    required this.en,
    required this.icon,
    required this.color,
  });
}

class _SpinTransactionResult {
  final String resultKey;
  final int spinNumber;
  final int flowersWon;
  final String? pendingRewardId;

  const _SpinTransactionResult({
    required this.resultKey,
    required this.spinNumber,
    required this.flowersWon,
    required this.pendingRewardId,
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

class _NoSpinsLeftException implements Exception {
  const _NoSpinsLeftException();
}

class _PendingRewardException implements Exception {
  const _PendingRewardException();
}

class _RewardAlreadyProcessedException implements Exception {
  const _RewardAlreadyProcessedException();
}

// ================================================================
// WHEEL PAINTER
// ================================================================

class _LuckyWheelPainter extends CustomPainter {
  final List<_WheelItem> items;
  final bool isVi;

  const _LuckyWheelPainter({
    required this.items,
    required this.isVi,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        min(size.width, size.height) / 2;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - 9,
    );

    final sectionAngle =
        (2 * pi) / items.length;

    for (int index = 0;
        index < items.length;
        index++) {
      final item = items[index];

      final startAngle =
          -pi / 2 + index * sectionAngle;

      final sectionPaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        rect,
        startAngle,
        sectionAngle,
        true,
        sectionPaint,
      );

      final dividerPaint = Paint()
        ..color = Colors.white.withOpacity(0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      final dividerStart = Offset(
        center.dx + cos(startAngle) * 48,
        center.dy + sin(startAngle) * 48,
      );

      final dividerEnd = Offset(
        center.dx +
            cos(startAngle) * (radius - 10),
        center.dy +
            sin(startAngle) * (radius - 10),
      );

      canvas.drawLine(
        dividerStart,
        dividerEnd,
        dividerPaint,
      );

      canvas.save();

      final textAngle =
          startAngle + sectionAngle / 2;

      canvas.translate(
        center.dx,
        center.dy,
      );

      canvas.rotate(textAngle);

      final label =
          isVi ? item.vi : item.en;

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.05,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 3,
        ellipsis: '…',
      )..layout(
          maxWidth: 112,
        );

      textPainter.paint(
        canvas,
        Offset(
          radius * 0.47,
          -textPainter.height / 2,
        ),
      );

      canvas.restore();
    }

    final whiteBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    canvas.drawCircle(
      center,
      radius - 9,
      whiteBorder,
    );

    final pinkBorder = Paint()
      ..color = const Color(0xFFCC3D7A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    canvas.drawCircle(
      center,
      radius - 3,
      pinkBorder,
    );

    final dotPaint = Paint()
      ..color = const Color(0xFFFFD75E)
      ..style = PaintingStyle.fill;

    const dotCount = 18;

    for (int i = 0; i < dotCount; i++) {
      final angle =
          (2 * pi / dotCount) * i;

      final dotCenter = Offset(
        center.dx +
            cos(angle) * (radius - 8),
        center.dy +
            sin(angle) * (radius - 8),
      );

      canvas.drawCircle(
        dotCenter,
        3.2,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _LuckyWheelPainter oldDelegate,
  ) {
    return oldDelegate.items != items ||
        oldDelegate.isVi != isVi;
  }
}
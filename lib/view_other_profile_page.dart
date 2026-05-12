import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'prompt_data.dart';

class ViewOtherProfilePage extends StatefulWidget {
  final String userId;
  final String languageCode;
  final String? fallbackName;
  final String? fallbackPhotoUrl;

  const ViewOtherProfilePage({
    super.key,
    required this.userId,
    required this.languageCode,
    this.fallbackName,
    this.fallbackPhotoUrl,
  });

  @override
  State<ViewOtherProfilePage> createState() => _ViewOtherProfilePageState();
}

class _ViewOtherProfilePageState extends State<ViewOtherProfilePage> {
  bool get isVi => widget.languageCode == 'vi';

  bool _isCheckingSwipe = true;
  bool _alreadyActed = false;
  bool _isProcessingAction = false;

  String _tr(String vi, String en) => isVi ? vi : en;

  Map<String, dynamic>? profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkExistingSwipe();
  }

  Future<void> _loadProfile() async {
    if (widget.userId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        profile = {};
      });
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (!mounted) return;

    setState(() {
      profile = doc.exists ? (doc.data() ?? {}) : {};
    });
  }

  Future<void> _checkExistingSwipe() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || widget.userId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _isCheckingSwipe = false;
        _alreadyActed = false;
      });
      return;
    }

    try {
      final docId = '${currentUser.uid}_${widget.userId}';

      final doc = await FirebaseFirestore.instance
          .collection('swipes')
          .doc(docId)
          .get();

      final data = doc.data();
      final action = (data?['action'] ?? '').toString().trim().toLowerCase();

      if (!mounted) return;
      setState(() {
        _alreadyActed =
            action == 'pass' || action == 'like' || action == 'flower';
        _isCheckingSwipe = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingSwipe = false;
        _alreadyActed = false;
      });
    }
  }

  Future<void> _handlePass(Map<String, dynamic> targetProfile) async {
    await _saveSwipe(
      targetProfile: targetProfile,
      action: 'pass',
    );
  }

  Future<void> _handleLike(Map<String, dynamic> targetProfile) async {
    final didMatch = await _saveSwipe(
      targetProfile: targetProfile,
      action: 'like',
    );

    if (!mounted) return;

    if (didMatch) {
      await _showMatchDialog(targetProfile);
    }
  }

  Future<void> _handleFlower(Map<String, dynamic> targetProfile) async {
    final controller = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            _tr(
              'Viết vài lời cho người bạn thích nhé!',
              'Write a few words to someone you like!',
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: _tr('Nhập lời nhắn của bạn...', 'Write your message...'),
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
              child: Text(_tr('Huỷ', 'Cancel')),
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
                _tr('Gửi', 'Send'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    await _saveSwipe(
      targetProfile: targetProfile,
      action: 'flower',
      flowerMessage: result,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr('Đã gửi flower thành công.', 'Flower sent successfully.'),
        ),
      ),
    );
  }

  Future<bool> _saveSwipe({
    required Map<String, dynamic> targetProfile,
    required String action,
    String? flowerMessage,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    if (_isProcessingAction) return false;

    final currentUid = currentUser.uid;
    final targetUid =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? widget.userId)
            .toString()
            .trim();

    if (targetUid.isEmpty || targetUid == currentUid) return false;

    bool didMatch = false;

    setState(() {
      _isProcessingAction = true;
    });

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
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get();

        final currentUserData = currentUserDoc.data() ?? {};

        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .collection('likedBy')
            .doc(currentUid)
            .set({
          'uid': currentUid,
          'firstName': (currentUserData['firstName'] ?? '').toString().trim(),
          'age': currentUserData['age'],
          'photoUrl': (currentUserData['mainPhotoUrl'] ?? '').toString().trim(),
          'mainPhotoUrl':
              (currentUserData['mainPhotoUrl'] ?? '').toString().trim(),
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
        final reverseDoc = await FirebaseFirestore.instance
            .collection('swipes')
            .doc('${targetUid}_$currentUid')
            .get();

        final reverseData = reverseDoc.data();
        final reverseAction =
            (reverseData?['action'] ?? '').toString().trim().toLowerCase();

        if (reverseAction == 'like') {
          didMatch = true;
          await _createMatch(targetProfile: targetProfile);
        }
      }

      if (!mounted) return didMatch;

      setState(() {
        _alreadyActed = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'pass'
                ? _tr('Đã bỏ qua hồ sơ này.', 'Profile passed.')
                : action == 'like'
                    ? _tr('Đã thích hồ sơ này.', 'Profile liked.')
                    : _tr('Đã gửi flower.', 'Flower sent.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('Có lỗi xảy ra: $e', 'Something went wrong: $e'),
          ),
        ),
      );
    } finally {
      if (!mounted) return didMatch;
      setState(() {
        _isProcessingAction = false;
      });
    }

    return didMatch;
  }

  String _chatIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  Future<void> _createFlowerChat({
    required Map<String, dynamic> targetProfile,
    required String message,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final fromUid = currentUser.uid;
    final toUid =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? widget.userId)
            .toString()
            .trim();

    if (toUid.isEmpty || toUid == fromUid) return;

    final chatId = _chatIdFor(fromUid, toUid);

    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(fromUid)
        .get();

    final currentUserData = currentUserDoc.data() ?? {};

    final fromName = _firstNonEmpty(currentUserData, ['firstName']);
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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final currentUid = currentUser.uid;
    final targetUid =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? widget.userId)
            .toString()
            .trim();

    if (targetUid.isEmpty || targetUid == currentUid) return;

    final matchId = _chatIdFor(currentUid, targetUid);

    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();

    final currentUserData = currentUserDoc.data() ?? {};

    final currentName = _firstNonEmpty(currentUserData, ['firstName']);
    final targetName = _firstNonEmpty(targetProfile, ['firstName']);

    final currentPhotoList = _extractPhotos(currentUserData);
    final targetPhotoList = _extractPhotos(targetProfile);

    final currentPhoto = currentPhotoList.isNotEmpty
        ? currentPhotoList.first
        : (currentUserData['mainPhotoUrl'] ?? '').toString().trim();

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

  Future<void> _showMatchDialog(Map<String, dynamic> targetProfile) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final currentUserData = currentUserDoc.data() ?? {};

    final currentPhoto = _extractPhotos(currentUserData).isNotEmpty
        ? _extractPhotos(currentUserData).first
        : (currentUserData['mainPhotoUrl'] ?? '').toString().trim();

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
                SizedBox(
                  width: double.infinity,
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
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reportUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(_tr('Báo cáo người dùng', 'Report user')),
          content: Text(
            _tr(
              'Bạn có chắc muốn báo cáo hồ sơ này không?',
              'Are you sure you want to report this profile?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_tr('Huỷ', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(
                _tr('Báo cáo', 'Report'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'fromUserId': currentUser.uid,
        'toUserId': widget.userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('Đã báo cáo người dùng.', 'User reported.')),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('Có lỗi xảy ra: $e', 'Something went wrong: $e'),
          ),
        ),
      );
    }
  }

  String _normalizeString(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  String _capitalizeName(String text) {
    final value = text.trim();
    if (value.isEmpty) return '';
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  String _firstNonEmpty(Map<String, dynamic> profile, List<String> keys) {
    for (final key in keys) {
      final value = (profile[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
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

  Widget _buildOnlineDot(bool isOnline) {
  if (!isOnline) {
    return const SizedBox.shrink();
  }

  return Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF2ECC71),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF2ECC71).withOpacity(0.35),
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
    required String highestDegree,
    required String occupation,
    required String annualIncome,
  }) {
    final items = [
      if (highestDegree.isNotEmpty)
        _HorizontalInfoItem(
          icon: Icons.school_outlined,
          label: _tr('Bằng cấp', 'Degree'),
          text: highestDegree,
        ),
      if (occupation.isNotEmpty)
        _HorizontalInfoItem(
          icon: Icons.work_outline_rounded,
          label: _tr('Nghề nghiệp', 'Occupation'),
          text: occupation,
        ),
      if (annualIncome.isNotEmpty)
        _HorizontalInfoItem(
          icon: Icons.payments_outlined,
          label: _tr('Thu nhập năm', 'Annual income'),
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
            onTap: _isProcessingAction ? null : () => _handlePass(profile),
            icon: Icons.close_rounded,
            iconColor: Colors.black87,
            size: 64,
          ),
          _buildActionCircleButton(
            onTap: _isProcessingAction ? null : () => _handleFlower(profile),
            icon: Icons.local_florist_rounded,
            iconColor: Colors.white,
            size: 72,
            backgroundColor: const Color(0xFFFFD54F),
          ),
          _buildActionCircleButton(
            onTap: _isProcessingAction ? null : () => _handleLike(profile),
            icon: Icons.favorite_rounded,
            iconColor: Colors.white,
            size: 64,
            backgroundColor: const Color(0xFFE91E63),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF8FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFF8FB),
          elevation: 0,
          foregroundColor: const Color(0xFF8A2F6A),
          title: Text(_tr('Hồ sơ', 'Profile')),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.pink),
        ),
      );
    }

    final isFallbackMode = profile!.isEmpty;

    if (isFallbackMode) {
      final fallbackName = (widget.fallbackName ?? '').trim().isEmpty
          ? _tr('Người dùng', 'User')
          : widget.fallbackName!.trim();

      final fallbackPhoto = (widget.fallbackPhotoUrl ?? '').trim();

      return Scaffold(
        backgroundColor: const Color(0xFFFFF8FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFF8FB),
          elevation: 0,
          foregroundColor: const Color(0xFF8A2F6A),
          title: Text(_tr('Hồ sơ', 'Profile')),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFDDEA),
                Color(0xFFFFEFF5),
                Color(0xFFFFFFFF),
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 40),
              child: Column(
                children: [
                  Center(
                    child: _buildMainCirclePhoto(fallbackPhoto),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fallbackName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8A2F6A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFFFD5E6)),
                    ),
                    child: Text(
                      _tr(
                        'Tài khoản này hiện không còn hoạt động. Một số thông tin hồ sơ không còn khả dụng.',
                        'This account is no longer active. Some profile details are no longer available.',
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF555555),
                        height: 1.5,
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

    final p = profile!;
    final photos = _extractPhotos(p);
    final prompts = _extractPrompts(p, isVi);

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

    final firstName = _capitalizeName((p['firstName'] ?? '').toString());
    final displayName =
        firstName.isEmpty ? _tr('Người dùng', 'User') : firstName;
    final age = (p['age'] ?? '').toString().trim();
    final isOnline = p['isOnline'] == true;

    final genderRaw = _firstNonEmpty(p, [
      'gender',
      'selectedGender',
      'userGender',
    ]);
    final gender = _translateProfileValue(genderRaw, isVi);

    final livingState = _livingStateDisplay(p);
    final bornDisplay = _buildBornDisplay(p, isVi);
    final religion = _translateProfileValue(
      _firstNonEmpty(p, ['religion']),
      isVi,
    );

    final highestDegree = _translateProfileValue(
      _firstNonEmpty(p, ['highestDegree', 'highestEducation']),
      isVi,
    );

    final occupation = _translateProfileValue(
      _firstNonEmpty(p, ['jobTitle', 'occupation']),
      isVi,
    );

    final annualIncome = _translateProfileValue(
      _firstNonEmpty(p, ['annualIncome', 'income', 'yearlyIncome']),
      isVi,
    );

    final maritalStatus = _translateProfileValue(
      _firstNonEmpty(p, ['maritalStatus']),
      isVi,
    );

 final haveChildren = _translateProfileValue(
  _firstNonEmpty(p, ['haveChildren', 'hasChildren', 'childrenStatus', 'want']),
  isVi,
);

    String relationshipGoal = _extractRelationshipGoalKey(p);
    relationshipGoal = _translateProfileValue(relationshipGoal, isVi);

    final residentStatus = _translateProfileValue(
      _firstNonEmpty(p, ['residentStatus']),
      isVi,
    );

    final drinking = _translateProfileValue(
      _firstNonEmpty(p, ['drinking']),
      isVi,
    );

    final smoking = _translateProfileValue(
      _firstNonEmpty(p, ['smoking']),
      isVi,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8FB),
        elevation: 0,
        foregroundColor: const Color(0xFF8A2F6A),
        centerTitle: true,
        title: Text(
          _tr('Hồ sơ', 'Profile'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF8A2F6A),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _reportUser,
            icon: const Icon(
              Icons.report_gmailerrorred_rounded,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFDDEA),
              Color(0xFFFFEFF5),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: _buildMainCirclePhoto(
                        getPhoto(0).isNotEmpty
                            ? getPhoto(0)
                            : (p['mainPhotoUrl'] ?? '').toString().trim(),
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
                            label: _tr('Tuổi', 'Age'),
                            text: age,
                          ),
                        if (gender.isNotEmpty)
                          _InfoItem(
                            icon: Icons.person_outline_rounded,
                            label: _tr('Giới tính', 'Gender'),
                            text: gender,
                          ),
                        if (livingState.isNotEmpty)
                          _InfoItem(
                            icon: Icons.location_on_outlined,
                            label: _tr('Bang đang sống', 'State living'),
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
                            label: _tr('Nơi sinh', 'Born'),
                            text: bornDisplay,
                          ),
                        if (religion.isNotEmpty)
                          _InfoItem(
                            icon: Icons.auto_awesome_outlined,
                            label: _tr('Tôn giáo', 'Religion'),
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
                            label: _tr('Tình trạng hôn nhân', 'Marital status'),
                            text: maritalStatus,
                          ),
                            if (haveChildren.isNotEmpty)
      if (haveChildren.isNotEmpty)
      _InfoItem(
        icon: Icons.child_care_outlined,
        label: _tr('Con cái', 'Children'),
        text: haveChildren,
      ),
                        if (relationshipGoal.isNotEmpty)
                          _InfoItem(
                            icon: Icons.flag_circle_outlined,
                            label: _tr('Mục tiêu hẹn hò', 'Relationship goal'),
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
                            label: _tr('Tình trạng cư trú', 'Resident status'),
                            text: residentStatus,
                          ),
                        if (drinking.isNotEmpty)
                          _InfoItem(
                            icon: Icons.wine_bar_outlined,
                            label: _tr('Uống rượu', 'Drink'),
                            text: drinking,
                          ),
                        if (smoking.isNotEmpty)
                          _InfoItem(
                            icon: Icons.smoke_free_outlined,
                            label: _tr('Hút thuốc', 'Smoke'),
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
              if (!_isCheckingSwipe && !_alreadyActed)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: _buildFloatingActionBar(p),
                ),
            ],
          ),
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
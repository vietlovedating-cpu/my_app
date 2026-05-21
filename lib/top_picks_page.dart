import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'message_page.dart';
import 'prompt_data.dart';

class TopPicksPage extends StatefulWidget {
  final String languageCode;

  const TopPicksPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<TopPicksPage> createState() => _TopPicksPageState();
}

class _TopPicksPageState extends State<TopPicksPage> {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  bool _isProcessingAction = false;

  List<Map<String, dynamic>> _topPicks = [];
  Map<String, dynamic>? _currentUserData;
  int _currentIndex = 0;

  static const int _dailyTopPicksLimit = 6;

  bool get isVi => widget.languageCode == 'vi';

  String _label(String vi, String en) => isVi ? vi : en;

  DocumentReference<Map<String, dynamic>> _dailyTopPicksRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('top_picks_daily')
        .doc(_todayKey());
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }
Future<void> _saveHomeFeed(List<Map<String, dynamic>> profiles) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final batch = FirebaseFirestore.instance.batch();

  for (final profile in profiles) {
    final uid = (profile['uid'] ?? profile['docId'] ?? '').toString().trim();
    if (uid.isEmpty) continue;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('home_feed')
        .doc(uid);

    batch.set(
      ref,
      {
        'seenAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  await batch.commit();
}

  Future<void> _loadData() async {
    final user = currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final currentUserData = currentUserDoc.data() ?? {};
      final dailyRef = _dailyTopPicksRef(user.uid);
      final dailyDoc = await dailyRef.get();

      List<String> pickUserIds = [];
      List<String> usedUserIds = [];

      if (dailyDoc.exists) {
        final data = dailyDoc.data() ?? {};
        pickUserIds = _stringList(data['pickUserIds']);
        usedUserIds = _stringList(data['usedUserIds']);
      }

      if (pickUserIds.isEmpty) {
        final generatedTopPicks = await _loadTopPicks(currentUserData);

        pickUserIds = generatedTopPicks
            .map((e) => (e['uid'] ?? e['docId'] ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .take(_dailyTopPicksLimit)
            .toList();

        usedUserIds = [];

        await dailyRef.set({
          'dateKey': _todayKey(),
          'pickUserIds': pickUserIds,
          'usedUserIds': usedUserIds,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
final swipesSnapshot = await FirebaseFirestore.instance
    .collection('swipes')
    .where('fromUserId', isEqualTo: user.uid)
    .get();

final swipedUserIds = swipesSnapshot.docs
    .map((doc) => (doc.data()['toUserId'] ?? '').toString().trim())
    .toSet();
      var remainingIds = pickUserIds
    .where((id) =>
        !usedUserIds.contains(id) &&
        !swipedUserIds.contains(id)) // 👈 thêm dòng này
    .toList();
if (remainingIds.length < _dailyTopPicksLimit) {
  final generatedTopPicks = await _loadTopPicks(currentUserData);

  final extraIds = generatedTopPicks
      .map((e) => (e['uid'] ?? e['docId'] ?? '').toString().trim())
      .where((id) =>
          id.isNotEmpty &&
          !pickUserIds.contains(id) &&
          !usedUserIds.contains(id) &&
          !swipedUserIds.contains(id) &&
          !remainingIds.contains(id))
      .take(_dailyTopPicksLimit - remainingIds.length)
      .toList();

  if (extraIds.isNotEmpty) {
    remainingIds.addAll(extraIds);
    pickUserIds.addAll(extraIds);

    await dailyRef.set({
      'dateKey': _todayKey(),
      'pickUserIds': pickUserIds,
      'usedUserIds': usedUserIds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
      final topPicks = await _loadProfilesByIds(remainingIds);

      if (!mounted) return;
      setState(() {
        _currentUserData = currentUserData;
        _topPicks = topPicks;
        _currentIndex = 0;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserData = {};
        _topPicks = [];
        _currentIndex = 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  String _normalizeString(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString().trim()) ?? 0;
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

  bool _isProfileAvailableForTopPicks(Map<String, dynamic> data) {
    if (data.isEmpty) return false;
    if (data['profileCompleted'] != true) return false;
    if (data['showMyProfile'] == false) return false;
    if (data['showOnDiscover'] == false) return false;
    if (data['accountPaused'] == true) return false;
    if (data['isPaused'] == true) return false;
    if (data['isDeleted'] == true) return false;
    return true;
  }

  Future<List<Map<String, dynamic>>> _loadProfilesByIds(List<String> ids) async {
    final List<Map<String, dynamic>> result = [];

    for (final uid in ids) {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists) continue;

      final data = doc.data() ?? {};
      if (!_isProfileAvailableForTopPicks(data)) continue;

      result.add({
        'docId': doc.id,
        ...data,
      });
    }

    return result;
  }

  Future<void> _markTopPickUsed(String targetUid) async {
    final user = currentUser;
    if (user == null || targetUid.trim().isEmpty) return;

    await _dailyTopPicksRef(user.uid).set({
      'dateKey': _todayKey(),
      'usedUserIds': FieldValue.arrayUnion([targetUid.trim()]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  Future<List<Map<String, dynamic>>> _loadTopPicks(
    Map<String, dynamic> currentUserData,
  ) async {
    final user = currentUser;
    if (user == null) return [];

    final currentUid = user.uid;

    final selectedGenderFilter = _normalizeGenderPreference(
      currentUserData['datingPreference'] ?? currentUserData['genderPreference'],
    );

    final selectedMinAgeFilter = _parseInt(
      currentUserData['minAgePreference'] ?? currentUserData['preferredMinAge'],
    );

    final selectedMaxAgeFilter = _parseInt(
      currentUserData['maxAgePreference'] ?? currentUserData['preferredMaxAge'],
    );

    final myState = _normalizeString(
      currentUserData['selectedState'] ?? currentUserData['state'],
    );

    final myGoal = _extractRelationshipGoalKey(currentUserData);

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
final homeFeedSnapshot = await FirebaseFirestore.instance
    .collection('users')
    .doc(currentUid)
    .collection('home_feed')
    .get();

    final swipedUserIds = swipesSnapshot.docs
        .map((doc) => (doc.data()['toUserId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final hiddenUserIds = hiddenSnapshot.docs
        .map((doc) => doc.id.toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();
final homeFeedUserIds = homeFeedSnapshot.docs
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
      if (homeFeedUserIds.contains(uid)) continue;
      if (data['profileCompleted'] != true) continue;
      if (data['showMyProfile'] == false) continue;
      if (data['showOnDiscover'] == false) continue;
      if (data['accountPaused'] == true) continue;
      if (data['isPaused'] == true) continue;
      if (data['isDeleted'] == true) continue;

      final profileGender = _normalizeGenderPreference(data['gender']);
      final profileAge = _parseInt(data['age']);

      if (selectedGenderFilter.isNotEmpty &&
          selectedGenderFilter != 'everyone') {
        if (!_genderMatches(profileGender, selectedGenderFilter)) {
          continue;
        }
      }

      if (selectedMinAgeFilter > 0 && profileAge < selectedMinAgeFilter) {
        continue;
      }

      if (selectedMaxAgeFilter > 0 && profileAge > selectedMaxAgeFilter) {
        continue;
      }

      profiles.add({
        'docId': doc.id,
        ...data,
      });
    }

    int scoreProfile(Map<String, dynamic> profile) {
      int score = 0;

      final profileState = _normalizeString(
        profile['selectedState'] ?? profile['state'],
      );

      final profileAge = _parseInt(profile['age']);
      final photos = _extractPhotos(profile);
      final relationshipGoal = _extractRelationshipGoalKey(profile);

      if (myState.isNotEmpty && profileState == myState) {
        score += 30;
      }

      if (selectedMinAgeFilter > 0 &&
          selectedMaxAgeFilter > 0 &&
          profileAge >= selectedMinAgeFilter &&
          profileAge <= selectedMaxAgeFilter) {
        score += 25;
      }

      if (photos.length >= 3) {
        score += 20;
      } else if (photos.length >= 2) {
        score += 10;
      }

      if (profile['isOnline'] == true) {
        score += 10;
      }

      if (myGoal.isNotEmpty && relationshipGoal == myGoal) {
        score += 15;
      }

      return score;
    }

    profiles.sort((a, b) => scoreProfile(b).compareTo(scoreProfile(a)));
    return profiles.take(_dailyTopPicksLimit).toList();
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
  if (imageUrl.trim().isEmpty) {
    return const SizedBox.shrink();
  }

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
      child: Image.network(
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

  Future<void> _handlePass({
    required Map<String, dynamic> targetProfile,
  }) async {
    final result = await _saveSwipe(
      targetProfile: targetProfile,
      action: 'pass',
    );

    if (!mounted || !result.success) return;

    final targetUid =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();

    await _markTopPickUsed(targetUid);

    if (!mounted) return;

    setState(() {
      if (_currentIndex < _topPicks.length) {
        _currentIndex++;
      }
    });
  }

  Future<void> _handleLike({
    required Map<String, dynamic> targetProfile,
  }) async {
    final result = await _saveSwipe(
      targetProfile: targetProfile,
      action: 'like',
    );

    if (!mounted || !result.success) return;

    final targetUid =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();

    await _markTopPickUsed(targetUid);

    if (!mounted) return;

    if (result.didMatch) {
      await _showMatchDialog(targetProfile);
    }

    setState(() {
      if (_currentIndex < _topPicks.length) {
        _currentIndex++;
      }
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
                  ? 'Bạn đã dùng hết 3 lượt flower miễn phí. Hãy mua VIP hoặc mua thêm \$1.99 cho 1 flower.'
                  : 'You have used all 3 free flowers. Please buy VIP or purchase 1 extra flower for \$1.99.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isVi ? 'Để sau' : 'Later'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
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
            style: const TextStyle(fontWeight: FontWeight.w800),
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
                borderSide: const BorderSide(color: Color(0xFFFFD5E6)),
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

    if (result == null) return;

    final swipeResult = await _saveSwipe(
      targetProfile: targetProfile,
      action: 'flower',
      flowerMessage: result,
    );

    if (!mounted || !swipeResult.success) return;

    final targetUid =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();

    await _markTopPickUsed(targetUid);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi ? 'Đã gửi flower thành công.' : 'Flower sent successfully.',
        ),
      ),
    );

    setState(() {
      if (_currentIndex < _topPicks.length) {
        _currentIndex++;
      }
    });
  }

  Future<_SwipeActionResult> _saveSwipe({
    required Map<String, dynamic> targetProfile,
    required String action,
    String? flowerMessage,
  }) async {
    final user = currentUser;
    if (user == null || _isProcessingAction) {
      return const _SwipeActionResult(success: false, didMatch: false);
    }

    final currentUid = user.uid;
    final targetUid =
        (targetProfile['uid'] ?? targetProfile['docId'] ?? '').toString().trim();

    if (targetUid.isEmpty || targetUid == currentUid) {
      return const _SwipeActionResult(success: false, didMatch: false);
    }

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
          'firstName':
              (_currentUserData?['firstName'] ?? '').toString().trim(),
          'age': _currentUserData?['age'],
          'photoUrl':
              (_currentUserData?['mainPhotoUrl'] ?? '').toString().trim(),
          'mainPhotoUrl':
              (_currentUserData?['mainPhotoUrl'] ?? '').toString().trim(),
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

      return _SwipeActionResult(success: true, didMatch: didMatch);
    } catch (e) {
      if (!mounted) {
        return const _SwipeActionResult(success: false, didMatch: false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Có lỗi xảy ra: $e' : 'Something went wrong: $e',
          ),
        ),
      );

      return const _SwipeActionResult(success: false, didMatch: false);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<bool> _canSendFlower() async {
    final user = currentUser;
    if (user == null) return false;

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

    final fromName = _firstNonEmpty(_currentUserData ?? {}, ['firstName']);
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

    final currentName = _firstNonEmpty(_currentUserData ?? {}, ['firstName']);
    final targetName = _firstNonEmpty(targetProfile, ['firstName']);

    final currentPhotoList = _extractPhotos(_currentUserData ?? {});
    final targetPhotoList = _extractPhotos(targetProfile);

    final currentPhoto = currentPhotoList.isNotEmpty
        ? currentPhotoList.first
        : (_currentUserData?['mainPhotoUrl'] ?? '').toString().trim();

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
    final currentPhoto = _extractPhotos(_currentUserData ?? {}).isNotEmpty
        ? _extractPhotos(_currentUserData ?? {}).first
        : (_currentUserData?['mainPhotoUrl'] ?? '').toString().trim();

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
                          side: const BorderSide(color: Color(0xFF3B6CB7)),
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
                              (targetProfile['uid'] ??
                                      targetProfile['docId'] ??
                                      '')
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
                              : (targetProfile['mainPhotoUrl'] ?? '')
                                  .toString()
                                  .trim();

                          Navigator.pop(context);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MessagePage(
                                languageCode: widget.languageCode,
                                chatId: chatId,
                                otherUserId: targetUid,
                                otherUserName:
                                    otherName.isNotEmpty ? otherName : 'User',
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
                      'Báo cáo và ẩn hồ sơ này khỏi Top Picks',
                      'Report and hide this profile from Top Picks',
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
                  'Bạn sẽ không còn thấy hồ sơ này nữa.',
                  'You will no longer see this profile.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: explanationController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _label(
                    'Viết thêm ghi chú nếu muốn.',
                    'Add a note if you want.',
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
        'targetUserId': targetUid,
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

      setState(() {
        if (_currentIndex < _topPicks.length) {
          _currentIndex++;
        }
      });
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

      setState(() {
        if (_currentIndex < _topPicks.length) {
          _currentIndex++;
        }
      });
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

  Widget _buildProfileStack(Map<String, dynamic> profile) {
    return Stack(
      children: [
        RefreshIndicator(
          color: Colors.pink,
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 112, 14, 150),
            child: _buildProfileContent(profile),
          ),
        ),
        Positioned(
          top: 18,
          right: 18,
          child: Container(
           height: 90,  
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.28),
              borderRadius: BorderRadius.circular(20),
            ),
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

  Widget _buildProfileContent(Map<String, dynamic> profile) {
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

    return Column(
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
              if (isOnline) ...[
  const SizedBox(width: 10),
  _buildOnlineDot(true),
],
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
                label: _label('Con cái', 'Children'),
                text: haveChildren,
              ),
            if (relationshipGoal.isNotEmpty)
              _InfoItem(
                icon: Icons.volunteer_activism_outlined,
                label: _label('Mục tiêu', 'Relationship goal'),
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
                icon: Icons.home_work_outlined,
                label: _label('Tình trạng cư trú', 'Resident status'),
                text: residentStatus,
              ),
            if (drinking.isNotEmpty)
              _InfoItem(
                icon: Icons.wine_bar_outlined,
                label: _label('Uống rượu', 'Drinking'),
                text: drinking,
              ),
            if (smoking.isNotEmpty)
              _InfoItem(
                icon: Icons.smoking_rooms_outlined,
                label: _label('Hút thuốc', 'Smoking'),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrent = _currentIndex < _topPicks.length;
    final currentProfile = hasCurrent ? _topPicks[_currentIndex] : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4F1),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          _label('Gợi ý cho bạn', 'Top Picks'),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.pink),
            )
          : currentProfile == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _label(
                        'Bạn đã dùng hết 6 Top Picks hôm nay. Hãy quay lại vào ngày mai.',
                        'You have used all 6 Top Picks today. Come back tomorrow.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                )
              : _buildProfileStack(currentProfile),
    );
  }
}

class _SwipeActionResult {
  final bool success;
  final bool didMatch;

  const _SwipeActionResult({
    required this.success,
    required this.didMatch,
  });
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String text;

  _InfoItem({
    required this.icon,
    required this.label,
    required this.text,
  });
}

class _HorizontalInfoItem {
  final IconData icon;
  final String label;
  final String text;

  _HorizontalInfoItem({
    required this.icon,
    required this.label,
    required this.text,
  });
}
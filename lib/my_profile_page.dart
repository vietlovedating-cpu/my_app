import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'prompt_data.dart';
import 'edit_profile_page.dart';
import 'support_help_page.dart';
import 'account_page.dart';
import 'notification_settings_page.dart';
import 'privacy_profile_page.dart';
import 'photo_verification_page.dart';
import 'my_gift_page.dart';
import 'utils/profile_health.dart';
import 'package:url_launcher/url_launcher.dart';

class MyProfilePage extends StatefulWidget {
  final String languageCode;
  final bool embedInParentScaffold;
  final VoidCallback? onSettingsTap;

  const MyProfilePage({
    super.key,
    required this.languageCode,
    this.embedInParentScaffold = false,
    this.onSettingsTap,
  });

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  StreamSubscription<User?>? _authSub;
  String? _lastUid;
  Future<Map<String, dynamic>?>? _profileFuture;

  final AudioPlayer _voicePromptPlayer = AudioPlayer();

  bool _isVoicePromptPlaying = false;
  String? _playingVoicePromptUrl;
  bool _isVoicePromptLoading = false;

 @override
void initState() {
  super.initState();

  _lastUid = FirebaseAuth.instance.currentUser?.uid;
  _profileFuture = _loadMyProfile();

  _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
    final newUid = user?.uid;

    if (_lastUid != newUid && mounted) {
      setState(() {
        _lastUid = newUid;
      });
    }
  });

  _voicePromptPlayer.onPlayerComplete.listen((_) {
    if (!mounted) return;

    setState(() {
      _isVoicePromptPlaying = false;
      _playingVoicePromptUrl = null;
    });
  });
}

  @override
  void didUpdateWidget(covariant MyProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.languageCode != widget.languageCode && mounted) {
      setState(() {});
    }
  }

 @override
void dispose() {
  _authSub?.cancel();
  _voicePromptPlayer.dispose();
  super.dispose();
}

  Future<Map<String, dynamic>?> _loadMyProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final requestedUid = user.uid;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(requestedUid)
        .get();

    final latestUid = FirebaseAuth.instance.currentUser?.uid;
    if (latestUid != requestedUid) return null;
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return {
      'docId': doc.id,
      ...data,
    };
  }

  String _tr(bool isVi, String vi, String en) => isVi ? vi : en;

  String _normalize(String value) => value.trim().toLowerCase();

  String _capitalizeName(String text) {
  final value = text.trim();

  if (value.isEmpty) return '';

  return value
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() +
            word.substring(1).toLowerCase();
      })
      .join(' ');
}

  String _resolveLanguageCode(Map<String, dynamic>? profile) {
    final candidates = [
      profile?['languageCode'],
      profile?['preferredLanguage'],
      profile?['appLanguage'],
      profile?['selectedLanguage'],
      profile?['language'],
      widget.languageCode,
    ];

    for (final item in candidates) {
      final value = (item ?? '').toString().trim().toLowerCase();
      if (value == 'vi' || value == 'vn' || value == 'vietnamese') return 'vi';
      if (value == 'en' || value == 'english') return 'en';
    }

    return widget.languageCode == 'vi' ? 'vi' : 'en';
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
List<String> _extractRelationshipGoalKeys(
  Map<String, dynamic> profile,
) {
  final dynamic raw =
      profile['relationshipGoals'] ?? profile['relationshipGoal'];

  if (raw is List) {
    return raw
        .map((item) => _normalize(item.toString()))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  final value = _normalize((raw ?? '').toString());

  if (value.isEmpty) {
    return [];
  }

  return [value];
}
  String _translateProfileValue(String raw, bool isVi) {
    final value = _normalize(raw);

    const viMap = {
      'single': 'Độc thân',
      'divorced': 'Ly hôn',
      'widowed': 'Góa',
      'separated': 'Ly thân',
      'never_married': 'Chưa từng kết hôn',
      'never married': 'Chưa từng kết hôn',
      'yes': 'Có',
      'no': 'Không',
      'sometimes': 'Thỉnh thoảng',
      'socially': 'Xã giao',
      'prefer_not_to_say': 'Không muốn chia sẻ',
      'prefer not to say': 'Không muốn chia sẻ',
      'serious_relationship': 'Mối quan hệ nghiêm túc',
      'long_term_partner': 'Bạn đời lâu dài',
      'friendship_first': 'Bắt đầu từ tình bạn',
      'chat_and_get_to_know': 'Trò chuyện và tìm hiểu',
      'marriage': 'Kết hôn',
      'friendship': 'Tình bạn',
      'casual': 'Tìm hiểu thoải mái',
      'citizen': 'Công dân',
      'permanent_resident': 'Thường trú nhân',
      'temporary_visa': 'Visa tạm trú',
      'student_visa': 'Visa du học',
      'working_holiday': 'Visa Working Holiday',
      'work_visa': 'Visa lao động',
      'temporary resident': 'Tạm trú',
      'buddhist': 'Phật giáo',
      'catholic': 'Công giáo',
      'christian': 'Cơ đốc giáo',
      'hindu': 'Ấn Độ giáo',
      'muslim': 'Hồi giáo',
      'jewish': 'Do Thái giáo',
      'sikh': 'Đạo Sikh',
      'taoist': 'Đạo giáo',
      'no_religion': 'Không tôn giáo',
      'none': 'Không theo tôn giáo',
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
      'other': 'Khác',
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
      'vietnam': 'Việt Nam',
      'australia': 'Úc',
      'nsw': 'NSW',
      'vic': 'VIC',
      'qld': 'QLD',
      'wa': 'WA',
      'sa': 'SA',
      'tas': 'TAS',
      'act': 'ACT',
      'nt': 'NT',
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
      'kết hôn': 'Marriage',
      'tình bạn': 'Friendship',
      'tìm hiểu thoải mái': 'Casual',
      'Công dân': 'Citizen',
      'thường trú nhân': 'Permanent Resident',
      'visa tạm trú': 'Temporary Visa',
      'visa du học': 'Student Visa',
      'visa working holiday': 'Working Holiday Visa',
      'visa lao động': 'Work Visa',
      'công dân': 'Citizen',
      'tạm trú': 'Temporary Resident',
      'phật giáo': 'Buddhist',
      'công giáo': 'Catholic',
      'cơ đốc giáo': 'Christian',
      'ấn độ giáo': 'Hindu',
      'hồi giáo': 'Muslim',
      'do thái giáo': 'Jewish',
      'đạo sikh': 'Sikh',
      'đạo giáo': 'Taoist',
      'không tôn giáo': 'No religion',
      'không theo tôn giáo': 'None',
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
      'khác': 'Other',
      'trung học': 'High School',
      'chứng chỉ nghề': 'Trade Certificate',
      'cao đẳng': 'Diploma',
      'đại học': 'Bachelor Degree',
      'sau đại học': 'Postgraduate',
      'thạc sĩ': 'Master Degree',
      'tiến sĩ': 'Doctorate / PhD',
      'dưới 40,000 aud': 'Below 40,000 AUD',
      '40,000 - 59,999 aud': '40,000 - 59,999 AUD',
      '60,000 - 79,999 aud': '60,000 - 79,999 AUD',
      '80,000 - 99,999 aud': '80,000 - 99,999 AUD',
      '100,000 - 119,999 aud': '100,000 - 119,999 AUD',
      '120,000 - 149,999 aud': '120,000 - 149,999 AUD',
      '150,000+ aud': '150,000+ AUD',
      'muốn có': 'Want children',
      'chưa chắc': 'Not sure',
      'việt nam': 'Vietnam',
      'úc': 'Australia',
      'nsw': 'NSW',
      'vic': 'VIC',
      'qld': 'QLD',
      'wa': 'WA',
      'sa': 'SA',
      'tas': 'TAS',
      'act': 'ACT',
      'nt': 'NT',
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

  String _livingStateDisplay(Map<String, dynamic> profile) {
  String firstNonEmpty(List<dynamic> values) {
    for (final item in values) {
      String value = (item ?? '').toString().trim();

      if (value.isEmpty) continue;

      final lowerValue = value.toLowerCase();

      if (lowerValue == 'other' ||
          lowerValue == 'no_preference') {
        continue;
      }

      if (lowerValue.startsWith('other -')) {
        value = value.substring(7).trim();
      } else if (lowerValue.startsWith('other:')) {
        value = value.substring(6).trim();
      }

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String shortAustralianState(String value) {
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
    profile['selectedStateKey'],
    profile['filterState'],
    profile['stateProvince'],
    profile['province'],
    profile['customState'],
    profile['otherState'],
    profile['selectedState'],
    profile['state'],
    profile['livingState'],
    profile['stateLiving'],
    profile['region'],
  ]);

  final country = firstNonEmpty([
    profile['selectedCountry'],
    profile['country'],
  ]);

  final normalizedCountry = country.toLowerCase();

  final isAustralia =
      normalizedCountry == 'australia' ||
      normalizedCountry == 'úc';

  final state = isAustralia
      ? shortAustralianState(rawState)
      : rawState.trim();

  final parts = <String>[];

  void addPart(String value) {
    final cleanValue = value.trim();

    if (cleanValue.isEmpty) return;

    final alreadyExists = parts.any(
      (item) =>
          item.toLowerCase() == cleanValue.toLowerCase(),
    );

    if (!alreadyExists) {
      parts.add(cleanValue);
    }
  }

  if (isAustralia) {
    addPart(city);
    addPart(state);
  } else {
    addPart(state);

    if (parts.isEmpty) {
      addPart(city);
    }
  }

  if (parts.isEmpty) {
    addPart(country);
  }

  return parts.join(', ');
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
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (
                        context,
                        child,
                        loadingProgress,
                      ) {
                        if (loadingProgress == null) {
                          return child;
                        }

                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return const Center(
                          child: Icon(
                            Icons.person,
                            color: Colors.white70,
                            size: 80,
                          ),
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
 Widget _buildMainCirclePhoto(String imageUrl) {
  return Container(
    width: 205,
    height: 205,
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
    child: GestureDetector(
      onTap: () {
        _openPhotoFullScreen(imageUrl);
      },
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (
                  context,
                  child,
                  loadingProgress,
                ) {
                  if (loadingProgress == null) return child;

                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.pink,
                    ),
                  );
                },
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const Center(
                    child: Icon(
                      Icons.person,
                      size: 74,
                      color: Colors.grey,
                    ),
                  );
                },
              )
            : const Center(
                child: Icon(
                  Icons.person,
                  size: 74,
                  color: Colors.grey,
                ),
              ),
      ),
    ),
  );
}

  Widget _buildPhotoBlock(String imageUrl) {
    if (imageUrl.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 310,
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
  required bool isVi,
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
                _tr(
  isVi,
  'Hãy nghe tôi nói để hiểu rõ tôi hơn nhé',
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
          // Nếu đang phát thì bấm để Pause.
          if (isPlaying) {
            await _voicePromptPlayer.pause();

            if (!mounted) return;

            setState(() {
              _isVoicePromptLoading = false;
              _isVoicePromptPlaying = false;
              _playingVoicePromptUrl = null;
            });

            return;
          }

          // Bắt đầu tải audio và khóa nút.
          if (!mounted) return;

          setState(() {
            _isVoicePromptLoading = true;
          });

          await _voicePromptPlayer.stop();

          await _voicePromptPlayer.play(
            UrlSource(audioUrl),
          );

          if (!mounted) return;

          // Audio đã sẵn sàng và bắt đầu phát.
          setState(() {
            _isVoicePromptLoading = false;
            _isVoicePromptPlaying = true;
            _playingVoicePromptUrl = audioUrl;
          });
        } catch (e) {
          debugPrint('PLAY MY VOICE PROMPT ERROR: $e');

          if (!mounted) return;

          // Nếu lỗi thì mở lại nút cho user thử lại.
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
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.white,
          ),
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
                    isPlaying
                        ? _tr(isVi, 'Đang phát', 'Playing')
                        : _tr(isVi, 'Bấm để nghe', 'Tap to listen'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4A2C40),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatVoicePromptDuration(durationSeconds),
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
  Widget _buildInfoCard({
    required List<_InfoItem> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
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
          label: _tr(isVi, 'Bằng cấp', 'Degree'),
          text: highestDegree,
        ),
      if (occupation.isNotEmpty)
        _HorizontalInfoItem(
          icon: Icons.work_outline_rounded,
          label: _tr(isVi, 'Nghề nghiệp', 'Occupation'),
          text: occupation,
        ),
      if (annualIncome.isNotEmpty)
        _HorizontalInfoItem(
          icon: Icons.payments_outlined,
          label: _tr(isVi, 'Thu nhập năm', 'Annual income'),
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

  Future<void> _openSettings() async {
  if (widget.onSettingsTap != null) {
    widget.onSettingsTap!.call();
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProfileSettingsPage(
        languageCode: widget.languageCode,
      ),
    ),
  );

  if (!mounted) return;

  setState(() {
    _profileFuture = _loadMyProfile();
  });
}
Future<void> _showPhotoRejectedDialog({
  required Map<String, dynamic> profile,
  required bool isVi,
}) async {
  final reason =
      (profile['photoVerificationRejectReason'] ?? '').toString();

  String reasonText;

  switch (reason) {
    case 'photo_not_match':
      reasonText = isVi
          ? 'Ảnh selfie xác minh không khớp với ảnh hồ sơ của bạn.'
          : 'Your verification selfie does not match your profile photos.';
      break;

    case 'face_not_clear':
      reasonText = isVi
          ? 'Khuôn mặt trong ảnh xác minh không rõ.'
          : 'Your face is not clear in the verification photo.';
      break;

    case 'multiple_people':
      reasonText = isVi
          ? 'Ảnh xác minh có nhiều hơn một người.'
          : 'More than one person appears in the verification photo.';
      break;

    default:
  reasonText = isVi
      ? 'Ảnh xác minh của bạn không khớp hoặc không rõ so với ảnh hồ sơ. Vui lòng chụp lại ảnh xác minh và đảm bảo ảnh hồ sơ của bạn có khuôn mặt rõ ràng.'
      : 'Your verification photo does not match or is unclear compared with your profile photos. Please take the verification photo again and make sure your profile photos clearly show your face.';
  }

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(
          isVi
              ? 'Ảnh chưa được xác minh'
              : 'Photo not verified',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          '$reasonText\n\n${isVi ? 'Vui lòng chụp lại ảnh selfie rõ mặt, đủ ánh sáng và không dùng bộ lọc.' : 'Please take another clear selfie in good lighting without filters.'}',
          style: const TextStyle(
            fontSize: 15,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(
              isVi ? 'Để sau' : 'Not now',
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoVerificationPage(
                    languageCode: widget.languageCode,
                  ),
                ),
              );

              if (result == true && mounted) {
                setState(() {});
              }
            },
            icon: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
            ),
            label: Text(
              isVi ? 'Chụp lại ảnh' : 'Retake photo',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
            ),
          ),
        ],
      );
    },
  );
}
  Widget _buildHeader({
    required Map<String, dynamic> profile,
    required bool isVi,
    required List<String> photos,
  }) {
    final mainPhoto = photos.isNotEmpty ? photos.first : '';

    final String firstName =
        _capitalizeName((profile['firstName'] ?? '').toString());
    final String displayName =
        firstName.isEmpty ? _tr(isVi, 'Người dùng', 'User') : firstName;

    final String age = (profile['age'] ?? '').toString().trim();
    final String livingState = _livingStateDisplay(profile);
    final String stateText = livingState.isNotEmpty
        ? _translateProfileValue(livingState, isVi)
        : _tr(isVi, 'Chưa cập nhật nơi ở', 'Living state not set');

    return Column(
      children: [
        const SizedBox(height: 8),
        Center(child: _buildMainCirclePhoto(mainPhoto)),
        const SizedBox(height: 18),
        Text(
  age.isNotEmpty ? '$displayName, $age' : displayName,
  textAlign: TextAlign.center,
  style: const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: Color(0xFF7A2E6E),
    letterSpacing: 0.15,
  ),
),

const SizedBox(height: 8),

InkWell(
  borderRadius: BorderRadius.circular(20),
  onTap: profile['photoVerificationStatus'] == 'pending'
    ? null
    : () async {
        final status =
            (profile['photoVerificationStatus'] ?? '').toString();

        if (status == 'rejected') {
          _showPhotoRejectedDialog(
            profile: profile,
            isVi: isVi,
          );
          return;
        }

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoVerificationPage(
              languageCode: widget.languageCode,
            ),
          ),
        );

        if (result == true && mounted) {
          setState(() {});
        }
      },
  child: Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 13,
      vertical: 7,
    ),
    decoration: BoxDecoration(
      color: profile['photoVerified'] == true
          ? const Color(0xFFE8F4FF)
          : const Color(0xFFFFEEF6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: profile['photoVerified'] == true
            ? const Color(0xFF2196F3)
            : const Color(0xFFFFC4DC),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          profile['photoVerified'] == true
    ? Icons.verified_rounded
    : (profile['photoVerificationStatus'] == 'pending'
        ? Icons.hourglass_top_rounded
        : Icons.camera_alt_outlined),
          size: 18,
          color: profile['photoVerified'] == true
              ? const Color(0xFF2196F3)
              : const Color(0xFFCC3D7A),
        ),
        const SizedBox(width: 6),
        Text(
          profile['photoVerified'] == true
    ? _tr(isVi, 'Ảnh đã xác minh', 'Photo Verified')
    : (profile['photoVerificationStatus'] == 'pending'
        ? _tr(isVi, 'Đang chờ duyệt ảnh', 'Photo Pending Review')
        : (profile['photoVerificationStatus'] == 'rejected'
            ? _tr(
                isVi,
                'Ảnh chưa được duyệt - Thử lại',
                'Photo not approved - Try again',
              )
            : _tr(isVi, 'Xác minh ảnh', 'Verify Photo'))),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: profile['photoVerified'] == true
                ? const Color(0xFF1976D2)
                : const Color(0xFFCC3D7A),
          ),
        ),
      ],
    ),
  ),
),

const SizedBox(height: 8),

Text(
  stateText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8D6B7D),
          ),
        ),
      ],
    );
  }
Widget _buildProfileHealthCard({
  required ProfileHealthResult profileHealth,
  required bool isVi,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFFFEFF6),
        ],
      ),
      border: Border.all(
        color: const Color(0xFFFFCFE1),
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
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFE91E63),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _tr(
                  isVi,
                  'Mức độ hoàn thiện hồ sơ',
                  'Profile strength',
                ),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7A2E6E),
                ),
              ),
            ),
            Text(
              '${profileHealth.score}%',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE91E63),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: profileHealth.score / 100,
            minHeight: 9,
            backgroundColor: const Color(0xFFFFDCE9),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFFE91E63),
            ),
          ),
        ),
        const SizedBox(height: 12),
       Text(
  profileHealth.score < 50
      ? _tr(
          isVi,
          'Hồ sơ dưới 50% sẽ không được hiển thị trên trang Khám phá.',
          'Profiles below 50% will not appear on the Discover page.',
        )
      : _tr(
          isVi,
          'Hoàn thiện hồ sơ để tăng khả năng Match.',
          'Complete your profile to improve your chances of matching.',
        ),
  style: const TextStyle(
    fontSize: 14.5,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: Color(0xFF6F5362),
  ),
),
       if (profileHealth.score < 100 &&
    profileHealth.suggestions.isNotEmpty) ...[
  const SizedBox(height: 14),

  ...profileHealth.suggestions.take(3).map((suggestion) {
    String text;
    IconData icon;

    if (suggestion == 'add_1_photo') {
      text = _tr(isVi, 'Thêm 1 ảnh nữa.', 'Add 1 more photo.');
      icon = Icons.add_a_photo_outlined;
    } else if (suggestion.startsWith('add_more_photos:')) {
      final count =
          int.tryParse(suggestion.split(':').last) ?? 1;

      text = _tr(
        isVi,
        'Thêm $count ảnh nữa.',
        'Add $count more photos.',
      );

      icon = Icons.add_a_photo_outlined;
    } else if (suggestion == 'answer_1_prompt') {
      text = _tr(
        isVi,
        'Trả lời thêm 1 câu hỏi.',
        'Answer 1 more prompt.',
      );

      icon = Icons.chat_bubble_outline_rounded;
    } else if (suggestion.startsWith('answer_more_prompts:')) {
      final count =
          int.tryParse(suggestion.split(':').last) ?? 1;

      text = _tr(
        isVi,
        'Trả lời thêm $count câu hỏi.',
        'Answer $count more prompts.',
      );

      icon = Icons.chat_bubble_outline_rounded;
    } else if (suggestion == 'add_voice_prompt') {
      text = _tr(
        isVi,
        'Thêm Voice Prompt để mọi người hiểu bạn hơn.',
        'Add a Voice Prompt so people can know you better.',
      );

      icon = Icons.mic_none_rounded;
    } else if (suggestion == 'add_bio') {
      text = _tr(
        isVi,
        'Thêm phần giới thiệu về bản thân.',
        'Add a short bio about yourself.',
      );

      icon = Icons.edit_note_rounded;
    } else if (suggestion == 'bio_too_short' ||
        suggestion == 'bio_could_be_longer') {
      text = _tr(
        isVi,
        'Bio của bạn đang hơi ngắn.',
        'Your bio is a little short.',
      );

      icon = Icons.edit_note_rounded;
    } else if (suggestion == 'verify_photo') {
      text = _tr(
        isVi,
        'Xác minh ảnh để tăng độ tin cậy.',
        'Verify your photo to build trust.',
      );

      icon = Icons.verified_outlined;
    } else if (suggestion == 'add_living_location') {
      text = _tr(
        isVi,
        'Thêm nơi bạn đang sống.',
        'Add where you currently live.',
      );

      icon = Icons.location_on_outlined;
    } else if (suggestion == 'add_height') {
      text = _tr(
        isVi,
        'Thêm chiều cao.',
        'Add your height.',
      );

      icon = Icons.height_rounded;
    } else if (suggestion == 'add_education') {
      text = _tr(
        isVi,
        'Thêm trình độ học vấn.',
        'Add your education.',
      );

      icon = Icons.school_outlined;
    } else if (suggestion == 'add_occupation') {
      text = _tr(
        isVi,
        'Thêm nghề nghiệp.',
        'Add your occupation.',
      );

      icon = Icons.work_outline_rounded;
    } else if (suggestion == 'add_relationship_goal') {
      text = _tr(
        isVi,
        'Thêm mục tiêu hẹn hò.',
        'Add your relationship goal.',
      );

      icon = Icons.favorite_border_rounded;
    } else {
      text = '';
      icon = Icons.info_outline_rounded;
    }

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: const Color(0xFFCC3D7A),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5F4654),
              ),
            ),
          ),
        ],
      ),
    );
  }),
],
      ],
    ),
  );
}

  Widget _buildMyProfile(Map<String, dynamic> profile, bool isVi) {
    final photos = _extractPhotos(profile);
    final facebookUrl =
    (profile['facebookUrl'] ?? '').toString().trim();

final instagramUrl =
    (profile['instagramUrl'] ?? '').toString().trim();

final tiktokUrl =
    (profile['tiktokUrl'] ?? '').toString().trim();

final showSocialMedia =
    profile['showSocialMedia'] == true;
    final prompts = _extractPrompts(profile, isVi);
    
    final profileHealthData = <String, dynamic>{
  ...profile,

  // Dùng danh sách ảnh đã được My Profile đọc và loại ảnh trùng.
  'photos': photos,

  // Chuyển prompt hiện tại về đúng dạng mà profile_health.dart đang đọc.
  for (int i = 0; i < prompts.length && i < 5; i++)
    'prompt${i + 1}Answer':
        (prompts[i]['answer'] ?? '').toString().trim(),
};

final profileHealth = calculateProfileHealth(profileHealthData);
debugPrint('PROFILE HEALTH: ${profileHealth.score}');
    

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

    final bornDisplay = _buildBornDisplay(profile, isVi);
    final religion = _translateProfileValue(
      (profile['religion'] ?? '').toString(),
      isVi,
    );
    final education = _translateProfileValue(
      (profile['highestEducation'] ?? profile['highestDegree'] ?? '').toString(),
      isVi,
    );
    final occupation = _translateProfileValue(
      (profile['occupation'] ?? '').toString(),
      isVi,
    );
    final annualIncome = _translateProfileValue(
      (profile['annualIncome'] ?? '').toString(),
      isVi,
    );
    final maritalStatus = _translateProfileValue(
      (profile['maritalStatus'] ?? '').toString(),
      isVi,
    );
    final haveChildren = _translateProfileValue(
  (profile['haveChildren'] ?? '').toString(),
  isVi,
);
    final relationshipGoal = _translateProfileValue(
      (profile['relationshipGoal'] ?? '').toString(),
      isVi,
    );
    final residentStatus = _translateProfileValue(
      (profile['residentStatus'] ?? '').toString(),
      isVi,
    );
    final drinking = _translateProfileValue(
      (profile['drinking'] ?? '').toString(),
      isVi,
    );
    final smoking = _translateProfileValue(
      (profile['smoking'] ?? '').toString(),
      isVi,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
  profile: profile,
  isVi: isVi,
  photos: photos,
),

const SizedBox(height: 18),

if (profileHealth.score < 100)
  _buildProfileHealthCard(
    profileHealth: profileHealth,
    isVi: isVi,
  ),

if (profileHealth.score < 100)
  const SizedBox(height: 22),


          if (getPhoto(1).isNotEmpty) _buildPhotoBlock(getPhoto(1)),
          if (getPhoto(1).isNotEmpty && getPrompt(0)['question']!.isNotEmpty)
            const SizedBox(height: 16),

          if (getPrompt(0)['question']!.isNotEmpty ||
              getPrompt(0)['answer']!.isNotEmpty)
            _buildPromptCard(
              question: getPrompt(0)['question'] ?? '',
              answer: getPrompt(0)['answer'] ?? '',
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
    durationSeconds: profile['voicePromptDuration'] is int
        ? profile['voicePromptDuration'] as int
        : int.tryParse(
              (profile['voicePromptDuration'] ?? '0').toString(),
            ) ??
            0,
    isVi: isVi,
  ),

          if ((bornDisplay.isNotEmpty || religion.isNotEmpty))
            const SizedBox(height: 18),
          _buildInfoCard(
            items: [
              if (bornDisplay.isNotEmpty)
                _InfoItem(
                  icon: Icons.public_rounded,
                  label: _tr(isVi, 'Nơi sinh', 'Born'),
                  text: bornDisplay,
                ),
              if (religion.isNotEmpty)
                _InfoItem(
                  icon: Icons.self_improvement_outlined,
                  label: _tr(isVi, 'Tôn giáo', 'Religion'),
                  text: religion,
                ),
            ],
          ),

          if (getPhoto(2).isNotEmpty) const SizedBox(height: 18),
          if (getPhoto(2).isNotEmpty) _buildPhotoBlock(getPhoto(2)),

          if (getPrompt(1)['question']!.isNotEmpty ||
              getPrompt(1)['answer']!.isNotEmpty)
            const SizedBox(height: 16),
          if (getPrompt(1)['question']!.isNotEmpty ||
              getPrompt(1)['answer']!.isNotEmpty)
            _buildPromptCard(
              question: getPrompt(1)['question'] ?? '',
              answer: getPrompt(1)['answer'] ?? '',
            ),

          if (education.isNotEmpty ||
              occupation.isNotEmpty ||
              annualIncome.isNotEmpty)
            const SizedBox(height: 18),
          _buildHorizontalCareerSlider(
            isVi: isVi,
            highestDegree: education,
            occupation: occupation,
            annualIncome: annualIncome,
          ),

          if (getPhoto(3).isNotEmpty) const SizedBox(height: 18),
          if (getPhoto(3).isNotEmpty) _buildPhotoBlock(getPhoto(3)),

          if (getPrompt(2)['question']!.isNotEmpty ||
              getPrompt(2)['answer']!.isNotEmpty)
            const SizedBox(height: 16),
          if (getPrompt(2)['question']!.isNotEmpty ||
              getPrompt(2)['answer']!.isNotEmpty)
            _buildPromptCard(
              question: getPrompt(2)['question'] ?? '',
              answer: getPrompt(2)['answer'] ?? '',
            ),

        if (maritalStatus.isNotEmpty || haveChildren.isNotEmpty)
            const SizedBox(height: 18),
          _buildInfoCard(
            items: [
              if (maritalStatus.isNotEmpty)
                _InfoItem(
                  icon: Icons.favorite_border_rounded,
                  label: _tr(isVi, 'Tình trạng hôn nhân', 'Marital status'),
                  text: maritalStatus,
                ),
    if (haveChildren.isNotEmpty)
  _InfoItem(
    icon: Icons.child_care_outlined,
    label: isVi ? 'Con cái' : 'Children',
    text: haveChildren,
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
                    _tr(
                      isVi,
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
          if (getPhoto(4).isNotEmpty) const SizedBox(height: 18),
          if (getPhoto(4).isNotEmpty) _buildPhotoBlock(getPhoto(4)),

          if (getPrompt(3)['question']!.isNotEmpty ||
              getPrompt(3)['answer']!.isNotEmpty)
            const SizedBox(height: 16),
          if (getPrompt(3)['question']!.isNotEmpty ||
              getPrompt(3)['answer']!.isNotEmpty)
            _buildPromptCard(
              question: getPrompt(3)['question'] ?? '',
              answer: getPrompt(3)['answer'] ?? '',
            ),

          if (residentStatus.isNotEmpty ||
              drinking.isNotEmpty ||
              smoking.isNotEmpty)
            const SizedBox(height: 18),
          _buildInfoCard(
            items: [
              if (residentStatus.isNotEmpty)
                _InfoItem(
                  icon: Icons.badge_outlined,
                  label: _tr(isVi, 'Tình trạng cư trú', 'Resident status'),
                  text: residentStatus,
                ),
              if (drinking.isNotEmpty)
                _InfoItem(
                  icon: Icons.local_bar_outlined,
                  label: _tr(isVi, 'Uống rượu', 'Drink'),
                  text: drinking,
                ),
              if (smoking.isNotEmpty)
                _InfoItem(
                  icon: Icons.smoke_free_outlined,
                  label: _tr(isVi, 'Hút thuốc', 'Smoke'),
                  text: smoking,
                ),
            ],
          ),

          if (getPrompt(4)['question']!.isNotEmpty ||
              getPrompt(4)['answer']!.isNotEmpty)
            const SizedBox(height: 16),
          if (getPrompt(4)['question']!.isNotEmpty ||
              getPrompt(4)['answer']!.isNotEmpty)
            _buildPromptCard(
              question: getPrompt(4)['question'] ?? '',
              answer: getPrompt(4)['answer'] ?? '',
            ),
if (showSocialMedia &&
    (facebookUrl.isNotEmpty ||
        instagramUrl.isNotEmpty ||
        tiktokUrl.isNotEmpty)) ...[
  const SizedBox(height: 24),

  Text(
    _tr(isVi, 'Mạng xã hội', 'Social media'),
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: Color(0xFF7A2E6E),
    ),
  ),

  const SizedBox(height: 14),
  Wrap(
  spacing: 14,
  children: [
    if (facebookUrl.isNotEmpty)
      InkWell(
      onTap: () => _openSocial(
  value: facebookUrl,
  platform: 'facebook',
),
        borderRadius: BorderRadius.circular(30),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF1877F2),
          child: const Icon(
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
        
        ],
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
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
                _tr(
                  widget.languageCode == 'vi',
                  'Có lỗi khi tải hồ sơ của bạn.',
                  'Error loading your profile.',
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

        final profile = snapshot.data;
        if (profile == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _tr(
                  widget.languageCode == 'vi',
                  'Không tìm thấy hồ sơ hiện tại.',
                  'Current profile not found.',
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

        final resolvedLanguageCode = _resolveLanguageCode(profile);
        final isVi = resolvedLanguageCode == 'vi';

        return _buildMyProfile(profile, isVi);
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

    switch (platform) {
      case 'facebook':
        url = 'https://www.facebook.com/$username';
        break;
      case 'instagram':
        url = 'https://www.instagram.com/$username';
        break;
      case 'tiktok':
        url = 'https://www.tiktok.com/@$username';
        break;
      default:
        url = input;
    }
  }

  final uri = Uri.tryParse(url);

  if (uri == null) return;

  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
}
  @override
  Widget build(BuildContext context) {
    final content = Container(
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
        bottom: false,
        child: _buildBody(),
      ),
    );

    if (widget.embedInParentScaffold) {
      return content;
    }

    final isVi = widget.languageCode == 'vi';

    return Scaffold(
      backgroundColor: Color.fromARGB(0, 255, 247, 251),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF7A2E6E),
        centerTitle: true,
        leading: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  stream: FirebaseAuth.instance.currentUser == null
      ? null
      : FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
  builder: (context, snapshot) {
    final profile = snapshot.data?.data();

    final hasWelcomeGift =
        profile?['welcomeGiftGranted'] == true;

    if (!hasWelcomeGift) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(left: 10),
      child: IconButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MyGiftPage(
                languageCode: widget.languageCode,
              ),
            ),
          );
        },
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.card_giftcard_rounded,
            color: Color(0xFFB83280),
            size: 22,
          ),
        ),
      ),
    );
  },
),
        title: const Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(Icons.favorite, color: Color(0xFF7A2E6E), size: 22),
    SizedBox(width: 6),
    Icon(Icons.favorite, color: Color(0xFF7A2E6E), size: 22),
    SizedBox(width: 6),
    Icon(Icons.favorite, color: Color(0xFF7A2E6E), size: 22),
  ],
),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            child: IconButton(
              onPressed: _openSettings,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: Color(0xFFB83280),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
      body: content,
    );
  }
}

class ProfileSettingsPage extends StatelessWidget {
  final String languageCode;

  const ProfileSettingsPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;
Future<void> _openInstagram() async {
  final appUri = Uri.parse(
    'instagram://user?username=chichouse9999',
  );

  final webUri = Uri.parse(
    'https://www.instagram.com/chichouse9999',
  );

  if (await canLaunchUrl(appUri)) {
    await launchUrl(
      appUri,
      mode: LaunchMode.externalApplication,
    );
    return;
  }

  await launchUrl(
    webUri,
    mode: LaunchMode.externalApplication,
  );
}
  @override
  Widget build(BuildContext context) {
   return Scaffold(
  backgroundColor: Color.fromARGB(255, 255, 248, 251),
  appBar: AppBar(
    backgroundColor: Color.fromARGB(255, 246, 240, 240),
    elevation: 0,
    foregroundColor: const Color(0xFF7A2E6E),
    centerTitle: true,
    title: Text(
      _tr('Cài đặt', 'Settings'),
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        color: Color(0xFF7A2E6E),
      ),
    ),
  ),

  // 👇 THÊM NGAY DƯỚI ĐÂY 👇
  body: ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
    children: [
      ListTile(
        leading: const Icon(Icons.edit),
        title: Text(_tr('Sửa hồ sơ', 'Edit Profile')),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditProfilePage(
                languageCode: languageCode,
              ),
            ),
          );
        },
      ),

      ListTile(
  leading: const Icon(Icons.notifications),
  title: Text(_tr('Thông báo', 'Notifications')),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationSettingsPage(
          languageCode: languageCode,
        ),
      ),
    );
  },
),

      ListTile(
  leading: const Icon(Icons.privacy_tip),
  title: Text(_tr('Quyền riêng tư', 'Privacy')),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivacyProfilePage(
          languageCode: languageCode,
        ),
      ),
    );
  },
),

       ListTile(
            leading: const Icon(Icons.support_agent),
            title: Text(_tr('Hỗ trợ và chat với admin', 'Support and chat with admin')),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SupportHelpPage(
                    languageCode: languageCode,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(_tr('Tài khoản', 'Account')),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountPage(
                    languageCode: languageCode,
                  ),
                ),
              );
            },
          ),
    ],
  ),
);
  }

  Widget _settingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFFF3F8),
              ],
            ),
            border: Border.all(color: const Color(0xFFFFD5E6)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFCC3D7A).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFCC3D7A),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF444444),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8D6B7D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB83280),
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
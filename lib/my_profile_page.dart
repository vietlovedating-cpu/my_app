import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'prompt_data.dart';
import 'edit_profile_page.dart';
import 'support_help_page.dart';
import 'account_page.dart';
import 'notification_settings_page.dart';
import 'privacy_profile_page.dart';

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

  @override
  void initState() {
    super.initState();

    _lastUid = FirebaseAuth.instance.currentUser?.uid;

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      final newUid = user?.uid;
      if (_lastUid != newUid && mounted) {
        setState(() {
          _lastUid = newUid;
        });
      }
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
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
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
      'australian_citizen': 'Công dân Úc',
      'permanent_resident': 'Thường trú nhân',
      'temporary_visa': 'Visa tạm trú',
      'student_visa': 'Visa du học',
      'working_holiday': 'Visa Working Holiday',
      'work_visa': 'Visa lao động',
      'citizen': 'Công dân',
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
      'công dân úc': 'Australian Citizen',
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
  final candidates = [
    profile['selectedState'],
    profile['state'],
    profile['livingState'],
    profile['stateLiving'],
  ];

  for (final item in candidates) {
    final value = (item ?? '').toString().trim();

    // Chỉ hiện state nếu user đã chọn state thật sự
    if (value.isNotEmpty) return value;
  }

  // Không lấy address nữa để tránh lộ full address
  return '';
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

  void _openSettings() {
    if (widget.onSettingsTap != null) {
      widget.onSettingsTap!.call();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileSettingsPage(
          languageCode: widget.languageCode,
        ),
      ),
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

  Widget _buildMyProfile(Map<String, dynamic> profile, bool isVi) {
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

          if (maritalStatus.isNotEmpty || relationshipGoal.isNotEmpty)
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
     if (haveChildren.isNotEmpty)
      _InfoItem(
        icon: Icons.child_care_outlined,
        label: _tr(isVi, 'Con cái', 'Children'),
        text: haveChildren,
      ),
              if (relationshipGoal.isNotEmpty)
                _InfoItem(
                  icon: Icons.favorite_rounded,
                  label: _tr(isVi, 'Mục tiêu mối quan hệ', 'Relationship goal'),
                  text: relationshipGoal,
                ),
            ],
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

          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadMyProfile(),
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
        title: Text(
          _tr(isVi, '❤️❤️❤️', '❤️❤️❤️'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Color(0xFF7A2E6E),
            letterSpacing: 0.2,
          ),
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
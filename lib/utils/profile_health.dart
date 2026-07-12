import 'package:flutter/foundation.dart';

class ProfileHealthResult {
  final int score;
  final List<String> suggestions;

  const ProfileHealthResult({
    required this.score,
    required this.suggestions,
  });
}

ProfileHealthResult calculateProfileHealth(
  Map<String, dynamic> user,
) {
  int score = 0;
  final suggestions = <String>[];

  bool hasText(dynamic value) {
    return (value ?? '').toString().trim().isNotEmpty;
  }

  bool hasAnyText(List<dynamic> values) {
    return values.any(hasText);
  }

  bool hasListValue(dynamic value) {
    if (value is List) {
      return value.any(
        (item) => item != null && item.toString().trim().isNotEmpty,
      );
    }

    return hasText(value);
  }

  /// ============================================================
  /// 1. ẢNH HỒ SƠ — TỐI ĐA 40 ĐIỂM
  /// ============================================================

  final rawPhotos = user['photos'];

  final photos = rawPhotos is List
      ? rawPhotos
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
      : <String>[];

  final photoCount = photos.length.clamp(0, 5);

  score += photoCount * 8;

  if (photoCount < 5) {
    final missingPhotos = 5 - photoCount;

    suggestions.add(
      missingPhotos == 1
          ? 'add_1_photo'
          : 'add_more_photos:$missingPhotos',
    );
  }

  /// ============================================================
  /// 2. PROMPT — TỐI ĐA 10 ĐIỂM
  /// ============================================================

  int answeredPrompts = 0;

  for (int i = 1; i <= 5; i++) {
    final answer =
        (user['prompt${i}Answer'] ?? '').toString().trim();

    if (answer.isNotEmpty) {
      answeredPrompts++;
    }
  }

  score += answeredPrompts * 2;

  if (answeredPrompts < 5) {
    final missingPrompts = 5 - answeredPrompts;

    suggestions.add(
      missingPrompts == 1
          ? 'answer_1_prompt'
          : 'answer_more_prompts:$missingPrompts',
    );
  }

  /// ============================================================
  /// 3. VOICE PROMPT — TỐI ĐA 5 ĐIỂM
  /// ============================================================

  final hasVoicePrompt = hasAnyText([
    user['voicePromptAudioUrl'],
    user['voicePromptUrl'],
    user['audioPromptUrl'],
  ]);

  if (hasVoicePrompt) {
    score += 5;
  } else {
    suggestions.add('add_voice_prompt');
  }


  /// ============================================================
  /// 5. XÁC MINH ẢNH — TỐI ĐA 5 ĐIỂM
  /// ============================================================

  final photoVerified =
      user['photoVerified'] == true ||
      user['isPhotoVerified'] == true ||
      (user['photoVerificationStatus'] ?? '')
              .toString()
              .trim()
              .toLowerCase() ==
          'approved';

  if (photoVerified) {
    score += 5;
  } else {
    suggestions.add('verify_photo');
  }

  /// ============================================================
  /// 6. THÔNG TIN CÁ NHÂN — TỐI ĐA 40 ĐIỂM
  /// Mỗi nhóm đầy đủ được 4 điểm.
  /// ============================================================

  final personalSections = <bool>[
    /// Nơi đang sống
    hasAnyText([
      user['selectedStateKey'],
      user['selectedState'],
      user['state'],
      user['filterState'],
      user['stateProvince'],
      user['province'],
      user['selectedCountry'],
      user['country'],
    ]),

    /// Nơi sinh
    hasAnyText([
      user['countryOfBirth'],
      user['cityOfBirth'],
      user['birthCity'],
      user['vietnamBirthProvince'],
      user['vietnamBirthCity'],
    ]),

    /// Chiều cao
    hasAnyText([
      user['height'],
      user['heightCm'],
    ]),

    /// Học vấn
    hasAnyText([
      user['highestEducation'],
      user['highestDegree'],
      user['education'],
    ]),

    /// Nghề nghiệp
    hasAnyText([
      user['occupation'],
      user['job'],
      user['profession'],
    ]),

    /// Tình trạng hôn nhân
    hasAnyText([
      user['maritalStatus'],
    ]),

    /// Con cái
    hasAnyText([
      user['haveChildren'],
      user['children'],
    ]),

    /// Tình trạng cư trú
    hasAnyText([
      user['residentStatus'],
      user['residencyStatus'],
      user['visaStatus'],
    ]),

    /// Lối sống: có ít nhất smoking hoặc drinking
    hasAnyText([
      user['smoking'],
      user['drinking'],
    ]),

    /// Mục tiêu hẹn hò
    hasListValue(
      user['relationshipGoals'] ?? user['relationshipGoal'],
    ),
  ];

  final completedPersonalSections =
      personalSections.where((item) => item).length;

  score += completedPersonalSections * 4;

  if (!personalSections[0]) {
    suggestions.add('add_living_location');
  }

  if (!personalSections[2]) {
    suggestions.add('add_height');
  }

  if (!personalSections[3]) {
    suggestions.add('add_education');
  }

  if (!personalSections[4]) {
    suggestions.add('add_occupation');
  }

  if (!personalSections[9]) {
  suggestions.add('add_relationship_goal');
}

/// Đảm bảo kết quả luôn nằm trong khoảng 0–100.
score = score.clamp(0, 100);

debugPrint('photoCount = $photoCount');
debugPrint('answeredPrompts = $answeredPrompts');
debugPrint('hasVoicePrompt = $hasVoicePrompt');
debugPrint('photoVerified = $photoVerified');
debugPrint('personalSections = $personalSections');
debugPrint(
  'completedPersonalSections = $completedPersonalSections',
);
debugPrint('score = $score');

return ProfileHealthResult(
  score: score,
  suggestions: suggestions,
);
}
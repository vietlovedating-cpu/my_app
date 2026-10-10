import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'language_exchange_group_chat_page.dart';
import 'group_chat_welcome_page.dart';
import 'group_data1.dart';
// ============================================================
// LANGUAGE EXCHANGE PAGE
// ============================================================

class LanguageExchangePage extends StatelessWidget {
  final String languageCode;

  const LanguageExchangePage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String label(String vi, String en) {
    return isVi ? vi : en;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF555555),
        centerTitle: true,
        title: Text(
          label(
            'Trao đổi ngôn ngữ',
            'Language Exchange',
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFDDEA),
              Color(0xFFFFEFF5),
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            18,
            20,
            18,
            35,
          ),
          children: [
            // ==================================================
            // INTRO
            // ==================================================

            _IntroCard(
              isVi: isVi,
            ),

            const SizedBox(height: 15),

            // ==================================================
            // EASY
            // ==================================================

            _SectionCard(
              icon: Icons.menu_book_rounded,
              title: '100 Easy Verbs',
              subtitle: label(
                '100 động từ tiếng Anh cơ bản dùng hằng ngày',
                '100 common English verbs for everyday speaking',
              ),
              color: const Color(0xFF6C63FF),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VocabularyPage(
                      type: VocabType.easy,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // ==================================================
            // INTERMEDIATE
            // ==================================================

            _SectionCard(
              icon: Icons.auto_stories_rounded,
              title: '250 Intermediate Words',
              subtitle: label(
                '250 từ vựng tiếng Anh trình độ trung cấp',
                '250 useful intermediate English words',
              ),
              color: const Color(0xFF4F8EF7),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VocabularyPage(
                      type: VocabType.intermediate,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // ==================================================
            // ADVANCED
            // ==================================================

            _SectionCard(
              icon: Icons.school_rounded,
              title: '850 Advanced Words',
              subtitle: label(
                '850 từ vựng tiếng Anh nâng cao',
                '850 advanced English words',
              ),
              color: const Color(0xFF8A5CF6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VocabularyPage(
                      type: VocabType.advanced,
                    ),
                  ),
                );
              },
            ),
            

            const SizedBox(height: 16),

            // ==================================================
            // 1,000 PRACTICE
            // ==================================================

            _PracticeCard(
              isVi: isVi,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PracticePage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // ==================================================
            // VOA
            // ==================================================

            const _VoASection(),
const SizedBox(height: 16),

// ==================================================
// STUDY TOGETHER
// ==================================================


_StudyTogetherCard(
  isVi: isVi,
  onTap: () async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            label(
              'Vui lòng đăng nhập trước khi vào nhóm.',
              'Please log in before entering the group.',
            ),
          ),
        ),
      );
      return;
    }

    final group = kDatingGroups.firstWhere(
      (g) => g.id == 'english_exchange',
    );

    bool hasAcceptedRules = false;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final acceptedRules = userData?['acceptedGroupRules'];

      hasAcceptedRules = acceptedRules is Map &&
          acceptedRules['english_exchange'] == true;
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            label(
              'Không thể kiểm tra nội quy. Vui lòng thử lại.',
              'Could not check the group rules. Please try again.',
            ),
          ),
        ),
      );
      return;
    }

    if (!context.mounted) return;

    // Đã đồng ý trước đó: vào thẳng group chat.
    if (hasAcceptedRules) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LanguageExchangeGroupChatPage(
            languageCode: languageCode,
            group: group,
          ),
        ),
      );
      return;
    }

    // Chưa đồng ý: hiện Welcome như bình thường.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (welcomeContext) => GroupChatWelcomePage(
          languageCode: languageCode,
          onAgree: () async {
            try {
              // Lưu trạng thái đồng ý vào Firestore.
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .set(
                {
                  'acceptedGroupRules': {
                    'english_exchange': true,
                  },
                },
                SetOptions(merge: true),
              );

              if (!welcomeContext.mounted) return;

              // Lưu thành công mới chuyển vào chat.
              Navigator.pushReplacement(
                welcomeContext,
                MaterialPageRoute(
                  builder: (_) => LanguageExchangeGroupChatPage(
                    languageCode: languageCode,
                    group: group,
                  ),
                ),
              );
            } catch (e) {
              if (!welcomeContext.mounted) return;

              ScaffoldMessenger.of(welcomeContext).showSnackBar(
                SnackBar(
                  content: Text(
                    label(
                      'Không lưu được xác nhận nội quy. Vui lòng thử lại.',
                      'Could not save your agreement. Please try again.',
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  },
),

const SizedBox(height: 16),


const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// INTRO CARD
// ============================================================

class _IntroCard extends StatelessWidget {
  final bool isVi;

  const _IntroCard({
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 13,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE3EF),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.language_rounded,
                  color: Color(0xFFE45B91),
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isVi
                      ? 'Học tiếng Anh mỗi ngày'
                      : 'Learn English Every Day',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            isVi
                ? 'Học từ vựng, luyện câu giao tiếp và nghe tiếng Anh theo cách đơn giản, dễ thực hành.'
                : 'Learn vocabulary, practise everyday English and improve your listening step by step.',
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NORMAL SECTION CARD
// ============================================================

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.055),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFAAAAAA),
                size: 29,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 1,000 PRACTICE CARD
// ============================================================

class _PracticeCard extends StatelessWidget {
  final bool isVi;
  final VoidCallback onTap;

  const _PracticeCard({
    required this.isVi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6548D8),
                Color(0xFFA34DB5),
                Color(0xFFE65C91),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6)
                    .withOpacity(0.28),
                blurRadius: 17,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.20),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '⭐ FEATURED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.headphones_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.18),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.record_voice_over_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1,000 PRACTICE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isVi
                              ? 'Nghe → Lặp lại → Nói'
                              : 'Listen → Repeat → Speak',
                          style: TextStyle(
                            color: Colors.white
                                .withOpacity(0.92),
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Text(
                isVi
                    ? '1.000 câu tiếng Anh giao tiếp hằng ngày để luyện nói.'
                    : '1,000 everyday English sentences to practise speaking.',
                style: TextStyle(
                  color: Colors.white
                      .withOpacity(0.95),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 17),

              Container(
                width: double.infinity,
                height: 51,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Color(0xFF7048D9),
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVi
                          ? 'BẮT ĐẦU LUYỆN TẬP'
                          : 'START PRACTICE',
                      style: const TextStyle(
                        color: Color(0xFF7048D9),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// VOA VIDEO SECTION
// ============================================================

class _VoASection extends StatelessWidget {
  const _VoASection();

  Future<void> _openVoA() async {
    final uri = Uri.parse(
      'https://learningenglish.voanews.com/',
    );

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openVoA,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ==================================================
            // VIDEO IMAGE
            // ==================================================

            Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/groups/coffee_weekend.jpg',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: const Color(0xFFE5E5E5),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.video_library_rounded,
                        size: 65,
                        color: Color(0xFF777777),
                      ),
                    );
                  },
                ),

                // Dark overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin:
                            Alignment.topCenter,
                        end:
                            Alignment.bottomCenter,
                        colors: [
                          Colors.black
                              .withOpacity(0.03),
                          Colors.black
                              .withOpacity(0.48),
                        ],
                      ),
                    ),
                  ),
                ),

                // BIG PLAY BUTTON
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withOpacity(0.97),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(0.25),
                        blurRadius: 13,
                        offset:
                            const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xFFE45B91),
                    size: 51,
                  ),
                ),

                // TAP TO WATCH
                Positioned(
                  bottom: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black
                          .withOpacity(0.64),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Tap to Watch Video',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ==================================================
            // DESCRIPTION
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                16,
                18,
                18,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFEAF0FF),
                          borderRadius:
                              BorderRadius.circular(
                            13,
                          ),
                        ),
                        child: const Icon(
                          Icons
                              .ondemand_video_rounded,
                          color:
                              Color(0xFF5D74D3),
                          size: 23,
                        ),
                      ),

                      const SizedBox(width: 12),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VOA Learning English',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w800,
                                color:
                                    Color(0xFF333333),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'English videos & listening practice',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    Color(0xFF777777),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Improve your English listening with VOA Learning English.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF666666),
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _openVoA,
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                      ),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Open VOA Learning English',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor:
                            const Color(0xFF5D74D3),
                        side: const BorderSide(
                          color: Color(0xFF5D74D3),
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _StudyTogetherCard extends StatelessWidget {
  final bool isVi;
  final VoidCallback onTap;

  const _StudyTogetherCard({
    required this.isVi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: const Color(0xFF3976D3).withOpacity(0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3976D3).withOpacity(0.10),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              // GROUP CHAT ICON
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Color(0xFF3976D3),
                  size: 32,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVi ? 'Học cùng nhau' : 'Study Together',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333333),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // GROUP CHAT LABEL
                    Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_rounded,
                          size: 14,
                          color: Color(0xFF3976D3),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isVi
                              ? 'Nhóm chat học tiếng Anh'
                              : 'English Study Group Chat',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3976D3),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      isVi
                          ? 'Tìm bạn cùng học, luyện nói và cùng cải thiện tiếng Anh.'
                          : 'Find people to study together, practise speaking and improve your English.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 17,
                color: Color(0xFF888888),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ============================================================
// VOCABULARY MODEL
// ============================================================

class VocabItem {
  final String word;
  final String meaning;

  const VocabItem({
    required this.word,
    required this.meaning,
  });
}

enum VocabType {
  easy,
  intermediate,
  advanced,
}

// ============================================================
// EASY WORDS
// ============================================================

const List<VocabItem> _easyWords = [
  VocabItem(word: 'be', meaning: 'là, ở, thì'),
  VocabItem(word: 'have', meaning: 'có'),
  VocabItem(word: 'do', meaning: 'làm'),
  VocabItem(word: 'go', meaning: 'đi'),
  VocabItem(word: 'come', meaning: 'đến'),
  VocabItem(word: 'get', meaning: 'nhận, lấy, có được'),
  VocabItem(word: 'make', meaning: 'làm, tạo ra'),
  VocabItem(word: 'take', meaning: 'lấy, mang'),
  VocabItem(word: 'give', meaning: 'cho'),
  VocabItem(word: 'see', meaning: 'thấy'),
  VocabItem(word: 'know', meaning: 'biết'),
  VocabItem(word: 'think', meaning: 'nghĩ'),
  VocabItem(word: 'want', meaning: 'muốn'),
  VocabItem(word: 'need', meaning: 'cần'),
  VocabItem(word: 'like', meaning: 'thích'),
  VocabItem(word: 'love', meaning: 'yêu'),
  VocabItem(word: 'look', meaning: 'nhìn'),
  VocabItem(word: 'watch', meaning: 'xem'),
  VocabItem(word: 'hear', meaning: 'nghe thấy'),
  VocabItem(word: 'listen', meaning: 'lắng nghe'),
  VocabItem(word: 'say', meaning: 'nói'),
  VocabItem(word: 'tell', meaning: 'nói, kể'),
  VocabItem(word: 'speak', meaning: 'nói'),
  VocabItem(word: 'talk', meaning: 'nói chuyện'),
  VocabItem(word: 'ask', meaning: 'hỏi'),
  VocabItem(word: 'answer', meaning: 'trả lời'),
  VocabItem(word: 'call', meaning: 'gọi'),
  VocabItem(word: 'help', meaning: 'giúp'),
  VocabItem(word: 'try', meaning: 'thử'),
  VocabItem(word: 'use', meaning: 'sử dụng'),
  VocabItem(word: 'find', meaning: 'tìm thấy'),
  VocabItem(word: 'keep', meaning: 'giữ'),
  VocabItem(word: 'put', meaning: 'đặt, để'),
  VocabItem(word: 'bring', meaning: 'mang đến'),
  VocabItem(word: 'buy', meaning: 'mua'),
  VocabItem(word: 'pay', meaning: 'trả tiền'),
  VocabItem(word: 'sell', meaning: 'bán'),
  VocabItem(word: 'eat', meaning: 'ăn'),
  VocabItem(word: 'drink', meaning: 'uống'),
  VocabItem(word: 'cook', meaning: 'nấu ăn'),
  VocabItem(word: 'sleep', meaning: 'ngủ'),
  VocabItem(word: 'wake', meaning: 'thức dậy'),
  VocabItem(word: 'sit', meaning: 'ngồi'),
  VocabItem(word: 'stand', meaning: 'đứng'),
  VocabItem(word: 'walk', meaning: 'đi bộ'),
  VocabItem(word: 'run', meaning: 'chạy'),
  VocabItem(word: 'drive', meaning: 'lái xe'),
  VocabItem(word: 'ride', meaning: 'đi, cưỡi'),
  VocabItem(word: 'open', meaning: 'mở'),
  VocabItem(word: 'close', meaning: 'đóng'),
  VocabItem(word: 'start', meaning: 'bắt đầu'),
  VocabItem(word: 'stop', meaning: 'dừng'),
  VocabItem(word: 'wait', meaning: 'đợi'),
  VocabItem(word: 'stay', meaning: 'ở lại'),
  VocabItem(word: 'leave', meaning: 'rời đi'),
  VocabItem(word: 'arrive', meaning: 'đến nơi'),
  VocabItem(word: 'live', meaning: 'sống'),
  VocabItem(word: 'work', meaning: 'làm việc'),
  VocabItem(word: 'study', meaning: 'học'),
  VocabItem(word: 'learn', meaning: 'học, học cách'),
  VocabItem(word: 'read', meaning: 'đọc'),
  VocabItem(word: 'write', meaning: 'viết'),
  VocabItem(word: 'remember', meaning: 'nhớ'),
  VocabItem(word: 'forget', meaning: 'quên'),
  VocabItem(word: 'understand', meaning: 'hiểu'),
  VocabItem(word: 'feel', meaning: 'cảm thấy'),
  VocabItem(word: 'hope', meaning: 'hy vọng'),
  VocabItem(word: 'wish', meaning: 'ước, mong'),
  VocabItem(word: 'choose', meaning: 'chọn'),
  VocabItem(word: 'change', meaning: 'thay đổi'),
  VocabItem(word: 'move', meaning: 'di chuyển'),
  VocabItem(word: 'turn', meaning: 'quay, rẽ'),
  VocabItem(word: 'follow', meaning: 'theo'),
  VocabItem(word: 'meet', meaning: 'gặp'),
  VocabItem(word: 'visit', meaning: 'thăm'),
  VocabItem(word: 'join', meaning: 'tham gia'),
  VocabItem(word: 'play', meaning: 'chơi'),
  VocabItem(word: 'win', meaning: 'thắng'),
  VocabItem(word: 'lose', meaning: 'thua, mất'),
  VocabItem(word: 'send', meaning: 'gửi'),
  VocabItem(word: 'receive', meaning: 'nhận'),
  VocabItem(word: 'show', meaning: 'cho xem, chỉ'),
  VocabItem(word: 'hold', meaning: 'cầm, giữ'),
  VocabItem(word: 'carry', meaning: 'mang, xách'),
  VocabItem(word: 'wear', meaning: 'mặc, đeo'),
  VocabItem(word: 'wash', meaning: 'rửa, giặt'),
  VocabItem(word: 'clean', meaning: 'làm sạch'),
  VocabItem(word: 'fix', meaning: 'sửa'),
  VocabItem(word: 'check', meaning: 'kiểm tra'),
  VocabItem(word: 'plan', meaning: 'lên kế hoạch'),
  VocabItem(word: 'decide', meaning: 'quyết định'),
  VocabItem(word: 'agree', meaning: 'đồng ý'),
  VocabItem(word: 'believe', meaning: 'tin'),
  VocabItem(word: 'happen', meaning: 'xảy ra'),
  VocabItem(word: 'become', meaning: 'trở thành'),
  VocabItem(word: 'seem', meaning: 'có vẻ'),
  VocabItem(word: 'mean', meaning: 'có nghĩa là'),
  VocabItem(word: 'practice', meaning: 'luyện tập'),
];

// ============================================================
// INTERMEDIATE WORDS
// ============================================================

const List<VocabItem> _intermediateWords = [
  VocabItem(word: 'ability', meaning: 'khả năng'),
  VocabItem(word: 'advice', meaning: 'lời khuyên'),
  VocabItem(word: 'advantage', meaning: 'lợi thế'),
  VocabItem(word: 'appointment', meaning: 'cuộc hẹn'),
  VocabItem(word: 'arrangement', meaning: 'sự sắp xếp'),
  VocabItem(word: 'attention', meaning: 'sự chú ý'),
  VocabItem(word: 'behavior', meaning: 'hành vi'),
  VocabItem(word: 'benefit', meaning: 'lợi ích'),
  VocabItem(word: 'challenge', meaning: 'thử thách'),
  VocabItem(word: 'choice', meaning: 'sự lựa chọn'),
  VocabItem(word: 'communication', meaning: 'giao tiếp'),
  VocabItem(word: 'community', meaning: 'cộng đồng'),
  VocabItem(word: 'confidence', meaning: 'sự tự tin'),
  VocabItem(word: 'connection', meaning: 'sự kết nối'),
  VocabItem(word: 'conversation', meaning: 'cuộc trò chuyện'),
  VocabItem(word: 'customer', meaning: 'khách hàng'),
  VocabItem(word: 'decision', meaning: 'quyết định'),
  VocabItem(word: 'difference', meaning: 'sự khác biệt'),
  VocabItem(word: 'experience', meaning: 'kinh nghiệm, trải nghiệm'),
  VocabItem(word: 'education', meaning: 'giáo dục'),
  VocabItem(word: 'environment', meaning: 'môi trường'),
  VocabItem(word: 'example', meaning: 'ví dụ'),
  VocabItem(word: 'exercise', meaning: 'bài tập, tập thể dục'),
  VocabItem(word: 'future', meaning: 'tương lai'),
  VocabItem(word: 'goal', meaning: 'mục tiêu'),
  VocabItem(word: 'habit', meaning: 'thói quen'),
  VocabItem(word: 'health', meaning: 'sức khỏe'),
  VocabItem(word: 'improvement', meaning: 'sự cải thiện'),
  VocabItem(word: 'information', meaning: 'thông tin'),
  VocabItem(word: 'interest', meaning: 'sự quan tâm'),
  VocabItem(word: 'knowledge', meaning: 'kiến thức'),
  VocabItem(word: 'language', meaning: 'ngôn ngữ'),
  VocabItem(word: 'lifestyle', meaning: 'lối sống'),
  VocabItem(word: 'opinion', meaning: 'ý kiến'),
  VocabItem(word: 'opportunity', meaning: 'cơ hội'),
  VocabItem(word: 'permission', meaning: 'sự cho phép'),
  VocabItem(word: 'personality', meaning: 'tính cách'),
  VocabItem(word: 'possibility', meaning: 'khả năng xảy ra'),
  VocabItem(word: 'problem', meaning: 'vấn đề'),
  VocabItem(word: 'relationship', meaning: 'mối quan hệ'),
  VocabItem(word: 'responsibility', meaning: 'trách nhiệm'),
  VocabItem(word: 'routine', meaning: 'thói quen hằng ngày'),
  VocabItem(word: 'situation', meaning: 'tình huống'),
  VocabItem(word: 'solution', meaning: 'giải pháp'),
  VocabItem(word: 'support', meaning: 'sự hỗ trợ'),
  VocabItem(word: 'suggestion', meaning: 'gợi ý'),
  VocabItem(word: 'success', meaning: 'thành công'),
  VocabItem(word: 'travel', meaning: 'du lịch'),
  VocabItem(word: 'comfortable', meaning: 'thoải mái'),
  VocabItem(word: 'convenient', meaning: 'thuận tiện'),
  VocabItem(word: 'curious', meaning: 'tò mò'),
  VocabItem(word: 'different', meaning: 'khác nhau'),
  VocabItem(word: 'difficult', meaning: 'khó'),
  VocabItem(word: 'effective', meaning: 'hiệu quả'),
  VocabItem(word: 'familiar', meaning: 'quen thuộc'),
  VocabItem(word: 'helpful', meaning: 'hữu ích'),
  VocabItem(word: 'important', meaning: 'quan trọng'),
  VocabItem(word: 'independent', meaning: 'độc lập'),
  VocabItem(word: 'interesting', meaning: 'thú vị'),
  VocabItem(word: 'local', meaning: 'địa phương'),
  VocabItem(word: 'natural', meaning: 'tự nhiên'),
  VocabItem(word: 'necessary', meaning: 'cần thiết'),
  VocabItem(word: 'normal', meaning: 'bình thường'),
  VocabItem(word: 'patient', meaning: 'kiên nhẫn'),
  VocabItem(word: 'personal', meaning: 'cá nhân'),
  VocabItem(word: 'popular', meaning: 'phổ biến'),
  VocabItem(word: 'possible', meaning: 'có thể'),
  VocabItem(word: 'practical', meaning: 'thực tế'),
  VocabItem(word: 'private', meaning: 'riêng tư'),
  VocabItem(word: 'professional', meaning: 'chuyên nghiệp'),
  VocabItem(word: 'recent', meaning: 'gần đây'),
  VocabItem(word: 'regular', meaning: 'thường xuyên'),
  VocabItem(word: 'responsible', meaning: 'có trách nhiệm'),
  VocabItem(word: 'similar', meaning: 'tương tự'),
  VocabItem(word: 'simple', meaning: 'đơn giản'),
  VocabItem(word: 'special', meaning: 'đặc biệt'),
  VocabItem(word: 'successful', meaning: 'thành công'),
  VocabItem(word: 'useful', meaning: 'hữu ích'),
  VocabItem(word: 'available', meaning: 'có sẵn'),
  VocabItem(word: 'aware', meaning: 'nhận thức được'),
  VocabItem(word: 'busy', meaning: 'bận'),
  VocabItem(word: 'careful', meaning: 'cẩn thận'),
  VocabItem(word: 'certain', meaning: 'chắc chắn'),
  VocabItem(word: 'clear', meaning: 'rõ ràng'),
  VocabItem(word: 'common', meaning: 'phổ biến'),
  VocabItem(word: 'creative', meaning: 'sáng tạo'),
  VocabItem(word: 'friendly', meaning: 'thân thiện'),
  VocabItem(word: 'generous', meaning: 'hào phóng'),
  VocabItem(word: 'honest', meaning: 'trung thực'),
  VocabItem(word: 'kind', meaning: 'tử tế'),
  VocabItem(word: 'polite', meaning: 'lịch sự'),
  VocabItem(word: 'quiet', meaning: 'yên tĩnh'),
  VocabItem(word: 'ready', meaning: 'sẵn sàng'),
  VocabItem(word: 'relaxed', meaning: 'thư giãn'),
  VocabItem(word: 'serious', meaning: 'nghiêm túc'),
  VocabItem(word: 'social', meaning: 'mang tính xã hội'),
  VocabItem(word: 'strong', meaning: 'mạnh'),
];

// ============================================================
// ADVANCED WORDS
// ============================================================

const List<VocabItem> _advancedWords = [
  VocabItem(word: 'abundant', meaning: 'dồi dào, phong phú'),
  VocabItem(word: 'accurate', meaning: 'chính xác'),
  VocabItem(word: 'adapt', meaning: 'thích nghi'),
  VocabItem(word: 'adequate', meaning: 'đầy đủ, phù hợp'),
  VocabItem(word: 'ambiguous', meaning: 'mơ hồ, có nhiều cách hiểu'),
  VocabItem(word: 'anticipate', meaning: 'dự đoán, lường trước'),
  VocabItem(word: 'apparent', meaning: 'rõ ràng, có vẻ'),
  VocabItem(word: 'arbitrary', meaning: 'tùy ý, không theo nguyên tắc'),
  VocabItem(word: 'assess', meaning: 'đánh giá'),
  VocabItem(word: 'assumption', meaning: 'giả định'),
  VocabItem(word: 'beneficial', meaning: 'có lợi'),
  VocabItem(word: 'coherent', meaning: 'mạch lạc'),
  VocabItem(word: 'compelling', meaning: 'thuyết phục, hấp dẫn'),
  VocabItem(word: 'comprehensive', meaning: 'toàn diện'),
  VocabItem(word: 'conceive', meaning: 'hình dung, nghĩ ra'),
  VocabItem(word: 'considerable', meaning: 'đáng kể'),
  VocabItem(word: 'consistent', meaning: 'nhất quán'),
  VocabItem(word: 'controversial', meaning: 'gây tranh cãi'),
  VocabItem(word: 'conventional', meaning: 'truyền thống, thông thường'),
  VocabItem(word: 'crucial', meaning: 'cực kỳ quan trọng'),
  VocabItem(word: 'deteriorate', meaning: 'xấu đi'),
  VocabItem(word: 'diminish', meaning: 'giảm bớt'),
  VocabItem(word: 'distinct', meaning: 'khác biệt, rõ rệt'),
  VocabItem(word: 'elaborate', meaning: 'chi tiết, công phu'),
  VocabItem(word: 'empirical', meaning: 'dựa trên thực nghiệm'),
  VocabItem(word: 'enhance', meaning: 'nâng cao, cải thiện'),
  VocabItem(word: 'equivalent', meaning: 'tương đương'),
  VocabItem(word: 'explicit', meaning: 'rõ ràng, minh bạch'),
  VocabItem(word: 'facilitate', meaning: 'tạo điều kiện'),
  VocabItem(word: 'fundamental', meaning: 'cơ bản, nền tảng'),
  VocabItem(word: 'inevitable', meaning: 'không thể tránh khỏi'),
  VocabItem(word: 'inherent', meaning: 'vốn có'),
  VocabItem(word: 'innovative', meaning: 'đổi mới, sáng tạo'),
  VocabItem(word: 'integrity', meaning: 'sự chính trực'),
  VocabItem(word: 'interpret', meaning: 'diễn giải'),
  VocabItem(word: 'justify', meaning: 'chứng minh là hợp lý'),
  VocabItem(word: 'logical', meaning: 'hợp lý, logic'),
  VocabItem(word: 'meticulous', meaning: 'tỉ mỉ'),
  VocabItem(word: 'notion', meaning: 'khái niệm, quan niệm'),
  VocabItem(word: 'obtain', meaning: 'đạt được, có được'),
  VocabItem(word: 'precise', meaning: 'chính xác'),
  VocabItem(word: 'predominant', meaning: 'chiếm ưu thế'),
  VocabItem(word: 'prioritize', meaning: 'ưu tiên'),
  VocabItem(word: 'profound', meaning: 'sâu sắc'),
  VocabItem(word: 'rational', meaning: 'hợp lý'),
  VocabItem(word: 'reluctant', meaning: 'miễn cưỡng'),
  VocabItem(word: 'substantial', meaning: 'đáng kể'),
  VocabItem(word: 'sustainable', meaning: 'bền vững'),
  VocabItem(word: 'transform', meaning: 'thay đổi, biến đổi'),
  VocabItem(word: 'underlying', meaning: 'tiềm ẩn, nền tảng'),
  VocabItem(word: 'allocate', meaning: 'phân bổ'),
  VocabItem(word: 'articulate', meaning: 'diễn đạt rõ ràng'),
  VocabItem(word: 'assert', meaning: 'khẳng định'),
  VocabItem(word: 'contemplate', meaning: 'cân nhắc, suy ngẫm'),
  VocabItem(word: 'contradict', meaning: 'mâu thuẫn, phủ nhận'),
  VocabItem(word: 'derive', meaning: 'bắt nguồn, có được'),
  VocabItem(word: 'discrete', meaning: 'riêng biệt'),
  VocabItem(word: 'diverse', meaning: 'đa dạng'),
  VocabItem(word: 'exceed', meaning: 'vượt quá'),
  VocabItem(word: 'exclude', meaning: 'loại trừ'),
  VocabItem(word: 'fluctuate', meaning: 'dao động'),
  VocabItem(word: 'implement', meaning: 'thực hiện, triển khai'),
  VocabItem(word: 'implicit', meaning: 'ngầm hiểu'),
  VocabItem(word: 'induce', meaning: 'gây ra, khiến'),
  VocabItem(word: 'inequality', meaning: 'bất bình đẳng'),
  VocabItem(word: 'infer', meaning: 'suy ra'),
  VocabItem(word: 'inhibit', meaning: 'kìm hãm'),
  VocabItem(word: 'integrate', meaning: 'tích hợp'),
  VocabItem(word: 'intrinsic', meaning: 'nội tại'),
  VocabItem(word: 'modify', meaning: 'điều chỉnh'),
  VocabItem(word: 'nevertheless', meaning: 'tuy nhiên'),
  VocabItem(word: 'notwithstanding', meaning: 'mặc dù'),
  VocabItem(word: 'objective', meaning: 'khách quan, mục tiêu'),
  VocabItem(word: 'paradigm', meaning: 'mô hình, hệ hình'),
  VocabItem(word: 'persistent', meaning: 'kiên trì, dai dẳng'),
  VocabItem(word: 'plausible', meaning: 'có vẻ hợp lý'),
  VocabItem(word: 'precisely', meaning: 'một cách chính xác'),
  VocabItem(word: 'profoundly', meaning: 'một cách sâu sắc'),
  VocabItem(word: 'rationalize', meaning: 'hợp lý hóa'),
  VocabItem(word: 'reinforce', meaning: 'củng cố'),
  VocabItem(word: 'relevant', meaning: 'liên quan'),
  VocabItem(word: 'resilient', meaning: 'kiên cường, có khả năng phục hồi'),
  VocabItem(word: 'rigorous', meaning: 'nghiêm ngặt'),
  VocabItem(word: 'scrutinize', meaning: 'xem xét kỹ lưỡng'),
  VocabItem(word: 'subsequent', meaning: 'tiếp theo, sau đó'),
  VocabItem(word: 'transparent', meaning: 'minh bạch'),
  VocabItem(word: 'unprecedented', meaning: 'chưa từng có'),
  VocabItem(word: 'validate', meaning: 'xác nhận, kiểm chứng'),
  VocabItem(word: 'versatile', meaning: 'linh hoạt, đa năng'),
];

// ============================================================
// VOCABULARY PAGE
// ============================================================

class VocabularyPage extends StatefulWidget {
  final VocabType type;

  const VocabularyPage({
    super.key,
    required this.type,
  });

  @override
  State<VocabularyPage> createState() =>
      _VocabularyPageState();
}

class _VocabularyPageState
    extends State<VocabularyPage> {
  final FlutterTts _tts = FlutterTts();
  final Random _random = Random();

  List<VocabItem> _items = [];
  int _index = 0;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();

    _loadItems();
    _setupTts();
  }

  void _loadItems() {
    switch (widget.type) {
      case VocabType.easy:
        _items = List<VocabItem>.from(
          _easyWords,
        );
        break;

      case VocabType.intermediate:
        _items = List<VocabItem>.from(
          _intermediateWords,
        );
        break;

      case VocabType.advanced:
        _items = List<VocabItem>.from(
          _advancedWords,
        );
        break;
    }

    _items.shuffle(_random);

    if (_items.isEmpty) {
      _items = const [
        VocabItem(
          word: 'learn',
          meaning: 'học',
        ),
      ];
    }
  }

  Future<void> _setupTts() async {
    try {
      await _tts.setLanguage('en-US');
    } catch (_) {}

    try {
      await _tts.setSpeechRate(0.42);
    } catch (_) {}

    try {
      await _tts.setPitch(1.0);
    } catch (_) {}

    try {
      await _tts.setVolume(1.0);
    } catch (_) {}

    _tts.setStartHandler(() {
      if (!mounted) return;

      setState(() {
        _speaking = true;
      });
    });

    _tts.setCompletionHandler(() {
      if (!mounted) return;

      setState(() {
        _speaking = false;
      });
    });

    _tts.setErrorHandler((_) {
      if (!mounted) return;

      setState(() {
        _speaking = false;
      });
    });
  }

  String get _title {
    switch (widget.type) {
      case VocabType.easy:
        return '100 Easy Verbs';

      case VocabType.intermediate:
        return '250 Intermediate Words';

      case VocabType.advanced:
        return '850 Advanced Words';
    }
  }

  Future<void> _speak() async {
    if (_items.isEmpty) return;

    try {
      await _tts.stop();

      if (!mounted) return;

      setState(() {
        _speaking = true;
      });

      await _tts.speak(
        _items[_index].word,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _speaking = false;
      });
    }
  }

  Future<void> _previous() async {
    if (_items.isEmpty) return;

    try {
      await _tts.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _index--;

      if (_index < 0) {
        _index = _items.length - 1;
      }

      _speaking = false;
    });
  }

  Future<void> _next() async {
    if (_items.isEmpty) return;

    try {
      await _tts.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _index++;

      if (_index >= _items.length) {
        _index = 0;
      }

      _speaking = false;
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No vocabulary available.',
          ),
        ),
      );
    }

    final item = _items[_index];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF555555),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFDDEA),
              Color(0xFFFFEFF5),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(
                '${_index + 1} / ${_items.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888),
                ),
              ),

              const SizedBox(height: 15),

              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(0.07),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          item.word,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                Color(0xFF333333),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Container(
                          height: 1,
                          color:
                              const Color(0xFFEEEEEE),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          item.meaning,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 21,
                            height: 1.4,
                            fontWeight:
                                FontWeight.w600,
                            color:
                                Color(0xFF666666),
                          ),
                        ),

                        const SizedBox(height: 30),

                        SizedBox(
                          width: 150,
                          height: 50,
                          child:
                              ElevatedButton.icon(
                            onPressed: _speak,
                            icon: Icon(
                              _speaking
                                  ? Icons
                                      .volume_up_rounded
                                  : Icons
                                      .play_arrow_rounded,
                            ),
                            label: const Text(
                              'Play',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(
                                      0xFFE45B91),
                              foregroundColor:
                                  Colors.white,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(15),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previous,
                      style:
                          OutlinedButton.styleFrom(
                        minimumSize:
                            const Size(0, 52),
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  15),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Previous',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: _next,
                      style:
                          ElevatedButton.styleFrom(
                        minimumSize:
                            const Size(0, 52),
                        backgroundColor:
                            const Color(
                                0xFF5D74D3),
                        foregroundColor:
                            Colors.white,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  15),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Next',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PRACTICE MODEL
// ============================================================

class PracticeSentence {
  final String en;
  final String vi;

  const PracticeSentence({
    required this.en,
    required this.vi,
  });
}

class _PracticeTemplate {
  final String en;
  final String vi;
  final List<String> valuesEn;
  final List<String> valuesVi;

  const _PracticeTemplate({
    required this.en,
    required this.vi,
    required this.valuesEn,
    required this.valuesVi,
  });
}

// ============================================================
// PRACTICE PAGE
// ============================================================

class PracticePage extends StatefulWidget {
  const PracticePage({
    super.key,
  });

  @override
  State<PracticePage> createState() =>
      _PracticePageState();
}

class _PracticePageState
    extends State<PracticePage> {
  final FlutterTts _tts = FlutterTts();
  final Random _random = Random();

  List<PracticeSentence> _sentences = [];
  int _index = 0;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();

    _sentences = _buildPracticeSentences();

    if (_sentences.isEmpty) {
      _sentences = const [
        PracticeSentence(
          en: 'How are you doing today?',
          vi: 'Hôm nay bạn thế nào?',
        ),
      ];
    }

    _sentences.shuffle(_random);

    _setupTts();
  }

  Future<void> _setupTts() async {
    // Do NOT use getVoices or setVoice.
    // Some devices throw "Invalid value".

    try {
      await _tts.setLanguage('en-US');
    } catch (_) {}

    try {
      await _tts.setSpeechRate(0.42);
    } catch (_) {}

    try {
      await _tts.setPitch(1.0);
    } catch (_) {}

    try {
      await _tts.setVolume(1.0);
    } catch (_) {}

    _tts.setStartHandler(() {
      if (!mounted) return;

      setState(() {
        _speaking = true;
      });
    });

    _tts.setCompletionHandler(() {
      if (!mounted) return;

      setState(() {
        _speaking = false;
      });
    });

    _tts.setErrorHandler((_) {
      if (!mounted) return;

      setState(() {
        _speaking = false;
      });
    });
  }

  List<PracticeSentence>
      _buildPracticeSentences() {
    final templates = <_PracticeTemplate>[
      _PracticeTemplate(
        en: 'I’m going to {x}.',
        vi: 'Mình sẽ {x}.',
        valuesEn: [
          'the supermarket',
          'work',
          'the gym',
          'the office',
          'the bank',
          'the shops',
          'the park',
          'the beach',
          'the station',
          'the café',
        ],
        valuesVi: [
          'siêu thị',
          'đi làm',
          'phòng gym',
          'văn phòng',
          'ngân hàng',
          'cửa hàng',
          'công viên',
          'bãi biển',
          'ga',
          'quán cà phê',
        ],
      ),

      _PracticeTemplate(
        en: 'I’m heading to {x}.',
        vi: 'Mình đang đi đến {x}.',
        valuesEn: [
          'work',
          'the city',
          'the office',
          'the supermarket',
          'the station',
          'the gym',
          'the beach',
          'the park',
          'the airport',
          'the restaurant',
        ],
        valuesVi: [
          'chỗ làm',
          'trung tâm thành phố',
          'văn phòng',
          'siêu thị',
          'ga',
          'phòng gym',
          'bãi biển',
          'công viên',
          'sân bay',
          'nhà hàng',
        ],
      ),

      _PracticeTemplate(
        en: 'I need to {x}.',
        vi: 'Mình cần {x}.',
        valuesEn: [
          'get some rest',
          'buy some groceries',
          'make a phone call',
          'send an email',
          'finish my work',
          'clean the house',
          'do some shopping',
          'take a shower',
          'charge my phone',
          'get ready',
        ],
        valuesVi: [
          'nghỉ ngơi một chút',
          'mua ít đồ ăn',
          'gọi điện thoại',
          'gửi email',
          'hoàn thành công việc',
          'dọn nhà',
          'đi mua sắm',
          'tắm',
          'sạc điện thoại',
          'chuẩn bị xong',
        ],
      ),

      _PracticeTemplate(
        en: 'Can you {x}?',
        vi: 'Bạn có thể {x} không?',
        valuesEn: [
          'help me',
          'call me later',
          'send me the address',
          'wait for me',
          'give me a minute',
          'check this for me',
          'open the door',
          'pick me up',
          'send me a message',
          'explain it again',
        ],
        valuesVi: [
          'giúp mình không?',
          'gọi cho mình sau được không?',
          'gửi địa chỉ cho mình không?',
          'đợi mình được không?',
          'cho mình một phút được không?',
          'kiểm tra giúp mình không?',
          'mở cửa giúp mình không?',
          'đón mình được không?',
          'nhắn tin cho mình không?',
          'giải thích lại được không?',
        ],
      ),

      _PracticeTemplate(
        en: 'I’ll {x}.',
        vi: 'Mình sẽ {x}.',
        valuesEn: [
          'call you later',
          'text you tonight',
          'let you know',
          'check and get back to you',
          'send it tomorrow',
          'take care of it',
          'see you soon',
          'call you when I get home',
          'finish it tonight',
          'talk to you later',
        ],
        valuesVi: [
          'gọi cho bạn sau',
          'nhắn cho bạn tối nay',
          'cho bạn biết',
          'kiểm tra rồi báo lại cho bạn',
          'gửi nó vào ngày mai',
          'lo việc đó',
          'gặp bạn sớm',
          'gọi cho bạn khi mình về nhà',
          'hoàn thành nó tối nay',
          'nói chuyện với bạn sau',
        ],
      ),

      _PracticeTemplate(
        en: 'I’m looking forward to {x}.',
        vi: 'Mình rất mong {x}.',
        valuesEn: [
          'seeing you',
          'the weekend',
          'our trip',
          'meeting everyone',
          'the holiday',
          'trying the new restaurant',
          'spending time together',
          'your visit',
          'the event',
          'having a day off',
        ],
        valuesVi: [
          'được gặp bạn',
          'đến cuối tuần',
          'chuyến đi của chúng ta',
          'được gặp mọi người',
          'kỳ nghỉ',
          'được thử nhà hàng mới',
          'được dành thời gian cùng nhau',
          'chuyến thăm của bạn',
          'sự kiện đó',
          'có một ngày nghỉ',
        ],
      ),

      _PracticeTemplate(
        en: 'What are you doing {x}?',
        vi: '{x} bạn làm gì?',
        valuesEn: [
          'tonight',
          'tomorrow',
          'this weekend',
          'after work',
          'this evening',
          'tomorrow morning',
          'on Saturday',
          'on Sunday',
          'later',
          'after dinner',
        ],
        valuesVi: [
          'Tối nay',
          'Ngày mai',
          'Cuối tuần này',
          'Sau giờ làm',
          'Tối nay',
          'Sáng mai',
          'Thứ Bảy',
          'Chủ nhật',
          'Lát nữa',
          'Sau bữa tối',
        ],
      ),

      _PracticeTemplate(
        en: 'I usually {x}.',
        vi: 'Mình thường {x}.',
        valuesEn: [
          'wake up early',
          'go for a walk',
          'cook at home',
          'drink coffee in the morning',
          'work from home',
          'go to the gym',
          'watch TV at night',
          'read before bed',
          'have lunch at work',
          'go to bed early',
        ],
        valuesVi: [
          'dậy sớm',
          'đi bộ',
          'nấu ăn ở nhà',
          'uống cà phê vào buổi sáng',
          'làm việc ở nhà',
          'đi tập gym',
          'xem TV vào buổi tối',
          'đọc sách trước khi ngủ',
          'ăn trưa ở chỗ làm',
          'đi ngủ sớm',
        ],
      ),

      _PracticeTemplate(
        en: 'Do you want to {x}?',
        vi: 'Bạn có muốn {x} không?',
        valuesEn: [
          'grab a coffee',
          'go for a walk',
          'have dinner together',
          'watch a movie',
          'go shopping',
          'try this restaurant',
          'meet up later',
          'go to the beach',
          'have lunch together',
          'come with me',
        ],
        valuesVi: [
          'đi uống cà phê',
          'đi dạo',
          'ăn tối cùng nhau',
          'xem phim',
          'đi mua sắm',
          'thử nhà hàng này',
          'gặp nhau sau',
          'đi biển',
          'ăn trưa cùng nhau',
          'đi cùng mình',
        ],
      ),

      _PracticeTemplate(
        en: 'I feel {x} today.',
        vi: 'Hôm nay mình cảm thấy {x}.',
        valuesEn: [
          'really good',
          'a little tired',
          'happy',
          'excited',
          'relaxed',
          'busy',
          'a bit stressed',
          'much better',
          'great',
          'ready to go',
        ],
        valuesVi: [
          'rất vui',
          'hơi mệt',
          'hạnh phúc',
          'háo hức',
          'thư giãn',
          'bận rộn',
          'hơi căng thẳng',
          'khá hơn nhiều',
          'rất tuyệt',
          'sẵn sàng đi rồi',
        ],
      ),
    ];

    final result = <PracticeSentence>[];

    for (final template in templates) {
      final count = min(
        template.valuesEn.length,
        template.valuesVi.length,
      );

      for (int i = 0; i < count; i++) {
        final english =
            template.en.replaceFirst(
          '{x}',
          template.valuesEn[i],
        );

        final vietnamese =
            template.vi.replaceFirst(
          '{x}',
          template.valuesVi[i],
        );

        result.add(
          PracticeSentence(
            en: english,
            vi: vietnamese,
          ),
        );
      }
    }

    return result;
  }

  Future<void> _speak() async {
    if (_sentences.isEmpty) return;

    try {
      await _tts.stop();

      if (!mounted) return;

      setState(() {
        _speaking = true;
      });

      await _tts.speak(
        _sentences[_index].en,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _speaking = false;
      });
    }
  }

  Future<void> _previous() async {
    if (_sentences.isEmpty) return;

    try {
      await _tts.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _index--;

      if (_index < 0) {
        _index = _sentences.length - 1;
      }

      _speaking = false;
    });
  }

  Future<void> _next() async {
    if (_sentences.isEmpty) return;

    try {
      await _tts.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _index++;

      if (_index >= _sentences.length) {
        _index = 0;
      }

      _speaking = false;
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sentences.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No practice sentences available.',
          ),
        ),
      );
    }

    final sentence = _sentences[_index];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF555555),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '1,000 Practice',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFDDEA),
              Color(0xFFFFEFF5),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              // COUNTER
              Text(
                '${_index + 1} / ${_sentences.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888),
                ),
              ),

              const SizedBox(height: 15),

              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.fromLTRB(
                      22,
                      30,
                      22,
                      30,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(0.07),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  const Color(
                                      0xFFFFE4EF),
                              borderRadius:
                                  BorderRadius.circular(
                                      20),
                            ),
                            child: const Text(
                              'LISTEN & REPEAT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w800,
                                color:
                                    Color(0xFFE45B91),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Text(
                            sentence.en,
                            textAlign:
                                TextAlign.center,
                            style: const TextStyle(
                              fontSize: 27,
                              height: 1.35,
                              fontWeight:
                                  FontWeight.w800,
                              color:
                                  Color(0xFF333333),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Container(
                            width: 70,
                            height: 1,
                            color:
                                const Color(0xFFEAEAEA),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            sentence.vi,
                            textAlign:
                                TextAlign.center,
                            style: const TextStyle(
                              fontSize: 19,
                              height: 1.45,
                              fontWeight:
                                  FontWeight.w600,
                              color:
                                  Color(0xFF666666),
                            ),
                          ),

                          const SizedBox(height: 30),

                          SizedBox(
                            width: 160,
                            height: 53,
                            child:
                                ElevatedButton.icon(
                              onPressed: _speak,
                              icon: Icon(
                                _speaking
                                    ? Icons
                                        .volume_up_rounded
                                    : Icons
                                        .play_arrow_rounded,
                              ),
                              label: const Text(
                                'Play',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    const Color(
                                        0xFFE45B91),
                                foregroundColor:
                                    Colors.white,
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(15),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 17),

                          const Text(
                            'Listen → Repeat aloud',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // PREVIOUS / NEXT
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previous,
                      style:
                          OutlinedButton.styleFrom(
                        minimumSize:
                            const Size(0, 52),
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  15),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Previous',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: _next,
                      style:
                          ElevatedButton.styleFrom(
                        minimumSize:
                            const Size(0, 52),
                        backgroundColor:
                            const Color(
                                0xFF5D74D3),
                        foregroundColor:
                            Colors.white,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  15),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Next',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
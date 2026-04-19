import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'top_picks_page.dart';

import 'upgrade_vip_page.dart';
import 'who_likes_me_page.dart';


class LikesAndViewsHubPage extends StatelessWidget {
  final String languageCode;

  const LikesAndViewsHubPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  Future<bool> _isVipUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final data = doc.data() ?? {};
    return data['isVip'] == true || data['vipUnlocked'] == true;
  }

  Future<String?> _resolveImageUrl(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return null;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    if (value.startsWith('gs://')) {
      try {
        return await FirebaseStorage.instance.refFromURL(value).getDownloadURL();
      } catch (_) {
        return null;
      }
    }

    try {
      return await FirebaseStorage.instance.ref(value).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _loadLikesPreviewUsers() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('likedBy')
          .orderBy('timestamp', descending: true)
          .limit(2)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> _loadLikesCount() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 0;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('likedBy')
          .get();

      return snapshot.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _loadViewsCount() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 0;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('viewedBy')
          .get();

      return snapshot.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _openLockedPage(
    BuildContext context, {
    required String type,
  }) async {
    final isVip = await _isVipUser();

    if (!context.mounted) return;

    if (!isVip) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UpgradeVipPage(
            languageCode: languageCode,
            onPurchaseSuccess: () async {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
        ),
      );
      return;
    }

    if (type == 'likes') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WhoLikesMePage(languageCode: languageCode),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TopPicksPage(languageCode: languageCode),
        ),
      );
    }
  }

  Widget _buildBlurredAvatar(
    String rawPhoto, {
    double size = 40,
  }) {
    final raw = rawPhoto.trim();

    if (raw.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          color: Colors.grey.shade300,
          child: const Icon(Icons.person, color: Colors.white, size: 18),
        ),
      );
    }

    return FutureBuilder<String?>(
      future: _resolveImageUrl(raw),
      builder: (context, snapshot) {
        final resolvedUrl = snapshot.data;

        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Stack(
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  image: resolvedUrl != null && resolvedUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(resolvedUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (resolvedUrl == null || resolvedUrl.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white, size: 18)
                    : null,
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLikesPreview() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadLikesPreviewUsers(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];

        final firstPhoto = items.isNotEmpty
            ? (items[0]['photoUrl'] ??
                    items[0]['mainPhotoUrl'] ??
                    items[0]['userPhotoUrl'] ??
                    '')
                .toString()
            : '';

        final secondPhoto = items.length > 1
            ? (items[1]['photoUrl'] ??
                    items[1]['mainPhotoUrl'] ??
                    items[1]['userPhotoUrl'] ??
                    '')
                .toString()
            : '';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBlurredAvatar(firstPhoto, size: 40),
            Transform.translate(
              offset: const Offset(-8, 0),
              child: _buildBlurredAvatar(secondPhoto, size: 40),
            ),
            const SizedBox(width: 2),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.black38,
                size: 20,
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatViewsBadge(int count) {
  if (count > 99) return '99+';
  return '$count';
}
  Widget _buildViewsPreview() {
  return FutureBuilder<int>(
    future: _loadViewsCount(),
    builder: (context, snapshot) {
      final count = snapshot.data ?? 0;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF5A6E),
                    Color(0xFFFF6B57),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B57).withOpacity(0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                _formatViewsBadge(count),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.black38,
              size: 20,
            ),
          ),
        ],
      );
    },
  );
}

  Widget _buildLikesSubtitle() {
  return FutureBuilder<int>(
    future: _loadLikesCount(),
    builder: (context, snapshot) {
      final count = snapshot.data ?? 0;

      // 👉 từ 0 → 10: KHÔNG hiện số
      if (count <= 10) {
        return Text(
          _tr(
            'Có người đã thích bạn 👀',
            'Someone liked you 👀',
          ),
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black45,
            fontWeight: FontWeight.w500,
          ),
        );
      }

      // 👉 > 10: hiện số thật
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFFE2A11A),
            ),
          ),
          Text(
            isVi ? 'người thích bạn' : 'people like you',
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    },
  );
}

  Widget _buildViewsSubtitle() {
    return Text(
      isVi
          ? 'Gợi ý tìm người phù hợp với tiêu chí của bạn'
          : 'Suggestions to find people who match your criteria',
  
      style: const TextStyle(
        fontSize: 15,
        height: 1.4,
        color: Colors.black45,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8A2F6A)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5F2A4D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTile({
    required IconData icon,
    required String title,
    required Widget subtitle,
    required Widget trailing,
    required VoidCallback onTap,
    required List<Color> iconGradient,
    required Color iconColor,
    bool showPremiumTag = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        splashColor: const Color(0xFFF4A261).withOpacity(0.12),
        highlightColor: const Color(0xFFF4A261).withOpacity(0.05),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: iconGradient),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient.last.withOpacity(0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        height: 1.15,
                      ),
                    ),
                    if (showPremiumTag) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFD76A),
                              Color(0xFFE9A91A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    subtitle,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopPremiumBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFE6F1),
            Color(0xFFFFF6E9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDA8AB0).withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD76A),
                      Color(0xFFE9A91A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _tr('Vietlove VIP', 'Vietlove VIP'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5A2946),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _tr(
              'Mở khóa danh sách ai đã thích và ai đã xem hồ sơ của bạn.',
              'Unlock the list of people who liked you and viewed your profile.',
            ),
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Color(0xFF6F5B67),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeaturePill(
                icon: Icons.favorite_rounded,
                text: _tr('Xem lượt thích', 'See likes'),
              ),
              _buildFeaturePill(
                icon: Icons.remove_red_eye_rounded,
                text: _tr('Xem lượt xem', 'See views'),
              ),
              _buildFeaturePill(
                icon: Icons.lock_open_rounded,
                text: _tr('Mở khóa ngay', 'Unlock now'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4F1),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          _tr('Nâng cấp VIP', 'Upgrade VIP'),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          _buildTopPremiumBanner(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _tr('Dịch vụ khác', 'More services'),
              style: const TextStyle(
                fontSize: 19,
                color: Colors.black38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.grey.shade100,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildServiceTile(
                  icon: Icons.favorite_outline_rounded,
                  title: isVi ? 'Ai thích tôi' : 'See Who Likes Me',
                  subtitle: _buildLikesSubtitle(),
                  trailing: _buildLikesPreview(),
                  onTap: () => _openLockedPage(context, type: 'likes'),
                  iconGradient: const [
                    Color(0xFFFFF1E7),
                    Color(0xFFFFE1CC),
                  ],
                  iconColor: const Color(0xFFF2A35A),
                  showPremiumTag: true,
                ),
                Divider(
                  color: Colors.grey.shade200,
                  height: 1,
                  thickness: 1,
                ),
                _buildServiceTile(
                  icon: Icons.remove_red_eye_outlined,
                  title: isVi ? 'Gợi ý cho bạn' : 'Top Picks',
                  subtitle: _buildViewsSubtitle(),
                  trailing: _buildViewsPreview(),
                  onTap: () => _openLockedPage(context, type: 'views'),
                  iconGradient: const [
                    Color(0xFFFFEEF0),
                    Color(0xFFFFD9DE),
                  ],
                  iconColor: const Color(0xFFFF6B74),
                  showPremiumTag: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
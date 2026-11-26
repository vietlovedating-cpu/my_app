import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class MoreAboutMeDetail {
  final IconData icon;
  final String label;
  final String value;

  const MoreAboutMeDetail({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class MoreAboutMePage extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String languageCode;
  final String aboutMe;
  final List<MoreAboutMeDetail> details;
  final String avatarUrl;
  final String location;

  // These callbacks reuse the existing HomePage action flows.
  final Future<void> Function()? onLike;
  final Future<void> Function()? onPass;
  final Future<void> Function()? onSendMessage;

  const MoreAboutMePage({
    super.key,
    required this.profile,
    required this.languageCode,
    required this.aboutMe,
    required this.details,
    required this.avatarUrl,
    required this.location,
    this.onLike,
    this.onPass,
    this.onSendMessage,
  });

  bool get _isVi => languageCode == 'vi';
  String _tr(String vi, String en) => _isVi ? vi : en;

  @override
  Widget build(BuildContext context) {
   final firstName = (profile['firstName'] ?? '')
    .toString()
    .trim()
    .split(' ')
    .where((word) => word.isNotEmpty)
    .map((word) =>
        '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
    .join(' ');
    final age = (profile['age'] ?? '').toString().trim();
    final displayName =
        firstName.isEmpty ? _tr('Người dùng', 'User') : firstName;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8FB),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF8A2F6A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _tr('Thêm về tôi', 'More About Me'),
          style: const TextStyle(
            color: Color(0xFF8A2F6A),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(displayName, age),
            if (aboutMe.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionHeading(
                Icons.person_outline_rounded,
                _tr('Về tôi', 'About Me'),
                _tr('Một chút về con người này', 'A little more about this person'),
              ),
              const SizedBox(height: 11),
              _aboutCard(),
            ],
            if (details.isNotEmpty) ...[
              const SizedBox(height: 21),
              _sectionHeading(
                Icons.favorite_border_rounded,
                _tr('Tìm hiểu thêm', 'Get to Know Me'),
                _tr('Những thông tin đã chia sẻ', 'Details this person has shared'),
              ),
              const SizedBox(height: 11),
              _detailsWrap(),
            ],
           
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8FB),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9B426C).withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onSendMessage == null
                  ? null
                  : () async {
                      await onSendMessage!.call();
                    },
              icon: const Icon(Icons.send_rounded, size: 19),
              label: Text(
                _tr('Gửi tin nhắn', 'Send a Message'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC3D7A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.pink.shade100,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String name, String age) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE6F0),
            Color(0xFFFFF4F8),
            Color(0xFFF9E5F0),
          ],
        ),
        border: Border.all(color: const Color(0xFFFFD6E5)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFDC6B9B),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 91,
                    height: 91,
                    child: avatarUrl.trim().isEmpty
                        ? _avatarPlaceholder()
                        : CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 300,
                            placeholder: (_, __) => _avatarPlaceholder(),
                            errorWidget: (_, __, ___) => _avatarPlaceholder(),
                          ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -1,
                child: _roundAction(
                  icon: Icons.favorite_rounded,
                  background: const Color(0xFFE84F83),
                  foreground: Colors.white,
                  onTap: onLike,
                  size: 34,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  age.isEmpty ? name : '$name, $age',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF812D5C),
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (location.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFE45C8B),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            color: Color(0xFF684C5B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 5),
          _roundAction(
            icon: Icons.close_rounded,
            background: Colors.white,
            foreground: const Color(0xFF8D536B),
            onTap: onPass,
            size: 39,
          ),
        ],
      ),
    );
  }

  Widget _roundAction({
    required IconData icon,
    required Color background,
    required Color foreground,
    required Future<void> Function()? onTap,
    required double size,
  }) {
    return Material(
      color: background,
      elevation: 3,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap == null
            ? null
            : () async {
                await onTap.call();
              },
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: foreground, size: size * 0.58),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: const Color(0xFFF7D8E6),
      child: const Icon(
        Icons.person_rounded,
        size: 48,
        color: Color(0xFFB65A83),
      ),
    );
  }

  Widget _sectionHeading(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE2EC),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: const Color(0xFFE65383), size: 22),
        ),
        const SizedBox(width: 10),
        Container(
          width: 3,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE85B89),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF7F2D5B),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF8F7B86),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _aboutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFFFE0EA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB94C7E).withOpacity(0.07),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '“',
            style: TextStyle(
              color: Color(0xFFF18A9E),
              fontSize: 32,
              height: 0.9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              aboutMe,
              softWrap: true,
              style: const TextStyle(
                color: Color(0xFF463B44),
                fontSize: 14,
                height: 1.48,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsWrap() {
    // Age is already displayed beside the profile name/avatar.
    // Keep the remaining details in the original order.
    final visibleDetails = details.where((item) {
      final label = item.label.toLowerCase().trim();
      return label != 'tuổi' && label != 'age';
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final halfWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: visibleDetails.map((item) {
            final label = item.label.toLowerCase().trim();

            // Long multi-choice fields need a full-width card so their
            // values can wrap naturally without looking cramped.
            final isFullWidth =
                label.contains('mục tiêu hẹn hò') ||
                label.contains('relationship goal') ||
                label.contains('thu nhập năm') ||
                label.contains('annual income') ||
                label.contains('yearly income');

            return SizedBox(
              width: isFullWidth ? constraints.maxWidth : halfWidth,
              child: _detailCard(item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _detailCard(MoreAboutMeDetail item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE2ED)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB94C7E).withOpacity(0.045),
            blurRadius: 11,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE7EF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              color: const Color(0xFFE65A87),
              size: 21,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  softWrap: true,
                  style: const TextStyle(
                    color: Color(0xFF806A77),
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                if (item.label.toLowerCase().contains('mục tiêu hẹn hò') ||
    item.label.toLowerCase().contains('relationship goal')) ...[
  ...item.value
      .split(RegExp(r'\s*[,;\n]\s*'))
      .where((choice) => choice.trim().isNotEmpty)
      .map(
        (choice) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '• ',
                style: TextStyle(
                  color: Color(0xFFE65A87),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  choice.trim(),
                  softWrap: true,
                  style: const TextStyle(
                    color: Color(0xFF3F3540),
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
] else
  Text(
    item.value,
    softWrap: true,
    style: const TextStyle(
      color: Color(0xFF3F3540),
      fontSize: 13.5,
      height: 1.3,
      fontWeight: FontWeight.w800,
    ),
  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

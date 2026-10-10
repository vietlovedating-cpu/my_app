import 'package:flutter/material.dart';

/// Welcome and community-rules page shown before entering a group chat.
///
/// To connect this page to the existing group chat, pass an [onAgree] callback
/// that navigates to the intended chat page. Keeping navigation in the caller
/// avoids coupling this page to a specific group-chat constructor.
class GroupChatWelcomePage extends StatefulWidget {
  final String languageCode;
  final VoidCallback onAgree;

  const GroupChatWelcomePage({
    super.key,
    required this.languageCode,
    required this.onAgree,
  });

  @override
  State<GroupChatWelcomePage> createState() => _GroupChatWelcomePageState();
}

class _GroupChatWelcomePageState extends State<GroupChatWelcomePage> {
  bool _acceptedRules = false;

  bool get _isVi => widget.languageCode.toLowerCase().startsWith('vi');

  String _tr(String vi, String en) => _isVi ? vi : en;

  static const Color _purple = Color(0xFF7A2E6E);
  static const Color _pink = Color(0xFFE45B91);
  static const Color _pageBackground = Color(0xFFFFF8FB);

  void _continueToChat() {
    if (!_acceptedRules) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Vui lòng đồng ý với nội quy trước khi vào nhóm.',
              'Please agree to the community guidelines before joining.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    widget.onAgree();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _purple,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _tr('Chào mừng', 'Welcome'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
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
              Color(0xFFFFE5F0),
              Color(0xFFFFF4F8),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  children: [
                    _buildWelcomeHeader(),
                    const SizedBox(height: 22),
                    _buildGuidelinesCard(),
                    const SizedBox(height: 14),
                    _buildThreeStrikeCard(),
                    const SizedBox(height: 12),
                    Text(
                      _tr(
                        'Hệ thống tự động có thể nhận diện nhầm một số từ. Các trường hợp vi phạm nên được xử lý theo quy tắc của nhóm và có thể cần xem xét lại.',
                        'Automated filters can sometimes make mistakes. Reported violations should be handled consistently with the group rules, with a review option where appropriate.',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildAgreement(),
                  ],
                ),
              ),
              _buildBottomAction(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 25, 22, 23),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _purple.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD9E8), Color(0xFFE8DFFF)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: _purple,
              size: 39,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            _tr(
              'Chào mừng đến với Practice English Together!',
              'Welcome to Practice English Together!',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _purple,
              fontSize: 23,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _tr(
              'Cùng luyện tiếng Anh, chia sẻ ý tưởng và kết bạn trong một môi trường thân thiện.',
              'Practise English, share ideas and make friends in a friendly, welcoming space.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPill(Icons.language_rounded, _tr('Luyện tiếng Anh', 'Practise English')),
              _buildPill(Icons.people_alt_rounded, _tr('Kết nối', 'Connect')),
              _buildPill(Icons.favorite_rounded, _tr('Tôn trọng', 'Respect')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _pink),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _purple,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelinesCard() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E7FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  color: _purple,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _tr('Nội quy cộng đồng', 'Community Guidelines'),
                  style: const TextStyle(
                    color: _purple,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _guidelineRow(
            icon: Icons.handshake_rounded,
            title: _tr('Tôn trọng mọi người', 'Be respectful'),
            description: _tr(
              'Tôn trọng văn hóa, ý kiến và sự khác biệt của mỗi thành viên.',
              'Respect every member’s culture, opinions and differences.',
            ),
          ),
          const SizedBox(height: 17),
          _guidelineRow(
            icon: Icons.chat_bubble_outline_rounded,
            title: _tr('Ngôn từ phù hợp', 'Keep language appropriate'),
            description: _tr(
              'Không xúc phạm, quấy rối, phân biệt đối xử hoặc gửi nội dung khiêu dâm.',
              'No abusive, harassing, discriminatory or sexually explicit messages.',
            ),
          ),
          const SizedBox(height: 17),
          _guidelineRow(
            icon: Icons.shield_outlined,
            title: _tr('Giữ nhóm an toàn', 'Help keep the group safe'),
            description: _tr(
              'Không đe dọa, bắt nạt hoặc cố tình làm người khác khó chịu.',
              'Do not threaten, bully or deliberately make others feel unsafe.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _guidelineRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F6),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: _pink, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF38313A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThreeStrikeCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF5D1CD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.gpp_maybe_rounded,
            color: Color(0xFFC34B45),
            size: 27,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr('Quy tắc 3 lần vi phạm', 'Three-strike rule'),
                  style: const TextStyle(
                    color: Color(0xFF9E302B),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _tr(
                    'Lần 1: cảnh báo. Lần 2: cảnh báo cuối. Lần 3: có thể bị loại khỏi nhóm nếu hệ thống xác nhận vi phạm theo nội quy.',
                    '1st: warning. 2nd: final warning. 3rd: removal from the group may follow if the violation is confirmed under the group rules.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF713B38),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreement() {
    return InkWell(
      onTap: () => setState(() => _acceptedRules = !_acceptedRules),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        decoration: BoxDecoration(
          color: _acceptedRules ? const Color(0xFFF3EAF5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _acceptedRules ? _purple : const Color(0xFFE5DDE5),
            width: _acceptedRules ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _acceptedRules,
              activeColor: _purple,
              onChanged: (value) {
                setState(() => _acceptedRules = value ?? false);
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 11),
                child: Text(
                  _tr(
                    'Tôi đã đọc và đồng ý tuân thủ nội quy của nhóm.',
                    'I have read and agree to follow the community guidelines.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF403744),
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 13, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _continueToChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFD8C8D7),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 21),
                const SizedBox(width: 9),
                Text(
                  _tr('ĐỒNG Ý VÀ VÀO NHÓM', 'AGREE & JOIN'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.25,
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(Icons.arrow_forward_rounded, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

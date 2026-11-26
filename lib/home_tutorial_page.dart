import 'package:flutter/material.dart';

class HomeTutorialPage extends StatefulWidget {
  final String languageCode;

  const HomeTutorialPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<HomeTutorialPage> createState() => _HomeTutorialPageState();
}

class _HomeTutorialPageState extends State<HomeTutorialPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _photoLikeKey = GlobalKey();
  final GlobalKey _promptLikeKey = GlobalKey();
  final GlobalKey _moreAboutKey = GlobalKey();
  final GlobalKey _sendMessageKey = GlobalKey();

  int _tutorialStep = 0;
  bool _showTutorial = true;
  late final AnimationController _pulseController;

  bool get isVi => widget.languageCode == 'vi';

  final Map<String, dynamic> tutorialProfile = {
    'uid': 'tutorial_nana_only',
    'isTutorialProfile': true,

    'firstName': 'Nana',
    'lastName': 'Tran',
    'fullName': 'Nana Tran',
    'age': 25,

    'gender': 'female',
    'datingPreference': 'male',

    'address': 'Wiley Park',
    'selectedState': 'New South Wales (NSW)',
    'selectedStateKey': 'NSW',
    'selectedCountry': 'Australia',

    'photoVerified': true,
    'photoVerificationStatus': 'approved',

    'occupation': 'Marketing Specialist',
    'education': 'Bachelor Degree',
    'highestEducation': 'Bachelor Degree',

    'heightCm': 165,
    'height': '165 cm',

    'annualIncome': '60,000–80,000 AUD',
    'maritalStatus': 'Single',
    'haveChildren': 'No',

    'religion': 'Buddhist',
    'residentStatus': 'Citizen',

    'smoking': 'No',
    'drinking': 'Socially',

    'relationshipGoals': [
      'Serious Relationship',
      'Long-term Partner',
    ],

    'countryOfBirth': 'Vietnam',
    'vietnamBirthProvince': 'Ho Chi Minh City',

    'photos': [
      'assets/tutorial/nana1.png',
      'assets/tutorial/nana2.png',
      'assets/tutorial/nana3.png',
      'assets/tutorial/nana4.png',
      'assets/tutorial/nana5.png',
    ],

    'prompt1Question': 'My perfect weekend looks like...',
    'prompt1Answer':
        'Breakfast, a walk by the beach and coffee together.',

    'prompt2Question': 'The quickest way to make me smile...',
    'prompt2Answer':
        'Make me laugh and bring me a delicious iced coffee.',

    'prompt3Question': 'We will get along if...',
    'prompt3Answer':
        'You are kind, honest, positive and care about family.',
  };


  final List<Map<String, String>> _stepsVi = const [
    {
      'title': 'Chào mừng đến với Kết nối VietLove',
      'description':
          'Đây là nơi bạn khám phá hồ sơ và tìm hiểu những người có thể phù hợp với mình. Hãy cùng xem cách tương tác nhé.',
    },
    {
      'title': 'Thích và bình luận trên ảnh',
      'description':
          'Khi bạn nhấn biểu tượng trái tim trên ảnh, bạn sẽ gửi một lượt Thích đến người đó. Khi bạn bình luận trên ảnh của một người, hệ thống cũng đồng thời gửi một lượt Thích đến người đó. Người đó sẽ biết bạn đã Thích ảnh và có thể xem chính xác nội dung bình luận bạn đã viết trên ảnh của họ.',
    },
    {
      'title': 'Thích câu trả lời Prompt',
      'description':
          'Bạn cũng có thể nhấn Thích ngay trên câu trả lời Prompt mà bạn yêu thích. Nếu người đó Thích lại bạn, hai bạn sẽ Match.',
    },
    {
      'title': 'Thêm về tôi',
      'description':
          'Nhấn vào mục “Thêm về tôi” trên hồ sơ để xem thông tin chi tiết mà người đó đã chia sẻ, như nơi sống, nơi sinh, chiều cao, học vấn và nghề nghiệp.',
    },
    {
      'title': 'Gửi tin nhắn',
      'description':
          'Nhấn “Gửi tin nhắn” để gửi tin nhắn cho người đó. Người nhận sẽ nhận được tin nhắn ngay lập tức.',
    },
  ];

  final List<Map<String, String>> _stepsEn = const [
    {
      'title': 'Welcome to VietLove Connections',
      'description':
          'This is where you discover profiles and get to know people who may be right for you. Let’s see how to interact.',
    },
    {
      'title': 'Like and comment on a photo',
      'description':
          'Tap the heart on a photo to send that person a Like. When you comment on someone’s photo, the system also sends that person a Like. They will know you Liked their photo and can see exactly what you wrote in your comment.',
    },
    {
      'title': 'Like a Prompt answer',
      'description':
          'You can also tap Like on a Prompt answer you enjoy. If that person Likes you back, you will Match.',
    },
    {
      'title': 'More About Me',
      'description':
          'Tap “More About Me” on a profile to see the details that person has shared, such as location, birthplace, height, education and occupation.',
    },
    {
      'title': 'Send a message',
      'description':
          'Tap “Send a Message” to message that person. They will receive your message straight away.',
    },
  ];

  List<Map<String, String>> get _steps => isVi ? _stepsVi : _stepsEn;

  List<String> get photos =>
      List<String>.from(tutorialProfile['photos'] as List<dynamic>);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _goToStep(int step) async {
    if (!mounted) return;
    setState(() => _tutorialStep = step);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final keys = [
      _homeKey,
      _photoLikeKey,
      _promptLikeKey,
      _moreAboutKey,
      _sendMessageKey,
    ];
    final context = keys[step].currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        alignment: 0.12,
      );
    }
  }

  Future<void> _nextStep() async {
    if (_tutorialStep == _steps.length - 1) {
      _finishTutorial();
    } else {
      await _goToStep(_tutorialStep + 1);
    }
  }

  Future<void> _previousStep() async {
    if (_tutorialStep > 0) await _goToStep(_tutorialStep - 1);
  }

  void _finishTutorial() {
    if (mounted) Navigator.pop(context, true);
  }

  void _hideTutorialCard() {
    setState(() => _showTutorial = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8FB),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: _finishTutorial,
          icon: const Icon(Icons.close_rounded, color: Color(0xFFCC3D7A)),
        ),
        title: Text(
          isVi ? 'Hướng dẫn VietLove' : 'VietLove Quick Guide',
          style: const TextStyle(
            color: Color(0xFF812D5C),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _finishTutorial,
            child: Text(
              isVi ? 'Bỏ qua' : 'Skip',
              style: const TextStyle(
                color: Color(0xFFCC3D7A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              _showTutorial ? 220 : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHomeHeader(),
                const SizedBox(height: 14),
                Container(
                  key: _homeKey,
                  child: _buildIntroCard(),
                ),
                const SizedBox(height: 22),
                _buildSectionTitle(isVi ? 'Khám phá hồ sơ' : 'Discover profiles'),
                const SizedBox(height: 12),
                Container(
                  key: _photoLikeKey,
                  child: _buildPhotoPost(),
                ),
                const SizedBox(height: 18),
                Container(
                  key: _promptLikeKey,
                  child: _buildPromptCard(),
                ),
                const SizedBox(height: 28),
                _buildSectionTitle(
                  isVi ? 'Xem hồ sơ của Nana' : 'View Nana’s profile',
                ),
                const SizedBox(height: 12),
                _buildProfilePreview(),
                const SizedBox(height: 14),
                Container(
                  key: _moreAboutKey,
                  child: _buildMoreAboutPreview(),
                ),
                const SizedBox(height: 18),
                Container(
                  key: _sendMessageKey,
                  child: _buildSendMessagePreview(),
                ),
                const SizedBox(height: 20),
                _buildBottomNavigationPreview(),
              ],
            ),
          ),
          if (_showTutorial) _buildTutorialPanel(),
        ],
      ),
    );
  }

  Widget _buildHomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE4EF), Color(0xFFFFF7FA)],
        ),
        border: Border.all(color: const Color(0xFFFFD5E5)),
      ),
      child: Column(
        children: [
          Text(
            isVi ? 'Kết nối VietLove' : 'VietLove Connections',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF812D5C),
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isVi ? 'Khám phá • Kết nối • Trò chuyện' : 'Discover • Connect • Chat',
            style: const TextStyle(
              color: Color(0xFFB34B7B),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: Color(0xFFE65383), size: 28),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              isVi
                  ? 'Khám phá ảnh và những câu trả lời thú vị của mọi người.'
                  : 'Discover people’s photos and interesting Prompt answers.',
              style: const TextStyle(
                color: Color(0xFF594451),
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPost() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 0.92,
                child: Image.asset(
                  photos[0],
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imageFallback(),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 14,
                child: _heartButton(highlighted: _tutorialStep == 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _actionPill(
                icon: Icons.thumb_up_alt_rounded,
                label: isVi ? 'Thích ảnh' : 'Like photo',
                filled: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionPill(
                icon: Icons.chat_bubble_outline_rounded,
                label: isVi ? 'Bình luận' : 'Comment',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isVi ? 'Ảnh của Nana (hồ sơ mẫu)' : 'Nana’s photo (sample profile)',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPromptCard() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: const Color(0xFFFFD9E7), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB94C7E).withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVi ? 'Bạn bè thường nói tôi là người...' : 'My friends describe me as...',
                style: const TextStyle(
                  color: Color(0xFF812D5C),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      isVi ? 'hoạt bát và lanh lợi' : 'energetic and quick-witted',
                      style: const TextStyle(
                        color: Color(0xFF403640),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _heartButton(highlighted: _tutorialStep == 2, size: 58),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _actionPill(
                icon: Icons.thumb_up_alt_outlined,
                label: isVi ? 'Thích' : 'Like',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionPill(
                icon: Icons.chat_bubble_outline_rounded,
                label: isVi ? 'Bình luận' : 'Comment',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfilePreview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              photos[0],
              width: 82,
              height: 82,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _imageFallback(),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVi ? 'Nana, 25' : 'Nana, 25',
                  style: const TextStyle(
                    color: Color(0xFF812D5C),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Wiley Park, NSW, Australia',
                  style: TextStyle(
                    color: Color(0xFF6B5964),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded, color: Colors.blue, size: 22),
        ],
      ),
    );
  }

  Widget _buildMoreAboutPreview() {
    final details = [
      (Icons.location_on_outlined, isVi ? 'Nơi sống' : 'Location', 'Wiley Park, NSW, Australia'),
      (Icons.public_rounded, isVi ? 'Nơi sinh' : 'Birthplace', 'Vietnam • Ho Chi Minh City'),
      (Icons.person_outline_rounded, isVi ? 'Giới tính' : 'Gender', isVi ? 'Nữ' : 'Female'),
      (Icons.auto_awesome_rounded, isVi ? 'Tôn giáo' : 'Religion', isVi ? 'Không tôn giáo' : 'No religion'),
      (Icons.height_rounded, isVi ? 'Chiều cao' : 'Height', '165 cm'),
      (Icons.school_outlined, isVi ? 'Bằng cấp' : 'Education', isVi ? 'Đại học' : 'Bachelor Degree'),
      (Icons.work_outline_rounded, isVi ? 'Nghề nghiệp' : 'Occupation', isVi ? 'Marketing' : 'Marketing Specialist'),
    ];

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = _tutorialStep == 3 ? 0.10 + _pulseController.value * 0.12 : 0.0;
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEDF4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _tutorialStep == 3
                  ? Color.lerp(const Color(0xFFFFD4E4), const Color(0xFFE65383), _pulseController.value)!
                  : const Color(0xFFFFD8E7),
              width: _tutorialStep == 3 ? 2.5 : 1.2,
            ),
            boxShadow: [
              if (_tutorialStep == 3)
                BoxShadow(
                  color: const Color(0xFFE65383).withOpacity(glow),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_border_rounded, color: Color(0xFFE65383)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      isVi ? 'Thêm về tôi' : 'More About Me',
                      style: const TextStyle(
                        color: Color(0xFF812D5C),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.touch_app_rounded, color: Color(0xFFE65383)),
                ],
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isVi ? 'Chạm để xem thêm về tôi' : 'Tap to learn more about me',
                  style: const TextStyle(color: Color(0xFF8F7B86), fontSize: 12),
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: details.map((item) {
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 76) / 2,
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: const Color(0xFFFFE0EA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(item.$1, color: const Color(0xFFE65A87), size: 19),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.$2, style: const TextStyle(color: Color(0xFF806A77), fontSize: 11)),
                                const SizedBox(height: 3),
                                Text(item.$3, style: const TextStyle(color: Color(0xFF3F3540), fontSize: 12, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSendMessagePreview() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final highlighted = _tutorialStep == 4;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: highlighted
                  ? Color.lerp(const Color(0xFFFFD5E5), const Color(0xFFE65383), _pulseController.value)!
                  : const Color(0xFFFFD8E7),
              width: highlighted ? 2.5 : 1.2,
            ),
            boxShadow: [
              if (highlighted)
                BoxShadow(
                  color: const Color(0xFFE65383).withOpacity(0.18 + _pulseController.value * 0.12),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: SizedBox(
            height: 58,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.send_rounded),
              label: Text(
                isVi ? 'Gửi tin nhắn' : 'Send a Message',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC3D7A),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationPreview() {
    final labels = isVi
        ? ['Home', 'Message', 'Match', 'Activities', 'Upgrade', 'Me']
        : ['Home', 'Message', 'Match', 'Activities', 'Upgrade', 'Me'];
    final icons = [
      Icons.home_rounded,
      Icons.chat_rounded,
      Icons.favorite_rounded,
      Icons.sports_esports_rounded,
      Icons.workspace_premium_rounded,
      Icons.person_rounded,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE0EA)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(labels.length, (i) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icons[i], color: i == 0 ? const Color(0xFF6677C9) : Colors.grey, size: 22),
              const SizedBox(height: 4),
              Text(labels[i], style: TextStyle(color: i == 0 ? const Color(0xFF6677C9) : Colors.grey, fontSize: 10)),
            ],
          );
        }),
      ),
    );
  }

  Widget _heartButton({required bool highlighted, double size = 62}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = highlighted ? 1 + _pulseController.value * 0.08 : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: highlighted ? Border.all(color: const Color(0xFFE65383), width: 2.5) : null,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9B426C).withOpacity(highlighted ? 0.24 : 0.12),
                  blurRadius: highlighted ? 18 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.favorite_rounded, color: const Color(0xFFCC3D7A), size: size * 0.48),
          ),
        );
      },
    );
  }

  Widget _actionPill({
    required IconData icon,
    required String label,
    bool filled = false,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFFFE6F0) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD8E7), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFCC3D7A), size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Color(0xFFCC3D7A), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF812D5C),
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: const Color(0xFFF7D8E6),
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded, color: Color(0xFFB65A83), size: 54),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD8E7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB94C7E).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _buildTutorialPanel() {
    final step = _steps[_tutorialStep];
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(17, 15, 17, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0xFFFFD6E5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7D315A).withOpacity(0.16),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${isVi ? 'Bước' : 'Step'} ${_tutorialStep + 1}/${_steps.length}',
                    style: const TextStyle(color: Color(0xFFCC3D7A), fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _hideTutorialCard,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFCC3D7A)),
                ),
              ],
            ),
            Text(
              step['title']!,
              style: const TextStyle(color: Color(0xFF812D5C), fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              step['description']!,
              style: const TextStyle(color: Color(0xFF594451), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                if (_tutorialStep > 0)
                  OutlinedButton(
                    onPressed: _previousStep,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFCC3D7A),
                      side: const BorderSide(color: Color(0xFFFFC5D9)),
                    ),
                    child: Text(isVi ? 'Quay lại' : 'Back'),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC3D7A),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _tutorialStep == _steps.length - 1
                        ? (isVi ? 'Hoàn tất' : 'Finish')
                        : (isVi ? 'Tiếp theo' : 'Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

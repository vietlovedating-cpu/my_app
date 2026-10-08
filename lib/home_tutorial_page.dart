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

class _HomeTutorialPageState extends State<HomeTutorialPage> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _photoFlowerKey = GlobalKey();
  final GlobalKey _floatingActionsKey = GlobalKey();
  final GlobalKey _promptLikeKey = GlobalKey();
  final GlobalKey _breakTheIceKey = GlobalKey();
  final GlobalKey _pagesKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _privacyKey = GlobalKey();
  final GlobalKey _filterCountryKey = GlobalKey();
  final GlobalKey _privacySwitchKey = GlobalKey();

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

  final List<Map<String, String>> tutorialStepsVi = [
    {'title': 'Chào mừng đến với VietLove', 'description': 'Mình sẽ hướng dẫn bạn từng chức năng chính và chỉ rõ cách bạn có thể tương tác với một hồ sơ.'},
    {'title': '3 nút chính', 'description': 'Đây là 3 nút chính trên hồ sơ. Mỗi nút có một cách sử dụng khác nhau. Mình sẽ giải thích từng nút ngay sau đây.'},
    {'title': 'Pass', 'description': 'Nếu bạn không muốn xem hồ sơ này, hãy bấm Pass. Hồ sơ hiện tại sẽ được bỏ qua và bạn sẽ chuyển sang hồ sơ tiếp theo.'},
    {'title': 'Like', 'description': 'Nếu bạn thấy người này phù hợp, hãy bấm Like để gửi một lượt Thích. Nếu người đó cũng Like bạn, hai bạn sẽ Match và có thể bắt đầu kết nối với nhau.'},
    {'title': 'Flower', 'description': 'Flower giúp bạn thể hiện sự quan tâm đặc biệt. Khi bấm Flower, bạn có thể gửi kèm một tin nhắn và người đó sẽ nhận được tin nhắn ngay lập tức.'},
    {'title': 'Like trên Prompt', 'description': 'Bạn có thể gửi một lượt Thích cho Prompt bạn thích. Bạn cũng có thể gửi tin nhắn về Prompt đó. Khi người đó xem hồ sơ của bạn, họ có thể thấy lượt Thích hoặc tin nhắn của bạn dành cho đúng Prompt đó.'},
    {'title': 'Flower trên ảnh', 'description': 'Bạn cũng có thể bấm Flower ngay trên một bức ảnh bạn thích. Bạn có thể gửi kèm tin nhắn, và người đó sẽ nhận được tin nhắn ngay.'},
    {'title': 'Phá băng', 'description': 'Nếu bạn chưa biết bắt chuyện thế nào, hãy chọn một câu trả lời trong Break the Ice. Câu trả lời của bạn không chỉ giúp bắt đầu cuộc trò chuyện mà còn gửi một lượt Like đến người đó.'},
    {'title': 'Các trang khác', 'description': 'Ngoài Kết Nối, VietLove còn có nhiều khu vực khác để bạn khám phá, kết bạn, tham gia hoạt động và tương tác với cộng đồng.'},
    {'title': 'Filter', 'description': 'Trong Filter, bạn có thể chọn All Countries nếu muốn mở rộng phạm vi tìm kiếm và khám phá những người dùng VietLove ở các quốc gia khác.'},
    {'title': 'Quyền riêng tư', 'description': 'Nếu bạn không muốn người trong danh bạ nhìn thấy hồ sơ của mình, hãy vào Cài đặt → Quyền riêng tư → Ẩn khỏi danh bạ. Tại đây bạn có thể bật hoặc tắt tính năng này bất cứ lúc nào.'},
    {'title': 'VietLove bảo vệ thông tin của bạn', 'description': 'VietLove tôn trọng quyền riêng tư của bạn. Thông tin cá nhân của bạn được bảo vệ và bạn luôn có thể chủ động lựa chọn các cài đặt riêng tư phù hợp.'},
    {'title': 'Bạn đã sẵn sàng!', 'description': 'Vậy là bạn đã biết những cách chính để tương tác và khám phá trên VietLove. Bây giờ hãy bắt đầu tìm những kết nối phù hợp với bạn nhé!'},
  ];

  final List<Map<String, String>> tutorialStepsEn = [
    {'title': 'Welcome to VietLove', 'description': 'I’ll guide you through the main features and show you how to interact with a profile.'},
    {'title': '3 main buttons', 'description': 'These are the 3 main buttons on a profile. Each one works differently, so I’ll show you what each button does.'},
    {'title': 'Pass', 'description': 'If you are not interested in this profile, tap Pass. The current profile will be skipped and you will move to the next person.'},
    {'title': 'Like', 'description': 'If you are interested in this person, tap Like to send one Like. If they Like you too, you will Match and can start connecting with each other.'},
    {'title': 'Flower', 'description': 'Flower is a stronger way to show interest. When you send a Flower, you can include a message and the person receives it immediately.'},
    {'title': 'Like a Prompt', 'description': 'You can send one Like to a Prompt you like. You can also send a message about that Prompt. When they view your profile, they can see your Like or message connected to that specific Prompt.'},
    {'title': 'Flower on a photo', 'description': 'You can also send a Flower directly on a photo you like. Add a message if you want, and the person will receive it immediately.'},
    {'title': 'Break the Ice', 'description': 'Not sure how to start a conversation? Choose an answer in Break the Ice. Your answer starts the conversation and also sends one Like to that person.'},
    {'title': 'Other pages', 'description': 'VietLove has more than the Connections page. Explore other areas to meet people, join activities and interact with the community.'},
    {'title': 'Filter', 'description': 'In Filter, choose All Countries if you want to expand your search and discover VietLove users in other countries.'},
    {'title': 'Privacy', 'description': 'If you do not want people in your contacts to see your profile, go to Settings → Privacy → Hide from Contacts. You can turn this setting on or off at any time.'},
    {'title': 'Your privacy matters', 'description': 'VietLove respects your privacy. Your personal information is protected, and you can control the privacy settings that work best for you.'},
    {'title': 'You are ready!', 'description': 'Now you know the main ways to interact and explore VietLove. You are ready to start discovering connections that are right for you!'},
  ];

  List<Map<String, String>> get tutorialSteps =>
      isVi ? tutorialStepsVi : tutorialStepsEn;

  List<String> get photos {
    return List<String>.from(
      tutorialProfile['photos'] as List<dynamic>,
    );
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    final keyContext = key.currentContext;

    if (keyContext == null) return;

    await Scrollable.ensureVisible(
      keyContext,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      alignment: 0.35,
    );
  }

  Future<void> _goToStep(int step) async {
    if (!mounted) return;

    setState(() {
      _tutorialStep = step;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 120),
    );

    if (!mounted) return;

    switch (step) {
      case 1:
      case 2:
      case 3:
      case 4:
        await _scrollToKey(_floatingActionsKey);
        break;
      case 5:
        await _scrollToKey(_promptLikeKey);
        break;
      case 6:
        await _scrollToKey(_photoFlowerKey);
        break;
      case 7:
        await _scrollToKey(_breakTheIceKey);
        break;
      case 8:
        await _scrollToKey(_pagesKey);
        break;
      case 9:
        await _scrollToKey(_filterCountryKey);
        break;
      case 10:
        await _scrollToKey(_privacySwitchKey);
        break;
      default:
        break;
    }
  }

  Future<void> _nextStep() async {
    if (_tutorialStep >= tutorialSteps.length - 1) {
      _finishTutorial();
      return;
    }

    await _goToStep(_tutorialStep + 1);
  }

  Future<void> _previousStep() async {
    if (_tutorialStep <= 0) return;

    await _goToStep(_tutorialStep - 1);
  }

  void _finishTutorial() {
    if (!mounted) return;

    Navigator.pop(context, true);
  }

  void _hideTutorialCard() {
    if (!mounted) return;

    setState(() {
      _showTutorial = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: _finishTutorial,
          icon: const Icon(
            Icons.close_rounded,
            color: Color(0xFFCC3D7A),
          ),
        ),
        title: Text(
          isVi ? 'Hướng dẫn VietLove' : 'VietLove Quick Guide',
          style: const TextStyle(
            color: Color(0xFF4A2C40),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _finishTutorial,
            child: Text(
              isVi ? 'Bỏ qua' : 'Skip',
              style: const TextStyle(
                color: Color(0xFFCC3D7A),
                fontWeight: FontWeight.w700,
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
              16,
              16,
              _showTutorial ? 235 : 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainPhotoCard(),

              const SizedBox(height: 22),

                _buildSectionTitle(
                  isVi ? 'Thông tin về Nana' : 'About Nana',
                ),

                const SizedBox(height: 14),

                _buildAboutCard(),

                const SizedBox(height: 20),

                _buildPhotoCard(
                  imagePath: photos.length > 1 ? photos[1] : photos.first,
                  showFlowerButton: true,
                  highlighted: _tutorialStep == 6,
                ),

                const SizedBox(height: 20),

                _buildPromptCard(
                  question: isVi
                      ? 'Cuối tuần hoàn hảo của tôi là...'
                      : tutorialProfile['prompt1Question'].toString(),
                  answer: isVi
                      ? 'Ăn sáng, đi dạo biển và cùng nhau uống cà phê.'
                      : tutorialProfile['prompt1Answer'].toString(),
                  showLikeButton: true,
                ),

                const SizedBox(height: 18),


                Container(
                  key: _promptLikeKey,
                  child: _buildPromptCard(
                    question: isVi
                        ? 'Cách nhanh nhất để khiến tôi mỉm cười...'
                        : tutorialProfile['prompt2Question'].toString(),
                    answer: isVi
                        ? 'Kể một câu chuyện vui và mang cho tôi một ly cà phê đá ngon.'
                        : tutorialProfile['prompt2Answer'].toString(),
                    showLikeButton: true,
                    highlightLikeButton: _tutorialStep == 5,
                  ),
                ),

                const SizedBox(height: 18),


                _buildPromptCard(
                  question: isVi
                      ? 'Chúng ta sẽ hợp nhau nếu...'
                      : tutorialProfile['prompt3Question'].toString(),
                  answer: isVi
                      ? 'Bạn tử tế, chân thành, tích cực và trân trọng gia đình.'
                      : tutorialProfile['prompt3Answer'].toString(),
                  showLikeButton: true,
                ),

                const SizedBox(height: 26),

                Container(
                  key: _breakTheIceKey,
                  child: _buildBreakTheIceCard(
                    highlighted: _tutorialStep == 7,
                  ),
                ),


                const SizedBox(height: 24),

                Container(
                  key: _pagesKey,
                  child: _buildGuideCard(
                    icon: Icons.dashboard_customize_rounded,
                    title: isVi
                        ? 'Các trang & chức năng khác'
                        : 'Other pages & features',
                    description: isVi
                        ? 'Khám phá các trang khác của VietLove để tìm bạn, trò chuyện, tham gia hoạt động và sử dụng các tính năng cộng đồng.'
                        : 'Explore other VietLove pages to discover people, chat, join activities and use community features.',
                    highlighted: _tutorialStep == 8,
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  key: _filterKey,
                  child: _buildFilterDemo(
                    highlighted: _tutorialStep == 9,
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  key: _privacyKey,
                  child: _buildPrivacyDemo(
                    highlighted: _tutorialStep == 10,
                  ),
                ),

                const SizedBox(height: 16),

                _buildPrivacyMessageCard(),

                const SizedBox(height: 22),

                Center(
                  child: Text(
                    isVi
                        ? 'Đây chỉ là hồ sơ hướng dẫn.'
                        : 'This is a tutorial profile only.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_showTutorial) _buildTutorialCard(),
        ],
      ),
    );
  }

  Widget _buildMainPhotoCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 0.78,
            child: _buildAssetImage(
              photos.first,
              borderRadius: BorderRadius.zero,
            ),
          ),

          // Photo indicators only — no extra image cards underneath.
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Row(
              children: List.generate(
                photos.length,
                (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                        right: index == photos.length - 1 ? 0 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: index == 0
                            ? Colors.white
                            : Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.48),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          '${tutorialProfile['firstName']}, '
                          '${tutorialProfile['age']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF42A5F5),
                        size: 27,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${tutorialProfile['address']}, NSW, '
                          '${tutorialProfile['selectedCountry']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isVi ? 'Ảnh đã xác minh' : 'Photo verified',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // The 3 REAL tutorial action buttons sit on the profile screen.
          Positioned(
            left: 18,
            right: 18,
            bottom: 112,
            child: Container(
              key: _floatingActionsKey,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFloatingTutorialButton(
                    icon: Icons.close_rounded,
                    label: 'Pass',
                    color: const Color(0xFF777777),
                    highlighted: _tutorialStep == 2,
                  ),
                  const SizedBox(width: 16),
                  _buildFloatingTutorialButton(
                    icon: Icons.favorite_rounded,
                    label: 'Like',
                    color: const Color(0xFFE91E63),
                    highlighted: _tutorialStep == 3,
                    size: 68,
                  ),
                  const SizedBox(width: 16),
                  _buildFloatingTutorialButton(
                    icon: Icons.local_florist_rounded,
                    label: 'Flower',
                    color: const Color(0xFFCC3D7A),
                    highlighted: _tutorialStep == 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTutorialButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool highlighted,
    double size = 60,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = highlighted ? _pulseController.value : 0.0;
        final scale = highlighted ? 1.0 + (0.10 * t) : 1.0;
        final blur = highlighted ? 14.0 + (14.0 * t) : 10.0;
        final spread = highlighted ? 1.0 + (4.0 * t) : 0.0;

        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: highlighted ? color : Colors.white,
                    width: highlighted ? 4 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(highlighted ? 0.28 + (0.22 * t) : 0.20),
                      blurRadius: blur,
                      spreadRadius: spread,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: size * 0.47,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: highlighted ? color : Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD5E6),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC3D7A).withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.work_outline_rounded,
            title: isVi ? 'Nghề nghiệp' : 'Occupation',
            value: tutorialProfile['occupation'].toString(),
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.school_outlined,
            title: isVi ? 'Học vấn' : 'Education',
            value: tutorialProfile['education'].toString(),
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.height_rounded,
            title: isVi ? 'Chiều cao' : 'Height',
            value: tutorialProfile['height'].toString(),
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.favorite_border_rounded,
            title: isVi ? 'Tình trạng' : 'Marital status',
            value: isVi ? 'Độc thân' : 'Single',
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.family_restroom_rounded,
            title: isVi ? 'Con cái' : 'Children',
            value: isVi ? 'Chưa có con' : 'No children',
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.flag_outlined,
            title: isVi ? 'Mục tiêu' : 'Looking for',
            value: isVi
                ? 'Mối quan hệ nghiêm túc'
                : 'Serious relationship',
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.public_rounded,
            title: isVi ? 'Sinh ra tại' : 'Born in',
            value: isVi ? 'Việt Nam' : 'Vietnam',
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.home_work_outlined,
            title: isVi ? 'Tình trạng cư trú' : 'Resident status',
            value: isVi ? 'Công dân' : 'Citizen',
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.self_improvement_rounded,
            title: isVi ? 'Tôn giáo' : 'Religion',
            value: isVi ? 'Phật giáo' : 'Buddhist',
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.smoke_free_rounded,
            title: isVi ? 'Hút thuốc' : 'Smoking',
            value: isVi ? 'Không' : 'No',
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.local_bar_outlined,
            title: isVi ? 'Uống rượu' : 'Drinking',
            value: isVi ? 'Xã giao' : 'Socially',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 21,
              color: const Color(0xFFCC3D7A),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF4A2C40),
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

  Widget _buildDivider() {
    return Divider(
      height: 18,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        color: Color(0xFF4A2C40),
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildPromptCard({
    required String question,
    required String answer,
    required bool showLikeButton,
    bool highlightLikeButton = false,
  }) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            showLikeButton ? 72 : 20,
            20,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFFFF3F8),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
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
              Text(
                question,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  color: Color(0xFF8B2E63),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                answer,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF4A2C40),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (showLikeButton)
          Positioned(
            right: 15,
            bottom: 15,
            child: _buildSmallLikeButton(
              highlighted: highlightLikeButton,
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoCard({
    required String imagePath,
    required bool showFlowerButton,
    bool highlighted = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: highlighted
            ? Border.all(color: const Color(0xFFCC3D7A), width: 4)
            : null,
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: const Color(0xFFCC3D7A).withOpacity(0.30),
                  blurRadius: 24,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 0.86,
              child: _buildAssetImage(
                imagePath,
                borderRadius: BorderRadius.zero,
              ),
            ),
            if (showFlowerButton)
              Positioned(
                key: _photoFlowerKey,
                right: 16,
                bottom: 16,
                child: _buildSmallFlowerButton(
                  highlighted: highlighted,
                ),
              ),

            if (highlighted)
              Positioned(
                left: 14,
                bottom: 14,
                right: 72,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.62),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    isVi
                        ? '💬 Tin nhắn sẽ được gửi ngay lập tức'
                        : '💬 Your message is sent immediately',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildFilterDemo({
    required bool highlighted,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFCC3D7A)
              : const Color(0xFFFFD5E6),
          width: highlighted ? 3 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC3D7A).withOpacity(
              highlighted ? 0.22 : 0.07,
            ),
            blurRadius: highlighted ? 24 : 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                color: Color(0xFFCC3D7A),
                size: 25,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  isVi ? 'Filter / Bộ lọc' : 'Filter',
                  style: const TextStyle(
                    fontSize: 19,
                    color: Color(0xFF4A2C40),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(
                Icons.close_rounded,
                color: Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMockFilterRow(
            icon: Icons.wc_rounded,
            title: isVi ? 'Giới tính' : 'Gender',
            value: isVi ? 'Mọi người' : 'Everyone',
          ),
          const SizedBox(height: 10),
          _buildMockFilterRow(
            icon: Icons.cake_rounded,
            title: isVi ? 'Độ tuổi' : 'Age',
            value: '18 – 60',
          ),
          const SizedBox(height: 10),
          Container(
            key: _filterCountryKey,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _tutorialStep == 10
                  ? const Color(0xFFFFE6F0)
                  : const Color(0xFFFFF6F9),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: _tutorialStep == 10
                    ? const Color(0xFFCC3D7A)
                    : const Color(0xFFFFD5E6),
                width: _tutorialStep == 10 ? 2.5 : 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.public_rounded,
                  color: Color(0xFFCC3D7A),
                  size: 24,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Quốc gia' : 'Country',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isVi ? 'Tất cả quốc gia' : 'All Countries',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4A2C40),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _tutorialStep == 10,
                  onChanged: (_) {},
                  activeColor: const Color(0xFFCC3D7A),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isVi
                ? 'Chọn “Tất cả quốc gia” để khám phá mọi người trên toàn thế giới.'
                : 'Select “All Countries” to discover people around the world.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF6F3657),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockFilterRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0EA)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFCC3D7A), size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4A2C40),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey.shade500,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyDemo({
    required bool highlighted,
  }) {
    final enabled = _tutorialStep == 11;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFCC3D7A)
              : const Color(0xFFFFD5E6),
          width: highlighted ? 3 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC3D7A).withOpacity(
              highlighted ? 0.22 : 0.07,
            ),
            blurRadius: highlighted ? 24 : 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_rounded,
                color: Color(0xFFCC3D7A),
                size: 25,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  isVi ? 'Settings → Quyền riêng tư' : 'Settings → Privacy',
                  style: const TextStyle(
                    fontSize: 19,
                    color: Color(0xFF4A2C40),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(
                Icons.settings_rounded,
                color: Color(0xFFCC3D7A),
                size: 21,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            key: _privacySwitchKey,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFFFFE6F0)
                  : const Color(0xFFFFF8FB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: highlighted
                    ? const Color(0xFFCC3D7A)
                    : const Color(0xFFFFD5E6),
                width: highlighted ? 2.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.contacts_rounded,
                    color: Color(0xFFCC3D7A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Ẩn khỏi danh bạ' : 'Hide from Contacts',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF4A2C40),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isVi
                            ? 'Bật để tăng quyền riêng tư.'
                            : 'Turn this on for extra privacy.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: (_) {},
                  activeColor: const Color(0xFFCC3D7A),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                enabled
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                color: enabled
                    ? const Color(0xFFCC3D7A)
                    : Colors.grey.shade500,
                size: 27,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  enabled
                      ? (isVi
                          ? 'Đã bật ON — bạn đã ẩn khỏi danh bạ.'
                          : 'ON — you are hidden from contacts.')
                      : (isVi
                          ? 'Kéo công tắc sang ON.'
                          : 'Turn the switch ON.'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6F3657),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard({
    required IconData icon,
    required String title,
    required String description,
    required bool highlighted,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFCC3D7A)
              : const Color(0xFFFFD5E6),
          width: highlighted ? 3 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC3D7A).withOpacity(
              highlighted ? 0.20 : 0.07,
            ),
            blurRadius: highlighted ? 22 : 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F6),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFCC3D7A),
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.25,
                    color: Color(0xFF4A2C40),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyMessageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF0F6),
            Color(0xFFFFF8FB),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFC9DE),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_rounded,
            color: Color(0xFFCC3D7A),
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isVi
                  ? 'VietLove luôn tôn trọng quyền riêng tư của bạn. Hãy yên tâm rằng thông tin của bạn được bảo vệ và bạn có thể chủ động lựa chọn cách mình xuất hiện trên VietLove.'
                  : 'VietLove respects your privacy. Your information is important to us, and you can control how you appear and what you choose to share on VietLove.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF5E3B4D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallLikeButton({
    bool highlighted = false,
  }) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 250),
      scale: highlighted ? 1.25 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: highlighted
                ? const Color(0xFFCC3D7A)
                : Colors.white,
            width: highlighted ? 4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: highlighted
                  ? const Color(0xFFCC3D7A).withOpacity(0.4)
                  : Colors.black.withOpacity(0.16),
              blurRadius: highlighted ? 20 : 10,
              spreadRadius: highlighted ? 4 : 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(
          Icons.favorite_rounded,
          color: Color(0xFFE91E63),
          size: 27,
        ),
      ),
    );
  }
Widget _buildSmallFlowerButton({
  bool highlighted = false,
}) {
  return AnimatedScale(
    duration: const Duration(milliseconds: 250),
    scale: highlighted ? 1.25 : 1,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: highlighted
              ? const Color(0xFFCC3D7A)
              : Colors.white,
          width: highlighted ? 4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? const Color(0xFFCC3D7A).withOpacity(0.4)
                : Colors.black.withOpacity(0.16),
            blurRadius: highlighted ? 20 : 10,
            spreadRadius: highlighted ? 4 : 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_florist_rounded,
        color: Color(0xFFE91E63),
        size: 27,
      ),
    ),
  );
}
  Widget _buildPromptMessageHint() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6F0),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFCC3D7A),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.chat_bubble_rounded,
            color: Color(0xFFCC3D7A),
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isVi
                  ? 'Bạn có thể Like Prompt hoặc gửi tin nhắn. Tin nhắn sẽ xuất hiện trên profile của bạn khi người đó xem hồ sơ.'
                  : 'You can Like the Prompt or send a message. Your message will appear on your profile when they view it.',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Color(0xFF6F3657),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakTheIceCard({
    required bool highlighted,
  }) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 250),
      scale: highlighted ? 1.02 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: highlighted
                ? const Color(0xFFCC3D7A)
                : const Color(0xFFFFD5E6),
            width: highlighted ? 3 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: highlighted
                  ? const Color(0xFFCC3D7A).withOpacity(0.22)
                  : const Color(0xFFCC3D7A).withOpacity(0.08),
              blurRadius: highlighted ? 24 : 16,
              spreadRadius: highlighted ? 2 : 0,
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
                  Icons.ac_unit_rounded,
                  color: Color(0xFFCC3D7A),
                  size: 24,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    isVi ? 'Phá băng' : 'Break the Ice',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Color(0xFF4A2C40),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isVi
                  ? 'Chọn một câu trả lời để phá băng. Lựa chọn của bạn cũng sẽ gửi một lượt Thích.'
                  : 'Choose an answer to break the ice. Your choice also sends a Like.',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            _buildIceAnswer(
              isVi ? 'Một buổi hẹn cà phê ☕' : 'A coffee date ☕',
            ),
            const SizedBox(height: 10),
            _buildIceAnswer(
              isVi ? 'Đi ăn món Việt cùng nhau' : 'Try Vietnamese food together',
            ),
            const SizedBox(height: 10),
            _buildIceAnswer(
              isVi ? 'Đi dạo và trò chuyện' : 'Go for a walk and talk',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIceAnswer(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD5E6),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF6F3657),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAssetImage(
    String imagePath, {
    required BorderRadius borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        imagePath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            color: const Color(0xFFFFE4EF),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_rounded,
                  size: 90,
                  color: Color(0xFFCC3D7A),
                ),
                const SizedBox(height: 10),
                Text(
                  isVi
                      ? 'Thêm ảnh Nana vào assets/tutorial'
                      : 'Add Nana’s photo to assets/tutorial',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF8B2E63),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTutorialCard() {
    final step = tutorialSteps[_tutorialStep];
    final isLastStep = _tutorialStep == tutorialSteps.length - 1;

    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFFFFC9DE),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.17),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCC3D7A),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_tutorialStep + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF4A2C40),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
  onPressed: _finishTutorial,
  icon: const Icon(
    Icons.close_rounded,
    color: Colors.grey,
  ),
),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                step['description'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF624A58),
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  Text(
                    '${_tutorialStep + 1}/${tutorialSteps.length}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const Spacer(),

                  if (_tutorialStep > 0)
                    TextButton(
                      onPressed: _previousStep,
                      child: Text(
                        isVi ? 'Quay lại' : 'Back',
                        style: const TextStyle(
                          color: Color(0xFF8B2E63),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                  const SizedBox(width: 5),

                  ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCC3D7A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isLastStep
                          ? (isVi ? 'Bắt đầu' : 'Start')
                          : (isVi ? 'Tiếp theo' : 'Next'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
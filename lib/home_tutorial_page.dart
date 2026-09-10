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

class _HomeTutorialPageState extends State<HomeTutorialPage> {
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _photoFlowerKey = GlobalKey();
  final GlobalKey _promptLikeKey = GlobalKey();
  final GlobalKey _breakTheIceKey = GlobalKey();
  final GlobalKey _nextProfileKey = GlobalKey();

  int _tutorialStep = 0;
  bool _showTutorial = true;

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
    {
      'title': 'Chào mừng bạn đến với VietLove Dating',
      'description':
          'Mình sẽ hướng dẫn nhanh cách sử dụng trang Kết Nối VietLove.',
    },
    {
      'title': 'Flower trên ảnh',
      'description':
          'Bấm Flower trên ảnh để thể hiện bạn đặc biệt quan tâm đến người này.',
    },
    {
      'title': 'Like Prompt',
      'description':
          'Bấm tim bên dưới câu trả lời để thích Prompt. Nếu hai bạn cùng thích nhau, hai bạn sẽ Match.',
    },
    {
      'title': 'Phá băng',
      'description':
          'Phá băng nằm ở cuối hồ sơ. Chọn một câu trả lời để thể hiện sự quan tâm. Lựa chọn của bạn cũng sẽ gửi một lượt Thích.',
    },
    {
      'title': 'Hồ sơ kế tiếp',
      'description':
          'Nút Pass nằm ở cuối hồ sơ. Bấm "Hồ sơ kế tiếp →" để bỏ qua hồ sơ này và xem người tiếp theo.',
    },
    {
      'title': 'Bạn đã sẵn sàng!',
      'description':
          'Bây giờ bạn đã biết cách sử dụng trang Kết Nối VietLove.',
    },
  ];

  final List<Map<String, String>> tutorialStepsEn = [
    {
      'title': 'Welcome to VietLove Dating',
      'description':
          'Here is a quick guide to using the VietLove Connections page.',
    },
    {
      'title': 'Flower on a photo',
      'description':
          'Tap Flower on a photo to show that you are especially interested in this person.',
    },
    {
      'title': 'Like a Prompt',
      'description':
          'Tap the heart below an answer to like that Prompt. If you both like each other, you will Match.',
    },
    {
      'title': 'Break the Ice',
      'description':
          'Break the Ice is at the end of the profile. Choose an answer to show your interest. Your choice also sends a Like.',
    },
    {
      'title': 'Next profile',
      'description':
          'Pass is at the end of the profile. Tap "Next profile →" to skip this profile and view the next person.',
    },
    {
      'title': 'You are ready!',
      'description':
          'You now know how to use the VietLove Connections page.',
    },
  ];

  List<Map<String, String>> get tutorialSteps =>
      isVi ? tutorialStepsVi : tutorialStepsEn;

  List<String> get photos {
    return List<String>.from(
      tutorialProfile['photos'] as List<dynamic>,
    );
  }

  @override
  void dispose() {
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
        await _scrollToKey(_photoFlowerKey);
        break;

      case 2:
        await _scrollToKey(_promptLikeKey);
        break;

      case 3:
        await _scrollToKey(_breakTheIceKey);
        break;

      case 4:
        await _scrollToKey(_nextProfileKey);
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
          isVi ? 'Hướng dẫn sử dụng' : 'VietLove Connections Tutorial',
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

                const SizedBox(height: 26),

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

                _buildPhotoCard(
                  imagePath: photos.length > 1 ? photos[1] : photos.first,
                  showFlowerButton: true,
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
                    highlightLikeButton: _tutorialStep == 2,
                  ),
                ),

                const SizedBox(height: 18),

                _buildPhotoCard(
                  imagePath: photos.length > 2 ? photos[2] : photos.first,
                  showFlowerButton: true,
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

                const SizedBox(height: 18),

                if (photos.length > 3)
                  _buildPhotoCard(
                    imagePath: photos[3],
                    showFlowerButton: true,
                  ),

                const SizedBox(height: 18),

                if (photos.length > 4)
                  _buildPhotoCard(
                    imagePath: photos[4],
                    showFlowerButton: true,
                  ),

                const SizedBox(height: 30),

                Container(
                  key: _breakTheIceKey,
                  child: _buildBreakTheIceCard(
                    highlighted: _tutorialStep == 3,
                  ),
                ),

                const SizedBox(height: 22),

                Container(
                  key: _nextProfileKey,
                  child: _buildNextProfileButton(
                    highlighted: _tutorialStep == 4,
                  ),
                ),

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
            key: _photoFlowerKey,
            right: 18,
            top: 34,
           child: _buildSmallFlowerButton(
  highlighted: _tutorialStep == 4,
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
        ],
      ),
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
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
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
              right: 16,
              bottom: 16,
              child: _buildSmallFlowerButton(),
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

  Widget _buildNextProfileButton({
    required bool highlighted,
  }) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 250),
      scale: highlighted ? 1.03 : 1,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF8B2E63),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: highlighted
                  ? const Color(0xFFCC3D7A)
                  : const Color(0xFFFFB7D2),
              width: highlighted ? 3 : 1.5,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 15,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            shadowColor: const Color(0xFFCC3D7A).withOpacity(0.20),
            elevation: highlighted ? 4 : 0,
          ),
          child: Text(
            isVi ? 'Hồ sơ kế tiếp →' : 'Next profile →',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
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
        child: Container(
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
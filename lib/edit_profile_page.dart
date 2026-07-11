import 'package:flutter/material.dart';
import 'edit_full_name_page.dart';
import 'edit_voice_prompt_page.dart';
import 'edit_age_page.dart';
import 'edit_gender_page.dart';
import 'edit_height_page.dart';
import 'edit_country_born_page.dart';
import 'edit_vietnam_birth_city_page.dart';
import 'edit_occupation_page.dart';
import 'edit_highest_education_page.dart';
import 'edit_have_children_page.dart';
import 'edit_marital_status_page.dart';
import 'edit_annual_income_page.dart';
import 'edit_religion_page.dart';
import 'edit_resident_status_page.dart';
import 'edit_smoking_page.dart';
import 'edit_drinking_page.dart';
import 'edit_max_distance_page.dart';
import 'edit_relationship_goal_page.dart';
import 'edit_current_location_page.dart';
import 'edit_prompt_question_answer_page.dart';
import 'edit_upload_photos_page.dart';
import 'edit_place_you_call_home_page.dart';

class EditProfilePage extends StatelessWidget {
  final String languageCode;

  const EditProfilePage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          _tr('Mình sẽ nối tiếp mục này ở đợt code tiếp theo', 'I will connect this item in the next code batch'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <_EditMenuItem>[
      _EditMenuItem(
  icon: Icons.person_outline,
  title: _tr('Họ tên', 'Full name'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditFullNamePage(
          languageCode: languageCode,
        ),
      ),
    );
  },
),

_EditMenuItem(
  icon: Icons.mic_none_rounded,
  title: _tr('Giọng nói Prompt', 'Voice Prompt'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditVoicePromptPage(
          languageCode: languageCode,
        ),
      ),
    );
  },
),

_EditMenuItem(
  icon: Icons.cake_outlined,
  title: _tr('Tuổi', 'Age'),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditAgePage(languageCode: languageCode),
            ),
          );
        },
      ),
      _EditMenuItem(
        icon: Icons.wc_outlined,
        title: _tr('Giới tính', 'Gender'),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditGenderPage(languageCode: languageCode),
            ),
          );
        },
      ),
_EditMenuItem(
  icon: Icons.public_outlined,
  title: _tr('Nơi bạn gọi là quê hương', 'Place you call home'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPlaceYouCallHomePage(
          languageCode: languageCode,
        ),
      ),
    );
  },
),
     
_EditMenuItem(
  icon: Icons.height,
  title: _tr('Chiều cao', 'Height'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditHeightPage(languageCode: languageCode),
      ),
    );
  },
),
_EditMenuItem(
  icon: Icons.flag_outlined,
  title: _tr('Nơi sinh', 'Country born'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditCountryBornPage(languageCode: languageCode),
      ),
    );
  },
),

      _EditMenuItem(
  icon: Icons.work_outline,
  title: _tr('Công việc', 'Occupation'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditOccupationPage(languageCode: languageCode),
      ),
    );
  },
),
_EditMenuItem(
  icon: Icons.school_outlined,
  title: _tr('Học vấn', 'Highest education'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditHighestEducationPage(languageCode: languageCode),
      ),
    );
  },
),
_EditMenuItem(
  icon: Icons.child_friendly_outlined,
  title: _tr('Con cái', 'Have children'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditHaveChildrenPage(languageCode: languageCode),
      ),
    );
  },
),
      _EditMenuItem(
  icon: Icons.favorite_border,
  title: _tr('Hôn nhân', 'Marital status'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditMaritalStatusPage(languageCode: languageCode),
      ),
    );
  },
),
_EditMenuItem(
  icon: Icons.attach_money,
  title: _tr('Lương năm', 'Annual income'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditAnnualIncomePage(languageCode: languageCode),
      ),
    );
  },
),
_EditMenuItem(
  icon: Icons.temple_buddhist_outlined,
  title: _tr('Tôn giáo', 'Religion'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditReligionPage(languageCode: languageCode),
      ),
    );
  },
),
      _EditMenuItem(
  icon: Icons.verified_user_outlined,
  title: _tr('Thẻ cư trú', 'Resident status'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditResidentStatusPage(languageCode: languageCode),
      ),
    );
  },
),
_EditMenuItem(
  icon: Icons.smoking_rooms_outlined,
  title: _tr('Hút thuốc', 'Smoking'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditSmokingPage(languageCode: languageCode),
      ),
    );
  },
),
_EditMenuItem(
  icon: Icons.local_bar_outlined,
  title: _tr('Drinking', 'Drinking'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditDrinkingPage(languageCode: languageCode),
      ),
    );
  },
),
_EditMenuItem(
  icon: Icons.place_outlined,
  title: _tr('Khoảng cách tối đa', 'Max distance'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditMaxDistancePage(languageCode: languageCode),
      ),
    );
  },
),
      _EditMenuItem(
  icon: Icons.favorite_outline,
  title: _tr('Mục tiêu mối quan hệ', 'Relationship goal'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditRelationshipGoalPage(languageCode: languageCode),
      ),
    );
  },
),
_EditMenuItem(
  icon: Icons.my_location_outlined,
  title: _tr('Vị trí hiện tại', 'Current location'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditCurrentLocationPage(languageCode: languageCode),
      ),
    );
  },
),
_EditMenuItem(
  icon: Icons.chat_bubble_outline,
  title: _tr('Prompt question and answer', 'Prompt question and answer'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPromptQuestionAnswerPage(
          languageCode: languageCode,
        ),
      ),
    );
  },
),
      _EditMenuItem(
  icon: Icons.photo_library_outlined,
  title: _tr('Ảnh', 'Photos'),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditUploadPhotosPage(
          languageCode: languageCode,
        ),
      ),
    );
  },
),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF7A2E6E),
        centerTitle: true,
        title: Text(
          _tr('Sửa hồ sơ', 'Edit Profile'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A2E6E),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return _EditMenuTile(item: item);
        },
      ),
    );
  }
}

class _EditMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _EditMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

class _EditMenuTile extends StatelessWidget {
  final _EditMenuItem item;

  const _EditMenuTile({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFFD5E6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              color: const Color(0xFFCC3D7A),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4A2C40),
                ),
              ),
            ),
            const Icon(
              Icons.edit_outlined,
              color: Color(0xFF7A2E6E),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
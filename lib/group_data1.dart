import 'package:flutter/material.dart';

class DatingGroupItem {
  final String id;
  final String imageAsset;
  final int monthlyPrice;
  final String titleVi;
  final String titleEn;
  final String subtitleVi;
  final String subtitleEn;
  final String detailTitleVi;
  final String detailTitleEn;
  final String detailBodyVi;
  final String detailBodyEn;
  final IconData icon;

  const DatingGroupItem({
    required this.id,
    required this.imageAsset,
    required this.monthlyPrice,
    required this.titleVi,
    required this.titleEn,
    required this.subtitleVi,
    required this.subtitleEn,
    required this.detailTitleVi,
    required this.detailTitleEn,
    required this.detailBodyVi,
    required this.detailBodyEn,
    required this.icon,
  });

  String title(bool isVi) => isVi ? titleVi : titleEn;
  String subtitle(bool isVi) => isVi ? subtitleVi : subtitleEn;
  String detailTitle(bool isVi) => isVi ? detailTitleVi : detailTitleEn;
  String detailBody(bool isVi) => isVi ? detailBodyVi : detailBodyEn;
}

const List<DatingGroupItem> kDatingGroups = [
  DatingGroupItem(
    id: 'english_exchange',
    imageAsset: 'assets/groups/coffee_weekend.jpg',
    monthlyPrice: 0,
    titleVi: '🇬🇧 Luyện tiếng Anh',
    titleEn: '🇬🇧 English Exchange',
    subtitleVi: 'Luyện tiếng Anh cùng mọi người trên thế giới',
    subtitleEn: 'Practice English with people around the world',
    detailTitleVi: 'Luyện tiếng Anh cùng nhau 🇬🇧',
    detailTitleEn: 'English Exchange 🇬🇧',
    detailBodyVi:
        'Đây là nhóm miễn phí dành cho những người muốn luyện tiếng Anh và kết nối với mọi người trên khắp thế giới.\n\n'
        'Bạn có thể trò chuyện, kết bạn, thực hành tiếng Anh hằng ngày và giúp nhau cải thiện kỹ năng ngôn ngữ một cách tự nhiên.\n\n'
        'Hãy thoải mái tham gia cuộc trò chuyện, đặt câu hỏi và làm quen với những người bạn mới.',
    detailBodyEn:
        'This is a free group for people who want to practice English and connect with others around the world.\n\n'
        'You can chat, make friends, practice English every day and help each other improve naturally.\n\n'
        'Feel free to join conversations, ask questions and meet new people.',
    icon: Icons.language_rounded,
  ),
  DatingGroupItem(
    id: 'vietnamese_exchange',
    imageAsset: 'assets/groups/hiking_camping.jpg',
    monthlyPrice: 0,
    titleVi: '🇻🇳 Luyện tiếng Việt',
    titleEn: '🇻🇳 Vietnamese Exchange',
    subtitleVi: 'Cùng học và luyện tiếng Việt trên toàn thế giới',
    subtitleEn: 'Learn and practice Vietnamese worldwide',
    detailTitleVi: 'Luyện tiếng Việt cùng nhau 🇻🇳',
    detailTitleEn: 'Vietnamese Exchange 🇻🇳',
    detailBodyVi:
        'Đây là nhóm miễn phí dành cho người Việt và những người đang học tiếng Việt trên toàn thế giới.\n\n'
        'Bạn có thể trò chuyện, kết bạn, đặt câu hỏi về tiếng Việt và giúp nhau luyện ngôn ngữ một cách tự nhiên.\n\n'
        'Dù bạn mới bắt đầu hay đã nói tiếng Việt tốt, bạn đều có thể tham gia và kết nối với cộng đồng.',
    detailBodyEn:
        'This is a free group for Vietnamese speakers and Vietnamese learners around the world.\n\n'
        'You can chat, make friends, ask questions about Vietnamese and help each other practice naturally.\n\n'
        'Whether you are a beginner or already speak Vietnamese well, you are welcome to join and connect with the community.',
    icon: Icons.translate_rounded,
  ),
];

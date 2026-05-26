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
    id: 'sydney_vietnamese',
    imageAsset: 'assets/groups/coffee_weekend.jpg',
    monthlyPrice: 10,
    titleVi: '🇦🇺 Nhóm Người Việt Sydney',
    titleEn: '🇦🇺 Sydney Vietnamese Group',
    subtitleVi: '',
    subtitleEn: '',
    detailTitleVi: 'Tham gia Nhóm Người Việt Sydney 🇦🇺',
    detailTitleEn: 'Join Sydney Vietnamese Group 🇦🇺',
    detailBodyVi:
        'Chỉ với \$9.99/tháng, bạn có thể tham gia cộng đồng người Việt tại Sydney.\n\n'
        'Sau khi tham gia, bạn có thể trò chuyện với các thành viên khác, kết bạn, hẹn hò, chia sẻ kinh nghiệm cuộc sống, công việc và các hoạt động cuối tuần.\n\n'
        'Đây là nơi phù hợp để kết nối với những người Việt đang sống tại Sydney một cách thân thiện, tự nhiên và chân thành.',
    detailBodyEn:
        'For only \$9.99/month, you can join the Vietnamese community in Sydney.\n\n'
        'After joining, you can chat with other members, make new friends, date, share life and work experiences, and join local weekend activities.\n\n'
        'This is a friendly space to connect naturally and meaningfully with Vietnamese people living in Sydney.',
    icon: Icons.location_city_rounded,
  ),
  DatingGroupItem(
    id: 'melbourne_vietnamese',
    imageAsset: 'assets/groups/hiking_camping.jpg',
    monthlyPrice: 10,
    titleVi: '☕ Nhóm Người Việt Melbourne',
    titleEn: '☕ Melbourne Vietnamese Group',
    subtitleVi: '',
    subtitleEn: '',
    detailTitleVi: 'Tham gia Nhóm Người Việt Melbourne ☕',
    detailTitleEn: 'Join Melbourne Vietnamese Group ☕',
    detailBodyVi:
        'Chỉ với \$9.99/tháng, bạn có thể tham gia cộng đồng người Việt tại Melbourne.\n\n'
        'Sau khi tham gia, bạn có thể trò chuyện, làm quen bạn mới, mở rộng các mối quan hệ và tham gia những buổi gặp mặt hoặc hoạt động xã hội phù hợp.\n\n'
        'Đây là không gian dành cho những ai muốn kết nối với cộng đồng người Việt tại Melbourne một cách nhẹ nhàng và thực tế hơn.',
    detailBodyEn:
        'For only \$9.99/month, you can join the Vietnamese community in Melbourne.\n\n'
        'After joining, you can chat, meet new people, build connections, and join local gatherings or social activities when suitable.\n\n'
        'This is a space for people who want to connect with the Vietnamese community in Melbourne in a natural and real way.',
    icon: Icons.people_alt_rounded,
  ),
  DatingGroupItem(
    id: 'queensland_vietnamese',
    imageAsset: 'assets/groups/speed_dating.jpg',
    monthlyPrice: 10,
    titleVi: '🌴 Nhóm Người Việt Queensland',
    titleEn: '🌴 Queensland Vietnamese Group',
    subtitleVi: '',
    subtitleEn: '',
    detailTitleVi: 'Tham gia Nhóm Người Việt Queensland 🌴',
    detailTitleEn: 'Join Queensland Vietnamese Group 🌴',
    detailBodyVi:
        'Chỉ với \$9.99/tháng, bạn có thể tham gia cộng đồng người Việt tại Queensland.\n\n'
        'Sau khi tham gia, bạn có thể trò chuyện với các thành viên khác, kết bạn, giao lưu, hẹn hò và chia sẻ các hoạt động trong khu vực.\n\n'
        'Đây là nơi giúp người Việt tại Queensland dễ dàng tìm thấy những kết nối phù hợp, thân thiện và gần gũi hơn.',
    detailBodyEn:
        'For only \$9.99/month, you can join the Vietnamese community in Queensland.\n\n'
        'After joining, you can chat with other members, make friends, socialize, date, and share local activities in the area.\n\n'
        'This group helps Vietnamese people in Queensland find friendly, suitable, and meaningful connections.',
    icon: Icons.beach_access_rounded,
  ),
  DatingGroupItem(
    id: 'perth_vietnamese',
    imageAsset: 'assets/groups/gym_fitness.jpg',
    monthlyPrice: 10,
    titleVi: '🌅 Nhóm Người Việt Perth',
    titleEn: '🌅 Perth Vietnamese Group',
    subtitleVi: '',
    subtitleEn: '',
    detailTitleVi: 'Tham gia Nhóm Người Việt Perth 🌅',
    detailTitleEn: 'Join Perth Vietnamese Group 🌅',
    detailBodyVi:
        'Chỉ với \$9.99/tháng, bạn có thể tham gia cộng đồng người Việt tại Perth.\n\n'
        'Sau khi tham gia, bạn có thể trò chuyện, tìm bạn mới, giao lưu, hẹn hò và xây dựng những mối quan hệ lâu dài trong cộng đồng.\n\n'
        'Đây là không gian thân thiện cho người Việt tại Perth muốn kết nối, chia sẻ và gặp gỡ những người phù hợp.',
    detailBodyEn:
        'For only \$9.99/month, you can join the Vietnamese community in Perth.\n\n'
        'After joining, you can chat, meet new friends, socialize, date, and build lasting relationships within the community.\n\n'
        'This is a friendly space for Vietnamese people in Perth to connect, share, and meet suitable people.',
    icon: Icons.wb_sunny_rounded,
  ),
];
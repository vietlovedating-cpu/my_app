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
    id: 'weekend_coffee',
    imageAsset: 'assets/groups/coffee_weekend.jpg',
    monthlyPrice: 30,
    titleVi: '☕ Coffee together',
    titleEn: '☕ Coffee together',
    subtitleVi: '',
    subtitleEn: '',
    detailTitleVi: 'Tham gia Nhóm Cafe Cuối Tuần ☕',
    detailTitleEn: 'Join Weekend Coffee Group ☕',
    detailBodyVi:
        'Chỉ với \$30/tháng, bạn có thể trở thành thành viên của nhóm.\n\n'
        'Sau khi tham gia, bạn sẽ được chat cùng các thành viên khác, chia sẻ những câu chuyện đời thường, làm quen một cách tự nhiên, thoải mái, và cùng nhau hẹn những buổi cafe cuối tuần nếu hợp nhau.\n\n'
        'Đây là một không gian nhẹ nhàng, thân thiện, phù hợp cho những người muốn kết nối chậm rãi, chân thành và thực tế hơn.',
    detailBodyEn:
        'For only \$30/month, you can become a member of the group.\n\n'
        'After joining, you can chat with other members, share everyday stories, get to know each other naturally and comfortably, and arrange weekend coffee meetups if you connect well.\n\n'
        'This is a gentle and friendly space for people who want a slower, more genuine, and more real connection.',
    icon: Icons.local_cafe_rounded,
  ),
  DatingGroupItem(
    id: 'hiking_camping',
    imageAsset: 'assets/groups/hiking_camping.jpg',
    monthlyPrice: 20,
    titleVi: 'Nhóm cắm trại, hiking',
    titleEn: 'Camping, hiking group',
    subtitleVi: '',
    subtitleEn: '',
    detailTitleVi: 'Tham gia Nhóm Hiking & Camping ⛰️',
    detailTitleEn: 'Join Hiking & Camping Group ⛰️',
    detailBodyVi:
        'Chỉ với \$20/tháng, bạn có thể trở thành thành viên của nhóm.\n\n'
        'Sau khi tham gia, bạn sẽ được trò chuyện với những người cùng yêu thích đi bộ, leo núi, dã ngoại và cắm trại, cùng chia sẻ kế hoạch cuối tuần và những trải nghiệm ngoài trời.\n\n'
        'Đây là nơi phù hợp để kết nối qua hoạt động thực tế, năng động và thoải mái hơn trước khi gặp mặt trực tiếp.',
    detailBodyEn:
        'For only \$20/month, you can become a member of the group.\n\n'
        'After joining, you can chat with people who enjoy hiking, outdoor trips, and camping, share weekend plans, and connect through real activities.\n\n'
        'It is a great place to meet others through active and relaxed outdoor experiences before seeing each other in person.',
    icon: Icons.hiking_rounded,
  ),
  DatingGroupItem(
    id: 'speed_dating',
    imageAsset: 'assets/groups/speed_dating.jpg',
    monthlyPrice: 50,
    titleVi: 'Hẹn hò xoay vòng',
    titleEn: 'Speed dating event',
    subtitleVi: '',
    subtitleEn: '',
    detailTitleVi: 'Tham gia Nhóm Hẹn Hò Xoay Vòng 💫',
    detailTitleEn: 'Join Speed Dating Group 💫',
    detailBodyVi:
        'Chỉ với \$50/tháng, bạn sẽ trở thành thành viên của cộng đồng Hẹn hò xoay vòng.\n\n'
        'Sự kiện hẹn hò xoay vòng diễn ra mỗi tháng một lần, nơi bạn có thể trò chuyện ngắn với nhiều thành viên khác nhau trong một không khí vui vẻ, thoải mái và không áp lực.\n\n'
        'Mỗi lượt trò chuyện chỉ kéo dài vài phút, sau đó bạn sẽ đổi sang người tiếp theo, giúp bạn dễ dàng cảm nhận sự phù hợp và tìm ra người bạn muốn kết nối nhiều hơn.\n\n'
        'Trước mỗi buổi gặp mặt, các thành viên vẫn có thể nhắn tin, làm quen và kết nối với nhau trước trong group chat, để khi gặp trực tiếp sẽ tự nhiên và dễ nói chuyện hơn.',
    detailBodyEn:
        'For only \$50/month, you will become a member of the Speed Dating community.\n\n'
        'The speed dating event takes place once a month, where you can have short conversations with different members in a fun, relaxed, and low-pressure atmosphere.\n\n'
        'Each chat lasts only a few minutes before rotating to the next person, making it easier to feel chemistry and decide who you would like to see again.\n\n'
        'Before each event, members can chat and get to know each other in the group chat first, so meeting in person feels more natural and comfortable.',
    icon: Icons.favorite_rounded,
  ),
  DatingGroupItem(
    id: 'gym_fitness',
    imageAsset: 'assets/groups/gym_fitness.jpg',
    monthlyPrice: 20,
    titleVi: '🏋️ Gym & Fitness',
    titleEn: '🏋️ Gym & Fitness',
    subtitleVi: '',
    subtitleEn: '',
    detailTitleVi: 'Tham gia Nhóm Gym & Fitness 🏋️',
    detailTitleEn: 'Join Gym & Fitness Group 🏋️',
    detailBodyVi:
        'Chỉ với \$20/tháng, bạn có thể trở thành thành viên của nhóm.\n\n'
        'Sau khi tham gia, bạn có thể trò chuyện với những người cùng sở thích tập luyện, chia sẻ lịch tập, mục tiêu, động lực và lối sống lành mạnh.\n\n'
        'Đây là nơi phù hợp để làm quen với những người năng động, tích cực và có thể cùng nhau hẹn tập hoặc tham gia các hoạt động vận động nếu hợp nhau.',
    detailBodyEn:
        'For only \$20/month, you can become a member of the group.\n\n'
        'After joining, you can chat with people who share your fitness interests, exchange workout routines, goals, motivation, and healthy lifestyle habits.\n\n'
        'It is a great place to meet active and positive people, and possibly arrange workouts or fitness activities together if you connect well.',
    icon: Icons.fitness_center_rounded,
  ),
];
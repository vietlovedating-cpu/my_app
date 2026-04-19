import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'message_page.dart';
import 'likes_and_views_hub_page.dart';

class MessagesListPage extends StatelessWidget {
  final String languageCode;

  const MessagesListPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

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

  Widget _buildAvatar(String rawPhoto, {double radius = 26}) {
    final raw = rawPhoto.trim();

    if (raw.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: const Icon(Icons.person),
      );
    }

    return FutureBuilder<String?>(
      future: _resolveImageUrl(raw),
      builder: (context, snapshot) {
        final resolvedUrl = snapshot.data;

        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: resolvedUrl != null && resolvedUrl.isNotEmpty
              ? NetworkImage(resolvedUrl)
              : null,
          child: (resolvedUrl == null || resolvedUrl.isEmpty)
              ? const Icon(Icons.person)
              : null,
        );
      },
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final now = DateTime.now();

    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    if (isToday) {
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');

      final displayHour = hour == 0
          ? 12
          : hour > 12
              ? hour - 12
              : hour;

      final amPm = hour >= 12 ? 'PM' : 'AM';
      return '$displayHour:$minute $amPm';
    }

    return '${date.day}/${date.month}';
  }

  Future<Map<String, String>> _getOtherUserInfo({
    required String otherUserId,
    required String fallbackName,
    required String fallbackPhoto,
  }) async {
    String name = fallbackName.trim();
    String photo = fallbackPhoto.trim();

    if (name.isNotEmpty && photo.isNotEmpty) {
      return {
        'name': name,
        'photo': photo,
      };
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get();

      final userData = userDoc.data() ?? {};

      if (name.isEmpty) {
        name = (userData['firstName'] ?? '').toString().trim();
      }

      if (photo.isEmpty) {
        photo = (userData['mainPhotoUrl'] ?? '').toString().trim();
      }
    } catch (_) {}

    return {
      'name': name,
      'photo': photo,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text(_tr('Bạn chưa đăng nhập', 'You are not logged in')),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
  backgroundColor: const Color(0xFFFFF7FB),
  elevation: 0,
  centerTitle: true,
  toolbarHeight: 70, // 👈 thêm dòng này
  actions: [
    IconButton(
      tooltip: _tr('Ai thích tôi', 'Who Likes Me'),
      icon: const Icon(
        Icons.star_rounded,
        color: Color(0xFFF4A261),
        size: 42, // 👈 đẹp nhất (đừng 48 quá to)
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LikesAndViewsHubPage(
              languageCode: languageCode,
            ),
          ),
        );
      },
    ),
    const SizedBox(width: 10),
  ],
),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser.uid)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(_tr('Có lỗi xảy ra', 'Something went wrong')),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Text(
                _tr('Chưa có cuộc trò chuyện nào', 'No conversations yet'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final participants = List<String>.from(data['participants'] ?? []);

              final otherUserId = participants.firstWhere(
                (id) => id != currentUser.uid,
                orElse: () => '',
              );

              final names = Map<String, dynamic>.from(
                data['participantNames'] ?? {},
              );

              final photos = Map<String, dynamic>.from(
                data['participantPhotos'] ?? {},
              );

              final fallbackName = (names[otherUserId] ?? '').toString().trim();
              final fallbackPhoto = (photos[otherUserId] ?? '').toString().trim();

              final lastMessage = (data['lastMessage'] ?? '').toString();
              final updatedAt = data['updatedAt'] as Timestamp?;
              final chatId = (data['chatId'] ?? docs[index].id).toString();

              return FutureBuilder<Map<String, String>>(
                future: _getOtherUserInfo(
                  otherUserId: otherUserId,
                  fallbackName: fallbackName,
                  fallbackPhoto: fallbackPhoto,
                ),
                builder: (context, userSnapshot) {
                  final userInfo = userSnapshot.data ??
                      {
                        'name': fallbackName,
                        'photo': fallbackPhoto,
                      };

                  final otherName = (userInfo['name'] ?? '').trim();
                  final otherPhoto = (userInfo['photo'] ?? '').trim();

                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MessagePage(
                            languageCode: languageCode,
                            chatId: chatId,
                            otherUserId: otherUserId,
                            otherUserName: otherName.isNotEmpty
                                ? otherName
                                : _tr('Người dùng', 'User'),
                            otherUserPhotoUrl: otherPhoto,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFF0F5),
                            Color(0xFFFFFFFF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFFD6E7),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(otherPhoto, radius: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  otherName.isNotEmpty
                                      ? otherName
                                      : _tr('Người dùng', 'User'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(updatedAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
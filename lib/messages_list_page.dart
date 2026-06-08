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
    if (otherUserId.trim().isEmpty) {
      return {
        'deleted': 'true',
        'name': '',
        'photo': '',
      };
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get();

      if (!userDoc.exists) {
        return {
          'deleted': 'true',
          'name': '',
          'photo': '',
        };
      }

      final userData = userDoc.data() ?? {};

      final name = (userData['firstName'] ?? fallbackName).toString().trim();

      final photo =
          (userData['mainPhotoUrl'] ?? fallbackPhoto).toString().trim();

      return {
        'deleted': 'false',
        'name': name,
        'photo': photo,
      };
    } catch (_) {
      return {
        'deleted': 'true',
        'name': '',
        'photo': '',
      };
    }
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
        toolbarHeight: 70,
        actions: [
          IconButton(
            tooltip: _tr('Ai thích tôi', 'Who Likes Me'),
            icon: const Icon(
  Icons.notifications_active_rounded,
  color: Color(0xFFE63946),
  size: 43,
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
            .collection('users')
            .doc(currentUser.uid)
            .collection('blocked_users')
            .snapshots(),
        builder: (context, blockedSnapshot) {
          final blockedIds = blockedSnapshot.data?.docs
                  .map((doc) => doc.id)
                  .toSet() ??
              <String>{};

          return StreamBuilder<QuerySnapshot>(
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
                  final hiddenFor = List<String>.from(data['hiddenFor'] ?? []);

if (hiddenFor.contains(currentUser.uid)) {
  return const SizedBox.shrink();
}

                  final participants =
                      List<String>.from(data['participants'] ?? []);

                  final otherUserId = participants.firstWhere(
                    (id) => id != currentUser.uid,
                    orElse: () => '',
                  );

                  if (blockedIds.contains(otherUserId)) {
                    return const SizedBox.shrink();
                  }

                  final names = Map<String, dynamic>.from(
                    data['participantNames'] ?? {},
                  );

                  final photos = Map<String, dynamic>.from(
                    data['participantPhotos'] ?? {},
                  );

                  final fallbackName =
                      (names[otherUserId] ?? '').toString().trim();
                  final fallbackPhoto =
                      (photos[otherUserId] ?? '').toString().trim();

                  final lastMessage = (data['lastMessage'] ?? '').toString();
                  final updatedAt = data['updatedAt'] as Timestamp?;
                  final chatId = (data['chatId'] ?? docs[index].id).toString();
                  final lastSenderId = (data['lastSenderId'] ?? '').toString();

                  final lastReadBy = Map<String, dynamic>.from(
                    data['lastReadBy'] ?? {},
                  );

                  final myLastReadAt = lastReadBy[currentUser.uid] as Timestamp?;

                  final isUnread = lastSenderId.isNotEmpty &&
                      lastSenderId != currentUser.uid &&
                      updatedAt != null &&
                      (myLastReadAt == null ||
                          updatedAt.toDate().isAfter(myLastReadAt.toDate()));

                  return FutureBuilder<Map<String, String>>(
                    future: _getOtherUserInfo(
                      otherUserId: otherUserId,
                      fallbackName: fallbackName,
                      fallbackPhoto: fallbackPhoto,
                    ),
                    builder: (context, userSnapshot) {
                      final userInfo = userSnapshot.data ??
                          {
                            'deleted': 'false',
                            'name': fallbackName,
                            'photo': fallbackPhoto,
                          };

                      if (userInfo['deleted'] == 'true') {
                        return const SizedBox.shrink();
                      }

                      final otherName = (userInfo['name'] ?? '').trim();
                      final otherPhoto = (userInfo['photo'] ?? '').trim();

                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          await FirebaseFirestore.instance
                              .collection('chats')
                              .doc(chatId)
                              .set({
                            'lastReadBy': {
                              currentUser.uid: FieldValue.serverTimestamp(),
                            },
                          }, SetOptions(merge: true));

                          if (!context.mounted) return;

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
                            gradient: LinearGradient(
                              colors: isUnread
                                  ? [
                                      const Color(0xFFFFD6E7),
                                      const Color(0xFFFFF3F8),
                                    ]
                                  : [
                                      const Color(0xFFFFF0F5),
                                      const Color(0xFFFFFFFF),
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
                                      style: TextStyle(
                                        color: isUnread
                                            ? Colors.black87
                                            : Colors.black54,
                                        fontSize: 13,
                                        fontWeight: isUnread
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),

Column(
  children: [
    Text(
      _formatTime(updatedAt),
      style: const TextStyle(
        fontSize: 11,
        color: Colors.black45,
      ),
    ),

    PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(
        Icons.more_vert,
        size: 18,
        color: Colors.black45,
      ),
      onSelected: (value) async {
        if (value == 'remove') {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(
        _tr(
          'Xóa khỏi danh sách?',
          'Remove from list?',
        ),
      ),
      content: Text(
        _tr(
          'Bạn có chắc muốn xóa cuộc trò chuyện này khỏi danh sách không?',
          'Are you sure you want to remove this conversation from your list?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(_tr('Huỷ', 'Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(_tr('Xóa', 'Remove')),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  await FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .set({
    'hiddenFor': FieldValue.arrayUnion([currentUser.uid]),
  }, SetOptions(merge: true));
}

        if (value == 'block') {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(_tr('Chặn người dùng?', 'Block user?')),
      content: Text(
        _tr(
          'Bạn có chắc muốn chặn người dùng này không?\n\nSau khi chặn, cuộc trò chuyện sẽ bị xóa khỏi danh sách và hai bạn sẽ không thể nhắn tin cho nhau.',
          'Are you sure you want to block this user?\n\nAfter blocking, this conversation will be removed from your list and you will no longer be able to message each other.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(_tr('Huỷ', 'Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(_tr('Chặn', 'Block')),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  await FirebaseFirestore.instance
    .collection('users')
    .doc(currentUser.uid)
    .collection('blocked_users')
    .doc(otherUserId)
    .set({
  'uid': otherUserId,
  'blockedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

  await FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .set({
    'hiddenFor': FieldValue.arrayUnion([currentUser.uid]),
  }, SetOptions(merge: true));
}
if (!context.mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(
      _tr(
        'Đã chặn người dùng',
        'User blocked',
      ),
    ),
  ),
);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'remove',
          child: Text(
            _tr(
              'Xóa khỏi danh sách',
              'Remove from list',
            ),
          ),
        ),
        PopupMenuItem(
          value: 'block',
          child: Text(
            _tr(
              'Chặn người dùng',
              'Block user',
            ),
          ),
        ),
      ],
    ),
  ],
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
          );
        },
      ),
    );
  }
}
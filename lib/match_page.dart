import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'message_page.dart';
import 'likes_and_views_hub_page.dart';

class MatchPage extends StatelessWidget {
  final String languageCode;

  const MatchPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  String _capitalizeName(String text) {
    final value = text.trim();
    if (value.isEmpty) return '';
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
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
  Icons.people_alt_rounded,
  color: Color(0xFFE76F51),
  size: 42,
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .where('users', arrayContains: currentUser.uid)
            .orderBy('lastMessageAt', descending: true)
            .snapshots(),
        builder: (context, matchSnapshot) {
          if (matchSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (matchSnapshot.hasError) {
            final errorText =
                matchSnapshot.error?.toString() ?? 'Unknown error';

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Lỗi match: $errorText',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = matchSnapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _tr(
                    'Bạn chưa có match nào.',
                    'You do not have any matches yet.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final List<dynamic> users = data['users'] ?? [];
              final String otherUid = users
                  .map((e) => e.toString())
                  .firstWhere(
                    (id) => id != currentUser.uid,
                    orElse: () => '',
                  );

              if (otherUid.isEmpty) {
                return const SizedBox.shrink();
              }

              final Map<String, dynamic> participantNames =
                  Map<String, dynamic>.from(data['participantNames'] ?? {});
              final Map<String, dynamic> participantPhotos =
                  Map<String, dynamic>.from(data['participantPhotos'] ?? {});

              final String otherName =
                  _capitalizeName((participantNames[otherUid] ?? '').toString());
              final String otherPhoto =
                  (participantPhotos[otherUid] ?? '').toString().trim();
              final String chatId = (data['chatId'] ?? docs[index].id).toString();

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUid)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }

                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  final userData = userSnapshot.data!.data() ?? {};

                  final String displayName = _capitalizeName(
                    (userData['firstName'] ?? otherName).toString(),
                  );

                  final String displayPhoto =
                      (userData['mainPhotoUrl'] ?? otherPhoto).toString().trim();

                  int age = 0;
                  final rawAge = userData['age'];

                  if (rawAge is int) {
                    age = rawAge;
                  } else {
                    age = int.tryParse('${rawAge ?? ''}') ?? 0;
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MessagePage(
                            languageCode: languageCode,
                            chatId: chatId,
                            otherUserId: otherUid,
                            otherUserName: displayName,
                            otherUserPhotoUrl: displayPhoto,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFCC3D7A).withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFFFD5E6),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 31,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: displayPhoto.isNotEmpty
                                ? NetworkImage(displayPhoto)
                                : null,
                            child: displayPhoto.isEmpty
                                ? const Icon(Icons.person, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  age > 0
                                      ? '$displayName, $age'
                                      : displayName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF8A2F6A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _tr('Nhấn để nhắn tin', 'Tap to message'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF8A2F6A),
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
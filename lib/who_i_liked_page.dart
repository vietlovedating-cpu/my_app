import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'view_other_profile_page.dart';

class WhoILikedPage extends StatelessWidget {
  final String languageCode;

  const WhoILikedPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  // ===========================================================
  // IMAGE URL
  // ===========================================================

  Future<String?> _resolveImageUrl(String raw) async {
    final value = raw.trim();

    if (value.isEmpty) {
      return null;
    }

    if (value.startsWith('http://') ||
        value.startsWith('https://')) {
      return value;
    }

    if (value.startsWith('gs://')) {
      try {
        return await FirebaseStorage.instance
            .refFromURL(value)
            .getDownloadURL();
      } catch (_) {
        return null;
      }
    }

    try {
      return await FirebaseStorage.instance
          .ref(value)
          .getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  String _capitalize(String text) {
    final value = text.trim();

    if (value.isEmpty) {
      return '';
    }

    return value[0].toUpperCase() +
        value.substring(1).toLowerCase();
  }

  // ===========================================================
  // LOAD VALID LIKED PROFILES
  // ===========================================================

  Future<List<Map<String, dynamic>>> _loadValidLikedProfiles({
    required String currentUid,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> swipeDocs,
  }) async {
    final likedSwipeDocs = swipeDocs.where((doc) {
      final data = doc.data();

      final fromUserId =
          (data['fromUserId'] ?? '').toString().trim();

      final toUserId =
          (data['toUserId'] ?? '').toString().trim();

      final action =
          (data['action'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      return fromUserId == currentUid &&
          toUserId.isNotEmpty &&
          toUserId != currentUid &&
          action == 'like';
    }).toList();

    // Like mới nhất hiện trước.
    likedSwipeDocs.sort((a, b) {
      final aCreatedAt = a.data()['createdAt'];
      final bCreatedAt = b.data()['createdAt'];

      if (aCreatedAt is Timestamp &&
          bCreatedAt is Timestamp) {
        return bCreatedAt.compareTo(aCreatedAt);
      }

      if (aCreatedAt is Timestamp) {
        return -1;
      }

      if (bCreatedAt is Timestamp) {
        return 1;
      }

      return 0;
    });

    final loadedProfiles = await Future.wait(
      likedSwipeDocs.map((swipeDoc) async {
        final swipeData = swipeDoc.data();

        final targetUid =
            (swipeData['toUserId'] ?? '')
                .toString()
                .trim();

        if (targetUid.isEmpty ||
            targetUid == currentUid) {
          return null;
        }

        // Đọc hồ sơ hiện tại của người được Like.
        final targetUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .get();

        // Tài khoản không còn tồn tại thì không hiện.
        if (!targetUserDoc.exists) {
          return null;
        }

        final userData = targetUserDoc.data() ?? {};

        // =====================================================
        // KHÔNG HIỆN PROFILE KHÔNG CÒN KHẢ DỤNG
        // =====================================================

        if (userData['isDeleted'] == true) {
          return null;
        }

        if (userData['accountPaused'] == true) {
          return null;
        }

        if (userData['isPaused'] == true) {
          return null;
        }

        if (userData['showMyProfile'] == false) {
          return null;
        }

        if (userData['showOnDiscover'] == false) {
          return null;
        }

        if (userData['profileCompleted'] != true) {
          return null;
        }

        final mainPhotoUrl =
            (userData['mainPhotoUrl'] ??
                    userData['photoUrl'] ??
                    '')
                .toString()
                .trim();

        // Không có ảnh chính thì không hiện.
        if (mainPhotoUrl.isEmpty) {
          return null;
        }

        // =====================================================
        // CHECK MATCH
        // Match ID hiện tại của app là UID sắp xếp rồi nối bằng "_"
        // =====================================================

        final userIds = [currentUid, targetUid]..sort();
        final matchId = userIds.join('_');

        final matchDoc = await FirebaseFirestore.instance
            .collection('matches')
            .doc(matchId)
            .get();

        final isMatched = matchDoc.exists;

        return <String, dynamic>{
          'docId': targetUserDoc.id,
          'uid': targetUid,
          ...userData,

          // Dữ liệu Like đã gửi.
          'likedContentType':
              swipeData['likedContentType'] ?? '',
          'likedContentIndex':
              swipeData['likedContentIndex'],
          'likedContentText':
              swipeData['likedContentText'] ?? '',
          'likeComment':
              swipeData['likeComment'] ?? '',
          'likedAt':
              swipeData['createdAt'],

          // Trạng thái match.
          'isMatched': isMatched,
        };
      }),
    );

    return loadedProfiles
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  // ===========================================================
  // EMPTY STATE
  // ===========================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEAF2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.favorite_outline_rounded,
                size: 42,
                color: Color(0xFFCC3D7A),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _tr(
                'Bạn chưa thích ai',
                'You have not liked anyone yet',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tr(
                'Những hồ sơ bạn đã thích sẽ xuất hiện ở đây.',
                'Profiles you have liked will appear here.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // HEADER
  // ===========================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _tr(
                'Tôi đã thích ai',
                'Who I Liked',
              ),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEAF2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _tr(
                'Dành cho VIP',
                'VIP feature',
              ),
              style: const TextStyle(
                color: Color(0xFFCC3D7A),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // MATCH BADGE
  // ===========================================================

  Widget _buildMatchedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF5A8A),
            Color(0xFFCC3D7A),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC3D7A)
                .withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        _tr(
          'Đã match',
          'Matched',
        ),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  // ===========================================================
  // USER CARD
  // ===========================================================

  Widget _buildUserCard(
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    final userId =
        (data['uid'] ?? data['docId'] ?? '')
            .toString()
            .trim();

    final name = _capitalize(
      (data['firstName'] ?? '').toString(),
    );

    final age =
        (data['age'] ?? '').toString().trim();

    final rawPhoto =
        (data['mainPhotoUrl'] ??
                data['photoUrl'] ??
                data['userPhotoUrl'] ??
                '')
            .toString()
            .trim();

    final isMatched =
        data['isMatched'] == true;

    final displayName = name.isNotEmpty
        ? name
        : _tr('Người dùng', 'User');

    final displayText =
        '$displayName${age.isNotEmpty ? ', $age' : ''}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: userId.isEmpty
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ViewOtherProfilePage(
                      userId: userId,
                      languageCode: languageCode,

                      // Ẩn Like và Pass trong mọi trường hợp.
                      hideLikeButton: true,
                      hidePassButton: true,

                      // Biến mới sẽ thêm vào
                      // ViewOtherProfilePage.
                      //
                      // Chưa match:
                      // chỉ hiện Flower.
                      //
                      // Đã match:
                      // không hiện Pass, Like, Flower.
                      allowFlowerForLikedProfile: true,
                    ),
                  ),
                );

                // Không cần setState ở đây.
                // Stream swipes sẽ tự cập nhật.
                //
                // Khi gửi Flower:
                // action "like" đổi thành "flower",
                // profile tự biến mất khỏi trang này.
              },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FutureBuilder<String?>(
                  future: _resolveImageUrl(rawPhoto),
                  builder: (context, snapshot) {
                    final resolvedUrl = snapshot.data;

                    return Container(
                      color: Colors.grey.shade200,
                      child: resolvedUrl != null &&
                              resolvedUrl.isNotEmpty
                          ? Image.network(
                              resolvedUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder:
                                  (_, __, ___) {
                                return Center(
                                  child: Icon(
                                    Icons.person,
                                    size: 36,
                                    color:
                                        Colors.grey.shade500,
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Icon(
                                Icons.person,
                                size: 36,
                                color:
                                    Colors.grey.shade500,
                              ),
                            ),
                    );
                  },
                ),

                // Gradient dưới ảnh.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.04),
                          Colors.black.withOpacity(0.28),
                        ],
                        stops: const [
                          0.52,
                          0.74,
                          1.0,
                        ],
                      ),
                    ),
                  ),
                ),

                // Badge đã match.
                if (isMatched)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _buildMatchedBadge(),
                  ),

                // Tên và tuổi.
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    constraints:
                        const BoxConstraints(
                      maxWidth: 120,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                          Colors.black.withOpacity(0.44),
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            Colors.white.withOpacity(0.16),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      displayText,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================
  // BUILD
  // ===========================================================

  @override
  Widget build(BuildContext context) {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor:
            const Color(0xFFF7F4F1),
        body: Center(
          child: Text(
            _tr(
              'Bạn chưa đăng nhập',
              'Not logged in',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F4F1),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFF7F4F1),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
        title: Text(
          _tr(
            'Tôi đã thích ai',
            'Who I Liked',
          ),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ),

      // Chỉ cần query fromUserId.
      // Không orderBy để tránh phải tạo composite index.
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('swipes')
            .where(
              'fromUserId',
              isEqualTo: currentUser.uid,
            )
            .snapshots(),
        builder: (context, swipeSnapshot) {
          if (swipeSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFCC3D7A),
              ),
            );
          }

          if (swipeSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _tr(
                    'Không thể tải danh sách lúc này.',
                    'Unable to load the list right now.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final swipeDocs =
              swipeSnapshot.data?.docs ?? [];

          final hasLikeSwipe =
              swipeDocs.any((doc) {
            final data = doc.data();

            final action =
                (data['action'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();

            final toUserId =
                (data['toUserId'] ?? '')
                    .toString()
                    .trim();

            return action == 'like' &&
                toUserId.isNotEmpty;
          });

          if (!hasLikeSwipe) {
            return _buildEmptyState();
          }

          return FutureBuilder<
              List<Map<String, dynamic>>>(
            future: _loadValidLikedProfiles(
              currentUid: currentUser.uid,
              swipeDocs: swipeDocs,
            ),
            builder: (
              context,
              profileSnapshot,
            ) {
              if (profileSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFCC3D7A),
                  ),
                );
              }

              final validProfiles =
                  profileSnapshot.data ?? [];

              if (validProfiles.isEmpty) {
                return _buildEmptyState();
              }

              return Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: GridView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        20,
                      ),
                      itemCount:
                          validProfiles.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.78,
                      ),
                      itemBuilder:
                          (context, index) {
                        return _buildUserCard(
                          validProfiles[index],
                          context,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
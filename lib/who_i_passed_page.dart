import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'view_other_profile_page.dart';

class WhoIPassedPage extends StatelessWidget {
  final String languageCode;

  const WhoIPassedPage({
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

  String _capitalize(String text) {
    final v = text.trim();
    if (v.isEmpty) return '';
    return v[0].toUpperCase() + v.substring(1).toLowerCase();
  }

  Future<bool> _isUserDeleted(String uid) async {
    if (uid.trim().isEmpty) return true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) return true;

      final data = doc.data() ?? {};

      if (data['isDeleted'] == true) return true;
      if (data['accountPaused'] == true) return true;
      if (data['isPaused'] == true) return true;

      return false;
    } catch (_) {
      return true;
    }
  }

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
                color: const Color(0xFFEFF3FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 42,
                color: Color(0xFF5C7CFA),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _tr(
                'Bạn chưa bỏ qua ai',
                'You have not passed anyone yet',
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
                'Những hồ sơ bạn đã bỏ qua sẽ xuất hiện ở đây.',
                'Profiles you passed will appear here.',
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

  Widget _buildUserCard(Map<String, dynamic> data, BuildContext context) {
    final userId = (data['uid'] ?? data['docId'] ?? '').toString().trim();

    final name = _capitalize((data['firstName'] ?? '').toString());
    final age = (data['age'] ?? '').toString().trim();

    final rawPhoto = (data['photoUrl'] ??
            data['mainPhotoUrl'] ??
            data['userPhotoUrl'] ??
            '')
        .toString()
        .trim();

    final displayName = name.isNotEmpty ? name : _tr('Người dùng', 'User');
    final displayText = '$displayName${age.isNotEmpty ? ', $age' : ''}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: userId.isEmpty
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ViewOtherProfilePage(
  userId: userId,
  languageCode: languageCode,
  allowActionsForPassedProfile: true,
),
                  ),
                );
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
                    final url = snapshot.data;

                    return Container(
                      color: Colors.grey.shade200,
                      child: url != null && url.isNotEmpty
                          ? Image.network(
                              url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.person,
                                  size: 36,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.person,
                                size: 36,
                                color: Colors.grey.shade500,
                              ),
                            ),
                    );
                  },
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.04),
                          Colors.black.withOpacity(0.22),
                        ],
                        stops: const [0.55, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 110),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.42),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.16),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _tr('Tôi đã bỏ qua', 'Who I Passed'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _tr(
                'Bạn có thể xem lại hồ sơ',
                'You can review profiles',
              ),
              style: const TextStyle(
                color: Color(0xFF5C7CFA),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F4F1),
        body: Center(
          child: Text(_tr('Bạn chưa đăng nhập', 'Not logged in')),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4F1),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          _tr('Tôi đã bỏ qua', 'Who I Passed'),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('passedUsers')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FutureBuilder<List<QueryDocumentSnapshot>>(
                  future: Future.wait(
                    docs.map((doc) async {
                      final data = doc.data() as Map<String, dynamic>;
                      final uid = (data['uid'] ?? doc.id).toString().trim();

                      final isDeleted = await _isUserDeleted(uid);
                      return isDeleted ? null : doc;
                    }),
                  ).then(
                    (list) => list.whereType<QueryDocumentSnapshot>().toList(),
                  ),
                  builder: (context, filteredSnapshot) {
                    if (filteredSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final validDocs = filteredSnapshot.data ?? [];

                    if (validDocs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: validDocs.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.78,
                      ),
                      itemBuilder: (context, index) {
                        final rawData =
                            validDocs[index].data() as Map<String, dynamic>;

                        final data = {
                          'docId': validDocs[index].id,
                          'uid': rawData['uid'] ?? validDocs[index].id,
                          ...rawData,
                        };

                        return _buildUserCard(data, context);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'group_chat_page.dart';
import 'group_data.dart';
import 'group_detail_page.dart';

class GroupPage extends StatelessWidget {
  final String languageCode;

  const GroupPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  User? get currentUser => FirebaseAuth.instance.currentUser;

  String _label(String vi, String en) => isVi ? vi : en;

  Future<bool> _hasActiveMembership(String groupId) async {
    final user = currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(user.uid)
        .get();

    if (!doc.exists) return false;

    final data = doc.data() ?? {};
    final membershipActive = data['membershipActive'] == true;
    final expiresAt = data['expiresAt'] as Timestamp?;

    if (!membershipActive || expiresAt == null) return false;

    return expiresAt.toDate().isAfter(DateTime.now());
  }

  Future<bool> _hasAnyMembershipDoc(String groupId) async {
    final user = currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(user.uid)
        .get();

    return doc.exists;
  }

  Future<void> _onTapGroup(
    BuildContext context,
    DatingGroupItem group,
  ) async {
    final active = await _hasActiveMembership(group.id);

    if (!context.mounted) return;

    if (active) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatPage(
            languageCode: languageCode,
            group: group,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailPage(
          languageCode: languageCode,
          group: group,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _membershipData(String groupId) async {
    final user = currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(user.uid)
        .get();

    return doc.data();
  }

  String _statusText(Map<String, dynamic>? data) {
    if (data == null) {
      return _label('Chưa tham gia', 'Not joined');
    }

    final membershipActive = data['membershipActive'] == true;
    final expiresAt = data['expiresAt'] as Timestamp?;

    if (membershipActive &&
        expiresAt != null &&
        expiresAt.toDate().isAfter(DateTime.now())) {
      return _label('Đang hoạt động', 'Active');
    }

    return _label('Đã hết hạn', 'Expired');
  }

  Color _statusColor(Map<String, dynamic>? data) {
    if (data == null) {
      return const Color(0xFF8E8E93);
    }

    final membershipActive = data['membershipActive'] == true;
    final expiresAt = data['expiresAt'] as Timestamp?;

    if (membershipActive &&
        expiresAt != null &&
        expiresAt.toDate().isAfter(DateTime.now())) {
      return const Color(0xFF2E9B63);
    }

    return const Color(0xFFE05A5A);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFDDEA),
            Color(0xFFFFEFF5),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                _label(
                  'Tham gia các nhóm để kết nối, làm quen và cùng nhau tận hưởng những điều bạn yêu thích.',
                  'Join groups to connect, get to know each other, and enjoy the things you love together.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6F72C9),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: kDatingGroups.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.58,
                ),
                itemBuilder: (context, index) {
                  final group = kDatingGroups[index];

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _membershipData(group.id),
                    builder: (context, snapshot) {
                      final data = snapshot.data;
                      final statusText = _statusText(data);
                      final statusColor = _statusColor(data);

                      return GestureDetector(
                        onTap: () => _onTapGroup(context, group),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        group.imageAsset,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) {
                                          return Container(
                                            color: Colors.grey.shade200,
                                            alignment: Alignment.center,
                                            child: Icon(
                                              group.icon,
                                              size: 38,
                                              color: const Color(0xFF6F72C9),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.95),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              group.title(isVi),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w600,
                                color: Color.fromARGB(221, 76, 83, 209),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              group.subtitle(isVi),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.25,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'language_exchange_group_chat_page.dart';
import 'group_data1.dart';

class LanguageExchangePage extends StatelessWidget {
  final String languageCode;

  const LanguageExchangePage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _label(String vi, String en) => isVi ? vi : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF6D6D6D),
        centerTitle: true,
        title: Text(
          _label('Trao đổi ngôn ngữ', 'Language Exchange'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF555555),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
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
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          itemCount: kDatingGroups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 18),
          itemBuilder: (context, index) {
            final group = kDatingGroups[index];

            return _LanguageGroupCard(
              languageCode: languageCode,
              group: group,
            );
          },
        ),
      ),
    );
  }
}

class _LanguageGroupCard extends StatelessWidget {
  final String languageCode;
  final DatingGroupItem group;

  const _LanguageGroupCard({
    required this.languageCode,
    required this.group,
  });

  bool get isVi => languageCode == 'vi';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LanguageExchangeDetailPage(
              languageCode: languageCode,
              group: group,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Image.asset(
                group.imageAsset,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    height: 190,
                    color: const Color(0xFFF1F3FF),
                    alignment: Alignment.center,
                    child: Icon(
                      group.icon,
                      size: 64,
                      color: const Color(0xFF6F72C9),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title(isVi),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    group.subtitle(isVi),
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.public_rounded,
                        size: 18,
                        color: Color(0xFF5D74D3),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        isVi ? '' : '',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5D74D3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LanguageExchangeDetailPage extends StatefulWidget {
  final String languageCode;
  final DatingGroupItem group;

  const LanguageExchangeDetailPage({
    super.key,
    required this.languageCode,
    required this.group,
  });

  @override
  State<LanguageExchangeDetailPage> createState() =>
      _LanguageExchangeDetailPageState();
}

class _LanguageExchangeDetailPageState
    extends State<LanguageExchangeDetailPage> {
  bool _loading = true;
  bool _joining = false;
  bool _hasJoined = false;
  Map<String, dynamic>? _membershipData;

  bool get isVi => widget.languageCode == 'vi';

  String _label(String vi, String en) => isVi ? vi : en;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>? get _memberRef {
    final user = currentUser;
    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.group.id)
        .collection('members')
        .doc(user.uid);
  }

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    final ref = _memberRef;

    if (ref == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasJoined = false;
      });
      return;
    }

    try {
      final doc = await ref.get();

      if (!mounted) return;

      setState(() {
        _membershipData = doc.data();
        _hasJoined = doc.exists &&
            (_membershipData?['membershipActive'] == true);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load free group membership error: $e');

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _joinGroup() async {
    final user = currentUser;
    final ref = _memberRef;

    if (user == null || ref == null || _joining) return;

    setState(() {
      _joining = true;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      final data = <String, dynamic>{
        'uid': user.uid,
        'userId': user.uid,
        'email': user.email ?? '',
        'firstName': (userData['firstName'] ?? '').toString(),
        'mainPhotoUrl': (userData['mainPhotoUrl'] ?? '').toString(),
        'membershipActive': true,
        'freeGroup': true,
        'groupId': widget.group.id,
        'joinedAt': FieldValue.serverTimestamp(),
      };

      await ref.set(data, SetOptions(merge: true));

      final freshDoc = await ref.get();
      final membership = freshDoc.data() ?? data;

      if (!mounted) return;

      setState(() {
        _hasJoined = true;
        _membershipData = membership;
        _joining = false;
      });

      _openGroupChat();
    } catch (e) {
      debugPrint('Join free language group error: $e');

      if (!mounted) return;

      setState(() {
        _joining = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Không thể tham gia nhóm lúc này. Vui lòng thử lại.',
              'Could not join the group right now. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  void _openGroupChat() {
    final user = currentUser;
    if (user == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LanguageExchangeGroupChatPage(
          languageCode: widget.languageCode,
          group: widget.group,
          currentUserMembership: _membershipData,
          currentUserGroupId: widget.group.id,
          currentUserEmail: user.email,
          currentUserUid: user.uid,
          currentUserHasJoined: true,
          currentUserIsActive: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.group.title(isVi);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF6D6D6D),
        centerTitle: true,
        title: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF555555),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        widget.group.imageAsset,
                        height: 260,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            height: 260,
                            color: const Color(0xFFF1F3FF),
                            alignment: Alignment.center,
                            child: Icon(
                              widget.group.icon,
                              size: 70,
                              color: const Color(0xFF6F72C9),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.group.detailTitle(isVi),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.public_rounded,
                                  size: 18,
                                  color: Color(0xFF5D74D3),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  _label(
                                    '',
                                    '',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF5D74D3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            widget.group.detailBody(isVi),
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.55,
                              color: Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _joining
                                  ? null
                                  : (_hasJoined
                                      ? _openGroupChat
                                      : _joinGroup),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF5D74D3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _joining
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _hasJoined
                                          ? _label(
                                              'Vào nhóm chat',
                                              'Open group chat',
                                            )
                                          : _label(
                                              'Tham gia miễn phí',
                                              'Join for Free',
                                            ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

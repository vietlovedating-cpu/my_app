import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'group_data.dart';
import 'group_detail_page.dart';
import 'view_other_profile_page.dart';

class GroupChatPage extends StatefulWidget {
  final String languageCode;
  final DatingGroupItem group;

  final Map<String, dynamic>? currentUserMembership;
  final String? currentUserGroupId;
  final String? currentUserEmail;
  final String? currentUserUid;
  final bool currentUserHasJoined;
final bool currentUserIsActive;

  const GroupChatPage({
  super.key,
  required this.languageCode,
  required this.group,
  this.currentUserMembership,
  this.currentUserGroupId,
  this.currentUserEmail,
  this.currentUserUid,
  this.currentUserHasJoined = false,
  this.currentUserIsActive = false,
});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

Map<String, dynamic>? _myMembershipData;

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  bool _membershipLoading = true;
  bool _hasActiveMembership = false;
  Map<String, dynamic>? _myMembershipData;
  Set<String> _deletedUserIds = {};

  bool get isVi => widget.languageCode == 'vi';
  User? get currentUser => FirebaseAuth.instance.currentUser;

  String _label(String vi, String en) => isVi ? vi : en;
  Future<String> _translateGroupMessage({
  required String text,
  required String target,
}) async {
  try {
    final uri = Uri.parse(
      'https://us-central1-flutter-vietlove-dating.cloudfunctions.net/autoTranslatePrompts',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'target': target,
      }),
    );

    debugPrint('GROUP TRANSLATE STATUS: ${response.statusCode}');
    debugPrint('GROUP TRANSLATE BODY: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['translatedText'] ?? '').toString().trim();
    }

    return '';
  } catch (e) {
    debugPrint('GROUP TRANSLATE ERROR: $e');
    return '';
  }
}

  CollectionReference<Map<String, dynamic>> get _membersRef =>
      FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.id)
          .collection('members');

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.id)
          .collection('messages');

  @override
void initState() {
  super.initState();
  _loadMembership();
  _loadDeletedUsers();
}
  Future<void> _loadMembership() async {
    final user = currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _membershipLoading = false;
        _hasActiveMembership = false;
      });
      return;
    }

    final doc = await _membersRef.doc(user.uid).get();
    final data = doc.data();

    bool active = false;
    if (data != null) {
  final membershipActive = data['membershipActive'] == true;
  final expiresAt = data['expiresAt'] as Timestamp?;

  final isExpired = expiresAt == null ||
      expiresAt.toDate().isBefore(DateTime.now());

  if (membershipActive && isExpired) {
    await _membersRef.doc(user.uid).set({
      'membershipActive': false,
    }, SetOptions(merge: true));
  }

  active = membershipActive && !isExpired;
}

    if (!mounted) return;
    setState(() {
      _myMembershipData = data;
      _hasActiveMembership = active;
      _membershipLoading = false;
    });
  }
Future<void> _loadDeletedUsers() async {
  try {
    final idsToCheck = <String>{};

    final membersSnapshot = await _membersRef.get();
    for (final doc in membersSnapshot.docs) {
      idsToCheck.add(doc.id);

      final data = doc.data();
      final uid = (data['uid'] ?? data['userId'] ?? '').toString().trim();

      if (uid.isNotEmpty) {
        idsToCheck.add(uid);
      }
    }

    final messagesSnapshot = await _messagesRef.limit(300).get();
    for (final doc in messagesSnapshot.docs) {
      final data = doc.data();
      final senderId = (data['senderId'] ?? '').toString().trim();

      if (senderId.isNotEmpty) {
        idsToCheck.add(senderId);
      }
    }

    final deletedIds = <String>{};

    for (final uid in idsToCheck) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        deletedIds.add(uid);
      }
    }

    if (!mounted) return;

    setState(() {
      _deletedUserIds = deletedIds;
    });
  } catch (e) {
    debugPrint('Load deleted users error: $e');
  }
}

  Future<bool> _checkMembershipBeforeAction() async {
    await _loadMembership();

    if (_hasActiveMembership) return true;

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _label(
            'Gói nhóm của bạn đã hết hạn. Vui lòng gia hạn để tiếp tục.',
            'Your group plan has expired. Please renew to continue.',
          ),
        ),
      ),
    );
    return false;
  }

  Future<void> _sendTextMessage() async {
    final user = currentUser;
    if (user == null) return;

    final allowed = await _checkMembershipBeforeAction();
    if (!allowed) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data() ?? {};
    final firstName = (userData['firstName'] ?? '').toString().trim();
    final mainPhotoUrl = (userData['mainPhotoUrl'] ?? '').toString().trim();

    if (!mounted) return;
    setState(() {
      _isSending = true;
    });

    try {
  String textVi = '';
  String textEn = '';

  if (isVi) {
    textVi = text;

    textEn = await _translateGroupMessage(
      text: text,
      target: 'en',
    );

    if (textEn.isEmpty) {
      textEn = text;
    }
  } else {
    textEn = text;

    textVi = await _translateGroupMessage(
      text: text,
      target: 'vi',
    );

    if (textVi.isEmpty) {
      textVi = text;
    }
  }

  await _messagesRef.add({
    'senderId': user.uid,
    'senderName': firstName,
    'senderPhotoUrl': mainPhotoUrl,

    'text': text,
    'textVi': textVi,
    'textEn': textEn,

    'imageUrl': '',
    'type': 'text',
    'createdAt': FieldValue.serverTimestamp(),
  });

  _messageController.clear();
  _scrollToBottom();
} finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final user = currentUser;
    if (user == null) return;

    final allowed = await _checkMembershipBeforeAction();
    if (!allowed) return;

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data() ?? {};
    final firstName = (userData['firstName'] ?? '').toString().trim();
    final mainPhotoUrl = (userData['mainPhotoUrl'] ?? '').toString().trim();

    if (!mounted) return;
    setState(() {
      _isSending = true;
    });

    try {
      final file = File(picked.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('group_messages')
          .child(widget.group.id)
          .child(fileName);

      await storageRef.putFile(file);
      final imageUrl = await storageRef.getDownloadURL();

      await _messagesRef.add({
        'senderId': user.uid,
        'senderName': firstName,
        'senderPhotoUrl': mainPhotoUrl,
        'text': '',
        'imageUrl': imageUrl,
        'type': 'image',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(
      _scrollController.position.maxScrollExtent,
    );
  });
}

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month  $hour:$minute';
  }

  String _expiryText() {
    final data = _myMembershipData;
    if (data == null) return '';

    final expiresAt = data['expiresAt'] as Timestamp?;
    if (expiresAt == null) return '';

    final dt = expiresAt.toDate();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _buildMemberAvatar(Map<String, dynamic> data) {
  final userId = (data['userId'] ?? data['uid'] ?? '').toString().trim();

  if (userId.isEmpty) {
    return const SizedBox.shrink();
  }

  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || !snapshot.data!.exists) {
        return const SizedBox.shrink();
      }

      final userData = snapshot.data!.data() ?? {};

      final isDeleted =
          userData['isDeleted'] == true ||
          userData['deleted'] == true ||
          userData['accountDeleted'] == true ||
          userData['status'] == 'deleted';

      final profileComplete =
          userData['profileComplete'] == true ||
          userData['isProfileComplete'] == true ||
          userData['profileCompleted'] == true;

      if (isDeleted || !profileComplete) {
        return const SizedBox.shrink();
      }

      final photo =
          (userData['mainPhotoUrl'] ?? '').toString().trim();

      final name =
          (userData['firstName'] ?? '').toString().trim();

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewOtherProfilePage(
                userId: userId,
                languageCode: widget.languageCode,
                hideLikeButton: true,
              ),
            ),
          );
        },
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.grey.shade300,
                backgroundImage:
                    photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? Text(
                        name.isNotEmpty
                            ? name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                name.isEmpty ? 'User' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF555555),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildMessageCard(Map<String, dynamic> data) {
    final user = currentUser;
    final senderId = (data['senderId'] ?? '').toString();
    final isMe = user != null && senderId == user.uid;

    final senderPhoto = (data['senderPhotoUrl'] ?? '').toString().trim();
    final senderName = (data['senderName'] ?? '').toString().trim();
    final rawText = (data['text'] ?? '').toString().trim();
final textVi = (data['textVi'] ?? '').toString().trim();
final textEn = (data['textEn'] ?? '').toString().trim();

final text = isVi
    ? (textVi.isNotEmpty ? textVi : rawText)
    : (textEn.isNotEmpty ? textEn : rawText);
    final imageUrl = (data['imageUrl'] ?? '').toString().trim();
    final timestamp = data['createdAt'] as Timestamp?;

    final avatar = GestureDetector(
      onTap: () {
        if (senderId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewOtherProfilePage(
              userId: senderId,
              languageCode: widget.languageCode,
              hideLikeButton: true,
            ),
          ),
        );
      },
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: senderPhoto.isNotEmpty ? NetworkImage(senderPhoto) : null,
        child: senderPhoto.isEmpty
            ? Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              )
            : null,
      ),
    );

    final bubble = Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isMe && senderName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 6, right: 6),
            child: Text(
              senderName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF777777),
              ),
            ),
          ),
        if (text.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF5D74D3) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              border: isMe
                  ? null
                  : Border.all(color: const Color.fromARGB(255, 93, 116, 211)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : const Color(0xFF444444),
              ),
            ),
          ),
        if (imageUrl.isNotEmpty) ...[
          if (text.isNotEmpty) const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                height: 190,
                width: 260,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 190,
                    width: 260,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey.shade500,
                      size: 34,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        if (timestamp != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
            child: Text(
              _formatTime(timestamp),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9A9A9A),
              ),
            ),
          ),
      ],
    );

    return Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: Row(
    mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: isMe
        ? [
            Flexible(child: bubble),
            const SizedBox(width: 8),
            avatar,
          ]
        : [
            avatar,
            const SizedBox(width: 8),
            Flexible(child: bubble),
          ],
  ),
);
  }

  Widget _buildExpiredBanner() {
    if (_membershipLoading || _hasActiveMembership) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD0D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_clock_rounded,
            color: Color(0xFFE05A5A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(
                    'Gói nhóm đã hết hạn',
                    'Group plan expired',
                  ),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE05A5A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _myMembershipData == null
                      ? _label(
                          'Bạn chưa tham gia nhóm này. Vui lòng mua gói để chat.',
                          'You have not joined this group. Please purchase a plan to chat.',
                        )
                      : _label(
                          'Ngày hết hạn: ${_expiryText()}. Vui lòng gia hạn để tiếp tục nhắn tin và gửi ảnh.',
                          'Expiry date: ${_expiryText()}. Please renew to continue chatting and sending images.',
                        ),
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Color(0xFF7A4E4E),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailPage(
                            languageCode: widget.languageCode,
                            group: widget.group,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D74D3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _label('Gia hạn ngay', 'Renew now'),
                      style: const TextStyle(
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
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupTitle = widget.group.title(isVi);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF6D6D6D),
        centerTitle: true,
        title: Text(
  groupTitle,
  textAlign: TextAlign.center,
  maxLines: 2,
  softWrap: true,
  overflow: TextOverflow.visible,
  style: const TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 16,
    color: Color(0xFF555555),
  ),
),
      ),
      body: Container(
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildExpiredBanner(),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
  stream: _membersRef.snapshots(),
  builder: (context, snapshot) {
    final now = DateTime.now();
    final allDocs = snapshot.data?.docs ?? [];

    final docs = allDocs.where((doc) {
  final data = doc.data();

  final membershipActive = data['membershipActive'] == true;
  final expiresAt = data['expiresAt'] as Timestamp?;

  final isDeleted = data['isDeleted'] == true ||
      data['deleted'] == true ||
      data['accountDeleted'] == true ||
      data['status'] == 'deleted';

  final userId = doc.id;

return !_deletedUserIds.contains(userId) &&
    !isDeleted &&
    membershipActive &&
    expiresAt != null &&
    expiresAt.toDate().isAfter(now);
}).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 86,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDCE4FF)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: docs.isEmpty
            ? Center(
                child: Text(
                  _label(
                    'Chưa có thành viên đang hoạt động',
                    'No active members yet',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF888888),
                  ),
                ),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return Center(
                    child: _buildMemberAvatar(docs[index].data()),
                  );
                },
              ),
      ),
    );
  },
),
                  const SizedBox(height: 14),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _messagesRef
                          .orderBy('createdAt', descending: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final allMessageDocs = snapshot.data?.docs ?? [];

final docs = allMessageDocs.where((doc) {
  final data = doc.data();
  final senderId = (data['senderId'] ?? '').toString().trim();

  if (senderId.isEmpty) return true;

  return !_deletedUserIds.contains(senderId);
}).toList();
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!_scrollController.hasClients) return;
  _scrollController.jumpTo(
    _scrollController.position.maxScrollExtent,
  );
});
if (docs.isEmpty) {
                          return Center(
                            child: Text(
                              _label(
                                'Chưa có tin nhắn nào',
                                'No messages yet',
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF999999),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            return _buildMessageCard(docs[index].data());
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: SafeArea(
                      top: false,
                      child: Opacity(
                        opacity: _hasActiveMembership ? 1 : 0.65,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF5D74D3),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: (_isSending || !_hasActiveMembership)
                                    ? null
                                    : _pickAndSendImage,
                                icon: const Icon(
                                  Icons.image_outlined,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFE0E0E0),
                                  ),
                                ),
                                child: TextField(
                                  controller: _messageController,
                                  minLines: 1,
                                  maxLines: 4,
                                  enabled: _hasActiveMembership,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) {
                                    if (!_isSending && _hasActiveMembership) {
                                      _sendTextMessage();
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: _hasActiveMembership
                                        ? _label(
                                            'Nhập tin nhắn...',
                                            'Type a message...',
                                          )
                                        : _label(
                                            'Gia hạn để tiếp tục nhắn tin...',
                                            'Renew to continue chatting...',
                                          ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF5D74D3),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: (_isSending || !_hasActiveMembership)
                                    ? null
                                    : _sendTextMessage,
                                icon: _isSending
    ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
    : const Icon(
        Icons.send_rounded,
        color: Colors.white,
        size: 20,
      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
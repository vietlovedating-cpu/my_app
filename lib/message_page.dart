import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'view_other_profile_page.dart';

class MessagePage extends StatefulWidget {
  final String languageCode;
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhotoUrl;

  const MessagePage({
    super.key,
    required this.languageCode,
    required this.chatId,
    required this.otherUserId,
    
    required this.otherUserName,
    required this.otherUserPhotoUrl,
    
  });

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  
  bool _isSendingImage = false;

File? _pendingImageFile;

  String _currentUserPhotoUrl = '';
  String _currentUserName = '';

  String _otherUserPhotoUrl = '';
  String _otherUserName = '';

  bool get isVi => widget.languageCode == 'vi';

  String get _effectiveOtherUserPhotoUrl {
    if (_otherUserPhotoUrl.trim().isNotEmpty) return _otherUserPhotoUrl.trim();
    return widget.otherUserPhotoUrl.trim();
  }

  String get _effectiveOtherUserName {
    if (_otherUserName.trim().isNotEmpty) return _otherUserName.trim();
    return widget.otherUserName.trim();
  }

  String _tr(String vi, String en) => isVi ? vi : en;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
    _loadOtherUserInfo();
    _markIncomingMessagesAsRead();
    
  }

  @override
void dispose() {
  _messageController.dispose();
  _scrollController.dispose();
  super.dispose();
}

  Future<void> _loadCurrentUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      if (!mounted) return;
      setState(() {
        _currentUserPhotoUrl = (data['mainPhotoUrl'] ?? '').toString().trim();
        _currentUserName = (data['firstName'] ?? '').toString().trim();
      });
    } catch (_) {}
  }

  Future<void> _loadOtherUserInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      final data = doc.data() ?? {};

      if (!mounted) return;
      setState(() {
        _otherUserPhotoUrl = (data['mainPhotoUrl'] ?? '').toString().trim();
        _otherUserName = (data['firstName'] ?? '').toString().trim();
      });
    } catch (_) {}
  }

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
void _onMessageChanged(String value) {}
  
  Future<void> _markIncomingMessagesAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final unreadMessages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unreadMessages.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
  final user = FirebaseAuth.instance.currentUser;
  final text = _messageController.text.trim();

  if (user == null || text.isEmpty) return;

  _messageController.clear();

  final firestore = FirebaseFirestore.instance;
final blockedDoc = await firestore
    .collection('users')
    .doc(user.uid)
    .collection('blockedUsers')
    .doc(widget.otherUserId)
    .get();

if (blockedDoc.exists) {
  if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(
      _tr(
        'Đã chặn người dùng này',
        'You blocked this user',
      ),
    ),
  ),
);

if (Navigator.canPop(context)) {
  Navigator.of(context).pop();
}

  return;
}
  await firestore
      .collection('chats')
      .doc(widget.chatId)
      .collection('messages')
      .add({
    'senderId': user.uid,
    'receiverId': widget.otherUserId,
    'senderName': _currentUserName,
    'senderPhotoUrl': _currentUserPhotoUrl,
    'text': text,
    'type': 'text',
    'imageUrl': '',
    'createdAt': FieldValue.serverTimestamp(),
    'isRead': false,
  });

  await firestore.collection('chats').doc(widget.chatId).set({
    'chatId': widget.chatId,
    'participants': [user.uid, widget.otherUserId],
    'lastMessage': text,
    'lastMessageType': 'text',
    'lastSenderId': user.uid,
    'updatedAt': FieldValue.serverTimestamp(),
    'typing': {
      user.uid: false,
      widget.otherUserId: false,
    },
  }, SetOptions(merge: true));

  await firestore.collection('matches').doc(widget.chatId).set({
    'lastMessage': text,
    'lastMessageAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));


WidgetsBinding.instance.addPostFrameCallback((_) {
  _scrollToBottom();
});
}
Future<void> _pickImageOnly() async {
  final XFile? pickedFile = await _imagePicker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 75,
  );

  if (pickedFile == null) return;

  setState(() {
    _pendingImageFile = File(pickedFile.path);
  });
}
Future<void> _sendPendingImage() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null || _pendingImageFile == null || _isSendingImage) {
    return;
  }

  try {
    setState(() {
      _isSendingImage = true;
    });

    final file = _pendingImageFile!;

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('chat_images')
        .child(widget.chatId)
        .child(fileName);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
    );

    await storageRef.putFile(file, metadata);

    final imageUrl = await storageRef.getDownloadURL();

    final firestore = FirebaseFirestore.instance;

    await firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': user.uid,
      'receiverId': widget.otherUserId,
      'senderName': _currentUserName,
      'senderPhotoUrl': _currentUserPhotoUrl,
      'text': '',
      'type': 'image',
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await firestore.collection('chats').doc(widget.chatId).set({
      'chatId': widget.chatId,
      'participants': [user.uid, widget.otherUserId],
      'lastMessage': _tr('Đã gửi một ảnh', 'Sent a photo'),
      'lastMessageType': 'image',
      'lastSenderId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'typing': {
        user.uid: false,
        widget.otherUserId: false,
      },
    }, SetOptions(merge: true));

    await firestore.collection('matches').doc(widget.chatId).set({
      'lastMessage': _tr('Đã gửi một ảnh', 'Sent a photo'),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() {
      _pendingImageFile = null;
    });

    _scrollToBottom();
  } catch (e) {
    debugPrint('SEND IMAGE ERROR: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Send image error: $e'),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isSendingImage = false;
      });
    }
  }
}

  Future<void> _pickAndSendImage() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || _isSendingImage) return;

  try {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (pickedFile == null) return;

    setState(() {
      _isSendingImage = true;
    });

    final file = File(pickedFile.path);

    if (!await file.exists()) {
      throw Exception('Picked file does not exist: ${pickedFile.path}');
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('chat_images')
        .child(widget.chatId)
        .child(fileName);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
    );

    final uploadTask = await storageRef.putFile(file, metadata);

    debugPrint('UPLOAD STATE: ${uploadTask.state}');
    debugPrint('UPLOAD PATH: ${storageRef.fullPath}');

    final imageUrl = await storageRef.getDownloadURL();
    debugPrint('DOWNLOAD URL: $imageUrl');

    final firestore = FirebaseFirestore.instance;

    await firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': user.uid,
      'receiverId': widget.otherUserId,
      'senderName': _currentUserName,
      'senderPhotoUrl': _currentUserPhotoUrl,
      'text': '',
      'type': 'image',
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await firestore.collection('chats').doc(widget.chatId).set({
      'chatId': widget.chatId,
      'participants': [user.uid, widget.otherUserId],
      'lastMessage': _tr('Đã gửi một ảnh', 'Sent a photo'),
      'lastMessageType': 'image',
      'lastSenderId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'typing': {
        user.uid: false,
        widget.otherUserId: false,
      },
    }, SetOptions(merge: true));

    await firestore.collection('matches').doc(widget.chatId).set({
      'lastMessage': _tr('Đã gửi một ảnh', 'Sent a photo'),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await Future.delayed(const Duration(milliseconds: 100));
    _scrollToBottom();
  } on FirebaseException catch (e) {
    debugPrint('FIREBASE ERROR CODE: ${e.code}');
    debugPrint('FIREBASE ERROR MESSAGE: ${e.message}');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Firebase error: ${e.code}'),
      ),
    );
  } catch (e) {
    debugPrint('SEND IMAGE ERROR: $e');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Send image error: $e'),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isSendingImage = false;
      });
    }
  }
}

  void _scrollToBottom() {
  if (!_scrollController.hasClients) return;
  _scrollController.jumpTo(0);
}

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
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

  Widget _buildAvatar(String imageUrl, {double radius = 18}) {
    final raw = imageUrl.trim();

    if (raw.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: Icon(
          Icons.person,
          size: radius,
          color: Colors.grey,
        ),
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
              ? Icon(
                  Icons.person,
                  size: radius,
                  color: Colors.grey,
                )
              : null,
        );
      },
    );
  }

 Widget _buildTypingIndicator() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
    child: Row(
      children: [
        _buildAvatar(_effectiveOtherUserPhotoUrl, radius: 16),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD5E6)),
          ),
          child: Text(
            _tr('đang nhập...', 'typing...'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildBubbleContent({
    required String type,
    required String text,
    required String imageUrl,
    required bool isMe,
  }) {
    if (type == 'image' && imageUrl.isNotEmpty) {
      return FutureBuilder<String?>(
        future: _resolveImageUrl(imageUrl),
        builder: (context, snapshot) {
          final resolvedUrl = snapshot.data;

          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              width: 220,
              height: 260,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (resolvedUrl == null || resolvedUrl.isEmpty) {
            return Container(
              width: 220,
              height: 120,
              alignment: Alignment.center,
              color: Colors.grey.shade200,
              child: Text(
                _tr('Không tải được ảnh', 'Image failed to load'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    child: InteractiveViewer(
                      child: Image.network(
                        resolvedUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              },
              child: Image.network(
                resolvedUrl,
                width: 220,
                height: 260,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    width: 220,
                    height: 120,
                    alignment: Alignment.center,
                    color: Colors.grey.shade200,
                    child: Text(
                      _tr('Không tải được ảnh', 'Image failed to load'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    }

    if (type == 'heart') {
      return const Text(
        '❤️',
        style: TextStyle(fontSize: 34),
      );
    }

    return Text(
      text,
      style: TextStyle(
        color: isMe ? Colors.white : Colors.black87,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );
  }

  Widget _buildMessageBubble({
  required bool isMe,
  required String text,
  required String type,
  required String imageUrl,
  required String timeText,
  required String avatarUrl,
  required bool isRead,
}) {
  final isHeart = type == 'heart';
  final isImage = type == 'image';

  final avatarWidget = _buildAvatar(
    avatarUrl,
    radius: 18,
  );

  final bubble = Column(
    crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Container(
        constraints: const BoxConstraints(maxWidth: 270),
        padding: isHeart
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
            : isImage
                ? const EdgeInsets.all(4)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: isHeart
            ? null
            : BoxDecoration(
                color: isMe
                    ? const Color(0xFFE91E63)
                    : const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 6),
                  bottomRight: Radius.circular(isMe ? 6 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isMe
                    ? null
                    : Border.all(color: const Color(0xFFFFD5E6)),
              ),
        child: _buildBubbleContent(
          type: type,
          text: text,
          imageUrl: imageUrl,
          isMe: isMe,
        ),
      ),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (timeText.isNotEmpty)
              Text(
                timeText,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (isMe && timeText.isNotEmpty) const SizedBox(width: 6),
            if (isMe)
              Text(
                isRead ? _tr('Đã xem', 'Seen') : _tr('Đã gửi', 'Sent'),
                style: TextStyle(
                  fontSize: 11,
                  color: isRead ? const Color(0xFFE91E63) : Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    ],
  );

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment:
          isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: isMe
          ? [
              Flexible(child: bubble),
              const SizedBox(width: 8),
              avatarWidget,
            ]
          : [
              avatarWidget,
              const SizedBox(width: 8),
              Flexible(child: bubble),
            ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF8A2F6A)),
        titleSpacing: 0,
        title: GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewOtherProfilePage(
          userId: widget.otherUserId,
          languageCode: widget.languageCode,
        ),
      ),
    );
  },
  child: Row(
    children: [
      _buildAvatar(_effectiveOtherUserPhotoUrl, radius: 16),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          _effectiveOtherUserName.isNotEmpty
              ? _effectiveOtherUserName
              : _tr('Người dùng', 'User'),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF8A2F6A),
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
    ],
  ),
),
        actions: [
  PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert),
    onSelected: (value) async {
      if (value == 'block') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              _tr(
                'Chặn người dùng?',
                'Block this user?',
              ),
            ),
            content: Text(
              _tr(
                'Bạn có chắc muốn chặn người dùng này không?',
                'Are you sure you want to block this user?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_tr('Không', 'No')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_tr('Có', 'Yes')),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        final currentUser =
            FirebaseAuth.instance.currentUser;

        if (currentUser == null) return;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('blockedUsers')
            .doc(widget.otherUserId)
            .set({
          'blockedAt': FieldValue.serverTimestamp(),
          'userId': widget.otherUserId,
          'name': _effectiveOtherUserName,
          'photoUrl': _effectiveOtherUserPhotoUrl,
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                'Đã chặn người dùng này',
                'You blocked this user',
              ),
            ),
          ),
        );

        Navigator.pop(context);
      }
    },
    itemBuilder: (context) => [
      PopupMenuItem(
        value: 'block',
        child: Text(
          _tr(
            'Chặn người dùng',
            'Block User',
          ),
        ),
      ),
    ],
  ),
],
      ),
      body: Column(
        children: [
          Expanded(
  child: StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      if (snapshot.hasError) {
        return Center(
          child: Text(
            _tr('Có lỗi xảy ra.', 'Something went wrong.'),
          ),
        );
      }

      final docs = snapshot.data?.docs ?? [];

      if (docs.isEmpty) {
        return Center(
          child: Text(
            _tr(
              'Hãy bắt đầu cuộc trò chuyện.',
              'Start the conversation.',
            ),
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }

      return ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final data = docs[index].data() as Map<String, dynamic>;

          final senderId = (data['senderId'] ?? '').toString();
          final text = (data['text'] ?? '').toString();
          final type = (data['type'] ?? 'text').toString();
          final imageUrl = (data['imageUrl'] ?? '').toString();
          final timestamp = data['createdAt'] as Timestamp?;
          final isRead = data['isRead'] == true;
          final isMe = senderId == currentUser?.uid;

          final senderPhotoUrl =
              (data['senderPhotoUrl'] ?? '').toString().trim();

          final avatarUrl = isMe
              ? (_currentUserPhotoUrl.isNotEmpty
                  ? _currentUserPhotoUrl
                  : senderPhotoUrl)
              : (senderPhotoUrl.isNotEmpty
                  ? senderPhotoUrl
                  : _effectiveOtherUserPhotoUrl);

          return _buildMessageBubble(
  isMe: isMe,
  text: text,
  type: type,
  imageUrl: imageUrl,
  timeText: _formatTime(timestamp),
  avatarUrl: avatarUrl,
  isRead: isMe ? isRead : false,
);
        },
      );
    },
  ),
),
         SafeArea(
  top: false,
  child: Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7FB),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
      
        if (_pendingImageFile != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFC7DE)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _pendingImageFile!,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _tr('Gửi ảnh này?', 'Send this photo?'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _pendingImageFile = null;
                    });
                  },
                  icon: const Icon(Icons.close, color: Colors.black54),
                ),
                IconButton(
  onPressed: _isSendingImage ? null : _sendPendingImage,
                  icon: const Icon(
                    Icons.check_circle,
                    color: Color(0xFFE91E63),
                  ),
                ),
              ],
            ),
          ),

        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              onTap: _isSendingImage ? null : _pickImageOnly,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4EF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFC7DE)),
                ),
                child: _isSendingImage
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.image_outlined,
                        color: Color(0xFFE91E63),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _messageController,
                onChanged: _onMessageChanged,
                onSubmitted: (_) => _sendMessage(),
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: _tr('Nhập tin nhắn...', 'Type a message...'),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFD5E6),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: Color(0xFFE91E63),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
  if (_pendingImageFile != null) {
    _sendPendingImage();
  } else {
    _sendMessage();
  }
},
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE91E63),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
),
        ],
      ),
    );
  }
}
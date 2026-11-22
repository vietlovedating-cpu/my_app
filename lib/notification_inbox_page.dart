import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'match_page.dart';
import 'message_page.dart';
import 'upgrade_vip_page.dart';

class NotificationInboxPage extends StatefulWidget {
  final String languageCode;

  const NotificationInboxPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<NotificationInboxPage> createState() =>
      _NotificationInboxPageState();
}

class _NotificationInboxPageState
    extends State<NotificationInboxPage> {
  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  CollectionReference<Map<String, dynamic>>? get _notificationsRef {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications');
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'vip_expiring':
      case 'vip_expired':
      case 'vip_7d':
      case 'vip_3d':
      case 'vip_1d':
        return Icons.workspace_premium_rounded;

      case 'match':
      case 'new_match':
        return Icons.favorite_rounded;

      case 'private_message':
      case 'new_message':
        return Icons.chat_bubble_rounded;

      case 'group_message':
      case 'new_group_message':
        return Icons.groups_rounded;

      case 'admin_message':
      case 'announcement':
      case 'system':
        return Icons.campaign_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'vip_expiring':
      case 'vip_expired':
      case 'vip_7d':
      case 'vip_3d':
      case 'vip_1d':
        return const Color(0xFFB8860B);

      case 'match':
      case 'new_match':
        return const Color(0xFFE63970);

      case 'private_message':
      case 'new_message':
        return const Color(0xFF5C6BC0);

      case 'group_message':
      case 'new_group_message':
        return const Color(0xFF269B83);

      case 'admin_message':
      case 'announcement':
      case 'system':
        return const Color(0xFFB83280);

      default:
        return const Color(0xFFB83280);
    }
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '';

    final date = value.toDate();
    final now = DateTime.now();

    final sameDay = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    if (sameDay) {
      final hour = date.hour == 0
          ? 12
          : date.hour > 12
              ? date.hour - 12
              : date.hour;

      final minute = date.minute.toString().padLeft(2, '0');

      return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _markAsRead(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    await ref.set({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _markAllAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final unread =
        docs.where((doc) => doc.data()['isRead'] != true);

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in unread) {
      batch.set(
        doc.reference,
        {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();

    final type =
        (data['type'] ?? '').toString().trim().toLowerCase();

    try {
      if (data['isRead'] != true) {
        await _markAsRead(doc.reference);
      }
    } catch (e) {
      debugPrint('Mark notification read error: $e');
    }

    if (!mounted) return;

    switch (type) {
      case 'vip_expiring':
      case 'vip_expired':
      case 'vip_7d':
      case 'vip_3d':
      case 'vip_1d':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UpgradeVipPage(
              languageCode: widget.languageCode,
              onPurchaseSuccess: () async {},
            ),
          ),
        );
        return;

      case 'match':
      case 'new_match':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchPage(
              languageCode: widget.languageCode,
            ),
          ),
        );
        return;

      case 'private_message':
      case 'new_message':
        final chatId =
            (data['chatId'] ?? '').toString().trim();

        final otherUserId =
            (data['otherUserId'] ?? '').toString().trim();

        if (chatId.isEmpty || otherUserId.isEmpty) {
          _showMessage(
            _tr(
              'Thông báo chưa có thông tin cuộc trò chuyện.',
              'This notification is missing chat details.',
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessagePage(
              languageCode: widget.languageCode,
              chatId: chatId,
              otherUserId: otherUserId,
              otherUserName:
                  (data['otherUserName'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty
                      ? data['otherUserName'].toString()
                      : _tr('Người dùng', 'User'),
              otherUserPhotoUrl:
                  (data['otherUserPhotoUrl'] ?? '').toString(),
            ),
          ),
        );
        return;

      case 'admin_message':
      case 'announcement':
      case 'system':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminNotificationDetailPage(
              languageCode: widget.languageCode,
              notification: data,
            ),
          ),
        );
        return;

      case 'group_message':
      case 'new_group_message':
        _showMessage(
          _tr(
            'Thông báo nhóm đã được đánh dấu đã đọc. Cần nối với trang Group Chat để mở đúng nhóm.',
            'Group notification marked as read. Group Chat navigation still needs to be connected.',
          ),
        );
        return;

      default:
        if ((data['action'] ?? '').toString() ==
            'upgrade_vip') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UpgradeVipPage(
                languageCode: widget.languageCode,
                onPurchaseSuccess: () async {},
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminNotificationDetailPage(
                languageCode: widget.languageCode,
                notification: data,
              ),
            ),
          );
        }
    }
  }
  @override
  Widget build(BuildContext context) {
    final ref = _notificationsRef;

    if (ref == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFF7FB),
          elevation: 0,
          centerTitle: true,
          title: Text(_tr('Thông báo', 'Inbox')),
        ),
        body: Center(
          child: Text(
            _tr(
              'Bạn chưa đăng nhập',
              'You are not logged in',
            ),
          ),
        ),
      );
    }

    final notificationsStream =
        ref.orderBy('createdAt', descending: true).snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),

      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FB),
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 70,

        title: Text(
          _tr('Thông báo', 'Inbox'),
          style: const TextStyle(
            color: Color(0xFF7A2E6E),
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: notificationsStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];

              if (!docs.any(
                (doc) => doc.data()['isRead'] != true,
              )) {
                return const SizedBox.shrink();
              }

              return IconButton(
                tooltip: _tr(
                  'Đánh dấu đã đọc tất cả',
                  'Mark all as read',
                ),
                onPressed: () async {
                  try {
                    await _markAllAsRead(docs);
                  } catch (e) {
                    _showMessage(
                      _tr(
                        'Không thể đánh dấu tất cả đã đọc.',
                        'Could not mark all as read.',
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.done_all_rounded,
                  color: Color(0xFFB83280),
                ),
              );
            },
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFCC3D7A),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _tr(
                    'Không thể tải thông báo. Vui lòng thử lại.',
                    'Could not load notifications. Please try again.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 58,
                    color: Colors.pink.shade200,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _tr(
                      'Bạn chưa có thông báo nào',
                      'No notifications yet',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF7A2E6E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final type =
                  (data['type'] ?? '').toString();

              final isRead = data['isRead'] == true;

              final title =
                  (data['title'] ?? '').toString().trim();

              final body =
                  (data['body'] ?? '').toString().trim();

              final color = _colorForType(type);

              final isAdminMessage =
                  type == 'admin_message' ||
                  type == 'announcement' ||
                  type == 'system';

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openNotification(doc),

                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isRead
                          ? const [
                              Color(0xFFFFF0F5),
                              Color(0xFFFFFFFF),
                            ]
                          : const [
                              Color(0xFFFFD6E7),
                              Color(0xFFFFF3F8),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),

                    borderRadius: BorderRadius.circular(18),

                    border: Border.all(
                      color: const Color(0xFFFFD6E7),
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.07),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconForType(type),
                          color: color,
                          size: 23,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title.isNotEmpty
                                        ? title
                                        : _tr(
                                            'Thông báo',
                                            'Notification',
                                          ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isRead
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                      color: const Color(
                                        0xFF48243B,
                                      ),
                                    ),
                                  ),
                                ),

                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration:
                                        const BoxDecoration(
                                      color: Color(0xFFE63970),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),

                            if (isAdminMessage) ...[
                              const SizedBox(height: 3),
                              Text(
                                _tr(
                                  'Từ VietLoveDating',
                                  'From VietLoveDating',
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFB83280),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],

                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  height: 1.35,
                                ),
                              ),
                            ],

                            const SizedBox(height: 7),

                            Text(
                              _formatTime(data['createdAt']),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Dedicated detail screen for Admin / system announcements.
/// This replaces the old AlertDialog without changing notification storage.
class AdminNotificationDetailPage extends StatelessWidget {
  final String languageCode;
  final Map<String, dynamic> notification;

  const AdminNotificationDetailPage({
    super.key,
    required this.languageCode,
    required this.notification,
  });

  bool get _isVi => languageCode == 'vi';

  String _tr(String vi, String en) => _isVi ? vi : en;

  String _formatDateTime(dynamic value) {
    if (value is! Timestamp) return '';

    final date = value.toDate().toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final title = (notification['title'] ?? '').toString().trim();
    final body = (notification['body'] ?? '').toString().trim();
    final sender = (notification['senderName'] ??
            notification['sender'] ??
            'VietLoveDating')
        .toString()
        .trim();
    final createdAt = _formatDateTime(notification['createdAt']);

    const primary = Color(0xFF9D347B);
    const background = Color(0xFFFFF7FB);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: _tr('Quay lại', 'Back'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: primary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _tr('Chi tiết thông báo', 'Notification'),
          style: const TextStyle(
            color: Color(0xFF7A2E6E),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE2EF), Color(0xFFFFF1F7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFD5E7)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Color(0xFFB83280),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _tr('THÔNG BÁO', 'ANNOUNCEMENT'),
                      style: const TextStyle(
                        color: Color(0xFFB83280),
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title.isEmpty
                          ? _tr('Thông báo', 'Announcement')
                          : title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF64264F),
                        fontSize: 23,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFF3DFE9)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9D347B).withOpacity(0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      body.isEmpty
                          ? _tr('Không có nội dung.', 'No message content.')
                          : body,
                      style: const TextStyle(
                        color: Color(0xFF44313F),
                        fontSize: 16,
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Divider(color: Color(0xFFF1E3EB), height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEAF3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFB83280),
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tr('Người gửi', 'From'),
                                style: const TextStyle(
                                  color: Colors.black45,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                sender.isEmpty ? 'VietLoveDating' : sender,
                                style: const TextStyle(
                                  color: Color(0xFF9D347B),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: Colors.black38,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            createdAt,
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 19),
                  label: Text(_tr('Quay lại hộp thư', 'Back to inbox')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB83280),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSettingsPage extends StatefulWidget {
  final String languageCode;

  const NotificationSettingsPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends State<NotificationSettingsPage> {
 bool messageNotifications = true;
bool groupMessageNotifications = true;

bool matchNotifications = true;
bool supportNotifications = true;

  bool isLoading = true;

  bool get isVi => widget.languageCode == 'vi';
  String _tr(String vi, String en) => isVi ? vi : en;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 🔥 LOAD từ Firebase
  Future<void> _loadSettings() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('settings')
        .doc('notifications')
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      messageNotifications = data['message'] ?? true;
groupMessageNotifications = data['groupMessage'] ?? true;

matchNotifications = data['match'] ?? true;
supportNotifications = data['support'] ?? true;
    }

    setState(() {
      isLoading = false;
    });
  }

  // 🔥 SAVE + APPLY NGAY
  Future<void> _updateSetting(String key, bool value) async {
    if (user == null) return;

    // update UI ngay
    setState(() {
      if (key == 'message') messageNotifications = value;
if (key == 'groupMessage') groupMessageNotifications = value;
if (key == 'match') matchNotifications = value;
if (key == 'support') supportNotifications = value;
    });

    // save Firebase
    await FirebaseFirestore.instance
    .collection('users')
    .doc(user!.uid)
    .collection('settings')
    .doc('notifications')
    .set({
  'message': messageNotifications,
  'groupMessage': groupMessageNotifications,
  'match': matchNotifications,
  'support': supportNotifications,
}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _tr('Thông báo', 'Notifications'),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _buildSwitchTile(
                  title: _tr('Thông báo tin nhắn', 'Message notifications'),
                  subtitle: _tr(
                    'Bật/tắt thông báo khi có tin nhắn mới',
                    'Turn on/off new message notifications',
                  ),
                  value: messageNotifications,
                  onChanged: (v) => _updateSetting('message', v),
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
  title: _tr('Thông báo tin nhắn nhóm', 'Group message notifications'),
  subtitle: _tr(
    'Bật/tắt thông báo khi có tin nhắn mới trong nhóm',
    'Turn on/off new group message notifications',
  ),
  value: groupMessageNotifications,
  onChanged: (v) => _updateSetting('groupMessage', v),
),
const SizedBox(height: 12),
                _buildSwitchTile(
                  title: _tr('Thông báo ghép đôi', 'Match notifications'),
                  subtitle: _tr(
                    'Bật/tắt khi có ghép đôi mới',
                    'Turn on/off new match notifications',
                  ),
                  value: matchNotifications,
                  onChanged: (v) => _updateSetting('match', v),
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  title: _tr('Thông báo hỗ trợ', 'Support notifications'),
                  subtitle: _tr(
                    'Thông báo từ hệ thống',
                    'System & support notifications',
                  ),
                  value: supportNotifications,
                  onChanged: (v) => _updateSetting('support', v),
                ),
              ],
            ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }
}
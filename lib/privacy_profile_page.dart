import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';


class PrivacyProfilePage extends StatefulWidget {
  final String languageCode;

  const PrivacyProfilePage({
    super.key,
    required this.languageCode,
  });

  @override
  State<PrivacyProfilePage> createState() => _PrivacyProfilePageState();
}

class _PrivacyProfilePageState extends State<PrivacyProfilePage> {
  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _isLoading = true;

  bool _showMyProfile = true;
  bool _hideFromContacts = false;
  bool _hideDistance = false;
  bool _showOnlineStatus = true;
  bool _showReadReceipts = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final user = currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      setState(() {
        _showMyProfile = data['showMyProfile'] ?? true;
        _hideFromContacts = data['hideFromContacts'] ?? false;
        _hideDistance = data['hideDistance'] ?? false;
        _showOnlineStatus = data['showOnlineStatus'] ?? true;
        _showReadReceipts = data['showReadReceipts'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String field, bool value) async {
    final user = currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      field: value,
    }, SetOptions(merge: true));
  }

  Future<void> _updateSwitch({
    required String field,
    required bool value,
    required void Function() updateLocal,
  }) async {
    updateLocal();

    try {
      await _saveSetting(field, value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('Không thể lưu cài đặt.', 'Could not save setting.'),
          ),
        ),
      );
    }
  }

  Future<void> _handleHideFromContacts(bool value) async {
    if (!value) {
      setState(() => _hideFromContacts = false);
      await _saveSetting('hideFromContacts', false);
      return;
    }

    final allow = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              _tr('Cho phép truy cập danh bạ?', 'Allow access to contacts?'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Text(
              _tr(
                'Để ẩn hồ sơ của bạn khỏi những người trong danh bạ, ứng dụng cần quyền truy cập danh bạ của thiết bị.',
                'To hide your profile from people in your contacts, the app needs permission to access your device contacts.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_tr('Không', 'No')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB83280),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(_tr('Cho phép', 'Allow')),
              ),
            ],
          ),
        ) ??
        false;

    if (!allow) return;

    final status = await Permission.contacts.request();

    if (status.isGranted) {
      setState(() => _hideFromContacts = true);
      await _saveSetting('hideFromContacts', true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Đã bật ẩn hồ sơ khỏi danh bạ.',
              'Hide profile from contacts enabled.',
            ),
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Bạn chưa cấp quyền truy cập danh bạ.',
              'Contacts permission was not granted.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showPauseAccountDialog() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              _tr('Tạm dừng tài khoản?', 'Pause account?'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Text(
              _tr(
                'Bạn có muốn tạm nghỉ không? Hồ sơ của bạn sẽ tạm thời không hiển thị cho người khác cho đến khi bạn bật lại.',
                'Do you want to take a break? Your profile will be temporarily hidden from others until you turn it back on.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_tr('Hủy', 'Cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB83280),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(_tr('OK', 'OK')),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .set({
      'accountPaused': true,
      'showMyProfile': false,
    }, SetOptions(merge: true));

    if (!mounted) return;

    setState(() {
      _showMyProfile = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Tài khoản đã được tạm dừng.',
            'Your account has been paused.',
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              _tr('Xóa tài khoản?', 'Delete account?'),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.red,
              ),
            ),
            content: Text(
              _tr(
                'Bạn có chắc muốn xóa tài khoản vĩnh viễn không? Dữ liệu sẽ không thể khôi phục.',
                'Are you sure you want to permanently delete your account? This data cannot be recovered.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_tr('Hủy', 'Cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(_tr('Xóa vĩnh viễn', 'Delete permanently')),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || currentUser == null) return;

    try {
      final uid = currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      await currentUser!.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Tài khoản đã được xóa.',
              'Your account has been deleted.',
            ),
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Không thể xóa tài khoản. Có thể bạn cần đăng nhập lại trước.',
              'Could not delete account. You may need to sign in again first.',
            ),
          ),
        ),
      );
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: Color(0xFF8B2E63),
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFF3F8),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD5E6),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC3D7A).withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: iconColor ?? const Color(0xFFCC3D7A),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15.8,
            fontWeight: FontWeight.w800,
            color: titleColor ?? const Color(0xFF444444),
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8D6B7D),
                    height: 1.4,
                  ),
                ),
              ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F0F0),
        elevation: 0,
        foregroundColor: const Color(0xFF7A2E6E),
        centerTitle: true,
        title: Text(
          _tr('Quyền riêng tư', 'Privacy'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A2E6E),
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
          top: false,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.pink),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  children: [
                    _sectionTitle(_tr('Hiển thị & tương tác', 'Visibility & interaction')),

                    _settingsTile(
                      icon: Icons.visibility_outlined,
                      title: _tr('Hiển thị hồ sơ của tôi', 'Show my profile'),
                      subtitle: _tr(
                        'Bật để hồ sơ của bạn xuất hiện với người khác.',
                        'Turn on to make your profile visible to others.',
                      ),
                      trailing: Switch(
                        value: _showMyProfile,
                        activeColor: const Color(0xFFB83280),
                        onChanged: (value) {
                          _updateSwitch(
                            field: 'showMyProfile',
                            value: value,
                            updateLocal: () {
                              setState(() => _showMyProfile = value);
                            },
                          );
                        },
                      ),
                    ),

                    _settingsTile(
                      icon: Icons.contacts_outlined,
                      title: _tr(
                        'Ẩn hồ sơ của tôi trong danh bạ',
                        'Hide my profile from contacts',
                      ),
                      subtitle: _tr(
                        'Ứng dụng sẽ cần quyền truy cập danh bạ.',
                        'The app will need access to your contacts.',
                      ),
                      trailing: Switch(
                        value: _hideFromContacts,
                        activeColor: const Color(0xFFB83280),
                        onChanged: _handleHideFromContacts,
                      ),
                    ),

                    _settingsTile(
                      icon: Icons.location_off_outlined,
                      title: _tr('Ẩn khoảng cách', 'Hide distance'),
                      subtitle: _tr(
                        'Không hiển thị khoảng cách của bạn cho người khác.',
                        'Do not show your distance to others.',
                      ),
                      trailing: Switch(
                        value: _hideDistance,
                        activeColor: const Color(0xFFB83280),
                        onChanged: (value) {
                          _updateSwitch(
                            field: 'hideDistance',
                            value: value,
                            updateLocal: () {
                              setState(() => _hideDistance = value);
                            },
                          );
                        },
                      ),
                    ),

                    _settingsTile(
                      icon: Icons.circle_outlined,
                      title: _tr('Hiện trạng thái online', 'Show online status'),
                      subtitle: _tr(
                        'Cho phép người khác thấy khi bạn đang hoạt động.',
                        'Let others see when you are active.',
                      ),
                      trailing: Switch(
                        value: _showOnlineStatus,
                        activeColor: const Color(0xFFB83280),
                        onChanged: (value) {
                          _updateSwitch(
                            field: 'showOnlineStatus',
                            value: value,
                            updateLocal: () {
                              setState(() => _showOnlineStatus = value);
                            },
                          );
                        },
                      ),
                    ),

                    _settingsTile(
                      icon: Icons.done_all_outlined,
                      title: _tr('Hiện đã xem tin nhắn', 'Show read receipts'),
                      subtitle: _tr(
                        'Cài đặt này áp dụng trong trang Message Page.',
                        'This setting only applies in the Message Page.',
                      ),
                      trailing: Switch(
                        value: _showReadReceipts,
                        activeColor: const Color(0xFFB83280),
                        onChanged: (value) {
                          _updateSwitch(
                            field: 'showReadReceipts',
                            value: value,
                            updateLocal: () {
                              setState(() => _showReadReceipts = value);
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 10),
                    _sectionTitle(_tr('Quản lý', 'Management')),

                    _settingsTile(
                      icon: Icons.block_outlined,
                      title: _tr('Danh sách chặn', 'Blocked list'),
                      subtitle: _tr(
                        'Xem và quản lý những người bạn đã chặn.',
                        'View and manage people you have blocked.',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFB83280),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlockedListPage(
                              languageCode: widget.languageCode,
                            ),
                          ),
                        );
                      },
                    ),

                    _settingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: _tr('Chính sách quyền riêng tư', 'Privacy Policy'),
                      subtitle: _tr(
                        'Xem cách ứng dụng thu thập và sử dụng dữ liệu.',
                        'See how the app collects and uses data.',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFB83280),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PrivacyPolicyPage(
                              languageCode: widget.languageCode,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class BlockedListPage extends StatelessWidget {
  final String languageCode;

  const BlockedListPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F0F0),
        elevation: 0,
        foregroundColor: const Color(0xFF7A2E6E),
        centerTitle: true,
        title: Text(
          _tr('Danh sách chặn', 'Blocked list'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A2E6E),
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
        child: currentUser == null
            ? Center(
                child: Text(
                  _tr('Bạn chưa đăng nhập.', 'You are not signed in.'),
                ),
              )
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.pink),
                    );
                  }

                  final data = snapshot.data!.data() ?? {};
                  final blockedUsers =
                      List<Map<String, dynamic>>.from(data['blockedUsers'] ?? []);

                  if (blockedUsers.isEmpty) {
                    return Center(
                      child: Text(
                        _tr(
                          'Bạn chưa chặn ai.',
                          'You have not blocked anyone.',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7A2E6E),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: blockedUsers.length,
                    itemBuilder: (context, index) {
                      final item = blockedUsers[index];
                      final uid = (item['uid'] ?? '').toString();
                      final name = (item['name'] ?? '').toString();
                      final photoUrl = (item['photoUrl'] ?? '').toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: Colors.white.withOpacity(0.9),
                          border: Border.all(color: const Color(0xFFFFD5E6)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.pink.shade50,
                            backgroundImage:
                                photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl.isEmpty
                                ? const Icon(Icons.person, color: Colors.grey)
                                : null,
                          ),
                          title: Text(
                            name.isEmpty
                                ? _tr('Người dùng', 'User')
                                : name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              final userRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUser.uid);

                              final currentDoc = await userRef.get();
                              final currentData = currentDoc.data() ?? {};
                              final currentBlocked = List<Map<String, dynamic>>.from(
                                currentData['blockedUsers'] ?? [],
                              );

                              currentBlocked.removeWhere(
                                (e) => (e['uid'] ?? '').toString() == uid,
                              );

                              await userRef.set({
                                'blockedUsers': currentBlocked,
                              }, SetOptions(merge: true));
                            },
                            child: Text(
                              _tr('Bỏ chặn', 'Unblock'),
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  final String languageCode;

  const PrivacyPolicyPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F0F0),
        elevation: 0,
        foregroundColor: const Color(0xFF7A2E6E),
        centerTitle: true,
        title: Text(
          _tr('Chính sách quyền riêng tư', 'Privacy Policy'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A2E6E),
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            _policyCard(
              title: _tr('1. Dữ liệu chúng tôi thu thập', '1. Data we collect'),
              content: _tr(
                'Chúng tôi có thể thu thập thông tin hồ sơ, ảnh, tin nhắn, vị trí gần đúng và các cài đặt tài khoản để cung cấp dịch vụ ghép đôi và liên lạc trong ứng dụng.',
                'We may collect profile information, photos, messages, approximate location, and account settings in order to provide matching and communication features in the app.',
              ),
            ),
            _policyCard(
              title: _tr('2. Cách chúng tôi sử dụng dữ liệu', '2. How we use your data'),
              content: _tr(
                'Dữ liệu được sử dụng để hiển thị hồ sơ, đề xuất phù hợp, cải thiện an toàn tài khoản và nâng cao trải nghiệm người dùng.',
                'Your data is used to show profiles, recommend matches, improve account safety, and enhance user experience.',
              ),
            ),
            _policyCard(
              title: _tr('3. Chia sẻ dữ liệu', '3. Data sharing'),
              content: _tr(
                'Chúng tôi không bán dữ liệu cá nhân của bạn. Một số thông tin chỉ được hiển thị theo cài đặt quyền riêng tư mà bạn chọn trong ứng dụng.',
                'We do not sell your personal data. Some information is shown only according to the privacy settings you choose inside the app.',
              ),
            ),
            _policyCard(
              title: _tr('4. Quyền của bạn', '4. Your rights'),
              content: _tr(
                'Bạn có thể chỉnh sửa hồ sơ, thay đổi cài đặt quyền riêng tư, tạm dừng tài khoản hoặc yêu cầu xóa tài khoản của mình.',
                'You can edit your profile, change privacy settings, pause your account, or request deletion of your account.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _policyCard({
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFF3F8),
          ],
        ),
        border: Border.all(color: const Color(0xFFFFD5E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF8B2E63),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.55,
              fontWeight: FontWeight.w600,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'phone_verification_page.dart';


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
  bool _showHomeTutorial = false;

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
        _showHomeTutorial = !(data['hasSeenHomeTutorial'] ?? false);
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

String _normalizeContactPhone(String phone) {
  return phone
      .trim()
      .replaceAll(RegExp(r'[^0-9+]'), '');
}
String _hashPhoneNumber(String normalizedPhone) {
  return sha256
      .convert(utf8.encode(normalizedPhone))
      .toString();
}
Future<List<String>> _readContactPhoneHashes() async {
  final contacts = await FlutterContacts.getContacts(
    withProperties: true,
  );

  final phoneHashes = <String>{};

  for (final contact in contacts) {
    for (final phone in contact.phones) {
      final normalized =
          _normalizeContactPhone(phone.number);

      if (normalized.isEmpty) {
        continue;
      }

      phoneHashes.add(
        _hashPhoneNumber(normalized),
      );
    }
  }

  return phoneHashes.toList();
}
Future<int> _syncHiddenContacts() async {
  final phoneHashes =
      await _readContactPhoneHashes();

  final callable = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  ).httpsCallable(
    'syncHiddenContacts',
  );

  final result = await callable.call({
    'phoneHashes': phoneHashes,
  });

  final rawData = result.data;

  if (rawData is! Map) {
    return 0;
  }

  final data = Map<String, dynamic>.from(
    rawData,
  );

  return (data['hiddenCount'] as num?)?.toInt() ?? 0;
}
Future<void> _clearHiddenContacts() async {
  final callable = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  ).httpsCallable(
    'clearHiddenContacts',
  );

  await callable.call();
}
  Future<void> _handleHideFromContacts(bool value) async {
  if (!value) {
  try {
    setState(() => _hideFromContacts = false);

    await _clearHiddenContacts();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Đã tắt tính năng và xóa dữ liệu danh bạ đã đồng bộ.',
            'The feature was disabled and synced contact data was deleted.',
          ),
        ),
      ),
    );
  } catch (e) {
    debugPrint(
      'CLEAR HIDDEN CONTACTS ERROR: $e',
    );

    if (!mounted) return;

    setState(() => _hideFromContacts = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Không thể tắt cài đặt.',
            'Could not disable this setting.',
          ),
        ),
      ),
    );
  }

  return;
}
final userSnapshot = await FirebaseFirestore.instance
    .collection('users')
    .doc(currentUser!.uid)
    .get();

final userData = userSnapshot.data() ?? {};

final phoneNumber = (
  userData['phoneNumber'] ??
  userData['otpPhoneNumber'] ??
  ''
).toString().trim();

final phoneVerified =
    userData['phoneVerified'] == true;

if (phoneNumber.isEmpty || !phoneVerified) {
  if (!mounted) return;

  setState(() => _hideFromContacts = false);

  final verified = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => PhoneVerificationPage(
        languageCode: widget.languageCode,
        firstName:
            (userData['firstName'] ?? '').toString(),
        isFromPrivacy: true,
      ),
    ),
  );

  if (!mounted) return;

  if (verified == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Đã xác minh số điện thoại. Vui lòng bật lại tính năng ẩn danh bạ.',
            'Phone number verified. Please enable Hide from Contacts again.',
          ),
        ),
      ),
    );
  }

  return;
}
  final consentGranted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              _tr(
                'Ẩn hồ sơ với người trong danh bạ',
                'Hide your profile from contacts',
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
           content: SingleChildScrollView(
  child: Text(
    _tr(
      'Để giúp bạn không xuất hiện với những người đã lưu trong danh bạ, VietLove Dating sẽ truy cập số điện thoại trong danh bạ của bạn. Trước khi gửi dữ liệu lên máy chủ, ứng dụng sẽ chuyển mỗi số điện thoại thành mã bảo mật SHA-256 ngay trên thiết bị của bạn.\n\n'
      'Chỉ các mã SHA-256 này được tải lên máy chủ để đối chiếu với tài khoản thành viên và xác định những hồ sơ cần được ẩn giữa bạn và những người trong danh bạ.\n\n'
      'Số điện thoại gốc trong danh bạ không được tải lên máy chủ. Dữ liệu này chỉ được sử dụng cho tính năng "Ẩn hồ sơ của tôi trong danh bạ", không được sử dụng cho quảng cáo và không được bán hoặc chia sẻ với bên thứ ba.\n\n'
      'Tính năng này hoàn toàn tự nguyện. Bạn vẫn có thể sử dụng tất cả các tính năng khác của ứng dụng nếu không đồng ý.',

      'To help prevent your profile from appearing to people saved in your contacts, VietLove Dating will access the phone numbers stored in your contacts. Before any data is transmitted, each phone number is converted into a secure SHA-256 hash directly on your device.\n\n'
      'Only these SHA-256 hashes are uploaded to our server to compare them with registered member accounts and identify which profiles should be hidden between you and people in your contacts.\n\n'
      'Original contact phone numbers are never uploaded to our server. This data is used solely for the "Hide my profile from contacts" feature. It is not used for advertising and is never sold or shared with third parties.\n\n'
      'This feature is completely optional. You can continue using all other app features if you choose not to enable it.',
    ),
    style: const TextStyle(
      fontSize: 14.5,
      height: 1.5,
    ),
  ),
),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: Text(
                  _tr(
                    'Không đồng ý',
                    'Not Now',
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB83280),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: Text(
                  _tr(
                    'Đồng ý và tiếp tục',
                    'Agree and Continue',
                  ),
                ),
              ),
            ],
          );
        },
      ) ??
      false;

  if (!consentGranted) {
    if (!mounted) return;

    setState(() => _hideFromContacts = false);
    return;
  }

  final permissionGranted =
      await FlutterContacts.requestPermission(readonly: true);

  if (!permissionGranted) {
    if (!mounted) return;

    setState(() => _hideFromContacts = false);

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

    return;
  }
 try {
  setState(() => _hideFromContacts = true);

  await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser!.uid)
      .set({
    'hideFromContacts': true,
    'contactsConsentGranted': true,
    'contactsConsentGrantedAt':
        FieldValue.serverTimestamp(),
    'contactsConsentVersion': '1.0',
    'contactsUploadFormat': 'sha256',
  }, SetOptions(merge: true));

  final hiddenCount =
      await _syncHiddenContacts();

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        _tr(
          'Đã bật tính năng và ẩn $hiddenCount tài khoản trong danh bạ.',
          'Enabled and hidden $hiddenCount accounts found in your contacts.',
        ),
      ),
    ),
  );
} catch (e) {
  debugPrint(
    'SYNC HIDDEN CONTACTS ERROR: $e',
  );

  if (!mounted) return;

  setState(() => _hideFromContacts = false);

  try {
    await _saveSetting(
      'hideFromContacts',
      false,
    );
  } catch (_) {}

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        _tr(
          'Không thể đồng bộ danh bạ. Vui lòng thử lại.',
          'Could not sync contacts. Please try again.',
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
  'Tùy chọn tải mã SHA-256 của số điện thoại trong danh bạ lên máy chủ để ẩn hồ sơ với những người bạn biết.',
  'Optionally uploads SHA-256 hashes of contact phone numbers to our server to hide your profile from people you know.',
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
_settingsTile(
  icon: Icons.school_outlined,
  title: _tr(
    'Hiển thị hướng dẫn Trang khám phá',
    'Show Discover tutorial',
  ),
  subtitle: _tr(
    'Bật để xem lại hướng dẫn khi mở Trang khám phá.',
    'Turn on to show the Discover tutorial the next time you open Discover.',
  ),
  trailing: Switch(
    value: _showHomeTutorial,
    activeColor: const Color(0xFFB83280),
    onChanged: (value) async {
      setState(() => _showHomeTutorial = value);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({
        'hasSeenHomeTutorial': !value,
      }, SetOptions(merge: true));
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

  Future<List<Map<String, dynamic>>> _loadVisibleBlockedUsers(
    List<Map<String, dynamic>> blockedItems,
  ) async {
    final results = await Future.wait(
      blockedItems.map((item) async {
        final uid = (item['uid'] ?? '').toString().trim();

        if (uid.isEmpty) {
          return null;
        }

        try {
          final userSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

          // Document user không còn tồn tại.
          if (!userSnapshot.exists) {
            return null;
          }

          final userData = userSnapshot.data() ?? {};

          final firstName =
              (userData['firstName'] ?? '').toString().trim();

          final surname =
              (userData['surname'] ?? '').toString().trim();

          final name = '$firstName $surname'.trim();

          final photoUrl = (userData['mainPhotoUrl'] ??
                  userData['photoUrl'] ??
                  userData['profileImageUrl'] ??
                  '')
              .toString()
              .trim();

          final isDeletedAccount =
              userData['accountDeleted'] == true ||
              userData['deleted'] == true ||
              userData['isDeleted'] == true ||
              userData['accountStatus'] == 'deleted';

          // Không hiện tài khoản đã xóa hoặc document trống.
          if (isDeletedAccount || (name.isEmpty && photoUrl.isEmpty)) {
            return null;
          }

          return <String, dynamic>{
            ...item,
            'name': name,
            'photoUrl': photoUrl,
          };
        } catch (e) {
          debugPrint('LOAD BLOCKED USER ERROR: $uid | $e');
          return null;
        }
      }),
    );

    return results.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _unblockUser({
    required String currentUid,
    required Map<String, dynamic> item,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    final camelDocIds =
        List<String>.from(item['camelDocIds'] ?? <String>[]);

    final snakeDocIds =
        List<String>.from(item['snakeDocIds'] ?? <String>[]);

    // Xóa trong blockedUsers.
    for (final docId in camelDocIds) {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('blockedUsers')
          .doc(docId);

      batch.delete(ref);
    }

    // Xóa trong blocked_users.
    for (final docId in snakeDocIds) {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('blocked_users')
          .doc(docId);

      batch.delete(ref);
    }

    await batch.commit();
  }

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
                  _tr(
                    'Bạn chưa đăng nhập.',
                    'You are not signed in.',
                  ),
                ),
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .collection('blockedUsers')
                    .snapshots(),
                builder: (context, camelSnapshot) {
                  if (camelSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !camelSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.pink,
                      ),
                    );
                  }

                  return StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('blocked_users')
                        .snapshots(),
                    builder: (context, snakeSnapshot) {
                      if (snakeSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snakeSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.pink,
                          ),
                        );
                      }

                      final merged =
                          <String, Map<String, dynamic>>{};

                      final camelDocs =
                          camelSnapshot.data?.docs ?? [];

                      for (final doc in camelDocs) {
                        final data = doc.data();

                        final uid = (data['userId'] ??
                                data['uid'] ??
                                doc.id)
                            .toString()
                            .trim();

                        if (uid.isEmpty) continue;

                        final item = merged.putIfAbsent(
                          uid,
                          () => <String, dynamic>{
                            'uid': uid,
                            'camelDocIds': <String>[],
                            'snakeDocIds': <String>[],
                          },
                        );

                        (item['camelDocIds'] as List<String>)
                            .add(doc.id);
                      }

                      final snakeDocs =
                          snakeSnapshot.data?.docs ?? [];

                      for (final doc in snakeDocs) {
                        final data = doc.data();

                        final uid = (data['uid'] ??
                                data['userId'] ??
                                doc.id)
                            .toString()
                            .trim();

                        if (uid.isEmpty) continue;

                        final item = merged.putIfAbsent(
                          uid,
                          () => <String, dynamic>{
                            'uid': uid,
                            'camelDocIds': <String>[],
                            'snakeDocIds': <String>[],
                          },
                        );

                        (item['snakeDocIds'] as List<String>)
                            .add(doc.id);
                      }

                      final blockedItems =
                          merged.values.toList();

                      if (blockedItems.isEmpty) {
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

                      return FutureBuilder<
                          List<Map<String, dynamic>>>(
                        future: _loadVisibleBlockedUsers(
                          blockedItems,
                        ),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.pink,
                              ),
                            );
                          }

                          final visibleUsers =
                              userSnapshot.data ?? [];

                          if (visibleUsers.isEmpty) {
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
                            itemCount: visibleUsers.length,
                            itemBuilder: (context, index) {
                              final item =
                                  visibleUsers[index];

                              final name =
                                  (item['name'] ?? '')
                                      .toString()
                                      .trim();

                              final photoUrl =
                                  (item['photoUrl'] ?? '')
                                      .toString()
                                      .trim();

                              return Container(
                                margin: const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(22),
                                  color:
                                      Colors.white.withOpacity(0.9),
                                  border: Border.all(
                                    color:
                                        const Color(0xFFFFD5E6),
                                  ),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        Colors.pink.shade50,
                                    backgroundImage:
                                        photoUrl.isNotEmpty
                                            ? NetworkImage(
                                                photoUrl,
                                              )
                                            : null,
                                    child: photoUrl.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            color: Colors.grey,
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  trailing: TextButton(
                                    onPressed: () async {
                                      try {
                                        await _unblockUser(
                                          currentUid:
                                              currentUser.uid,
                                          item: item,
                                        );

                                        if (!context.mounted) {
                                          return;
                                        }

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              _tr(
                                                'Đã bỏ chặn người dùng.',
                                                'User unblocked.',
                                              ),
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) {
                                          return;
                                        }

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              _tr(
                                                'Không thể bỏ chặn.',
                                                'Could not unblock user.',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      _tr(
                                        'Bỏ chặn',
                                        'Unblock',
                                      ),
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
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
  title: _tr(
    '4. Danh bạ và tính năng ẩn hồ sơ',
    '4. Contacts and profile hiding',
  ),
 content: _tr(
  'Nếu bạn tự nguyện bật tính năng "Ẩn hồ sơ của tôi trong danh bạ", VietLove Dating sẽ truy cập số điện thoại trong danh bạ của bạn. Trước khi gửi dữ liệu lên máy chủ, mỗi số điện thoại sẽ được chuyển thành mã bảo mật SHA-256 ngay trên thiết bị của bạn.\n\n'
  'Chỉ các mã SHA-256 này được tải lên máy chủ để đối chiếu với tài khoản thành viên và xác định những hồ sơ cần được ẩn giữa bạn và những người trong danh bạ.\n\n'
  'Số điện thoại gốc trong danh bạ không được tải lên máy chủ. Dữ liệu này chỉ được sử dụng cho tính năng "Ẩn hồ sơ của tôi trong danh bạ", không được sử dụng cho quảng cáo và không được bán hoặc chia sẻ với bên thứ ba.\n\n'
  'Bạn có thể không cấp quyền truy cập danh bạ và vẫn tiếp tục sử dụng tất cả các tính năng khác của ứng dụng.',

  'If you voluntarily enable "Hide my profile from contacts", VietLove Dating will access the phone numbers stored in your contacts. Before any data is transmitted, each phone number is converted into a secure SHA-256 hash directly on your device.\n\n'
  'Only these SHA-256 hashes are uploaded to our server to compare them with registered member accounts and identify which profiles should be hidden between you and people in your contacts.\n\n'
  'Original contact phone numbers are never uploaded to our server. This data is used solely for the "Hide my profile from contacts" feature. It is not used for advertising and is never sold or shared with third parties.\n\n'
  'You may decline contact access and continue using all other features of the app.',
),
),
            _policyCard(
             title: _tr(
  '5. Quyền của bạn',
  '5. Your rights',
),
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
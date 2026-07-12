import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'privacy_profile_page.dart';
import 'support_help_page.dart';

class AccountPage extends StatefulWidget {
  final String languageCode;

  const AccountPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _isLoading = false;

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  Future<void> _logout() async {
    try {
      setState(() => _isLoading = true);

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginPage(
            initialLanguageCode: widget.languageCode,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      _showSnackBar(
        _tr(
          'Đăng xuất thất bại. Vui lòng thử lại.',
          'Logout failed. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pauseAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar(_tr('Bạn chưa đăng nhập.', 'You are not logged in.'));
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: _tr('Tạm dừng tài khoản', 'Pause account'),
      message: _tr(
        'Bạn có chắc bạn muốn pause account không?',
        'Are you sure you want to pause your account?',
      ),
      confirmText: _tr('Có', 'Yes'),
      cancelText: 'Cancel',
      isDestructive: false,
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isPaused': true,
        'isDeleted': false,
        'showOnDiscover': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'pausedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      _showSnackBar(
        _tr('Tài khoản đã được tạm dừng.', 'Your account has been paused.'),
      );
    } catch (e) {
      _showSnackBar(
        _tr(
          'Không thể tạm dừng tài khoản. Vui lòng thử lại.',
          'Could not pause account. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    _showSnackBar(
      _tr('Bạn chưa đăng nhập.', 'You are not logged in.'),
    );
    return;
  }

  final deleteReason = await _showDeleteReasonDialog();
  if (deleteReason == null) return;

  final password = await _showDeletePasswordDialog();
  if (password == null) return;

  final confirmed = await _showConfirmDialog(
    title: _tr('Xóa tài khoản', 'Delete account'),
    message: _tr(
      'Bạn có chắc bạn muốn xóa tài khoản vĩnh viễn không?\n\nNếu muốn, bạn có thể chọn tạm dừng tài khoản thay vì xóa.\n\nKhi xóa thì sẽ không thể khôi phục tài khoản.',
      'Are you sure you want to permanently delete your account?\n\nIf you want, you can pause your account instead of deleting it.\n\nOnce deleted, your account cannot be recovered.',
    ),
    confirmText: _tr('Có', 'Yes'),
    cancelText: 'Cancel',
    isDestructive: true,
  );

  if (confirmed != true) return;

  try {
    setState(() => _isLoading = true);

    final email = user.email;

    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Current user email is missing.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);

    final callable = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).httpsCallable('deleteMyAccount');

    await callable.call({
      'deleteReason': deleteReason['reason'] ?? '',
      'deleteReasonText': deleteReason['text'] ?? '',
    });

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          initialLanguageCode: widget.languageCode,
        ),
      ),
      (route) => false,
    );
  } on FirebaseAuthException catch (e) {
    String message;

    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        message = _tr(
          'Mật khẩu không đúng.',
          'Incorrect password.',
        );
        break;

      case 'requires-recent-login':
        message = _tr(
          'Vì lý do bảo mật, vui lòng đăng nhập lại rồi thử xóa tài khoản lần nữa.',
          'For security reasons, please log in again and try deleting your account once more.',
        );
        break;

      default:
        message = _tr(
          'Không thể xóa tài khoản: ${e.message ?? e.code}',
          'Could not delete account: ${e.message ?? e.code}',
        );
    }

    _showSnackBar(message);
  } on FirebaseFunctionsException catch (e) {
    _showSnackBar(
      _tr(
        'Không thể xóa tài khoản: ${e.message ?? e.code}',
        'Could not delete account: ${e.message ?? e.code}',
      ),
    );
  } catch (e) {
    _showSnackBar(
      _tr(
        'Có lỗi khi xóa tài khoản: $e',
        'An error occurred while deleting the account: $e',
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  Future<void> _deleteMatches(String uid) async {
    final firestore = FirebaseFirestore.instance;

    final snap = await firestore
        .collection('matches')
        .where('users', arrayContains: uid)
        .get();

    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
  

  Future<void> _anonymizeChats(String uid) async {
    final firestore = FirebaseFirestore.instance;

    final chatSnap = await firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();

    for (final chat in chatSnap.docs) {
      final data = chat.data();

      final participants = List<String>.from(data['participants'] ?? []);
      final newParticipants = participants.where((id) => id != uid).toList();

      final participantNames =
          Map<String, dynamic>.from(data['participantNames'] ?? {});
      final participantPhotos =
          Map<String, dynamic>.from(data['participantPhotos'] ?? {});

      participantNames.remove(uid);
      participantPhotos.remove(uid);

      await chat.reference.set({
        'participants': newParticipants,
        'participantNames': participantNames,
        'participantPhotos': participantPhotos,
        'deletedUserIds': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final messages = await chat.reference.collection('messages').get();

      for (final msg in messages.docs) {
        final msgData = msg.data();
        final senderId = (msgData['senderId'] ?? '').toString();
        final type = (msgData['type'] ?? 'text').toString();

        if (senderId == uid) {
          await msg.reference.set({
            'senderId': 'deleted_user',
            'senderName': _tr('Người dùng đã xóa', 'Deleted user'),
            'senderPhotoUrl': '',
            'text': type == 'image'
                ? _tr('[Ảnh đã bị xóa]', '[Image deleted]')
                : _tr('[Tin nhắn đã bị xóa]', '[Message deleted]'),
            'imageUrl': '',
            'isFromDeletedAccount': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    }
  }

  Future<void> _deleteUserImagesFromStorage({
    required String uid,
    required Map<String, dynamic> userData,
  }) async {
    final storage = FirebaseStorage.instance;
    final urls = <String>{};

    final mainPhotoUrl = (userData['mainPhotoUrl'] ?? '').toString().trim();
    if (mainPhotoUrl.isNotEmpty) {
      urls.add(mainPhotoUrl);
    }

    if (userData['photoUrls'] is List) {
      for (final item in (userData['photoUrls'] as List)) {
        final value = item.toString().trim();
        if (value.isNotEmpty) urls.add(value);
      }
    }

    if (userData['photos'] is List) {
      for (final item in (userData['photos'] as List)) {
        final value = item.toString().trim();
        if (value.isNotEmpty) urls.add(value);
      }
    }

    for (final url in urls) {
      try {
        await storage.refFromURL(url).delete();
      } catch (_) {}
    }

    await _deleteFolderIfExists(storage.ref().child('user_photos').child(uid));
  }

  Future<void> _deleteFolderIfExists(Reference ref) async {
    try {
      final result = await ref.listAll();

      for (final item in result.items) {
        try {
          await item.delete();
        } catch (_) {}
      }

      for (final folder in result.prefixes) {
        await _deleteFolderIfExists(folder);
      }
    } catch (_) {}
  }

  Future<void> _deleteKnownUserSubcollections(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);

    const subcollections = [
      'likes',
      'passes',
      'flowers',
      'notifications',
      'reports',
    ];

    for (final sub in subcollections) {
      try {
        final snap = await userRef.collection(sub).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
    required bool isDestructive,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final confirmColor =
            isDestructive ? const Color(0xFFE53935) : const Color(0xFFD94B8A);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: isDestructive
                  ? const Color(0xFFE53935)
                  : const Color(0xFF444444),
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: Color(0xFF666666),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                cancelText,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }
Future<Map<String, String>?> _showDeleteReasonDialog() async {
  String? selectedReason;
  final otherController = TextEditingController();
  final scrollController = ScrollController();

  final reasons = [
  _tr(
    'Tôi đã gặp được người phù hợp trên VietLove Dating',
    'I met someone through VietLove Dating',
  ),
  _tr(
    'Tôi đã tìm được người phù hợp theo cách khác',
    'I found the right person elsewhere',
  ),
  _tr(
    'Không có nhiều người phù hợp',
    'Not enough suitable people',
  ),
  _tr(
    'App khó sử dụng',
    'The app is difficult to use',
  ),
  _tr(
    'Tôi lo về quyền riêng tư',
    'I have privacy concerns',
  ),
  _tr(
    'Tôi muốn nghỉ hẹn hò một thời gian',
    'I want to take a break from dating',
  ),
  _tr(
    'Khác',
    'Other',
  ),
];

  return showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setInnerState) {
          final isOther = selectedReason == _tr('Khác', 'Other');
          final isDifficultToUse = selectedReason ==
    _tr(
      'App khó sử dụng',
      'The app is difficult to use',
    );

final isPrivacyConcern = selectedReason ==
    _tr(
      'Tôi lo về quyền riêng tư',
      'I have privacy concerns',
    );

final isTakingBreak = selectedReason ==
    _tr(
      'Tôi muốn nghỉ hẹn hò một thời gian',
      'I want to take a break from dating',
    );

          return RadioGroup<String>(
            groupValue: selectedReason,
            onChanged: (value) {
  setInnerState(() {
    selectedReason = value;
  });

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!scrollController.hasClients) return;

    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  });
},
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                _tr(
                  'Tại sao bạn muốn xóa tài khoản?',
                  'Why do you want to delete your account?',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
  controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...reasons.map(
                      (reason) => RadioListTile<String>(
                        value: reason,
                        title: Text(reason),
                        activeColor: const Color(0xFFD94B8A),
                      ),
                    ),
                    if (isDifficultToUse)
  Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7FA),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFC7DD)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr(
            '💡 Bạn có thể chưa khám phá hết các tính năng của VietLove.',
            '💡 You may not have discovered all of VietLove\'s features yet.',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _tr(
            'Bạn có thể vào phần Settings để xem hướng dẫn sử dụng và khám phá thêm các tính năng trước khi quyết định xóa tài khoản.',
            'You can visit Settings to learn how to use VietLove before deciding to delete your account.',
          ),
        ),
        const SizedBox(height: 14),

SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    icon: const Icon(Icons.settings_outlined),
    label: Text(
      _tr(
        'Mở trang Cài đặt',
        'Open Settings',
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFD94B8A),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    onPressed: () {
  Navigator.pop(dialogContext, null);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SupportHelpPage(
        languageCode: widget.languageCode,
      ),
    ),
  );
},
  ),
),
      ],
    ),
  ),
  if (isPrivacyConcern)
  Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7FA),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFC7DD)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr(
            '🔒 Quyền riêng tư của bạn rất quan trọng với chúng tôi.',
            '🔒 Your privacy is important to us.',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _tr(
            '• Email và số điện thoại của bạn không hiển thị công khai.\n'
            '• Chúng tôi không bán thông tin cá nhân của bạn.\n'
            '• Bạn có thể ẩn hồ sơ khỏi những người trong danh bạ.',
            '• Your email and phone number are never shown publicly.\n'
            '• We never sell your personal information.\n'
            '• You can hide your profile from people in your contacts.',
          ),
        ),
        const SizedBox(height: 14),

SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    icon: const Icon(Icons.privacy_tip_outlined),
    label: Text(
      _tr(
        'Ẩn hồ sơ khỏi danh bạ',
        'Hide my profile from contacts',
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFD94B8A),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    onPressed: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrivacyProfilePage(
            languageCode: widget.languageCode,
          ),
        ),
      );
    },
  ),
),
      ],
    ),
  ),
  if (isTakingBreak)
  Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7FA),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFC7DD)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr(
            '💤 Bạn không cần xóa tài khoản.',
            '💤 You do not need to delete your account.',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _tr(
            'Bạn có thể Pause Account. Hồ sơ sẽ được ẩn, nhưng ảnh, tin nhắn, matches và dữ liệu của bạn vẫn được giữ lại để bạn quay lại bất cứ lúc nào.',
            'You can Pause your account. Your profile will be hidden while your photos, messages, matches and data are safely kept until you come back.',
          ),
        ),
        const SizedBox(height: 14),

SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    icon: const Icon(Icons.pause_circle_outline_rounded),
    label: Text(
      _tr(
        'Tạm dừng tài khoản',
        'Pause account',
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFD94B8A),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    onPressed: () async {
      Navigator.pop(dialogContext, null);

      await _pauseAccount();
    },
  ),
),
      ],
    ),
  ),
                    if (isOther) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: _tr(
                            'Vui lòng cho chúng tôi biết lý do...',
                            'Please tell us your reason...',
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFFF7FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext, {
                            'reason': selectedReason!,
                            'text': isOther ? otherController.text.trim() : '',
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD94B8A),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_tr('Tiếp tục', 'Continue')),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
  Future<String?> _showDeletePasswordDialog() async {
    final controller = TextEditingController();
    bool obscure = true;
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                _tr('Nhập lại mật khẩu', 'Re-enter password'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tr(
                      'Để xóa tài khoản, vui lòng nhập lại mật khẩu của bạn.',
                      'To delete your account, please enter your password again.',
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: _tr('Mật khẩu', 'Password'),
                      errorText: errorText,
                      filled: true,
                      fillColor: const Color(0xFFFFF7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFFFD6E7),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Colors.pink,
                          width: 1.4,
                        ),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setInnerState(() {
                            obscure = !obscure;
                          });
                        },
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setInnerState(() {
                        errorText = _tr(
                          'Vui lòng nhập mật khẩu',
                          'Please enter your password',
                        );
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, value);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD94B8A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(_tr('Tiếp tục', 'Continue')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFD),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFF6CADB),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: _isLoading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDanger
                            ? const Color(0xFFF44336)
                            : const Color(0xFF4A4A4A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8D7281),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 34,
                color: isDanger
                    ? const Color(0xFFF44336)
                    : const Color(0xFFD94B8A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD94B8A),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          _tr('Đăng xuất', 'Log out'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFFFF7FB),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFFF7FB),
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Color(0xFFD94B8A)),
            title: Text(
              _tr('Tài khoản', 'Account'),
              style: const TextStyle(
                color: Color(0xFF333333),
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              child: Column(
                children: [
                  _buildLogoutButton(),
                  const SizedBox(height: 22),
                  _buildItem(
                    icon: Icons.pause_circle_outline_rounded,
                    iconColor: const Color(0xFFD94B8A),
                    title: _tr('Tạm dừng tài khoản', 'Pause account'),
                    subtitle: _tr(
                      'Tạm ẩn hồ sơ của bạn cho đến khi bạn quay lại.',
                      'Temporarily hide your profile until you come back.',
                    ),
                    onTap: _pauseAccount,
                  ),
                  _buildItem(
                    icon: Icons.delete_outline_rounded,
                    iconColor: const Color(0xFFF44336),
                    title: _tr('Xóa tài khoản', 'Delete account'),
                    subtitle: _tr(
                      'Xóa vĩnh viễn tài khoản và dữ liệu, không thể khôi phục.',
                      'Permanently delete your account and data. This cannot be undone.',
                    ),
                    onTap: _deleteAccount,
                    isDanger: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
           color: Colors.black.withValues(alpha: 0.12),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD94B8A),
              ),
            ),
          ),
      ],
    );
  }
}
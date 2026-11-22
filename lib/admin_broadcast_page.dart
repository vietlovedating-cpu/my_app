
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminBroadcastPage extends StatefulWidget {
  final String languageCode;

  const AdminBroadcastPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<AdminBroadcastPage> createState() =>
      _AdminBroadcastPageState();
}

class _AdminBroadcastPageState extends State<AdminBroadcastPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _identifierController = TextEditingController();

  String _target = 'all';
  bool _isSending = false;

  bool get _isVi =>
      widget.languageCode.toLowerCase().startsWith('vi');

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  String _tr(String vi, String en) => _isVi ? vi : en;

  Color get _primaryColor => const Color(0xFFB83280);

  String get _targetName {
    switch (_target) {
      case 'vip':
        return 'VIP Members';
      case 'individual':
        return 'Individual User';
      case 'free':
        return 'Free Members';
      default:
        return 'All Users';
    }
  }

  IconData _targetIcon(String value) {
    switch (value) {
      case 'vip':
        return Icons.workspace_premium_rounded;
      case 'individual':
        return Icons.person_rounded;
      case 'free':
        return Icons.person_outline_rounded;
      default:
        return Icons.groups_rounded;
    }
  }

  String _targetDescription(String value) {
    switch (value) {
      case 'vip':
        return _tr(
          'Chỉ gửi đến thành viên VIP còn hạn.',
          'Only users with active VIP membership.',
        );
      case 'individual':
        return _tr(
          'Gửi riêng cho một người bằng email hoặc User ID.',
          'Send to one user by email or User ID.',
        );
      case 'free':
        return _tr(
          'Chỉ gửi đến người dùng không có VIP đang hoạt động.',
          'Only users without an active VIP membership.',
        );
      default:
        return _tr(
          'Gửi thông báo đến tất cả người dùng.',
          'Send a message to every user.',
        );
    }
  }

  Future<void> _sendBroadcast() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isSending) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _tr('Xác nhận gửi', 'Confirm Broadcast'),
        ),
        content: Text(
          _tr(
            'Bạn có chắc muốn gửi thông báo đến $_targetName?',
            'Are you sure you want to send this message to $_targetName?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: Text(_tr('Hủy', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: Text(_tr('Xác nhận', 'Confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('sendAdminBroadcast');

      final result = await callable.call({
        'title': _titleController.text.trim(),
        'body': _messageController.text.trim(),
        'target': _target,
        'identifier': _target == 'individual'
            ? _identifierController.text.trim()
            : '',
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final sentCount = data['sentCount'] ?? 0;

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 48,
          ),
          title: Text(
            _tr('Gửi thành công', 'Broadcast Sent'),
          ),
          content: Text(
            _tr(
              'Đã gửi thông báo đến $sentCount người dùng.',
              'Successfully sent to $sentCount users.',
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      _titleController.clear();
      _messageController.clear();
      _identifierController.clear();

      setState(() {
        _target = 'all';
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      String message = e.message ??
          _tr(
            'Không thể gửi thông báo. Vui lòng thử lại.',
            'Unable to send broadcast. Please try again.',
          );

      if (e.code == 'not-found') {
        message = _tr(
          'Không tìm thấy người dùng. Hãy kiểm tra email hoặc User ID.',
          'User not found. Please check the email or User ID.',
        );
      } else if (e.code == 'permission-denied') {
        message = _tr(
          'Bạn không có quyền gửi thông báo.',
          'You are not authorised to send broadcasts.',
        );
      }

      _showError(message);
    } catch (e) {
      if (!mounted) return;
      _showError(
        _tr(
          'Đã xảy ra lỗi. Vui lòng thử lại.',
          'Something went wrong. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildTargetOption({
    required String value,
    required String title,
    required String description,
  }) {
    final selected = _target == value;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _isSending
          ? null
          : () {
              setState(() {
                _target = value;
                _identifierController.clear();
              });
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? _primaryColor.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? _primaryColor
                : Theme.of(context).dividerColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _targetIcon(value),
              color: selected
                  ? _primaryColor
                  : Colors.grey,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected
                  ? _primaryColor
                  : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: _primaryColor,
          width: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tr('Admin Broadcast', 'Admin Broadcast'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFB83280),
                        Color(0xFF7B2D8E),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tr(
                                'Send Announcement',
                                'Send Announcement',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _tr(
                                'Gửi tin nhắn trực tiếp đến Inbox của người dùng.',
                                'Send a message directly to users’ Inbox.',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                _buildSectionTitle(
                  _tr('1. Chọn người nhận', '1. Select Recipients'),
                ),

                _buildTargetOption(
                  value: 'all',
                  title: 'All Users',
                  description: _targetDescription('all'),
                ),
                _buildTargetOption(
                  value: 'vip',
                  title: 'VIP Members',
                  description: _targetDescription('vip'),
                ),
                _buildTargetOption(
                  value: 'individual',
                  title: 'Individual User',
                  description: _targetDescription('individual'),
                ),
                _buildTargetOption(
                  value: 'free',
                  title: 'Free Members',
                  description: _targetDescription('free'),
                ),

                if (_target == 'individual') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _identifierController,
                    enabled: !_isSending,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(
                      label: _tr(
                        'Email hoặc User ID',
                        'Email or User ID',
                      ),
                      hint: _tr(
                        'Nhập email hoặc Firebase User ID',
                        'Enter email or Firebase User ID',
                      ),
                      icon: Icons.person_search_rounded,
                    ),
                    validator: (value) {
                      if (_target == 'individual' &&
                          (value == null || value.trim().isEmpty)) {
                        return _tr(
                          'Vui lòng nhập email hoặc User ID.',
                          'Please enter an email or User ID.',
                        );
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 26),

                _buildSectionTitle(
                  _tr('2. Nội dung thông báo', '2. Message Content'),
                ),

                TextFormField(
                  controller: _titleController,
                  enabled: !_isSending,
                  maxLength: 100,
                  decoration: _inputDecoration(
                    label: _tr('Tiêu đề', 'Title'),
                    hint: _tr(
                      'Nhập tiêu đề thông báo',
                      'Enter announcement title',
                    ),
                    icon: Icons.title_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return _tr(
                        'Vui lòng nhập tiêu đề.',
                        'Please enter a title.',
                      );
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _messageController,
                  enabled: !_isSending,
                  minLines: 5,
                  maxLines: 8,
                  maxLength: 3000,
                  decoration: _inputDecoration(
                    label: _tr('Nội dung', 'Message'),
                    hint: _tr(
                      'Nhập nội dung thông báo tại đây...',
                      'Write your announcement here...',
                    ),
                    icon: Icons.message_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return _tr(
                        'Vui lòng nhập nội dung.',
                        'Please enter a message.',
                      );
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _tr(
                            'Thông báo sẽ được lưu vào Inbox của người nhận. Người dùng vẫn có thể đọc khi tắt Push Notifications.',
                            'Messages are saved in recipients’ Inbox. Users can still read them even if Push Notifications are disabled.',
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isSending ? null : _sendBroadcast,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _isSending
                          ? _tr('Đang gửi...', 'Sending...')
                          : _tr(
                              'GỬI THÔNG BÁO',
                              'SEND BROADCAST',
                            ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          _primaryColor.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

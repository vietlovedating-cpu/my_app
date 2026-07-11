import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'view_other_profile_page.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'trusted_contacts_page.dart';
import 'package:flutter_sms/flutter_sms.dart';

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
  final TextEditingController _dateLocationController =
    TextEditingController();

DateTime? _selectedDate;
TimeOfDay? _selectedTime;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  
  bool _isSendingImage = false;

File? _pendingImageFile;

final AudioRecorder _audioRecorder = AudioRecorder();
final AudioPlayer _audioPlayer = AudioPlayer();

String? _playingVoiceUrl;
final ValueNotifier<String?> _playingVoiceNotifier =
    ValueNotifier<String?>(null);

bool _isRecordingVoice = false;
final ValueNotifier<bool> _isRecordingVoiceNotifier =
    ValueNotifier<bool>(false);

final ValueNotifier<String?> _pendingVoicePathNotifier =
    ValueNotifier<String?>(null);
bool _isSendingVoice = false;
final ValueNotifier<bool> _isSendingVoiceNotifier =
    ValueNotifier<bool>(false);
String? _pendingVoicePath;
int _recordSeconds = 0;
DateTime? _recordStartedAt;
final ValueNotifier<int> _recordSecondsNotifier =
    ValueNotifier<int>(0);

Timer? _recordTimer;

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
  String _formatDatePlanDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}

String _formatDatePlanTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0
      ? 12
      : time.hourOfPeriod;

  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';

  return '$hour:$minute $period';
}

DateTime _combineDateAndTime(
  DateTime date,
  TimeOfDay time,
) {
  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
}

Future<void> _shareDatePlanBySms({
  required DateTime selectedDate,
  required TimeOfDay selectedTime,
  required String location,
  required List<Map<String, dynamic>> selectedContacts,
}) async {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    throw Exception('User is not signed in');
  }

  final scheduledAt = _combineDateAndTime(
    selectedDate,
    selectedTime,
  );

  final contactCopies = selectedContacts.map((contact) {
    return {
      'contactId':
          (contact['contactId'] ?? '').toString(),
      'name': (contact['name'] ?? '').toString(),
      'phone': (contact['phone'] ?? '').toString(),
      'relationship':
          (contact['relationship'] ?? '').toString(),
    };
  }).toList();

  final datePlanReference = FirebaseFirestore.instance
    .collection('users')
    .doc(currentUser.uid)
    .collection('datePlans')
    .doc(widget.chatId);

  await datePlanReference.set({
  'datePlanId': widget.chatId,
  'ownerId': currentUser.uid,
  'ownerName': _currentUserName,
  'chatId': widget.chatId,

  'partnerId': widget.otherUserId,
  'partnerName': _effectiveOtherUserName,
  'partnerPhotoUrl': _effectiveOtherUserPhotoUrl,

  'scheduledAt': Timestamp.fromDate(scheduledAt),
  'location': location,

  'selectedContacts': contactCopies,

  'status': 'scheduled',
  'shareMethod': 'sms',

  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
  'shareOpenedAt': FieldValue.serverTimestamp(),

  'safeConfirmedAt': null,
  'cancelledAt': null,
}, SetOptions(merge: true));

  final ownerName = _currentUserName.trim().isNotEmpty
      ? _currentUserName.trim()
      : _tr('Người dùng VietLove', 'A VietLove user');

  final partnerName =
      _effectiveOtherUserName.trim().isNotEmpty
          ? _effectiveOtherUserName.trim()
          : _tr('một người dùng VietLove', 'a VietLove user');

  final message = isVi
      ? '''
VietLove Dating – Kế hoạch hẹn hò an toàn

$ownerName sắp gặp: $partnerName

Ngày: ${_formatDatePlanDate(selectedDate)}
Giờ: ${_formatDatePlanTime(selectedTime)}
Địa điểm: $location

Mã kế hoạch an toàn: ${datePlanReference.id}

Vui lòng liên hệ với $ownerName sau buổi hẹn để bảo đảm họ đã về nhà an toàn.
'''
      : '''
VietLove Dating – Safe Date Plan

$ownerName is meeting: $partnerName

Date: ${_formatDatePlanDate(selectedDate)}
Time: ${_formatDatePlanTime(selectedTime)}
Location: $location

Safety plan ID: ${datePlanReference.id}

Please check in with $ownerName after the date to make sure they arrived home safely.
''';

  final recipients = selectedContacts
      .map(
        (contact) =>
            (contact['phone'] ?? '').toString().trim(),
      )
      .where((phone) => phone.isNotEmpty)
      .toList();

  if (recipients.isEmpty) {
    throw Exception('No valid phone number selected');
  }

  await sendSMS(
    message: message.trim(),
    recipients: recipients,
  );
}
Future<void> _openDatePlan() async {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) return;

  try {
    final planDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('datePlans')
        .doc(widget.chatId)
        .get();

    if (!mounted) return;

    final data = planDoc.data();

    final status =
        (data?['status'] ?? '').toString().trim().toLowerCase();

    final hasActivePlan =
        planDoc.exists &&
        data != null &&
        status == 'scheduled';

    if (hasActivePlan) {
      _showExistingDatePlanSheet(data);
    } else {
      _selectedDate = null;
      _selectedTime = null;
      _dateLocationController.clear();

      _showDatePlanSheet();
    }
  } catch (e) {
    debugPrint('OPEN DATE PLAN ERROR: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Không thể tải kế hoạch hẹn hò.',
            'Could not load the date plan.',
          ),
        ),
      ),
    );
  }
}
  void _showExistingDatePlanSheet(
  Map<String, dynamic> planData,
) {
  final scheduledTimestamp =
      planData['scheduledAt'] as Timestamp?;

  final scheduledAt = scheduledTimestamp?.toDate();

  final location =
      (planData['location'] ?? '').toString().trim();

  final partnerName =
      (planData['partnerName'] ?? _effectiveOtherUserName)
          .toString()
          .trim();

  final partnerPhotoUrl =
      (planData['partnerPhotoUrl'] ??
              _effectiveOtherUserPhotoUrl)
          .toString()
          .trim();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      bool isUpdating = false;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius:
                            BorderRadius.circular(999),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFE4EF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _tr(
                            'Cuộc hẹn sắp tới',
                            'Upcoming Date',
                          ),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8A2F6A),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: isUpdating
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                              },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7FB),
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFD5E6),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildAvatar(
                          partnerPhotoUrl,
                          radius: 34,
                        ),

                        const SizedBox(height: 10),

                        Text(
                          partnerName.isNotEmpty
                              ? partnerName
                              : _tr(
                                  'Người dùng VietLove',
                                  'VietLove user',
                                ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 18),

                        _buildDatePlanDetailRow(
                          icon:
                              Icons.calendar_today_rounded,
                          label: _tr('Ngày', 'Date'),
                          value: scheduledAt == null
                              ? _tr(
                                  'Chưa xác định',
                                  'Not available',
                                )
                              : _formatDatePlanDate(
                                  scheduledAt,
                                ),
                        ),

                        const SizedBox(height: 12),

                        _buildDatePlanDetailRow(
                          icon: Icons.schedule_rounded,
                          label: _tr('Giờ', 'Time'),
                          value: scheduledAt == null
                              ? _tr(
                                  'Chưa xác định',
                                  'Not available',
                                )
                              : _formatDatePlanTime(
                                  TimeOfDay.fromDateTime(
                                    scheduledAt,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 12),

                        _buildDatePlanDetailRow(
                          icon:
                              Icons.location_on_outlined,
                          label:
                              _tr('Địa điểm', 'Location'),
                          value: location.isNotEmpty
                              ? location
                              : _tr(
                                  'Chưa xác định',
                                  'Not available',
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isUpdating
                          ? null
                          : () {
                              if (scheduledAt != null) {
                                _selectedDate = DateTime(
                                  scheduledAt.year,
                                  scheduledAt.month,
                                  scheduledAt.day,
                                );

                                _selectedTime =
                                    TimeOfDay.fromDateTime(
                                  scheduledAt,
                                );
                              }

                              _dateLocationController.text =
                                  location;

                              Navigator.pop(sheetContext);

                              _showDatePlanSheet();
                            },
                      icon: const Icon(
                        Icons.edit_calendar_rounded,
                      ),
                      label: Text(
                        _tr(
                          'Chỉnh sửa kế hoạch',
                          'Edit Date Plan',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isUpdating
                          ? null
                          : () async {
                              final confirmed =
                                  await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    title: Text(
                                      _tr(
                                        'Bạn đã về nhà an toàn?',
                                        'Are you home safely?',
                                      ),
                                    ),
                                    content: Text(
                                      _tr(
                                        'Xác nhận rằng cuộc hẹn đã kết thúc và bạn đã về nhà an toàn.',
                                        'Confirm that the date has ended and you are home safely.',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(
                                            dialogContext,
                                            false,
                                          );
                                        },
                                        child: Text(
                                          _tr('Hủy', 'Cancel'),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(
                                            dialogContext,
                                            true,
                                          );
                                        },
                                        child: Text(
                                          _tr(
                                            'Tôi an toàn',
                                            'I am safe',
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirmed != true) return;

                              setSheetState(() {
                                isUpdating = true;
                              });

                              try {
                                await _updateDatePlanStatus(
                                  status: 'completed',
                                  additionalData: {
                                    'safeConfirmedAt':
                                        FieldValue
                                            .serverTimestamp(),
                                    'completedAt': FieldValue
                                        .serverTimestamp(),
                                  },
                                );

                                if (!mounted) return;

                                Navigator.pop(sheetContext);

                                ScaffoldMessenger.of(
                                  this.context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _tr(
                                        'Rất vui vì bạn đã về nhà an toàn ❤️',
                                        'We are glad you arrived home safely ❤️',
                                      ),
                                    ),
                                  ),
                                );
                              } catch (e) {
                                debugPrint(
                                  'SAFE CONFIRM ERROR: $e',
                                );

                                if (!mounted) return;

                                setSheetState(() {
                                  isUpdating = false;
                                });
                              }
                            },
                      icon: const Icon(
                        Icons.verified_user_rounded,
                      ),
                      label: Text(
                        _tr(
                          'Tôi đã về nhà an toàn',
                          'I’m Home Safely',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            const Color(0xFF2E7D32),
                        side: const BorderSide(
                          color: Color(0xFF81C784),
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: isUpdating
                          ? null
                          : () async {
                              final confirmed =
                                  await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    title: Text(
                                      _tr(
                                        'Hủy kế hoạch hẹn?',
                                        'Cancel Date Plan?',
                                      ),
                                    ),
                                    content: Text(
                                      _tr(
                                        'Kế hoạch này sẽ được đánh dấu là đã hủy.',
                                        'This date plan will be marked as cancelled.',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(
                                            dialogContext,
                                            false,
                                          );
                                        },
                                        child: Text(
                                          _tr('Không', 'No'),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(
                                            dialogContext,
                                            true,
                                          );
                                        },
                                        child: Text(
                                          _tr(
                                            'Hủy kế hoạch',
                                            'Cancel Plan',
                                          ),
                                          style:
                                              const TextStyle(
                                            color: Colors.red,
                                            fontWeight:
                                                FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirmed != true) return;

                              setSheetState(() {
                                isUpdating = true;
                              });

                              try {
                                await _updateDatePlanStatus(
                                  status: 'cancelled',
                                  additionalData: {
                                    'cancelledAt':
                                        FieldValue
                                            .serverTimestamp(),
                                  },
                                );

                                if (!mounted) return;

                                Navigator.pop(sheetContext);

                                ScaffoldMessenger.of(
                                  this.context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _tr(
                                        'Đã hủy kế hoạch hẹn.',
                                        'Date plan cancelled.',
                                      ),
                                    ),
                                  ),
                                );
                              } catch (e) {
                                debugPrint(
                                  'CANCEL DATE PLAN ERROR: $e',
                                );

                                if (!mounted) return;

                                setSheetState(() {
                                  isUpdating = false;
                                });
                              }
                            },
                      icon: const Icon(
                        Icons.event_busy_rounded,
                        color: Colors.red,
                      ),
                      label: Text(
                        _tr(
                          'Hủy kế hoạch hẹn',
                          'Cancel Date Plan',
                        ),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  if (isUpdating)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
Widget _buildDatePlanDetailRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Color(0xFFFFE4EF),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: const Color(0xFFE91E63),
        ),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
Future<void> _updateDatePlanStatus({
  required String status,
  Map<String, dynamic>? additionalData,
}) async {
  final currentUser =
      FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    throw Exception('User is not signed in');
  }

  await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .collection('datePlans')
      .doc(widget.chatId)
      .set({
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
    if (additionalData != null)
      ...additionalData,
  }, SetOptions(merge: true));
}
  void _showDatePlanSheet() {
  DateTime? tempSelectedDate = _selectedDate;
  TimeOfDay? tempSelectedTime = _selectedTime;

  final Set<String> selectedContactIds = {};
  final Map<String, Map<String, dynamic>>
      selectedContactData = {};

  bool isSharing = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final keyboardBottom =
              MediaQuery.of(context).viewInsets.bottom;

          return SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * 0.90,
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                keyboardBottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius:
                              BorderRadius.circular(999),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFE4EF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFFE91E63),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _tr(
                              'Chia sẻ kế hoạch hẹn hò',
                              'Share Date Plan',
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8A2F6A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isSharing
                              ? null
                              : () {
                                  Navigator.pop(
                                    sheetContext,
                                  );
                                },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(
                      _tr(
                        'Chia sẻ thời gian và địa điểm với người thân hoặc bạn bè mà bạn tin tưởng.',
                        'Share the time and location with a trusted friend or family member.',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7FB),
                        borderRadius:
                            BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFFD5E6),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(
                            _effectiveOtherUserPhotoUrl,
                            radius: 25,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _tr(
                                    'Bạn sẽ gặp',
                                    'You are meeting',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _effectiveOtherUserName
                                          .trim()
                                          .isNotEmpty
                                      ? _effectiveOtherUserName
                                          .trim()
                                      : _tr(
                                          'Người dùng VietLove',
                                          'VietLove user',
                                        ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      _tr(
                        'Ngày hẹn',
                        'Date',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 8),

                    InkWell(
                      onTap: isSharing
                          ? null
                          : () async {
                              final now = DateTime.now();

                              final pickedDate =
                                  await showDatePicker(
                                context: context,
                                initialDate:
                                    tempSelectedDate ?? now,
                                firstDate: DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                ),
                                lastDate: DateTime(
                                  now.year + 2,
                                ),
                              );

                              if (pickedDate == null) return;

                              setSheetState(() {
                                tempSelectedDate =
                                    pickedDate;
                              });
                            },
                      borderRadius:
                          BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7FB),
                          borderRadius:
                              BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                const Color(0xFFFFD5E6),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              color: Color(0xFFE91E63),
                              size: 21,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tempSelectedDate == null
                                    ? _tr(
                                        'Chọn ngày',
                                        'Select date',
                                      )
                                    : _formatDatePlanDate(
                                        tempSelectedDate!,
                                      ),
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.w700,
                                  color:
                                      tempSelectedDate ==
                                              null
                                          ? Colors.black45
                                          : Colors.black87,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons
                                  .keyboard_arrow_down_rounded,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      _tr(
                        'Giờ hẹn',
                        'Time',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 8),

                    InkWell(
                      onTap: isSharing
                          ? null
                          : () async {
                              final pickedTime =
                                  await showTimePicker(
                                context: context,
                                initialTime:
                                    tempSelectedTime ??
                                        TimeOfDay.now(),
                              );

                              if (pickedTime == null) return;

                              setSheetState(() {
                                tempSelectedTime =
                                    pickedTime;
                              });
                            },
                      borderRadius:
                          BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7FB),
                          borderRadius:
                              BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                const Color(0xFFFFD5E6),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              color: Color(0xFFE91E63),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tempSelectedTime == null
                                    ? _tr(
                                        'Chọn giờ',
                                        'Select time',
                                      )
                                    : _formatDatePlanTime(
                                        tempSelectedTime!,
                                      ),
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.w700,
                                  color:
                                      tempSelectedTime ==
                                              null
                                          ? Colors.black45
                                          : Colors.black87,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons
                                  .keyboard_arrow_down_rounded,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      _tr(
                        'Địa điểm',
                        'Location',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller:
                          _dateLocationController,
                      enabled: !isSharing,
                      textCapitalization:
                          TextCapitalization.words,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: _tr(
                          'Ví dụ: Nhà hàng tại Bankstown',
                          'Example: Restaurant in Bankstown',
                        ),
                        prefixIcon: const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFFE91E63),
                        ),
                        filled: true,
                        fillColor:
                            const Color(0xFFFFF7FB),
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color:
                                Color(0xFFFFD5E6),
                          ),
                        ),
                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE91E63),
                            width: 1.3,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    StreamBuilder<
                        QuerySnapshot<
                            Map<String, dynamic>>>(
                      stream: FirebaseAuth
                                  .instance.currentUser ==
                              null
                          ? null
                          : FirebaseFirestore.instance
                              .collection('users')
                              .doc(
                                FirebaseAuth.instance
                                    .currentUser!.uid,
                              )
                              .collection(
                                'trustedContacts',
                              )
                              .orderBy(
                                'createdAt',
                                descending: false,
                              )
                              .snapshots(),
                      builder: (context, snapshot) {
                        final contacts =
                            snapshot.data?.docs ?? [];

                        return Container(
                          padding:
                              const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFF7FB),
                            borderRadius:
                                BorderRadius.circular(18),
                            border: Border.all(
                              color:
                                  const Color(0xFFFFD5E6),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.shield_rounded,
                                    color:
                                        Color(0xFFE91E63),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      _tr(
                                        'Liên hệ an toàn',
                                        'Trusted Contacts',
                                      ),
                                      style:
                                          const TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (selectedContactIds
                                      .isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFFE4EF,
                                        ),
                                        borderRadius:
                                            BorderRadius
                                                .circular(999),
                                      ),
                                      child: Text(
                                        selectedContactIds
                                            .length
                                            .toString(),
                                        style:
                                            const TextStyle(
                                          color: Color(
                                            0xFFE91E63,
                                          ),
                                          fontWeight:
                                              FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              if (snapshot
                                      .connectionState ==
                                  ConnectionState.waiting)
                                const Center(
                                  child: Padding(
                                    padding:
                                        EdgeInsets.all(14),
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else if (snapshot.hasError)
                                Padding(
                                  padding:
                                      const EdgeInsets.all(
                                    10,
                                  ),
                                  child: Text(
                                    _tr(
                                      'Không thể tải liên hệ an toàn.',
                                      'Could not load trusted contacts.',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.red,
                                    ),
                                  ),
                                )
                              else if (contacts.isEmpty)
                                Padding(
                                  padding: const EdgeInsets
                                      .symmetric(
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    _tr(
                                      'Bạn chưa có liên hệ an toàn. Hãy thêm người thân hoặc bạn bè trước.',
                                      'You do not have any trusted contacts yet. Add a friend or family member first.',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      height: 1.4,
                                    ),
                                  ),
                                )
                              else
                                ...contacts.map((contact) {
                                  final data =
                                      contact.data();

                                  final name =
                                      (data['name'] ?? '')
                                          .toString()
                                          .trim();

                                  final phone =
                                      (data['phone'] ?? '')
                                          .toString()
                                          .trim();

                                  final relationship =
                                      (data['relationship'] ??
                                              '')
                                          .toString();

                                  final isSelected =
                                      selectedContactIds
                                          .contains(
                                    contact.id,
                                  );

                                  return CheckboxListTile(
                                    value: isSelected,
                                    enabled:
                                        !isSharing &&
                                            phone.isNotEmpty,
                                    contentPadding:
                                        EdgeInsets.zero,
                                    dense: true,
                                    activeColor:
                                        const Color(
                                      0xFFE91E63,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity
                                            .leading,
                                    title: Text(
                                      name.isNotEmpty
                                          ? name
                                          : _tr(
                                              'Không có tên',
                                              'No name',
                                            ),
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      phone.isNotEmpty
                                          ? phone
                                          : _tr(
                                              'Chưa có số điện thoại',
                                              'No phone number',
                                            ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            phone.isNotEmpty
                                                ? Colors
                                                    .black54
                                                : Colors.red,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setSheetState(() {
                                        if (value == true) {
                                          selectedContactIds
                                              .add(
                                            contact.id,
                                          );

                                          selectedContactData[
                                              contact.id] = {
                                            'contactId':
                                                contact.id,
                                            'name': name,
                                            'phone': phone,
                                            'relationship':
                                                relationship,
                                          };
                                        } else {
                                          selectedContactIds
                                              .remove(
                                            contact.id,
                                          );

                                          selectedContactData
                                              .remove(
                                            contact.id,
                                          );
                                        }
                                      });
                                    },
                                  );
                                }),

                              const SizedBox(height: 8),

                              SizedBox(
                                width: double.infinity,
                                child:
                                    OutlinedButton.icon(
                                  onPressed: isSharing
                                      ? null
                                      : () async {
                                          await Navigator
                                              .push(
                                            this.context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  TrustedContactsPage(
                                                languageCode:
                                                    widget
                                                        .languageCode,
                                              ),
                                            ),
                                          );
                                        },
                                  icon: const Icon(
                                    Icons
                                        .manage_accounts_rounded,
                                  ),
                                  label: Text(
                                    contacts.isEmpty
                                        ? _tr(
                                            'Thêm liên hệ an toàn',
                                            'Add Trusted Contact',
                                          )
                                        : _tr(
                                            'Quản lý liên hệ',
                                            'Manage Contacts',
                                          ),
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton
                                      .styleFrom(
                                    foregroundColor:
                                        const Color(
                                      0xFFE91E63,
                                    ),
                                    side:
                                        const BorderSide(
                                      color: Color(
                                        0xFFFFC7DE,
                                      ),
                                    ),
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      vertical: 12,
                                    ),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSharing
                            ? null
                            : () async {
                                final location =
                                    _dateLocationController
                                        .text
                                        .trim();

                                if (tempSelectedDate ==
                                    null) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _tr(
                                          'Vui lòng chọn ngày hẹn.',
                                          'Please select the date.',
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (tempSelectedTime ==
                                    null) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _tr(
                                          'Vui lòng chọn giờ hẹn.',
                                          'Please select the time.',
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (location.isEmpty) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _tr(
                                          'Vui lòng nhập địa điểm hẹn.',
                                          'Please enter the location.',
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (selectedContactData
                                    .isEmpty) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _tr(
                                          'Vui lòng chọn ít nhất một liên hệ an toàn.',
                                          'Please select at least one trusted contact.',
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final scheduledAt =
                                    _combineDateAndTime(
                                  tempSelectedDate!,
                                  tempSelectedTime!,
                                );

                                if (scheduledAt.isBefore(
                                  DateTime.now(),
                                )) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _tr(
                                          'Thời gian hẹn phải ở trong tương lai.',
                                          'The date must be in the future.',
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                FocusScope.of(context)
                                    .unfocus();

                                setSheetState(() {
                                  isSharing = true;
                                });

                                try {
                                  await _shareDatePlanBySms(
                                    selectedDate:
                                        tempSelectedDate!,
                                    selectedTime:
                                        tempSelectedTime!,
                                    location: location,
                                    selectedContacts:
                                        selectedContactData
                                            .values
                                            .toList(),
                                  );

                                  _selectedDate =
                                      tempSelectedDate;
                                  _selectedTime =
                                      tempSelectedTime;

                                  if (!mounted) return;

                                  Navigator.pop(
                                    sheetContext,
                                  );

                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _tr(
                                          'Kế hoạch đã được lưu. Hãy kiểm tra và gửi tin nhắn.',
                                          'The plan was saved. Review and send the message.',
                                        ),
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint(
                                    'SHARE DATE PLAN ERROR: $e',
                                  );

                                  if (!mounted) return;

                                  setSheetState(() {
                                    isSharing = false;
                                  });

                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _tr(
                                          'Không thể mở ứng dụng tin nhắn. Vui lòng thử lại.',
                                          'Could not open the messaging app. Please try again.',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: isSharing
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .send_to_mobile_rounded,
                              ),
                        label: Text(
                          isSharing
                              ? _tr(
                                  'Đang chuẩn bị...',
                                  'Preparing...',
                                )
                              : _tr(
                                  'Chia sẻ kế hoạch',
                                  'Share Date Plan',
                                ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFFF48FB1),
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 17,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _tr(
                              'VietLove sẽ mở ứng dụng Tin nhắn. Bạn vẫn cần kiểm tra và bấm gửi.',
                              'VietLove will open your messaging app. You still need to review and tap send.',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  @override
void initState() {
  super.initState();
  _loadCurrentUserInfo();
  _loadOtherUserInfo();
  _markIncomingMessagesAsRead();

  _audioPlayer.onPlayerComplete.listen((_) {
  _playingVoiceNotifier.value = null;
});
}

 @override
void dispose() {
  _recordTimer?.cancel();
_recordSecondsNotifier.dispose();
_playingVoiceNotifier.dispose();
_isRecordingVoiceNotifier.dispose();
_pendingVoicePathNotifier.dispose();
_isSendingVoiceNotifier.dispose();
  _audioRecorder.dispose();
  _audioPlayer.dispose();
  _messageController.dispose();
  _dateLocationController.dispose();
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
Future<void> _startVoiceRecording() async {
  final hasPermission = await _audioRecorder.hasPermission();

  if (!hasPermission) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'Cần quyền micro',
            'Microphone permission required',
          ),
        ),
      ),
    );

    return;
  }

  final dir = await getTemporaryDirectory();

  final path =
      '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

  await _audioRecorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 44100,
    ),
    path: path,
  );

  if (!mounted) return;

  _isRecordingVoice = true;
_pendingVoicePath = null;
_recordSeconds = 0;
_recordStartedAt = DateTime.now();

_isRecordingVoiceNotifier.value = true;
_pendingVoicePathNotifier.value = null;
  _recordTimer?.cancel();
_recordSecondsNotifier.value = 0;

_recordTimer = Timer.periodic(
  const Duration(seconds: 1),
  (_) {
    _recordSecondsNotifier.value++;
  },
);
}

Future<void> _stopVoiceRecording() async {
  _recordTimer?.cancel();
  final path = await _audioRecorder.stop();

if (path == null) {
  debugPrint('VOICE STOP PATH NULL');
  return;
}

final file = File(path);
debugPrint('RECORDED VOICE PATH: $path');
debugPrint('RECORDED VOICE EXISTS: ${await file.exists()}');
debugPrint('RECORDED VOICE SIZE: ${await file.length()}');

  final startedAt = _recordStartedAt;

  int durationSeconds = 1;

  if (startedAt != null) {
    durationSeconds =
        DateTime.now().difference(startedAt).inSeconds;

    if (durationSeconds < 1) {
      durationSeconds = 1;
    }
  }

  if (!mounted) return;

  _isRecordingVoice = false;
_pendingVoicePath = path;
_recordSeconds = durationSeconds;
_recordStartedAt = null;

_isRecordingVoiceNotifier.value = false;
_pendingVoicePathNotifier.value = path;
}

String _formatVoiceDuration(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
Future<void> _sendPendingVoice() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null ||
      _pendingVoicePath == null ||
      _isSendingVoice) {
    return;
  }

  try {
  _isSendingVoice = true;
  _isSendingVoiceNotifier.value = true;

  final file = File(_pendingVoicePath!);

    if (!await file.exists()) {
      throw Exception('Voice file does not exist');
    }
    debugPrint('SEND VOICE PATH: ${file.path}');
debugPrint('SEND VOICE SIZE: ${await file.length()}');

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.m4a';

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('chat_voice')
        .child(widget.chatId)
        .child(fileName);

    await storageRef.putFile(
      file,
      SettableMetadata(
        contentType: 'audio/mp4',
      ),
    );

    final voiceUrl = await storageRef.getDownloadURL();

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
      'type': 'voice',
      'imageUrl': '',
      'voiceUrl': voiceUrl,
      'voiceDuration': _recordSeconds,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await firestore.collection('chats').doc(widget.chatId).set({
      'chatId': widget.chatId,
      'participants': [user.uid, widget.otherUserId],
      'lastMessage': _tr('Tin nhắn thoại', 'Voice message'),
      'lastMessageType': 'voice',
      'lastSenderId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'typing': {
        user.uid: false,
        widget.otherUserId: false,
      },
    }, SetOptions(merge: true));

    await firestore.collection('matches').doc(widget.chatId).set({
      'lastMessage': _tr('Tin nhắn thoại', 'Voice message'),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

_pendingVoicePath = null;
_recordSeconds = 0;
_isRecordingVoice = false;

_pendingVoicePathNotifier.value = null;
_recordSecondsNotifier.value = 0;
_isRecordingVoiceNotifier.value = false;

    _scrollToBottom();
  } catch (e) {
    debugPrint('SEND VOICE ERROR: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Send voice error: $e'),
      ),
    );
  } finally {
  _isSendingVoice = false;
  _isSendingVoiceNotifier.value = false;
}
}
  Future<void> _sendMessage() async {
  final user = FirebaseAuth.instance.currentUser;
  final text = _messageController.text.trim();

  if (user == null || text.isEmpty) return;

  if (!mounted) return;
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
Future<void> _deleteMessage(String messageId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await FirebaseFirestore.instance
    .collection('chats')
    .doc(widget.chatId)
    .collection('messages')
    .doc(messageId)
    .update({
  'isDeleted': true,
  'text': 'Message deleted',
  'type': 'text',
  'imageUrl': '',
  'editedAt': null,
  'deletedAt': FieldValue.serverTimestamp(),
});
}

Future<void> _editMessage(String messageId, String oldText) async {
  final controller = TextEditingController(text: oldText);

  final newText = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(_tr('Sửa tin nhắn', 'Edit message')),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: _tr('Nhập tin nhắn...', 'Type a message...'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_tr('Hủy', 'Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(_tr('Lưu', 'Save')),
        ),
      ],
    ),
  );


  if (newText == null || newText.isEmpty || newText == oldText.trim()) return;

  await FirebaseFirestore.instance
      .collection('chats')
      .doc(widget.chatId)
      .collection('messages')
      .doc(messageId)
      .update({
    'text': newText,
    'editedAt': FieldValue.serverTimestamp(),
  });
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
  Future<void> _setMessageReaction(
  String messageId,
  String reaction,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await FirebaseFirestore.instance
      .collection('chats')
      .doc(widget.chatId)
      .collection('messages')
      .doc(messageId)
      .set({
    'reactions': {
      user.uid: reaction,
    },
  }, SetOptions(merge: true));
}
void _showMessageOptions({
  required String messageId,
  required String text,
  required String type,
  required bool isMe,
}) {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          SizedBox(
  height: 220,
  child: SingleChildScrollView(
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final reaction in [
          '😀', '😃', '😄', '😁', '😆', '🥹', '😅', '😂',
          '🤣', '🥲', '😊', '😇', '🙂', '🙃', '😉', '😌',
          '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛',
          '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩',
          '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁',
          '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭',
          '😤', '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶',
          '😱', '😨', '😰', '😥', '😓', '🤗', '🤔', '🫣',
          '🤭', '🫢', '🫡', '👍', '👎', '❤️', '🔥', '👏',
          '🙏',
        ])
          InkWell(
            onTap: () {
              Navigator.pop(context);
              _setMessageReaction(messageId, reaction);
            },
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                reaction,
                style: const TextStyle(fontSize: 27),
              ),
            ),
          ),
      ],
    ),
  ),
),
          if (isMe && type == 'text')
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(_tr('Sửa tin nhắn', 'Edit message')),
              onTap: () {
                Navigator.pop(context);
                _editMessage(messageId, text);
              },
            ),
            if (isMe)
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(
              _tr('Xóa tin nhắn', 'Delete message'),
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              _deleteMessage(messageId);
            },
          ),
        ],
      ),
    ),
  );
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
  required String likedContentType,
  required String likedContentText,
  required int likedContentIndex,
}) {
  if (type == 'content_like') {
  final normalizedContentType =
      likedContentType.trim().toLowerCase();

  final comment = text.trim();
  final contentValue = likedContentText.trim();

  final actionLabel = normalizedContentType == 'photo'
      ? isMe
          ? _tr(
              'Bạn đã thích ảnh này',
              'You liked this photo',
            )
          : _tr(
              'Đã thích ảnh của bạn',
              'Liked your photo',
            )
      : isMe
          ? _tr(
              'Bạn đã thích câu trả lời này',
              'You liked this answer',
            )
          : _tr(
              'Đã thích câu trả lời của bạn',
              'Liked your answer',
            );

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 17,
            color: isMe
                ? Colors.white
                : const Color(0xFFE91E63),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              actionLabel,
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : const Color(0xFFE91E63),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),

      const SizedBox(height: 9),

      if (normalizedContentType == 'photo' &&
          contentValue.isNotEmpty)
        FutureBuilder<String?>(
          future: _resolveImageUrl(contentValue),
          builder: (context, snapshot) {
            final resolvedUrl = snapshot.data;

            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const SizedBox(
                width: 210,
                height: 180,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (resolvedUrl == null || resolvedUrl.isEmpty) {
              return Container(
                width: 210,
                height: 120,
                alignment: Alignment.center,
                color: Colors.grey.shade200,
                child: Text(
                  _tr(
                    'Không tải được ảnh',
                    'Image failed to load',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                resolvedUrl,
                width: 210,
                height: 210,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    width: 210,
                    height: 120,
                    alignment: Alignment.center,
                    color: Colors.grey.shade200,
                    child: Text(
                      _tr(
                        'Không tải được ảnh',
                        'Image failed to load',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),

      if (normalizedContentType == 'prompt' &&
          contentValue.isNotEmpty)
        Container(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withOpacity(0.16)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMe
                  ? Colors.white.withOpacity(0.35)
                  : const Color(0xFFFFC7DE),
            ),
          ),
          child: Text(
            contentValue,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),

      if (comment.isNotEmpty) ...[
        const SizedBox(height: 9),
        Text(
          comment,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    ],
  );
}
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
if (type == 'voice') {
  final voiceUrl = imageUrl.trim();
 return ValueListenableBuilder<String?>(
  valueListenable: _playingVoiceNotifier,
  builder: (context, playingVoiceUrl, _) {
    final isPlaying = playingVoiceUrl == voiceUrl;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: voiceUrl.isEmpty
              ? null
              : () async {
                  try {
                    if (isPlaying) {
                      await _audioPlayer.pause();
                      _playingVoiceNotifier.value = null;
                      return;
                    }

                    _playingVoiceNotifier.value = voiceUrl;

                    await _audioPlayer.stop();
                    await _audioPlayer.play(
                      UrlSource(voiceUrl),
                    );
                  } catch (e) {
                    debugPrint('PLAY VOICE ERROR: $e');
                    _playingVoiceNotifier.value = null;
                  }
                },
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 24,
                color: isMe
                    ? Colors.white
                    : const Color(0xFFE91E63),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Voice',
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
  required String messageId,
  required bool isMe,
  required String text,
  required String type,
  required String imageUrl,
  required String likedContentType,
  required String likedContentText,
  required int likedContentIndex,
  required String timeText,
  required String avatarUrl,
  required bool isRead,
  required bool isDeleted,
  required bool isEdited,
  required Map<String, dynamic> reactions,
}) {
  final isHeart = type == 'heart';
  final isImage = type == 'image';
  final isContentLike = type == 'content_like';
final displayText = isDeleted
    ? _tr('Tin nhắn đã được xóa', 'Message deleted')
    : text;

final displayType = isDeleted ? 'text' : type;
final displayImageUrl = isDeleted ? '' : imageUrl;
  final avatarWidget = _buildAvatar(
    avatarUrl,
    radius: 18,
  );

  final bubbleContent = Column(
    crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Container(
        constraints: const BoxConstraints(maxWidth: 270),
       padding: isHeart
    ? const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      )
    : (isImage || isContentLike)
        ? const EdgeInsets.all(6)
        : const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
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
  type: displayType,
  text: displayText,
  imageUrl: displayImageUrl,
  isMe: isMe,
  likedContentType:
      isDeleted ? '' : likedContentType,
  likedContentText:
      isDeleted ? '' : likedContentText,
  likedContentIndex:
      isDeleted ? -1 : likedContentIndex,
),
      ),
      if (reactions.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Wrap(
      spacing: 4,
      children: reactions.values
          .map(
            (reaction) => Text(
              reaction.toString(),
              style: const TextStyle(fontSize: 18),
            ),
          )
          .toList(),
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
                isDeleted
    ? _tr('Đã xóa', 'Deleted')
    : isEdited
        ? _tr('Đã chỉnh sửa', 'Edited')
        : isRead
            ? _tr('Đã xem', 'Seen')
            : _tr('Đã gửi', 'Sent'),
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
final bubble = GestureDetector(
  onLongPress: !isDeleted
      ? () {
          _showMessageOptions(
            messageId: messageId,
            text: text,
            type: type,
            isMe: isMe,
          );
        }
      : null,
  child: bubbleContent,
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
          IconButton(
  tooltip: _tr(
    'Kế hoạch hẹn hò an toàn',
    'Safe Date Plan',
  ),
  onPressed: _showDatePlanSheet,
  icon: SizedBox(
    width: 30,
    height: 30,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 1,
          bottom: 1,
          child: Icon(
            Icons.calendar_month_rounded,
            size: 28,
            color: Color(0xFF8A2F6A),
          ),
        ),
        Positioned(
          right: -1,
          top: -2,
          child: Container(
            width: 15,
            height: 15,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7FB),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.favorite_rounded,
              size: 13,
              color: Color(0xFFE91E63),
            ),
          ),
        ),
      ],
    ),
  ),
),
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
          final likedContentType =
    (data['likedContentType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

final likedContentText =
    (data['likedContentText'] ?? '')
        .toString()
        .trim();

final rawLikedContentIndex =
    data['likedContentIndex'];

final likedContentIndex =
    rawLikedContentIndex is int
        ? rawLikedContentIndex
        : int.tryParse(
              rawLikedContentIndex?.toString() ?? '',
            ) ??
            -1;
          final imageUrl = type == 'voice'
    ? (data['voiceUrl'] ?? '').toString()
    : (data['imageUrl'] ?? '').toString();
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
final messageId = docs[index].id;
final isDeleted = data['isDeleted'] == true;
final isEdited = data['editedAt'] != null;
final reactions =
    Map<String, dynamic>.from(data['reactions'] ?? {});
          return _buildMessageBubble(
            messageId: messageId,
isDeleted: isDeleted,
isEdited: isEdited,
reactions: reactions,
  isMe: isMe,
  text: text,
  type: type,
  imageUrl: imageUrl,
  likedContentType: likedContentType,
likedContentText: likedContentText,
likedContentIndex: likedContentIndex,
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
       ValueListenableBuilder<bool>(
  valueListenable: _isRecordingVoiceNotifier,
  builder: (context, isRecording, _) {
    if (!isRecording) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFC7DE),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mic,
            color: Color(0xFFE91E63),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _recordSecondsNotifier,
              builder: (context, seconds, _) {
                return Text(
                  '${_tr('Đang ghi âm', 'Recording')} '
                  '${_formatVoiceDuration(seconds)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE91E63),
                  ),
                );
              },
            ),
          ),
          IconButton(
            onPressed: _stopVoiceRecording,
            icon: const Icon(
              Icons.stop_circle,
              color: Color(0xFFE91E63),
            ),
          ),
        ],
      ),
    );
  },
),

ValueListenableBuilder<String?>(
  valueListenable: _pendingVoicePathNotifier,
  builder: (context, pendingVoicePath, _) {
    if (pendingVoicePath == null) {
      return const SizedBox.shrink();
    }

    return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 8,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFFFFC7DE),
      ),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.mic,
          color: Color(0xFFE91E63),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${_tr('Tin nhắn thoại', 'Voice message')} '
            '${_formatVoiceDuration(_recordSeconds)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: () async {
  final path = _pendingVoicePath;

  _pendingVoicePath = null;
  _recordSeconds = 0;
  _recordStartedAt = null;

  _pendingVoicePathNotifier.value = null;
  _recordSecondsNotifier.value = 0;
  _isRecordingVoiceNotifier.value = false;

  if (path != null) {
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }
  }
},
          icon: const Icon(
            Icons.close,
            color: Colors.black54,
          ),
        ),
        ValueListenableBuilder<bool>(
  valueListenable: _isSendingVoiceNotifier,
  builder: (context, isSendingVoice, _) {
    return IconButton(
      onPressed:
          isSendingVoice ? null : _sendPendingVoice,
      icon: isSendingVoice
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : const Icon(
              Icons.send_rounded,
              color: Color(0xFFE91E63),
            ),
    );
  },
),
      ],
        ),
  );
  },
),

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
            InkWell(
  onTap: () {
    if (_isRecordingVoice) {
      _stopVoiceRecording();
    } else {
      _startVoiceRecording();
    }
  },
  borderRadius: BorderRadius.circular(999),
  child: Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: _isRecordingVoice
          ? const Color(0xFFE91E63)
          : const Color(0xFFFFE4EF),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFFFC7DE)),
    ),
    child: Icon(
      _isRecordingVoice ? Icons.stop : Icons.mic_none,
      color: _isRecordingVoice ? Colors.white : const Color(0xFFE91E63),
    ),
  ),
),
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
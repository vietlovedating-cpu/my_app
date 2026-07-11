import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TrustedContactsPage extends StatefulWidget {
  final String languageCode;

  const TrustedContactsPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<TrustedContactsPage> createState() =>
      _TrustedContactsPageState();
}

class _TrustedContactsPageState extends State<TrustedContactsPage> {
  bool _isSaving = false;

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  CollectionReference<Map<String, dynamic>>? get _contactsReference {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('trustedContacts');
  }

  String _relationshipLabel(String relationship) {
    switch (relationship.trim().toLowerCase()) {
      case 'family':
        return _tr('Gia đình', 'Family');

      case 'friend':
        return _tr('Bạn bè', 'Friend');

      default:
        return _tr('Khác', 'Other');
    }
  }

  IconData _relationshipIcon(String relationship) {
    switch (relationship.trim().toLowerCase()) {
      case 'family':
        return Icons.family_restroom_rounded;

      case 'friend':
        return Icons.people_alt_rounded;

      default:
        return Icons.person_rounded;
    }
  }

  Future<void> _showContactDialog({
    String? contactId,
    Map<String, dynamic>? existingData,
  }) async {
    final nameController = TextEditingController(
      text: (existingData?['name'] ?? '').toString(),
    );

    final phoneController = TextEditingController(
      text: (existingData?['phone'] ?? '').toString(),
    );

    String relationship =
        (existingData?['relationship'] ?? 'family').toString();

    if (!['family', 'friend', 'other'].contains(relationship)) {
      relationship = 'other';
    }

    final isEditing = contactId != null;

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE4EF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing
                          ? _tr(
                              'Sửa liên hệ an toàn',
                              'Edit Trusted Contact',
                            )
                          : _tr(
                              'Thêm liên hệ an toàn',
                              'Add Trusted Contact',
                            ),
                      style: const TextStyle(
                        color: Color(0xFF8A2F6A),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: _tr('Tên', 'Name'),
                        hintText: _tr(
                          'Ví dụ: Mẹ, Anh trai, Bạn thân',
                          'Example: Mom, Brother, Best Friend',
                        ),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFFE91E63),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFFF7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFFFD5E6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE91E63),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: _tr(
                          'Số điện thoại',
                          'Phone Number',
                        ),
                        hintText: _tr(
                          'Ví dụ: +61 412 345 678',
                          'Example: +61 412 345 678',
                        ),
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: Color(0xFFE91E63),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFFF7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFFFD5E6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE91E63),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _tr(
                        'Mối quan hệ',
                        'Relationship',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: relationship,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFFFF7FB),
                        prefixIcon: Icon(
                          _relationshipIcon(relationship),
                          color: const Color(0xFFE91E63),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFFFD5E6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE91E63),
                            width: 1.4,
                          ),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'family',
                          child: Text(
                            _tr('Gia đình', 'Family'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'friend',
                          child: Text(
                            _tr('Bạn bè', 'Friend'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text(
                            _tr('Khác', 'Other'),
                          ),
                        ),
                      ],
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value == null) return;

                              setDialogState(() {
                                relationship = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: Text(
                    _tr('Hủy', 'Cancel'),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final phone = phoneController.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _tr(
                                    'Vui lòng nhập tên.',
                                    'Please enter a name.',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }

                          if (phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _tr(
                                    'Vui lòng nhập số điện thoại.',
                                    'Please enter a phone number.',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }

                          final contactsReference =
                              _contactsReference;

                          if (contactsReference == null) {
                            return;
                          }

                          setDialogState(() {
                            _isSaving = true;
                          });

                          try {
                            if (isEditing) {
                              await contactsReference
                                  .doc(contactId)
                                  .set({
                                'name': name,
                                'phone': phone,
                                'relationship': relationship,
                                'updatedAt':
                                    FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                            } else {
                              await contactsReference.add({
                                'name': name,
                                'phone': phone,
                                'relationship': relationship,
                                'createdAt':
                                    FieldValue.serverTimestamp(),
                                'updatedAt':
                                    FieldValue.serverTimestamp(),
                              });
                            }

                            if (!mounted) return;

                            Navigator.pop(dialogContext);

                            ScaffoldMessenger.of(this.context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEditing
                                      ? _tr(
                                          'Đã cập nhật liên hệ.',
                                          'Contact updated.',
                                        )
                                      : _tr(
                                          'Đã thêm liên hệ an toàn.',
                                          'Trusted contact added.',
                                        ),
                                ),
                              ),
                            );
                          } catch (e) {
                            debugPrint(
                              'SAVE TRUSTED CONTACT ERROR: $e',
                            );

                            if (!mounted) return;

                            ScaffoldMessenger.of(this.context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                  _tr(
                                    'Không thể lưu liên hệ. Vui lòng thử lại.',
                                    'Could not save the contact. Please try again.',
                                  ),
                                ),
                              ),
                            );
                          } finally {
                            _isSaving = false;
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing
                              ? _tr('Lưu', 'Save')
                              : _tr('Thêm', 'Add'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> _confirmDeleteContact({
    required String contactId,
    required String contactName,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            _tr(
              'Xóa liên hệ an toàn?',
              'Delete Trusted Contact?',
            ),
            style: const TextStyle(
              color: Color(0xFF8A2F6A),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            _tr(
              'Bạn có chắc muốn xóa $contactName khỏi danh sách liên hệ an toàn không?',
              'Are you sure you want to remove $contactName from your trusted contacts?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                _tr('Không', 'No'),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                _tr('Xóa', 'Delete'),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final contactsReference = _contactsReference;

    if (contactsReference == null) return;

    try {
      await contactsReference.doc(contactId).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Đã xóa liên hệ.',
              'Contact deleted.',
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('DELETE TRUSTED CONTACT ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Không thể xóa liên hệ.',
              'Could not delete the contact.',
            ),
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 34,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 94,
              height: 94,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE4EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_rounded,
                size: 48,
                color: Color(0xFFE91E63),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              _tr(
                'Chưa có liên hệ an toàn',
                'No Trusted Contacts Yet',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8A2F6A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _tr(
                'Thêm người thân hoặc bạn bè mà bạn tin tưởng để chia sẻ kế hoạch hẹn hò.',
                'Add a trusted friend or family member to share your date plans with.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required String contactId,
    required Map<String, dynamic> data,
  }) {
    final name = (data['name'] ?? '').toString().trim();
    final phone = (data['phone'] ?? '').toString().trim();
    final relationship =
        (data['relationship'] ?? 'other').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(
        14,
        12,
        8,
        12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD5E6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE4EF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _relationshipIcon(relationship),
              color: const Color(0xFFE91E63),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty
                      ? _tr(
                          'Không có tên',
                          'No Name',
                        )
                      : name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F5),
                    borderRadius:
                        BorderRadius.circular(999),
                  ),
                  child: Text(
                    _relationshipLabel(relationship),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.black45,
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _showContactDialog(
                  contactId: contactId,
                  existingData: data,
                );
              }

              if (value == 'delete') {
                _confirmDeleteContact(
                  contactId: contactId,
                  contactName: name,
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFFE91E63),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _tr('Sửa', 'Edit'),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _tr('Xóa', 'Delete'),
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final contactsReference = _contactsReference;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FB),
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFF8A2F6A),
        ),
        title: Text(
          _tr(
            'Liên hệ an toàn',
            'Trusted Contacts',
          ),
          style: const TextStyle(
            color: Color(0xFF8A2F6A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                _showContactDialog();
              },
              backgroundColor:
                  const Color(0xFFE91E63),
              foregroundColor: Colors.white,
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
              ),
              label: Text(
                _tr(
                  'Thêm liên hệ',
                  'Add Contact',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
      body: user == null || contactsReference == null
          ? Center(
              child: Text(
                _tr(
                  'Vui lòng đăng nhập lại.',
                  'Please sign in again.',
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    8,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4EF),
                    borderRadius:
                        BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFC7DE),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.security_rounded,
                        color: Color(0xFFE91E63),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _tr(
                            'Những người này có thể nhận kế hoạch hẹn hò và thông báo an toàn của bạn.',
                            'These people can receive your date plans and safety check-ins.',
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: contactsReference
                        .orderBy(
                          'createdAt',
                          descending: false,
                        )
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child:
                              CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(24),
                            child: Text(
                              _tr(
                                'Không thể tải danh sách liên hệ.',
                                'Could not load trusted contacts.',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final contacts =
                          snapshot.data?.docs ?? [];

                      if (contacts.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(
                          16,
                          10,
                          16,
                          100,
                        ),
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact =
                              contacts[index];

                          return _buildContactCard(
                            contactId: contact.id,
                            data: contact.data(),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
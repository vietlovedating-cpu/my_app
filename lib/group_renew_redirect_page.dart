import 'package:flutter/material.dart';
import 'group_data.dart';
import 'group_detail_page.dart';

class GroupRenewRedirectPage extends StatelessWidget {
  final String groupId;
  final String languageCode;

  const GroupRenewRedirectPage({
    super.key,
    required this.groupId,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  @override
  Widget build(BuildContext context) {
    final match = kDatingGroups.where((g) => g.id == groupId).toList();

    if (match.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_tr('Gia hạn nhóm', 'Renew group')),
        ),
        body: Center(
          child: Text(
            _tr(
              'Không tìm thấy nhóm để gia hạn.',
              'Could not find the group to renew.',
            ),
          ),
        ),
      );
    }

    final group = match.first;

    return GroupDetailPage(
      languageCode: languageCode,
      group: group,
    );
  }
}
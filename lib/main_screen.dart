import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

import 'home_page.dart';
import 'match_page.dart';
import 'group_detail_page.dart';
import 'group_data.dart';

class MainScreen extends StatefulWidget {
  final String languageCode;

  const MainScreen({
    super.key,
    required this.languageCode,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final AppLinks _appLinks;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _initDeepLink();
  }

  void _initDeepLink() {
    _appLinks = AppLinks();

    _sub = _appLinks.uriLinkStream.listen((uri) {
      if (uri == null) return;

      // 👉 ví dụ: vietlove://group-renew?groupId=gym_fitness
      if (uri.host == 'group-renew') {
        final groupId = uri.queryParameters['groupId'];

        if (groupId != null) {
          _openGroupDetail(groupId);
        }
      }
    });
  }

  void _openGroupDetail(String groupId) {
    final group = kDatingGroups.firstWhere(
  (g) => g.id == groupId,
  orElse: () => kDatingGroups.first,
);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailPage(
          languageCode: widget.languageCode,
          group: group,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(languageCode: widget.languageCode),
      MatchPage(languageCode: widget.languageCode),
    ];

    return Scaffold(
      body: pages[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Match',
          ),
        ],
      ),
    );
  }
}
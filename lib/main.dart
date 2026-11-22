import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import 'firebase_options.dart';
import 'splash_page.dart';
import 'home_page.dart';
import 'push_notification_service.dart';
import 'group_renew_redirect_page.dart';

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'view_other_profile_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  runApp(const MyApp());

  // Chạy sau khi app đã mở
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('MAIN PERMISSION: ${settings.authorizationStatus}');

      final apnsToken =
          await FirebaseMessaging.instance.getAPNSToken();

      print('MAIN APNS TOKEN: $apnsToken');

      final fcmToken =
          await FirebaseMessaging.instance.getToken();

      print('MAIN FCM TOKEN: $fcmToken');
    } catch (e) {
      debugPrint('MAIN FCM INIT ERROR: $e');
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>();
  }
}

class _MyAppState extends State<MyApp> {
  int _compareVersions(String current, String latest) {
  final currentParts = current.split('.').map(
    (e) => int.tryParse(e) ?? 0,
  ).toList();

  final latestParts = latest.split('.').map(
    (e) => int.tryParse(e) ?? 0,
  ).toList();

  final length = currentParts.length > latestParts.length
      ? currentParts.length
      : latestParts.length;

  for (int i = 0; i < length; i++) {
    final a = i < currentParts.length ? currentParts[i] : 0;
    final b = i < latestParts.length ? latestParts[i] : 0;

    if (a < b) return -1;
    if (a > b) return 1;
  }

  return 0;
}
Future<void> _checkForOptionalUpdate() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('version')
        .get();

    if (!doc.exists || !mounted) return;

    final data = doc.data();
    if (data == null) return;

    final latestVersion = Platform.isAndroid
        ? data['androidLatestVersion']?.toString() ?? ''
        : data['iosLatestVersion']?.toString() ?? '';

    if (latestVersion.isEmpty) return;

    if (_compareVersions(currentVersion, latestVersion) >= 0) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();

final dismissKey = 'updatePopupDismissedAt_$latestVersion';

final lastDismissed = prefs.getInt(dismissKey);

if (lastDismissed != null) {
  final lastDate = DateTime.fromMillisecondsSinceEpoch(lastDismissed);

  if (DateTime.now().difference(lastDate) <
      const Duration(days: 5)) {
    return;
  }
}

    final title = data['updateTitle']?.toString() ??
        'New Version Available';

    final message = data['updateMessage']?.toString() ??
        'A new version of VietLoveDating is available.';

    final storeUrl = Platform.isAndroid
        ? data['androidUrl']?.toString() ?? ''
        : data['iosUrl']?.toString() ?? '';

    if (!mounted || navigatorKey.currentContext == null) return;

   
await showDialog<void>(
  context: navigatorKey.currentContext!,
  barrierDismissible: true,
  builder: (dialogContext) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE84D91)
                  .withOpacity(0.18),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                24, 28, 24, 24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFE5F0),
                    Color(0xFFFFF5F9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCE0ED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFE84D91),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB92F70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Color(0xFF795267),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'NEW VERSION AVAILABLE',
                      style: TextStyle(
                        color: Color(0xFFC23A7A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                22, 20, 22, 22,
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE84D91),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        final uri = Uri.tryParse(storeUrl);

                        if (uri == null ||
                            uri.scheme != 'https') {
                          return;
                        }

                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: const Text(
                        'UPDATE NOW',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF795267),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        final prefs =
                            await SharedPreferences.getInstance();

                       await prefs.setInt(
  'updatePopupDismissedAt_$latestVersion',
  DateTime.now().millisecondsSinceEpoch,
);

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                      child: const Text(
                        'Maybe Later',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your next connection could be just around the corner ❤️',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
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

  } catch (e) {
    debugPrint('Optional update check error: $e');
  }
}
  String _languageCode = 'vi';
  bool _isReady = true;
  late final PushNotificationService _pushService;
  String? _lastPushUserId;
  late final AppLinks _appLinks;
StreamSubscription? _appLinkSubscription;
StreamSubscription? _deepLinkAuthSubscription;

String? _pendingProfileUserId;
bool _isOpeningDeepLinkProfile = false;

  @override
void initState() {
  super.initState();

  _pushService = PushNotificationService(
    navigatorKey: navigatorKey,
    getLanguageCode: () => _languageCode,
  );

  _appLinks = AppLinks();
  _initDeepLink();

  _deepLinkAuthSubscription =
      FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      _openPendingProfile();
    }
  });

  _loadSavedLanguage();
  WidgetsBinding.instance.addPostFrameCallback((_) {
  _checkForOptionalUpdate();
});
} // thêm dấu đóng initState ở đây

 void _initDeepLink() {
  _appLinkSubscription = _appLinks.uriLinkStream.listen(
    (uri) {
      String userId = '';

      // Link riêng của app:
      // vietlove://profile/UID
      if (uri.scheme == 'vietlove' &&
          uri.host == 'profile' &&
          uri.pathSegments.isNotEmpty) {
        userId = uri.pathSegments.first.trim();
      }

      // Hỗ trợ thêm link website:
      // https://vietlovedating.com/profile/UID
      if ((uri.host == 'vietlovedating.com' ||
              uri.host == 'www.vietlovedating.com') &&
          uri.pathSegments.length >= 2 &&
          uri.pathSegments.first.toLowerCase() == 'profile') {
        userId = uri.pathSegments[1].trim();
      }

      if (userId.isEmpty) return;

      _pendingProfileUserId = userId;
      _openPendingProfile();
    },
    onError: (error) {
      debugPrint('App link error: $error');
    },
  );
}

void _openPendingProfile() {
  final userId = _pendingProfileUserId;

  if (userId == null || userId.isEmpty) return;
  if (_isOpeningDeepLinkProfile) return;

  // Chưa đăng nhập thì giữ UID lại.
  // Sau khi đăng nhập, authStateChanges sẽ gọi lại hàm này.
  if (FirebaseAuth.instance.currentUser == null) return;

  _isOpeningDeepLinkProfile = true;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!mounted) {
      _isOpeningDeepLinkProfile = false;
      return;
    }

    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      _isOpeningDeepLinkProfile = false;

      Future<void>.delayed(
        const Duration(milliseconds: 300),
        _openPendingProfile,
      );
      return;
    }

    _pendingProfileUserId = null;

    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ViewOtherProfilePage(
          userId: userId,
          languageCode: _languageCode,
        ),
      ),
    );

    _isOpeningDeepLinkProfile = false;
  });
}

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('languageCode') ?? 'vi';

      if (!mounted) return;

      setState(() {
        _languageCode = savedLanguage;
        _isReady = true;
      });
    } catch (e) {
      debugPrint('Load language error: $e');

      if (!mounted) return;

      setState(() {
        _languageCode = 'vi';
        _isReady = true;
      });
    }
  }

  Future<void> changeLanguage(String lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('languageCode', lang);
    } catch (e) {
      debugPrint('Save language error: $e');
    }

    if (!mounted) return;

    setState(() {
      _languageCode = lang;
    });
  }

  void _safeInitPush(String userId) {
  if (_lastPushUserId == userId) return;

  _lastPushUserId = userId;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await _pushService.init();
    } catch (e) {
      debugPrint('Push init error: $e');
    }
  });
}
@override
void dispose() {
  _appLinkSubscription?.cancel();
  _deepLinkAuthSubscription?.cancel();
  super.dispose();
}
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('APP START currentUser: ${user?.uid}');

    if (user != null) {
  _safeInitPush(user.uid);
} else {
  _lastPushUserId = null;
}

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: user != null
          ? HomePage(
              key: ValueKey('home_${user.uid}_$_languageCode'),
              languageCode: _languageCode,
            )
          : SplashPage(
              languageCode: _languageCode,
              onLanguageChanged: (lang) {
                changeLanguage(lang);
              },
            ),
      onGenerateRoute: (settings) {
        if (settings.name == '/group-renew') {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          final groupId = (args['groupId'] ?? '').toString();
          final languageCode =
              (args['languageCode'] ?? _languageCode).toString();

          return MaterialPageRoute(
            builder: (_) => GroupRenewRedirectPage(
              groupId: groupId,
              languageCode: languageCode,
            ),
          );
        }

        return null;
      },
    );
  }
}
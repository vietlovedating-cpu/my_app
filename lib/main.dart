import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'splash_page.dart';
import 'home_page.dart';
import 'push_notification_service.dart';
import 'group_renew_redirect_page.dart';


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
  String _languageCode = 'vi';
  bool _isReady = true;
  late final PushNotificationService _pushService;
  String? _lastPushUserId;

  @override
  void initState() {
    super.initState();

    _pushService = PushNotificationService(
      navigatorKey: navigatorKey,
      getLanguageCode: () => _languageCode,
    );

    _loadSavedLanguage();
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
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
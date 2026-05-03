import 'dart:async';

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
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e, s) {
    debugPrint('🔥 Background Firebase init error: $e');
    debugPrint('$s');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    debugPrint('🔥 FLUTTER ERROR: ${details.exception}');
    debugPrint('🔥 FLUTTER STACK: ${details.stack}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(
                'Flutter error:\n\n${details.exception}\n\n${details.stack}',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e, s) {
      debugPrint('🔥 Firebase init error: $e');
      debugPrint('$s');
    }

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e, s) {
      debugPrint('🔥 Background message setup error: $e');
      debugPrint('$s');
    }

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('🔥 ZONE ERROR: $error');
    debugPrint('🔥 ZONE STACK: $stack');
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
  bool _isReady = false;
  late final PushNotificationService _pushService;
  bool _pushInitialized = false;

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
    } catch (e, s) {
      debugPrint('🔥 Load language error: $e');
      debugPrint('$s');

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
    } catch (e, s) {
      debugPrint('🔥 Save language error: $e');
      debugPrint('$s');
    }

    if (!mounted) return;

    setState(() {
      _languageCode = lang;
    });
  }

  void _safeInitPush() {
    if (_pushInitialized) return;

    _pushInitialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _pushService.init();
      } catch (e, s) {
        debugPrint('🔥 Push init error: $e');
        debugPrint('$s');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Text(
                  'Auth error:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final user = snapshot.data;

          if (user != null) {
            _safeInitPush();

            return HomePage(
              key: ValueKey('home_${user.uid}_$_languageCode'),
              languageCode: _languageCode,
            );
          }

          return SplashPage(
            languageCode: _languageCode,
            onLanguageChanged: (lang) {
              MyApp.of(context)?.changeLanguage(lang);
            },
          );
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
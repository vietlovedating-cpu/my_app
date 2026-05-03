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
  } catch (e) {
    debugPrint('Background Firebase init error: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
  };

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Main init error: $e');
  }

  runApp(const MyApp());
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
  String? _startupError;

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
    } catch (e) {
      debugPrint('Load language error: $e');

      if (!mounted) return;

      setState(() {
        _languageCode = 'vi';
        _startupError = 'Load language error: $e';
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

  void _safeInitPush() {
    if (_pushInitialized) return;

    _pushInitialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _pushService.init();
      } catch (e) {
        debugPrint('Push init error: $e');
      }
    });
  }

  Widget _errorScreen(String message) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingScreen() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _loadingScreen(),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: Builder(
        builder: (context) {
          if (_startupError != null) {
            return _errorScreen(_startupError!);
          }

          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _loadingScreen();
              }

              if (snapshot.hasError) {
                return _errorScreen('Auth error: ${snapshot.error}');
              }

              final user = snapshot.data;

              if (user != null) {
                _safeInitPush();

                try {
                  return HomePage(
                    key: ValueKey('home_${user.uid}_$_languageCode'),
                    languageCode: _languageCode,
                  );
                } catch (e) {
                  return _errorScreen('HomePage error: $e');
                }
              }

              return SplashPage(
                languageCode: _languageCode,
                onLanguageChanged: (lang) {
                  MyApp.of(context)?.changeLanguage(lang);
                },
              );
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
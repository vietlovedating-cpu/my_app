import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'current_location_page.dart';
import 'highest_education_page.dart';
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
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Background message setup error: $e');
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

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
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
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(
                child: Text('Auth error'),
              ),
            );
          }

          final user = snapshot.data;

          if (user != null) {
            _safeInitPush();

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, userDocSnapshot) {
                if (userDocSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (userDocSnapshot.hasError) {
                  debugPrint('Firestore user doc error: ${userDocSnapshot.error}');

                  return const Scaffold(
                    body: Center(
                      child: Text('Firestore error'),
                    ),
                  );
                }

                final doc = userDocSnapshot.data;

                if (doc == null || !doc.exists) {
                  return const Scaffold(
                    body: Center(
                      child: Text('No user data'),
                    ),
                  );
                }

                final data = doc.data() ?? {};
                final step = (data['onboardingStep'] ?? '').toString();
                final profileCompleted = data['profileCompleted'] == true;

                if (profileCompleted) {
                  return HomePage(
                    key: ValueKey('home_${user.uid}_$_languageCode'),
                    languageCode: _languageCode,
                  );
                }

                if (step == 'current_location') {
                  return CurrentLocationPage(
                    languageCode: _languageCode,
                    selectedState: (data['selectedState'] ?? '').toString(),
                    firstName: (data['firstName'] ?? '').toString(),
                  );
                }

                if (step == 'highest_education') {
                  return HighestEducationPage(
                    languageCode: _languageCode,
                    selectedState: (data['selectedState'] ?? '').toString(),
                    firstName: (data['firstName'] ?? '').toString(),
                    address: (data['address'] ?? '').toString(),
                    gender: (data['gender'] ?? '').toString(),
                    datingPreference:
                        (data['datingPreference'] ?? '').toString(),
                    age: (data['age'] ?? 18),
                    minAgePreference: (data['minAgePreference'] ?? 18),
                    maxAgePreference: (data['maxAgePreference'] ?? 50),
                    maritalStatus: (data['maritalStatus'] ?? '').toString(),
                    relationshipGoals:
                        List<String>.from(data['relationshipGoals'] ?? []),
                    photoUrls: List<String>.from(data['photoUrls'] ?? []),
                  );
                }

                return HomePage(
                  key: ValueKey('home_${user.uid}_$_languageCode'),
                  languageCode: _languageCode,
                );
              },
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
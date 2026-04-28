import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'splash_page.dart';
import 'home_page.dart';
import 'current_location_page.dart';
import 'highest_education_page.dart';
import 'group_renew_redirect_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _languageCode = 'vi';
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('languageCode') ?? 'vi';

    if (!mounted) return;

    setState(() {
      _languageCode = savedLanguage;
      _isReady = true;
    });
  }

  Future<void> changeLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', lang);

    if (!mounted) return;

    setState(() {
      _languageCode = lang;
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

          final user = snapshot.data;

          if (user == null) {
            return SplashPage(
              languageCode: _languageCode,
              onLanguageChanged: (lang) {
                MyApp.of(context)?.changeLanguage(lang);
              },
            );
          }

          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future:
                FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final data = userDocSnapshot.data?.data() ?? {};
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
                  datingPreference: (data['datingPreference'] ?? '').toString(),
                  age: data['age'] ?? 18,
                  minAgePreference: data['minAgePreference'] ?? 18,
                  maxAgePreference: data['maxAgePreference'] ?? 50,
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
import 'dart:io';
import 'message_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'group_chat_page.dart';
import 'group_data.dart';

class PushNotificationService {
  final GlobalKey<NavigatorState> navigatorKey;
  final String Function() getLanguageCode;

  PushNotificationService({
    required this.navigatorKey,
    required this.getLanguageCode,
  });

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'vietlove_default',
    'VietLove Notifications',
    description: 'General notifications',
    importance: Importance.max,
  );

  bool _isInitialized = false;
  bool _listenersAttached = false;

  Future<void> init() async {
  print('PUSH INIT START');

  if (_isInitialized) return;

  await _initLocalNotifications();

  await Future.delayed(const Duration(seconds: 2));

  try {
    await _requestPermission();
  } catch (e) {
    print('PERMISSION ERROR: $e');
  }

  try {
    await _setupForegroundPresentation();
  } catch (e) {
    print('FOREGROUND ERROR: $e');
  }

  try {
    await _saveToken();
  } catch (e) {
    print('TOKEN ERROR: $e');
  }

  if (!_listenersAttached) {
    _listenTokenRefresh();
    _listenForegroundMessages();
    _listenOpenAppFromNotification();
    _listenersAttached = true;
  }

  try {
    await _checkInitialMessage();
  } catch (e) {
    print('INITIAL MESSAGE ERROR: $e');
  }

  _isInitialized = true;
}

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings();

const initSettings = InitializationSettings(
  android: androidInit,
  iOS: iosInit,
);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload ?? '';
        final parts = payload.split('|');
        final route = parts.isNotEmpty ? parts[0] : '';
        final groupId = parts.length > 1 ? parts[1] : '';

        _handleNavigationFromPayload(
          route: route,
          groupId: groupId,
        );
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('NOTIFICATION PERMISSION = ${settings.authorizationStatus}');
  }

  Future<void> _setupForegroundPresentation() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> _saveToken() async {
  final user = FirebaseAuth.instance.currentUser;
  print('CURRENT USER = ${user?.uid}');

  if (user == null) return;

  final userRef =
      FirebaseFirestore.instance.collection('users').doc(user.uid);

  try {
    await userRef.set({
      'pushDebugLastRunAt': FieldValue.serverTimestamp(),
      'pushDebugPlatform': Platform.isIOS ? 'ios' : 'android',
      'pushDebugStep': 'started',
    }, SetOptions(merge: true));

    if (Platform.isIOS) {
  String? apnsToken;

  for (int i = 0; i < 10; i++) {
    await Future.delayed(const Duration(seconds: 2));

    apnsToken = await _messaging.getAPNSToken();

    print('APNS RETRY $i = $apnsToken');

    if (apnsToken != null && apnsToken.isNotEmpty) {
      break;
    }
  }

  await userRef.set({
    'pushDebugApnsTokenNull': apnsToken == null || apnsToken.isEmpty,
    'pushDebugStep':
        apnsToken == null || apnsToken.isEmpty ? 'apns_null' : 'apns_ok',
    'pushDebugUpdatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  if (apnsToken == null || apnsToken.isEmpty) {
    print('APNS TOKEN STILL NULL - SKIP FCM TOKEN');
    return;
  }
}

    final token = await _messaging.getToken();
    print('FCM TOKEN = $token');

    await userRef.set({
      'pushDebugFcmTokenNull': token == null || token.isEmpty,
      'pushDebugStep':
          token == null || token.isEmpty ? 'fcm_null' : 'fcm_ok',
      'pushDebugUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (token == null || token.isEmpty) {
      print('FCM TOKEN NULL - NOT SAVED');
      return;
    }

    await userRef.set({
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
      'fcmPlatform': Platform.isIOS ? 'ios' : 'android',
      'pushDebugStep': 'saved',
      'pushDebugError': FieldValue.delete(),
    }, SetOptions(merge: true));

    print('TOKEN SAVED TO FIRESTORE');
  } catch (e) {
    print('SAVE TOKEN ERROR: $e');

    await userRef.set({
      'pushDebugStep': 'error',
      'pushDebugError': e.toString(),
      'pushDebugUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

  void _listenTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      final user = FirebaseAuth.instance.currentUser;
      print('TOKEN REFRESH USER = ${user?.uid}');
      print('TOKEN REFRESH VALUE = $token');

      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('REFRESHED TOKEN SAVED');
    });
  }

  void _listenForegroundMessages() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('FOREGROUND PUSH RECEIVED');
    print('DATA = ${message.data}');

    final route = message.data['route']?.toString() ?? '';
    final groupId = message.data['groupId']?.toString() ?? '';
    final title =
        message.data['title']?.toString() ??
        message.notification?.title ??
        'VietLove Dating';
    final body =
        message.data['body']?.toString() ??
        message.notification?.body ??
        'You have a new notification';

    final payload = '$route|$groupId';

    const androidDetails = AndroidNotificationDetails(
      'vietlove_default',
      'VietLove Notifications',
      channelDescription: 'General notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  });
}

  void _listenOpenAppFromNotification() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final route = message.data['route']?.toString();
      final groupId =
    message.data['chatId']?.toString() ??
    message.data['groupId']?.toString();

      _handleNavigationFromPayload(
        route: route,
        groupId: groupId,
      );
    });
  }

  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage == null) return;

    final route = initialMessage.data['route']?.toString();
    final groupId =
    initialMessage.data['chatId']?.toString() ??
    initialMessage.data['groupId']?.toString();

    _handleNavigationFromPayload(
      route: route,
      groupId: groupId,
    );
  }

  void _handleNavigationFromPayload({
    String? route,
    String? groupId,
  }) {
    print('OPEN FROM PUSH route=$route groupId=$groupId');
if (route == 'chat') {
  final chatId = groupId;

  final nav = navigatorKey.currentState;
  if (nav == null || chatId == null || chatId.isEmpty) return;

  nav.push(
    MaterialPageRoute(
      builder: (_) => MessagePage(
        languageCode: getLanguageCode(),
        chatId: chatId,
        otherUserId: '', // tạm thời để trống
        otherUserName: '',
        otherUserPhotoUrl: '',
      ),
    ),
  );

  return;
}
if (route == 'group_chat') {
  print('PUSH GROUP ROUTE = $route');
print('PUSH GROUP ID = $groupId');
  final nav = navigatorKey.currentState;
  if (nav == null || groupId == null || groupId.isEmpty) return;

  final matchingGroups =
    kDatingGroups.where((g) => g.id == groupId).toList();

  if (matchingGroups.isEmpty) {
    print('GROUP NOT FOUND FROM PUSH: $groupId');
    return;
  }

  final group = matchingGroups.first;

  nav.push(
    MaterialPageRoute(
      builder: (_) => GroupChatPage(
        languageCode: getLanguageCode(),
        group: group,
        currentUserGroupId: group.id,
        currentUserHasJoined: true,
        currentUserIsActive: true,
      ),
    ),
  );

  return;
}
    if (route != 'group_renew' || groupId == null || groupId.isEmpty) return;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.pushNamed(
      '/group-renew',
      arguments: {
        'groupId': groupId,
        'languageCode': getLanguageCode(),
      },
    );
  }
}
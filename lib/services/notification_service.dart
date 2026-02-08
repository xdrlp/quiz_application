import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

class NotificationService {
  static GlobalKey<NavigatorState>? navigatorKey;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(

      settings,

      onDidReceiveNotificationResponse: (NotificationResponse response) async {

        if (response.payload != null) {

          final data = jsonDecode(response.payload!) as Map<String, dynamic>;

          _handleNotificationData(data);

        }

      },

    );

    // Create Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );
    await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

    // 1. Request Permission
    NotificationSettings settingsFCM = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settingsFCM.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else {
      debugPrint('User declined or has not accepted permission');
      return; 
    }

    // 2. Get Token
    String? token = await _messaging.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      await _saveTokenToFirestoreInternal(token);
    }

    // 3. Listen for token refreshes
    _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestoreInternal(newToken);
    });

    // 4. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        // Show local notification
        await _showLocalNotification(message);
      }
    });

    // 5. Handle notification clicks when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);

    // 6. Handle initial message if app was opened from terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage);
    }
  }

  Future<void> saveTokenToFirestore() async {
    String? token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToFirestoreInternal(token);
    }
  }

  Future<void> _saveTokenToFirestoreInternal(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('FCM Token updated for user ${user.uid}');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel', // channel id
      'High Importance Notifications', // channel name
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      message.hashCode, // unique id
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  }

  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      0,
      'Test Notification',
      'This is a test notification to verify settings.',
      details,
    );
  }

  void _handleNotificationClick(RemoteMessage message) {
    _handleNotificationData(message.data);
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final screen = data['screen'];
    final quizId = data['quizId'];
    final attemptId = data['attemptId'];

    // Navigate to the appropriate screen
    if (screen == 'attempt_detail' && attemptId != null) {
      NotificationService.navigatorKey?.currentState?.pushNamed('/attempt_detail', arguments: attemptId);
    } else if (screen == 'quiz_results' && quizId != null) {
      // TODO: Navigate to quiz results screen
      debugPrint('Navigate to quiz results for quizId: $quizId');
    }
  }
}

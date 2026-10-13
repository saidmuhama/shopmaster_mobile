import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

const _channelId = 'mdspro_sales';
const _channelName = 'Sales Alerts';
const _channelDesc = 'Notifications for new sales';
const _prefFcmToken = 'fcm_token';

// Top-level plugin instance shared between main isolate and background isolate
final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();

// Background message handler — runs in a separate isolate, must reinitialize everything
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  await _notif.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  await _showNotification(
    message.notification?.title ?? 'New Sale',
    message.notification?.body ?? '',
  );
}

Future<void> _showNotification(String title, String body, {int badgeCount = 1}) async {
  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF0F2D1A),
      playSound: true,
      enableVibration: true,
      number: badgeCount,
      styleInformation: const BigTextStyleInformation(''),
    ),
  );
  await _notif.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
    title, body, details,
  );
}

class NotificationService {
  static Timer? _pollTimer;

  static Future<void> init() async {
    // Initialize local notifications (Android + iOS)
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _notif.initialize(initSettings);

    // Explicitly create the notification channel (required Android 8+)
    await _notif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId, _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ));

    // Request notification permission
    await _notif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Register FCM background handler
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // Foreground FCM messages → show as local notification
    FirebaseMessaging.onMessage.listen((msg) {
      _showNotification(
        msg.notification?.title ?? 'New Sale',
        msg.notification?.body ?? '',
      );
    });

    // Request FCM permission only — do NOT upload token here (no session yet)
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}

    // Re-upload if token rotates (will only fire when logged in)
    FirebaseMessaging.instance.onTokenRefresh.listen(_uploadAndSave);
  }

  // Call this after login — when the session cookie is active
  static Future<void> uploadToken() => _uploadToken();

  static Future<void> _uploadToken() async {
    try {
      // On iOS physical device, APNS must be ready before getToken() works.
      // On simulator, APNS is never available — skip silently.
      if (Platform.isIOS) {
        final apns = await FirebaseMessaging.instance.getAPNSToken()
            .timeout(const Duration(seconds: 4), onTimeout: () => null);
        if (apns == null) {
          debugPrint('[FCM] APNS not available (simulator or permission denied) — skipping');
          return;
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _uploadAndSave(token);
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
    }
  }

  static Future<void> _uploadAndSave(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefFcmToken, token);
      await ApiService.registerFcmToken(token);
      debugPrint('[FCM] token registered: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[FCM] upload error: $e');
    }
  }

  // Foreground polling every 2 min as backup
  static void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 2), (_) => _checkNewSales());
  }

  static void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  static Future<void> _checkNewSales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getInt('last_sale_id') ?? 0;
      final sales = await ApiService.getRecentSales();
      if (sales.isEmpty) return;
      final latestId = sales.first.id;
      if (latestId <= lastId) return;
      final newSales = lastId == 0 ? <dynamic>[] : sales.where((s) => s.id > lastId).toList();
      await prefs.setInt('last_sale_id', latestId);
      if (lastId == 0 || newSales.isEmpty) return;
      final count = newSales.length;
      final first = newSales.first;
      await _showNotification(
        count == 1 ? 'New Sale!' : '$count New Sales!',
        count == 1 ? '${first.invoiceNo} · ${first.custName}' : '$count sales recorded',
      );
    } catch (_) {}
  }
}

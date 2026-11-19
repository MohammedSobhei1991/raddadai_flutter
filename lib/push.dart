import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core.dart';

/// إشعارات FCM (Firebase) تصل والتطبيق مغلقاً: نسجّل رمز الجهاز في الباك إند بعد الدخول
/// ونحذفه عند الخروج. إن غاب ملف إعدادات Firebase يعمل التطبيق بدونها (تنبيهات محلية فقط).
class PushService {
  static bool _ready = false;
  static String? _token;
  static bool _loggedIn = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        if (_loggedIn) _register();
      });
    } catch (e) {
      debugPrint('Firebase غير مهيأ: $e');
    }
  }

  /// تُستدعى بعد تسجيل الدخول (الرمز يتبع آخر مستخدم دخل من الجهاز).
  static Future<void> register() async {
    _loggedIn = true;
    if (!_ready) return;
    try {
      await LocalAlerts.init(); // ينشئ قناة 'orders' ويطلب إذن Android 13+
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (Platform.isIOS) {
        await FirebaseMessaging.instance.getAPNSToken();
      }
      _token = await FirebaseMessaging.instance.getToken();
      await _register();
    } catch (e) {
      debugPrint('تعذر تسجيل رمز الإشعارات: $e');
    }
  }

  static Future<void> _register() async {
    final token = _token;
    if (token == null) return;
    try {
      await api('/push-tokens', method: 'POST', body: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'});
    } catch (_) {}
  }

  /// نرسل الرمز مع طلب الخروج ليحذفه الباك إند فلا تصل إشعارات لجهاز خرج منه التاجر.
  static String? get token => _token;

  static void markLoggedOut() => _loggedIn = false;
}

/// تنبيهات محلية ما دام التطبيق مفتوحاً (تُستدعى عند وصول إشعار جديد عبر التحديث الدوري).
class LocalAlerts {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _id = 0;

  static Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      // نفس قناة FCM الافتراضية (AndroidManifest) كي تظهر إشعارات الخلفية بأولوية عالية
      await android?.createNotificationChannel(const AndroidNotificationChannel('orders', 'Orders', importance: Importance.high));
      await android?.requestNotificationsPermission();
    }
    _ready = true;
  }

  static Future<void> show(String title, String? body) async {
    await init();
    await _plugin.show(
      id: _id++,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('orders', 'Orders', importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }
}

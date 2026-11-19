import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'auth.dart';
import 'core.dart';
import 'screens/conversation_detail.dart';
import 'screens/order_detail.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// إشعارات FCM (Firebase) تصل والتطبيق مغلقاً: نسجّل رمز الجهاز في الباك إند بعد الدخول
/// ونحذفه عند الخروج. إن غاب ملف إعدادات Firebase يعمل التطبيق بدونها (تنبيهات محلية فقط).
class PushService {
  static bool _ready = false;
  static String? _token;
  static bool _loggedIn = false;
  static ({String type, int id})? _pending;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
      // الضغط على إشعار FCM والتطبيق في الخلفية أو مغلقاً → فتح الطلب/المحادثة مباشرة
      FirebaseMessaging.onMessageOpenedApp.listen((m) => open(m.data['type'] as String?, m.data['id']));
      // FCM لا يعرض الإشعار بنفسه والتطبيق مفتوح، فنعرضه كتنبيه محلي فوراً
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        LocalAlerts.show(n.title ?? '', n.body, payload: '${m.data['type']}:${m.data['id']}');
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) open(initial.data['type'] as String?, initial.data['id']);
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

  /// يحفظ الوجهة ثم يحاول فتحها؛ إن لم يكن المستخدم داخل التطبيق بعد تُفتح عند أول [flush] من الشاشة الرئيسية.
  static void open(String? type, Object? id) {
    final n = id is int ? id : int.tryParse('$id');
    if (n == null || (type != 'order' && type != 'conversation')) return;
    _pending = (type: type!, id: n);
    flush();
  }

  /// payload التنبيه المحلي بصيغة 'order:5'.
  static void openPayload(String? payload) {
    final parts = (payload ?? '').split(':');
    if (parts.length == 2) open(parts[0], parts[1]);
  }

  static void flush() {
    final target = _pending;
    final nav = navigatorKey.currentState;
    if (target == null || nav == null || auth.user == null) return;
    _pending = null;
    nav.push(MaterialPageRoute(
      builder: (_) => target.type == 'order' ? OrderScreen(id: target.id) : ConversationScreen(id: target.id),
    ));
  }
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
    ), onDidReceiveNotificationResponse: (r) => PushService.openPayload(r.payload));
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      // نفس قناة FCM الافتراضية (AndroidManifest) كي تظهر إشعارات الخلفية بأولوية عالية
      await android?.createNotificationChannel(const AndroidNotificationChannel('orders', 'Orders', importance: Importance.high));
      await android?.requestNotificationsPermission();
    }
    _ready = true;
  }

  static final _recent = <String, DateTime>{};

  static Future<void> show(String title, String? body, {String? payload}) async {
    // نفس الإشعار قد يصل من FCM ومن التحديث الدوري: نعرضه مرة واحدة
    final key = '$title|$body';
    final now = DateTime.now();
    _recent.removeWhere((_, t) => now.difference(t).inSeconds > 90);
    if (_recent.containsKey(key)) return;
    _recent[key] = now;
    await init();
    await _plugin.show(
      id: _id++,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('orders', 'Orders', importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }
}

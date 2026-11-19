import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
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

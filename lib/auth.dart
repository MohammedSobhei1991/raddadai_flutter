import 'dart:io';

import 'package:flutter/foundation.dart';

import 'core.dart';
import 'push.dart';

class Auth extends ChangeNotifier {
  bool ready = false;
  J? user;

  J? get merchant => user?['merchant'] as J?;
  String get currency => (merchant?['currency'] as String?) ?? '';

  Future<void> init() async {
    onUnauthorized = () => clear();
    final savedLocale = await storage.read(key: 'app_locale');
    await l10n.apply(savedLocale, save: false);
    final saved = await storage.read(key: 'auth_token');
    if (saved != null) {
      setAuthToken(saved);
      try {
        await _afterLogin((await api('/me'))['user'] as J);
      } catch (_) {
        await clear();
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> clear() async {
    setAuthToken(null);
    user = null;
    await storage.delete(key: 'auth_token');
    notifyListeners();
  }

  Future<void> _afterLogin(J me) async {
    await l10n.apply(me['locale'] as String?);
    user = me;
    notifyListeners();
    PushService.register();
  }

  Future<void> _sign(String path, J body) async {
    final result = await api(path, method: 'POST', body: {...body, 'device_name': '${Platform.operatingSystem} app'});
    setAuthToken(result['token'] as String);
    await storage.write(key: 'auth_token', value: result['token'] as String);
    await _afterLogin(result['user'] as J);
  }

  Future<void> login(String email, String password) => _sign('/login', {'email': email, 'password': password});
  Future<void> register(J data) => _sign('/register', data);

  Future<void> logout() async {
    try {
      await api('/logout', method: 'POST', body: {if (PushService.token != null) 'push_token': PushService.token});
    } catch (_) {}
    PushService.markLoggedOut();
    await clear();
  }

  Future<void> refreshUser() async {
    user = (await api('/me'))['user'] as J;
    notifyListeners();
  }

  Future<void> chooseLocale(String locale) async {
    await l10n.apply(locale);
    if (user != null) {
      try {
        await api('/me/locale', method: 'PATCH', body: {'locale': locale});
      } catch (_) {}
    }
  }
}

final auth = Auth();

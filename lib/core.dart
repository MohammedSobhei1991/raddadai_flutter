import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'i18n_tr.dart';

// ---------- i18n (النص العربي هو المفتاح) ----------
/// مؤقتاً: التطبيق بالعربية فقط (يُخفي مبدّل اللغة ويتجاهل لغة الحساب/المحفوظة). غيّرها إلى false لإعادة التركية.
const arabicOnly = true;

class L10n extends ChangeNotifier {
  String locale = 'ar';
  bool get rtl => locale == 'ar';

  String t(String text, [Map<String, Object>? params]) {
    var out = locale == 'tr' ? (trStrings[text] ?? text) : text;
    params?.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
    return out;
  }

  Future<void> apply(String? value, {bool save = true}) async {
    if (value != 'ar' && value != 'tr') return;
    if (arabicOnly && value != 'ar') return;
    if (value == locale) return;
    locale = value!;
    if (save) await storage.write(key: 'app_locale', value: value);
    notifyListeners();
  }
}

final l10n = L10n();
String t(String text, [Map<String, Object>? params]) => l10n.t(text, params);

const storage = FlutterSecureStorage();

// ---------- API ----------
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://raddadai.com/api/v1');

class ApiError implements Exception {
  ApiError(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}

String? _token;
void Function()? onUnauthorized;
void setAuthToken(String? v) => _token = v;
Map<String, String> authHeaders() => _token == null ? {} : {'Authorization': 'Bearer $_token'};

Future<Map<String, dynamic>> api(String path, {String method = 'GET', Object? body}) async {
  final uri = Uri.parse(apiUrl + path);
  final headers = {'Accept': 'application/json', 'Content-Type': 'application/json', ...authHeaders()};
  http.Response res;
  try {
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'POST':
        res = await http.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        res = await http.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        res = await http.delete(uri, headers: headers, body: encoded);
      default:
        res = await http.get(uri, headers: headers);
    }
  } catch (_) {
    throw ApiError(t('تعذر الاتصال بالخادم. تحقق من الإنترنت ومن عنوان الخادم.'), 0);
  }
  if (res.statusCode == 401 && _token != null) onUnauthorized?.call();
  if (res.statusCode == 204) return {};
  dynamic json;
  try {
    json = jsonDecode(utf8.decode(res.bodyBytes));
  } catch (_) {}
  if (res.statusCode >= 400) {
    String? first;
    if (json is Map && json['errors'] is Map && (json['errors'] as Map).isNotEmpty) {
      final v = (json['errors'] as Map).values.first;
      if (v is List && v.isNotEmpty) first = '${v.first}';
    }
    throw ApiError(first ?? (json is Map ? json['message'] as String? : null) ?? t('حدث خطأ غير متوقع.'), res.statusCode);
  }
  return json is Map<String, dynamic> ? json : {};
}

// ---------- ألوان وتنسيق ----------
class C {
  static const primary = Color(0xFF059669), primaryDark = Color(0xFF047857), bg = Color(0xFFF8FAFC);
  static const card = Colors.white, border = Color(0xFFE2E8F0), text = Color(0xFF1E293B), muted = Color(0xFF64748B);
  static const danger = Color(0xFFDC2626), chatBg = Color(0xFFEFEAE2);
}

class Tone {
  const Tone(this.label, this.bg, this.fg);
  final String label;
  final Color bg, fg;
}

Tone orderTone(String status, String fulfillment) {
  switch (status) {
    case 'pending':
      return Tone(t('بانتظار القبول'), const Color(0xFFFEF3C7), const Color(0xFF92400E));
    case 'accepted':
      return Tone(t('مقبول'), const Color(0xFFE0F2FE), const Color(0xFF075985));
    case 'rejected':
      return Tone(t('مرفوض'), const Color(0xFFFEE2E2), const Color(0xFF991B1B));
    case 'delivered':
      return Tone(fulfillment == 'pickup' ? t('تم التسليم') : t('تم التوصيل'), const Color(0xFFD1FAE5), const Color(0xFF065F46));
    default:
      return Tone(t('ألغاه العميل'), const Color(0xFFE2E8F0), const Color(0xFF334155));
  }
}

Tone paymentTone(String s) {
  switch (s) {
    case 'awaiting':
      return Tone(t('بانتظار الدفع'), const Color(0xFFFEF3C7), const Color(0xFF92400E));
    case 'proof_sent':
      return Tone(t('أرسل إثبات تحويل'), const Color(0xFFE0F2FE), const Color(0xFF075985));
    case 'paid':
      return Tone(t('مدفوع'), const Color(0xFFD1FAE5), const Color(0xFF065F46));
    case 'failed':
      return Tone(t('فشل الدفع'), const Color(0xFFFEE2E2), const Color(0xFF991B1B));
    case 'refunded':
      return Tone(t('تم إرجاع المبلغ'), const Color(0xFFEDE9FE), const Color(0xFF5B21B6));
    default:
      return Tone(t('يُدفع عند الاستلام'), const Color(0xFFF1F5F9), const Color(0xFF334155));
  }
}

String paymentMethod(String m) => switch (m) {
      'card_on_delivery' => t('💳 بطاقة عند الاستلام'),
      'jawwal_pay' => t('📱 جوال بي'),
      'lahza' => t('💳 دفع إلكتروني'),
      _ => t('💵 نقداً عند الاستلام'),
    };

Tone conversationTone(String s) => switch (s) {
      'human' => Tone(t('تحتاج موظفاً'), const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      'closed' => Tone(t('مغلقة'), const Color(0xFFF1F5F9), const Color(0xFF475569)),
      _ => Tone(t('البوت يرد'), const Color(0xFFD1FAE5), const Color(0xFF065F46)),
    };

String money(num v, String currency) => '${v.toStringAsFixed(2)} $currency';

String timeAgo(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final minutes = DateTime.now().difference(d).inMinutes;
  if (minutes < 1) return t('الآن');
  if (minutes < 60) return t('منذ {n} د', {'n': minutes});
  final hours = minutes ~/ 60;
  if (hours < 24) return t('منذ {n} س', {'n': hours});
  return t('منذ {n} يوم', {'n': hours ~/ 24});
}

String clock(String iso) {
  final d = (DateTime.tryParse(iso) ?? DateTime.now()).toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String ltr(String? v) => v == null || v.isEmpty ? '' : '\u2066$v\u2069';

// ---------- نماذج (خرائط ديناميكية بغلاف رقيق) ----------
typedef J = Map<String, dynamic>;

String customerName(J? c) {
  final name = c?['name'] as String?;
  final phone = c?['phone'] as String?;
  return (name != null && name.isNotEmpty) ? name : (phone ?? t('عميل'));
}

num n(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);

// ---------- Polling ----------
class Poller {
  Poller(this.fn, this.interval) {
    fn();
    _timer = Timer.periodic(interval, (_) => fn());
  }
  final Future<void> Function() fn;
  final Duration interval;
  late final Timer _timer;
  void dispose() => _timer.cancel();
}

// ---------- حوارات ----------
Future<void> notify(BuildContext context, String title, [String? message]) => showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text('OK'))],
      ),
    );

Future<void> confirmAction(BuildContext context, String title, String message, String confirmText, VoidCallback onConfirm, {bool destructive = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('إلغاء'))),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmText, style: TextStyle(color: destructive ? C.danger : C.primary)),
        ),
      ],
    ),
  );
  if (ok == true) onConfirm();
}

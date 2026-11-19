import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../auth.dart';
import '../core.dart';
import '../ui.dart';

class Home extends StatefulWidget {
  const Home({super.key, required this.onGo});
  final void Function(int) onGo;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends PollState<Home> {
  J? stats;
  bool toggling = false;

  @override
  Duration get every => const Duration(seconds: 20);

  @override
  Future<void> load() async {
    final s = await api('/stats');
    safeSet(() => stats = s);
    await auth.refreshUser().catchError((_) {});
  }

  Future<void> run(Future<void> Function() action, String fallback) async {
    setState(() => toggling = true);
    try {
      await action();
      await load();
    } on ApiError catch (e) {
      if (mounted) notify(context, t('خطأ'), e.message);
    } catch (_) {
      if (mounted) notify(context, t('خطأ'), fallback);
    }
    safeSet(() => toggling = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: auth,
        builder: (context, _) {
          final user = auth.user;
          final m = auth.merchant;
          final s = stats;
          final hours = s?['hours'] as J?;
          final status = m?['status'];
          final tiles = s == null
              ? <(String, String, Color?, VoidCallback?)>[]
              : [
                  (t('طلبات اليوم'), '${s['orders_today']}', null, null),
                  (t('مبيعات اليوم'), money(n(s['sales_today']), '${s['currency']}'), null, null),
                  (t('بانتظار القبول'), '${s['pending_orders']}', n(s['pending_orders']) > 0 ? const Color(0xFFD97706) : null, () => widget.onGo(2)),
                  (t('تحتاج موظفاً'), '${s['needs_human']}', n(s['needs_human']) > 0 ? C.danger : null, () => widget.onGo(1)),
                ];
          return RefreshIndicator(
            onRefresh: load,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text(t('أهلاً، {name} 👋', {'name': user?['name'] ?? ''}), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text('${m?['name'] ?? ''}', style: const TextStyle(color: C.muted)),
              const SizedBox(height: 16),
              if (m != null)
                CardBox(
                  gap: 6,
                  border: status == 'expired' ? C.danger : (status == 'pending' || m['requested_plan'] != null) ? const Color(0xFFFCD34D) : C.border,
                  children: [
                    if (status == 'pending') ...[
                      Text(t('⏳ حسابك بانتظار التفعيل'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        '${m['requested_plan_label'] != null ? t('سنتواصل معك لتفعيل باقة {plan} بعد الدفع.', {'plan': m['requested_plan_label']}) : t('نراجع طلبك ونفعّل حسابك قريباً، وتبدأ تجربتك المجانية من يوم التفعيل.')} ${t('عند التفعيل يظهر مطعمك للعملاء تلقائياً، جهّز منيوك من لوحة التحكم على الويب.')}',
                        style: const TextStyle(color: C.muted, fontSize: 13),
                      ),
                    ] else if (status == 'expired') ...[
                      Text(t('⛔ انتهى اشتراك باقة {plan}', {'plan': m['plan_label']}), style: const TextStyle(fontWeight: FontWeight.w700, color: C.danger)),
                      Text(t('مطعمك معطّل ولا يظهر للعملاء. تواصل معنا للتجديد.'), style: const TextStyle(color: C.muted, fontSize: 13)),
                    ] else ...[
                      Text(
                        '${t('📦 باقة {plan}', {'plan': m['plan_label']})}${m['days_left'] != null ? ' · ${t('باقي {n} يوماً', {'n': m['days_left']})}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (m['requested_plan_label'] != null)
                        Text(t('⏳ طلب باقة {plan} قيد المراجعة. سنتواصل معك لتفعيلها بعد الدفع.', {'plan': m['requested_plan_label']}), style: const TextStyle(color: Color(0xFF92400E), fontSize: 13)),
                      if (m['listed_on_platform'] != true)
                        Text(t('مطعمك مخفي عن العملاء. فعّل الظهور من الإعدادات في لوحة التحكم.'), style: const TextStyle(color: C.muted, fontSize: 13)),
                    ],
                  ],
                ),
              if (s?['share_url'] != null) ...[
                const SizedBox(height: 16),
                CardBox(children: [
                  Text(t('📲 رابط الطلب من مطعمك'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(t('من يفتحه يطلب منك مباشرة عبر واتساب. شاركه في إنستغرام وحالة واتساب، وتجد QR وملصقاً للطباعة في لوحة التحكم.'), style: const TextStyle(color: C.muted, fontSize: 13)),
                  Btn(t('مشاركة الرابط'), () => SharePlus.instance.share(ShareParams(text: '${t('اطلب من {name} عبر واتساب 👇', {'name': m?['name'] ?? t('مطعمنا')})}\n${s!['share_url']}'))),
                ]),
              ],
              const SizedBox(height: 16),
              CardBox(children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s?['bot_enabled'] == true ? t('🤖 البوت يعمل') : t('⏸️ البوت متوقف'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(s?['bot_enabled'] == true ? t('يرد على العملاء تلقائياً') : t('الرسائل تصلك دون رد تلقائي'), style: const TextStyle(color: C.muted, fontSize: 13)),
                    ]),
                  ),
                  Switch(
                    value: s?['bot_enabled'] == true,
                    activeColor: C.primary,
                    onChanged: s == null || toggling ? null : (v) => run(() => api('/bot', method: 'PATCH', body: {'bot_enabled': v}), t('تعذر تغيير حالة البوت.')),
                  ),
                ]),
              ]),
              if (hours != null) ...[
                const SizedBox(height: 16),
                CardBox(gap: 10, border: hours['reason'] == 'emergency' ? C.danger : C.border, children: [
                  Text(
                    hours['open'] == true ? t('🟢 المطعم مفتوح الآن') : hours['reason'] == 'emergency' ? t('⛔ إغلاق طارئ') : t('🌙 مغلق حسب ساعات العمل'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (hours['open'] != true && hours['message'] != null)
                    Text(t('رسالة العملاء: {message}', {'message': hours['message'] as String}), style: const TextStyle(color: C.muted, fontSize: 13)),
                  if (hours['reason'] == 'emergency')
                    Btn(t('إعادة الفتح الآن'), toggling ? null : () => run(() => api('/emergency', method: 'PATCH', body: {'closed': false}), t('تعذر تغيير حالة المطعم.')))
                  else
                    Btn(
                      t('إغلاق طارئ'),
                      toggling
                          ? null
                          : () => confirmAction(context, t('إغلاق المطعم الآن؟'), t('لن يأخذ البوت طلبات، وسيرد على كل عميل مرة واحدة بأن المطعم مغلق.'), t('إغلاق'),
                              () => run(() => api('/emergency', method: 'PATCH', body: {'closed': true}), t('تعذر تغيير حالة المطعم.')),
                              destructive: true),
                      color: C.danger,
                    ),
                ]),
              ],
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final (label, value, color, onTap) in tiles)
                  GestureDetector(
                    onTap: onTap,
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: const TextStyle(color: C.muted, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color ?? C.text)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 24),
              const LanguageSwitch(),
            ]),
          );
        },
      );
}

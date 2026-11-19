import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth.dart';
import '../core.dart';
import '../ui.dart';
import 'conversation_detail.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.id});
  final int id;
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends PollState<OrderScreen> {
  J? order;
  bool notifyCustomer = true, paying = false, deciding = false;
  String? saving;
  final reason = TextEditingController();

  @override
  Duration get every => const Duration(seconds: 15);

  @override
  Future<void> load() async {
    final r = await api('/orders/${widget.id}');
    safeSet(() => order = r['data'] as J);
  }

  Future<void> call(String path, Object body, void Function(bool) busy) async {
    busy(true);
    try {
      final r = await api(path, method: 'PATCH', body: body);
      safeSet(() => order = r['data'] as J);
      if (mounted) notify(context, t('تم'), r['message'] as String?);
    } on ApiError catch (e) {
      if (mounted) notify(context, t('خطأ'), e.message);
    } catch (_) {
      if (mounted) notify(context, t('خطأ'), t('حدث خطأ.'));
    }
    busy(false);
  }

  void update(String status) {
    run() => call('/orders/${widget.id}/status', {'status': status, 'notify': notifyCustomer, if (status == 'rejected') 'rejection_reason': reason.text}, (b) => safeSet(() => saving = b ? status : null));
    if (status == 'rejected') {
      confirmAction(context, t('رفض الطلب؟'), t('سيُبلَّغ العميل إذا كان الإشعار مفعلاً.'), t('رفض'), run, destructive: true);
    } else {
      run();
    }
  }

  void decide(String decision) {
    run() => call('/orders/${widget.id}/cancellation', {'decision': decision, 'notify': notifyCustomer}, (b) => safeSet(() => deciding = b));
    if (decision == 'approve') {
      confirmAction(context, t('إلغاء الطلب؟'), t('سيُلغى الطلب ويُبلَّغ العميل.'), t('نعم، ألغِ الطلب'), run, destructive: true);
    } else {
      run();
    }
  }

  void pay(String action) {
    run() => call('/orders/${widget.id}/payment', {'action': action}, (b) => safeSet(() => paying = b));
    if (action == 'paid') {
      confirmAction(context, t('تأكيد الدفع'), t('تأكدت من وصول المبلغ إلى محفظة جوال بي؟'), t('نعم، وصل'), run);
    } else {
      run();
    }
  }

  Widget line(String label, String value, {Color? color, bool bold = false, double size = 15}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: color ?? (bold ? C.text : C.muted), fontWeight: bold ? FontWeight.w700 : null)),
        Text(value, style: TextStyle(color: color ?? (bold ? C.text : C.muted), fontWeight: bold ? FontWeight.w700 : null, fontSize: size)),
      ]);

  @override
  Widget build(BuildContext context) {
    final o = order;
    if (o == null) return Scaffold(appBar: AppBar(title: Text(t('طلب'))), body: const Center(child: CircularProgressIndicator(color: C.primary)));
    final cur = auth.currency;
    final status = '${o['status']}', fulfil = '${o['fulfillment']}';
    final finished = ['delivered', 'rejected', 'cancelled'].contains(status);
    final items = ((o['items'] as List?) ?? []).cast<J>();
    final customer = o['customer'] as J?;
    final ps = '${o['payment_status']}';
    return Scaffold(
      appBar: AppBar(title: Text(t('طلب #{number}', {'number': o['number']}))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(DateTime.tryParse('${o['created_at']}')?.toLocal().toString().substring(0, 16) ?? '', style: const TextStyle(color: C.muted)),
          Badge2(orderTone(status, fulfil)),
        ]),
        const SizedBox(height: 14),
        CardBox(gap: 10, children: [
          for (final it in items) line('${it['quantity']} × ${it['name']}', money(n(it['unit_price']) * n(it['quantity']), cur), color: C.text),
          const Divider(height: 1),
          line(t('مجموع الأصناف'), money(n(o['subtotal']), cur)),
          line(t('التوصيل'), fulfil == 'pickup' ? '—' : (n(o['delivery_fee']) > 0 ? money(n(o['delivery_fee']), cur) : t('مجاني'))),
          if (n(o['discount']) > 0) line(t('خصم'), '−${money(n(o['discount']), cur)}', color: C.primary),
          line(t('الإجمالي'), money(n(o['total']), cur), bold: true, size: 18),
          if (o['notes'] != null && '${o['notes']}'.isNotEmpty) Text(t('ملاحظات: {notes}', {'notes': '${o['notes']}'}), style: const TextStyle(color: C.muted)),
        ]),
        if (o['invoice_url'] != null) ...[
          const SizedBox(height: 14),
          Btn(t('🖨️ طباعة الفاتورة'), () async {
            final ok = await launchUrl(Uri.parse('${o['invoice_url']}'), mode: LaunchMode.externalApplication).catchError((_) => false);
            if (!ok && mounted) notify(context, t('خطأ'), t('تعذر فتح الفاتورة.'));
          }, outline: true),
        ],
        const SizedBox(height: 14),
        CardBox(gap: 6, children: [
          Text(customerName(customer), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(ltr(customer?['phone'] as String?), style: const TextStyle(color: C.muted)),
          Text(fulfil == 'pickup' ? t('🏪 استلام من المطعم') : '${t('🛵 توصيل')} · 📍 ${o['delivery_address'] ?? ''}'),
          if (o['conversation_id'] != null)
            Btn(t('فتح المحادثة'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationScreen(id: o['conversation_id'] as int))), outline: true),
        ]),
        const SizedBox(height: 14),
        CardBox(gap: 10, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t('الدفع'), style: const TextStyle(fontWeight: FontWeight.w700)), Badge2(paymentTone(ps))]),
          Text(paymentMethod('${o['payment_method']}'), style: const TextStyle(color: C.muted)),
          if (o['can_confirm_payment'] == true) ...[
            if (ps == 'proof_sent') Text(t('أرسل العميل صورة التحويل. تحقق من وصول {amount} إلى محفظتك.', {'amount': money(n(o['total']), cur)}), style: const TextStyle(color: Color(0xFF075985), fontSize: 13)),
            Row(children: [
              Expanded(child: Btn(t('وصل التحويل ✓'), paying ? null : () => pay('paid'), loading: paying)),
              const SizedBox(width: 8),
              Expanded(child: Btn(t('لم يصل'), paying ? null : () => pay('not_received'), outline: true)),
            ]),
          ],
        ]),
        if (o['cancel_requested'] == true) ...[
          const SizedBox(height: 14),
          CardBox(gap: 10, border: const Color(0xFFFCD34D), fill: const Color(0xFFFFFBEB), children: [
            Text(t('⚠️ العميل يطلب إلغاء هذا الطلب'), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
            if (o['cancel_request_reason'] != null) Text(t('السبب: {reason}', {'reason': '${o['cancel_request_reason']}'}), style: const TextStyle(color: Color(0xFF92400E))),
            if (ps == 'paid' || ps == 'proof_sent') Text(t('الطلب مدفوع: عند الموافقة أعِد المبلغ للعميل.'), style: const TextStyle(color: Color(0xFF92400E))),
            Row(children: [
              Expanded(child: Btn(t('الموافقة على الإلغاء'), deciding ? null : () => decide('approve'), color: C.danger, loading: deciding)),
              const SizedBox(width: 8),
              Expanded(child: Btn(t('رفض الإلغاء'), deciding ? null : () => decide('decline'), outline: true)),
            ]),
          ]),
        ],
        const SizedBox(height: 14),
        CardBox(gap: 12, children: [
          Text(t('تحديث الحالة'), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (status == 'pending') ...[
            Row(children: [
              Expanded(child: Btn(t('قبول'), saving != null || o['awaiting_online_payment'] == true ? null : () => update('accepted'), color: const Color(0xFF0284C7), loading: saving == 'accepted')),
              const SizedBox(width: 8),
              Expanded(child: Btn(t('رفض'), saving != null ? null : () => update('rejected'), color: C.danger, loading: saving == 'rejected')),
            ]),
            if (o['awaiting_online_payment'] == true) Text(t('💳 بانتظار الدفع الإلكتروني: يصبح القبول متاحاً بعد أن يدفع العميل عبر لحظة.'), style: const TextStyle(color: Color(0xFFB45309))),
            TextField(controller: reason, maxLength: 255, decoration: inputDeco(hint: t('سبب الرفض (اختياري، يصل للعميل)'))),
          ],
          if (status == 'accepted') Btn(fulfil == 'pickup' ? t('تم التسليم') : t('تم التوصيل'), saving != null ? null : () => update('delivered'), loading: saving == 'delivered'),
          if (finished) ...[
            Text(t('الطلب منتهٍ، ولا يمكن تغيير حالته.'), style: const TextStyle(color: C.muted)),
            if (o['rejection_reason'] != null) Text(t('سبب الرفض: {reason}', {'reason': '${o['rejection_reason']}'}), style: const TextStyle(color: C.muted)),
          ],
          if (!finished)
            Row(children: [
              Expanded(child: Text(t('إرسال إشعار للعميل على واتساب'))),
              Switch(value: notifyCustomer, activeColor: C.primary, onChanged: (v) => setState(() => notifyCustomer = v)),
            ]),
        ]),
      ]),
    );
  }
}

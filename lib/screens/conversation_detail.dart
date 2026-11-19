import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core.dart';
import '../ui.dart';
import 'order_detail.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.id});
  final int id;
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends PollState<ConversationScreen> {
  J? conversation;
  List<J> messages = [];
  bool canReply = false, sending = false;
  int lastId = 0;
  final text = TextEditingController();
  final scroll = ScrollController();

  @override
  Duration get every => const Duration(seconds: 4);

  void toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
      });

  Future<void> loadAll() async {
    final d = (await api('/conversations/${widget.id}'))['data'] as J;
    safeSet(() {
      conversation = d;
      messages = ((d['messages'] as List?) ?? []).cast<J>();
      canReply = d['can_reply'] == true;
      lastId = messages.isEmpty ? 0 : messages.last['id'] as int;
    });
    toEnd();
  }

  @override
  Future<void> load() async {
    try {
      if (conversation == null) return await loadAll();
      final u = await api('/conversations/${widget.id}/messages?after=$lastId');
      final raw = u['messages'];
      final fresh = (raw is List ? raw : (raw is Map ? (raw['data'] as List? ?? []) : [])).cast<J>();
      safeSet(() {
        canReply = u['can_reply'] == true;
        if (u['status'] != conversation!['status']) conversation = {...conversation!, 'status': u['status']};
        if (fresh.isNotEmpty) {
          lastId = fresh.last['id'] as int;
          messages = [...messages, ...fresh];
        }
      });
      if (fresh.isNotEmpty) toEnd();
    } on ApiError catch (e) {
      if (e.status == 404 && mounted) Navigator.pop(context);
    }
  }

  Future<void> send() async {
    final body = text.text.trim();
    if (body.isEmpty) return;
    setState(() => sending = true);
    try {
      await api('/conversations/${widget.id}/reply', method: 'POST', body: {'body': body});
      text.clear();
      await loadAll();
    } on ApiError catch (e) {
      if (mounted) notify(context, t('لم تُرسل الرسالة'), e.message);
    } catch (_) {
      if (mounted) notify(context, t('لم تُرسل الرسالة'), t('حدث خطأ.'));
    }
    safeSet(() => sending = false);
  }

  Future<void> changeStatus(String status) async {
    try {
      await api('/conversations/${widget.id}/status', method: 'PATCH', body: {'status': status});
      safeSet(() => conversation = {...conversation!, 'status': status});
    } on ApiError catch (e) {
      if (mounted) notify(context, t('خطأ'), e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    if (c == null) return Scaffold(appBar: AppBar(title: Text(t('محادثة'))), body: const Center(child: CircularProgressIndicator(color: C.primary)));
    final status = '${c['status']}';
    final actions = [('human', t('تولَّ المحادثة'), const Color(0xFFD97706)), ('bot', t('أعدها للبوت'), C.primary), ('closed', t('إغلاق'), const Color(0xFF475569))].where((a) => a.$1 != status);
    final orders = ((c['orders'] as List?) ?? []).cast<J>();
    return Scaffold(
      appBar: AppBar(title: Text(customerName(c['customer'] as J?))),
      body: Column(children: [
        Container(
          color: C.card,
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(ltr((c['customer'] as J?)?['phone'] as String?), style: const TextStyle(color: C.muted)), Badge2(conversationTone(status))]),
            const SizedBox(height: 10),
            Row(children: [
              for (final a in actions) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Btn(a.$2, () => changeStatus(a.$1), color: a.$3))),
            ]),
            for (final o in orders)
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(id: o['id'] as int))),
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${t('🧾 طلب #{number}', {'number': o['number']})} · ${o['total']}', style: const TextStyle(fontSize: 13)),
                    Badge2(orderTone('${o['status']}', '${o['fulfillment']}')),
                  ]),
                ),
              ),
          ]),
        ),
        Expanded(
          child: Container(
            color: C.chatBg,
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                final role = '${m['role']}';
                final fromCustomer = role == 'customer';
                final label = role == 'bot' ? t('🤖 البوت') : role == 'agent' ? t('👤 موظف') : '';
                return Align(
                  // رسائل العميل في جهة بداية السطر، وردود البوت والموظف في الجهة المقابلة
                  alignment: fromCustomer ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: fromCustomer ? Colors.white : (role == 'bot' ? const Color(0xFFD1FAE5) : const Color(0xFFE0F2FE)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (m['media_url'] != null && m['is_image'] == true)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('${m['media_url']}', headers: authHeaders(), width: 220, height: 220, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 220, height: 60, child: Center(child: Text('🖼'))))),
                        )
                      else if (m['media_url'] != null)
                        GestureDetector(onTap: () => launchUrl(Uri.parse('${m['media_url']}'), mode: LaunchMode.externalApplication), child: Text(t('⬇️ فتح الملف'), style: const TextStyle(color: C.primary, decoration: TextDecoration.underline))),
                      Text('${m['body'] ?? ''}'),
                      Text([label, clock('${m['created_at']}')].where((s) => s.isNotEmpty).join(' '), style: const TextStyle(fontSize: 10, color: C.muted)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
        Container(
          color: C.card,
          padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
          child: canReply
              ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: TextField(controller: text, minLines: 1, maxLines: 5, decoration: inputDeco(hint: t('اكتب ردك… (يوقف البوت في هذه المحادثة)')), onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 8),
                  Btn(t('إرسال'), text.text.trim().isEmpty ? null : send, loading: sending),
                ])
              : Text(t('مرت 24 ساعة على آخر رسالة من العميل؛ لا يمكن الرد حتى يراسلك مجدداً.'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontSize: 13)),
        ),
      ]),
    );
  }
}

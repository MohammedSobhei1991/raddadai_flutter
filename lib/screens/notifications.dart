import 'package:flutter/material.dart';

import '../core.dart';
import '../ui.dart';
import 'conversation_detail.dart';
import 'order_detail.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});
  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends PollState<NotificationsTab> {
  String filter = '';
  List<J>? items;

  @override
  Duration get every => const Duration(seconds: 15);

  @override
  Future<void> load() async {
    final r = await api('/notifications${filter.isEmpty ? '' : '?unread=1'}');
    safeSet(() => items = ((r['data'] as List?) ?? []).cast<J>());
  }

  void open(J item) {
    if (item['read'] != true) {
      setState(() => item['read'] = true);
      api('/notifications/${item['id']}/read', method: 'POST').catchError((_) => <String, dynamic>{});
    }
    final id = item['target_id'];
    if (id is! int) return;
    if (item['target_type'] == 'order') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(id: id)));
    } else if (item['target_type'] == 'conversation') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationScreen(id: id)));
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: load,
        child: ListView(children: [
          Row(children: [
            Expanded(child: Chips<String>(options: [('', t('الكل')), ('unread', t('غير المقروءة'))], value: filter, onChange: (v) {
              setState(() {
                filter = v;
                items = null;
              });
              load();
            })),
            if (items?.any((x) => x['read'] != true) ?? false)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Btn(t('قراءة الكل'), () async {
                  await api('/notifications/read-all', method: 'POST').catchError((_) => <String, dynamic>{});
                  await load();
                }, outline: true),
              ),
          ]),
          if (items == null || items!.isEmpty) Empty(items == null ? t('جاري التحميل…') : t('لا توجد إشعارات.')),
          for (final x in items ?? <J>[])
            InkWell(
              onTap: () => open(x),
              child: Container(
                color: x['read'] == true ? C.card : (x['urgent'] == true ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 1),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${x['icon']}', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${x['title']}', style: TextStyle(fontWeight: x['read'] == true ? FontWeight.w500 : FontWeight.w700, color: x['urgent'] == true ? C.danger : C.text)),
                      if (x['body'] != null) Text('${x['body']}', style: const TextStyle(color: C.muted, fontSize: 13)),
                    ]),
                  ),
                  Text(timeAgo(x['created_at'] as String?), style: const TextStyle(color: C.muted, fontSize: 11)),
                ]),
              ),
            ),
        ]),
      );
}

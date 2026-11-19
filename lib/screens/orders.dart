import 'package:flutter/material.dart';

import '../auth.dart';
import '../core.dart';
import '../ui.dart';
import 'order_detail.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends PollState<OrdersTab> {
  String filter = '';
  List<J>? items;
  Map counts = {};

  @override
  Duration get every => const Duration(seconds: 10);

  @override
  Future<void> load() async {
    final r = await api('/orders${filter.isEmpty ? '' : '?status=$filter'}');
    safeSet(() {
      items = ((r['data'] as List?) ?? []).cast<J>();
      counts = (r['counts'] as Map?) ?? {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('', t('الكل')),
      ('pending', t('بانتظار القبول')),
      ('cancel_requested', t('⚠️ طلبات إلغاء')),
      ('accepted', t('مقبولة')),
      ('delivered', t('تم التوصيل')),
      ('rejected', t('مرفوضة')),
      ('cancelled', t('ألغاها العميل')),
    ];
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(children: [
        Chips<String>(
          options: [for (final (v, l) in filters) (v, '$l (${counts[v] ?? 0})')],
          value: filter,
          onChange: (v) {
            setState(() {
              filter = v;
              items = null;
            });
            load();
          },
        ),
        if (items == null || items!.isEmpty) Empty(items == null ? t('جاري التحميل…') : t('لا توجد طلبات.')),
        for (final o in items ?? <J>[])
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(id: o['id'] as int))),
            child: Container(
              color: C.card,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 1),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('#${o['number']} · ${customerName(o['customer'] as J?)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${t('{n} أصناف', {'n': o['items_count'] ?? 0})} · ${o['fulfillment'] == 'pickup' ? t('🏪 استلام') : '🛵 ${o['delivery_address'] ?? ''}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: C.muted, fontSize: 13),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(n(o['total']), auth.currency), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Badge2(orderTone('${o['status']}', '${o['fulfillment']}')),
                  if (o['cancel_requested'] == true) ...[const SizedBox(height: 4), Badge2(Tone(t('⚠️ طلب إلغاء'), const Color(0xFFFEF3C7), const Color(0xFF92400E)))],
                  Text(timeAgo(o['created_at'] as String?), style: const TextStyle(color: C.muted, fontSize: 11)),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import '../core.dart';
import '../ui.dart';
import 'conversation_detail.dart';

class ConversationsTab extends StatefulWidget {
  const ConversationsTab({super.key});
  @override
  State<ConversationsTab> createState() => _ConversationsTabState();
}

class _ConversationsTabState extends PollState<ConversationsTab> {
  String filter = '';
  List<J>? items;

  @override
  Duration get every => const Duration(seconds: 10);

  @override
  Future<void> load() async {
    final r = await api('/conversations${filter.isEmpty ? '' : '?status=$filter'}');
    safeSet(() => items = ((r['data'] as List?) ?? []).cast<J>());
  }

  @override
  Widget build(BuildContext context) {
    const prefix = {'customer': '', 'bot': '🤖 ', 'agent': '👤 '};
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(children: [
        Chips<String>(
          options: [('', t('الكل')), ('human', t('تحتاج موظفاً')), ('bot', t('البوت يرد')), ('closed', t('مغلقة'))],
          value: filter,
          onChange: (v) {
            setState(() {
              filter = v;
              items = null;
            });
            load();
          },
        ),
        if (items == null || items!.isEmpty) Empty(items == null ? t('جاري التحميل…') : t('لا توجد محادثات.')),
        for (final c in items ?? <J>[])
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationScreen(id: c['id'] as int))),
            child: Container(
              color: C.card,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 1),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(customerName(c['customer'] as J?), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Builder(builder: (_) {
                      final last = c['latest_message'] as J?;
                      return Text(last == null ? '' : '${prefix[last['role']] ?? ''}${last['body']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 13));
                    }),
                  ]),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(timeAgo(c['last_message_at'] as String?), style: const TextStyle(color: C.muted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Badge2(conversationTone('${c['status']}')),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}

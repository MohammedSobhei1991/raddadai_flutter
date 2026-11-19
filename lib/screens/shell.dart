import 'package:flutter/material.dart';

import '../core.dart';
import '../push.dart';
import '../ui.dart';
import 'conversations.dart';
import 'home.dart';
import 'notifications.dart';
import 'orders.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends PollState<Shell> {
  int index = 0;
  J? stats;
  int? lastSeen;

  @override
  Duration get every => const Duration(seconds: 15);

  @override
  Future<void> load() async {
    try {
      final s = await api('/stats');
      safeSet(() => stats = s);
    } catch (_) {}
    // تنبيه محلي لكل إشعار جديد
    try {
      final latest = (((await api('/notifications'))['data']) as List).cast<J>();
      if (latest.isEmpty) return;
      final newest = latest.first['id'] as int;
      if (lastSeen != null && newest > lastSeen!) {
        for (final x in latest.where((x) => (x['id'] as int) > lastSeen! && x['read'] != true).toList().reversed) {
          await LocalAlerts.show('${x['icon']} ${x['title']}', x['body'] as String?);
        }
      }
      lastSeen = newest > (lastSeen ?? 0) ? newest : lastSeen;
    } catch (_) {}
  }

  Widget badge(int? count, Widget icon) => count == null || count == 0 ? icon : Badge(label: Text('$count'), child: icon);

  @override
  Widget build(BuildContext context) {
    final titles = [t('الرئيسية'), t('المحادثات'), t('الطلبات'), t('الإشعارات')];
    return Scaffold(
      appBar: AppBar(title: Text(titles[index]), actions: const [LogoutButton()]),
      body: IndexedStack(index: index, children: [
        Home(onGo: (i) => setState(() => index = i)),
        const ConversationsTab(),
        const OrdersTab(),
        const NotificationsTab(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          NavigationDestination(icon: const Text('🏠', style: TextStyle(fontSize: 20)), label: titles[0]),
          NavigationDestination(icon: badge(stats?['needs_human'] as int?, const Text('💬', style: TextStyle(fontSize: 20))), label: titles[1]),
          NavigationDestination(icon: badge(stats?['pending_orders'] as int?, const Text('🧾', style: TextStyle(fontSize: 20))), label: titles[2]),
          NavigationDestination(icon: badge(stats?['unread_notifications'] as int?, const Text('🔔', style: TextStyle(fontSize: 20))), label: titles[3]),
        ],
      ),
    );
  }
}

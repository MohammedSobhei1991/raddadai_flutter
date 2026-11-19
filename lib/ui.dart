import 'package:flutter/material.dart';

import 'auth.dart';
import 'core.dart';

class Badge2 extends StatelessWidget {
  const Badge2(this.tone, {super.key});
  final Tone tone;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
        child: Text(tone.label, style: TextStyle(color: tone.fg, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.children, this.border, this.fill, this.gap = 8});
  final List<Widget> children;
  final Color? border, fill;
  final double gap;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fill ?? C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border ?? C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]]],
        ),
      );
}

class Btn extends StatelessWidget {
  const Btn(this.title, this.onPressed, {super.key, this.color = C.primary, this.outline = false, this.loading = false});
  final String title;
  final VoidCallback? onPressed;
  final Color color;
  final bool outline, loading;
  @override
  Widget build(BuildContext context) {
    final inactive = onPressed == null || loading;
    final child = loading
        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: outline ? C.text : Colors.white))
        : Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: outline ? C.text : Colors.white));
    return Opacity(
      opacity: inactive ? 0.4 : 1,
      child: Material(
        color: outline ? Colors.transparent : color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: outline ? const BorderSide(color: C.border) : BorderSide.none),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: inactive ? null : onPressed,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14), child: Center(child: child)),
        ),
      ),
    );
  }
}

class Chips<V> extends StatelessWidget {
  const Chips({super.key, required this.options, required this.value, required this.onChange});
  final List<(V, String)> options;
  final V value;
  final void Function(V) onChange;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (v, label) in options)
            GestureDetector(
              onTap: () => onChange(v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: v == value ? C.primary : Colors.white,
                  border: Border.all(color: v == value ? C.primary : C.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(label, style: TextStyle(fontSize: 13, color: v == value ? Colors.white : C.text)),
              ),
            ),
        ]),
      );
}

class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final (v, label) in [('ar', 'العربية'), ('tr', 'Türkçe')])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => auth.chooseLocale(v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: l10n.locale == v ? C.primary : Colors.white,
                  border: Border.all(color: l10n.locale == v ? C.primary : C.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(label, style: TextStyle(fontSize: 12, color: l10n.locale == v ? Colors.white : C.text)),
              ),
            ),
          ),
      ]);
}

class Empty extends StatelessWidget {
  const Empty(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(text, style: const TextStyle(color: C.muted))));
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator(color: C.primary)));
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => confirmAction(context, t('تسجيل الخروج'), t('لن تصلك إشعارات على هذا الجهاز بعد الخروج.'), t('خروج'), () => auth.logout(), destructive: true),
        child: Text(t('خروج ⎋'), style: const TextStyle(color: C.danger, fontWeight: FontWeight.w700)),
      );
}

InputDecoration inputDeco({String? hint}) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
    );

/// مساعد لشاشات تعيد البناء عند تغير اللغة وتدير Poller
abstract class PollState<T extends StatefulWidget> extends State<T> {
  Poller? _poller;
  Duration get every;
  Future<void> load();
  @override
  void initState() {
    super.initState();
    _poller = Poller(() async {
      try {
        await load();
      } catch (_) {}
    }, every);
  }

  @override
  void dispose() {
    _poller?.dispose();
    super.dispose();
  }

  void safeSet(VoidCallback f) {
    if (mounted) setState(f);
  }
}

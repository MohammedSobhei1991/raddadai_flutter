import 'package:flutter/material.dart';

import '../auth.dart';
import '../core.dart';
import '../ui.dart';

String _local(J item) => (l10n.locale == 'tr' && item['label_tr'] != null ? item['label_tr'] : item['label']) as String;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  J? options;
  String? loadError, error;
  bool loading = false;
  final name = TextEditingController(), phone = TextEditingController(), owner = TextEditingController(), email = TextEditingController(), password = TextEditingController();
  String country = 'ps', region = 'west_bank', plan = 'trial';

  @override
  void initState() {
    super.initState();
    fetch();
  }

  Future<void> fetch() async {
    setState(() => loadError = null);
    try {
      final loaded = await api('/signup-options?locale=${l10n.locale}');
      final countries = ((loaded['countries'] as List?) ?? []).cast<J>();
      if (!mounted) return;
      setState(() {
        options = loaded;
        if (countries.isNotEmpty && !countries.any((c) => c['key'] == country)) {
          country = countries.first['key'] as String;
          region = ((countries.first['regions'] as List).isEmpty ? '' : (countries.first['regions'] as List).first['key']) as String;
        }
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => loadError = e.message);
    }
  }

  List<J> get countries => ((options?['countries'] as List?) ?? []).cast<J>();
  List<J> get plans => ((options?['plans'] as List?) ?? []).cast<J>();
  J? get currentCountry => countries.where((c) => c['key'] == country).firstOrNull ?? countries.firstOrNull;
  bool availableIn(J p, String key) {
    final c = (p['countries'] as List?) ?? [];
    return c.isEmpty || c.contains(key);
  }

  void chooseCountry(String key) {
    final picked = countries.firstWhere((c) => c['key'] == key);
    final regions = (picked['regions'] as List).cast<J>();
    setState(() {
      country = key;
      region = regions.isEmpty ? '' : regions.first['key'] as String;
      final p = plans.where((x) => x['key'] == plan).firstOrNull;
      if (p == null || !availableIn(p, key)) plan = 'trial';
    });
  }

  bool get complete => [name, phone, owner, email].every((c) => c.text.trim().isNotEmpty) && password.text.isNotEmpty && options != null;

  Future<void> submit() async {
    setState(() {
      error = null;
      loading = true;
    });
    try {
      await auth.register({
        'restaurant_name': name.text.trim(),
        'country': country,
        'region': region,
        'contact_phone': phone.text.replaceAll(RegExp(r'[\s-]'), ''),
        'plan': plan,
        'owner_name': owner.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
      });
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } on ApiError catch (e) {
      error = e.message;
    } catch (_) {
      error = t('حدث خطأ غير متوقع.');
    }
    if (mounted) setState(() => loading = false);
  }

  Widget field(String label, TextEditingController c, {bool ltrField = false, String? hint, bool secret = false, TextInputType? type}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label),
        const SizedBox(height: 6),
        TextField(controller: c, obscureText: secret, keyboardType: type, textDirection: ltrField ? TextDirection.ltr : null, decoration: inputDeco(hint: hint), onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
      ]);

  Widget planCard(J p) {
    final selected = p['key'] == plan;
    final prices = (p['prices'] as Map?) ?? {};
    final price = n(prices[country] ?? p['price']);
    final features = [
      p['max_products'] == null ? t('منتج بلا حد') : t('حتى {n} منتج', {'n': p['max_products']}),
      p['max_users'] == null ? t('حسابات بلا حد') : (p['max_users'] == 1 ? t('حتى {n} حساب', {'n': 1}) : t('حتى {n} حسابات', {'n': p['max_users']})),
      n(p['commission']) != 0 ? t('عمولة {n}% على الطلبات', {'n': p['commission']}) : t('بدون عمولة'),
      p['online_payments'] == true ? t('دفع إلكتروني بالبطاقة') : t('دفع نقدي فقط'),
      if (p['featured'] == true) t('يظهر أولاً في قائمة المطاعم'),
    ];
    return GestureDetector(
      onTap: () => setState(() => plan = p['key'] as String),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFECFDF5) : C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? C.primary : C.border, width: selected ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_local(p), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (p['featured'] == true) ...[const SizedBox(width: 8), Badge2(Tone(t('الأفضل'), const Color(0xFFFEF3C7), const Color(0xFF92400E)))],
            const Spacer(),
            Text(
              price > 0 ? t('{price} / شهر', {'price': '$price ${currentCountry?['symbol'] ?? '₪'}'}) : t('مجاني {n} يوماً', {'n': p['trial_days'] ?? 0}),
              style: const TextStyle(fontWeight: FontWeight.w700, color: C.primaryDark),
            ),
          ]),
          const SizedBox(height: 4),
          for (final f in features) Text('✓ $f', style: const TextStyle(color: C.muted, fontSize: 13)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cc = currentCountry;
    final regions = ((cc?['regions'] as List?) ?? []).cast<J>();
    final selectedPlan = plans.where((p) => p['key'] == plan).firstOrNull;
    final trialDays = plans.where((p) => p['key'] == 'trial').firstOrNull?['trial_days'];
    return Scaffold(
      appBar: AppBar(title: Text(t('سجّل مطعمك'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const LanguageSwitch(),
          const SizedBox(height: 12),
          Center(child: Text(t('بوت واتساب يستقبل طلبات عملائك ويرد عليهم تلقائياً'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
          const SizedBox(height: 16),
          CardBox(children: [
            Text(t('بيانات المطعم'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            field(t('اسم المطعم'), name, hint: t('مثال: مطعم الياسمين')),
            if (countries.length > 1) ...[
              Text(t('الدولة')),
              Chips<String>(options: [for (final c in countries) (c['key'] as String, '${c['flag']} ${_local(c)}')], value: country, onChange: chooseCountry),
            ],
            Text(countries.length > 1 ? t('المدينة / المنطقة') : t('المنطقة')),
            Chips<String>(options: [for (final r in regions) (r['key'] as String, _local(r))], value: region, onChange: (v) => setState(() => region = v)),
            field(t('رقم الجوال للتواصل'), phone, ltrField: true, hint: cc?['phone_example'] as String? ?? '0599123456', type: TextInputType.phone),
          ]),
          const SizedBox(height: 16),
          Text(t('اختر باقتك'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (loadError != null)
            CardBox(children: [Text(loadError!, style: const TextStyle(color: C.danger)), Btn(t('إعادة المحاولة'), fetch, outline: true)])
          else if (options == null)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: C.primary)))
          else
            for (final p in plans.where((p) => availableIn(p, country))) planCard(p),
          if (selectedPlan != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${n(selectedPlan['price']) > 0 ? t('يراجع فريقنا طلبك ويتواصل معك لتفعيل باقة {plan} بعد الدفع.', {'plan': _local(selectedPlan)}) : t('يراجع فريقنا طلبك ويفعّله، وتبدأ التجربة المجانية {n} يوماً من يوم التفعيل.', {'n': trialDays ?? 0})} ${t('يظهر مطعمك للعملاء تلقائياً عند التفعيل.')}',
                style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          CardBox(children: [
            Text(t('حساب صاحب المطعم'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            field(t('الاسم'), owner),
            field(t('البريد الإلكتروني'), email, ltrField: true, type: TextInputType.emailAddress),
            field(t('كلمة المرور'), password, ltrField: true, secret: true, hint: t('8 أحرف على الأقل')),
          ]),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
              child: Text(error!, style: const TextStyle(color: C.danger)),
            ),
          ],
          const SizedBox(height: 16),
          Btn(t('إنشاء الحساب'), complete ? submit : null, loading: loading),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('لديك حساب؟ سجّل الدخول'), style: const TextStyle(color: C.primaryDark, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../auth.dart';
import '../core.dart';
import '../ui.dart';
import 'register.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), password = TextEditingController();
  String? error;
  bool loading = false;

  Future<void> submit() async {
    setState(() {
      error = null;
      loading = true;
    });
    try {
      await auth.login(email.text.trim(), password.text);
    } on ApiError catch (e) {
      error = e.message;
    } catch (_) {
      error = t('حدث خطأ غير متوقع.');
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const LanguageSwitch(),
                const SizedBox(height: 16),
                CardBox(gap: 12, children: [
                  Center(
                    child: Column(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/logo.png', width: 72, height: 72)),
                      const SizedBox(height: 6),
                      Text(t('لوحة تحكم المطعم'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      Text(t('الطلبات ومحادثات واتساب في جيبك'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
                    ]),
                  ),
                  if (error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                      child: Text(error!, style: const TextStyle(color: C.danger)),
                    ),
                  Text(t('البريد الإلكتروني')),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, autocorrect: false, textDirection: TextDirection.ltr, decoration: inputDeco(), onChanged: (_) => setState(() {})),
                  Text(t('كلمة المرور')),
                  TextField(controller: password, obscureText: true, textDirection: TextDirection.ltr, decoration: inputDeco(), onChanged: (_) => setState(() {}), onSubmitted: (_) => submit()),
                  Btn(t('دخول'), email.text.isEmpty || password.text.isEmpty ? null : submit, loading: loading),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: Text(t('مطعم جديد؟ سجّل مطعمك الآن'), style: const TextStyle(color: C.primaryDark, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth.dart';
import 'core.dart';
import 'push.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushService.init();
  auth.init();
  runApp(const RaddadApp());
}

class RaddadApp extends StatelessWidget {
  const RaddadApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([l10n, auth]),
        builder: (context, _) => MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'رداد - المطعم',
          locale: Locale(l10n.locale),
          supportedLocales: const [Locale('ar'), Locale('tr')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'CoconNextArabic',
            colorScheme: ColorScheme.fromSeed(seedColor: C.primary, primary: C.primary),
            scaffoldBackgroundColor: C.bg,
            appBarTheme: const AppBarTheme(centerTitle: true, backgroundColor: Colors.white, foregroundColor: C.primaryDark, surfaceTintColor: Colors.white),
            navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: Color(0xFFD1FAE5)),
          ),
          home: !auth.ready ? const Loading() : (auth.user == null ? const LoginScreen() : const Shell()),
        ),
      );
}

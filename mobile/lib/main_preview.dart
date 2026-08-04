// UI smoke-test uchun preview entrypoint — hub/onboardingni chetlab o'tib
// bitta bo'limni to'g'ridan-to'g'ri ochadi.
//
// Circles (standart):
//   flutter run -t lib/main_preview.dart -d <device>
//
// To'yxona (yangi modul, hub'ga hali ulanmagan):
//   flutter run -t lib/main_preview.dart -d <device> --dart-define=PREVIEW=toyxona
//   Backendga ulanish: store.init() haqiqiy token'ni o'qiydi, ya'ni qurilmada
//   ilovaga kirilgan bo'lsa /api/toyxona so'rovlari ishlaydi. Lokal backend uchun:
//   --dart-define=API_URL=http://localhost:3000 (+ adb reverse tcp:3000 tcp:3000).
import 'package:flutter/material.dart';
import 'api.dart';
import 'store.dart';
import 'theme.dart';
import 'main.dart';
import 'screens/toyxona.dart';

const String _preview = String.fromEnvironment('PREVIEW', defaultValue: 'circles');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_preview == 'toyxona') {
    // To'yxona serverdan o'qiydi — til/tema sozlamalari va TOKEN kerak.
    await store.init();
    await Api.loadToken();
    runApp(const ToyxonaPreviewApp());
    return;
  }
  store.S['stage'] = 'app';        // onboarding gate'ini ochamiz
  store.S['screen'] = 'circles';   // Circles tabidan boshlaymiz
  store.S['lang'] = 'en';          // prototip kanonik (inglizcha) matn
  store.S['dark'] = false;
  store.S['meId'] = 'preview';
  store.S['meName'] = 'Preview';
  runApp(const TrustApp());
}

/// To'yxona modulini yakka o'zi ishga tushiradi (hub Stack'isiz).
/// Apparat "orqaga" tugmasini ekranning o'zi boshqaradi (handleSystemBack: true) —
/// hub ichida bu FALSE bo'lishi kerak, u yerda Root PopScope boshqaradi.
class ToyxonaPreviewApp extends StatelessWidget {
  const ToyxonaPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final dark = store.S['dark'] == true;
        final p = pal(dark);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: p.bg,
            useMaterial3: true,
          ),
          home: Scaffold(
            backgroundColor: p.bg,
            resizeToAvoidBottomInset: true,
            body: const SafeArea(
              child: SizedBox.expand(child: ToyxonaScreen(handleSystemBack: true)),
            ),
          ),
        );
      },
    );
  }
}

// Circles UI smoke-test uchun preview entrypoint — auth/backendni chetlab o'tib,
// to'g'ridan-to'g'ri Circles tabini ochadi (Circles butunlay in-memory mock).
// Ishga tushirish: flutter run -t lib/main_preview.dart -d <device>
import 'package:flutter/material.dart';
import 'store.dart';
import 'main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  store.S['stage'] = 'app';        // onboarding gate'ini ochamiz
  store.S['screen'] = 'circles';   // Circles tabidan boshlaymiz
  store.S['lang'] = 'en';          // prototip kanonik (inglizcha) matn
  store.S['dark'] = false;
  store.S['meId'] = 'preview';
  store.S['meName'] = 'Preview';
  runApp(const TrustApp());
}

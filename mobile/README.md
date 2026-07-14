# Trust — mobil ilova (Flutter, Android + iOS)

UI **prototip bilan 1:1**: `prototype/template.html` — dizayn manbasi, `prototype/logic.js` — logika manbasi. Butun holat va hodisalar `lib/store.dart` ichida (prototip logikasining Dart porti), har bir ekran `lib/screens/` da prototipdagi ekranga mos.

Ekranlar: Onboarding (Welcome → Telefon → OTP → PIN, davlat kodi tanlash), Hamkorlar (swipe-arxiv, skeleton, qidiruv, cheksiz scroll), Hamkor sahifasi (chat: matn / ovozli xabar / video-doira / tasdiq kodi / operatsiya kartalari + Operatsiyalar tab, flip-rejim, nom tahrirlash, taklif), Yangi operatsiya / Yangi hamkor sheetlari, Dalil + PDF dalil, O'zgartirish so'rovi va uni ko'rib chiqish, Bildirishnomalar, Ikkinchi tomon tasdig'i, Android push demo, Moliya, Xarajat (hisobot + AI chat + ovoz), Profil (tungi rejim, til UZ/RU).

Ma'lumotlar: demo (prototipdagidek). OTP yuborish/tasdiqlash mavjud backend API'ga ham urinadi (`lib/api.dart`), server javob bermasa demo rejimda davom etadi.

## Ishga tushirish

Platforma papkalari (`android/`, `ios/`) loyihada tayyor:

```bash
cd mobile
flutter pub get
flutter run
```

Agar platforma fayllarini qayta generatsiya qilish kerak bo'lsa: `flutter create . --org uz.trust --project-name trust_mobile` (mavjud fayllarni saqlaydi). iOS build faqat macOS/Xcode'da.

## API manzili

Standart: `http://localhost:3000`. O'zgartirish:

```bash
flutter run --dart-define=API_URL=http://192.168.1.100:3000
```

Eslatma: Android emulyatorda kompyuterning localhost'i `http://10.0.2.2:3000` bo'ladi. Haqiqiy telefonda kompyuter bilan bir Wi-Fi'dagi IP manzilni ishlating. HTTP (cleartext) allaqachon yoqilgan: Android manifestda `usesCleartextTraffic="true"`, iOS Info.plist'da `NSAllowsArbitraryLoads` (ishlab chiqarishda HTTPS'ga o'tgach bularni cheklang).

## Tuzilma

- `lib/theme.dart` — dizayn tokenlari (light/dark palitra, prototip bilan 1:1)
- `lib/store.dart` — butun holat + logika (ChangeNotifier), `vals()` prototip placeholderlarini beradi
- `lib/ui.dart` — umumiy vidjetlar (Tx/Inter matn, KeyPad, CodeBoxes, SheetShell, tugmalar, toast)
- `lib/api.dart` — backend chaqiruvlari
- `lib/main.dart` — ekran/overlay kompo
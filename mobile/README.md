# Trust — mobil ilova (Flutter, Android + iOS)

UI **prototip bilan 1:1**: `prototype/template.html` — dizayn manbasi, `prototype/logic.js` — logika manbasi. Butun holat va hodisalar `lib/store.dart` ichida (prototip logikasining Dart porti), har bir ekran `lib/screens/` da prototipdagi ekranga mos.

Ekranlar: Onboarding (Welcome → Telefon → OTP → PIN, davlat kodi tanlash), Hamkorlar (swipe-arxiv, skeleton, qidiruv, cheksiz scroll), Hamkor sahifasi (chat: matn / ovozli xabar / video-doira / tasdiq kodi / operatsiya kartalari + Operatsiyalar tab, flip-rejim, nom tahrirlash, taklif), Yangi operatsiya / Yangi hamkor sheetlari, Dalil + PDF dalil, O'zgartirish so'rovi va uni ko'rib chiqish, Bildirishnomalar, Ikkinchi tomon tasdig'i, Android push demo, Moliya, Xarajat (hisobot + AI chat + ovoz), Profil (tungi rejim, til UZ/RU).

Ma'lumotlar: demo (prototipdagidek). OTP yuborish/tasdiqlash mavjud backend API'ga ham urinadi (`lib/api.dart`), server javob bermasa demo rejimda davom etadi.

**Ovoz → matn (STT, 2 qatlam — XOTIRA-ovoz-va-kategoriya.md):** Xarajat’dagi mikrofon endi real yozadi (`lib/stt.dart`: 16kHz mono wav, maks 10 s, to'lqinni bosib to'xtatiladi) va `POST /api/stt/transcribe` ga yuboradi — backend 1-qatlam **Groq whisper-large-v3**, past ishonch/xatoda 2-qatlam **OpenAI gpt-4o-transcribe**. Natija matni mavjud qoida-parser (`xarParse_`) oqimiga tushadi. Login qilinmagan/kalit yo'q/ruxsat berilmagan holatlarda demo jumlalari va matn kiritish ishlayveradi. Ruxsatlar: Android `RECORD_AUDIO`, iOS `NSMicrophoneUsageDescription` — qo'shilgan.

## Ishga tushirish

Platforma papkalari (`android/`, `ios/`) loyihada tayyor:

```bash
cd mobile
flutter pub get
flutter run
```

Agar platforma fayllarini qayta generatsiya qilish kerak bo'lsa: `flutter create . --org uz.trust --project-name trust_mobile` (mavjud fayllarni saqlaydi). iOS build faqat macOS/Xcode'da.

## API manzili

Standart: `http://localhost:3000`. Production (Render):

```bash
flutter run --dart-define=API_URL=https://trust-backend-ft1s.onrender.com
```

Lokal backend bilan: `--dart-define=API_URL=http://192.168.1.100:3000` (kompyuter IP).

Eslatma: Android emulyatorda kompyuterning localhost'i `http://10.0.2.2:3000` bo'ladi. Haqiqiy telefonda kompyuter bilan bir Wi-Fi'dagi IP manzilni ishlating. HTTP (cleartext) allaqachon yoqilgan: Android manifestda `usesCleartextTraffic="true"`, iOS Info.plist'da `NSAllowsArbitraryLoads` (ishlab chiqarishda HTTPS'ga o'tgach bularni cheklang).

## Tuzilma

- `lib/theme.dart` — dizayn tokenlari (light/dark palitra, prototip bilan 1:1)
- `lib/store.dart` — butun holat + logika (ChangeNotifier), `vals()` prototip placeholderlarini beradi
- `lib/ui.dart` — umumiy vidjetlar (Tx/Inter matn, KeyPad, CodeBoxes, SheetShell, tugmalar, toast)
- `lib/api.dart` — backend chaqiruvlari
- `lib/main.dart` — ekran/overlay kompozitsiyasi (prototipdagi z-tartib)
- `lib/screens/` — 17 ekran
- `prototype/` — asl prototip manbasi (solishtirish uchun)
- `android/`, `ios/` — platforma papkalari (INTERNET ruxsati, cleartext HTTP, ilova nomi «Trust», ikonkalar tayyor)

## Backendga ulash xaritasi

Hozir ma'lumotlar demo. Real API'ga o'tishda `lib/store.dart` dagi quyidagi amallar backend endpointlariga mos keladi (`README.md` ildizda — to'liq API jadvali):

| store.dart | Backend |
|---|---|
| `sendOtpApi` / `verifyOtpApi` (tayyor) | `POST /api/auth/send-otp` · `verify-otp` |
| `S['clients']` yuklash, `npCreate` | `GET/POST /api/partners` |
| `renSave_`, `archive_`/`restore_` | `PATCH /api/partners/:id` |
| `createTx` | `POST /api/operations` |
| `confirmTx` / `confirmSecond` | `POST /api/operations/:id/confirm` |
| `submitEdit` | `POST /api/operations/:id/edit-request` |
| `approveEdit` / `rejectEdit` | `POST .../edit-request/:reqId/resolve` |
| Dalil (`receipt`/`pdf` vals) | `GET /api/operations/:id` |
| `xarEntries`, `limSave_` | `GET/POST /api/expenses` · `GET/PUT /api/limits` |
| `notifs` | `GET /api/notifications` · `POST :id/read` |

Token `verifyOtpApi` da `SharedPreferences('trust_token')` ga saqlanadi — keyingi so'rovlarda `Authorization: Bearer` sifatida `lib/api.dart` `_post(..., token:)` orqali yuboriladi.

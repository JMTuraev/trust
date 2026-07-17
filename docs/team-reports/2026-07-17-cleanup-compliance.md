# 2026-07-17 — TOZALASH / COMPLIANCE sub-sessiyasi

Teammate: CLEANUP/COMPLIANCE. Ikki ish: **(A)** ovoz/STT'ni butunlay olib tashlash,
**(B)** uchinchi tomon AI (Anthropic) uchun maxfiylik/do'kon hujjatlarini yangilash.

Mahsulot qarori (PO, yakuniy): **FAQAT MATN — ovoz, audio, mikrofon yo'q.**
Sabab: odam pul masalasini ovoz chiqarib aytmaydi; qarz/xarajat maxfiy mavzu.
Manba: `docs/ai-character.md` §11.

> **Groq QOLDI** — u `src/services/parse.js` da matn→JSON parsing uchun ishlatiladi.
> Faqat STT (whisper) olib tashlandi. Parsing buzilmadi.

---

## 0. Boshlang'ich holat (muhim)

Sub-sessiya boshlanganda ishning bir qismi **allaqachon bajarilgan** edi (oldingi yurish):
`src/routes/stt.js`, `src/services/stt.js`, `mobile/lib/stt.dart` o'chirilgan; `messages.js`
audio'dan tozalangan; `RECORD_AUDIO` / `NSMicrophoneUsageDescription` / `record` paketi yo'q;
`XOTIRA-ovoz-va-kategoriya.md` annotatsiya qilingan.
Men qolganini tugatdim va **hammasini qayta tekshirdim** (quyidagi grep-dalil).

⚠️ **Eng muhim topilma:** `mobile/lib/store.dart:14` hali ham `import 'stt.dart';` qiladi —
fayl esa **o'chirilgan**. Ya'ni **hozir mobil kompilyatsiya qilinmaydi**. store.dart MOBILE
egaligida → §NEW-PATCHES da aniq patch berdim. **Bu P0 blocker.**

---

## 1. O'chirilgan / o'zgartirilgan fayllar

| Fayl | Amal | Holat |
|---|---|---|
| `src/routes/stt.js` | **O'CHIRILDI** | ✅ (oldingi yurishda) |
| `src/services/stt.js` | **O'CHIRILDI** | ✅ (oldingi yurishda) |
| `mobile/lib/stt.dart` | **O'CHIRILDI** | ✅ (oldingi yurishda) |
| `src/routes/messages.js` | Audio endpointlar olib tashlangan; matn chat butun | ✅ tekshirdim, `node --check` PASS |
| `mobile/lib/screens/xarajat.dart` | Mic/hold-to-talk UI yo'q; matn input butun | ✅ tekshirdim — 0 ta mic/stt referens |
| `mobile/pubspec.yaml` | `record` paketi yo'q | ✅ (`audioplayers` — pastga qarang) |
| `mobile/android/app/src/main/AndroidManifest.xml` | `RECORD_AUDIO` yo'q | ✅ |
| `mobile/ios/Runner/Info.plist` | `NSMicrophoneUsageDescription` yo'q | ✅ |
| `render.yaml` | **`STT_ENABLED` olib tashlandi** (men) | ✅ |
| `docs/privacy-policy.html` | **Qayta yozildi** — AI/uchinchi tomon bo'limi (men) | ✅ |
| `docs/play-store-checklist.md` | **AI compliance bo'limlari** (men) | ✅ |
| `docs/ai-consent-copy.md` | **YANGI** — uz/ru/en rozilik matni (men) | ✅ |
| `XOTIRA-ovoz-va-kategoriya.md` | §1/§2/§5/§6/§7 SUPERSEDED; §3/§4 kuchda | ✅ |

### `render.yaml` — aniq o'zgarish
- ❌ `STT_ENABLED: "true"` — **olib tashlandi** (izohli tarixiy eslatma qoldirildi).
- ✅ `GROQ_API_KEY` — **QOLDI** (izoh tuzatildi: endi "STT+parsing" emas, faqat **parsing**).
- ✅ `ANTHROPIC_API_KEY` — bor, `sync: false`, izohli. **Qiymat yozilmagan** — PO Render
  Dashboard'da kiritadi. (Hard rule: hech qanday sir yozilmadi.)

---

## 2. Ruxsatlar — oldin / keyin

| Platforma | Oldin | Keyin |
|---|---|---|
| Android | `INTERNET`, **`RECORD_AUDIO`** | `INTERNET` **faqat** |
| iOS | `NSMicrophoneUsageDescription` | **yo'q** |
| Flutter paket | `record: ^5.x` (mikrofon) | **yo'q** |

**Natija:** ilova mikrofonga **umuman murojaat qilmaydi**. Moliyaviy ilova uchun bu jiddiy ishonch
yutug'i; Play Data Safety'da butun **Audio** toifasi tushib qoladi (§4).

---

## 3. Grep-dalil

Buyruq: `grep -rniE "\bstt\b|kStt|whisper|transcrib|RECORD_AUDIO|NSMicrophone"`
(chiqarilgan: `node_modules`, `.git`, `build`, `.dart_tool`, `.gradle`, `.kotlin`)

| Fayl | Nima topildi | Baho |
|---|---|---|
| `src/routes/stt.js`, `src/services/stt.js`, `mobile/lib/stt.dart` | **YO'Q (fayl o'chirilgan)** | ✅ |
| `mobile/lib/screens/xarajat.dart` | **0 ta moslik** | ✅ toza |
| `mobile/android/**`, `mobile/ios/**` | **0 ta moslik** | ✅ toza |
| `render.yaml` | faqat men yozgan tarixiy izoh | ✅ ataylab |
| `src/index.js`, `src/config.js`, `src/routes/ai.js`, `src/lib/anthropic.js` | faqat **izohlar** ("olib tashlandi") | ✅ ataylab (BACKEND) |
| `src/config.js:81` + `src/services/parse.js` (9 joy) | `config.stt = {groqKey, openaiKey}` **shim** | ⚠️ ishlaydi — pastga qarang |
| **`mobile/lib/store.dart`** | `import 'stt.dart'` + `Stt.*` + `kSttEnabled` + `sttOn`/`mic*` | 🔴 **P0 — patch berildi** |
| **`mobile/lib/api.dart`** | `transcribe()` + `sendAudio()` — o'lik endpointlar | 🔴 **patch berildi** |
| `mobile/lib/l10n.dart` | `tVoiceFail` (6 til) — patchdan keyin ishlatilmaydi | 🟡 patch berildi |
| `SOZLASH.md`, `mobile/README.md`, `docs/ai-character.md`, `XOTIRA-*.md` | annotatsiyalangan tarix | ✅ ataylab |
| `docs/team-reports/2026-07-16-*.md` | eski hisobotlar | ✅ **tegilmadi** (tarix — o'zgartirilmaydi) |
| `TAVSIYA-texnologiya.md`, `Trust_STT-off.html` | tarixiy hujjat / dizayn fayl nomi | 🟡 zararsiz |
| `.env` (1 izoh qatori) | `# STT + LLM parsing (Groq...)` | ⛔ **TEGILMADI** — hard rule: `.env` ga tegilmaydi. Faqat izoh, kodga ta'siri yo'q. PO xohlasa o'zi tuzatadi. |

### `config.stt` shim haqida
`src/config.js:77-81` — BACKEND **ataylab** qoldirgan moslik shimi: `config.stt.groqKey` →
`config.llm.groqKey`. `parse.js` hali eski nom bilan o'qiydi. **Ishlaydi, parsing buzilmagan.**
Bu faqat **kosmetik nom qoldig'i** — `parse.js` ni `config.llm.*` ga o'tkazish keyingi tozalash
uchun (mening ham, BACKEND'ning ham exclusive faylim emas). **Shoshilinch emas.**

---

## 4. JOB B — maxfiylik va do'kon compliance

### 4.1 `docs/privacy-policy.html` (qayta yozildi, uz + en)
- Sana → 2026-07-17.
- **Ovoz/mikrofon qatorlari olib tashlandi**; yuqoriga "ilova mikrofondan foydalanmaydi" bloki.
- **Yangi §3 «Trust AI va uchinchi tomon (Anthropic)»:**
  - **Nima yuboriladi:** agregat moliyaviy xulosa + xabar matni + suhbatning oxirgi bir necha xabari.
  - **Nima yuborilmaydi:** **haqiqiy ismlar** (→ `HAMKOR_1`), **xom yozuvlar**, telefon raqami, token/OTP.
  - Kimga: **Anthropic PBC (AQSH)**, `claude-opus-4-8`.
  - Rozilik: birinchi foydalanishda, rad etish yo'li bilan.
  - Saqlash + nazorat: tarix Supabase'da; hisob o'chirilsa AI tarixi ham o'chadi; alohida so'rov mumkin.
  - Flag tugmasi + "moliyaviy maslahatchi emas".
- Sharing jadvaliga **Anthropic** qo'shildi; Groq/OpenAI **"matn tahlili"** ga o'zgartirildi (whisper emas).
- §5 chegaradan tashqari uzatish; biometrik/genetik ma'lumot yig'ilmasligi aniq yozildi.

**Pseudonymizatsiya — TEKSHIRILDI (taxmin emas):** `src/services/ai-context.js`
(`pseudonymizeText`, `HAMKOR_${++n}`, `restoreBlocks`) va `src/routes/ai.js:145-155` —
kontekst ham, foydalanuvchi xabari ham serverda almashtiriladi. Hujjatdagi da'vo **kodga mos**.

### 4.2 `docs/play-store-checklist.md`
- Data Safety jadvalidan **Ovoz yozuvi qatori olib tashlandi** + "Audio toifasini BELGILAMANG" eslatmasi
  (soddalashtirish aniq ko'rsatilgan).
- Moliyaviy ma'lumot **Shared = YES (Anthropic)**; yangi **Messages (AI chat)** qatori.
- **Yangi §2a — uchinchi tomon AI:** Play **2026-07-15** yangilanishi (User Data talablari
  uchinchi tomon AI'ga ham tatbiq; javobgar — developer), disclosure, consent, limited use.
- **AI-Generated Content:** in-app flag SHART → `POST /api/ai/flag` + `ai_flags` (`013_ai.sql`) +
  `ai_chat.dart` tugmasi (BACKEND+MOBILE bajaryapti).
- **Yangi §2b — Apple:** yosh reytingi so'rovnomasi AI chatbot'ni hisobga olsin (13+/16+/18+) → **18+**.
- §3 IARC: "foydalanuvchilararo aloqa → No" **asoslandi** (AI odam emas; chat `kChatEnabled=false`).
- **Yangi §8 — O'zbekiston qonuni** (pastga qarang).

### 4.3 `docs/ai-consent-copy.md` (yangi)
uz (asosiy) + ru + en; har biri 4 gap, sodda va halol. **Rad etish yo'li majburiy** —
«Hozir emas» → AI o'chiq, ilovaning qolgani to'liq ishlaydi. Roziliqni qaytarib olish yo'li ham.
es/fr/zh uchun hozircha EN fallback (noto'g'ri tarjima qilingan rozilik matni — xavf).

---

## 5. Compliance kamchiliklari + HUQUQSHUNOS SAVOLI

### 🔴 P0 — `ai_messages` hisob o'chirilganda O'CHMAYDI (mos kelmaslik)
**Topildi:** `013_ai.sql` — `ai_messages.user_id ... references profiles(id) **on delete cascade**`.
Lekin `src/routes/profile.js:169` — `DELETE /api/profile/me` **SOFT delete** qiladi
(faqat `profiles.deleted_at` belgilanadi, qator **o'chmaydi**).
→ **Cascade hech qachon ishlamaydi. AI suhbat tarixi hisob "o'chirilgandan" keyin ham qoladi.**

**Nima uchun muhim:** men maxfiylik siyosatiga *"Hisobingizni o'chirsangiz, Trust AI suhbat
tarixingiz ham o'chiriladi"* deb yozdim — bu **Play/Apple talabi** va Data Safety
"Data deletion: YES" javobiga bog'liq. **Hozir bu gap HAQIQAT EMAS.**

> **Siyosat URL'ini e'lon qilishdan OLDIN §NEW-PATCHES P0-B patchi qo'llanilsin,
> AKS HOLDA hujjat noto'g'ri da'vo qiladi** (Data Safety nomuvofiqligi = review'da rad etish sababi).

### ⚠️ Huquqshunos tasdig'i kerak — O'zbekiston (27-mart 2026 o'zgartirishlari)
Tushunishimiz (**yuridik xulosa emas**): qat'iy lokalizatsiya **yumshatildi** — nosezgir shaxsiy
ma'lumot chet elda saqlanishi mumkin, agar qabul qiluvchi davlat **yetarli himoya** bersa YOKI
**SCC/BCR** qo'llansa. **Biometrik/genetik va telekom abonent ma'lumoti — mamlakat ichida.**

Trust holati: ✅ biometrik/genetik yo'q (**mikrofon ham yo'q** — ovoz biometrik deb talqin
qilinishi mumkin edi, endi bu savol tug'ilmaydi); ✅ Anthropic'ga telefon raqami ketmaydi,
ismlar taxallusda. ⚠️ **Ochiq savol: telefon raqami "telekom abonent ma'lumoti"mi?**

**Huquqshunosga (checklist §8 da ham yozilgan):**
1. Telefon raqami (OTP) — telekom abonent ma'lumoti sifatida lokalizatsiya talabiga tushadimi?
   (Hozir Supabase — chet elda.)
2. Agregat moliyaviy + taxalluslangan ma'lumotni AQSH'ga uzatishga SCC/BCR kerakmi?
   Anthropic DPA yetarlimi?
3. Davlat personallashtirish markazi reyestridan ro'yxatdan o'tish kerakmi?

> **Hech qanday muvofiqlik DA'VO QILINMADI** — hujjatlarda "huquqshunos tasdiqlasin" deb belgilandi.

### 🟡 Tekshirilishi kerak (men tarmoqqa chiqa olmayman)
Siyosatda yozdim: *"Anthropic API orqali yuborilgan ma'lumot model o'qitish uchun
ishlatilmaydi (tijorat shartlariga muvofiq)"*. Bu Anthropic tijorat shartlari bo'yicha odatda
to'g'ri, lekin **PO joriy DPA/Commercial Terms'dan tasdiqlasin** — sandboxda tarmoq yo'q.

---

## 6. §NEW-PATCHES — lead qo'llasin (boshqa egalarning fayllari)

> Men bu fayllarga **tegmadim** (MOBILE egaligida). Patchlar aniq old→new.

### 🔴 P0-A — `mobile/lib/store.dart`: o'chirilgan `stt.dart` importi (BUILD BLOCKER)

**A1. Import (satr 14):**
```dart
import 'api.dart';
import 'stt.dart';
import 'secure.dart';
```
→
```dart
import 'api.dart';
import 'secure.dart';
```

**A2. Flag (satr 22-24):**
```dart
// Ovozli kiritish (STT) vaqtincha o'chirilgan — matn-birinchi rejim.
// Qayta yoqish: true qiling (mic UI qaytadi, matn input yo'qoladi).
const bool kSttEnabled = false;
```
→ (butunlay o'chirilsin; 2026-07-17: ovoz qaytmaydi)
```dart
// 2026-07-17: ovoz/STT butunlay olib tashlandi — ilova FAQAT MATN (docs/ai-character.md §11).
```

**A3. Ovoz yozish funksiyalari (satr 1360-1395) — BUTUNLAY O'CHIRILSIN:**
```dart
  // Real ovoz — Telegram/Instagram uslubi: mikrofonni BOSIB USHLAB turganda yozadi,
  // qo'yib yuborganda to'xtaydi va avtomatik chatga chiqadi (alohida ekran/tasdiq yo'q).
  bool _recActive = false;

  Future<void> voiceHoldStart() async {
    ...
  }

  void voiceHoldEnd() {
    if (!_recActive) return;
    Stt.finish(); // STT natijani onDone orqali qaytaradi
  }

  void _voiceDone(String? text) {
    ...
  }
```
→ (hech narsa — blok o'chiriladi). `voiceHoldStart` / `voiceHoldEnd` / `_voiceDone` /
`_recActive` boshqa hech qayerda ishlatilmaydi (tekshirdim).

**A4. `xarPick_` ichidagi `Stt.cancel()` (satr 1400):**
```dart
  Future<void> xarPick_(String txt, {String source = 'text'}) async {
    Stt.cancel();
    set({'voiceStage': 'parsing', 'vText': txt});
```
→
```dart
  Future<void> xarPick_(String txt, {String source = 'text'}) async {
    set({'voiceStage': 'parsing', 'vText': txt});
```

**A5. `vals()` mic kalitlari (satr 2275-2296):**
```dart
      // ---- Mikrofon: bosib ushlab yozish (Telegram/Instagram) ----
      // STT o'chiq bo'lsa (kSttEnabled=false) mic o'rniga matn input ko'rsatiladi.
      'sttOn': kSttEnabled,
      'xarTextVal': S['xarText'] ?? '',
```
→
```dart
      // ---- Matn input (yagona kirish usuli — ovoz yo'q, 2026-07-17) ----
      'xarTextVal': S['xarText'] ?? '',
```
va shu blok oxiridagi **6 ta kalit butunlay o'chirilsin**:
```dart
      'micHoldStart': () => voiceHoldStart(),
      'micHoldEnd': () => voiceHoldEnd(),
      'micRec': S['voiceStage'] == 'rec',        // yozayapti (pulse)
      'micParsing': S['voiceStage'] == 'parsing', // tahlil qilinyapti
      'micHint': S['voiceStage'] == 'rec'
          ? "Tinglayapman… gapiring, qo'yib yuboring"
          : S['voiceStage'] == 'parsing'
              ? 'Tahlil qilinyapti…'
              : "Bosib ushlab gapiring — AI o'zi yozib toifalaydi",
```
→ (hech narsa). **Tekshirdim:** `sttOn` / `micHoldStart` / `micHoldEnd` / `micRec` /
`micParsing` / `micHint` — `mobile/lib/` da store.dart'dan **tashqarida ishlatilmaydi** (o'lik).

> **DIQQAT — `voiceStage` / `vText` O'CHIRILMASIN!** Nomi "voice" bo'lsa ham, ular hozir
> **matn parsing** oqimining holati (`'parsing'` bosqichi, `xarajat.dart` ishlatadi).
> Faqat `'rec'` qiymati o'ladi. Nomni `parseStage` ga o'zgartirish — **kosmetik, keyinroq**
> (alohida commit; hozir tegilmasin).

### 🔴 P0-B — `ai_messages` soft-delete'da o'chirilsin (`src/routes/profile.js`)
`DELETE /api/profile/me` (satr ~169) ichida, `profiles` update'idan keyin:
```js
      .update({ deleted_at: nowIso, updated_at: nowIso })
```
→ shundan keyin qo'shilsin:
```js
    // 2026-07-17: soft-delete'da AI suhbat tarixi HAQIQATAN o'chiriladi.
    // Sabab: on-delete-cascade faqat HARD delete'da ishlaydi, biz esa soft qilamiz.
    // privacy-policy.html §3.4 shuni va'da qiladi — kod bilan mos bo'lishi SHART (Play Data Safety).
    await supabaseAdmin.from('ai_messages').delete().eq('user_id', req.user.id);
    await supabaseAdmin.from('ai_profile').delete().eq('user_id', req.user.id);
```
> `ai_usage` (token/xarajat auditi) **qoldirilsin** — moliyaviy audit yozuvi, shaxsiy suhbat emas.
> `ai_flags` — `message_id` orqali `ai_messages` ga cascade bo'lib o'zi o'chadi.
> **Egasi:** `profile.js` hech kimning exclusive ro'yxatida yo'q → lead hal qilsin.
> **Bu patchsiz maxfiylik siyosati noto'g'ri da'vo qiladi.**

### 🟡 P1 — `mobile/lib/api.dart`: o'lik STT/audio chaqiruvlari
Endpointlar serverdan **o'chirilgan** — bu kod 404 qaytaradi.
- **`sendAudio()`** (satr ~187-210, `/api/messages/:id/audio`) — **butunlay o'chirilsin**.
- **`lastSttError` + `transcribe()`** (satr ~272-307, `/api/stt/transcribe`) — **butunlay o'chirilsin**
  (faylning oxirgi metodi; yopuvchi `}` qolsin).
`transcribe`/`sendAudio` faqat o'chirilgan `stt.dart`/store audio oqimidan chaqirilardi.

### 🟡 P2 — `mobile/lib/l10n.dart`: ishlatilmaydigan kalitlar
P0-A dan keyin `'tVoiceFail'` (6 tilda: 65/414/763/1112/1461/1810-satrlar) **o'lik** → o'chirilsin.
`'tAudioFail'` — **hozircha QOLSIN** (audio ijro P3 patchida o'chsa, keyin o'chadi).

### 🟢 P3 — (ixtiyoriy) chat audio ijrosi + `audioplayers`
`store.dart` da hali chat **ovozli xabar ijrosi** bor: `AudioPlayer _player` (816),
`togglePlayReal` (935-973), `_mapMsg` audio maydonlari (823-827), voice bubble vals (2721, 2749, 2766).
Chat UI `kChatEnabled=false` bilan yopiq → **zarar keltirmaydi**, lekin o'lik kod.
Tozalansa `pubspec.yaml` dan **`audioplayers: ^6.1.0`** ham olib tashlanadi.

> **Shuning uchun `audioplayers` ni pubspec'da QOLDIRDIM** — hozir o'chirsam store.dart
> kompilyatsiya qilinmaydi. Buyruq: "faqat haqiqatan ishlatilmayotganini o'chir".
> `record` (mikrofon paketi) esa **yo'q** ✅ — muhimi shu.
> P3 `client_screen.dart` ga ham tegadi (u hech kimning ro'yxatida yo'q) → alohida rejalashtirilsin.

---

## 7. Tekshiruv (VERIFY)

| Tekshiruv | Natija |
|---|---|
| `node --check src/routes/messages.js` | ✅ **PASS** |
| `render.yaml` — `STT_ENABLED` yo'q, `GROQ_API_KEY` + `ANTHROPIC_API_KEY` bor | ✅ PASS |
| `xarajat.dart` — mic/stt referens | ✅ **0 ta** |
| `mobile/android/**`, `mobile/ios/**` — mic ruxsati | ✅ **0 ta** |
| Pseudonymizatsiya da'vosi kodga mos (`ai-context.js`) | ✅ tekshirildi |
| `.env` ga tegilmadi, sir yozilmadi/chop etilmadi | ✅ |
| git buyruqlari ishlatilmadi | ✅ |

**Sandbox cheklovi:** bu muhitda **flutter/dart yo'q va tarmoq yo'q** →
`flutter analyze` / `flutter test` **men bajara olmadim**.

### Lead bajarishi kerak (tartib bilan)
1. **Avval §NEW-PATCHES P0-A** ni qo'llang (store.dart) — **busiz `flutter analyze` yiqiladi**
   (o'chirilgan `stt.dart` importi).
2. `cd mobile && flutter pub get` — `record` paketi olib tashlangani uchun **majburiy**.
3. `flutter analyze` → `flutter test`.
4. **P0-B** (profile.js) — **siyosat URL'i e'lon qilinishidan oldin**.
5. P1/P2 — o'sha commitda qilinsa yaxshi (o'lik kod).
6. Reviewer diff'ni tasdiqlasin.

---

## 8. Xavflar (risks)

| Xavf | Ta'sir | Yumshatish |
|---|---|---|
| **store.dart `import 'stt.dart'`** — o'chirilgan fayl | 🔴 mobil **umuman qurilmaydi** | P0-A patch (aniq old→new berilgan) |
| **Siyosat "AI tarixi o'chadi" deydi, kod o'chirmaydi** | 🔴 Data Safety nomuvofiqligi → **review rad etadi** | P0-B patch; siyosat URL'i e'londan oldin |
| O'zbekiston qonuni bo'yicha noaniqlik (telefon raqami) | 🟠 yuridik | **Huquqshunos** — checklist §8; muvofiqlik da'vo qilinmadi |
| Anthropic "train qilmaydi" da'vosi tekshirilmagan | 🟡 hujjat aniqligi | PO joriy DPA'dan tasdiqlasin (sandboxda tarmoq yo'q) |
| `config.stt` shim — nom qoldig'i | 🟢 kosmetik, ishlaydi | `parse.js` → `config.llm.*` keyingi tozalash |
| P3 o'lik audio-ijro kodi | 🟢 chat `kChatEnabled=false` bilan yopiq | P3 patch, `audioplayers` bilan birga |
| Eski DB'dagi `kind='audio'` xabarlar | 🟢 `messages.js` ularni **filtrlaydi** | ✅ allaqachon hal |

---

## 9. Qabul qilingan taxminlar (savol berilmadi — buyruq bo'yicha)

1. **`audioplayers` QOLDIRILDI** — store.dart hali ishlatadi (chat ovoz ijrosi). `record`
   (mikrofon) olib tashlangan — ruxsat uchun muhimi shu. P3 da tozalanadi.
2. **`voiceStage`/`vText` saqlandi** — nomi "voice" bo'lsa ham matn parsing holati. Rename = kosmetik.
3. **Maxfiylik siyosati "hisob o'chsa AI tarixi o'chadi" deb yozildi** — bu **majburiyat**;
   P0-B patch bilan haqiqatga aylanadi. Blocker sifatida belgilandi (siyosat URL'idan oldin).
4. **`ai_usage` o'chirilmaydi** hisob o'chganda — moliyaviy/token auditi, shaxsiy suhbat emas.
5. **es/fr/zh rozilik matni = EN fallback** — noto'g'ri tarjima qilingan rozilik yuridik xavf.
6. **Yosh reytingi 18+** — mavjud "Target audience 18+" bilan mos (AI chat uni oshirmaydi).
7. **`.env` va eski `team-reports/*.md` ga tegilmadi** — mos ravishda hard rule va tarix yozuvi.
8. **`profile.js` / `parse.js` / `client_screen.dart`** — mening exclusive faylim emas →
   tahrirlamadim, patch/tavsiya sifatida berdim.

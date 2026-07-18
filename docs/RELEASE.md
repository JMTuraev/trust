# Trust — Play Store reliz paketi (v3.4.0+2)

> Tayyorlangan: 2026-07-18. Bu fayl relizni Google Play Console'ga yuklash uchun
> tayyor barcha materiallarni bir joyga bog'laydi. **Yuklash va "review"ga yuborish —
> Play Console akkaunt amali (foydalanuvchi bajaradi).**

## 1. Imzolangan App Bundle (yuklanadigan artefakt)

- **Fayl:** `mobile/build/app/outputs/bundle/release/app-release.aab` (~16 MB)
- **Imzo:** release kalit (`android/key.properties` + `android/trust-release.jks`) — Play'ga tayyor.
- **ABI:** **arm64-v8a (64-bit)** — ataylab (build.gradle `abiFilters`/`packagingOptions`;
  32-bit "yarim" split crashining oldini oladi). 2019+ qurilmalar. Bu to'g'ri artefakt.
- **Versiya:** versionName `3.4.0`, versionCode `2`.
  ⚠️ **versionCode Play'ga oxirgi yuklangandan KATTA bo'lishi shart** — ilgari yuklangan
  bo'lsa `pubspec.yaml`da bump qiling va qayta quring.
- **Qayta qurish (lokal, Windows):**
  `cd mobile && flutter build appbundle --release --target-platform android-arm64`
  (to'liq `flutter build appbundle` Windows'da 32-bit AOT'da qulaydi — `--target-platform` shart).
- **Toza/takrorlanadigan qurilish:** GitHub Actions — `.github/workflows/android-release.yml`
  (Linux; `v*` teg push'da yoki qo'lda). Sirlar (keystore/parollar) GitHub Secrets'da:
  `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`.

## 2. Do'kon materiallari (bu papkada)

- **Store listing (UZ):** [store-listing.md](store-listing.md) — nom, qisqa/to'liq tavsif, "Yangiliklar".
- **Skrinshotlar:** `store-screenshots/*.png` — 5 ta, 1080×1920 (9:16), toza demo ma'lumot:
  `01-hub`, `02-two-sided`, `03-trust-ai`, `04-expense`, `05-trust`.
  (Generator: `store-screenshots/generator.html`. Xohlasangiz haqiqiy qurilma kadrlari bilan
  almashtiring — lekin real ism/telefon ko'rinmasin.)
- **Ilova ikonkasi:** `mobile/assets/icon/icon.png` (512×512 do'kon ikoni manbasi).

## 3. Compliance / Console formalari

- **Data Safety:** [data-safety.md](data-safety.md) — telefon (OTP), moliyaviy ma'lumot,
  AI'ga uzatiladigan agregat (hamkor ismlari **taxalluslashtirilgan**). Uchinchi-taraf LLM
  (Anthropic; Groq zaxira) sharhlangan.
- **AI-Generated Content (Play 2026):** [ai-content-compliance.md](ai-content-compliance.md) —
  generativ AI, "noto'g'ri javob" flag (`POST /api/ai/flag`), xavfsizlik chegaralari, disclosure.
- **Release-readiness audit:** [release-readiness-audit.md](release-readiness-audit.md) —
  ruxsatlar minimal (INTERNET, mikrofon YO'Q), target API 36, imzo wiring, HTTPS majburiy.
- **Cheklist:** [play-store-checklist.md](play-store-checklist.md), Maxfiylik: [privacy-policy.html](privacy-policy.html).

## 4. Foydalanuvchi bajaradigan qadamlar (Play Console — men qila olmayman)

1. **versionCode** oxirgi yuklangandan kattaligini tasdiqlang (kerak bo'lsa bump + qayta build).
2. `app-release.aab` ni **Internal testing** trekiga yuklang (avval internal — production emas).
3. **Privacy policy**ni ochiq URL'da host qiling (masalan GitHub Pages `/docs`) va App content'ga kiriting.
4. **Data safety**, **Content rating (IARC)**, **Target audience (18+)** formalarini yuqoridagi
   hujjatlar bo'yicha to'ldiring.
5. **App access:** review jamoasiga OTP-login uchun **test telefon raqami + kod olish yo'lini** bering.
6. Store listing matni + skrinshotlarni joylang.
7. **Huquqiy:** O'zbekiston shaxsiy ma'lumotlar qonuni + Anthropic'ga uzatish (DPA/SCC) —
   huquqshunos tasdig'i (checklist §8, hali ochiq).
8. Ichki testda tekshirib, so'ng **production**ga chiqarib, Google review'ga yuboring.

## 5. Reliz-oldi xavfsizlik review'i — topilmalar (2026-07-18, YAGONA MANBA)

Adversarial security + release review o'tkazildi. Toza: sirlar commit qilinmagan,
AI-chat pseudonimizatsiyasi (asosiy yo'l), auth (HS256+aud pin), HTTPS majburiy,
ruxsatlar minimal, AI xavfsizlik chegaralari + flag endpoint.

| # | Topilma | Holat |
|---|---|---|
| H1 | AI psevdonim kesh (ai_profile.tokens) eskirib, yangi/qayta-nomlangan hamkor ismi 6s ichida LLM'ga xom ketishi mumkin edi | ✅ **TUZATILDI** — `invalidateProfile()` endi partner create/rename/archive va link accept/reject'da chaqiriladi (partners.js, links.js) |
| H2 | `/expenses/parse` va `/preview` foydalanuvchi XOM matnini (ichida hamkor ismi bo'lishi mumkin) Groq/OpenAI'ga psevdonimsiz yuboradi — bu AI-chatdan BOSHQA data-oqim | ⚠️ **DISCLOSURE:** privacy-policy + Data Safety'da "pseudonimizatsiya faqat AI-CHAT'ga tegishli; xarajat matni tahlili uchun Groq/OpenAI'ga xom boradi" deb aniq yozilsin. Yoki parse kirishi ham psevdonimlashtirilsin. |
| H3 | Data Safety hujjati AI'ni "consent-gated / opt-in" deb da'vo qiladi, lekin birinchi-kirish CONSENT ekrani hali YO'Q (kodда yo'q) | ⚠️ **BLOCKER:** yuklashdan oldin YOKI consent ekranini qo'shing (`docs/ai-consent-copy.md`) YOKI formada "consent-gated"ni belgilamang. Soxta deklaratsiya = policy buzilishi. |
| H4 | `data-safety.md` (Shared=No) va `ai-content-compliance.md` (Shared=Yes) qarama-qarshi | ⚠️ **BITTA javob tanlang:** Anthropic/Groq/OpenAI bilan imzolangan DPA/processor shartlari BO'LSA → "service provider, Shared=No"; BO'LMASA → **"Shared=Yes (third-party AI)"**. Huquqshunos hal qilsin, ikkala hujjat + privacy-policy bir xil bo'lsin. Ehtiyot uchun default: **Shared=Yes**. |
| M5 | Obuna: 7-kun sinovdan keyin Play Billing YO'Q (verify 501), barcha yozuv (xarajat/qarz/AI) 402'ga tushadi — real foydalanuvchi 8-kuni tugab qoladi. Google review sinovда o'tadi. | ⚠️ **MAHSULOT QARORI:** ishga tushirishdan oldin Play Billing ulang YOKI billing bo'lguncha yozuv/AI'ni bepul qiling (`requireActiveSub` olib turing). |
| M6 | versionCode=2 — Play'ga oxirgi yuklangandan katta bo'lsin | ⚠️ Console'da tekshiring, kerak bo'lsa bump |
| M7 | 3 belgidan qisqa yoki saqlanmagan hamkor ismi psevdonimlashmaydi | ℹ️ privacy-copy'da cheklov sifatida qayd eting |
| L | Ochiq CORS (cookiesiz Bearer API — CSRF yo'q), `.env.example`da real supabase ref (public id) | ℹ️ ixtiyoriy |

> **H2/H3/H4 — yuklash BLOKERI emas (Google review fresh-account'da o'tadi), lekin
> Data Safety DEKLARATSIYASINI to'g'ri to'ldirish uchun hal qilinishi SHART** (noto'g'ri
> Data Safety = Play policy buzilishi, keyinchalik ilova o'chirilishi mumkin).

## 6. Ochiq savollar (PO qarori)

Har hujjatning oxirida "Ochiq savollar" bo'limi bor — asosiylari: obuna/narx wording
(to'lov hali ulanmagan — M5), qaysi tillar/mamlakatlar yoqiladi, huquqiy tasdiq.

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

## 5. Ochiq savollar (PO qarori)

Har hujjatning oxirida "Ochiq savollar" bo'limi bor — asosiylari: obuna/narx w'ording
(to'lov hali ulanmagan), qaysi tillar/mamlakatlar yoqiladi, huquqiy tasdiq. Yuklashdan
oldin ularni ko'rib chiqing.

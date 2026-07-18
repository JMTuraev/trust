# Play Store Release-Readiness Audit — Android (uz.trust.trust_mobile)

> Manba: Trust Play Store reliz tayyorlash (2026-07-18), kodga asoslangan.

## Play Store chiqarishga tayyorlik auditi — Android build

Tekshirilgan manbalar: `mobile/android/app/src/main/AndroidManifest.xml`, `mobile/android/app/build.gradle`, `mobile/pubspec.yaml`, `mobile/android/gradle.properties`, `mobile/android/app/src/main/res/xml/network_security_config.xml`, `docs/play-store-checklist.md`, `docs/privacy-policy.html`, va **haqiqiy qurilgan packaged manifest** (`build/app/intermediates/packaged_manifests/release/...`). Flutter 3.38.9 (stable) SDK default'lari `FlutterExtension.kt` dan o'qildi.

### Checklist (PASS / FAIL / TODO / USER-VERIFY)

| # | Element | Holat | Izoh |
|---|---|---|---|
| 1 | `applicationId` = `uz.trust.trust_mobile` | PASS | `build.gradle` da `namespace` ham `applicationId` ham `uz.trust.trust_mobile`. Packaged manifest shu paketni tasdiqlaydi. |
| 2 | versionName / versionCode | USER-VERIFY (blocker) | `pubspec.yaml`: `version: 3.4.0+2` → versionName=**3.4.0**, versionCode=**2**. versionCode Play'ga oxirgi yuklangandan **KATTA** bo'lishi shart. `2` juda past — agar ilgari internal/closed testga versionCode ≥ 2 yuklangan bo'lsa, upload "Version code 2 has already been used" bilan **rad etiladi**. Yuklashdan oldin tekshiring / bump qiling. |
| 3 | Permissions (merged/packaged manifest) | PASS | Yakuniy manifestda faqat: `INTERNET` + `uz.trust.trust_mobile.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. Ikkinchisi — AndroidX core avtomatik qo'shadigan **signature-level** ichki ruxsat (runtime receiver, Android 13+), foydalanuvchiga ko'rinmaydi, sezgir emas. **`RECORD_AUDIO` yo'q. Media/storage ruxsati yo'q.** `image_picker` (Android Photo Picker) va `audioplayers` (faqat playback) manifest merge orqali hech qanday sezgir ruxsat qo'shmagan. Minimal va toza. |
| 4 | targetSdk / compileSdk / minSdk | PASS | `flutter.targetSdkVersion`=**36**, `compileSdkVersion`=**36**, `minSdkVersion`=**24** (Android 7.0). Packaged manifest `targetSdkVersion="36"` ni tasdiqlaydi. Play joriy minimumi (2025-08-31 dan): yangi ilova va yangilanishlar **API 35 (Android 15)** ni target qilishi kerak. **36 > 35 → talab bajarilgan.** |
| 5 | Release signing config | PASS | `android/key.properties` mavjud, `android/trust-release.jks` keystore mavjud, **ikkalasi ham `.gitignore`da** (`key.properties`, `**/*.jks`). `build.gradle` `signingConfigs.release` ni `key.properties` dan o'qiydi va `buildTypes.release` da qo'llaydi (fayl bo'lsa release kalit, bo'lmasa debug). Wiring to'g'ri. Sirlar o'qilmadi. |
| 6 | minifyEnabled / R8 shrinking | TODO (opsional, blocker EMAS) | `build.gradle` da `minifyEnabled` / `shrinkResources` / proguard **umuman yo'q** → default **OFF**. Play buni talab qilmaydi, lekin R8 yoqilsa APK kichrayadi va Dart tashqi Java/Kotlin kodi obfuscatsiya bo'ladi. Xohlasangiz `minifyEnabled true` + `proguard-rules.pro` qo'shing (Flutter uchun odatda kerak emas). |
| 7 | App label | PASS | `android:label="Trust"` (manifest + packaged manifest). |
| 8 | App icon (mipmap) | PASS | `@mipmap/ic_launcher` barcha zichliklarda mavjud (mdpi→xxxhdpi PNG). **Adaptive icon** ham bor: `mipmap-anydpi-v26/ic_launcher.xml` (background `@color/ic_launcher_background`, foreground inset 16%). Store 512×512 ikoni `assets/icon/icon.png` (14 KB) dan olinadi. |
| 9 | `android:debuggable` | PASS | Release packaged manifestda `android:debuggable="true"` **yo'q** (Flutter release inject qilmaydi). |
| 10 | Network security (bonus, ijobiy) | PASS | `network_security_config.xml`: `base-config cleartextTrafficPermitted="false"` → **production faqat HTTPS**. Cleartext faqat `localhost`/`10.0.2.2`/`127.0.0.1` (dev). `allowBackup="false"` — moliyaviy ilova uchun to'g'ri tanlov. |
| 11 | Privacy policy fayli | TODO (Console blocker) | `docs/privacy-policy.html` mavjud (12.5 KB). Ammo Play uchun **ochiq public URL**da host qilinishi va App content → Privacy policy ga kiritilishi **SHART** (fayl repo'da yetmaydi). Checklist §1: GitHub Pages `/docs` tavsiya etilgan. |
| 12 | arm64-only AAB vs full-ABI / CI | INFO + USER-DECISION | `build.gradle` ataylab `abiFilters 'arm64-v8a'` + `packagingOptions` bilan boshqa barcha ABI native libs'ni chiqarib tashlaydi — bu Windows'dagi 32-bit ARM AOT (`gen_snapshot`) crashini chetlab o'tadi. Natija: **AAB faqat 64-bit qurilmalarga** chiqadi (2019+). Bu Play uchun to'liq yaroqli va lokal `flutter build appbundle --release` bu mashinada ishlaydi. **Universal/full-ABI (armeabi-v7a qo'shilgan) AAB kerak bo'lsagina** — u Windows'da crash beradi, shuning uchun **CI (Codemagic/GitHub Actions) kerak bo'ladi.** Aks holda arm64-only yetarli. |

### Xulosa
Kod tomonidagi Android build **texnik jihatdan chiqarishga tayyor**: paket ID to'g'ri, ruxsatlar minimal (INTERNET, mikrofon yo'q), target API 36 (Play minimumidan yuqori), release signing wiring joyida, ikonka va label bor, debuggable yo'q, HTTPS majburiy. Qolgan blokerlar asosan **Play Console tomonida** (data safety, content rating, app access/OTP test yo'li, store listing assetlari) va **versionCode** hamda **huquqiy tasdiq**da — pastdagi `gaps`ga qarang.

> Eslatma: packaged manifest o'qilgan build oldingi qurilishdan; ammo ruxsatlar to'plami plaginlar + manba manifest bilan aniqlanadi va ular o'zgarmagan, shuning uchun ruxsat tekshiruvi joriy holatga to'g'ri keladi. Yuklashdan oldin **toza `flutter build appbundle --release`** (versionCode bump'dan keyin) qiling.

## Ochiq savollar / PO tasdig'i kerak

- [ ] BLOCKER: versionCode=2 (pubspec 3.4.0+2) — Play'ga oxirgi yuklangandan katta bo'lishi shart; ilgari yuklangan bo'lsa bump qiling (user-verify).
- [ ] BLOCKER (Console): docs/privacy-policy.html ochiq public URL'da host qilinishi va App content → Privacy policy ga kiritilishi kerak.
- [ ] BLOCKER (Console): App access — OTP-login ilova uchun review jamoasiga test telefon raqami + OTP olish yo'li berilishi shart (aks holda 'kira olmadik' rad).
- [ ] BLOCKER (Console): Data safety, Content rating (IARC), Target audience (18+) formalarini to'ldirish — kod bilan tekshirib bo'lmaydi.
- [ ] BLOCKER (huquqiy): Checklist §8 — O'zbekiston shaxsiy ma'lumotlar qonuni bo'yicha huquqshunos yozma tasdig'i (telefon raqami lokalizatsiyasi, Anthropic'ga uzatish SCC/DPA) hali ochiq.
- [ ] MANUAL: AI birinchi foydalanish consent ekrani va AI javob ostidagi flag tugmasi (POST /api/ai/flag) release'dan oldin qo'lda tekshirilsin (checklist §2a).
- [ ] DECISION: arm64-only AAB 64-bit qurilmalarnigina qamraydi; full-ABI (32-bit) kerak bo'lsa CI (Codemagic/GitHub Actions) sozlansin — bu Windows'da lokal build crash beradi.
- [ ] OPSIONAL: minifyEnabled/R8 o'chirilgan — Play blokeri emas, lekin APK hajmi/obfuscatsiya uchun yoqish mumkin.
- [ ] ACTION: versionCode bump'dan keyin toza 'flutter build appbundle --release' bilan yangi imzolangan AAB generatsiya qiling (repo'dagi build tree eski).

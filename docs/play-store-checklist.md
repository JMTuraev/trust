# Trust — Google Play'ga chiqarish yo'riqnomasi

Bu ro'yxat Play Console'da (play.google.com/console) to'ldiriladigan barcha **majburiy** bosqichlarni
qamrab oladi. Kod tomonidagi ishlar tugagan; quyidagilar faqat Console'da bajariladi.

---

## 0. Boshlash (bir martalik)
- [ ] Google Play Developer hisobi ochish — **$25** (bir marta, bir umrga).
- [ ] Yangi ilova yaratish: **Create app** → nomi "Trust", til Uzbek/English, "App", "Free".

---

## 1. App content → Privacy policy  🔴 MAJBURIY
- [ ] `docs/privacy-policy.html` ni **ochiq URL**da joylashtiring (host variantlari pastda).
- [ ] URL'ni **App content → Privacy policy** ga kiriting.

**Host qilishning eng oson yo'li — GitHub Pages (bepul):**
1. GitHub repo → Settings → Pages → Source: `main` branch, `/docs` papka → Save.
2. Bir necha daqiqada URL tayyor: `https://<username>.github.io/<repo>/privacy-policy.html`

---

## 2. App content → Data safety  🔴 MAJBURIY
Quyidagilarni aynan shunday belgilang (ilovaning haqiqiy ma'lumot oqimiga mos):

**Data collection: YES** (ma'lumot yig'iladi va serverga uzatiladi)
**Encrypted in transit: YES** (HTTPS)
**Data deletion: YES** — foydalanuvchi email orqali o'chirishni so'ray oladi.

| Ma'lumot toifasi | Play'dagi joyi | Collected | Shared | Maqsad |
|---|---|---|---|---|
| Telefon raqami | Personal info → Phone number | ✅ | ✅ (SMS provayder) | Account management, App functionality |
| Ism | Personal info → Name | ✅ | ❌ | App functionality |
| Moliyaviy ma'lumot | Financial info → Other financial info | ✅ | ❌ | App functionality |
| Ovoz yozuvi | Audio → Voice or sound recordings | ✅ | ✅ (Groq/OpenAI STT) | App functionality |

> **Muhim:** Data safety'dagi javoblar `privacy-policy.html` bilan mos bo'lishi kerak — nomuvofiqlik review'da rad etiladi.

---

## 3. App content → Content rating (IARC)  🔴 MAJBURIY
- [ ] So'rovnomani to'ldiring. Kategoriya: **Utility / Productivity / Finance**.
- [ ] Savollar (zo'ravonlik, kontent va h.k.) — hammasiga **No/Yo'q**.
- [ ] Foydalanuvchilararo aloqa: ilovada erkin chat/xabar yo'q (faqat hisob-kitob) → **No**.
- [ ] Submit → IARC reytingi avtomatik beriladi.

---

## 4. App content → Target audience
- [ ] Yosh: **18+** (moliyaviy ilova).
- [ ] Bolalar uchun emas.

---

## 5. App access  🔴 (login bor ilova uchun MUHIM)
Ilova telefon + SMS OTP bilan kiradi. Google review jamoasi kira olishi kerak:
- [ ] **All or some functionality is restricted** ni tanlang.
- [ ] Test uchun ko'rsatma bering: test telefon raqami va OTP kodini qanday olish
      (yoki maxsus test hisob). Aks holda review "kira olmadik" deb rad etadi.

> ⚠️ Bu ko'p rad etilishga sabab bo'ladi — OTP'li ilovalar uchun test yo'lini albatta bering.

---

## 6. Main store listing
- [ ] Ilova nomi: **Trust**
- [ ] Qisqa tavsif (80 belgigacha) va to'liq tavsif.
- [ ] **App icon 512×512** — `mobile/assets/icon/icon.png` dan (1024×1024, kerak bo'lsa kichiklashtiring).
- [ ] **Feature graphic 1024×500** (banner).
- [ ] **Screenshotlar** — kamida 2 ta telefon skrini (`phone.png` bor; yana bir nechta oling).

---

## 7. Release → Production
- [ ] `mobile/build/app/outputs/bundle/release/app-release.aab` ni yuklang.
- [ ] Play App Signing: **birinchi yuklashda yoqing** (tavsiya). Bizning kalitimiz = upload key.
- [ ] Release notes yozing.
- [ ] Ko'rib chiqishga yuboring (review odatda 1–7 kun).

---

## Eslatmalar
- **arm64-only .aab**: 64-bit qurilmalarga chiqadi. Juda eski 32-bit telefonlar "nomos" ko'radi
  (crash emas). Zamonaviy qurilmalar (2019+) qamrab olinadi.
- **Play App Signing**: yoqilgach, Google o'z imzo kalitini yaratadi; bizning `trust-release.jks`
  faqat **upload key** bo'lib qoladi. Uni yo'qotmang — kelgusi yangilanishlar shu bilan imzolanadi.

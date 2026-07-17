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
| Moliyaviy ma'lumot | Financial info → Other financial info | ✅ | ✅ (Anthropic — AI tahlili, agregat) | App functionality |
| Xabarlar (AI chat) | Messages → Other in-app messages | ✅ | ✅ (Anthropic) | App functionality |

> ✅ **Ovoz yozuvi qatori OLIB TASHLANDI (2026-07-17).** Ilova endi mikrofonga umuman murojaat
> qilmaydi (`RECORD_AUDIO` / `NSMicrophoneUsageDescription` yo'q, `record` paketi yo'q).
> **Data Safety'da "Audio → Voice or sound recordings" ni BELGILAMANG.** Bu forma va review'ni
> sezilarli soddalashtiradi — moliyaviy ilovada mikrofon so'rovi doim qo'shimcha savol tug'dirardi.

> **Muhim:** Data safety'dagi javoblar `privacy-policy.html` bilan mos bo'lishi kerak — nomuvofiqlik review'da rad etiladi.

---

## 2a. Uchinchi tomon AI (Trust AI / Anthropic)  🔴 MAJBURIY — YANGI (2026-07-17)

Google Play **2026-yil 15-iyul** siyosat yangilanishi: User Data talablari **uchinchi tomon AI
integratsiyalariga ham** to'liq tatbiq etiladi. Model provayderi emas, **biz (developer)** javobgarmiz —
limited use, disclosure va consent bizning zimmamizda.

- [ ] **Data Safety:** yuqoridagi jadvalda Moliyaviy ma'lumot va AI xabarlari **Shared = YES**
      (qabul qiluvchi: Anthropic PBC, `claude-opus-4-8`).
- [ ] **Disclosure:** `privacy-policy.html` §3 «Trust AI va uchinchi tomon (Anthropic)» — nima
      yuboriladi (agregat + xabar matni), nima yuborilmaydi (**haqiqiy ismlar — `HAMKOR_1` taxallusi**,
      xom yozuvlar), saqlash muddati, foydalanuvchi nazorati.
- [ ] **Consent (birinchi foydalanishda):** AI'ni birinchi ochganda aniq rozilik ekrani —
      matn `docs/ai-consent-copy.md` da. Rad etish yo'li bo'lishi SHART; rad etilsa ilovaning
      qolgani to'liq ishlaydi (AI ixtiyoriy).
- [ ] **Limited use:** AI'ga yuborilgan ma'lumot faqat foydalanuvchiga javob berish uchun;
      reklama yoki model o'qitish uchun EMAS. (Anthropic tijorat shartlarini PO tekshirib tasdiqlasin.)

### AI-Generated Content siyosati — in-app flagging  🔴 MAJBURIY
Play'ning AI-Generated Content talabi: nomaqbul AI javobini foydalanuvchi **ilova ichida**
belgilay (flag/report) olishi shart.

- [ ] Har AI javobi ostida **flag tugmasi** bor (mobil: `ai_chat.dart`).
- [ ] Backend: **`POST /api/ai/flag`** shikoyatni qabul qiladi (`ai_flags` jadvali,
      migratsiya `013_ai.sql`).
- [ ] Release'dan oldin **qo'lda tekshiring**: flag bosilganda shikoyat DB'ga tushyaptimi.

---

## 2b. Apple App Store — yosh reytingi (iOS chiqishida)
Apple yosh-reyting so'rovnomasi AI chatbot funksiyasini hisobga olishi kerak (13+/16+/18+ granularlik).

- [ ] So'rovnomada **AI chatbot** bor deb belgilang.
- [ ] Trust uchun tanlov: **18+** — moliyaviy ilova + AI chat (Play'dagi Target audience bilan mos).
- [ ] AI javoblari filtrlanadi (system prompt chegaralari: investitsiya/soliq/huquqiy maslahat yo'q).

---

## 3. App content → Content rating (IARC)  🔴 MAJBURIY
- [ ] So'rovnomani to'ldiring. Kategoriya: **Utility / Productivity / Finance**.
- [ ] Savollar (zo'ravonlik, kontent va h.k.) — hammasiga **No/Yo'q**.
- [ ] **Foydalanuvchilararo aloqa → No.** Trust AI — bu odam emas, model; hamkorlar chati
      `kChatEnabled=false` bilan yopiq. Agar chat kelajakda yoqilsa — bu javob **qayta ko'rilsin**.
- [ ] **AI-generated content bor → Yes** (so'ralsa). Moderatsiya: system prompt chegaralari +
      in-app flag (`POST /api/ai/flag`) — §2a ga qarang.
- [ ] Submit → IARC reytingi avtomatik beriladi.

---

## 4. App content → Target audience
- [ ] Yosh: **18+** (moliyaviy ilova + AI chat).
- [ ] Bolalar uchun emas.
- [ ] `privacy-policy.html` §7 va Apple yosh reytingi (§2b) bilan **mos** bo'lsin.

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

## 8. O'zbekiston — Shaxsiy ma'lumotlar to'g'risidagi qonun  ⚠️ HUQUQSHUNOS TASDIG'I KERAK

> **Bu bo'lim yuridik xulosa EMAS.** Quyidagi tushunish muhandis tomonidan yozilgan va
> **advokat/huquqshunos tomonidan tasdiqlanishi shart** — ayniqsa AI ma'lumotni chet elga
> yuborgani uchun. Play'ga chiqishdan oldin yopilishi kerak.

Holat (2026-yil 27-mart o'zgartirishlaridan keyingi tushunishimiz):
- Qat'iy **lokalizatsiya talabi yumshatildi**: nosezgir (non-sensitive) shaxsiy ma'lumot chet elda
  saqlanishi mumkin — agar qabul qiluvchi davlat **yetarli himoya** darajasini ta'minlasa
  YOKI **standart shartnoma bandlari (SCC)** / **majburiy korporativ qoidalar (BCR)** qo'llansa.
- **Mamlakat ichida qolishi shart:** biometrik va genetik ma'lumot, telekom abonent ma'lumotlari.

Trust uchun amaliy holat:
- ✅ Ilova **biometrik/genetik ma'lumot yig'maydi** (mikrofon ham yo'q — ovoz biometrik deb
  talqin qilinishi mumkin edi, endi bu savol umuman tug'ilmaydi).
- ⚠️ **Telefon raqami** yig'iladi. U "telekom abonent ma'lumoti"ga kiradimi yoki yo'qmi —
  **huquqshunos aytsin**. Raqam Supabase (chet el) da saqlanadi. Bu eng katta noaniqlik.
- ✅ Anthropic'ga **telefon raqami YUBORILMAYDI**; kontragent ismlari **taxallusda** (`HAMKOR_1`).
  Ya'ni AI oqimidagi ma'lumot deyarli identifikatsiyalanmagan.

**Huquqshunosga beriladigan savollar:**
1. Telefon raqami (OTP autentifikatsiya uchun) — telekom abonent ma'lumoti sifatida
   lokalizatsiya talabiga tushadimi?
2. Agregat moliyaviy ma'lumot + taxalluslangan ismlarni AQSH'ga (Anthropic) uzatish uchun
   SCC/BCR kerakmi; Anthropic DPA yetarlimi?
3. Ro'yxatdan o'tish (Davlat personallashtirish markazi reyestri) talab qilinadimi?

- [ ] Huquqshunos yozma tasdig'i olindi.
- [ ] Kerak bo'lsa: Anthropic bilan DPA/SCC imzolandi.

---

## Eslatmalar
- **arm64-only .aab**: 64-bit qurilmalarga chiqadi. Juda eski 32-bit telefonlar "nomos" ko'radi
  (crash emas). Zamonaviy qurilmalar (2019+) qamrab olinadi.
- **Play App Signing**: yoqilgach, Google o'z imzo kalitini yaratadi; bizning `trust-release.jks`
  faqat **upload key** bo'lib qoladi. Uni yo'qotmang — kelgusi yangilanishlar shu bilan imzolanadi.

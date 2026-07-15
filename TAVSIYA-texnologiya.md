# TAVSIYA: Matn-birinchi Xarajat AI uchun texnologiyalar

> 2026-07-15. "Xarajatlar Trust" yangi dizayni (AI matn input, papkalar, kirim/chiqim, papka ichi xronologiya)
> asosida joriy stack baholandi. Qisqa xulosa: **stack almashtirilmaydi** — Flutter + Node/Express (Render) +
> Supabase + Groq allaqachon zamonaviy va yangi dizaynga 90% tayyor. Quyida faqat kuchaytirishlar.

## 1. Xulosa (bir qarashda)

| Qatlam | Hozir | Tavsiya |
|---|---|---|
| Mobil | Flutter | Qoladi. Optimistik UI + uchish animatsiyalari qo'shiladi |
| API | Node/Express, Render starter (Frankfurt) | Qoladi — 1000+ user'gacha yetadi |
| Baza/Auth | Supabase (Postgres) + devsms OTP | Qoladi. Realtime va pgvector'ni keyin yoqamiz |
| AI parsing | Groq llama-3.3-70b → OpenAI 4o-mini → qoida | Model va zanjir yangilanadi (2-bo'lim) — tezroq va $0 |
| STT | Groq whisper → OpenAI | VAQTINCHA O'CHIQ (STT_ENABLED flag). Kod turibdi |

## 2. AI qatlami — "yashin tezligi" va $0 uchun

Zanjir (hammasi bepul tierda):

1. **Groq `llama-3.1-8b-instant`** — asosiy parser. Bepul tierda eng saxiy model: ~14 400 so'rov/kun,
   560–840 token/s (70b'dan 2–3 barobar tez). Bizning prompt kichik — oddiy "taksiga 25 ming" uchun 8B yetarli.
2. **Eskalatsiya**: ishonch < 0.8 yoki ko'p-amalli murakkab gap → `llama-3.3-70b-versatile` (1 000/kun)
   yoki `openai/gpt-oss-120b` — bunda Groq'ning **strict json_schema** rejimi bor: JSON 100% sxemaga mos,
   `sanitizeAction` dagi himoyalar soddalashadi.
3. **Bepul zaxira: Google Gemini 2.5 Flash** (1 500 so'rov/kun, 15/min, karta talab qilmaydi) —
   hozirgi pullik OpenAI zaxirasining OLDIGA qo'yiladi. OpenAI ixtiyoriy 4-qatlamga tushadi.
4. Qoida-parser (bor) — oxirgi tayanch, o'zgarmaydi.

Kodda bu faqat `config.llm` + `parse.js` dagi zanjirga 1 provayder qo'shish. Kutiladigan natija:
odatiy javob < 1 soniya (hozirgi 7s timeout o'rniga), oy davomida LLM xarajati — 0 so'm.

**"Yashin" hissi serverda emas, UI'da yasaladi:**
- Yozish paytidagi jonli highlight (summa/toifa ranglanishi) — faqat lokal regex, serverga so'rov YO'Q.
- Enter bosilganda darhol lokal `ruleParse` natijasi bilan karta/bubble ko'rsatiladi (skelet),
  ~0.5–1s da AI natijasi kelib jimgina almashtiradi. Foydalanuvchi kutishni sezmaydi.
- Flutter'da papkaga "uchish" — `Hero` yoki `AnimatedPositioned` + spring curve; server bilan bog'liq emas.

## 3. Yangi dizayn talab qiladigan backend qo'shimchalari (kichik)

1. **Kirim (daromad) toifalari** — dizaynda kirim papkalari alohida turadi (Oylik, Biznes, Boshqa kirim).
   Migratsiya 007: `categories.kind` ustuni (`chiqim` default | `kirim`) + 3 seed. LLM promptiga kirim
   ro'yxati qo'shiladi (hozir category='Daromad' qotirilgan).
2. **Papka ichi (xronologiya)** — `GET /api/expenses` ga bitta qator:
   `if (req.query.category) q = q.eq('category', req.query.category)`. Kunlik guruhlash mobil tomonda.
3. **Sparkline/papka summalari** — `GET /api/expenses/summary/month` ga kunlik agregat massivini qo'shish
   (bitta SQL, N+1 yo'q).
4. **Matndan papka boshqaruvi** ("Taksi'ni Transportga birlashtir") — keyingi bosqich:
   parse.js'ga `command` action turi + `POST /api/categories/merge`. UI tasdiq bilan (dizaynda bor).

## 4. Supabase'dan ko'proq foydalanish (bor obunada, bepul)

- **Realtime** — expenses jadvaliga obuna: papka summalari va yangi yozuvlar jonli yangilanadi
  (kelajakda ikki qurilma/oila rejimi uchun ham asos).
- **pgvector** — XOTIRA §4 rejasi o'z kuchida qoladi (k-NN uchinchi signal, "Boshqa"ni klasterlash).
- **pg_cron + Edge Function** — haftalik "Boshqa" tahlili (XOTIRA'da rejalangan).

## 5. Flutter tomonda

- Optimistik render (2-bo'lim) + `flutter_animate` yoki oddiy `AnimationController` bilan spring.
- **Offline navbat** (XOTIRA qoldig'i, matn rejimida ham kerak): yozuv lokalga (sqflite/drift) →
  fon sinxron → muvaffaqiyatda belgilanadi. Render yiqilsa ham yozuv yo'qolmaydi.
- Matn input allaqachon ulandi (kSttEnabled=false rejimi) — `xarPick_` oqimi o'zgarishsiz ishlaydi.

## 6. STT holati (bugungi o'zgarish)

O'chirilgan, kod saqlangan. Qayta yoqish nuqtalari:
- Backend: Render env `STT_ENABLED=true` (render.yaml'da hozir "false"; src/config.js → routes/stt.js 503 qaytaradi).
- Flutter: `lib/store.dart` boshida `kSttEnabled = true` (mic UI qaytadi, matn input yashirinadi).
- Dizayn prototipi: Tweaks panelida `sttEnabled` toggle (Trust.dc.html/Trust.html — yangilangan nusxalar).
LLM parsing STT'ga bog'liq EMAS — GROQ_API_KEY ishlashda davom etadi.

## 7. Narx mo'ljali (1 000 faol user, kuniga ~10 yozuv)

Parsing so'rovlari ~10 000/kun: Groq 8b-instant (14 400/kun bepul) + Gemini zaxira (1 500/kun bepul) —
sig'adi, LLM $0. Render starter ~$7/oy va devsms SMS — asosiy xarajat bo'lib qoladi. STT qaytarilsa
oldingi hisob-kitob (~$55+18/oy) XOTIRA'da turibdi. O'sishda: Groq dev tier (karta) — limitlar 10x.

## Manbalar

- Groq bepul tier limitlari: https://console.groq.com/docs/rate-limits · https://tokenmix.ai/blog/groq-free-tier-limits-2026
- Groq modellar/tezlik: https://console.groq.com/docs/models
- Groq structured outputs (strict json_schema): https://console.groq.com/docs/structured-outputs
- Gemini bepul tier: https://ai.google.dev/gemini-api/docs/rate-limits

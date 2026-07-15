# XOTIRA: Ovozli kiritish va kategoriyalash — qabul qilingan qarorlar

> 2026-07-14. Claude bilan maslahat xulosasi. Xarajat (ovoz → matn → tahlil) qismiga kelganda shu hujjatga tayanamiz.
> Prototip: https://claude.ai/design/p/1df61b94-2996-4af3-8abe-970664b680b6?file=Trust.dc.html

## 1. Arxitektura tamoyili

Har qatlamning zaxirasi bor — biri xato qilsa/yiqilsa ikkinchisi qo'llab-quvvatlaydi.
Butun backend Supabase ichida (Postgres + Auth + Storage + Edge Functions + Realtime).
Self-hosted model YO'Q — hammasi tayyor API orqali. Mohir AI ishlatilmaydi (qaror).

Oqim: audio (16kHz mono, 3–10 s, VAD bilan avto-to'xtash)
→ Supabase Storage → Edge Function → STT → LLM parsing → tasdiqlash → Postgres.
Kutilgan tezlik: yozuvdan bubble'gacha ~2–2.5 soniya. UX: darhol skelet-bubble ko'rsatiladi.

## 2. STT (audio → matn) — tanlangan texnologiyalar

| Rol | Xizmat | Model | Narx | Link |
|---|---|---|---|---|
| ASOSIY | Groq | whisper-large-v3 | $0.111/soat (~$0.0019/daq) | https://console.groq.com/docs/speech-to-text |
| ZAXIRA | OpenAI | gpt-4o-transcribe | $0.006/daq | https://developers.openai.com/api/docs/pricing |

- Groq bepul tarifi: kuniga 2 000 so'rov — MVP bosqichida STT bepul.
- Groq billing: har so'rov minimum 10 soniya deb hisoblanadi.
- Zaxiraga o'tish sharti: Whisper `avg_logprob` past / matn bo'sh / timeout (~5 s).
- Zaxira sifatida mini emas, to'liq gpt-4o-transcribe (og'ir holatlar — shovqin, sheva — aynan zaxiraga tushadi, kuchli model kerak).
- Ikkalasi ham yiqilsa: audio Storage'da saqlanadi, foydalanuvchiga "qayta ayting yoki yozing", keyin qayta ishlanadi.
- Oxirgi fallback doim bor: matn kiritish maydoni.
- Byudjet mo'ljali: 1 000 faol foydalanuvchi (kuniga 10 yozuv × 6 s) ≈ oyiga ~$55 Groq + ~$18 zaxira.
- STT provayderi almashtiriladigan interfeys orqasida tursin: `transcribe(audio) -> {text, confidence}`.

## 3. Parsing (matn → daromad/xarajat/qarz)

Uch mustaqil signal parallel ishlaydi, natijalar solishtiriladi:
1. LLM (Claude Haiku darajasi) — qat'iy JSON schema:
   `{yo'nalish: daromad|xarajat|qarz_berdim|qarz_oldim|qaytardi, summa, valyuta, kategoriya, izoh, shaxs?, yangi_toifa_taklifi?, ishonch}`
   LLM massiv qaytaradi — bitta gapda bir nechta amal bo'lishi mumkin ("bozorga 200 ming, taksiga 30").
2. Qoida-asosli parser (Edge Function ichida, TS): regex summa ("25 ming"→25000, "5 mln"→5000000), kalit so'zlar (tushdi/keldi→daromad, to'ladim/ketdi→xarajat, qarz berdim/oldim→qarz).
3. Kalit so'z lug'ati + (keyinroq) pgvector k-NN — pastda.

Qoidalar:
- LLM va qoida-parser summasi mos → yuqori ishonch, bubble to'g'ridan-to'g'ri.
- Mos kelmasa yoki ishonch < 0.8 → tasdiqlash kartasi (summa/tomon/kategoriya bosib o'zgartiriladi).
- LLM yiqilsa → qoida-parser natijasi majburiy tasdiq bilan.
- MUHIM: parser qarz iboralarini ("Anvarga 500 ming qarz berdim") Xarajatga emas, Hamkorlar/Oldi-berdi oqimiga yo'naltiradi. Bitta mic — uch natija: daromad, xarajat, qarz. Bu Trust'ning asosiy farqi.

## 4. Kategoriyalash — eng kuchli variant (qabul qilingan)

Baza: 7 toifa (Oziq-ovqat, Transport, Kommunal, Ko'ngilochar, Kiyim, Salomatlik, Boshqa) + foydalanuvchi CRUD (qo'shish/qayta nomlash/arxivlash; o'chirish yo'q — tarix buzilmasin).

Qatlamlar (joriy qilish tartibida):
1. **Kalit so'z lug'ati (o'z-o'zini to'ldiruvchi)** — har tasdiqlangan yozuvdan `so'z → toifa` juftligi saqlanadi (per-user jadval). "Korzinka" bir marta to'g'irlandi → keyingi safar LLM'siz to'g'ri tushadi. Anonimlashtirilgan global lug'at — yangi foydalanuvchi birinchi kunidan foyda oladi.
2. **Ko'p amalli parsing** — LLM massiv qaytaradi (3-bo'limda).
3. **pgvector embedding** — har yozuv izohi vektorda saqlanadi. (a) yangi yozuvga k-NN: "o'xshash 5 eski yozuv qaysi toifada" — uchinchi signal; (b) "Boshqa"ni klasterlash.
4. **Kontekst signallari** — vaqt, summa diapazoni, hafta kuni LLM promptiga qo'shimcha maydon bo'lib boradi.

Yangi toifa yaratish:
- LLM har doim joriy ro'yxat ichidan tanlashga majbur; mos kelmasa `yangi_toifa_taklifi` qaytaradi.
- Yangi toifa JIMGINA yaratilmaydi — tasdiqlash kartasida "Yangi toifa: X — qo'shilsinmi?" (bir bosish). Rad etilsa → "Boshqa".
- Sinonimga qarshi prompt-qoida: "yangi nom mavjudiga ma'nodosh bo'lsa, mavjudini tanla".
- Haftalik tahlil (pg_cron + Edge Function): "Boshqa"dagi yozuvlar klasterlanadi, takror mavzu topilsa taklif: "'Boshqa'da 9 ta kitob/kurs yozuvi — 'Ta'lim' ochaylikmi?"
- Har tuzatish saqlanadi va LLM promptiga few-shot misol bo'lib qaytadi — tizim foydalanuvchiga moslashadi.
- Keyinroq: toifa boshiga alohida oylik limit (Hisobotlar UI'ga tabiiy qo'shiladi).

## 5. Qurish tartibi (roadmap)

1. ✅ Matn kiritish + qoida-parser + tasdiqlash kartasi + toifa CRUD (audio hali yo'q, oqim ishlaydi).
2. ✅ LLM parsing ustiga; qoida-parser validator roliga o'tadi; lug'at + tuzatishlardan o'rganish.
3. ✅ Groq STT + mic UX ("Tinglayapman..." reali); matn kiritish fallback bo'lib qoladi.
4. ⬜ OpenAI zaxira-STT ✅, confidence-marshrutlash ✅, offline navbat ⬜, monitoring (STT xato %, parsing aniqlik %, fallback chastotasi) ⬜. Keyin pgvector ⬜ va kontekst signallari ⬜, "Boshqa"ni haftalik klasterlash (pg_cron) ⬜.

Tamoyil: har bosqichda app to'liq ishlaydi — yangi texnologiya tagida doim tayyor fallback turadi.

## 6. Joriy holat (2026-07-15 — 2-bosqich amalga oshirildi)

Backend:
- `src/services/parse.js` — uch signal orkestri: `parseText(text, userId)`. Groq llama-3.3-70b (JSON mode, massiv, few-shot bilan) → zaxira OpenAI gpt-4o-mini → ikkalasi yiqilsa qoida-parser (majburiy tasdiq). Lug'at (word_map): user x3 og'irlik + global agregat, score>=2 bo'lsa toifani LLM'siz belgilaydi. Validator: matndagi har bir summa LLM natijasida bo'lishi shart, aks holda karta.
- `POST /api/expenses/parse` (saqlamaydi) va `POST /api/expenses/confirm` (saqlaydi + `learnFrom`: word_map hits++, tuzatish bo'lsa corrections'ga few-shot). Qarz `routed` bo'lib qaytadi — expenses'ga yozilmaydi.
- `/api/categories` CRUD (arxivlash, o'chirish yo'q), baza 7 toifa birinchi so'rovda seed.
- Migratsiya: `005_xarajat_ai.sql` (categories, word_map, corrections + expenses.source/confidence/raw_text).

Mobil:
- `xarPick_` endi server parse'ga boradi (lokal `xarParse_` faqat server yiqilganda zaxira).
- Tasdiqlash kartasi (`voiceStage: 'confirm'`, xarajat.dart `_confirmCard`): tomon (X/D chip), summa, toifa chiplari, yangi toifa taklifi "+ Nomi" (bir bosishda `accept_new_category`), qarz qatori "QARZ" belgisi bilan.
- Qarz yo'naltirish `_routeQarz`: hamkor ismdan topilsa — operatsiya oynasi to'ldirilgan holda; topilmasa — yangi hamkor oynasi + `qarzDraft` (hamkor yaratilgach avtomatik davom etadi).

Tasdiqlash kartasi qachon chiqadi: ishonch < 0.8 YOKI summa mos kelmasa YOKI yangi toifa taklifi YOKI qarz. Aks holda bubble to'g'ridan-to'g'ri.

UX qarori (2026-07-15): Xarajat chatida MATN INPUT YO'Q — pastda markazda faqat mikrofon
(inputsiz, ovoz-birinchi). Klaviatura faqat bitta joyda chiqadi: tasdiqlash kartasida
STT matni xato eshitilgan bo'lsa, «matn»ni bosib tahrirlash → qayta tahlil (xcEdit oqimi).
Eski matn-fallback endpointlari o'zgarmagan — faqat UI'dan olib tashlandi.

Keyingi navbat (4-bosqich qoldiqlari): offline navbat, monitoring metrikalar, pgvector k-NN, kontekst signallari, haftalik "Boshqa" klasterlash, toifa boshiga limit.

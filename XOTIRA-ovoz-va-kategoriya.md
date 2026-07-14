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

1. Matn kiritish + qoida-parser + tasdiqlash kartasi + toifa CRUD (audio hali yo'q, oqim ishlaydi).
2. LLM parsing ustiga; qoida-parser validator roliga o'tadi; lug'at + tuzatishlardan o'rganish.
3. Groq STT + mic UX ("Tinglayapman..." reali); matn kiritish fallback bo'lib qoladi.
4. OpenAI zaxira-STT, confidence-marshrutlash, offline navbat, monitoring (STT xato %, parsing aniqlik %, fallback chastotasi). Keyin pgvector va kontekst signallari.

Tamoyil: har bosqichda app to'liq ishlaydi — yangi texnologiya tagida doim tayyor fallback turadi.

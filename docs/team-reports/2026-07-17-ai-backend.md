# Trust AI — backend (2026-07-17)

Ijrochi: AI-BACKEND teammate. Spec: `docs/ai-character.md`. Holat: **kod tayyor, offline tekshirilgan**
(sandboxda tarmoq yo'q — jonli API chaqiruvi qilinmagan).

## 1. Nima qurildi

| Fayl | Roli |
|---|---|
| `src/routes/ai.js` | 3 ta endpoint, limitlar, oqim orkestri |
| `src/services/ai-persona.js` | System prompt (server konstantasi) + kontekst blok shabloni |
| `src/services/ai-context.js` | Agregat kontekst quruvchi + psevdonimlashtirish (ikki tomonlama) |
| `src/lib/anthropic.js` | Anthropic Messages API + prompt caching + tool-use + Groq zaxira |
| `src/services/ai-context.test.js` | Offline unit tekshiruv (19 ta test) — **YANGI** |
| `supabase/migrations/013_ai.sql` | 4 ta jadval + indeks + RLS |
| `src/config.js` | `config.ai` + **STT olib tashlandi** + `ANTHROPIC_API_KEY` startup ogohlantirishi |
| `src/index.js` | `/api/ai` mount + **STT unmount** + versiya 3.3 → **3.4** |
| `package.json` | `"test"` script (SDK **qo'shilmadi** — §12.1) |
| `render.yaml` | AI env kalitlari |

### 1.1 STT olib tashlash (2-passda bajarildi) — **PRODUCTION BUG TUZATILDI**

TOZALASH teammate'i `src/routes/stt.js` ni **o'chirgan**, lekin `index.js` uni hali
`import` qilardi. Natija: **backend umuman ko'tarilmasdi** —

```
Error [ERR_MODULE_NOT_FOUND]: Cannot find module '.../src/routes/stt.js'
                              imported from .../src/index.js
```

Ya'ni repo shu holatda **deploy qilinsa prod butunlay yiqilardi** (health ham javob bermasdi).
Tuzatildi: `index.js` dan import + `app.use('/api/stt', ...)` olib tashlandi;
`config.js` dan `stt` bloki (`STT_ENABLED`) olib tashlandi.

**Kalitlar saqlandi (ataylab):** `GROQ_API_KEY`/`OPENAI_API_KEY` — STT'niki EMAS, LLM'niki
(`parse.js` matn→JSON + Trust AI zaxirasi). `ai-character.md` §11 ham "Groq **parsing uchun
qoladi**" deydi. Shuning uchun ular o'z uyiga — `config.llm.{groqKey,openaiKey}` ga ko'chirildi.

## 2. Endpointlar

| Metod | Yo'l | Obuna | Limit | Javob |
|---|---|---|---|---|
| POST | `/api/ai/chat` | `requireActiveSub` → expired **402 SUB_EXPIRED** | 5/daq (per-user), 40/kun, 400/oy, 20/daq (per-IP) | `201 {success, data:{id, blocks, ...}}` |
| GET | `/api/ai/messages` | **OCHIQ** (read-only model: expired user tarixni ko'radi) | `/api` global 120/daq | `200 {success, data:[...], has_more}` |
| GET | `/api/ai/history` | **= `/messages` sinonimi** (bir xil handler) | bir xil | bir xil |
| POST | `/api/ai/flag` | **OCHIQ** (Play talabi — shikoyat mahsulot emas) | 20/daq | `200 {success, data:{message}}` |

> **Nega ikkita GET yo'li?** Texnik topshiriq `GET /api/ai/history` deydi, mobil (`api.dart:269`)
> esa allaqachon `/api/ai/messages` ga qurilgan. Nomni o'zgartirish MOBIL'ni sindirardi,
> spec'ni tashlab ketish integratsiyada shu bahsni qaytarardi → **ikkalasi ham ishlaydi**
> (`router.get(['/messages','/history'], ...)`). Mobil hech narsa o'zgartirmasin.

## 3. Mobil uchun KONTRAKT (aniq shakllar)

> Diqqat: butun repo `{success, data}` konvensiyasida — bloklar **`data.blocks`** ichida.

### POST /api/ai/chat

```jsonc
// So'rov
{ "message": "Bu oy qanday ketyapman?" }        // 1–1000 belgi

// Javob 201
{ "success": true, "data": {
    "id": "uuid",                                // flag uchun SHU id
    "role": "assistant",
    "provider": "anthropic",                     // anthropic | groq | fallback
    "created_at": "2026-07-17T10:00:00.001Z",
    "blocks": [ /* pastda */ ],
    "limits": { "daily_left": 39, "monthly_left": 399 }
} }
```

Xatolar (hammasi `{success:false, error:"<o'zbekcha>"}`, ba'zilarida `code`):

| Status | code | Mobil nima qiladi |
|---|---|---|
| 400 | — | Xabar bo'sh/uzun |
| 401 | — | Login |
| 402 | `SUB_EXPIRED` | Paywall banneri (mavjud oqim) |
| 429 | `AI_RATE_MINUTE` | Xabarni ko'rsat, input'ni qisqa bloklа |
| 429 | `AI_LIMIT_DAILY` / `AI_LIMIT_MONTHLY` | Xabarni ko'rsat, input'ni o'chir |
| 429 | *(code yo'q)* | IP limiti — umumiy "sekinroq" |
| 503 | `AI_OFF` | AI tab'ini yashir/bo'sh holat |

### GET /api/ai/messages?limit=30&before=\<iso\>

`data` — **yangidan eskiga** (`created_at desc`). Mobil ro'yxatni teskari chizadi.
Sahifalash: eng eski elementning `created_at` ini `before` ga ber. `has_more:true` — yana bor.

```jsonc
{ "success": true, "has_more": false, "data": [
  { "id":"uuid", "role":"assistant", "content":"matn qismi", "blocks":[...], "provider":"anthropic", "created_at":"..." },
  { "id":"uuid", "role":"user", "content":"Bu oy qanday ketyapman?", "blocks":null, "created_at":"..." }
] }
```

### POST /api/ai/flag

```jsonc
{ "message_id": "uuid", "reason": "Raqam noto'g'ri" }   // reason ixtiyoriy, ≤500 belgi
// 200 { "success": true, "data": { "message": "Rahmat — javob ko'rib chiqiladi" } }
// 404 — xabar topilmadi / seniki emas;  400 — role != assistant
```

Takror bosish xato bermaydi (idempotent upsert).

### Blok sxemasi (mobil AYNAN shuni oladi — belgilar allaqachon real qiymatga almashgan)

```jsonc
{ "type":"text",  "text":"Yaxshi ketyapsan — balans +1.8 mln." }

{ "type":"stat",  "label":"Transport", "value":"1.2 mln", "delta":"+25%",
  "tone":"good|warn|bad|neutral" }                       // brend qizil/yashil (theme.dart p.red/p.green)

{ "type":"chart", "kind":"bar|line", "title":"Iyul toifalari",
  "data":[["Oziq-ovqat",2100000],["Transport",1200000]] } // ≤6 nuqta, [string, number]

{ "type":"chips", "items":["Qaysi kunlar?","Mayli, keyin"] }  // ≤4

{ "type":"debt_card", "partner_id":"<REAL uuid>", "name":"Anvar", "amount":2000000,
  "direction":"toMe|fromMe", "days":87, "due_in":null,
  "actions":[{"label":"Eslatma yuborish","action":"remind","confirm":true}] }  // actions BO'SH bo'lishi mumkin

{ "type":"budget_set", "scope":"monthly", "label":"Oylik xarajat chegarasi", "amount":6000000,
  "actions":[{"label":"Chegara qo'yish","action":"set_limit","confirm":true}] }

{ "type":"category_move", "expense_id":"<REAL uuid>", "note":"taksi", "amount":30000,
  "from":"Boshqa", "to":"Transport",
  "actions":[{"label":"Transportga ko'chirish","action":"move_category","confirm":true}] }

{ "type":"progress", "label":"Streak", "value":80, "caption":"4 kundan beri byudjetda" }  // value 0..100
```

### Tugma → mavjud endpoint (AI hech narsani O'ZI bajarmaydi)

| `action` | Mobil chaqiradi | Tana |
|---|---|---|
| `remind` | `POST /api/partners/{partner_id}/remind` | — |
| `set_limit` | `PUT /api/limits` | `{ "monthly_limit": <slider qiymati> }` |
| `move_category` | `PATCH /api/expenses/{expense_id}` | `{ "category": "<to>" }` |

**MUHIM eslatmalar (mobil):**
1. Har `action` da `confirm:true` — foydalanuvchi bosmasdan **hech narsa bajarilmaydi** (§11 oltin qoida).
2. `budget_set` — **UMUMIY OYLIK** chegara, toifa bo'yicha EMAS (`limits` jadvalida toifa chegarasi yo'q).
   Slider default `amount` dan boshlansin, natija `PUT /api/limits` ga to'liq oylik limit sifatida ketadi.
3. `debt_card.actions` bo'sh bo'lishi mumkin (link qabul qilinmagan yoki bu mening qarzim) → kartani tugmasiz chiz.
4. Har AI javobi ostida **flag ikonkasi** shart (Play 2026) → `POST /api/ai/flag` + `data.id`.
5. Bloklar ≤6 ta. Noma'lum `type` kelsa — jimgina tashla (oldinga moslik).
6. Javob **oqim (streaming) EMAS** — 3–8 soniya. "Yozmoqda..." indikatori kerak.

## 4. Kontekst formati + token o'lchovi

`ai-context.js` §7 dagi namunani ayni holda quradi (o'lchangan namuna, `HAMKOR_n` bilan):

```
Joriy oy (iyul): daromad 8 mln, xarajat 6.2 mln, balans +1.8 mln.
O'tgan oy (iyun): daromad 7.5 mln, xarajat 6.6 mln, balans +900k.
Top xarajat toifalari (iyul): Oziq-ovqat 2.1 mln (34%, o'tgan oydan +5%), Transport 1.2 mln (19%, o'tgan oydan +25%), ...
Eng tez o'suvchi: Transport (+25%), asosiy sabab: taksi (12 marta, 480k).
Qarzlar (menga qarzdorlar): HAMKOR_1 2 mln (87 kun), HAMKOR_2 500k (12 kun).
Mening qarzlarim: HAMKOR_3ga 1.5 mln (muddati 5 kun qoldi).
Jamg'arma odati: oxirgi 3 oy o'rtacha +1.2 mln/oy.
Oylik chegara: 6 mln, sarflandi 6.2 mln (103%). Kunlik ~194k.
Streak: 4 kundan beri kunlik byudjetda.
Toifasiz yozuvlar (category_move taklifi uchun): YOZUV_1 "taksi" 30k (12-iyul).
Mavjud toifalar: Oziq-ovqat, Transport, Kommunal, Ko'ngilochar, Kiyim, Salomatlik, Boshqa.
```

**O'lchangan:** 927 belgi ≈ **273 token** (byudjet ~600 — 2x zaxira bor).
Qattiq cheklov: `MAX_SUMMARY_CHARS = 2600`, test bilan qo'riqlanadi.
Kesh: `ai_profile`, TTL `AI_PROFILE_TTL_HOURS` (default 6 soat).

## 5. Psevdonimlashtirish (maxfiylik) — dizayn

**Nega:** hamkor ismi — **uchinchi shaxs** ma'lumoti. U Anthropic'ga ma'lumot yuborishga rozilik
bermagan; ilova disclosure'si faqat foydalanuvchining o'zini qamraydi. Shuning uchun ism modelga
**umuman yuborilmaydi**.

**Qanday:**
1. `ai_profile.tokens` — belgi → real qiymat xaritasi (**faqat bizning DB'da**):
   `{"HAMKOR_1":{"id":"<uuid>","name":"Anvar","to_me":2000000,"days":87,"can_remind":true}, "YOZUV_1":{...}}`
2. **Oldinga:** kontekstda ism o'rniga `HAMKOR_n`; foydalanuvchi **xabari** ham tozalanadi
   (`"Anvarga qachon aytay?"` → `"HAMKOR_1ga qachon aytay?"`). O'zbek affikslari saqlanadi.
3. **Orqaga:** model javobidagi `HAMKOR_n` → real ism, `partner_id`/`expense_id` → real UUID.
4. **Qarzsiz hamkorlar ham xaritada** — summary'ga tushmaydi (token sarflamaydi), lekin
   xabardagi ismini tozalash uchun kerak.
5. Xarajat id'lari `YOZUV_n` — token tejaydi (UUID ≈ 15–20 token) **va** id sizib chiqmaydi.

**Qattiq qoidalar (test bilan qo'riqlangan):**
- `Ali` hamkor bo'lsa `Alisher` **tegilmaydi** (so'z chegarasi + affiks ro'yxati; ism ≥3 belgi).
- To'qilgan belgi (`HAMKOR_9`) → matnda "hamkoring" ga tushadi, kartada esa **blok tashlanadi**.
- Bloklar tiklanmasa xom bloklar **hech qachon ko'rsatilmaydi** (belgi sizib chiqmasin) — iliq matn qaytadi.
- `debt_card` raqamlarini (`amount`, `days`, `name`) **server** xaritadan qo'yadi — model to'qiy olmaydi.
- Tarix DB'da **asl** (real ism) saqlanadi; belgilar faqat model yo'nalishida.

## 6. Keshlash strategiyasi + o'lchangan token matematikasi

System 2 blokka bo'lingan, ikkalasida ham `cache_control:{type:'ephemeral'}`:

| Blok | Nima | O'lcham | Kesh xatti-harakati |
|---|---|---|---|
| 1 | `tools` + `PERSONA` (**100% statik**) | ~1904 token | **Hamma userga umumiy** — trafik bo'lsa doim issiq |
| 2 | Per-user kontekst (ism, sana, agregat) | ~273 token | `ai_profile` TTL ichida bayt-barqaror |

> Shuning uchun `{{ISM}}` personadan **chiqarilgan** va 2-blokka ko'chirilgan: aks holda 1-blok
> har userda boshqacha bo'lib, umumiy kesh butunlay yo'qolardi. Xarakter o'zgarmadi —
> persona modelga "ismni keyingi blokdan ol" deydi.

**Kesh minimumi ~1024 token** — 1-blok 1904 token, ya'ni **sig'adi** (o'lchangan, taxmin emas).

**Xabar narxi** (default tarif $5/$25 per MTok):

| Holat | Hisob | Jami |
|---|---|---|
| Kesh urildi | 2177×$0.5 + 300×$5 + 300×$25 /1M | **~$0.0101** |
| 2-blok yozildi | 1904×$0.5 + 273×$6.25 + 300×$5 + 300×$25 | ~$0.0117 |
| Keshsiz (taqqoslash) | 2177×$5 + 300×$5 + 300×$25 | ~$0.0199 |

→ **Kesh ~49% tejaydi.** Oylik: tipik (40 xabar) **~$0.42** (obunaning 4.7%),
eng faol (400 cap) **~$4.05** (**45%**). Spec $0.0085/xabar degan — biroz optimistik, lekin bir tartibda.
**Xarajatning ~74% i output** — shuning uchun `max_tokens:400` eng katta ikkinchi richag.

## 7. Limitlar

| Limit | Qiymat | Env | Qayerda |
|---|---|---|---|
| Daqiqalik | 5 | `AI_MINUTE_LIMIT` | **per-user**, xotirada |
| Kunlik | 40 | `AI_DAILY_LIMIT` | `ai_usage` dan sanaladi (Toshkent kuni) |
| Oylik | 400 | `AI_MONTHLY_LIMIT` | `ai_usage` dan sanaladi |
| IP | 20/daq | — | `rateLimit` middleware |

- Daqiqalik limit **per-user** (mavjud `rateLimit` IP bo'yicha — bitta Wi-Fi ortidagi 3 kishi
  bir-birining limitini yemasin).
- **Ikkala provayder yiqilsa limit yeyilmaydi**: `provider='fallback'` qatorlari sanoqqa kirmaydi.
- Har chaqiruv `ai_usage` ga yoziladi (model, input/cached/write/output, `cost_usd`) — PO real
  ma'lumot bilan keyin sozlaydi.

## 8. Migratsiya `013_ai.sql`

| Jadval | Mazmuni |
|---|---|
| `ai_messages` | `user_id, role(user\|assistant), content, blocks jsonb, provider, created_at` |
| `ai_usage` | `provider, model, input/cached_input/cache_write/output_tokens, cost_usd(12,6)` |
| `ai_profile` | `user_id PK, summary, tokens jsonb, computed_at` |
| `ai_flags` | `user_id, message_id, reason, unique(user_id,message_id)` |

Indekslar: hammasida `(user_id, created_at desc)` + `ai_flags(message_id)`.
RLS **yoqilgan, policy YO'Q** — faqat `service_role` (012 naqshi). Idempotent (`if not exists`).

## 9. Fallback zanjiri

`Anthropic` → (5xx/429/timeout/bo'sh natija) → `Groq llama-3.3-70b` → iliq o'zbekcha matn.

- `askAI()` **hech qachon tashlamaydi** — chat hech qachon oq ekran ko'rsatmaydi.
- Groq'da tool-use o'rniga JSON rejimi, lekin natija **bir xil** `validateBlocks()` dan o'tadi.
- Xom model JSON'iga hech qachon ishonilmaydi: noto'g'ri blok tashlanadi, butun javob emas.
- Timeout: Anthropic 25s, Groq 12s. Kalit/qiymat **hech qayerda loglanmaydi** (faqat status).

## 10. Tekshiruv

```
node --check  → src/{config,index}.js, routes/ai.js, services/ai-{persona,context}.js,
                lib/anthropic.js, services/ai-context.test.js, services/parse.js  — hammasi OK
npm test      → 19/19 pass (0 fail)
```

**Boot tekshiruvi (yangi — aynan shu buzuq edi):** `index.js` ning HAR BIR route importi
alohida yechildi → **13/13 OK**. (`index.js` ning o'zi import qilinmaydi — u `app.listen`
qiladi va test jarayonini osib qo'yadi.)

**Offline self-test** (repoga KIRMAYDI, `outputs/ai-selftest.mjs`) — soxta ma'lumot bilan
kontekst quruvchi + psevdonimlashtirish **round-trip** isboti, **20/20 ok**. Chiqishi:

```
foydalanuvchi  : Anvarga qachon eslatay? Doniyorga ham 1.5 mln qarzim bor, Shiringa uy sotdim.
modelga ketadi : HAMKOR_1ga qachon eslatay? HAMKOR_2ga ham 1.5 mln qarzim bor, HAMKOR_3ga uy sotdim.
foydalanuvchiga: Anvarga qachon eslatay? Doniyorga ham 1.5 mln qarzim bor, Shiringa uy sotdim.
```

Yurgizish: `REPO=<repo yo'li> node outputs/ai-selftest.mjs`

Qamrov: formatlash (`2.4 mln`/`480k`), `pctDelta`, `monthAgg`, `streakDays`, `aggregateDebts`
(87 kun / 5 kun muddat), `composeContext` (§7 formati + token byudjeti), **maxfiylik**
(kontekstda real ism yo'qligi + qarzsiz hamkor), psevdonim **round-trip**, `Ali≠Alisher`,
affiksli tiklash (`HAMKOR_2ga`→`Doniyorga`), `restoreBlocks` (server majburlashi + to'qilgan
belgi tashlanishi), `validateBlocks`, `alternating`.

> Backend'da test harness yo'q edi — `node --test` (ichki runner, 0 bog'liqlik) ishlatildi.
> `package.json` **menikida** ekan → `"test"` script qo'shildi (avvalgi passda adashib
> "menikida emas" deb yozilgan edi).

⚠️ **`"test": "node --test src/"` — ISHLAMAYDI, tuzoq.** Node 22 da katalog berilsa runner
`src/` dagi **HAMMA** faylni yurgizadi, jumladan `index.js` ni → **server ko'tariladi va
test hech qachon tugamaydi** (CI abadiy osilib qoladi; men aynan shunga tushdim). To'g'ri
shakl — glob, tirnoq bilan (glob'ni shell emas, Node o'zi ochsin → Windows/Linux bir xil):

```json
"test": "node --test \"src/**/*.test.js\""
```

**Ish davomida topilgan va tuzatilgan 5 ta bug** (1–3 birinchi pass, 4–5 ikkinchi pass):
1. **Belgi sizib chiqishi:** `\b` bilan `HAMKOR_2ga` moslikka tushmasdi → foydalanuvchi xom
   belgini ko'rardi. Regex lookbehind'ga o'tkazildi, affiks erkin qoldirildi.
2. **Belgi sizib chiqishi (2):** bloklar tiklanmay hammasi tushib qolsa xom bloklar
   ko'rsatilardi → endi iliq matn (`EMPTY_TEXT`).
3. **Chat butunlay buzilishi:** tarixda ketma-ket ikkita `user` qolsa (oldingi so'rov yarim
   yiqilgan bo'lsa) Anthropic 400 qaytarardi → `alternating()` tarixni normallashtiradi.
4. **PROD BUTUNLAY YIQILARDI (eng jiddiy):** `index.js` o'chirilgan `routes/stt.js` ni import
   qilardi → `ERR_MODULE_NOT_FOUND`, server umuman ko'tarilmasdi. Unmount qilindi (§1.1).
   Bu ikki teammate orasidagi **koordinatsiya teshigi** edi: TOZALASH faylni o'chirdi,
   unmount esa menda — oraliqda repo deploy qilib bo'lmaydigan holatda turdi.
5. **`npm test` osilib qolishi:** yuqoridagi glob tuzog'i (o'zim kiritdim, o'zim topdim).

## 11. PO Render'da qo'shishi kerak bo'lgan env

| Kalit | Qiymat | Izoh |
|---|---|---|
| **`ANTHROPIC_API_KEY`** | *(maxfiy)* | **YAGONA MAJBURIY.** `sync:false` — Dashboard'da qo'lda |
| `AI_MODEL` | `claude-opus-4-8` | ✅ render.yaml da |
| `AI_ENABLED` | `true` | Favqulodda o'chirgich |
| `AI_MAX_TOKENS` | `400` | ✅ |
| `AI_DAILY_LIMIT` / `AI_MONTHLY_LIMIT` / `AI_MINUTE_LIMIT` | `40` / `400` / `5` | ✅ |
| `AI_PROFILE_TTL_HOURS` | `6` | ✅ |
| `AI_PRICE_IN/CACHE_WRITE/CACHE_READ/OUT` | `5` / `6.25` / `0.5` / `25` | ⚠️ **tekshirilsin** — faqat audit uchun |

Qo'lda: **`supabase/migrations/013_ai.sql` ni Supabase SQL Editor'da yurgizish.**
`GROQ_API_KEY` allaqachon bor (zaxira uchun ishlatiladi).

## 12. Taxminlar (qaror qilindi, savol berilmadi)

1. **`@anthropic-ai/sdk` QO'SHILMADI** (topshiriq "qo'sh" degan edi — **ataylab bajarilmadi**,
   topshiriqning o'zi "decide and document; **prefer plain fetch**" deb tanlov bergani uchun).
   Sabab: kod xom `fetch` bilan yozilgan → SDK **ishlatilmaydi**. Ishlatilmaydigan paketni
   `dependencies` ga yozish = sof zarar: `npm install` da qo'shimcha supply-chain yuzasi,
   sandboxda **tekshirib bo'lmaydi** (tarmoq yo'q), va prod'da bootni yiqitish xavfi —
   hech qanday foyda bermay. Butun repo allaqachon xom `fetch` bilan boradi (`parse.js`).
   Anthropic Messages API — oddiy JSON POST; SDK bermaydigan hech narsa kerak emas.
   `lib/anthropic.js` **adapter shaklida** (`askAI()` yagona kirish nuqtasi) — SDK kerak
   bo'lsa bitta fayl ichida almashtiriladi. Lead rozi bo'lmasa — bir qatorlik o'zgarish.
2. **Javob `{success, data}` ichida** — topshiriqda `{blocks:[...]}` deyilgan; repo konvensiyasi
   ustun qo'yildi, bloklar `data.blocks` da. Mobil shunga qursin.
2a. **`GET /api/ai/history`** (spec) va **`/api/ai/messages`** (mobil qurgan) — **ikkalasi ham**
   ishlaydi, bitta handler. Birini tanlash tomonlardan birini sindirardi.
2b. **`src/services/ai-context.test.js` ruxsat ro'yxatimda YO'Q edi** (birinchi passda yaratilgan).
   O'chirmadim: u maxfiylik kafolatlarini (real ism modelga ketmasligi) test bilan **qulflab
   turadi** — o'chirish real qiymat yo'qotish bo'lardi. Lead tasdiqlasin yoki aytsin — olaman.
   Topshiriq "self-test outputs'da, repoga kirmasin" degan → u **alohida** yozildi
   (`outputs/ai-selftest.mjs`, repodan tashqarida).
3. **Foydalanuvchining O'Z ismi modelga boradi** (spec §6 `{{ISM}}` talab qiladi; u ma'lumot
   subyekti va disclosure uni qamraydi). Faqat **birinchi so'z** (ism), familiya emas. Ismi
   bo'lmasa — "do'stim". **Hamkorlar** ismi hech qachon bormaydi.
4. **`budget_set` = umumiy oylik chegara** (toifa bo'yicha emas): `limits` jadvalida faqat
   `monthly_limit` bor. Model bergan `category` **ataylab tashlanadi** — aks holda "Transportga
   800k" taklifi **butun** oylik limitni 800k qilib qo'yardi. Spec §11 dagi `suggest_budget(category, ...)`
   shu sababdan qisqartirildi.
5. **Qarz konteksti faqat UZS** (v1) — kontekst so'mda gapiradi; boshqa valyutali qarzlar
   hisobga olinmaydi.
6. **Vaqt zonasi UTC+5 qattiq yozilgan** (O'zbekistonda DST yo'q) — oy/kun chegaralari mahalliy.
7. **Kesh invalidatsiyasi faqat TTL bo'yicha** (6 soat) — `invalidateProfile()` eksport qilingan,
   lekin uni chaqiradigan route'lar (expenses/debts) **mening fayllarim emas**.
8. **Groq qatorlarida `cost_usd = 0`** (narx jadvali Anthropic'niki; Groq ~10x arzon va sozlash
   nishoni emas) — tokenlari baribir yoziladi.

## 13. Risklar

| # | Risk | Ta'sir | Yumshatish |
|---|---|---|---|
| 1 | **`claude-opus-4-8` model id va tarifi jonli API'da tasdiqlanmagan** (tarmoq yo'q) | id noto'g'ri bo'lsa har chaqiruv 404 → **Groq'ga tushadi** (sifat pasayadi, ilova ishlayveradi) | `AI_MODEL` env bilan — deploysiz tuzatiladi. **Birinchi deploy'da `/api/ai/chat` javobidagi `provider` ni tekshirish shart** |
| 2 | Eng faol user narxi ~$4.05/oy = obunaning **45%** (spec 38% degan) | Marja | `ai_usage` da real o'lchov; `AI_MAX_TOKENS` va `AI_MONTHLY_LIMIT` — ikki richag |
| 3 | Prompt kesh TTL **5 daqiqa** | Trafik past bo'lsa 1-blok ham qayta yoziladi (+14% keshsizga nisbatan) | 1-blok **umumiy** — trafik o'sishi bilan doim issiq bo'ladi |
| 4 | Psevdonim affiks ro'yxati **evristik** | "Usta"/"Aka" kabi umumiy so'z hamkor nomi bo'lsa, xabardagi oddiy so'z ham belgiga aylanishi mumkin (model ma'noni yo'qotadi, **ism sizmaydi** — xato xavfsiz tomonga) | ism ≥3 belgi + so'z chegarasi; kerak bo'lsa ro'yxat kengaytiriladi |
| 5 | Daqiqalik limit **xotirada** (instans bo'yicha) | Render ko'p instansga chiqsa limit ×N | Mavjud `rateLimit` bilan bir xil cheklov; kunlik/oylik limit **DB'da** — u aniq |
| 6 | `ai_profile` 6 soatgacha **eskirgan** bo'lishi mumkin | Yangi xarajatdan keyin AI eski raqam aytishi mumkin | Follow-up: `expenses`/`debts` route'lari `invalidateProfile(userId)` chaqirsin (egasi men emasman) |
| 7 | Streaming yo'q — 3–8s kutish | UX | Mobil "yozmoqda..." indikatori (§3 da yozildi) |
| 8 | Anthropic prompt caching GA deb hisoblandi (beta header yuborilmaydi) | Kesh ishlamasa narx ~2x | Xato bermaydi, faqat qimmatlashadi — `ai_usage.cached_input_tokens=0` bo'lsa darhol ko'rinadi |
| 9 | **`ANTHROPIC_API_KEY` yo'q** (PO qo'shmasa) | **Server NORMAL ko'tariladi** (fail-soft, ataylab): AI **Groq zaxirasida** ishlayveradi — sifat pasayadi, lekin chat tirik. Ikkala kalit ham yo'q bo'lsa `/chat` → `503 AI_OFF`, qolgan ilova (auth/qarz/xarajat) **to'liq ishlaydi** | Startupda aniq **ogohlantirish** (`assertConfig`, qiymat loglanmaydi). **`assertConfig` ni fail-fast qilmadim**: AI — fishka, oldi-berdi yadrosi emas; kalit yo'qligi butun ilovani yiqitmasligi kerak. `ai_usage.provider` da darhol ko'rinadi |

## §NEW-PATCHES — boshqa agent fayllari uchun aniq patchlar

> Bu fayllar mening ruxsat ro'yxatimda YO'Q — tegmadim. Patchlar tayyor, egasi qo'llasin.

### P1. `src/services/parse.js` — `config.stt.*` → `config.llm.*` (PRIORITET: past, lekin qilinsin)

**Kontekst:** `config.stt` bloki o'chirildi (STT mahsulotdan chiqdi). Kalitlar `config.llm`
ga ko'chdi. `parse.js` ni sindirmaslik uchun `config.js` da **vaqtincha alias** qoldirdim:

```js
config.stt = { groqKey: config.llm.groqKey, openaiKey: config.llm.openaiKey };
```

Alias bo'lmasa `parse.js` da `Cannot read properties of undefined` — ya'ni **xarajat parsingi
(asosiy funksiya) yiqilardi**. Quyidagi 8 ta almashtirish qo'llangach, alias (config.js:77–81,
izohi bilan) **o'chirilsin**. Sof kosmetik tozalash — shoshilinch emas, hozir hammasi ishlaydi.

| Qator | old | new |
|---|---|---|
| 172 | `if (hasContext && config.stt.groqKey) {` | `if (hasContext && config.llm.groqKey) {` |
| 175 | `key: config.stt.groqKey, model: config.llm.groqModel, text, amounts, timeoutMs: 3500 });` | `key: config.llm.groqKey, model: config.llm.groqModel, text, amounts, timeoutMs: 3500 });` |
| 179 | `if (hasContext && !kinds && config.stt.openaiKey) {` | `if (hasContext && !kinds && config.llm.openaiKey) {` |
| 182 | `key: config.stt.openaiKey, model: config.llm.openaiModel, text, amounts, timeoutMs: 4500 });` | `key: config.llm.openaiKey, model: config.llm.openaiModel, text, amounts, timeoutMs: 4500 });` |
| 356 | `return !!(config.stt.groqKey \|\| config.stt.openaiKey);` | `return !!(config.llm.groqKey \|\| config.llm.openaiKey);` |
| 372 | `if (config.stt.groqKey) {` | `if (config.llm.groqKey) {` |
| 376 | `key: config.stt.groqKey, model: config.llm.groqModel,` | `key: config.llm.groqKey, model: config.llm.groqModel,` |
| 382 | `if (!actions && config.stt.openaiKey) {` | `if (!actions && config.llm.openaiKey) {` |
| 386 | `key: config.stt.openaiKey, model: config.llm.openaiModel,` | `key: config.llm.openaiKey, model: config.llm.openaiModel,` |

Eng oson: `config.stt.` → `config.llm.` (faqat shu faylda, 8 ta o'rin). Keyin `config.js` dagi
alias qatorini va uning izohini o'chirish. Tekshiruv: `node --check src/services/parse.js`
va `npm test`.

### P2. `render.yaml` (TOZALASH) — `STT_ENABLED` o'chirilsin

`STT_ENABLED` endi kodda **o'qilmaydi** (config.js dan olib tashlandi). `render.yaml` da qolsa
— zararsiz, lekin chalg'ituvchi. `GROQ_API_KEY`/`OPENAI_API_KEY` esa **QOLSIN** (parsing +
AI zaxirasi ularsiz ishlamaydi).

### P3. `src/routes/expenses.js` + `src/routes/debts.js` — kesh invalidatsiyasi (ixtiyoriy, UX)

`ai_profile` TTL 6 soat → yangi xarajatdan keyin AI eski raqam aytishi mumkin. Yozuv
o'zgarganda bir qator:

```js
import { invalidateProfile } from '../services/ai-context.js';
// ... muvaffaqiyatli insert/update/delete dan KEYIN (javobni bloklamasin):
invalidateProfile(req.user.id).catch(() => {});   // fire-and-forget — AI keshi asosiy oqimni buzmasin
```

`invalidateProfile()` allaqachon eksport qilingan va ishlaydi.

## 14. Keyingi qadamlar (mening doiramdan tashqarida)

1. `expenses`/`debts` route'lariga `invalidateProfile(userId)` (risk #6) → **§NEW-PATCHES P3**.
2. ~~`package.json` ga test script~~ → **bajarildi** (glob shakli bilan).
3. §9 "proaktiv insight" push'lari (haftada 1–2) — alohida ish, hozir qurilmadi.
4. Maxfiylik siyosati: "hamkorlar ismi AI provayderga **yuborilmaydi**" — bu **kuchli** disclosure
   gapi, TOZALASH teammate'i uni hujjatga kiritsin.

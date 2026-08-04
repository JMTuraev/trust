# Parse pipeline stress-test — 112 real-uslub kirish, papka routing sifati

Sana: 2026-08-03 · Muallif: qa-tester · Skript: `docs/team-reports/e2e/parse-combos.mjs` · Xom natijalar: `docs/team-reports/e2e/parse-combos-results.json`

## 1. Xulosa (headline)

| Ko'rsatkich | Natija |
|---|---|
| Umumiy (112 case) | **77/112 = 68.8%** — LEKIN bu raqam kvota insidenti bilan ifloslangan, pastga qarang |
| **Groq (LLM) xizmat qilgan 72 case** | **57/72 = 79.2%** |
| Rules-fallback'ga tushgan 40 case | 20/40 = 50.0% (bu parser sifati EMAS — infratuzilma artefakti) |
| Lug'at (word_map) ifloslanishini chiqarib tashlaganda LLM-yo'l bahosi | **~64/72 ≈ 88.9%** (7 ta fail lug'at majburlashi) |
| `amountSpans` sof-funksiya regressiyasi (23 format, NBSP bilan) | **23/23 = 100%** |
| Groq-yo'lda summa aniqligi | 70/72 = 97.2%; 2 ta xato ham validator tomonidan ushlangan (`needs_confirm=true`) |
| Qarz-himoya (qarz so'zisiz "berdim" xarajat qolishi) | 2/2 PASS (rules-fallback'da ham — guard deterministik) |

## 2. Metodika

- Haqiqiy pipeline: `parseText(text, userId)` (`src/services/parse.js`) — LLM (Groq `llama-3.3-70b-versatile`) + qoida-parser + user lug'ati. **OpenAI zaxira kaliti yo'q** — Groq yiqilsa to'g'ridan-to'g'ri rules'ga tushadi.
- Test user: `48c3b085…` (oxirgi expenses yozuvidan, faqat o'qish). Papkalari: baza 7 + `Soliq`, `operatsionka`.
- 112 case, 14 guruh (Toshkent/Farg'ona/Xorazm/Qashqadaryo lahjalari, kirill, rus-aralash, emotsional, typo, ko'p amalli, qarz, daromad-so'zli, yangi-papka, summa formatlari, valyuta). Ketma-ket, 1100 ms oraliq, xatoda 2 marta backoff-retry.
- Hech qanday yozish yo'q: `learnFrom` chaqirilmagan, DB'ga insert/update yo'q.
- O'tish mezoni saxiy: bir nechta papka mantiqan to'g'ri bo'lsa, hammasi qabul; `new_category_suggestion` mavzuga mos bo'lsa qabul; mobil daromad->xarajat konvertini hisobga olib, chin daromad matnlarida `daromad` "qabul-lekin-qayd" deb belgilandi.

## 3. KVOTA INSIDENTI (natijalarni o'qishdan oldin shart)

- Groq kunlik token kvotasi (TPD limit **100 000**) run O'RTASIDA tugadi: birinchi 429 **72-case'da** (~12:30 UTC atrofida, run yakuni 12:37:36 UTC). Xato matni: `Rate limit reached ... on tokens per day (TPD): Limit 100000, Used ~98 7xx`.
- 72-case'dan boshlab (bitta tasodifiy o'tib ketgan 78-case'dan tashqari) hamma case `provider='rules'` bilan yakunlangan — ya'ni **10-qarz (8/9), 11-daromad, 12-yangi-papka, 13-format, 14-valyuta guruhlari LLM'siz o'lchandi**. Bu guruhlarning past ko'rsatkichi parser sifati haqidagi signal EMAS.
- Kvota prod bilan umumiy — bu insidentning o'zi mustaqil topilma: **kunlik 100k TPD real foydalanuvchi oqimi uchun ham xavf** (retry'lar bilan ~70 parse'da tugadi).
- Backend hozirgina lokal ravishda **Anthropic-first (claude-haiku-4-5) + lug'at short-circuit** ga o'tkazildi — bu hisobot ESKI Groq yo'lini tavsiflaydi. **Qayta-run lokal `.env` ga `ANTHROPIC_API_KEY` qo'shilishini kutmoqda**; skript tayyor, o'zgarishsiz qayta ishga tushiriladi. (Diqqat: lug'at short-circuit bo'lsa, §6 dagi ifloslanish YANADA kuchliroq ta'sir qiladi.)

## 4. Guruh bo'yicha jadval (provider kesimida)

| Guruh | Jami | Pass | Groq pass/soni | Rules pass/soni | Izoh |
|---|---|---|---|---|---|
| 1-toshkent | 8 | 8 | 8/8 | — | ideal |
| 2-fargona | 8 | 7 | 7/8 | — | 1 fail = lug'at (bozor→Kiyim) |
| 3-xorazm | 8 | 4 | **4/8** | — | eng zaif lahja (LLM'da ham) |
| 4-qashqadaryo | 8 | 6 | 6/8 | — | 1 fail lug'at (sotib→Kiyim) |
| 5-kirill | 8 | 6 | 6/8 | — | 1 summa xatosi (минг x10), 1 toifa |
| 6-rus-aralash | 8 | 7 | 7/8 | — | мороженое→Ko'ngilochar (chegaraviy) |
| 7-emotsional | 8 | 8 | 8/8 | — | emoji/uf/voy muammo emas |
| 8-typo | 8 | 5 | 5/8 | — | 2 fail lug'at, 1 summa (mng→mln!) |
| 9-kop-amal | 8 | 5 | 5/7 | 0/1 | 2 fail lug'at (bozor, svet) |
| 10-qarz | 9 | 5 | 1/1 | 4/8 | kvota qurboni; himoya 2/2 PASS |
| 11-daromad-soz | 6 | 6 | — | 6/6 | rules'da ham to'g'ri |
| 12-yangi-papka | 9 | 5 | — | 5/9 | **LLM'da SINALMADI** (kvota) |
| 13-format | 9 | 4 | — | 4/9 | fail'lar rules artefakti |
| 14-valyuta | 7 | 1 | — | 1/7 | so'z-summalar LLM'siz imkonsiz |

## 5. Har bir FAIL — kutilgan vs olingan

### 5a. Groq (LLM) yo'lidagi 15 fail — haqiqiy sifat signali

| # | Matn | Kutilgan | Olingan | Sabab-tahlil |
|---|---|---|---|---|
| 9 | bozorga chiqib 80 mingni ishlatvordim | Oziq-ovqat | Kiyim (conf 0.9, silent) | **lug'at: bozor→Kiyim** |
| 17 | ekin dori aldim 60 ming | Boshqa + Dehqonchilik-taklif | Salomatlik (silent) | lug'at: dori→Salomatlik (taklifni ham o'chirgan) |
| 20 | o'g'limga kitob aldim 40 ming | Boshqa + Ta'lim-taklif | Kiyim (silent) | **lug'at: kitob→Kiyim** |
| 21 | gazing pulini tuladim 95 ming | Kommunal | Transport (silent) | LLM: Xorazm "gazing"ni tushunmadi |
| 22 | shipoxonaga barib 50 ming to'ladim | Salomatlik | Transport (silent) | LLM: "shipoxona"(shifoxona)ni tanimadi |
| 25 | mol bozoriga borib 50 ming yo'l kira berdim | Transport | Oziq-ovqat (silent) | LLM: "yo'l kira"ni ilg'amadi |
| 26 | qo'y sotib oldim 2 mln berdim | Boshqa/Chorva | Kiyim (silent) | **lug'at: sotib→Kiyim** |
| 33 | нонга 5 минг кетди | 5 000 | **50 000** | LLM kirill "минг"ni x10 qildi; validator ushladi (needs_confirm) |
| 35 | дорихонага 45 минг кетди | Salomatlik | Oziq-ovqat (silent) | LLM kirill toifalashda zaif |
| 48 | мороженое bolalarga 18 ming | Oziq-ovqat | Ko'ngilochar (silent) | chegaraviy, lekin qayd |
| 59 | svetga 80000som | Kommunal | Transport (silent) | **lug'at: svet→Transport** (Kommunal bilan teng ball, tartib hal qilgan!) |
| 61 | taksga 12 mng ketdi | 12 000 yoki 12 | **1 200 000** | LLM "mng"ni mln deb o'qidi; validator ushladi |
| 63 | bozorga borip 65 min ishlatdim | Oziq-ovqat | Kiyim | **lug'at: bozor→Kiyim** (summa farqi tufayli confirm chiqqan) |
| 65 | bozorga 200 ming taksiga 30 ming berdim | Oziq-ovqat + Transport | **Kiyim** + Transport | **lug'at: bozor→Kiyim** |
| 67 | svetga 80 ming gazga 60 ming to'ladim | Kommunal x2 | Transport x2 | **lug'at: svet→Transport** |

### 5b. Rules-fallback'dagi 20 fail — kvota artefakti (LLM'da qayta sinash shart)

Qisqacha, chunki bular rules-parserning ma'lum cheklovlari: 72 (ko'p amalli — rules faqat 1 action), 75/76/77 (qarz to'g'ri, lekin `person=null` — `personFromText` faqat "Xga" shaklini biladi, "Dilshod ... qaytardi"ni emas), 79 (**"Karimga qarzga 300 ming berdim" rules'da xarajat bo'ldi** — `qarzDirection` regexi `qarzga <summa> berdim` oraliqli shaklni tanimaydi, LLM'da sinalmagan), 90/96/104/107 ("oldim/oylik" tufayli daromad), 92/94/100/102/103/105/106 (rules CAT_RULES'da obed/kofe/чой/ukol/sport so'zlari yo'q → Boshqa), 109–112 (so'z bilan yozilgan summalar — "yarim million", "ikki yuz ming" — rules uchun imkonsiz, actions bo'sh).

## 6. ENG MUHIM TOPILMA: word_map lug'ati zaharlangan va LLM'ni jim bosib qo'yadi

Read-only tekshiruv (`word_map`, user `48c3b085…`): `bozor→Kiyim (hits 1)`, `kitob→Kiyim (1)`, `sotib→Kiyim (1)` — katta ehtimol bitta "bozordan kitob sotib oldim…Kiyim" tasdig'idan hamma so'z o'rganilgan; `svet→Transport (1)` va `svet→Kommunal (1)` — teng ball, g'olibni DB qator tartibi hal qiladi (nodeterminizm!).

Zanjir: `hits=1 × user-vazn 3 = 3 ≥ 2 (bosag'a)` → toifa MAJBURLANADI → `confidence=0.9` ko'tariladi → `new_category_suggestion` o'chiriladi → `needs_confirm=false`. Ya'ni bitta eski tasdiq **LLM to'g'ri topgan toifani jimgina, tasdiq kartasisiz** noto'g'risiga almashtiradi. Groq-yo'ldagi 15 faildan 7 tasi (ehtimol 8) aynan shu. 11 toifa-faildan 10 tasi `needs_confirm=false` bilan o'tib ketgan — foydalanuvchi xatoni ko'rmaydi ham.

Yangi Anthropic-first arxitekturada "dict short-circuit" bo'lsa, bu ifloslanish LLM chaqiruvini umuman chetlab o'tadi — **short-circuit'dan oldin lug'at gigienasi shart.**

## 7. new_category_suggestion sifati

Groq-yo'lda 6 ta taklif kuzatildi: **To'y, Savdo, Remont, Ta'lim, Chorvachilik, Bolalar bog'chasi**. Hammasi 1–2 so'z, bosh harf bilan, prompt uslubiga mos; "Savdo" biroz keng, "Bolalar bog'chasi" yaxshi ("Bog'cha" ham bo'lardi). Sifat: yaxshi. LEKIN maxsus 12-guruh (kurs/sovg'a/parikmaxer/it ovqati…) to'liq kvota oynasiga tushdi — **taklif generatsiyasi asosiy guruhda LLM'da sinalmagan**, qayta-run'da birinchi navbatda tekshirilsin.

## 8. Qarz himoyasi

- "Anvarga 200 ming berdim", "singlimga 100 ming berdim" (qarz so'zisiz) — **ikkalasi ham xarajat bo'lib qoldi (PASS)**, hatto rules-fallback'da ham: `sanitizeAction`dagi `QARZ_SIGNAL` guard deterministik ishlaydi.
- Groq'da sinalgan yagona qarz case ("qo'shnimga 250 ming qarz berib turdim") to'g'ri `qarz_berdim`.
- Rules zaifliklari (LLM'siz): `person` faqat "Xga" shaklidan olinadi; "qarzga <summa> berdim" oraliqli shakli qarz deb tanilmaydi. Bular fallback-rejim sifatini belgilaydi — Groq yiqilganda qarz oqimi ham degradatsiya bo'ladi.

## 9. Summa (amount) xatolari — eng kritik bo'lim

- `amountSpans` regressiyasi: 23/23, shu jumladan NBSP-guruhlangan "400 000", "1 500 000", kirill "минг/тыс/млн", yopishgan "15ming", "5000 kofe"da k-multiplikator emasligi, "12 mng"/"120 ping" buzuq multiplikator emasligi.
- Groq-yo'lda 2/72 summa xatosi, ikkalasi LLM tomonida: "5 минг"→50 000 (x10), "12 mng"→1 200 000 (mln deb o'qidi). **Ikkalasini ham qoida-validator ushlab `needs_confirm=true` qildi** — foydalanuvchiga tasdiq kartasi chiqadi, jim saqlanmaydi. Bu qatlamli dizayn o'zini oqladi.
- So'z bilan summalar ("yarim million", "ikki yuz ming", "besh ming") faqat LLM orqali ishlaydi — fallback'da butunlay yo'qoladi (bo'sh actions).
- Valyuta: "20 baks taksi" rules'da 20 deb saqlanib PASS (xom qiymat qabul mezonida); "10 dollar obed", "100$ kurtka" LLM'da sinalmagan — qayta-run'da UZS konvertatsiya xatti-harakati aniqlansin.

## 10. Tavsiyalar

1. **Lug'at gigienasi (blokerga yaqin):** `hits=1` yozuv toifani majburlamasin (bosag'ani user-hit uchun ≥2 real tasdiqqa ko'taring yoki x3 vaznni olib tashlang); lug'at ustun kelganda `confidence`ni 0.9 ga ko'tarish va taklifni o'chirishni to'xtating; teng balldagi nodeterminizmni (svet: Transport vs Kommunal) barqaror tiebreak bilan hal qiling. Anthropic short-circuit'dan OLDIN shart.
2. **Kvota/fallback:** OPENAI_API_KEY yoki Anthropic kaliti — ikkinchi provayder majburiy; 100k TPD prod uchun yetarli emas, 429'da foydalanuvchi sezmay rules-sifatga tushadi.
3. **Prompt:** Xorazm/kirill misollari qo'shilsin (aldim=oldim, barib=borib, shipoxona=shifoxona, "минг"=ming x1000 — x10 EMAS, "mng"=ming typo — mln EMAS); "yo'l kira", "mol bozori" kabi iboralar uchun 1-2 few-shot.
4. **Rules-parser (fallback sifati):** CAT_RULES'ga obed/tushlik/kofe/чой/somsa (Oziq-ovqat), ukol/shifoxona (Salomatlik) qo'shish arzon g'alaba; `qarzDirection`ga `qarzga\s+\d... berdim` oraliqli shakl; `personFromText`ga "Ism ... qaytardi" shakli.
5. **Qayta-run:** ANTHROPIC_API_KEY kelgach `node docs/team-reports/e2e/parse-combos.mjs` o'zgarishsiz — 10/12/13/14-guruhlar LLM'da birinchi marta real o'lchanadi; natijani shu hisobotga provider=anthropic ustuni bilan qo'shish.

---

# ROUND 2 — yangilangan parser (2026-08-03, 14:02 UTC run)

Sinov obyekti: commit qilinmagan `src/services/parse.js` (Anthropic-first, ko'p-amalli rules-fallback, 3-klass multiplikatorlar 万=×10 000 bilan, 6-til CAT_RULES, sheva shakllari, dict pog'onalari MIN=2/STRONG=6, `rankDictRows` deterministik tiebreak, `(?<!п)обед` guard, zero-amount filtri). Ishga tushirish: `node docs/team-reports/e2e/parse-combos.mjs --round2`. Natijalar JSON'da `round2` kaliti ostida.

## R2.1 Xulosa

| Bo'lim | Natija | Izoh |
|---|---|---|
| Multiplikatorlar (sof `amountSpans`, 16 case) | **16/16 = 100%** | 万=40 000, 千, 百万, mil/mille/millones/millón, thousand, "milk"/"5000 kofe" guardlari, NBSP, kirill — hammasi to'g'ri |
| Fallback-multi (LLM o'chiq, 5 case) | **5/5 = 100%** | data-loss fix ishlaydi: 2/3/5 amal, cap 5 (6-summa to'g'ri tashlanadi), daromad+xarajat aralash, qarz yakka yo'l person bilan |
| Til-qoidalari (LLM o'chiq, 10 case) | **9/10 qat'iy, 10/10 funksional** | yagona "fail" — `taxi 20k` `provider=dict` bilan keldi (STRONG lug'at hit): kategoriya/summa/yo'nalish TO'G'RI, scorer kutgan `rules` provider eskirgan kutish. ru/en/es/fr/zh va bazar/shipoxona/gazing sheva yo'llari ishladi |
| Qo'shimcha sof tekshiruvlar (4 case) | **4/4** | `победа 50k`→Boshqa (обед-guard ishladi), `пообедал на 40к`→Oziq-ovqat (guard oshirib yubormagan), `обед 40 тыс` regressiyasi, zero-amount filtri (`0 som` amal yaratmaydi) |
| LLM guruhlari (3-xorazm, 10-qarz, 12-yangi-papka, 14-valyuta; 33 case) | **RUN=2 (1 pass), SKIPPED-QUOTA=31** | Groq TPD hali ham o'lik (~99.6k/100k, "try again in 10m" — lekin har chaqiruv retry'lari kvotani qayta yeydi). 2 marta urinishdan keyin to'xtatildi, vaqt yoqilmadi |

## R2.2 Deterministik bo'lim tafsiloti

- **Fallback-multi (Round 1'dagi eng katta data-loss xavfi yopilgan):** "bozorga 200 ming taksiga 30 ming berdim" endi LLM'siz ham 2 ta amal (200k Oziq-ovqat + 30k Transport); "nonushta 25k obed 40k kechki 60k" 3 amal; 6-summali matn 5 ga cap'lanadi (yo'qolgan — oxirgi 60k, hujjatlangan xatti-harakat); "oylik keldi 4 mln kreditga 200 ming berdim" → daromad 4 000 000 + xarajat 200 000 (yo'nalishlar lokal kontekstdan); "Anvarga qarz berdim 500 ming" yakka `qarz_berdim` + person=Anvar. Hammasi `needs_confirm=true` bilan — to'g'ri.
- **Til-qoidalari:** обед/аптека (ru), taxi/rent (en), comida/repas (es/fr), 吃饭 5万 (zh), bazar/shipoxona/gazing (Xorazm sheva) — CAT_RULES to'g'ri papkaga yo'naltirdi. `rent 500k` Kommunal'ga tushdi va yo'nalish xarajat bo'ldi (EXP_NOUN `\brent\b`).
- **`taxi 20k` kuzatuvi:** yangi `dict` short-circuit (score≥6) LLM'siz, `needs_confirm=false` bilan to'g'ri natija berdi — token tejash yo'li jonli ishlayapti. Bu Round 1'dagi zahar-lug'at muammosining tuzatilgani bilan mos: STRONG pog'ona (≥6) haqiqiy takrorlangan signalni o'tkazadi, hits=1 zahar yozuvlar (score 3) endi o'ta olmaydi — buni R2-D'dagi "ekin dori aldim" ham tasdiqladi (endi dict majburlamadi; Salomatlik'ni LLM'ning o'zi tanladi).

## R2.3 LLM guruhlari holati

Groq'da faqat 2 case o'tdi, keyin 429 (TPD) qaytdi: "bazarga barib 100 ming savdo etdim" — PASS (promptdagi yangi 8-sheva qoidasi ishlagan ko'rinadi), "ekin dori aldim 60 ming" — FAIL (LLM Salomatlik dedi; dehqonchilik konteksti hali ham promptning zaif joyi). Qolgan 31 case **SKIPPED-QUOTA** deb belgilandi — bu holat parser sifati haqida hech narsa demaydi. Anthropic qayta-run hali ham lokal `.env`'dagi ANTHROPIC_API_KEY'ni kutmoqda.

**TEST-OPS ogohlantirishi kelgusi qayta-run uchun:** `config.llm.anthropicUserDailyMax` default 40 — 112-case run 40-chaqiruvdan keyin `userLlmBudgetOk` tufayli jimgina rules'ga tushadi. Test oldidan `ANTHROPIC_USER_DAILY_MAX` env ko'tarilsin (yoki bir nechta test-user ishlatilsin), aks holda Round 1'dagi kvota-artefakt hikoyasi budjet-artefakt bo'lib qaytadi.

## R2.5 Round 3 holati — BLOKLANGAN (ANTHROPIC_API_KEY topilmadi)

Round 3 (to'liq Anthropic qayta-run) so'raldi, lekin tekshiruv (2026-08-03 ~14:3x UTC, faqat boolean, qiymat chiqarilmagan) shuni ko'rsatdi:

- `D:\trust\.env` — `ANTHROPIC` qatori **0 ta**; fayl oxirgi marta **2026-07-15** da o'zgargan (bugun tegilmagan);
- `process.env.ANTHROPIC_API_KEY` — aniqlanmagan;
- `D:\trust\.env.example` — bugun 18:05 (+05) da yangilangan, 4 ta `ANTHROPIC_*` o'zgaruvchi NOMI hujjatlashtirilgan, qiymatlar bo'sh/default — **sizib chiqish yo'q, lekin haqiqiy kalit ham yo'q**. Ehtimol kalit `.env` o'rniga faqat example-fayl yangilanishi bilan "qo'shildi" deb hisoblangan.

QA `.env`ga tega olmaydi (qattiq qoida). Kalit **foydalanuvchi tomonidan** `D:\trust\.env`ga qo'shilgach, run bitta buyruq (skript tayyor, smoke-test o'tgan; kalitsiz/past-limitli holatda fail-fast guardlar bor):

```
ANTHROPIC_USER_DAILY_MAX=1000 node docs/team-reports/e2e/parse-combos.mjs --round3
```

Rejim tarkibi: 112 case + `пообедал 40000` extra (jami 113; "ekin dori aldim 60 ming" 3-guruhda bor, endi Boshqa+Dehqonchilik kutiladi), 600 ms LLM-throttle (dict/rules'da 150 ms), 429'da 2 retry, provider taqsimoti + dict short-circuit alohida hisob, token/narx yig'indisi (`[llm]` qatorlaridan, $1/$5 MTok Haiku taxmini), Round 1 Groq-72 bilan matn-mos taqqoslash, natija JSON `round3` kalitiga.

---

# ROUND 3 — to'liq Anthropic qayta-run (2026-08-03, 17:21 UTC / 22:21 lokal)

Buyruq: `ANTHROPIC_USER_DAILY_MAX=1000 node docs/team-reports/e2e/parse-combos.mjs --round3`. Provayder: **claude-haiku-4-5** (Anthropic-first + dict short-circuit). 113 case (112 + `пообедал 40000`). Natijalar JSON `round3` kalitida.

Infra qaydi: run o'rtasida lokal mashina Supabase'ga ulanishni ~20 daqiqa yo'qotdi — #34/#35 (`таксига 15 минг тўладим`, `дорихонага 45 минг кетди`) `fetch failed` bo'ldi. Ulanish tiklangach ikkalasi alohida qayta o'tkazildi (ikkalasi PASS, anthropic), summary qayta hisoblandi.

## R3.1 Xulosa

| Ko'rsatkich | Natija |
|---|---|
| **Umumiy aniqlik** | **104/113 = 92.0%** (Round 1 Groq-aralash 68.8% edi) |
| Provider taqsimoti | anthropic 107, **dict 6 (0-token g'alaba, 6/6 pass)**, rules/error **0** — LLM qamrovi 100% |
| **Claude vs Groq (R1'da Groq javob bergan 72 case)** | Groq 57/72 (79.2%) → **Claude 68/72 (94.4%)**; 19 flip: **15 ta G−→R3+**, 4 ta G+→R3− |
| **Xorazm verdikti** | Groq'da 4/8 edi → **Claude'da 8/8** — sheva prompt-qoidasi (8-band) ishladi |
| Qarz guruhi | **9/9** — barcha yo'nalishlar + personlar to'g'ri, jumladan R1'da rules o'tkazib yuborgan "Karimga qarzga 300 ming berdim" (qarz_berdim, person=Karim, conf 0.95) |
| Ferma-case | "ekin dori aldim 60 ming" → **Boshqa + taklif "Dehqonchilik"** — aynan kutilganidek (yangi prompt-bandi + `(?<!ekin )dori` guard) |
| **Real token/narx** | 107 chaqiruv: in=227 596, out=11 188 ≈ **$0.284** ($1/$5 MTok Haiku taxmini) — prognoz ($0.25) bilan mos |

## R3.2 Guruh jadvali (R1-Groq bilan solishtirma)

| Guruh | R3 | R1 (provayder) | Izoh |
|---|---|---|---|
| 1-toshkent | 7/8 | 8/8 (groq) | yangi fail: "muzqaymoq oldim"→daromad |
| 2-fargona | 8/8 | 7/8 (groq) | bozor zahar-lug'ati endi ta'sir qilmaydi |
| 3-xorazm | **8/8** | 4/8 (groq) | sheva qoidasi + STRONG pog'ona |
| 4-qashqadaryo | 7/8 | 6/8 (groq) | yangi fail: "chorvaga yem"→Oziq-ovqat |
| 5-kirill | 8/8 | 6/8 (groq) | "нонга 5 минг" endi 5000 (Groq 50k qilgan edi) |
| 6-rus-aralash | 8/8 | 7/8 (groq) | мороженое endi Oziq-ovqat |
| 7-emotsional | 8/8 | 8/8 (groq) | barqaror |
| 8-typo | 7/8 | 5/8 (groq) | "12 mng" endi to'g'ri; yangi g'alati fail: "obetga"→Transport |
| 9-kop-amal | 7/8 | 5/7 (groq) | svet/gaz endi Kommunal; yangi fail: "futbolka 80 ming oldim"→daromad |
| 10-qarz | **9/9** | 5/9 (kvota) | birinchi to'liq LLM o'lchovi — mukammal |
| 11-daromad-soz | 6/6 | 6/6 (rules) | "oylikdan 50 ming ishlatdim" xarajat bo'ldi ✓ |
| 12-yangi-papka | 7/9 | 5/9 (kvota) | takliflar sifatli; 2 fail quyida |
| 13-format | 8/9 | 4/9 (kvota) | "1,200,000 telefon oldim"→daromad |
| 14-valyuta | 5/7 | 1/7 (kvota) | so'z-summalar ("yarim million", "ikki yuz ming", "besh ming") endi ishlaydi |
| 15-extra | 1/1 | — | "пообедал 40000" → Oziq-ovqat ✓ |

## R3.3 Barcha 9 haqiqiy FAIL

| Matn | Kutilgan | Olingan | Naqsh |
|---|---|---|---|
| bolalarga muzqaymoq oldim 12 ming | xarajat/Oziq-ovqat | **daromad** | "oldim"→daromad |
| singlimga sovg'a oldim 150 ming | xarajat + Sovg'a-taklif | **daromad** | "oldim"→daromad |
| bola kiyimiga 150 ming o'zimga futbolka 80 ming oldim | 2× xarajat/Kiyim | 150k Kiyim ✓ + 80k **daromad** | "oldim"→daromad |
| 1,200,000 telefon oldim | xarajat | **daromad** | "oldim"→daromad |
| bir yarim million divan oldim | xarajat | **daromad** | "oldim"→daromad |
| chorvaga yem oldim 180 ming | Boshqa + Chorva-taklif | Oziq-ovqat | toifa (hayvon yemi ≠ odam ovqati) |
| sport zalga obuna 300 ming | Salomatlik (hint: sport zali) | Ko'ngilochar | **hint to'qnashuvi**: "obunalar" Ko'ngilochar hintida |
| obetga 38 ming ishlatim | Oziq-ovqat | Transport (conf 0.9) | izohsiz sirg'alish (typo "obetga") |
| 100$ ga kurtka oldim | 100 yoki ~1.2–1.6 mln | 425 000 | **USD kursi nomuvofiq**: "10 dollar obed"da 12 000/$ (to'g'ri), bu yerda 4 250/$ |

Dominant naqsh: **"NARSA + oldim" → daromad** (9 faildan 5 tasi). Groq bunda adashmasdi. Xavf: sanitize daromadga category="Daromad" qo'yadi va confidence baland — tasdiq kartasi chiqmaydi; mobil asosiy input direction'ni xarajatga aylantirsa ham, toifa jimgina noto'g'ri ketishi mumkin.

## R3.4 new_category_suggestion sifati (endi to'liq o'lchandi)

7 taklif: **Marosim, Dehqonchilik, Hayvonot, Remont, Bolalar, Go'zallik, To'y** — hammasi 1 so'z, bosh harf, prompt uslubiga mos. "Dehqonchilik" ferma-case uchun ideal; "Hayvonot" ishlaydi, lekin "Chorvachilik" aniqroq bo'lardi; "Bolalar" biroz keng. Umumiy sifat: yaxshi. Dict short-circuit "kursga 500 ming" ni userning mavjud **Talim** papkasiga 0 token bilan yubordi — o'z-o'zini o'rgatish davri yopilganining isboti.

## R3.5 Tavsiyalar (Round 3)

1. **Prompt-band (P1):** "NARSA nomi + oldim/олдим = sotib olish = XARAJAT; daromad faqat PUL kelganini bildirsin (oylik/avans/pul oldim)" — 5 failni yopadi. Muqobil: sanitize'da deterministik guard ("N oldim" + narsa-ot va qarz/pul-so'z yo'q → xarajat).
2. **CAT_HINTS to'qnashuvi:** "obunalar"ni Ko'ngilochar hintidan olib tashlash yoki "sport obunasi Salomatlik" aniqlashtirish.
3. **USD siyosati:** kurs LLM xayoliga qolmasin — "chet valyuta ko'rsang amount'ni XOM qoldir, currency maydoniga yoz" qoidasi + backend kursi. Hozir bir xil matn turida 3x farqli kurs chiqdi.
4. Kuzatuv: "obetga → Transport" tipidagi yakka sirg'alishlar uchun arzon himoya — CAT_RULES'dagi aniq hit (obed) LLM toifasiga zid bo'lsa needs_confirm ko'tarish.

## R2.4 Round 1 tavsiyalariga bog'lanish (Round 2 yakuni)

Round 1'dagi 1-tavsiya (lug'at gigienasi) — bajarilgan va sinovdan o'tdi (STRONG/MIN pog'onalar, deterministik tiebreak, learnFrom'da verified-only + unlearnFrom qo'shilgan — oxirgi ikkisi bu raundda alohida sinalmadi, keyingi raund uchun nomzod). 4-tavsiya (rules-fallback lug'ati) — qisman bajarilgan (obed/такси kabi so'zlar CAT_RULES'da, ko'p-amalli fallback bor); `qarzDirection` "qarzga <summa> berdim" oraliqli shakli va `personFromText` "Ism ... qaytardi" shakli hali ochiq. 2-tavsiya (ikkinchi provayder) — Anthropic-first arxitektura kirdi, kalit kutilmoqda.

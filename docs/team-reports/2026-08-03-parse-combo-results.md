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

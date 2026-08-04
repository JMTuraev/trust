# 2026-08-03 — Xarajat inputi qurilma testi, qizil-rang qoidasi, Claude API o'tkazmasi

Jamoa: lead + flutter-dev + qa-tester + backend-dev + reviewer (2 raund).

## Nima qilindi

1. **Input rangi — har doim qizil** (PO talabi: input faqat xarajat yozadi, daromad o'z panelidan).
   `_HlController`dan kirim/chiqim heuristikasi va server LLM preview qatlami butunlay olib tashlandi
   (~237 qator o'lik kod; endi inputdan hech qanday tarmoq so'rovi ketmaydi). Qurilmada tasdiqlandi.
2. **Qarz — xarajat menyusidan butunlay ajratildi** (PO tanlovi: "faqat ogohlantirish").
   "O'tish" tugmasi va `_routeQarz` navigatsiyasi o'chirildi; endi tugmasiz toast:
   "Qarz uchun Hamkorlar bo'limidan yozing" (6 tilda, `tDebtUsePartners`). Qarz hech qachon
   xarajat sifatida saqlanmaydi (server `routed` qaytaradi — o'zgarmagan). Qurilmada tasdiqlandi.
3. **LLM provayder: Groq → Anthropic Claude** (PO talabi). `parse.js` endi Anthropic-birinchi
   (claude-haiku-4-5, majburiy tool_use JSON), zanjir: anthropic → groq → openai → rules.
   Token-tejash qatlami: lug'at short-circuit (0 token), user-scoped LRU kesh, few-shot 4→2,
   per-user kunlik limit (40), kunlik token kill-switch (300k), usage log.
4. **Lug'at gigienasi**: ikki bosag'a — score>=6 (2 ta user tasdig'i) LLM'ni bosib o'tadi/short-circuit;
   score>=2 faqat rules-fallback'da (needs_confirm bilan). Teng-ball deterministik (score→hits→updated_at,
   to'liq tenglik = hit yo'q). Rules-fallback endi lug'atni ham qo'llaydi (ilgari umuman qo'llamasdi).

## Qurilma testi (SM A576B, prod backend, hisob 99 703 44 44)

| Test | Natija |
|------|--------|
| "somsa yedim 15 ming" | Summa to'g'ri, LEKIN tray'ga tushdi (Groq kvotasi tugagan — pastga q.) |
| "uf taksiga 20k ketti" | ✅ Transport, 20 000 |
| "svetga 80ming tuladim" (typo) | ✅ Kommunal, 80 000 |
| "dorixonadan dori oldim 45000" | Tray → "+ Boshqa nom" bilan Salomatlik yaratildi ("Yangi ✨") |
| "kursga 500 ming toladim" | Tray → Talim papkasi qo'lda yaratildi |
| "Anvarga qarz berdim 500 ming" | ✅ Xarajatga yozilmadi; yangi buildda faqat ogohlantirish |
| Inline o'chirish (⋮ → O'chirish) | ✅ Tasdiq dialogi + undo toast |
| Input rangi (barcha 6 matn) | ✅ Hamma summa qizil (13% fon), "oylik" so'zida ham |

## Asosiy topilmalar

1. **Groq kunlik kvotasi (100k TPD) tugagan edi** — kun bo'yi prod `rules` rejimida ishlagan
   (papka aniqlash zaif: somsa/dori → Boshqa, ✨ taklif yo'q). QA'ning 112-case testi ham kvotani
   yeyishga hissa qo'shdi. Yechim: Claude API + kill-switch (endi bunday jim o'lim bo'lmaydi).
2. **word_map zaharlanishi**: bitta eski tasdiq (hits=1) `bozor→Kiyim`, `svet→Transport` kabi
   xato mapping bilan LLM'ni jimgina bosib o'tardi (bosh ekrandagi "gaz va svetga → Transport"
   xatosining ildizi). QA: LLM-yo'l faillarining 7/15 tasi shu. Endi STRONG bosag'a bilan hal.
3. **UI bug (ochiq)**: pastki input ustidagi gradient zonasi orqasidagi elementlarning taplarini
   yutadi — tray chiplari ekran pastida bo'lsa bosilmaydi ("+ Boshqa nom" 3 tap javobsiz),
   yuqoriga scroll qilinsa ishlaydi. Alohida fix kerak (xarajat.dart Stack/hit-test).
4. **Degradatsiya rejimida ko'p amalli gap**: ruleParse faqat 1-summani oladi, mobil
   needs_confirm'ni tekshirmaydi → "bozorga 200 ming taksiga 30 ming berdim"da 30k JIMGINA
   yo'qoladi. LLM tirikligida muammo yo'q, lekin fallback'da ma'lumot yo'qotish — ochiq masala.
5. `/api/expenses/preview` va `Api.previewExpense` endi mobil tomonidan ishlatilmaydi — deprecate nomzodi.

## QA raqamlari (112 kombinatsiya, hisobot: 2026-08-03-parse-combo-results.md)

- Groq-yo'l: 57/72 = 79.2% (lug'at zaharisiz ~88.9%); rules-yo'l (kvota artefakti): 20/40 = 50%
- Summa aniqligi (LLM-yo'l): 97.2%, xatolar validator bilan ushlangan (jim saqlanish yo'q)
- amountSpans sof-funksiya: 23/23; qarz-himoya: 2/2
- Eng zaif lahja: Xorazm (4/8); Toshkent va emotsional: 8/8
- Anthropic bilan qayta-run: ANTHROPIC_API_KEY lokal .env'ga qo'shilgach `parse-combos.mjs` bilan

## Sifat darvozasi

- flutter analyze: 0 issue; flutter test: 14/14 — har uch mobil raundda
- node --check: toza; backend stub/live testlar: dict-tier 10/10, budget, fallback
- Reviewer: xarajat.dart — APPROVE; backend 1-raund — CHANGES NEEDED (2 majburiy: strict:true
  beta-headersiz 400 xavfi; kesh user-scoped emas + lug'atdan oldin) → tuzatildi; 2-raund delta — **APPROVE**
  (barcha 8 band hal, qarz/ko'p-summa guardlari regressiyasiz, budjet bir marta sarflanadi)

## Deploy / PO uchun qadamlar

1. Render'da `ANTHROPIC_API_KEY` (sync:false, Trust AI uchun allaqachon e'lon qilingan bo'lishi mumkin).
2. Lokal `.env`ga ham xuddi shu kalit (QA qayta-run va lokal smoke uchun).
3. Claude Console: oylik spend-limit (~$10) + auto-reload — PO o'zi sozlaydi.
4. Commit/push va Render deploy — PO ruxsati bilan.

Narx bahosi: parse ≈ $0.002/chaqiruv (Haiku 4.5); o'rgatilgan/takror iboralar $0;
kunlik shift: user-cap 40 → ≈$0.08/user/kun maks; kill-switch 300k token ≈ $0.40-0.50/kun shift.

---

# Kechki raundlar (2026-08-03, v3.9'dan keyin, commit qilinmagan)

## Qilingan ishlar

1. **Ko'p summali fallback** — LLM'siz rejimda har summa alohida amal (cap 5), 2-summa endi
   yo'qolmaydi; 0-summa spanlari filtrlangan. QA: 5/5.
2. **6 til kuchaytirish** — birliklar: es mil, fr mille, en thousand, zh 千/万(×10k)/百万 (yangi
   qiymat-klass, server+mobil sinxron); CAT_RULES va INC/EXP fe'llari ru/en/es/fr/zh; Xorazm
   lahjasi (bazar, shipoxona) + prompt'ga ~50 tokenlik sheva qatori. QA: 16/16 birlik, til 10/10.
3. **Papka xoreografiyasi** — kapalak ESKI joyga qo'nadi → summa sanaladi (900ms) → 1s'da BIR
   marta qayta tartib; partiya ustma-tushishida eski taymer bekor. Qurilmada jonli tasdiqlandi.
4. **O'Z-O'ZINI ZAHARLASH HALQASI topildi va yopildi** (eng muhim): LLM avto-javobi → avto-saqlash
   → learnFrom → STRONG lug'at → xato abadiy ("svetga ... KOMMUNAL tuladim" ham Transport bo'lgan
   edi). Davo: (a) learnFrom faqat USER tasdiqlagan amaldan (triple parsed'dan farq qilsa yoki
   accept_new_category); (b) PATCH toifa o'zgarishi = tuzatish (unlearn+learn+corrections);
   (c) DELETE = best-effort unlearn. Reviewer: APPROVE (2 polish bilan: (?<!п)обед, triple lowercase).
5. **Ma'lumot tozalash (PO ruxsati bilan)**: zaharlangan word_map qatorlari (svet/gaz/kommunal→
   Transport, bozor/kitob/sotib→Kiyim) o'chirildi; "gaz va svetga tuladim" 300k va 2 ta svet
   yozuvi Kommunal'ga ko'chirildi.

## Yakuniy jonli tasdiq (deploy'dan keyin)

- Deploy: `80028f2` (v3.9.1) + `be53a66` (STOP hotfix). Yakuniy qurilma testi:
  **"Svetga 25 ming tuladim" → Kommunal (conf 0.95)** — kunning bosh muammosi hal.
- TAG-SABAB: "svetga → Transport" xatolarining haqiqiy aybdori **'tuladim'** so'zi edi —
  "to'ladim/toladim" STOP'da bor, "tuladim" imlosi yo'q edi; u word_map'da Transport bilan
  7 hitgacha o'rganilib, STRONG bo'lib har "...tuladim" gapini Transport'ga majburlagan
  (LLM javobini ham bosib). Hotfix: umumiy fe'l imlo variantlari (tuladim, sarfladim,
  ishlatdim, bedim, ketti, qilish, yedim/yedik...) STOP'ga qo'shildi — endi ular na
  o'rganiladi, na so'raladi (eski zahar qatorlar o'lik).
- v3.9.1 tasdig'i: yakuniy testlarda avto-saqlash lug'atni O'ZGARTIRMADI (svet→Kommunal
  1 hitligicha qoldi) — verified-only o'rganish jonli ishlayapti.
- PO tekshirishi kerak (ochiq): Render'da ANTHROPIC_API_KEY qiymati kiritilganmi +
  Claude Console Usage'da so'rovlar ko'rinyaptimi — kunning bir qismida LLM zanjiri
  fallback'da ishlagani ehtimoli bor (aniq javob Render loglarida: `[llm] anthropic`).

## Yangi ochiq masalalar

- **Papka-ko'chirish UI yo'q** (muhim UX bo'shliq): folder-detail "Tahrirlash" faqat summa/izoh
  PATCH qiladi — noto'g'ri avto-joylashgan yozuvni foydalanuvchi ko'chira olmaydi, demak AI ham
  o'rganish signalini olmaydi. Keyingi feature-nomzod №1 (round-4 PATCH-learning bilan juftlikda).
- "Svetga X tuladim" qisqa iborasini prod Claude toza lug'at bilan ham 1 marta Transport dedi —
  svet→Kommunal STRONG bo'lgach deterministik hal bo'ladi (2-tasdiq kerak).
- "ekin dori aldim" (dehqonchilik konteksti) — LLM zaifligi, prompt nomzodi.
- QA Anthropic qayta-run kutilmoqda (lokal ANTHROPIC_API_KEY yo'q); qayta-runda
  ANTHROPIC_USER_DAILY_MAX'ni vaqtincha ko'tarish kerak (40 chaqiruvdan keyin jim o'chadi).

## Tungi raund: papka-ko'chirish UI + Anthropic QA (2026-08-03/04)

1. **Papka-ko'chirish UI qurildi** (№1 UX bo'shliq yopildi): yozuv ⋮ → Ko'chirish → picker
   (chip uslubi, joriy/Daromad/arxiv chiqarilgan, "➕ Boshqa nom" avval toifa yaratadi) →
   PATCH → server o'rganadi (unlearn+learn+correction) → toast + Bekor qilish (teskari
   o'rganish bilan). Qurilmada to'liq tasdiqlandi; **foydalanuvchining o'zi ham jonli
   ishlatdi** (qizlaga 400k → yangi Sovg'a papkasi) — o'rganish zanjiri real ishlaydi.
2. **Dehqonchilik prompti**: "ekin dori" endi Salomatlik emas — Boshqa + ✨Dehqonchilik
   taklifi; rules yo'lida (?<!ekin )dori guard. Reviewer APPROVE.
3. **QA Round 3 — to'liq Anthropic o'lchovi (113 keys, $0.284):**
   - Umumiy aniqlik: **92.0%** (Groq-aralash 68.8% edi); Claude vs Groq (72 umumiy keys):
     79.2% → **94.4%**; Xorazm: 4/8 → **8/8**; qarz 9/9; dict short-circuit 6/6 (0 token)
   - Suggestion sifati: 7/7 mantiqiy (Marosim, Dehqonchilik, Hayvonot, Remont...)
   - Yangi P1 nomzod: "NARSA + oldim" → daromad naqshi (5 fail; eslatma: asosiy mobil
     input daromadni baribir xarajatga o'giradi — amaliy zarar toifa sifatida cheklangan,
     lekin prompt bandi kerak). Mayda: sport-zal/obuna hint to'qnashuvi, USD kurs
     nomuvofiqligi (kursni LLM'ga qoldirmaslik), "chorvaga yem" konteksti.

## Sifat darvozasi (kechki raundlar)

- flutter analyze 0 / flutter test 14-14 (3 mobil raund); node --check toza
- Backend testlar: fallback 43/43, learn-suite 12/12, dict-tier 10/10, Anthropic stub yashil
- QA round-2: deterministik guruhlar 100%; LLM guruhlari SKIPPED-QUOTA (Groq); reviewer APPROVE ×2

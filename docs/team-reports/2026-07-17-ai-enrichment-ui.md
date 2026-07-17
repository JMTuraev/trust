# 2026-07-17 — Trust AI javob boyitish + 4 UI tuzatish

PO fikri: "javoblar kuchli emas, oddiy... pul bilan munosabatini boyitib borishimiz kerak" + 4 UI e'tiroz.

## Tashxis

Ma'lumot (agregat) va renderer (ai_blocks.dart, 8 blok turi) boy edi — muammo faqat promptda:
system prompt qasddan qisqalikka sozlangan ("1–4 blok", "2–4 gap", default text+chips),
AI proaktiv insight bermasdi, chart/progress/debt_card deyarli chizilmasdi.

## Backend (backend-dev)

- **ai-persona.js** — qisqalik biasi yumshatildi (3–6 gap mumkin); yangi PSIXOLOGIYA-6:
  har javobda so'ralmagan kamida bitta insight; oldinga qaragan freyming (proyeksiya/temp);
  JAVOB FORMATI: "odatda 2–5 blok", default naqsh text + (chart/progress/stat/debt_card) + chips,
  vizual bloklardan saxiy foydalanish. ⛔ Compliance qatorlar (MAXFIYLIK, QAT'IY CHEGARALAR,
  OLTIN XAVFSIZLIK, ROLDA QOLISH, render_blocks-only, 8 blok turi) — so'zma-so'z saqlandi.
- **ai-context.js** — 3 hosila signal: (2b) top toifa yillik proyeksiyasi, (2c) oyning eng
  katta bitta xarajati (+izoh slice 30), (6b) oy-temp (vaqt% ↔ byudjet%, +10% farqda "tez" flagi).
- **config.js** — AI_MAX_TOKENS default 400 → 800.
- **anthropic.js** — izoh + BLOCKS_TOOL schema hintlari persona bilan sinxronlandi (lead).

## Reviewer topilmalari (APPROVE, 2 kichik) — ikkalasi tuzatildi (lead)

1. *Maxfiylik doirasi*: 2c xom izohda hamkor ismi bo'lishi mumkin edi → **yakuniy summary
   endi bir marta pseudonymizeText'dan o'tadi** (composeContext oxirida) — §7 va 2c hamda
   kelajakdagi barcha xom-matn manbalari bitta joyda yopiladi. Sinov: "Anvarga osh berdim"
   izohi → "HAMKOR_1ga osh berdim" (maskalandi, leak yo'q).
2. *Budjet bosimi*: MAX_SUMMARY_CHARS 2600 → 3000 (~700 token) — yangi satrlar oxirgi
   bo'limlarni (§7, toifalar) kesib qo'ymasin.

## Mobile (flutter-dev)

1. **Back tugma** — ai_chat.dart header chapida chevron; store.dart: goAi() `aiFrom` ni
   saqlaydi (faqat asosiy tab, aks holda 'home'), yangi goAiBack() o'sha tabga qaytaradi.
2. **Bottom nav AI'da yashirin** — main.dart: `&& v['isAi'] != true` sharti.
3. **"yozmoqda" matni o'rniga brend loader** — `_BrandLoader`: TrustMark logotipi ohista
   puls (opaklik 0.45↔1.0, masshtab 0.92↔1.0, 1000ms repeat-reverse). Controller dispose
   qilinadi. l10n `aiTyping` kaliti qoldi (ishlatilmaydi).
4. **Qora chiziq (120×4 home-indicator) olib tashlandi** — tab_bar.dart, o'rniga
   SizedBox(12). ⚠️ Prototype template.html'dan ataylab chetlashish — PO so'rovi (product
   override), kodda izoh bilan hujjatlangan.

## Sifat darvozasi

- backend: node --check ×5 OK; node --test ai-context.test.js **19/19**; maxfiylik smoke-sinovi OK.
- mobile: flutter analyze **No issues found!**; flutter test **10/10**.
- reviewer: **APPROVE** (2 kichik topilma → tuzatildi).

## Holat / qolganlar

- APK (arm64, 18.5MB) qurilmaga o'rnatildi (ustidan, login saqlangan). Qurilmada UI
  tekshiruvi PIN qulfi ochilishini kutmoqda.
- **Backend hali deploy qilinmagan** — boy javoblar prod'da ko'rinishi uchun commit +
  push (Render autoDeploy) kerak. PO ruxsati kutilmoqda.
- Kelajak (PO tanlamadi, keyinга): proaktiv ochilish kartasi; function-calling tarix
  asboblari (get_category_history, get_month, biggest_expenses).

## Qo'shimcha (2-iteratsiya, commit 794c62d) — umumiy bilim + dunyo faktlari

PO fikri: "AI javoblari faqat user ma'lumotlaridan chetga chiqolmayapti". Sabab: "faqat
kontekstdagi raqamlar" qoidasini model "tashqi bilim taqiq" deb talqin qilgan. Yechim —
persona'ga "UMUMIY BILIM VA QIZIQARLI FAKTLAR" bo'limi: nomlangan barqaror metodlar
(50/30/20, kakeibo, qor koptok/ko'chki, xavfsizlik yostig'i, latte-faktor) RUXSAT va
KERAK, har doim foydalanuvchi raqamiga hisoblab. Himoya: tashqi aniq raqam (kurs/foiz/
statistika) to'qish taqiq; fakt ilhom uchun (ijtimoiy taqqoslash taqiq); 1 javob = max 1
fakt; investitsiya taqiqi va compliance o'zgarmagan. + "har doim sen" qat'iylashtirildi,
abstrakt savolga yomon-vs-yaxshi namuna qo'shildi.

Qurilmada tasdiq (skrinshot 28, 29): o'sha savodxonlik savoli endi 50/30/20 ni PO'ning
real daromadiga hisoblab beradi (11.9 mln -> 5.95/3.57/2.38); "qiziqarli fakt" so'roviga
latte-faktor. Qolgan kuzatuv: eski suhbat tarixida "siz" ohangi ko'p bo'lgani uchun model
ba'zan "siz"ga qaytadi — yangi suhbatlarda "sen"ga o'tishi kutiladi.

## Qo'shimcha (3-iteratsiya, commitlar 7a4ecc0 / 243533d / 06d1b9f) — xilma-xillik

PO fikrlari: har javob "Jafar," bilan boshlanmasin; yozuv dinamik terilsin ("marjon");
faktlar soni o'sib, takrorlanmasin.

- **45 kartalik bilim kutubxonasi** (ai-knowledge.js): 17 metod, 14 xulq-iqtisodiyot
  fakti, 8 odat, 6 o'zbek konteksti ('gap' ROSCA ehtiyot eslatmasi bilan). pickKnowledge:
  kun+user bo'yicha deterministik 3 karta (aralash tag), kun ichida bayt-barqaror
  (prompt-cache omon), 45 kunda to'liq aylanish (1-qadam kunlik siljish — LEN 3 ga
  karrali bo'lganda ⅓ chiqmay qolish xatosi reviewda topilib tuzatildi). Kontekstga
  so'rov paytida in'ektsiya (ai_profile keshiga yozilmaydi).
- **Marjon-effekt** (mobil): yangi javob matni so'zma-so'z ochiladi (~55ms/so'z, 2.5s cap,
  TextSpan alpha — layout sakramaydi), blok xoreografiya matn ochilishini kutadi.
  Reviewer topilmalari tuzatildi: ListView qayta yaratishда animatsiya replay/scroll
  hijack yo'q (landed initState'da), reveal ichida ma'nosiz scroll listener olib tashlandi.
  Qurilmada kadrma-kadr tasdiqlandi (burst3: yarim ochilgan matn; burst4: count-up 13905).
- **"Ism," ochilishi — deterministik yechim** (stripNameOpening): prompt qoidasi va uslub
  eslatmasi eski tarix mirroringini yenga olmadi — server endi suhbat davomida birinchi
  text blokdan "Ism,/—" prefiksini kesadi (birinchi javobда qoladi; "Jafarova" tegilmaydi).

Ochiq kuzatuvlar: (1) eski suhbatda "siz" ohangi qolyapti — yangi suhbatda kuzatiladi;
(2) model bir javobda qarz YO'NALISHINI teskari aytdi (server kartasi to'g'ri edi) —
kontekst satriga "menga qarzdorlar = ULAR SENGA qarzdor" aniqlashtirish nomzodi;
(3) debt_card remind tugmasi bug'i — alohida task chipda.

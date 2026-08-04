# 2026-08-04 — TO'YXONA moduli (v1 MVP)

Jamoa: lead (xarajatlar sessiyasi) + backend-dev + flutter-dev + reviewer.
Parallel sessiyalar: qarz daftar/obuna sessiyasi (fayl-egalik protokoli bo'yicha).

## Mahsulot mantiqi (nega shunday qurildi)

To'yxona egasining tovari — **sana + vaqt**. Shu sotiladi, avans bilan qulflanadi, to'y kuni
yakuniy hisob yopiladi. Shundan kelib chiqib:

- **Kunning uch vaqti** (O'zbekistonga xos): `nahor` (nahorgi osh) · `tushlik` · `kechki`.
  Bitta kunga uch to'y sig'adi, har biri alohida sotiladi.
- **Bir egada bir nechta to'yxona** — asosiy holat, chekka emas. Har biri ALOHIDA hisob:
  alohida kalendar, alohida pul yakuni. Ikki zalli bino = ikki to'yxona yozuvi (shunda
  har biri o'z kalendariga ega bo'ladi va ustma-ust bron imkonsiz).
- **Narx turlari** (`hall_menus`): "Oddiy — 150 000", "Lyuks — 200 000" — bir marta
  yaratiladi, bron qilishda tanlanadi. Chegirma uchun qo'lda ham o'zgartirsa bo'ladi.
- **Pul**: mehmon × bir kishilik narx (food) + qo'shimcha xizmatlar (extras) − to'lovlar = qoldiq.

## Uch kafolat (mahsulotning yuragi)

1. **Ustma-ust bron JISMONAN imkonsiz** — partial unique index
   `(user_id, coalesce(hall_id, '000…'), event_date, slot) where status <> 'bekor'`.
   `coalesce` shart: SQL'da `NULL <> NULL`, ya'ni oddiy indeks to'yxonasiz egalarni
   himoyasiz qoldirardi. Route ham oldindan tekshiradi, ham 23505 → 409 `SLOT_TAKEN`
   ga o'giradi — parallel so'rovlar poygasi ham o'tib keta olmaydi.
2. **Narx tarixi o'zgarmaydi** — `price_per_guest` va `menu_title` bron ichida SNAPSHOT.
   Narx ro'yxatini keyin ko'tarish/o'chirish o'tgan bronlar puliga tegmaydi.
3. **Aqlli holat** — avans kelishi bilan `band → tasdiq` (o'zbekcha mantiq: avans = sana
   qulflandi), qoldiq 0 bo'lsa `→ yakun`. To'lov o'chirilsa pasaymaydi; qo'lda PATCH ustun.

## Fayllar

Backend: `supabase/migrations/021_toyxona.sql` (5 jadval), `src/routes/toyxona.js` (16 route),
`src/routes/toyxona.test.js` (35 test), `src/index.js` (2 qator mount).
Mobil: `mobile/lib/toyxona_l10n.dart` (149 kalit × 6 til), `mobile/lib/toyxona_data.dart`
(butun HTTP shu yerda), `mobile/lib/screens/toyxona.dart` (4 ekran),
`mobile/lib/main_preview.dart` (dev kirish).

Circles naqshi (alohida `_data`/`_l10n` fayl) ATAYLAB tanlandi: uchta sessiya bir vaqtda
ishlayotgani uchun `l10n.dart`/`store.dart`/`api.dart` ga umuman tegilmadi.

## Reviewer topilmalari (12 ta, hammasi tuzatildi)

Eng muhim ikkitasi — pul yo'qotadigan turdan:
- `money()` `null`/`''`/`[]` ni jimgina 0 ga aylantirardi → `PATCH {price_per_guest: null}`
  kelishilgan shartnoma narxini na xato, na iz qoldirib nolga tushirardi.
- To'lov yozilgach status yangilanmasa 500 qaytardi → klient qayta yuborardi → **pul ikki
  marta yozilardi**. Endi warn + 201 (POST /bookings dagi avans yo'li bilan bir xil).

Migratsiyaga tegishli ikkitasi **qo'llashdan oldin** 021 ning o'ziga kiritildi (keyin bo'lsa
022 kerak bo'lardi): `create index if not exists` NOM bo'yicha ishlagani uchun eski zaif
indeks jimgina qolib ketishi mumkin edi → endi `drop` + majburiy `create`; `bookings.
price_per_guest` uchun ikki qatlamli `>= 0` cheklovi.

Qabul qilingan **qaror**: `yakun` bandga xizmat qo'shilib qoldiq paydo bo'lishi — xato EMAS
(to'y o'tgan, otashbozlik alohida hisoblangan). Status — egasi boshqaradigan ish holati,
puldan hosila emas; qoldiq har doim `totals.left` dan o'qiladi.

## Ikkinchi to'lqin (PO qarorlari + sessiyalararo ogohlantirishlar)

1. **BITTA TO'YXONA QOIDASI** (PO: $24 = bitta to'yxona; do'konlar obunada "miqdor"ni
   qo'llamaydi). `POST /halls` va arxivdan qaytarish `403 HALL_LIMIT` beradi (402 EMAS —
   ortiqcha zal SOTIB BO'LMAYDI, paywall ochilmasligi kerak). Chetlab o'tish teshigi ham
   yopildi (arxivla → yarat → qaytar = 2 faol). Chegara `MODULES.toyxona.max_units` dan
   o'qiladi — pog'onali SKU'ga o'tilsa faqat katalog o'zgaradi. Mobil: bitta to'yxona
   bo'lsa "qo'shish" tugmasi umuman ko'rsatilmaydi (o'lik affordance yo'q).
2. **APPARAT "ORQAGA" — ma'lumot yo'qolishi** (parallel sessiya reviewer'i topgan, bizda ham
   bor edi): `handleSystemBack: false` bo'lgani uchun ichki qatlamlar Root'ga ko'rinmasdi —
   to'ldirilgan bron formasida BACK butun modulni yopardi. Endi `store.setModuleBack_`
   ilgagi orqali eng yuqori qatlamdan yopiladi; ildizda `false` qaytib hub'ga chiqadi.
   `late final` majburiy (identity bo'yicha tozalash) — izohda sababi yozilgan.
3. **BEKOR QILINGAN BRON PULNI YUTARDI**: avans olingan, to'y bekor bo'lgan, pul egada
   qolgan — lekin oylik "olingan pul" jimgina kamayardi (daftar kassa bilan mos kelmasdi).
   Tuzatish ATAYLAB parallel sessiyanikidan farqli: ular to'lovni bronidan uzadi
   (`charge_id → null`), biz **bog'lanishni saqlab** `/summary` ga `cancelledPaid` qo'shdik —
   audit izi buzilmaydi, har so'm qaysi to'ydan kelgani ko'rinadi. Mobil uni alohida,
   bosiladigan qator qilib ko'rsatadi → bekor qilingan (puli qolgan) bronlar ro'yxati →
   tafsilot. Aks holda raqam ko'rinib, tekshirib bo'lmasdi.
   Qator ichida `left` EMAS, `paid` ko'rsatiladi: bekor bo'lgan to'yda "qoldiq 22 mln"
   qizil rangda turishi noto'g'ri — hech kim hech kimdan qarzdor emas.
4. **MIGRATSIYA TARTIBI KLAPANI**: 021 tasodifan 020 dan oldin qo'llansa, kvota 5-brondan
   keyin bloklardi, lekin obuna jadvali yo'qligi uchun to'lash ham imkonsiz edi.
   `isQuotaEnforceable(userId)` false bo'lsa kvota umuman majburlanmaydi.

## Darvozalar (yakuniy)

`node --check` toza · backend **134/134** · `flutter analyze` **0** · repo testlari **217/217**
(To'yxona l10n: 152 kalit × 6 til, paritet skript bilan tasdiqlangan).

## Ochiq ishlar

1. **021 migratsiya QO'LLANMAGAN** — PO Supabase SQL editor'ida ishga tushirishi kerak;
   ungacha barcha endpointlar 500, mobil xato holatini ko'rsatadi (kutilgan xatti-harakat).
   Qo'llagach fayl oxiridagi tekshiruv bloki (0-qadam: `indexdef` dump) bajarilsin.
2. **Hub'ga ulanmagan** — `home_hub.dart` obuna sessiyasida; kirish nuqtasi
   `ToyxonaScreen(onBack: ...)`, `handleSystemBack` o'chiq qolsin (Root PopScope boshqaradi).
3. **Narx modeli** (obuna sessiyasi tadqiqoti, `2026-08-04-iap-per-unit-research.md`):
   "har zalga $24" do'konlar orqali sotib bo'lmaydi (Apple/Play quantity obunani
   qo'llamaydi). Tavsiya — pog'onali SKU (1 zal / 2-3 zal / 4-10 zal). Qaror qabul qilinsa,
   `toyxona.js` da zal yaratishda `max_units` majburlanishi kerak bo'ladi. Modul UI'sida
   narx da'vosi YO'Q — qaror qanday chiqsa ham mobil o'zgarmaydi.
4. **Test bo'shlig'i**: `mobile/test/` fayl-egalik chegarasidan tashqarida edi — kalendar
   grid va `SLOT_TAKEN` forma-ochiq-qoladi yo'llari uchun widget test yozilsin.
5. `showDatePicker` ingliz oy nomlarini ko'rsatadi (butun ilovada `localizationsDelegates`
   yo'q — mavjud kamchilik, xarajat filtri ham shunday).
6. Prototip: yangi modul uchun `bosh-ekran.dc.html` da bo'lim yo'q. Kelishuv — jonli ekran
   PO tomonidan tasdiqlangach spetsifikatsiya obuna sessiyasiga beriladi, ular yozadi.

## Sessiyalararo koordinatsiya

Fayl-egalik protokoli ishladi: uch sessiya bir daraxtda, bitta ham to'qnashuv bo'lmadi.
Kelishilgan chegaralar — To'yxona funksionali (bu sessiya), obuna/paywall/hub (qarz sessiyasi);
umumiy fayllar navbat + oldindan e'lon bilan. README matni tayyorlab berildi, ular kiritdi.
Bepul kvota kelishuvi: `used` = `bookings` (`status <> 'bekor'`), `free_limit` = 5 — ko'rsatiladigan
limit har doim server majburlayotgan limit bilan bir xil bo'lishi qoida sifatida qabul qilindi.

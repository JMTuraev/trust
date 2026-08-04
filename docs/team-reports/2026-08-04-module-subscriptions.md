# 2026-08-04 — Modul obunalari (backend)

PO qarori: yagona $9 premium o'rniga **har menyu uchun alohida oylik obuna**.

| Modul | Narx/oy | Play/Apple product ID | Holat |
|---|---|---|---|
| Xarajatlar | $5 | `trust_xarajat_monthly` | Ishlayapti |
| Qarz daftar | $8 | `trust_qarz_monthly` | Ishlayapti |
| Ijarachi | $13 | `trust_ijarachi_monthly` | `soon` — modul qurilmoqda |
| To'yxona | $24 (har zal) | `trust_toyxona_monthly` | `soon` — modul qurilmoqda |

Bepul tarif: har modulda **5 ta yozuv** (mobil kartada `0/5`), keyin paywall.

## O'zgarishlar

- **`supabase/migrations/020_module_subs.sql`** — `module_subs(user_id, module, active_until, product_id, updated_at)`, PK `(user_id, module)`. RLS yoqilgan, policy **ataylab yo'q** va `anon/authenticated`ga GRANT yo'q: klient obuna muddatini o'zi yoza olmaydi (018 §2 saboqi — bepul obuna olish yo'li yopiq). ⚠️ **Qo'llash kerak**: Supabase SQL Editor'da, 019 kabi.
- **`src/lib/subscription.js`** — `MODULES` katalogi (narx + product_id yagona manba), `isModuleActive(userId, module)`, `getModulesStatus(userId)`. Eski premium (`profiles.premium_until`) **barcha modullarni ochadi** (grandfather). Kvota middlewarelari endi modul obunasini tekshiradi va 402 javobiga `module` maydonini qo'shadi (mobil aynan o'sha paywall'ni ochadi), xabarda modul narxi ($5/$8).
- **`src/routes/subs.js`** (yangi) — `GET /api/subs/status`, `src/index.js`da `/api/subs` ga ulandi.
- **`src/routes/profile.js`** — xarid tekshiruvi modullarga kengaytirildi: klient faqat `module` kalitini yuboradi, `product_id` **serverdagi** katalogdan olinadi (arzon modul cheki bilan qimmat modulni olish yo'li yopiq — chek aynan shu product_id bo'yicha tekshiriladi). `auditPurchase()` ajratildi — chek bir akkauntga bog'lanishi (2026-08-02 audit qoidasi) premium va modul xaridlari uchun bir xil. `grantModule()` — `max(joriy, yangi)` oldinga siljish; 020 qo'llanmagan bo'lsa **aniq 409** (foydalanuvchi pul to'lab obunasiz qolmasin).
- **`render.yaml`** — `FREE_DEBT_ENTRIES=300`, `FREE_EXPENSE_ENTRIES=300` qo'shildi. Kod defaulti 5, lekin **production hali test rejimida**: Play Billing ulanmaguncha mavjud foydalanuvchilar to'satdan qulflanmasin. **Launch'da shu ikki qatorni o'chirish kifoya** — paywall o'sha zahoti kuchga kiradi.

## Mobil kontrakt

```json
GET /api/subs/status
{
  "success": true,
  "legacy_premium": { "active": false, "until": null },
  "modules": [
    { "module": "xarajat", "active": false, "active_until": null, "soon": false,
      "price_usd": 5, "product_id": "trust_xarajat_monthly", "used": 2, "free_limit": 5 },
    { "module": "qarz", "active": false, "active_until": null, "soon": false,
      "price_usd": 8, "product_id": "trust_qarz_monthly", "used": 7, "free_limit": 5 },
    { "module": "ijarachi", "active": false, "active_until": null, "soon": true,
      "price_usd": 13, "product_id": "trust_ijarachi_monthly", "used": 0, "free_limit": 0 },
    { "module": "toyxona", "active": false, "active_until": null, "soon": true,
      "price_usd": 24, "product_id": "trust_toyxona_monthly", "used": 0, "free_limit": 0 }
  ]
}
```

Xarid: `POST /api/profile/me/subscription/verify` + `{ platform, module, purchase_token|receipt_data }`. `module` berilmasa — eski premium oqimi (orqaga moslik saqlangan). Javob: `{ success, data: <legacy sub>, modules: [...] }`.

## Verifikatsiya

- `node --check` — barcha o'zgargan fayllar toza; `subs.js` router yuklanadi (`GET /status`).
- `npm test` — **53/53 o'tdi**; `subscription.test.js` 13 → **20 test** (yangi 7 tasi: premium grandfather, modul izolyatsiyasi, muddati o'tgan obuna, 020 yo'qligida bardoshlilik, `getModulesStatus` shakli va narxlari, 402 `module` maydoni + narx matni).
- Mobil: `flutter analyze` toza, `flutter test` — **98/98 o'tdi**.

## Mobil tomon

- **Hub kartalari** (`home_hub.dart`): sarlavha qatorida chip — bepul holatda `3/5` hisoblagich, limit tugasa qulf + `$8/oy`. Obuna faol / legacy premium / server qo'llamasa — chip yo'q va ko'rinish avvalgidek. Qulflangan karta bosilsa navigatsiya o'rniga paywall ochiladi (store kaliti yo'q bo'lsa eski navigatsiya ishlaydi — hub hech qachon "o'lik" bo'lmaydi).
- **Teaser qatorlari**: Ijarachi ($13) va To'yxona ($24) — «Tez kunda», bosilsa modul nima berishini ko'rsatuvchi paywall ochiladi. Bo'sh holatda ham ko'rinadi.
- **`paywall_sheet.dart`** (yangi): narx pill, `{used}/{limit}` progress (tugasa qizil), 4 ta foyda qatori, CTA «Obuna bo'lish — $N/oy» (xarid ketayotganda spinner) yoki «Tez kunda» pill. Ko'rinishni store boshqaradi (Navigator yo'q).
- **`store.dart` / `api.dart` / `iap.dart`**: `GET /api/subs/status` (hydrate'da + yozuv qo'shilgach + xariddan keyin), 402 javobida `module` bo'lsa aynan o'sha paywall ochiladi va **butun ilova bo'ylab qizil "obuna tugadi" banneri YOQILMAYDI** (modul kvotasi ≠ akkaunt obunasi). `module`siz 402 — eski yo'l bayt-aynan. IAP: 4 ta modul mahsuloti xaritasi; Play'da mahsulot yo'qligi/timeout — xatosiz "tez orada" xabari.
- **l10n**: 35 yangi kalit ×6 til (modul nomlari, foydalar, paywall matnlari, `pwPayComingSoon`, `subModuleThanks`). Paritet tekshirildi: **537 kalit har 6 xaritada**.
- **Prototip** `bosh-ekran.dc.html`: 4a — hisoblagich chiplari, 4b — qulflangan holat, 4c — bo'sh holat + teaserlar.
- Testlar: `subs_status_test.dart` (23 ta) — parsing, bo'sh/nuqsonli javob, 6 til × 4 modul matn interpolatsiyasi, narx kontrakti (5/8/13/24) regressiya qulfi.

## Review (NEEDS-FIXES → tuzatildi)

Reviewer 15 ta topilma berdi; 1–4 relizni bloklovchi deb belgilandi. Backend tomoni (lead tuzatdi):

1. **KRITIK — xarid so'rovida `module` yuborilmasdi.** Mobil faqat `product_id` yuborardi, backend esa (anti-fraud sababli) uni ataylab e'tiborsiz qoldirib `module` bo'yicha marshrutlaydi. SKU'lar App Store'da yaratilgan kuni har bir modul xaridi: 400 → `completePurchase()` → **pul olingan, obuna yo'q, ilova ichida tiklab bo'lmaydi**. Yomonroq varianti: chekda eski tugagan premium bo'lsa 200 qaytib, "obuna yoqildi — rahmat!" ko'rsatilardi, modul esa qulf. Server tomoni: marshrutlash `productIdForModule()` ga ajratildi + 3 ta test (modulsiz → premium; har modul o'z SKU'si; noma'lum modul → null, premiumga tushmaydi). Mobil tomoni jamoada tuzatilmoqda.
4. **Reliz tartibi tuzog'i → kod bilan hal qilindi.** `FREE_*` qatorlari 020 qo'llanishidan oldin olib tashlansa, foydalanuvchilar 5 yozuvda qulflanib, sotib olish ham 409 berardi (to'lash yo'li yo'q). Endi **xavfsizlik klapani**: `module_subs` jadvali yo'q bo'lsa kvota UMUMAN majburlanmaydi (bir marta ogohlantirish log'i). Ya'ni noto'g'ri tartib endi hech kimni qulflab qo'ymaydi.
6. **Muddati o'tgan chek "muvaffaqiyat" edi** — `expiryMs <= now` holati endi 400 `SUB_EXPIRED_RECEIPT`.
7. **Apple `exclude-old-transactions`** — modul obunalarida bitta akkauntda bir nechta faol obuna bo'ladi, Apple esa faqat oxirgisini qaytarishi mumkin edi (ikkinchi modul cheki "topilmadi" → 1-topilmadagi yo'qotish). Endi kerakli mahsulot topilmasa **to'liq tarix bilan qayta so'raladi**.
11. **Chek endi mahsulotga ham bog'lanadi** — bitta token bilan boshqa modulni ochib bo'lmaydi (409). Ilgari faqat akkauntga bog'langan edi, ya'ni dev/Play yo'lida bitta `DEV.` token 4 ta modulni ochardi va QA aynan 1-topilma yashiringan joyni sinay olmasdi.
12. **«5 bepul» aslida 9 edi** — `/confirm` bitta so'rovda 5 tagacha yozuv saqlaydi, kvota esa faqat "1 ta joy bormi" deb tekshirilardi. Endi `expenseQuotaBlock(userId, n)` butun to'plam bo'yicha sanaydi (qarz_* amallari kvotani yemaydi).
14. `GET /api/subs/status` — 30/min rate limit + README API jadvaliga qo'shildi.

Backend testlari: **85/85 o'tdi** (obuna bo'yicha 13 → 27 test).

Mobil tomoni (jamoa tuzatdi, **119/119 test**):

1. **Xarid so'roviga `module` qo'shildi.** `IapService.verifyBodyFor(sku, receipt)` — SKU→modul qarorining yagona egasi; `Api.verifyApple()` butunlay olib tashlandi (chaqiruvchisiz qolgan va aynan shu bugni tug'dirgan shakl edi). Eski premium so'rovi bayt-aynan o'zgarishsiz. 13 ta yangi test.
2. **`PaywallSheet` global overlay bo'ldi** (`main.dart`, z:64 — LangSheet'dan keyin, ToastView'dan oldin). Ilgari faqat hub'da chizilardi: Xarajat ekranida 402 kelsa hech narsa ko'rinmasdi, `S['paywall']` esa qolib, keyin hub'ga kirilganda kutilmaganda ochilardi.
3. **Android «orqaga»** endi paywall'ni yopadi (`_anyLayerOpen` + `closeTopLayer_`) — ilgari ildiz ekranda modal ochiq turib ilova yopilardi (2026-08-02 auditi ogohlantirgan bug sinfi).
5. **«7/300» oshkorligi**: hisoblagich chipi faqat `limit ≤ 20` bo'lganda chiziladi (`kModChipMaxLimit = kSubLimitDisplayMax` — bitta manba). Qulf chipi har qanday limitda ishlaydi.
8. **Profil ekranidagi eskirgan narx**: qoida — **narx faqat StoreKit'dan kelganda ko'rsatiladi**. `$9/oy` qotirilgan zaxira matnlar o'chirildi (qayta yozilmadi), `subInfo` modul modeliga moslab 6 tilda yangilandi, `subPriceMonthly` → `subPerMonth` ({price} bilan; ilgari `'$narx/oy'` suffiksi tarjimasiz Dart literal edi). Apple 3.1.2 avto-yangilanish ma'lumoti ham faqat haqiqiy narx bilan chiqadi. Eski premium egalarining ko'rinishi tegilmadi.
9/10. Ochiq paywall hisoblagichlari `refreshSubs_` da qayta hisoblanadi; `refreshSubs_` ga identity guard qo'shildi (chiqib qayta kirilganda oldingi akkaunt raqamlari yozilmaydi).
13. Paywall sarlavhasi noma'lum modulda endi **«Xarajatlar»ga tushmaydi** (boshqa modul narxi yonida noto'g'ri sarlavha ko'rinardi) — xom modul kodi chiqadi; uchala xarita uchun paritet testlari qo'shildi.
15. Teaser kartalari prototipga moslandi (tekis fon + hair border, butun karta 0.75 shaffoflik) — aksent gradient *ochiq* bo'limlarning belgisi, qulflanganda ishlatilishi dizayn tilига zid edi.

## Ikkinchi review (tuzatishlar tekshiruvi) — yana 7 topilma, hammasi tuzatildi

Reviewer 16 ta da'vodan 11 tasini to'liq to'g'ri deb tasdiqladi, qolganlarida bo'shliq topdi:

1. **HIGH — `/confirm` da kvota middleware qolib ketgan edi.** Handler ichidagi to'plamli gate to'g'ri yozilgan, lekin route'dagi eski `requireExpenseQuota` (n=1) undan OLDIN ishlar edi. Natija: limitga yetgan foydalanuvchi Xarajat chatiga «Aliga 100 ming qarz berdim» deb yozsa — yozuvda BITTA ham xarajat yo'q bo'lsa ham 402 olardi va mobil **xarajat paywall'ini ($5)** ochardi, holbuki amal QARZ edi. Modullararo qulflash — modul modeli aynan shuni taqiqlaydi. Middleware olib tashlandi.
2. **HIGH — to'langan tranzaksiya qaytariladigan xatoda ham yopilardi.** `iap.dart` faqat `status == 0` (tarmoq) ni qaytariladigan deb bilardi; 409 (020 qo'llanmagan), 500, 502 — hammasi "doimiy" deb yopilardi, ya'ni StoreKit chekni boshqa qaytarmasdi → **pul olingan, obuna yo'q**. Aynan 020 qo'llanmagan deploy oynasi — klapanning butun sababi — shu tuzoqqa tushar edi. Endi `isRetryableVerify(status, code)` sof funksiyasi: 0 · 5xx (501'dan tashqari) · 409 `SUB_DB_NOT_READY` → tranzaksiya OCHIQ. Server bu kodni javobga chiqaradi (`index.js` xato handleri 4xx da `code` qo'shadi) — chunki boshqa 409 («chek boshqa akkauntniki») DOIMIY va yopilishi kerak. 501 ataylab doimiy: «to'lov ulanmagan» — imkoniyat yo'qligi, nosozlik emas. 4 ta test.
3. **MEDIUM — migratsiya-yo'q klassifikatori juda keng edi.** `/does not exist|schema cache/i` HAR QANDAY xabarga mos kelardi — jumladan USTUN topilmadi. Doimiy shunday xato kvota gate'ini HAMMA uchun cheksiz ochib qo'yardi va faqat bitta log qatori bilan bildirilardi (jimgina daromad yo'qolishi). Endi: jadval kodlari (42P01/PGRST205) YOKI xabar aynan o'sha jadval nomini o'z ichiga olishi shart; klapan ochiq turganda har daqiqada `console.error`.
4. **LOW — «orqaga» tugmasi tartibi z-tartibga zid edi.** Paywall main.dart'da z:64 (cc/til sheetlaridan ustida), yopish tartibida esa ulardan keyin turardi: til varag'i ochiq turib 402 kelsa, birinchi «orqaga» ko'rinmayotgan varaqni yopar va foydalanuvchiga hech narsa o'zgarmagandek tuyulardi. Paywall birinchi o'ringa ko'chirildi.
5. **LOW — `errSubExpired` da eskirgan `$9/oy`** 6 tilda qolib ketgan edi (hozircha o'qilmaydi, lekin bir `Lf()` chaqiruvi bilan jonlanardi). Narxsiz qayta yozildi.
6. **LOW — App Store subscription group tuzog'i.** Agar 4 modul bitta guruhda yaratilsa, ular bir-birini almashtiradi (foydalanuvchi ikki modulga birdan obuna bo'la olmaydi) va Apple `original_transaction_id` ni qayta ishlatgani uchun yangi «bitta chek — bitta mahsulot» tekshiruvi noto'g'ri 409 berardi. `docs/play-store-checklist.md` ga **6a bo'limi** qo'shildi: mahsulot ID'lari jadvali, har modul AYRIM guruhda, 020 → keyin limitni tushirish tartibi, ikki modulni birdan sotib olish sinovi.
7. **LOW — logout/login poygasi.** Band paytda kelgan majburiy so'rov tashlanardi va yangi akkaunt 60 soniyagacha hisoblagichsiz qolardi. Endi `_subsAgain` bayrog'i bilan qayta uriladi.

Yakuniy: backend **97/97**, mobil **125/125**, `flutter analyze` toza.

### Regressiya qulflari (yangi testlar)

- `mobile/test/paywall_mount_test.dart` — paywall hub'dan TASHQARI ekranda ham chiziladi va ikki marta mount bo'lmaydi. Muallif testni **ataylab buzib sinab ko'rgan** (main.dart mount'ini o'chirib — ikkala holat ham yiqildi), ya'ni qulf haqiqiy.
- `mobile/test/iap_verify_body_test.dart` — xarid so'rovi tanasi: modul SKU'si `module` bilan, eski premium `module`siz (bayt-aynan), noma'lum SKU → eski yo'l.
- `src/lib/subscription.test.js` — 020/021 migratsiyasiz holat, xavfsizlik klapani, to'plamli kvota, xarid marshrutlash, to'yxona kvota ko'rsatkichi.

Umumiy: backend **85/85**, mobil **121/121**, `flutter analyze` toza.

### PO qarorlari (2026-08-04, kechqurun)

1. **«Har zalga $24» BEKOR QILINDI.** Buning o'rniga: **bitta obuna = bitta to'yxona**. Ko'proq kerak bo'lsa foydalanuvchi boshqa raqamga alohida ro'yxatdan o'tadi («bu bizga muammo emas»). Natijada pog'onali SKU ham, `qty` ustuni ham, do'kon miqdorli obunasi ham kerak emas — tadqiqotdagi eng murakkab yo'l butunlay chetlab o'tildi. Katalogda `per_unit` o'rniga `max_units` (toyxona 1, ijarachi 5); majburlash modul route'larida (To'yxona sessiyasi `POST /halls` va arxivdan qaytarishda **403 `HALL_LIMIT`** qildi — 402 EMAS, chunki bu paywall holati emas: ortiqcha zalni sotib bo'lmaydi).
2. **Ikkala yangi menyu ham OCHIQ** — «Tez kunda» holati olib tashlandi (`soon` bayrog'i katalogdan chiqdi). Ular endi Xarajatlar/Qarz daftar kabi to'liq menyu: hub kartasi haqiqiy ekranga olib boradi, `getModulesStatus` ularga ham `used`/`free_limit` qaytaradi.
3. **«Ijarachi» → «Ijaradagi uylar»** (ko'rinadigan nom, 6 tilda). Modul kaliti `ijarachi` saqlanadi — u 020 dagi check-constraint'da. Modul chegarasi: **maksimum 5 uy**.
4. **Profil ekrani modul ro'yxatiga aylantiriladi** — har modul alohida qator (holat, `{used}/{limit}`, obuna tugmasi). «Obunani yangilash» warti shu bilan yopiladi.

### Profil ekrani — modul ro'yxati (PO qarori #4, bajarildi)

Bitta umumiy karta o'rniga har modul alohida qator: nom, holat (`Faol · sana gacha` / `3/5 bepul yozuv ishlatildi` / `Bepul limit tugagan` / `Bepul reja`) va tugma. Muhim qarorlar:

- **Profil modul qatorlarida narx ko'rsatilmaydi** — u yerda holat muhim, tarif emas.

> ⚠️ **NARX QOIDASI YANGILANDI (PO 2026-08-04, kechqurun).** Yuqoridagi qator faqat PROFIL ekraniga tegishli. Umumiy qoida endi surface bo'yicha ajratilgan:
> - **Hub kartalari** — o'ng pastki burchakda tarif DOIM ko'rinadi (PO talabi: «menyu narxi /month standart tarzida»).
> - **Narx manbai — bitta funksiya** (`modPriceLabel`): avval DO'KON narxi (foydalanuvchi haqiqatan to'laydigan summa, o'z valyutasida), u bo'lmasa katalog narxi (`$13/oy`) ko'rsatkich sifatida. Widget ichida qotirilgan narx satri BO'LMAYDI.
> - **Xarid nuqtasi** (paywall narx pilli va CTA tugmasi) — do'kon narxi bor bo'lsa **doim** o'sha (`modCtaLabel`). Bu eng muhim joy: tugmada «$8/oy» yozilib, do'kon so'mda boshqa summa yechishi mumkin emas.
> - Buning uchun `modPerMonthCur` / `pwCtaCur` kalitlari qo'shildi (6 tilda) — ular `$` belgisini QO'YMAYDI, chunki do'kon narxi o'z valyuta belgisini olib keladi (aks holda «$24 000 so'm/oy» chiqardi).
> Bugun do'konda mahsulotlar yo'q, ya'ni hamma joyda katalog narxi ko'rinadi; mahsulotlar yaratilgan kuni hammasi **avtomatik** haqiqiy narxga o'tadi — ilovani yangilash shart emas.
- **Faol modulda tugma yo'q** — yashil belgi. Allaqachon obuna bo'lgan modulda «Obuna bo'lish — $8/oy» oynasini ochish mantiqsiz.
- Hisoblagich qoidasi hub bilan **bitta manbadan** (`kSubLimitDisplayMax`, nusxa emas) — production'dagi `free_limit=300` profilda ham «7/300» bo'lib chiqmaydi, «Bepul reja» ko'rinadi.
- PO shikoyati ildizidan yopildi: «Obunani yangilash» faqat obuna HAQIQATAN tugagan bo'lsa chiqadi; hech qachon obuna bo'lmaganga «Obuna bo'lish».
- Eski $9 premium egasi ko'rinishi bayt-aynan saqlandi, ustiga 4 modul «Premium obunangizga kiritilgan» bo'lib qo'shildi (tugmasiz).
- Server modullarni qaytarmasa — eski umumiy karta (narxsiz); server qisman qaytarsa yetishmagan modullar bepul qator sifatida to'ldiriladi (hub 4 ta, profil 2 ta ko'rsatib qolmaydi).

Nom o'zgarishi 6 tilda: `modIjarachi` → «Ijaradagi uylar» / «Сдаваемые дома» / «Rental properties» / «Propiedades en alquiler» / «Biens en location» / «出租房产». Tavsiflar va paywall matnlari ham ijarachi (yashovchi) emas, **uy egasi** nuqtai nazariga o'tkazildi. Kalit nomi `modIjarachi` saqlandi — u backend modul kaliti va 020 check-constraint'i.

### Ochiq qolgan

- `kModChipMaxLimit = 20` — vaqtinchalik; `render.yaml`dagi 300 qiymatlari olib tashlangach keraksiz bo'ladi.
- ⚠️ **Migratsiyalar hali qo'llanmagan** (020, 021, va yangi 022). Qo'llanmaguncha: obuna sotib bo'lmaydi (xavfsizlik klapani kvotani majburlamaydi — hech kim qulflanmaydi), To'yxona va Ijara ekranlari esa xato holatini ko'rsatadi (barcha endpointlar 500). Bu **kutilgan** holat, buzuqlik emas.

## Keyingi qadamlar

1. **020 migratsiyani Supabase'da qo'llash** (busiz modul obunasini sotib bo'lmaydi; o'qish tomoni migratsiyasiz ham yiqilmaydi).
2. Play Console'da 4 ta obuna mahsulotini yaratish (yuqoridagi product ID'lar), keyin `render.yaml`dagi `FREE_*` qatorlarini olib tashlash.
3. Ijarachi va To'yxona modullarining o'zini qurish — tavsiyalar: `2026-08-04-rivals-research.md`.

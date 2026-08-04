# 2026-08-04 — «Ijaradagi uylar» moduli (yangi)

PO qarori: uy egasi ijaraga bergan uylarini yuritadi. Obuna **$13/oy**, bitta hisobda **maksimum 5 uy** — ko'proq kerak bo'lsa boshqa telefon raqamiga alohida hisob ochiladi («bu bizga muammo emas»). Bepul: 5 ta hisob-kitob yozuvi, keyin obuna. Ijarachiga (uyda yashovchiga) **akkaunt kerak emas** — uyda ism + telefon sifatida saqlanadi.

Nomi ataylab «Ijarachi» emas, **«Ijaradagi uylar»**: mahsulot uy EGASI uchun. Modul kaliti kodda `ijarachi` bo'lib qoladi (020 migratsiyadagi check-constraint).

## Backend (migratsiya 022)

| Jadval | Mazmuni |
|---|---|
| `rent_houses` | uy nomi/manzil, ijarachi ismi+telefoni, oylik ijara (UZS), arxiv, tartib |
| `rent_charges` | hisoblangan to'lov: oy (`YYYY-MM`), turi (`ijara`/`kommunal`/`boshqa`), summa, muddat, holat (`kutilmoqda`/`tolangan`/`bekor`) |
| `rent_payments` | to'lovlar; `charge_id` bo'sh bo'lishi mumkin (taqsimlanmagan to'lov) |

Endpointlar README'da (`### Ijaradagi uylar (022 migratsiya)`).

**5 uy chegarasi ikki qatlamda:**
1. Route — `POST /houses` faol uylarni sanaydi; `PATCH /houses/:id` arxivdan qaytarishda qayta tekshiradi (arxivla → yangi yarat → qaytar teshigi yopiq). **403 `HOUSE_LIMIT`**, 402 EMAS — pul to'lab ham 6-uy ochilmaydi, demak paywall ochilmasligi kerak.
2. DB trigger — `pg_advisory_xact_lock` bilan: ikki parallel so'rov ikkalasi ham «4 ta bor» deb ko'rib 6-uy yaratib yubormasin.

Chegara qiymati `MODULES.ijarachi.max_units` dan (yagona manba). Kvota gate faqat `POST /charges` da; **to'lov kiritish hech qachon bloklanmaydi** (pul kirishi to'silmaydi — qarz daftari/to'yxona bilan bir xil siyosat). Bekor qilingan yozuv kvotani yemaydi; uyni arxivlash kvotani tiklamaydi (reset hiylasi yo'q).

Bitta yaxshi qaror: `tolangan` holati to'lov o'chirilsa `kutilmoqda` ga **qaytadi** — aks holda haqiqiy qarz yashil yorliq ostida yashirinib qolardi.

## Mobil

Fayllar: `ijara_data.dart` (modellar + sof parserlar + `IjaraRepo`), `ijara_l10n.dart` (101 kalit × 6 til), `screens/ijara.dart`. Circles/To'yxona naqshi — umumiy `l10n.dart` ga tegilmaydi.

Oqim: uylar ro'yxati (oy · N uy, sarlavhada **yig'ilishi kerak** summa, qatorlarda ijarachi, qoldiq, `to'langan/jami`, kechikkanlar soni) → uy tafsiloti (ijarachi + nusxalanadigan telefon, balans, davr yozuvlari, to'lovlar) → modallar: uy formasi, hisob-kitob formasi (tur chiplari, summa, muddat), to'lov formasi (maqsad chiplari — umumiy yoki aniq yozuv, qoldiq bilan oldindan to'ldiriladi).

Chegaraga yetganda **forma umuman ochilmaydi** — tushuntirish oynasi chiqadi (bosilib, kafolatlangan xato chiqmasin).

**Backend yo'q bo'lsa (404) xato holati ko'rsatilmaydi** — bo'sh ro'yxat va odatdagi «Hali uy qo'shilmagan» kartasi. Buzuq JSON ham istisno tug'dirmaydi (14 ta test shuni qoplaydi).

## Verifikatsiya

- Backend: `npm test` **130/130** (33 tasi yangi).
- Mobil: `flutter analyze` toza, `flutter test` **183/183** (48 tasi yangi).

## Keyingi qadamlar

1. ⚠️ **022 migratsiyani Supabase'da qo'llash** (020, 021 bilan birga — birlashtirilgan fayl PO'da).
2. ~~Hub kartasini ulash~~ — BAJARILDI (quyida).
3. Kichik bo'shliqlar (muallif qayd etgan): muddatni tozalab bo'lmaydi; to'lovni tahrirlash yo'q (o'chirib qayta kiritiladi); uylarni qayta tartiblash UI yo'q; yozuvni boshqa oyga ko'chirib bo'lmaydi; `truncated` bayrog'i UI'da ishlatilmaydi.
4. Umumiy texnik qarz (ikkala modul uchun): `money`/`monthBounds` kabi yordamchilar `toyxona.js` va `ijara.js` da nusxalangan — `src/lib/money.js` ga chiqarish kerak (`money()` allaqachon bir marta pul yo'qotadigan bugga sabab bo'lgan).

## Hub'ga ulanishi (yakuniy bosqich)

`_teaserCard` butunlay olib tashlandi — ikkala modul ham hero/qarz kartalari bilan bir oiladagi to'liq menyu kartasi (`_menuCard`): gradient + halo, 104px suv belgisi, sarlavha qatorida `_modChip` (hisoblagich yoki qulf), tavsif va o'ng chevron. Bo'sh holatda ham ko'rinadi.

- Navigatsiya: `goIjara_` / `goToyxona_` — `goXarajat_` naqshi bilan aynan bir xil; main.dart'da `IjaraScreen(onBack: …)` / `ToyxonaScreen(onBack: …)`, `handleSystemBack` BERILMAYDI (Root PopScope boshqaradi).
- Qulflangan modul kartani bosganda **navigatsiya emas, paywall** ochadi (hero/qarz kartalari bilan bir xil mantiq).
- `kSubModuleDefaults` da `soon: false` (backend katalogi bilan sinxron). `soon` MEXANIZMI saqlandi — kelajakdagi modul uchun ishlaydi.
- Paywall'da chegara siyosati matni: `pwCapIjara` / `pwCapToy` (6 tilda). Uy soni `{n}` — `MODULES.ijarachi.max_units` bilan sinxron, tarjimaga qotirilmagan. Narx yo'q.

**Uch mustaqil qaror** (reviewga qo'yildi): karta sarlavhasi modul nomini o'zi ko'taradi (nom ikki marta yozilmasin); aksent rangi `p.ink` — qizil/yashil bu ilovada pul yo'nalishini bildiradi, kartada raqam yo'q ekan rang ma'no to'qib chiqarardi; `kModuleSubsUi` bayrog'i bu kartalardan olib tashlandi — u obuna UI'sining avariya tugmasi, uni o'chirish endi ikkita ishlaydigan modulni umuman yo'q qilib qo'yardi.

**Yo'l-yo'lakay topilgan bug (hozirgi buildda bor edi):** «SO'NGGI / Bugun:» sarlavha qatori 320pt ekranda **rus va fransuz** tillarida toshib ketardi (ru 31px, fr 50px) — bugungi summa ekrandan chiqib ketgan. Tuzatildi (`Expanded` + `FittedBox`).

**Ma'lum qirra:** modul ICHIDAN (masalan uy formasi ochiq turib) Android «orqaga» bosilsa to'g'ridan-to'g'ri hub'ga qaytadi, modul ro'yxatiga emas. Ikkala modul muallifi ham `handleSystemBack: false` ni talab qilgan (Root PopScope egaligi) — kelajakda store darajasidagi «modulda ichki qatlam ochiq» ilgagi bilan hal qilinadi.

Testlar: **202/202** (hub_menu_test.dart — 14 ta yangi: 4 karta, «Tez kunda» qolmagani, ochiq modul navigatsiyasi, qulflangan modul paywall'i, orqaga qaytish, 6 tilda 320pt render).

## Review (NEEDS-FIXES → hammasi tuzatildi)

Reviewer 10 ta topilma berdi. Toza deb tasdiqlanganlar: 5 uy chegarasi (uch joyda, arxiv teshigi va parallel so'rov ham yopiq), kvota gate (faqat `POST /charges`; to'lov hech qachon bloklanmaydi; ko'rsatilgan va majburlanadigan sanoq **bayt-aynan bir xil so'rov**), 022 migratsiya konvensiyalari, l10n pariteti, hub/navigatsiya, testlarning haqiqiyligi.

1. **HIGH — bekor qilingan yozuv OLINGAN PULNI yo'qotardi.** Ijarachi ijarani to'liq to'laydi → egasi yozuvni bekor qiladi (takror kiritilgan) → pul yozuv, davr va uy yakunlaridan **butunlay chiqib ketardi**, to'lovlar ro'yxatida esa to'liq summa turaverardi. Ya'ni daftar egasi qo'lida turgan pulni «olinmagan» deb ko'rsatardi. Tuzatish: bekor qilishda (DELETE va `PATCH status:'bekor'`) to'lovlar **uziladi** (`charge_id → null`) va taqsimlanmagan tushum bo'lib qoladi — «pul hech qayerga yo'qolmaydi» qoidasi endi kodda ham bajariladi. Test invariantni qulflaydi.
2. **MEDIUM — modul ichidan «orqaga» ma'lumot yo'qotardi.** To'lov formasi ochiq, summa yozilgan holatda bir marta bosilsa modul butunlay yopilardi; tafsilotdan esa ro'yxatga emas, hub'ga chiqib ketardi (ekran ichidagi qatlamlar store'ga ko'rinmasdi). Yechim: `store.moduleBack` ilgagi — modul o'z `_closeTop` ini ro'yxatdan o'tkazadi, Root PopScope avval shuni chaqiradi. To'yxona moduliga ham shu kerak (egasiga 3 qator yuborildi).
3. **MEDIUM — paywall mavjud bo'lmagan funksiyalarni sotardi** (quyida alohida).
4. **MEDIUM — kvota klapani yo'q edi**: 020 dan oldin 022 qo'llansa foydalanuvchi 5-yozuvda **to'lash imkoniyatisiz** qulflanardi. `isQuotaEnforceable()` eksport qilindi va gate'ga qo'shildi.
5. **MEDIUM — prototip kod bilan ajralib ketgan edi** (eski «Tez kunda» kartalari) — uchala variant va AI ikonkasi sinxronlandi.
6–9. Server chegara qiymati ichma-ich o'qilmasdi; xato xabarlari 5 tilda o'zbekcha chiqardi; modul nomi ikki xil edi (`title` va `modIjarachi` 5 tilda farq qilardi); eskirgan izohlar.
10. LOW, qoldirildi: `POST /payments` idempotent emas (loyiha bo'ylab naqsh) — sovuq startda takror urinish to'lovni ikki marta yozishi mumkin.

Qo'shimcha: mobil tomonda davr yakuni taqsimlanmagan to'lovlarni sanamasdi — server sanardi. Endi bitta qoida (`ijSumPeriod`).

## Paywall matnlari: sotilayotgan, lekin mavjud bo'lmagan funksiyalar

Auditda **7 ta band** (42 satr, 6 til) haqiqiy funksiyalarga almashtirildi. Eng jiddiylari:

| Modul | Eski va'da | Haqiqat |
|---|---|---|
| Qarz daftar $8 | «PDF dalil va arxiv» | PDF eksporti YO'Q — tugma `tPdfSoon` («tez orada») toastini chiqaradi |
| Ijara $13 | «Ijarachi obunasiz tasdiqlaydi» | Ijarachida akkaunt yo'q — ikkita matn ustuni xolos |
| Ijara $13 | «avto-eslatmalar» | `dueReminder.js` faqat `debts` jadvalini o'qiydi |
| Xarajat $5 | «Oylik hisobot va grafiklar» | Hisobot tabi va grafiklar hech qaysi ekranga ulanmagan |
| Xarajat $5 | «oylik chegara nazorati» | Backend bor, ekranda UI yo'q |
| To'yxona $24 | «Zal yoki kishi boshiga narxlash» | `computeTotals` faqat kishi boshiga ko'paytiradi |
| To'yxona $24 | «xonalar» | Presetlar: musiqa, fotograf, videograf, tort, bezash, otashbozlik |

Har bir yangi bandning tagida uni isbotlovchi kod yo'li bor va kalit ustida izoh qoldirildi (eski va'da nima edi, nega yolg'on edi, yangisini nima tasdiqlaydi) — matn ortga «siljib» ketmasligi uchun. Mahsulotlar do'konlarda hali yaratilmagani uchun bu va'dalarga hech kim pul to'lamagan.

**Yakuniy darvoza:** backend **134/134**, mobil **217/217**, `flutter analyze` toza.

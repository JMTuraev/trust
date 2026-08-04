# Raqobatchilar tadqiqoti — "Ijarachi" va "To'yxona" modullari (2026-08-04)

## 1) Ijarachi moduli — raqobatchilar

### Jadval: global va MDH raqobatchilari

| Nom | Narx | Asosiy funksiyalar |
|---|---|---|
| TenantCloud (AQSh) | Starter $15/oy, Growth ~$29/oy, Pro $50/oy (https://www.softwareadvice.com/property/tenantcloud-profile/) | Onlayn ijara to'lovi, to'langan/muddati o'tgan invoyslarni avtomatik kuzatish, ta'mirlash so'rovlari, soliq hisobotlari, e-imzo, shartnoma konstruktori (lease builder) |
| DoorLoop (AQSh) | ~$49/oy (20 birlikkacha, yillik), Pro $109/oy (https://www.getapp.com/real-estate-property-software/a/doorloop/) | Ijarachi portali (xabarlar, shartnomalar, hisobotlar), buxgalteriya, ta'mirlash work-order, skrining |
| RentRedi (AQSh) | $9–19.95/oy, obyektlar cheksiz (https://rentredi.com/pricing) | Ijarachi mobil ilovasi: telefondan to'lov, **naqd pul bilan to'lash opsiyasi**, avto-eslatmalar, kechikish jarimasi, e-imzo, ta'mirlash so'rovi |
| Landlordy (mobil-first) | Bepul: 1 obyekt + yozuvlar soni cheklangan; Mini/Plus/Pro IAP, Pro $99.99 bir martalik (https://landlordy.com/pricing.html) | Bizga eng yaqin analog: telefondan invoys yuborish (matn/PDF, messenjer orqali), xarajat hisobi, 2/10/cheksiz obyekt darajalari |
| Stessa (AQSh) | Essentials bepul (obyektlar cheksiz), Manage $12–15/oy, Pro $28–35/oy (https://www.softwareadvice.com/property/stessa-profile/) | Portfel monitoringi, xarajat hisobi, avto-eslatmali ijara yig'imi, soliqqa tayyor hisobotlar |
| Rentila (Fransiya) | Bepul: 1 obyekt/2 ijarachi; pullik €40/yildan (https://www.rentila.com/pricing) | **Kvitansiya (receipt) generatsiyasi**, avto-eslatmalar, e-imzo, hujjat shablonlari, soliq deklaratsiyasiga yordam |
| Azibo / TurboTenant (AQSh) | Yadro bepul; pul xizmatlardan: skrining $39.99–55, shartnoma $29.99–59, e-imzo $9.99; TurboTenant Premium $149–199/yil (https://softwarefinder.com/property-management-software/azibo, https://support.turbotenant.com/en/articles/4003980-is-there-a-cost-to-sign-up-for-turbotenant) | Bepul ijara yig'imi + xizmatlar orqali monetizatsiya (AQSh to'lov infratuzilmasiga bog'liq model) |
| Landlord Studio | GO bepul (3 birlik), PRO $12/oy + $1/birlik (https://www.landlordstudio.com/pricing) | Freemium: 3 obyekt bepul; ularning to'lov xizmatini yoqsangiz — cheksiz bepul birlik |
| АрендаSoft (Rossiya, tijoriy ijara) | Narx ochiq emas (https://arendasoft.ru/about/) | Tarif stavkalari asosida **avtomatik hisoblash (nachisleniya)**, bandlik/qarzdorlik dashboardi, avto-bildirishnomalar |
| Про.рент / EasyRent / ÓDIN (Rossiya) | Turlicha, asosan B2B (https://pro.rent/automation, https://easysoftware.pro/projects/rent/) | Bankdan to'lov importi, **schyotchik (hisoblagich) ko'rsatkichlarini kiritish**, muddat tugashi eslatmalari, SMS/Email |
| O'zbekiston | Maxsus SMB-ilova topilmadi | Davlat tomoni: ijara shartnomasini soliqda ro'yxatga olish (https://ijara.soliq.uz/login); e-ijara.uz faqat qishloq xo'jaligi yerlari. **Bo'sh nisha** |

Muhim xulosa: hech bir raqobatchida bizning asosiy farqimiz — **ikki tomonlama tasdiq (ijarachi to'lovni ilovada tasdiqlaydi, obunasiz)** — yo'q. Ular yo to'lovni platforma orqali o'tkazadi (AQSh), yo bir tomonlama qayd yuritadi (Landlordy, MDH).

### Ijarachi MVP tavsiyasi (ustuvorlik tartibida)

1. Multi-obyekt dashboard: har obyekt bo'yicha balans, qarzdorlik, "kim kechikkan" ro'yxati (barcha raqobatchilarda bor).
2. Oylik ijara jadvali + avto-eslatma (push; keyin Telegram-bot) — RentRedi/Stessa'ning eng ko'p ishlatiladigan funksiyasi.
3. Kommunal va boshqa yig'imlar: erkin qatorlar + schyotchik ko'rsatkichi kiritish (MDH-standarti, Про.рент namunasi) — AQSh ilovalarida kuchsiz, bizda ustunlik bo'ladi.
4. Qisman to'lov va naqd to'lov qaydi — ikki tomonlama tasdiq bilan (RentRedi'da naqd opsiyasi bor, lekin tasdiqsiz).
5. Depozit (zaklad/zalog) alohida hisobda ko'rsatish.
6. Kvitansiya/chek generatsiyasi: matn yoki PDF qilib messenjerda ulashish (Landlordy/Rentila modeli — Telegram'ga mos).
7. Ijarachi tomoni bepul: mavjud Trust link-modeli ustiga quriladi; ilovasiz mijoz uchun ulashiladigan link/PDF fallback.
8. Keyinroq (v2): shartnoma shabloni + soliqda ro'yxatga olish eslatmasi (ijara.soliq.uz), hisobotlar/eksport.

$13/oy narxi global fonda o'rtacha (TenantCloud $15, RentRedi $9–20, Stessa $12) — O'zbekiston uchun yuqoriroq seziladi, lekin "ijarachi cheksiz + tasdiqlangan daftar" qiymati bilan oqlanadi; yillik chegirma tarifini ko'zda tuting.

## 2) To'yxona moduli — raqobatchilar

### Jadval

| Nom | Narx | Asosiy funksiyalar |
|---|---|---|
| Planning Pod (AQSh) | Venue plan $149/oy; Planner $49–74/oy (https://www.capterra.com/p/125947/Planning-Pod/pricing/) | Bron kalendari, lead/CRM, taklifnoma+shartnoma+e-imzo, invoys va to'lovlar, **F&B paketlar, menyu, BEO**, zal sxemalari (floor plan) |
| Tripleseat (AQSh) | ~$300–500/oy bitta zal uchun (ochiq emas, foydalanuvchilar xabari) (https://pricingnow.com/question/tripleseat-pricing/) | Rangli bron kalendari, lead qabul, BEO, e-imzo va to'lovlar, ko'p-zal hisobotlari |
| Event Temple (Kanada) | Individual narx (https://hoteltechreport.com/meetings-and-events/event-management-software/event-temple) | Mehmonxona/zallar uchun sotuv pipeline, e-taklifnomalar, raqamli shartnomalar, guruh bronlari |
| HoneyBook (AQSh, umumiy servis-biznes) | $29/$49/$109/oy yillik (https://www.honeybook.com/pricing) | Smart Files: taklifnoma+shartnoma+invoys bitta havolada, mijoz portali, avans/bo'lib to'lash jadvali, avtomatlashtirish |
| Releventful (AQSh) | Ochiq emas, "arzon" deb baholanadi (https://www.releventful.com/industries/event-venue-software) | Venue-first: to'lovlar, ikki tomonlama SMS, 2D/3D zal sxemasi, mobil ilova |
| EasyWeek (MDH) | Bepul tarif + Basic/Pro/Enterprise (https://easyweek.ru/biz/pricing/, https://easyweek.ru/solutions/banquet-hall) | Banket zali bron kalendari, "units" (bir nechta zal/stol) boshqaruvi, onlayn-yozilish vidjeti |
| AppEvent (Rossiya) | Start bepul; Profi 490 RUB/oy/foydalanuvchi (~$5) (https://appevent.ru/price) | Tadbirlar hisobi, **smeta (tadbir kalkulyatsiyasi)**, mijozlar bazasi, bron vidjeti, zal bandligi nazorati |
| O'zbekiston | SaaS topilmadi | Faqat kataloglar (https://top.uz/uz/section/toykhana) — bron/avans/xizmatlar boshqaruvi uchun maxsus mahsulot yo'q. **Bo'sh nisha** |

Muhim xulosa: G'arb narxlari $149–500/oy — bizning $24/oy juda raqobatbardosh; MDH'da AppEvent ~$5/oy bor, lekin unda ikki tomonlama tasdiqlangan moliyaviy daftar va to'yxonaga xos per-person narxlash yo'q.

### To'yxona MVP tavsiyasi (ustuvorlik tartibida)

1. Bron kalendari: kun + smena (kunduzgi/kechki) darajasida bandlik, bir egada bir nechta zal (Tripleseat'dagi rangli kalendarning soddalashtirilgan varianti).
2. Avans (zadatok) va bo'lib to'lash jadvali: har bron uchun to'lov grafigi, qolgan qarz, ikki tomonlama tasdiq (HoneyBook'ning payment schedule analogi, lekin naqd/UZS bilan).
3. Ikki narx modeli: (a) zalni butunlay ijaraga berish; (b) odam boshiga narx + "nima kiradi" ro'yxati — bu **hech bir raqobatchida tayyor ko'rinishda yo'q**, mahalliy differensiator.
4. Xizmat qo'shimchalari (add-on): bezak, tort, xona, artist va h.k. — smeta ichida alohida qatorlar (AppEvent smeta modeli).
5. Bron holatlari: so'rov → band (avans olindi) → o'tkazildi/bekor (bekor bo'lsa avans siyosati).
6. Mijoz tomoni bepul: bron tafsiloti + to'lov tarixini link orqali ko'rish va tasdiqlash.
7. Keyinroq (v2): mehmonlar soni bo'yicha yakuniy hisob-kitob (per-person × son), oddiy menyu/BEO-lite varaq, bandlik/daromad hisoboti. 3D sxemalar, floor-plan — kerak emas (ortiqcha).

## 3) Freemium/obuna naqshlari — saboqlar

- **Kunlik/oylik limit yaxshi ishlaydi**: Splitwise bepulda kuniga 3 ta xarajat, 4-chisida paywall — Pro $4.99/oy; aynan shu limit asosiy konversiya dvigateli (https://feedback.splitwise.com/knowledgebase/articles/2010350-why-am-i-seeing-an-expense-limit). Bizning "5 ta yozuv bepul" shunga mos, lekin **umrbod 5 ta emas, oyiga 5 ta** qilish konversiyani barqaror ushlaydi.
- **Yozuv-limitli arzon tarif**: Xero Early $25/oy — oyiga 20 invoys, 5 bill; limitga tegib turgan mijoz o'zi upgrade qiladi (https://www.xero.com/us/pricing-plans/early/).
- **Obyekt-limitli freemium**: Landlordy bepulda 1 obyekt + cheklangan yozuvlar, so'ng Mini/Plus/Pro darajalar (https://landlordy.com/pricing.html); Landlord Studio GO — 3 birlik bepul, PRO $12/oy (https://www.landlordstudio.com/pricing). "5 yozuv" bilan birga "1 obyekt / 1 zal bepul" chegarasi ham sinovga arziydi.
- **Bepul yadro + xizmatdan pul**: Azibo/TurboTenant to'liq bepul, pulni skrining/shartnoma/to'lov komissiyasidan oladi — bu model AQSh to'lov infratuzilmasiga bog'liq, naqd bozorda ishlamaydi; bizga obuna modeli to'g'ri.
- **Khatabook saboqlari**: bepul daftar bilan ommaviy baza yig'ib, keyin premium obuna (avto-eslatma, hisobotlar, multi-device) va to'lov xizmatlariga o'tgan (https://startuptalky.com/khatabook-business-model/). "Bir tomon to'laydi, ikkinchi tomon bepul" bizdagi kabi — bu qabul qilingan naqsh.
- **UI-naqsh**: menyu kartochkalarida 0/5 hisoblagich + qulflangan modulda qulf va narx ko'rsatish — Splitwise paywall amaliyotiga mos; qulf bosilganda "nima ochiladi" ro'yxatini ko'rsatish konversiyani oshiradi.

## 4) Bizda yo'q, ammo muhim funksiyalar (ustuvorlik bilan)

**P0 — MVP'siz chiqmaslik kerak:**
- Avto-eslatmalar (to'lov kuni yaqin/o'tdi) — barcha raqobatchilarning №1 funksiyasi; bizda push bor, jadvalga bog'langan eslatma yo'q.
- Qisman to'lov va qoldiq balans ko'rinishi (RentRedi, АрендаSoft standarti).
- Kvitansiya/chekni matn yoki PDF qilib ulashish — Telegram-first mijozlar uchun (Landlordy modeli): ilovasiz tomon ham hujjat oladi.
- UZS naqd birinchi o'rinda; hech qanday to'lov-protsessing majburiyatisiz qayd + tasdiq.

**P1 — birinchi 1–2 relizda:**
- Telegram-bot bildirishnomalari va tasdiq-linklari (ilova o'rnatmagan ijarachi/mijoz uchun past-texnologiyali yo'l) — G'arb raqobatchilarida yo'q, bizning bozorda hal qiluvchi.
- Kommunal + schyotchik ko'rsatkichlari moduli (Про.рент/EasyRent naqshi) — MDH'da odat, AQSh ilovalarida zaif.
- Depozit/avans alohida hisob turi sifatida (qaytariladigan summa mantig'i).
- To'yxona bron kalendari smena darajasida + avans grafigi (yuqoridagi MVP).
- Click/Payme to'lov linki generatsiyasi (to'lov bizdan o'tmaydi, faqat link + tasdiq) — komissiyasiz qulaylik.

**P2 — keyinroq:**
- Shartnoma shablonlari + soliq ro'yxati eslatmasi (ijara.soliq.uz konteksti).
- Hisobotlar: obyekt/zal bo'yicha oylik daromad, bandlik foizi, qarzdorlik reytingi.
- E-imzo (hozircha ikki tomonlama tasdiqning o'zi kifoya), menyu/BEO-lite, mavsumiy narxlash.
- Qilmaslik kerak: 3D zal sxemalari, listing-sindikatsiya, tenant-skrining — bozorga mos emas.

**Strategik xulosa:** ikkala nishada ham O'zbekistonda tayyor mahsulot yo'q; bizning himoya chizig'imiz — mavjud ikki tomonlama tasdiqlangan daftar ustiga qurilgan, ikkinchi tomoni bepul modullar. Narxlar ($13/$24) global raqobatchilardan ancha past, MDH'dagi arzon vositalardan esa funksional (tasdiq + naqd + Telegram) jihatdan ustun turadi.

## Manbalar

- [TenantCloud pricing/features](https://www.softwareadvice.com/property/tenantcloud-profile/), [GetApp TenantCloud](https://www.getapp.com/real-estate-property-software/a/tenantcloud/)
- [DoorLoop GetApp](https://www.getapp.com/real-estate-property-software/a/doorloop/), [DoorLoop Software Advice](https://www.softwareadvice.com/property/doorloop-profile/)
- [RentRedi pricing](https://rentredi.com/pricing), [RentRedi tenants](https://rentredi.com/tenants/)
- [Landlordy pricing](https://landlordy.com/pricing.html), [Landlordy App Store](https://apps.apple.com/us/app/landlordy-property-management/id975031084)
- [Stessa Software Advice](https://www.softwareadvice.com/property/stessa-profile/), [Stessa Capterra](https://www.capterra.com/p/181042/Stessa/)
- [Rentila pricing](https://www.rentila.com/pricing)
- [Azibo Software Finder](https://softwarefinder.com/property-management-software/azibo), [Is Azibo free](https://www.azibo.com/blog/is-azibo-really-free-for-landlords)
- [TurboTenant cost](https://support.turbotenant.com/en/articles/4003980-is-there-a-cost-to-sign-up-for-turbotenant)
- [Landlord Studio pricing](https://www.landlordstudio.com/pricing), [Unlimited free units on GO](https://help.landlordstudio.com/en/articles/8389595-unlock-unlimited-free-units-on-go)
- [АрендаSoft](https://arendasoft.ru/about/), [Про.рент](https://pro.rent/automation), [EasyRent](https://easysoftware.pro/projects/rent/), [Домиленд](https://domyland.ru/)
- [ijara.soliq.uz](https://ijara.soliq.uz/login), [e-ijara.uz](https://e-ijara.uz/), [AGRO.UZ E-IJARA](https://www.agro.uz/e-ijara-axborot-tizimi/)
- [Planning Pod pricing Capterra](https://www.capterra.com/p/125947/Planning-Pod/pricing/), [Planning Pod GetApp](https://www.getapp.com/customer-management-software/a/planning-pod/)
- [Tripleseat pricing reports](https://pricingnow.com/question/tripleseat-pricing/), [Tripleseat Software Advice](https://www.softwareadvice.com/event-management/tripleseat-profile/)
- [Event Temple HotelTechReport](https://hoteltechreport.com/meetings-and-events/event-management-software/event-temple)
- [HoneyBook pricing](https://www.honeybook.com/pricing)
- [Releventful venue software](https://www.releventful.com/industries/event-venue-software)
- [EasyWeek banquet hall](https://easyweek.ru/solutions/banquet-hall), [EasyWeek pricing](https://easyweek.ru/biz/pricing/), [AppEvent price](https://appevent.ru/price), [AppEvent restaurant](https://appevent.ru/restaurant)
- [Top.uz to'yxona katalogi](https://top.uz/uz/section/toykhana)
- [Splitwise expense limit](https://feedback.splitwise.com/knowledgebase/articles/2010350-why-am-i-seeing-an-expense-limit), [Xero Early plan](https://www.xero.com/us/pricing-plans/early/), [Khatabook business model](https://startuptalky.com/khatabook-business-model/)

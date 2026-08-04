# «Har obyekt uchun $24/oy» ni IAP orqali sotish — tadqiqot (2026-08-04)

Savol: To'yxona moduli «$24 HAR ZALGA» deb narxlangan. Do'konlar «miqdorli» (quantity) obunani qo'llab-quvvatlaydimi?

## Qisqa javob: YO'Q — ikkala do'konda ham

**Apple (StoreKit, auto-renewable):**
- `quantity` opsiyasi **faqat consumable va non-renewing** obunalarga tegishli — auto-renewable obunaga umuman qo'llanilmaydi ([hujjat](https://developer.apple.com/documentation/storekit/product/purchaseoption/quantity(_:))).
- Bir subscription group ichida bir vaqtda **faqat bitta** obuna bo'ladi ([App Store Connect help](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/)).
- Turli guruhlardagi obunalar parallel bo'lishi mumkin va alohida hisoblanadi — «N zal = N guruh» hackining yagona asosi, ammo foydalanuvchi Settings'da N ta obuna ko'radi va N marta bekor qiladi.
- Yagona rasmiy istisno — **Advanced Commerce API**, lekin Apple ruxsati shart va eligibility 3 ta biznes modeli bilan cheklangan; bizning holat tasdiqlanishi **noma'lum**.

**Google Play:**
- Multi-quantity **faqat one-time mahsulotlar** uchun (BPL 4.0+), obunalarga emas.
- «Subscription with add-ons» (BPL 8+) bir nechta obunani bog'laydi, lekin ro'yxatdagi har element **unikal productId** bo'lishi shart — bitta SKU'ni 3 marta qo'shib bo'lmaydi.
- Egallangan SKU'ni qayta olishga urinish → `ITEM_ALREADY_OWNED` (kod 7).
- Flutter `in_app_purchase` da quantity faqat iOS consumable uchun; add-ons/Advanced Commerce **surface qilinmagan**.

**Tashqi to'lov (veb-checkout):** O'zbekiston storefront'ida Apple qoidasi 3.1.1(a) bo'yicha **taqiqlangan** (link-out entitlementlari faqat ayrim storefrontlarda; AQSh/EI rejimlari 2026-da o'zgarmoqda — tayanmang). Apple 3.1.3(f) «Free Stand-alone Apps» yo'li bor, lekin u ilovada **umuman xarid bo'lmasligini** talab qiladi — ya'ni $5/$8 modul obunalarini ham IAP'da sota olmaymiz. Aralashtirish = rad etilish riski.

## Tavsiya: pog'onali SKU (tiered), 3 daraja, BITTA Apple guruhida

| SKU | Zal | Narx/oy |
|---|---|---|
| `trust_toyxona_monthly` (mavjud) | 1 | $24 |
| `trust_toyxona3_monthly` | 2–3 | ~$59 |
| `trust_toyxona10_monthly` | 4–10 | ~$169 |

Sabablari: 1 zalli ega uchun ishqalanish **nol** (bugungi $24 aynan qoladi); bugungi stack bilan qo'shimchasiz ishlaydi; review riski nol; Apple'da uchala SKU bitta guruhda bo'lsa «bir guruh — bir obuna» qoidasi upgrade/downgrade'ni o'zi hal qiladi (ikki marta hisoblash imkonsiz); qaror qaytariladigan.

**Qilmang:** bitta SKU'ni N marta sotib olishga urinish — Apple dialog bilan to'xtatadi, Play `ITEM_ALREADY_OWNED` qaytaradi; bu «pul olinib obuna berilmaydi» bug sinfini qayta tug'diradi.

## Qabul qilinsa, kodga ta'siri

- `src/lib/subscription.js` — `MODULES.toyxona.per_unit` marker **daraja modeliga** aylanadi (SKU → `max_halls`); `productIdForModule()` modul + daraja bo'yicha SKU beradi (klient hamon faqat kalit yuboradi — anti-fraud qoidasi buzilmaydi).
- Yangi migratsiya (masalan `022_module_sub_units.sql`): `module_subs.max_units`. **020 tahrirlanmaydi.**
- `src/routes/toyxona.js` — zal yaratishda `max_units` bo'yicha majburlash (kvota middleware naqshi).
- `mobile/lib/iap.dart` — SKU xaritasi 4 → 6; paywall'da daraja tanlash. Narx qoidasi saqlanadi: **faqat StoreKit'dan kelgan narx ko'rsatiladi**.

## ⚠️ Alohida diqqat: Play Billing Library 8 muddati

2026-08-31 dan barcha yangi va yangilanadigan ilovalar **BPL 8+** bo'lishi shart ([release notes](https://developer.android.com/google/play/billing/release-notes)). Bizda `in_app_purchase_android` **0.5.0** (BPL 8.0.0 ishlatadi — tadqiqot ma'lumoti), ya'ni **muvofiq ko'rinadi**. Nashrdan oldin bir marta tasdiqlang.

## Tasdiqlanmagan / kuzatuvda

(i) Apple'ning faol SKU'ni qayta xarid qilishdagi aniq StoreKit natijasi rasmiy hujjatda yo'q (forum amaliyoti); (ii) Advanced Commerce API bizning use-case uchun tasdiqlanishi noma'lum; (iii) AQSh/EI link-out rejimi 2026-da o'zgarmoqda; (iv) Apple tomonda O'zbekiston merchant/payout holati tekshirilmadi.

# 2026-09-08 — To'yxona v2: DB + backend + Flutter (analyze QOLDI)

PO ro'yxati (6/7/8/15 — rasm, katalog, mijoz o'zi bron, sharh — OLIB TASHLANDI):
1 stollar+stol menyusi · 2 servislar katalogi · 3 bonus · 4 telefon→ism autofill ·
5 bekor jarimasi · 9 migratsiya 024 · 10 chek/PDF · 11 avans/qoldiq eslatma ·
12 slot hold · 13 minimal avans % · 14 ko'p zal tarifi · 16 analitika · 17 off-app mijoz.

**MUHIM:** 21-avgustdagi `price_mode` (kishi boshiga / butun to'yga) repo'da YO'Q edi
(o'sha zip qo'llanmagan) — shu sessiyada 024 ichida qayta kiritildi.

## Bajarildi (bulutda, repo klon: commit 43f282b ustida; npm test 157/157)

### `supabase/migrations/024_toyxona_v2.sql` (QO'LDA, deploy'dan OLDIN)
- halls: `price_mode` guest/total, `total_price` (podklyuch), `deposit_pct` 0..100, `cancel_policy` jsonb `[{days,pct}]`
- hall_menus = STOL TURLARI: `seats`, `note`; yangi `hall_menu_items` (title, qty matn)
- yangi `hall_services` (katalog: title, price, note, hall_id NULL=umumiy)
- booking_items: `service_id` (set null), `is_bonus`; amount check `>= 0`
- bookings: `price_mode`, `total_price`, `cancelled_at`, `cancel_reason`, `cancel_penalty` (SNAPSHOT),
  `hold_until`, `client_user_id`, `final_reminder_sent_at`, `hold_reminder_sent_at`
- booking_payments.kind + `'qaytarim'`
- notifications.type + `'toy_hold'`, `'toy_due'`
- BACKFILL: client_phone → faqat raqam; client_user_id ← profiles.phone
- RLS 021 naqshi (policy yo'q, service_role)

### `src/routes/toyxona.js` (+739)
Sof: `computeTotals` (total rejimi, bonus alohida, qaytarim ayiriladi, penalty/refundDue),
`depositMin`, `parseCancelPolicy`, `cancelPenalty`, `normPhone`, `foldSummary` analitika
(penalties/refunded/bonus/guests/avgCheck/topServices), `PRICE_MODES`, `KINDS`.
Endpointlar:
- halls POST/PATCH: `price_mode, total_price, deposit_pct, cancel_policy`; GET embed menus.items
- menus POST/PATCH: `seats, note, items[]` (items = TO'LIQ almashtirish)
- **yangi** `GET/POST /services`, `PATCH/DELETE /services/:id`
- **yangi** `GET /clients?phone=` → `{client_name, bookings, last_event_date, in_trustbook}` | null
- bookings POST: `price_mode, total_price, items[] ({service_id|title, amount, qty, is_bonus}), hold_hours`;
  telefon normallashadi; `client_user_id` avtomatik; javobda `deposit_min, deposit_short`
- bookings PATCH: `price_mode, total_price, hold_until`; `status:'bekor'` → jarima hisobi (`cancel` obyekt)
- **yangi** `GET /bookings/:id/cancel-preview` → `{paid, penalty, refund, daysLeft, policy, total}`
- **yangi** `POST /bookings/:id/cancel {reason?, penalty?, refund_now?}`
- items POST: `service_id`/`is_bonus`; **yangi** `PATCH /items/:id {is_bonus, qty, amount}`
- payments POST: `kind:'qaytarim'` (paid'dan oshmasin → 400 REFUND_OVER); to'lov kelsa hold tozalanadi
- summary: `occupancyPct` + foldSummary analitikasi

### `src/services/toyxonaSweeper.js` (yangi, index.js'da yoqilgan)
Soatlik, 09–20 Toshkent: hold o'tgan to'lovsiz 'band' → 'bekor' + egaga `toy_hold`;
to'yga ≤3 kun (TOY_FINAL_REMINDER_DAYS) va left>0 → egaga `toy_due` (bir marta).

### `src/services/otp.js` — linkPartners: login'da bookings.client_user_id telefon bo'yicha bog'lanadi.

## NARX QARORI (PO 2026-09-08): HAR ZAL $21/oy
- `subscription.js`: `MODULES.toyxona.per_unit`, `unit_products {1..5}` → `trust_toyxona_monthly`, `trust_toyxona_2_monthly` ($42) … `_5_monthly` ($105); `productIdForModule(module, units)`, `unitsForProduct`, `activeUnits`; `/api/subs/status` → `per_unit, units, max_units`.
- `profile.js` verify: klient `units` yuboradi; `module_subs.units` (024) yoziladi.
- `toyxona.js hallLimitError`: chegara = faol obuna zal soni (obunasiz 1); 403 HALL_LIMIT + units/max_units.
- **Do'konlarda 4 ta yangi SKU yaratish KERAK** (ASC + Play): `trust_toyxona_2_monthly` $41.99, `_3` $62.99, `_4` $83.99, `_5` $104.99 (Apple narx nuqtalari .99).

## Flutter (bulutda yozildi, `flutter analyze/test` QOLDI)
- `toyxona_data.dart`: `MenuItemRow`, `Menu.seats/items`, `Hall.priceMode/totalPrice/depositPct/cancelPolicy`, `CancelRule`, `HallService`, `CancelPreview`, `ClientHint`, `BookingItem.serviceId/isBonus`, `Booking.priceMode/totalPrice/holdUntil/cancelReason/cancelPenalty/inTrustbook` + `bonus/refunded/refundDue/onHold`, `ToySummary` analitika; repo: `servicesFor`, `lookupClient`, `cancelPreview`, `cancelBooking`, `setItemBonus`, `create/patch/deleteService`, `createMenu(seats, items)`, `createHall(extra)`; sof: `toyCancelPenalty`, `toyDepositMin`, `toyPhoneDigits`, `toyParsePolicy`.
- `screens/toyxona.dart`: bron formasi — AVVAL telefon (500ms debounce → `/clients` → ism autofill, «oldin N ta bron» + Trustbook belgisi), narx rejimi toggle, podklyuch narxi, stol turi taomlari eslatmasi, servis chiplari (1-bosish tanlash, 2-bosish bonus), min avans/hold eslatmasi, jonli hisob (+servislar); tafsilot — hold/Trustbook/sabab belgilari, bonus badge (bosilsa almashadi), jarima/qaytarim/bonus qatorlari, min avans eslatmasi, xizmat formasida katalog chiplari + bonus checkbox, «Chek (PDF)» tugmasi; bekor varag'i (`_cancelModal`: kun, tushgan pul, jarima (tahrirlanadi), qaytarish, «hozir qaytardim», sabab); oy xulosasida analitika chiplari; to'yxona formasi — rejim, podklyuch narxi, min avans %, jarima jadvali (30/7/0 kun); stol turi — sig'im + taomlar (har qatorda bittadan); servislar katalogi ekrani (`_servicesView` + modal); «+ zal» doim ko'rinadi → 403 → `store.openPaywallUnits_('toyxona', n)`.
- `ui.dart`: `Tx.strike`, `ListRow.subtitle`. `store.dart`: `openPaywallUnits_`, `paywallUnits_`, vals `paywallUnits`; `paywallBuy_` units. `iap.dart`: `toyxonaUnitProductIds`, `productIdFor`, `unitsOf`, `buyModule(units:)`, `moduleOf` unit SKU. `api.dart`: `verifyAppleBody(units:)`. `paywall_sheet.dart`: zal soni stepper, `kModCapUnits.toyxona=5`.
- `toyxona_receipt.dart` (YANGI): `shareBookingReceipt` — A4 PDF (PdfGoogleFonts NotoSans, oflaynda Helvetica), `Printing.sharePdf`. `pubspec`: `pdf ^3.11.1`, `printing ^5.13.3` → **`flutter pub get` SHART**.
- l10n: `toyxona_l10n.dart` +66 kalit × 6 til (paritet skript bilan tekshirildi), `tyPriceMode`, `tyPolicyDays`, `tyPayKind('qaytarim')`; `l10n.dart`: `pwUnitsPrice/pwUnitsN/pwUnitsEach`, `pwCapToy` yangi matn ({price}).
- Push `toy_hold`/`toy_due` bosilganda to'yxona bo'limini ochish — `openFromNotif` (store.dart) da HALI YO'Q (audit 09-07 #8 bilan birga qilinsin).

## Bajarilmadi (keyingi sessiya)
- `flutter pub get` + `flutter analyze` + `flutter test` (Windows'da) — kod ko'r yozilgan, xato bo'lishi tabiiy; testlar: `toyxona_data_test.dart` l10n paritet/`House.fromJson` uslubida yangi maydonlar uchun test yo'q.
- Push `toy_hold`/`toy_due` → to'yxona bo'limi (store.openFromNotif).
- Do'konlarda 4 ta SKU.
- Mobil eski build formatli telefon yuboradi — backend normPhone qabul qiladi, muammo yo'q.

## Deploy tartibi
1. Supabase SQL Editor → `024_toyxona_v2.sql` (destructive warning: constraint drop/add — normal).
2. `cd D:\trust` → `git add -A` → `git commit -m "toyxona v2 (024): stollar, servislar, bonus, jarima, hold, har zal $21"` → `git push` (Render).
4. `cd D:\trust\mobile` → `flutter pub get` → `flutter analyze` → `flutter test` → xatolarni menga yuboring.
3. Render: ixtiyoriy env `TOY_FINAL_REMINDER_DAYS` (default 3).

# trust

**Oldi-Berdi** — ikki tomonlama tasdiqli hisob-kitob. Har bir yozuv kod bilan tasdiqlanib, o'chirilmas dalilga aylanadi.

## Tarkib
- `src/` — Node.js + Express backend (API)
- `mobile/` — Flutter mobil ilova (Android + iOS, UI prototip bilan 1:1)
- `supabase/migrations/` — PostgreSQL sxema (001 init, 002 trust modeli)

## Stack
Node.js + Express · Supabase (PostgreSQL, Auth) · devsms.uz (O'zbekiston OTP) · Flutter

## Ishga tushirish (backend)
```bash
npm install
cp .env.example .env   # kalitlarni to'ldiring (SOZLASH.md)
npm run dev
```
Supabase'da `supabase/migrations/*.sql` ni SQL Editor orqali ishga tushiring.

## Ma'lumot modeli (v2)
- **profiles** — foydalanuvchilar
- **partners** — hamkorlar (owner ↔ counterparty), on_trust, archived
- **operations** — ikki tomonlama tasdiqli yozuvlar. type: qarz_berdim / qarz_oldim / qaytardim / menga_qaytarildi. Kod bilan tasdiqlanadi → dalil
- **op_history** — o'zgarishlar tarixi (o'chirilmaydi)
- **edit_requests** — o'zgartirish so'rovlari (ikki tomon roziligi)
- **expenses** — shaxsiy xarajat/daromad (Xarajat chat)
- **limits** — oylik limit
- **notifications** — bildirishnomalar
- **module_subs** (020) — modul obunalari (xarajat/qarz/ijarachi/toyxona), `active_until` bo'yicha
- **halls · hall_menus · bookings · booking_items · booking_payments** (021) — to'yxona moduli, hammasi ega (`user_id`) bo'yicha
- **rent_houses · rent_charges · rent_payments** (022) — ijaradagi uylar moduli, hammasi ega (`user_id`) bo'yicha

## API

### Auth
| Metod | Yo'l | Tavsif |
|---|---|---|
| POST | `/api/auth/send-otp` | `{ phone }` — +998 → devsms, boshqalar → Supabase |
| POST | `/api/auth/verify-otp` | `{ phone, code }` → `access_token` |

### Profil / Hamkorlar
| Metod | Yo'l | Tavsif |
|---|---|---|
| GET/PUT | `/api/profile/me` | Profil |
| GET | `/api/partners` | Hamkorlar (balans + pending + `counterparty_deleted` bilan); `?period_from=&period_to=` (epoch ms) → har qatorda `period: { to_me, by_me, repaid_to_me, repaid_by_me, count }` |
| POST | `/api/partners` | `{ name, counterparty_phone, on_trust }` |
| GET | `/api/partners/:id` | Hamkor + operatsiyalar |
| POST | `/api/partners/:id/remind` | Qarshi tomonga eslatma (3 soat cooldown) |
| PATCH | `/api/partners/:id` | `{ name?, archived? }` — nom/arxiv |

### Operatsiyalar
| Metod | Yo'l | Tavsif |
|---|---|---|
| POST | `/api/operations` | `{ partner_id, type, amount, note? }` → on_trust: pending + confirm_code; aks holda unconfirmed (daftar yozuvi) |
| POST | `/api/operations/:id/confirm` | `{ code }` — 2-tomon tasdiqlaydi → dalil |
| POST | `/api/operations/:id/cancel` | Faqat pending/unconfirmed — dalil o'chirilmas |
| POST | `/api/operations/:id/archive` | Dalil arxivga (balansda qoladi) |
| GET | `/api/operations/:id` | Dalil (tarix + so'rovlar bilan) |
| POST | `/api/operations/:id/edit-request` | `{ new_amount, new_note? }` |
| POST | `/api/operations/:id/edit-request/:reqId/resolve` | `{ approve }` |

Status modeli: `pending → confirmed → archived`, bir tomonlama yozuvlar `unconfirmed`, bekor qilinganlar `cancelled`. Balans = confirmed + unconfirmed + archived (mobil ilova bilan bir xil).

### Xarajat / Limit / Bildirishnoma
| Metod | Yo'l | Tavsif |
|---|---|---|
| GET/POST | `/api/expenses` | Shaxsiy yozuvlar |
| GET | `/api/expenses/summary/month` | Bu oy: daromad/xarajat/sof/toifalar/limit |
| GET/PUT | `/api/limits` | Oylik limit |
| GET | `/api/notifications` | Bildirishnomalar |
| GET | `/api/notifications/counts` | Har hamkor bo'yicha o'qilmagan: `{ [partner_id]: { count, total_amount, last_amounts } }` |
| POST | `/api/notifications/read` | `{ partner_id }` — shu hamkor bildirishnomalarini o'qildi qilish (idempotent) |
| POST | `/api/notifications/:id/read` · `/read-all` | O'qildi |

### Obuna (modul-boshiga, PO 2026-08-04)
| Metod | Yo'l | Tavsif |
|---|---|---|
| GET | `/api/subs/status` | `{ legacy_premium: {active, until}, modules: [{module, active, active_until, soon, price_usd, product_id, used, free_limit}] }` — xarajat $5 · qarz $8 · ijarachi $13 (maks 5 uy) · toyxona $24 (1 ta to'yxona). Bepul: har modulda 5 yozuv |
| POST | `/api/profile/me/subscription/verify` | `{ platform, module?, purchase_token \| receipt_data }` — `module` berilmasa eski $9 premium oqimi. `product_id` KLIENTDAN OLINMAYDI (serverdagi katalogdan) |

Eski `$9 premium` (`profiles.premium_until`) — muddati tugaguncha BARCHA modullarga kirish (grandfather). Modul obunalari: `module_subs` (020 migratsiya).

### To'yxona (021 migratsiya)
| Metod | Yo'l | Tavsif |
|---|---|---|
| GET | `/api/toyxona/halls` | To'yxona (venue) + ichida narx turlari (`menus[]`). Bitta hisobda 1 ta to'yxona |
| POST/PATCH | `/api/toyxona/halls` · `/halls/:id` | To'yxona qo'shish/tahrirlash (`name, capacity, price_per_guest, archived, sort`). O'chirish YO'Q — arxivlash |
| GET/POST | `/api/toyxona/halls/:hallId/menus` | Narx turlari: «Oddiy 150 000», «Lyuks 200 000» — bir marta yaratiladi, bron qilishda tanlanadi |
| PATCH/DELETE | `/api/toyxona/menus/:id` | Narx turini tahrirlash/o'chirish. Eski bronlar TEGILMAYDI (narx va nom bron ichida snapshot) |
| GET | `/api/toyxona/bookings?from&to&hall_id` | Bronlar + `items[]`, `payments[]`, `totals{food,extras,total,paid,left}`. Standart — joriy oy (Toshkent vaqti); `hall_id=none` — to'yxonasiz yozuvlar |
| POST | `/api/toyxona/bookings` | Yangi bron. Sana+vaqt band bo'lsa `409 SLOT_TAKEN` — ustma-ust bron BAZA darajasida imkonsiz |
| PATCH/DELETE | `/api/toyxona/bookings/:id` | Tahrirlash (sana/vaqt/zal o'zgarsa qayta tekshiriladi) · o'chirish. Yumshoq bekor — `status:'bekor'` |
| POST/DELETE | `/api/toyxona/bookings/:id/items` · `/items/:itemId` | Qo'shimcha xizmatlar smetasi (musiqa, fotograf, tort…) |
| POST/DELETE | `/api/toyxona/bookings/:id/payments` · `/payments/:payId` | Avans va yakuniy to'lovlar. Avans kelishi bilan `band → tasdiq`, qoldiq 0 bo'lsa `→ yakun` |
| GET | `/api/toyxona/summary?from&to&hall_id` | `{count, total, paid, left, byStatus}` — pul hisobida `bekor` qatnashmaydi |

Vaqt (slot): `nahor` (nahorgi osh) · `tushlik` · `kechki`. Holat: `band → tasdiq → yakun`, yoki `bekor`. Pul — UZS butun son; bron ichidagi `price_per_guest`/`menu_title` SNAPSHOT (narx ro'yxati keyin o'zgarsa ham tarix o'zgarmaydi). Bepul: 5 bron (`FREE_TOYXONA_BOOKINGS`), keyin modul obunasi ($24/oy). Bitta hisobda **1 ta to'yxona** (`403 HALL_LIMIT`) — ko'proq kerak bo'lsa boshqa telefon raqami bilan alohida hisob (PO 2026-08-04).

### Ijaradagi uylar (022 migratsiya)
| Metod | Yo'l | Tavsif |
|---|---|---|
| GET | `/api/ijara/houses` | Uylar + har biriga umrbod yakun `totals{charged,paid,left}`; `limit:{max_houses,used}` — arxivlanganlar ham qaytadi |
| POST | `/api/ijara/houses` | Yangi uy (`name, tenant_name, tenant_phone, rent_amount`). 5 ta faol uy bo'lsa `403 HOUSE_LIMIT` — QAT'IY chegara, obuna ochmaydi |
| PATCH | `/api/ijara/houses/:id` | Tahrirlash (`name, tenant_name, tenant_phone, rent_amount, archived, sort`). O'chirish YO'Q — arxivlash. Arxivdan qaytarish ham chegaraga kiradi |
| GET | `/api/ijara/charges?from&to&house_id` | Hisoblangan to'lovlar + `payments[]`, `totals{charged,paid,left}` va `unallocated[]` (biriktirilmagan to'lovlar). Standart — joriy oy (Toshkent vaqti) |
| POST | `/api/ijara/charges` | Yangi hisob-kitob (`house_id, amount?, period?, kind?, title?, due_date?`). Bepul kvota tugasa `402 SUB_EXPIRED` + `module:'ijarachi'` |
| PATCH/DELETE | `/api/ijara/charges/:id` | Tahrirlash · yumshoq bekor (`status:'bekor'`). Bekor qilingan yozuv kvota YEMAYDI va pul yakuniga kirmaydi |
| POST/DELETE | `/api/ijara/payments` · `/payments/:id` | To'lov kiritish/olib tashlash. `charge_id` berilsa yozuv statusi qayta hisoblanadi, berilmasa — taqsimlanmagan to'lov |
| GET | `/api/ijara/summary?from&to&house_id` | `{count, countActive, charged, paid, left, byStatus}` — pul hisobida `bekor` qatnashmaydi |

Tur (kind): `ijara` · `kommunal` · `boshqa`. Holat: `kutilmoqda → tolangan`, yoki `bekor`. Oy — `period` ('YYYY-MM'), oraliq filtri OY aniqligida (muddatsiz yozuv tushib qolmasin). Ijarachiga AKKAUNT KERAK EMAS — uyda ism + telefon. Pul — UZS butun son. Bepul: 5 hisob-kitob (`FREE_IJARA_CHARGES`), keyin modul obunasi ($13/oy); bitta hisobda ko'pi bilan **5 ta uy** — ko'proq kerak bo'lsa boshqa telefon raqami bilan alohida hisob.

## Tasdiq oqimi
1. Owner operatsiya yozadi → `pending`, 5 xonali `confirm_code` yaratiladi, 2-tomonga bildirishnoma.
2. 2-tomon kodni kiritadi → `confirmed`, o'chirilmas dalil.
3. O'zgartirish faqat `edit-request` + qarshi tomon tasdig'i bilan; eski qiymat tarixda qoladi.
4. Hamkor Trust'ga keyin qo'shilsa — trigger uni telefon raqami bo'yicha mavjud hamkor yozuvlariga avtomatik bog'laydi (`on_trust=true`, egasiga bildirishnoma).

## Deploy

**Render.com (joriy):** repo'da `render.yaml` bor — Dashboard → New → Blueprint → repo tanlang. Region: Frankfurt, health check: `/health`. Maxfiy env qiymatlarni (SUPABASE_*, DEVSMS_TOKEN) Dashboard'da kiriting; `APP_JWT_SECRET` avtomatik yaratiladi. Free planda 15 daqiqa harakatsizlikdan keyin uxlaydi — birinchi so'rov ~30-50 s.

**VPS/Docker (keyingi bosqich):** `Dockerfile` tayyor:
```bash
docker build -t trust-backend .
docker run -d --env-file .env -p 3000:3000 --restart unless-stopped trust-backend
```

Supabase migratsiyalari: `supabase/migrations/001..003` ni SQL Editor'da tartib bilan ishga tushiring (idempotent — qayta yurgizish xavfsiz). Batafsil: `SOZLASH.md`.

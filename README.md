# trust

**Oldi-Berdi** — ikki tomonlama tasdiqli hisob-kitob. Har bir yozuv kod bilan tasdiqlanib, o'chirilmas dalilga aylanadi.

## Tarkib
- `src/` — Node.js + Express backend (API)
- `app/` — Flutter mobil ilova (web deploy: https://jmturaev.github.io/trust/)
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
| GET | `/api/partners` | Hamkorlar (balans + pending bilan) |
| POST | `/api/partners` | `{ name, counterparty_phone, on_trust }` |
| GET | `/api/partners/:id` | Hamkor + operatsiyalar |
| PATCH | `/api/partners/:id` | `{ name?, archived? }` — nom/arxiv |

### Operatsiyalar
| Metod | Yo'l | Tavsif |
|---|---|---|
| POST | `/api/operations` | `{ partner_id, type, amount, note? }` → pending + confirm_code |
| POST | `/api/operations/:id/confirm` | `{ code }` — 2-tomon tasdiqlaydi → dalil |
| POST | `/api/operations/:id/cancel` | Bekor qilish |
| GET | `/api/operations/:id` | Dalil (tarix + so'rovlar bilan) |
| POST | `/api/operations/:id/edit-request` | `{ new_amount, new_note? }` |
| POST | `/api/operations/:id/edit-request/:reqId/resolve` | `{ approve }` |

### Xarajat / Limit / Bildirishnoma
| Metod | Yo'l | Tavsif |
|---|---|---|
| GET/POST | `/api/expenses` | Shaxsiy yozuvlar |
| GET | `/api/expenses/summary/month` | Bu oy: daromad/xarajat/sof/toifalar/limit |
| GET/PUT | `/api/limits` | Oylik limit |
| GET | `/api/notifications` | Bildirishnomalar |
| POST | `/api/notifications/:id/read` · `/read-all` | O'qildi |

## Tasdiq oqimi
1. Owner operatsiya yozadi → `pending`, 5 xonali `confirm_code` yaratiladi, 2-tomonga bildirishnoma.
2. 2-tomon kodni kiritadi → `confirmed`, o'chirilmas dalil.
3. O'zgartirish faqat `edit-request` + qarshi tomon tasdig'i bilan; eski qiymat tarixda qoladi.

# trust

**Oldi-berdi** — qarz hisobini elektronlashtirish, hujjatlashtirish va eslatish uchun mobil ilova backendi.

## Stack

- Node.js + Express
- Supabase (PostgreSQL, Auth)
- devsms.uz — O'zbekiston raqamlari uchun OTP SMS (AllClubs shabloni)
- Supabase Auth OTP — boshqa davlatlar uchun

## O'rnatish

```bash
npm install
cp .env.example .env   # kalitlarni to'ldiring
npm run dev
```

Supabase'da `supabase/migrations/001_init.sql` ni SQL Editor orqali ishga tushiring.

## API

### Auth
| Metod | Yo'l | Tavsif |
|---|---|---|
| POST | `/api/auth/send-otp` | `{ phone }` — OTP yuborish. +998 → devsms.uz, boshqalar → Supabase |
| POST | `/api/auth/verify-otp` | `{ phone, code }` — tekshirish, `access_token` qaytaradi |

### Profil (Bearer token kerak)
| Metod | Yo'l | Tavsif |
|---|---|---|
| GET | `/api/profile/me` | Profilni olish |
| PUT | `/api/profile/me` | `{ full_name, avatar_url }` |

### Qarzlar (Bearer token kerak)
| Metod | Yo'l | Tavsif |
|---|---|---|
| GET | `/api/debts` | Mening qarzlarim (`?role=lender\|borrower&status=...`) |
| POST | `/api/debts` | `{ direction: "lent"\|"borrowed", counterparty_phone, amount, currency?, note?, due_date? }` |
| GET | `/api/debts/:id` | Bitta qarz (to'lovlari bilan) |
| POST | `/api/debts/:id/confirm` | Ikkinchi taraf tasdiqlaydi → `active` |
| POST | `/api/debts/:id/cancel` | Bekor qilish |
| POST | `/api/debts/:id/payments` | `{ amount, note? }` — to'lov; to'liq to'lansa qarz `paid` bo'ladi |

## Qarz holati oqimi

`pending` (bir taraf kiritdi) → `active` (ikkinchi taraf tasdiqladi) → `paid` / `cancelled` / `disputed`

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
| POST | `/api/partners` | `{ name, counterparty_p
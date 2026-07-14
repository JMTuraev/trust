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

### STT (ovoz → matn) — 2 qatlamli (XOTIRA-ovoz-va-kategoriya.md)
| Metod | Yo'l | Tavsif |
|---|---|---|
| POST | `/api/stt/transcribe` | Body: xom audio (audio/wav). 1-qatlam: **Groq whisper-large-v3**; past ishonch/bo'sh/timeout'da 2-qatlam: **OpenAI gpt-4o-transcribe**. Javob: `{ text, confidence, provider }`. Ikkalasi yiqilsa audio Storage'ga saqlanadi. Env: `GROQ_API_KEY` (majburiy), `OPENAI_API_KEY` (zaxira uchun). |

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
4. Hamkor Trust'ga keyin qo'shilsa — trigger uni telefon raqami bo'yicha mavjud hamkor yozuvlariga avtomatik bog'laydi (`on_trust=true`, egasiga bildirishnoma).

## Deploy

**Render.com (joriy):** repo'da `render.yaml` bor — Dashboard → New → Blueprint → repo tanlang. Region: Frankfurt, health check: `/health`. Maxfiy env qiymatlarni (SUPABASE_*, DEVSMS_TOKEN) Dashboard'da kiriting; `APP_JWT_SECRET` avtomatik yaratiladi. Free planda 15 daqiqa harakatsizlikdan keyin uxlaydi — birinchi so'rov ~30-50 s.

**VPS/Docker (keyingi bosqich):** `Dockerfile` tayyor:
```bash
docker build -t trust-backend .
docker run -d --env-file .env -p 3000:3000 --restart unless-stopped trust-backend
```

Supabase migratsiyalari: `supabase/migrations/001..003` ni SQL Editor'da tartib bilan ishga tushiring (idempotent — qayta yurgizish xavfsiz). Batafsil: `SOZLASH.md`.

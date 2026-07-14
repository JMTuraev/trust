# Sozlash qo'llanmasi (trust backend)

Supabase loyihasi (`trust`) va jadvallar allaqachon yaratilgan. Ishga tushirish uchun 4 ta maxfiy kalitni `.env` fayliga qo'yish kerak.

## 1. Kalitlarni olish

Bu sahifani oching: **https://supabase.com/dashboard/project/cgqudcbvezwxjxgaqdiw/settings/api-keys/legacy**

U yerdan 2 ta qiymatni "Copy" tugmasi orqali nusxalang:
- **anon / public** → `SUPABASE_ANON_KEY`
- **service_role / secret** ("Reveal" bosib) → `SUPABASE_SERVICE_ROLE_KEY`

JWT secret uchun: **https://supabase.com/dashboard/project/cgqudcbvezwxjxgaqdiw/settings/jwt**
- **JWT Secret** → `SUPABASE_JWT_SECRET`

DevSMS token: **https://devsms.uz** → Dashboard → API token → `DEVSMS_TOKEN`

## 2. .env faylini yaratish

```bash
cp .env.example .env
```
So'ng `.env` ichidagi qiymatlarni to'ldiring. `SUPABASE_URL` allaqachon qo'yilgan.

## 3. Ishga tushirish

```bash
npm install
npm run dev
```

Test: `curl http://localhost:3000/health` → `{"ok":true}`

## Eslatma
- **O'zbekiston (+998)** raqamlari — devsms.uz orqali OTP (AllClubs shabloni). Tayyor.
- **Boshqa davlatlar** — Supabase Auth OTP. Buning uchun Supabase → Authentication → Providers → Phone da SMS provayder (masalan Twilio) ulash kerak. Keyinroq.

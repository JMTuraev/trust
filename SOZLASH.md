# Sozlash qo'llanmasi (trust backend)

## 1. Kalitlarni olish

Bu sahifani oching: **https://supabase.com/dashboard/project/cgqudcbvezwxjxgaqdiw/settings/api-keys/legacy**

U yerdan 2 ta qiymatni "Copy" tugmasi orqali nusxalang:
- **anon / public** → `SUPABASE_ANON_KEY`
- **service_role / secret** ("Reveal" bosib) → `SUPABASE_SERVICE_ROLE_KEY`

DevSMS token: **https://devsms.uz** → Dashboard → API token → `DEVSMS_TOKEN`

## 2. Supabase migratsiyalari

SQL Editor'da (**https://supabase.com/dashboard/project/cgqudcbvezwxjxgaqdiw/sql/new**) quyidagilarni **tartib bilan** ishga tushiring:

1. `supabase/migrations/001_init.sql`
2. `supabase/migrations/002_trust_model.sql`
3. `supabase/migrations/003_v2_fixes.sql` ← **yangi, majburiy**

Hammasi idempotent — oldin qisman bajarilgan bo'lsa ham qayta yurgizish xavfsiz.

**Tekshirish (Table Editor'da shu 9 jadval bo'lishi kerak):**
`profiles, otp_codes, partners, operations, op_history, edit_requests, expenses, limits, notifications`.
`debts, payments, reminders` (eski v1) — 003 dan keyin YO'Q bo'lishi kerak.
`notifications` jadvalida `sender_id` ustuni paydo bo'lgan bo'lishi kerak.

## 3. Lokal ishga tushirish

```bash
cp .env.example .env   # kalitlarni to'ldiring
npm install
npm run dev
```

Test: `curl http://localhost:3000/health` → `{"ok":true,...,"version":"2.1"}`

## 4. Render.com'ga deploy (joriy bosqich)

1. Kodni GitHub'ga push qiling (`.env` push bo'lmasligiga ishonch — `.gitignore`da bor).
2. **https://dashboard.render.com** → New → **Blueprint** → repo'ni tanlang (`render.yaml` avtomatik o'qiladi).
3. Environment bo'limida maxfiy qiymatlarni kiriting: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DEVSMS_TOKEN`. (`APP_JWT_SECRET` ni Render o'zi yaratadi.)
4. Deploy tugagach: `curl https://trust-backend-ft1s.onrender.com/health`
5. Mobil ilovani shu manzilga ulang:
   ```bash
   flutter run --dart-define=API_URL=https://trust-backend-ft1s.onrender.com
   ```

**Joriy holat (2026-07-14): deploy qilingan va ishlayapti** — `https://trust-backend-ft1s.onrender.com` (health/404/401/400/DB testlari o'tgan).

Eslatma: Free plan 15 daqiqa harakatsizlikdan keyin uxlaydi — birinchi so'rov 30–50 soniya olishi mumkin. Jiddiy foydalanishda Starter'ga o'ting yoki VPS bosqichiga o'ting.

## 5. VPS/Docker'ga ko'chish (keyingi bosqich)

```bash
docker build -t trust-backend .
docker run -d --name trust --env-file .env -p 3000:3000 --restart unless-stopped trust-backend
```

Kod 12-factor: barcha sozlama env orqali, holat faqat Supabase'da — shuning uchun Render ↔ VPS ko'chish faqat env fayl ko'chirishdan iborat. Oldida NGINX + Let's Encrypt qo'yish tavsiya etiladi, keyin mobil `API_URL`ni yangi domenga o'zgartirasiz.

## 6. STT (ovoz → matn) — 2 qatlam (XOTIRA-ovoz-va-kategoriya.md)

1-qatlam: **Groq whisper-large-v3** (asosiy, bepul tarif kuniga 2000 so'rov). 2-qatlam: **OpenAI gpt-4o-transcribe** (zaxira — shovqin/sheva; past ishonch, bo'sh matn yoki timeout'da avtomatik o'tadi).

1. **https://console.groq.com** → API Keys → Create API Key → nusxalang
2. Render Dashboard → **trust-backend** → **Environment** → Add: `GROQ_API_KEY` = (kalit) → Save (avto qayta deploy bo'ladi)
3. (Zaxira qatlam uchun, ixtiyoriy-lekin-tavsiya) `OPENAI_API_KEY` ham qo'shing — platform.openai.com
4. Lokal `.env`ga ham qo'shib qo'ying
5. Test: ilovada login → Xarajat → mikrofon → gapiring → to'lqinni bosing

Kalit qo'shilmaguncha endpoint 503 qaytaradi va ilova demo/matn rejimida ishlayveradi.

## Eslatma
- **O'zbekiston (+998)** raqamlari — devsms.uz orqali OTP (AllClubs shabloni, 5 xonali kod). Tayyor.
- **Boshqa davlatlar** — Supabase Auth OTP. Buning uchun Supabase → Authentication → Providers → Phone da SMS provayder (masalan Twilio) ulash kerak. Keyinroq.
- Auth endpointlarida rate limit bor: IP boshiga daqiqasiga 10 ta so'rov; SMS qayta yuborish — 60 soniyada 1 marta.

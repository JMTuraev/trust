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
cp 
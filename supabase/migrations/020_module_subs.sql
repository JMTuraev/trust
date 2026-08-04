-- 020 — MODUL OBUNALARI (PO 2026-08-04): yagona $9 premium o'rniga har modul alohida oylik obuna.
--   xarajat $5/oy · qarz $8/oy · ijarachi $13/oy (kelajak) · toyxona $24/oy har zalga (kelajak).
--   Bepul tarif: har modulda 5 ta yozuv (FREE_DEBT_ENTRIES / FREE_EXPENSE_ENTRIES env), keyin paywall.
--   ESKI premium (profiles.premium_until, trust_premium_monthly) — muddati tugaguncha BARCHA
--   modullarga kirish beradi (grandfather); bu jadvalga ko'chirilmaydi, kod ikkalasini tekshiradi.
--   Ikki tomonlama qoida O'ZGARMAGAN: daftar EGASI to'laydi, kontragent bepul yozadi
--   (src/lib/subscription.js — kvota va modul tekshiruvi EGA bo'yicha).
-- Idempotent. Supabase SQL Editor'da qo'lda ishga tushiring (019 kabi).
-- Backend bu jadval YO'Q bo'lsa ham yiqilmaydi (kodda relation-missing fallback bor),
-- lekin modul obunasi SOTISH uchun migratsiya avval qo'llangan bo'lishi SHART.

-- 018 hali qo'llanmagan bo'lsa ham skript yiqilmasin (schema_migrations 018 da yaratiladi)
create table if not exists public.schema_migrations (
  version    text primary key,
  applied_at timestamptz not null default now()
);
alter table public.schema_migrations enable row level security;

create table if not exists public.module_subs (
  user_id      uuid not null references public.profiles(id) on delete cascade,
  module       text not null check (module in ('xarajat','qarz','ijarachi','toyxona')),
  active_until timestamptz,  -- null yoki o'tmishda = faol emas
  product_id   text,         -- masalan: trust_qarz_monthly (audit/diagnostika uchun)
  updated_at   timestamptz not null default now(),
  primary key (user_id, module)
);

-- RLS yoqilgan, policy ATAYLAB yo'q (012 subscription_events naqshi): faqat service_role
-- (backend, supabaseAdmin) o'qiydi/yozadi. anon/authenticated'ga GRANT ham yo'q — klient
-- obuna holatini FAQAT API orqali oladi (GET /api/subs/status) va o'zi active_until yozib
-- bepul obuna ololmaydi (018 §2 dagi profiles.premium_until saboqi).
alter table public.module_subs enable row level security;
revoke all on public.module_subs from anon, authenticated;

insert into public.schema_migrations(version) values ('020') on conflict do nothing;

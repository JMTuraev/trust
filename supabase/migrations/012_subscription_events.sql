-- 012: obuna to'lov hodisalari — audit + idempotentlik
-- POST /api/profile/me/subscription/verify uchun (hozircha DEV-stub;
-- Google Play Billing server-tomonda tekshiruvi keyin shu jadvalga yozadi).
-- purchase_token UNIQUE: bitta xarid tokeni ikki marta premium bermaydi
-- (replay/parallel so'rovlarga qarshi). Idempotent: qayta yurgizish xavfsiz.

create table if not exists public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null default 'google_play',      -- google_play | google_play_dev | app_store
  product_id text not null,                          -- masalan: trust_premium_monthly
  purchase_token text not null unique,               -- Play purchaseToken (DEV rejimda 'DEV.' prefiks)
  premium_until_after timestamptz,                   -- grant natijasida profiles.premium_until qiymati
  created_at timestamptz not null default now()
);

create index if not exists sub_events_user_idx on public.subscription_events(user_id);

-- RLS yoqilgan, policy ATAYLAB yo'q: faqat service_role (backend) o'qiydi/yozadi.
alter table public.subscription_events enable row level security;

-- 010 — Circles (guruhli navbatli jamg'arma / ROSCA) modeli.
-- Ko'p foydalanuvchili, server-avtoritar. Har a'zoning har round'dagi to'lovi ALOHIDA yozuv;
-- ikki tomonlama: to'lovchi 'to'ladim' → oluvchi 'oldim' → round yopiladi (dalil).
-- RLS yoqiladi, policy YO'Q — backend service_role bilan ishlaydi, huquq KODDA tekshiriladi
-- (debts modeli bilan bir xil naqsh). Idempotent. Supabase SQL Editor'da ishga tushiring.

-- ============================================================
-- 1. CIRCLES — doira
-- ============================================================
create table if not exists public.circles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),      -- yaratuvchi/admin
  name text not null,
  amount bigint not null check (amount > 0),                  -- har round bir a'zo badali
  currency text not null default 'UZS' check (currency in ('UZS','USD','EUR','RUB','GBP','KZT')),
  frequency text not null default 'monthly' check (frequency in ('monthly','custom')),
  payout_order text not null default 'inTurn' check (payout_order in ('inTurn','random','iPick')),
  status text not null default 'active' check (status in ('active','complete')),
  current_round int not null default 1,                       -- 1-based joriy round
  period text,                                                -- yakunlangan ko'rinish uchun ("Jan–May")
  join_token text unique default encode(gen_random_bytes(9), 'hex'),  -- ulashiladigan taklif havolasi
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- 2. CIRCLE_MEMBERS — a'zolar (real user yoki telefon bo'yicha taklif)
--    status: active (qo'shilgan) | invited (kutilmoqda) | declined
-- ============================================================
create table if not exists public.circle_members (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles(id) on delete cascade,
  user_id uuid references public.profiles(id),                -- qo'shilganda to'ldiriladi
  invited_phone text,                                         -- telefon bo'yicha taklif (raqamsiz)
  display_name text not null,
  payout_position int not null,                              -- 1-based: qaysi round'da oladi
  is_admin boolean not null default false,
  status text not null default 'active' check (status in ('active','invited','declined')),
  joined_at timestamptz default now(),
  unique (circle_id, payout_position)
);
create index if not exists circle_members_circle_idx on public.circle_members(circle_id);
create index if not exists circle_members_user_idx on public.circle_members(user_id) where user_id is not null;
create index if not exists circle_members_phone_idx on public.circle_members(invited_phone) where invited_phone is not null;

-- ============================================================
-- 3. CIRCLE_ROUNDS — roundlar
--    status: done | current | upcoming
-- ============================================================
create table if not exists public.circle_rounds (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles(id) on delete cascade,
  idx int not null,                                          -- 1-based
  recipient_member_id uuid not null references public.circle_members(id) on delete cascade,
  due_date text,                                            -- "Jul 20" ko'rinishida (yoki ISO)
  status text not null default 'upcoming' check (status in ('done','current','upcoming')),
  receipt_confirmed boolean not null default false,
  created_at timestamptz default now(),
  unique (circle_id, idx)
);
create index if not exists circle_rounds_circle_idx on public.circle_rounds(circle_id, idx);

-- ============================================================
-- 4. CIRCLE_PAYMENTS — har round, har a'zoning to'lovi (ikki tomonlama)
--    status: pending (kutilmoqda) | paid (to'lovchi belgiladi) | confirmed (oluvchi tasdiqladi)
-- ============================================================
create table if not exists public.circle_payments (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.circle_rounds(id) on delete cascade,
  member_id uuid not null references public.circle_members(id) on delete cascade,
  amount bigint not null check (amount > 0),
  status text not null default 'pending' check (status in ('pending','paid','confirmed')),
  paid_at timestamptz,
  confirmed_at timestamptz,
  created_at timestamptz default now(),
  unique (round_id, member_id)
);
create index if not exists circle_payments_round_idx on public.circle_payments(round_id);

-- ============================================================
-- RLS (policy yo'q — service_role backend, huquq kodda)
-- ============================================================
alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.circle_rounds enable row level security;
alter table public.circle_payments enable row level security;

-- ============================================================
-- 5. NOTIFICATIONS — circle turlari + circle_id (tap manzili uchun)
-- ============================================================
alter table public.notifications add column if not exists circle_id uuid references public.circles(id) on delete cascade;
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in (
    'req','ok','rem','edit','rej','link_new','link_acc','link_rej','op_new','msg',
    'debt_new','debt_confirm','debt_reject','repay_new','settle_new','edit_req','review_req',
    'circle_invite','circle_turn','circle_paid','circle_confirm','circle_due','circle_joined'
  ));

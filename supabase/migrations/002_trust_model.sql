-- Trust — prototipга mos ma'lumot modeli
-- profiles allaqachon 001_init.sql da yaratilgan (id, phone, full_name, avatar_url)

-- 1. HAMKORLAR (owner ↔ counterparty munosabati)
create table if not exists public.partners (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  counterparty_id uuid references public.profiles(id),   -- ro'yxatdan o'tgan bo'lsa
  counterparty_phone text not null,
  name text not null,                                     -- owner qo'ygan nom
  on_trust boolean not null default false,                -- ikki tomon ham Trust'da
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, counterparty_phone)
);
create index if not exists partners_owner_idx on public.partners(owner_id);
create index if not exists partners_cp_idx on public.partners(counterparty_id);

-- 2. OPERATSIYALAR (ikki tomonlama tasdiq)
-- type: qarz_berdim | qarz_oldim | qaytardim | menga_qaytarildi
-- delta: owner nuqtai nazaridan balansga ta'sir (+ = menga qarzdor)
create table if not exists public.operations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  partner_id uuid not null references public.partners(id) on delete cascade,
  counterparty_id uuid references public.profiles(id),
  type text not null check (type in ('qarz_berdim','qarz_oldim','qaytardim','menga_qaytarildi')),
  amount numeric(18,2) not null check (amount > 0),
  delta numeric(18,2) not null,            -- signed
  currency text not null default 'UZS',
  note text,
  status text not null default 'pending'
    check (status in ('pending','confirmed','cancelled','disputed')),
  confirm_code text,                        -- 5 xonali, 2-tomon kiritadi
  confirmed_at timestamptz,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ops_owner_idx on public.operations(owner_id);
create index if not exists ops_partner_idx on public.operations(partner_id);
create index if not exists ops_status_idx on public.operations(status);

-- 3. OPERATSIYA TARIXI (o'zgarishlar — o'chirilmaydi)
create table if not exists public.op_history (
  id uuid primary key default gen_random_uuid(),
  operation_id uuid not null references public.operations(id) on delete cascade,
  change_text text not null,                -- "780 000 → 760 000"
  changed_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists ophist_op_idx on public.op_history(operation_id);

-- 4. O'ZGARTIRISH SO'ROVLARI
create table if not exists public.edit_requests (
  id uuid primary key default gen_random_uuid(),
  operation_id uuid not null references public.operations(id) on delete cascade,
  new_amount numeric(18,2) not null check (new_amount > 0),
  new_note text,
  requested_by uuid not null references public.profiles(id),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists editreq_op_idx on public.edit_requests(operation_id);

-- 5. SHAXSIY XARAJAT/DAROMAD (Xarajat chat — o'zi bilan)
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  income boolean not null default false,    -- true=daromad, false=xarajat
  amount numeric(18,2) not null check (amount > 0),
  category text,                            -- AI toifasi
  note text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists exp_user_idx on public.expenses(user_id, occurred_at);

-- 6. OYLIK LIMIT
create table if not exists public.limits (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  monthly_limit numeric(18,2) not null default 0,
  updated_at timestamptz not null default now()
);

-- 7. BILDIRISHNOMALAR
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('req','ok','rem','edit','rej')),
  title text not null,
  detail text,
  operation_id uuid references public.operations(id) on delete set null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notif_user_idx on public.notifications(user_id, created_at);

-- RLS (backend service_role bilan ishlaydi; klientlar to'g'ridan-to'g'ri kira olmasin)
alter table public.partners enable row level security;
alter table public.operations enable row level security;
alter table public.op_history enable row level security;
alter table public.edit_requests enable row level security;
alter table public.expenses enable row level security;
alter table public.limits enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "own partners" on public.partners;
create policy "own partners" on public.partners for select
  using (auth.uid() = owner_id or auth.uid() = counterparty_id);

drop policy if exists "own operations" on public.operations;
create policy "own operations" on public.operations for select
  using (auth.uid() = owner_id or auth.uid() = counterparty_id);

drop policy if exists "own expenses" on public.expenses;
create policy "own expenses" on public.expenses for select using (auth.uid() = user_id);

drop policy if exists "own limits" on public.limits;
create policy "own limits" on public.limits for select using (auth.uid() = user_id);

drop policy if exists "own notifs" on public.notifications;
create policy "own notifs" on public.notifications for select using (auth.uid() = user_id);

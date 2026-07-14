-- trust (oldi-berdi) — boshlang'ich sxema
-- Supabase Dashboard -> SQL Editor'da ishga tushiring

-- 1. Profillar (auth.users bilan bog'langan)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text unique,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Yangi user yaratilganda avtomatik profil ochish
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, phone)
  values (new.id, regexp_replace(coalesce(new.phone, ''), '\D', '', 'g'))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2. Qarzlar
create table if not exists public.debts (
  id uuid primary key default gen_random_uuid(),
  lender_id uuid references public.profiles(id),      -- qarz bergan
  borrower_id uuid references public.profiles(id),    -- qarz olgan
  counterparty_phone text not null,                   -- ikkinchi taraf telefoni (ro'yxatdan o'tmagan bo'lishi mumkin)
  amount numeric(18,2) not null check (amount > 0),
  currency text not null default 'UZS',
  note text,
  due_date date,
  status text not null default 'pending'
    check (status in ('pending','active','paid','cancelled','disputed')),
  created_by uuid not null references public.profiles(id),
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists debts_lender_idx on public.debts(lender_id);
create index if not exists debts_borrower_idx on public.debts(borrower_id);
create index if not exists debts_phone_idx on public.debts(counterparty_phone);

-- 3. To'lovlar (qisman qaytarish)
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  debt_id uuid not null references public.debts(id) on delete cascade,
  payer_id uuid not null references public.profiles(id),
  amount numeric(18,2) not null check (amount > 0),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists payments_debt_idx on public.payments(debt_id);

-- 4. OTP kodlari (faqat O'zbekiston / devsms oqimi uchun)
create table if not exists public.otp_codes (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  code_hash text not null,
  attempts int not null default 0,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists otp_phone_idx on public.otp_codes(phone);

-- 5. Eslatmalar (qarz muddati uchun)
create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  debt_id uuid not null references public.debts(id) on delete cascade,
  remind_at timestamptz not null,
  sent boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists reminders_due_idx on public.reminders(remind_at) where not sent;

-- 6. RLS — backend service_role bilan ishlaydi (RLS chetlab o'tadi),
-- lekin klientlar to'g'ridan-to'g'ri ulanolmasligi uchun yoqib qo'yamiz
alter table public.profiles enable row level security;
alter table public.debts enable row level security;
alter table public.payments enable row level security;
alter table public.otp_codes enable row level security;
alter table public.reminders enable row level security;

-- Foydalanuvchi o'z profilini ko'ra oladi/tahrirlaydi
drop policy if exists "own profile read" on public.profiles;
create policy "own profile read" on public.profiles
  for select using (auth.uid() = id);
drop policy if exists "own profile update" on public.profiles;
create policy "own profile update" on public.profiles
  for update using (auth.uid() = id);

-- O'ziga tegishli qarzlarni ko'rish
drop policy if exists "own debts read" on public.debts;
create policy "own debts read" on public.debts
  for select using (auth.uid() = lender_id or auth.uid() = borrower_id or auth.uid() = created_by);

-- O'z qarzlariga tegishli to'lovlarni ko'rish
drop policy if exists "own payments read" on public.payments;
create policy "own payments read" on public.payments
  for select using (
    exists (
      select 1 from public.debts d
      where d.id = debt_id and (auth.uid() = d.lender_id or auth.uid() = d.borrower_id)
    )
  );

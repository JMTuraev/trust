-- apply_all.sql = 001+002+003+004 (bitta paste uchun, idempotent)
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
-- 003 — v2 tuzatishlar: statuslar, hamkor bog'lash trigger, eslatma sender,
-- eski (v1) jadvallarni olib tashlash. Supabase SQL Editor'da ishga tushiring.

-- 1. OPERATSIYA STATUSLARI: 'unconfirmed' (bir tomonlama daftar yozuvi, dalil emas)
--    va 'archived' (dalil yashirilgan, balansda qoladi)
alter table public.operations drop constraint if exists operations_status_check;
alter table public.operations add constraint operations_status_check
  check (status in ('pending','confirmed','unconfirmed','archived','cancelled','disputed'));

-- 2. BILDIRISHNOMAGA YUBORUVCHI (eslatma cooldown'i uchun)
alter table public.notifications add column if not exists
  sender_id uuid references public.profiles(id) on delete set null;
create index if not exists notif_sender_idx
  on public.notifications(sender_id, type, created_at);

-- 3. YANGI FOYDALANUVCHINI MAVJUD HAMKORLARGA BOG'LASH
--    Kimdir uni telefon raqami bo'yicha hamkor qilib qo'shgan bo'lsa —
--    counterparty_id to'ldiriladi, on_trust yoqiladi, egasiga xabar boradi.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  norm_phone text := regexp_replace(coalesce(new.phone, ''), '\D', '', 'g');
  p record;
begin
  insert into public.profiles (id, phone)
  values (new.id, norm_phone)
  on conflict (id) do nothing;

  if norm_phone <> '' then
    for p in
      update public.partners
        set counterparty_id = new.id, on_trust = true, updated_at = now()
      where counterparty_phone = norm_phone and counterparty_id is null
      returning id, owner_id, name
    loop
      insert into public.notifications (user_id, type, title, detail)
      values (p.owner_id, 'ok', 'Hamkor Trust''ga qo''shildi',
              p.name || ' endi Trust''da — yozuvlar ikki tomonlama tasdiqlanadi');
    end loop;
  end if;

  return new;
end;
$$;

-- (trigger 001 da yaratilgan — funksiya yangilandi, qayta bog'lash shart emas,
--  lekin xavfsizlik uchun qayta e'lon qilamiz)
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. ESKI (V1) JADVALLARNI OLIB TASHLASH — backend v2 ularni ishlatmaydi
drop table if exists public.payments cascade;
drop table if exists public.reminders cascade;
drop table if exists public.debts cascade;

-- 5. OTP jadvalini tozalab turish uchun indeks (muddati o'tganlarni o'chirish oson bo'lsin)
create index if not exists otp_expires_idx on public.otp_codes(expires_at);


-- 004 — Bog'lanish (Link) modeli: operatsiya darajasidagi tasdiq olib tashlanadi,
-- o'rniga bir martalik bog'lanish tasdig'i (pending/accepted/rejected) kiritiladi.
-- Idempotent. Supabase SQL Editor'da ishga tushiring.

-- ============================================================
-- 1. PARTNERS = LINK: status, mijoz aliasi
-- ============================================================
alter table public.partners add column if not exists
  link_status text not null default 'pending';
alter table public.partners drop constraint if exists partners_link_status_check;
alter table public.partners add constraint partners_link_status_check
  check (link_status in ('pending','accepted','rejected'));

alter table public.partners add column if not exists
  status_changed_at timestamptz;

-- Mijozning sotuvchiga o'zi qo'ygan nomi (counterparty tomonidan tahrirlanadi)
alter table public.partners add column if not exists
  client_alias text;

-- ============================================================
-- 2. AUDIT: har bir status o'zgarishi
-- ============================================================
create table if not exists public.link_events (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete cascade,
  from_status text,
  to_status text not null,
  changed_by uuid references public.profiles(id) on delete set null, -- null = tizim/migratsiya
  created_at timestamptz not null default now()
);
create index if not exists link_events_partner_idx on public.link_events(partner_id, created_at);
create index if not exists link_events_reject_idx on public.link_events(to_status, created_at);
alter table public.link_events enable row level security;

-- ============================================================
-- 3. KECHIKTIRILGAN RAD SIGNALI NAVBATI
-- ============================================================
create table if not exists public.reject_signals (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null unique references public.partners(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  due_at timestamptz not null,
  sent boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists reject_signals_due_idx on public.reject_signals(sent, due_at);
alter table public.reject_signals enable row level security;

-- ============================================================
-- 4. BLOKLAR: mijoz -> sotuvchi
-- ============================================================
create table if not exists public.blocks (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (client_id, seller_id)
);
alter table public.blocks enable row level security;

-- ============================================================
-- 5. OPERATSIYALAR: tasdiq tushunchasi olib tashlanadi
--    pending/confirmed/unconfirmed -> active (bir tomonlama da'vo)
-- ============================================================
alter table public.operations drop constraint if exists operations_status_check;
update public.operations
  set status = 'active'
  where status in ('pending','confirmed','unconfirmed','disputed');
alter table public.operations add constraint operations_status_check
  check (status in ('active','archived','cancelled'));

-- confirm_code endi ishlatilmaydi (sarflangan kodlar — saqlash shart emas)
alter table public.operations drop column if exists confirm_code;
-- confirmed_at tarixiy ma'lumot sifatida qoladi (faqat o'qish)

-- ============================================================
-- 6. EDIT_REQUESTS: tasdiqlash oqimi bilan birga o'chadi
--    (tasdiqlangan o'zgarishlar tarixi op_history'da saqlangan)
-- ============================================================
drop table if exists public.edit_requests cascade;

-- ============================================================
-- 7. NOTIFICATIONS: yangi turlar + link_id
--    Eski turlar (req/ok/edit/rej) mavjud qatorlar uchun CHECKda qoladi.
-- ============================================================
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in ('req','ok','rem','edit','rej','link_new','link_acc','link_rej','op_new'));

alter table public.notifications add column if not exists
  link_id uuid references public.partners(id) on delete set null;
create index if not exists notif_link_idx on public.notifications(link_id);

-- ============================================================
-- 8. PROFIL: bildirishnoma sozlamasi
--    (op_new va rem shu bayroq bilan boshqariladi; link_new/link_rej doim boradi)
-- ============================================================
alter table public.profiles add column if not exists
  notif_enabled boolean not null default true;

-- ============================================================
-- 9. BACKFILL: mavjud bog'lanishlarga status
--    Kamida bitta KOD BILAN TASDIQLANGAN operatsiyasi bor hamkor -> accepted
--    (mijoz munosabatdan xabardor va rozi bo'lgan). Qolganlari -> pending.
-- ============================================================
update public.partners p
  set link_status = 'accepted', status_changed_at = now()
  where link_status = 'pending'
    and exists (
      select 1 from public.operations o
      where o.partner_id = p.id and o.confirmed_at is not null
    );

-- Audit: boshlang'ich holat yozuvlari (faqat hali yozilmaganlarga)
insert into public.link_events (partner_id, from_status, to_status, changed_by)
select p.id, null, p.link_status, null
from public.partners p
where not exists (select 1 from public.link_events e where e.partner_id = p.id);

-- Ro'yxatdan o'tgan mijozlarga pending linklar haqida bildirishnoma
insert into public.notifications (user_id, sender_id, type, title, detail, link_id)
select p.counterparty_id, p.owner_id, 'link_new',
       'Sizni kontragent qilib qo''shishdi',
       coalesce(nullif(pr.full_name, ''), pr.phone) || ' sizni kontragent qilib qo''shgan — qabul qilasizmi?',
       p.id
from public.partners p
join public.profiles pr on pr.id = p.owner_id
where p.link_status = 'pending'
  and p.counterparty_id is not null
  and not exists (
    select 1 from public.notifications n
    where n.link_id = p.id and n.type = 'link_new'
  );

-- ============================================================
-- 10. on_trust USTUNI O'CHADI — o'rnini link_status='accepted' bosadi
-- ============================================================
alter table public.partners drop column if exists on_trust;

-- ============================================================
-- 11. TRIGGER: yangi foydalanuvchi ro'yxatdan o'tganda
--     - pending linklar counterparty_id bilan bog'lanadi
--     - MIJOZGA har pending link uchun 'link_new' bildirishnoma
--       (endi sotuvchiga emas — qaror mijozda)
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  norm_phone text := regexp_replace(coalesce(new.phone, ''), '\D', '', 'g');
  p record;
begin
  insert into public.profiles (id, phone)
  values (new.id, norm_phone)
  on conflict (id) do nothing;

  if norm_phone <> '' then
    for p in
      update public.partners
        set counterparty_id = new.id, updated_at = now()
      where counterparty_phone = norm_phone and counterparty_id is null
      returning id, owner_id
    loop
      insert into public.notifications (user_id, sender_id, type, title, detail, link_id)
      select new.id, p.owner_id, 'link_new',
             'Sizni kontragent qilib qo''shishdi',
             coalesce(nullif(pr.full_name, ''), pr.phone) || ' sizni kontragent qilib qo''shgan — qabul qilasizmi?',
             p.id
      from public.profiles pr where pr.id = p.owner_id;
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

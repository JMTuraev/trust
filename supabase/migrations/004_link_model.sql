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

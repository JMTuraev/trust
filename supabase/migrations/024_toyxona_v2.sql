-- 024 — TO'YXONA v2 (PO 2026-09-08):
--   1) NARX REJIMI: 'guest' (kishi boshiga: mehmon × narx) yoki 'total' (butun
--      to'yxona "podklyuch" — bitta yakuniy summa). Toggle bandda; to'yxonada default.
--   2) STOL TURLARI = hall_menus (avvalgi "narx toifasi"). Har turga STOL USTIDAGI
--      taomlar/mahsulotlar ro'yxati (hall_menu_items) + stol sig'imi (seats).
--   3) SERVISLAR KATALOGI (hall_services): video, sahna bezagi, shou... narx bilan.
--      Bandga qo'shilganda booking_items ga SNAPSHOT; is_bonus = bepul beriladi
--      (narx ko'rinadi, jamiga QO'SHILMAYDI).
--   4) BEKOR JARIMASI: halls.cancel_policy (kun→foiz jadvali). Bekor qilinganda
--      jarima BANDGA yoziladi (cancel_penalty) — keyin siyosat o'zgarsa ham eski
--      bandning jarimasi o'zgarmaydi (snapshot qoidasi). Qaytarim = 'qaytarim' to'lov.
--   5) MINIMAL AVANS: halls.deposit_pct (0 = talab yo'q). hold_until — avans kelmasa
--      shu vaqtgacha sana ushlab turiladi, keyin sweeper avto-bekor qiladi.
--   6) OFF-APP MIJOZ: bookings.client_user_id — mijoz keyin Trustbook'ka kirsa
--      telefoni bo'yicha bog'lanadi (otp.js linkPartners naqshi).
--
-- Idempotent. Supabase SQL Editor'da QO'LDA ishga tushiring (021/022/023 kabi),
-- deploy'dan OLDIN. Eski qatorlar: price_mode='guest', deposit 0, jarima yo'q —
-- xulq O'ZGARMAYDI, hech qanday summa qayta hisoblanmaydi.

create table if not exists public.schema_migrations (
  version    text primary key,
  applied_at timestamptz not null default now()
);
alter table public.schema_migrations enable row level security;

-- ---------------------------------------------------------------------
-- 1) halls — narx rejimi defaulti, "podklyuch" narxi, minimal avans, jarima siyosati
-- ---------------------------------------------------------------------
alter table public.halls add column if not exists price_mode  text   not null default 'guest';
alter table public.halls add column if not exists total_price bigint not null default 0;
alter table public.halls add column if not exists deposit_pct int    not null default 0;
-- [{"days":30,"pct":0},{"days":7,"pct":50},{"days":0,"pct":100}]
--   days = to'ygacha KAMIDA shuncha kun qolganda; pct = TUSHGAN puldan (avans)
--   ushlab qolinadigan foiz. Bo'sh massiv = jarima yo'q (hammasi qaytariladi).
alter table public.halls add column if not exists cancel_policy jsonb not null default '[]'::jsonb;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'halls_price_mode_chk') then
    alter table public.halls add constraint halls_price_mode_chk
      check (price_mode in ('guest','total'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'halls_total_price_nonneg') then
    alter table public.halls add constraint halls_total_price_nonneg check (total_price >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'halls_deposit_pct_chk') then
    alter table public.halls add constraint halls_deposit_pct_chk
      check (deposit_pct >= 0 and deposit_pct <= 100);
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 2) hall_menus = STOL TURLARI. seats — bir stolda necha kishi (ixtiyoriy).
--    hall_menu_items — stol ustidagi taom/mahsulot ro'yxati (faqat matn, pulsiz:
--    narx STOL TURIDA, mahsulotda emas — aks holda ega har taomga narx qo'yishga
--    majbur bo'lardi, O'zbekistonda esa "stol narxi" bitta raqam).
-- ---------------------------------------------------------------------
alter table public.hall_menus add column if not exists seats int;
alter table public.hall_menus add column if not exists note  text;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'hall_menus_seats_chk') then
    alter table public.hall_menus add constraint hall_menus_seats_chk
      check (seats is null or (seats > 0 and seats <= 100));
  end if;
end $$;

create table if not exists public.hall_menu_items (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  menu_id    uuid not null references public.hall_menus(id) on delete cascade,
  title      text not null,
  qty        text,                 -- "2 dona", "1 kg" — erkin matn, hisoblanmaydi
  sort       int  default 0,
  created_at timestamptz default now()
);
create index if not exists hall_menu_items_menu_idx on public.hall_menu_items (menu_id, sort);

-- ---------------------------------------------------------------------
-- 3) SERVISLAR KATALOGI. hall_id NULL = egaining barcha to'yxonalari uchun.
-- ---------------------------------------------------------------------
create table if not exists public.hall_services (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  hall_id    uuid references public.halls(id) on delete cascade,
  title      text not null,
  price      bigint not null default 0 check (price >= 0),
  note       text,
  sort       int default 0,
  archived   boolean default false,
  created_at timestamptz default now()
);
create index if not exists hall_services_user_idx on public.hall_services (user_id, hall_id, sort);

-- booking_items: katalogga bog'lanish (snapshot — servis o'chsa qator qoladi) + bonus.
alter table public.booking_items add column if not exists service_id uuid
  references public.hall_services(id) on delete set null;
alter table public.booking_items add column if not exists is_bonus boolean not null default false;
-- Bonus xizmat 0 so'mlik ham bo'lishi mumkin (ega katalogga narx qo'ymagan bo'lsa):
-- eski `amount > 0` cheklovi `amount >= 0` ga yumshatiladi. Pullik xizmat 0 bo'lsa
-- baribir backend 400 beradi (money() allowZero faqat bonusda).
do $$ begin
  if exists (select 1 from pg_constraint
             where conname = 'booking_items_amount_check' and conrelid = 'public.booking_items'::regclass) then
    alter table public.booking_items drop constraint booking_items_amount_check;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'booking_items_amount_nonneg') then
    alter table public.booking_items add constraint booking_items_amount_nonneg check (amount >= 0);
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 4) bookings — narx rejimi, podklyuch summasi, bekor/jarima, hold, mijoz bog'lanishi
-- ---------------------------------------------------------------------
alter table public.bookings add column if not exists price_mode     text   not null default 'guest';
alter table public.bookings add column if not exists total_price    bigint not null default 0;  -- 'total' rejimida
alter table public.bookings add column if not exists cancelled_at   timestamptz;
alter table public.bookings add column if not exists cancel_reason  text;
alter table public.bookings add column if not exists cancel_penalty bigint not null default 0;  -- SNAPSHOT
alter table public.bookings add column if not exists hold_until     timestamptz;  -- avans kutish muddati
alter table public.bookings add column if not exists client_user_id uuid references public.profiles(id) on delete set null;
alter table public.bookings add column if not exists final_reminder_sent_at timestamptz;  -- to'y arafasi qoldiq eslatmasi
alter table public.bookings add column if not exists hold_reminder_sent_at  timestamptz;  -- avans muddati eslatmasi

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'bookings_price_mode_chk') then
    alter table public.bookings add constraint bookings_price_mode_chk
      check (price_mode in ('guest','total'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'bookings_total_price_nonneg') then
    alter table public.bookings add constraint bookings_total_price_nonneg check (total_price >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'bookings_cancel_penalty_nonneg') then
    alter table public.bookings add constraint bookings_cancel_penalty_nonneg check (cancel_penalty >= 0);
  end if;
end $$;

-- Sweeper so'rovlari: hold muddati o'tgan 'band'lar; mijozning o'z bandlari.
create index if not exists bookings_hold_idx on public.bookings (hold_until) where status = 'band' and hold_until is not null;
create index if not exists bookings_client_user_idx on public.bookings (client_user_id) where client_user_id is not null;
-- Telefon bo'yicha mijoz autofill (POST /bookings da telefon → ism) va off-app bog'lash
create index if not exists bookings_user_phone_idx on public.bookings (user_id, client_phone);
-- BACKFILL: eski bandlarda telefon "+998 90 123-45-67" ko'rinishida; endi FAQAT raqam
-- (backend normPhone bilan bir xil). Idempotent — raqamli qatorlar o'zgarmaydi.
update public.bookings
   set client_phone = nullif(regexp_replace(client_phone, '\D', '', 'g'), '')
 where client_phone is not null and client_phone ~ '\D';
-- Mavjud mijozlarni Trustbook profillariga bog'lash (telefon mos kelsa)
update public.bookings b
   set client_user_id = p.id
  from public.profiles p
 where b.client_user_id is null and b.client_phone is not null
   and p.phone = b.client_phone and p.deleted_at is null;

-- ---------------------------------------------------------------------
-- 5) booking_payments — 'qaytarim' (mijozga QAYTARILGAN pul, jamidan ayiriladi)
-- ---------------------------------------------------------------------
do $$ begin
  if exists (select 1 from pg_constraint
             where conname = 'booking_payments_kind_check' and conrelid = 'public.booking_payments'::regclass) then
    alter table public.booking_payments drop constraint booking_payments_kind_check;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'booking_payments_kind_chk') then
    alter table public.booking_payments add constraint booking_payments_kind_chk
      check (kind in ('avans','yakuniy','qaytarim'));
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 5b) module_subs.units — per_unit modul (to'yxona: HAR ZAL $21/oy, PO 2026-09-08).
--     SKU trust_toyxona_N_monthly -> units=N. Eski qatorlar 1.
-- ---------------------------------------------------------------------
alter table public.module_subs add column if not exists units int not null default 1;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'module_subs_units_chk') then
    alter table public.module_subs add constraint module_subs_units_chk check (units >= 1 and units <= 50);
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 6) RLS — 021 naqshi: yoqilgan, policy YO'Q, faqat service_role.
-- ---------------------------------------------------------------------
alter table public.hall_menu_items enable row level security;
alter table public.hall_services   enable row level security;
revoke all on public.hall_menu_items from anon, authenticated;
revoke all on public.hall_services   from anon, authenticated;

-- ---------------------------------------------------------------------
-- 7) notifications.type — to'yxona sweeper turlari (011 ro'yxati + 2 yangi):
--    'toy_hold' — avans muddati o'tdi, band avto-bekor qilindi (egaga);
--    'toy_due'  — to'y arafasi, qoldiq bor (egaga). Mobil: 'toy_*' → to'yxona bo'limi.
-- ---------------------------------------------------------------------
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in (
    'req','ok','rem','edit','rej','link_new','link_acc','link_rej','op_new','msg',
    'debt_new','debt_confirm','debt_reject','repay_new','settle_new','edit_req','review_req',
    'circle_invite','circle_turn','circle_paid','circle_confirm','circle_due','circle_joined',
    'circle_closed','toy_hold','toy_due'
  ));

insert into public.schema_migrations (version) values ('024') on conflict do nothing;

-- ===== QO'LDA TEKSHIRISH (ixtiyoriy) =====
-- select column_name from information_schema.columns where table_name='bookings' and column_name in ('price_mode','hold_until','cancel_penalty','client_user_id');
-- select conname from pg_constraint where conname in ('booking_payments_kind_chk','booking_items_amount_nonneg');
-- select count(*) from public.hall_services; -- 0 (yangi)

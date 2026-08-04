-- 021 — TO'YXONA moduli (to'yxona / banket zali boshqaruvi).
--   Egasi SANA + VAQT (slot) sotadi. Bir kunda 3 ta slot:
--     'nahor'   — nahorgi osh (erta tongdagi osh; O'zbekistonda alohida marosim),
--     'tushlik' — tushlik ziyofati,
--     'kechki'  — kechki to'y.
--   Pul hisobi: mehmon soni × bir mehmon narxi (food) + qo'shimcha xizmatlar
--   (musiqa, fotograf, tort, bezak, salyut — booking_items) − to'lovlar
--   (avans sanani ushlab turadi, yakuniy to'lov to'y kuni — booking_payments).
--
--   KO'P TO'YXONA (asosiy holat): bitta ega BIR NECHTA to'yxona yuritishi mumkin
--   va HAR BIRI ALOHIDA HISOB yuritadi (alohida kalendar, alohida pul yakuni).
--   `halls` qatori = bitta TO'YXONA (bandlanadigan obyekt), zal ichidagi xona emas —
--   ikkita zali bor ega ikkita qator ochadi. Obuna ham HAR TO'YXONAGA $24/oy
--   (hisob-kitob subs sessiyasida: archived = false bo'lgan qatorlar sanaladi).
--
--   ENG KATTA XATAR: IKKI MARTA BAND QILISH (double booking) — bitta to'yxona,
--   bitta sana, bitta slot ikki mijozga sotilishi. Bu SXEMA darajasida imkonsiz
--   qilingan (pastdagi partial unique indeks) — dastur tekshiruvi (read-then-write)
--   ikki parallel so'rovda yetarli emas, chunki ikkalasi ham "bo'sh" deb ko'radi.
--
-- Idempotent. Supabase SQL Editor'da QO'LDA ishga tushiring (019/020 kabi).
-- Backend bu jadvallarsiz ham ishga tushadi (faqat /api/toyxona 500 qaytaradi),
-- shuning uchun migratsiyani deploy'dan OLDIN qo'llang.

-- Oldingi migratsiyalar qo'llanmagan bo'lsa ham skript yiqilmasin (018 da yaratiladi)
create table if not exists public.schema_migrations (
  version    text primary key,
  applied_at timestamptz not null default now()
);
alter table public.schema_migrations enable row level security;

-- ---------------------------------------------------------------------
-- 1) TO'YXONALAR (halls) — bitta egada bir nechta to'yxona bo'lishi mumkin,
--    har biri alohida hisob. Bitta to'yxonali egalar umuman qator yaratmasligi
--    mumkin (bookings.hall_id NULL — pastdagi coalesce indeksiga qarang).
--    price_per_guest — narx TOIFALARI (hall_menus) yaratmagan egalar uchun
--    ixtiyoriy DEFAULT/zaxira narx. Toifa bo'lsa — narx o'shandan olinadi.
-- ---------------------------------------------------------------------
create table if not exists public.halls (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  name            text not null,
  capacity        int,
  price_per_guest bigint default 0,   -- UZS, butun son (tiyin yo'q)
  sort            int default 0,
  archived        boolean default false,
  created_at      timestamptz default now()
);

create index if not exists halls_user_idx on public.halls (user_id, sort);

-- ---------------------------------------------------------------------
-- 2) NARX TOIFALARI (hall_menus) — "stol/menyu" darajalari.
--    Ega toifalarni BIR MARTA belgilaydi (masalan "Oddiy — 150 000",
--    "Lyuks — 200 000") va band qilishda BITTASINI tanlaydi.
--    hall_id — qaysi to'yxonaga tegishli (to'yxona o'chsa toifalari ham o'chadi).
-- ---------------------------------------------------------------------
create table if not exists public.hall_menus (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  hall_id         uuid references public.halls(id) on delete cascade,
  title           text not null,
  price_per_guest bigint not null check (price_per_guest >= 0),
  sort            int default 0,
  archived        boolean default false,
  created_at      timestamptz default now()
);

create index if not exists hall_menus_user_hall_idx on public.hall_menus (user_id, hall_id);

-- ---------------------------------------------------------------------
-- 3) BANDLAR (bookings) — sana + slot + mijoz.
--
--    SNAPSHOT QOIDASI (MUHIM): bandning price_per_guest va menu_title ustunlari
--    band qilingan PAYTDAGI narx va toifa nomining NUSXASI. Ega keyinchalik narx
--    ro'yxatini o'zgartirsa (hall_menus.price_per_guest yangilansa) yoki toifani
--    o'chirsa — O'TGAN bandlarning puli HECH QACHON qayta yozilmaydi. Shu sababli
--    menu_id `on delete set null`, lekin menu_title/price_per_guest qoladi:
--    shartnoma summasi o'zgarmas bo'lishi kerak (aks holda avans/qoldiq hisobi
--    orqaga qarab buziladi).
--
--    status: 'band' (avanssiz band) -> 'tasdiq' (avans olindi) ->
--            'yakun' (to'liq to'landi/o'tkazildi); 'bekor' — bekor qilingan.
-- ---------------------------------------------------------------------
create table if not exists public.bookings (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  -- To'yxona o'chirilsa band YO'QOLMAYDI (pul/tarix qoladi) — hall_id NULL bo'ladi
  hall_id         uuid references public.halls(id) on delete set null,
  menu_id         uuid references public.hall_menus(id) on delete set null,
  menu_title      text,               -- SNAPSHOT: tanlangan toifa nomi
  event_date      date not null,
  slot            text not null check (slot in ('nahor','tushlik','kechki')),
  client_name     text not null,
  client_phone    text,
  guests          int not null check (guests > 0),
  -- SNAPSHOT: o'sha paytdagi narx. MANFIY BO'LMASIN — manfiy narx computeTotals'da
  -- food = guests × narx ni manfiy qilib, jami summani JIMGINA kamaytirardi
  -- (hall_menus.price_per_guest da shunday check bor edi, bu yerda yo'q edi).
  price_per_guest bigint not null default 0 check (price_per_guest >= 0),
  note            text,
  status          text not null default 'band'
                  check (status in ('band','tasdiq','yakun','bekor')),
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- 021 ning oldingi (toifasiz) varianti allaqachon qo'llangan bo'lsa — ustunlarni qo'shamiz
alter table public.bookings add column if not exists menu_id uuid references public.hall_menus(id) on delete set null;
alter table public.bookings add column if not exists menu_title text;

-- Yuqoridagi `create table if not exists` jadval MAVJUD bo'lsa CHECK'ni qo'shmaydi —
-- shuning uchun cheklovni alohida, idempotent qo'shamiz (018 naqshi).
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'bookings_price_nonneg') then
    alter table public.bookings add constraint bookings_price_nonneg
      check (price_per_guest >= 0) not valid;
  end if;
end $$;

-- Oylik kalendar so'rovi: where user_id = ? and event_date between ? and ?
create index if not exists bookings_user_date_idx on public.bookings (user_id, event_date);
-- To'yxona bo'yicha alohida hisob (GET /bookings?hall_id=..., /summary?hall_id=...)
create index if not exists bookings_user_hall_date_idx on public.bookings (user_id, hall_id, event_date);

-- ===== IKKI MARTA BAND QILISH QALQONI =====
-- (ega, to'yxona, sana, slot) — bekor qilinganlardan tashqari — YAGONA.
-- DIQQAT — hall_id NULL: SQL'da NULL <> NULL, shuning uchun oddiy unique indeks
-- to'yxonasiz (bitta obyektli) egalarni HIMOYA QILMAS EDI — ular xohlagancha bir
-- sana + bir slotga bir necha band yozaverardi. Shu sababli indeks ifodasida NULL
-- nol-UUID ga aylantiriladi: barcha "obyektsiz" qatorlar bitta guruhga tushadi.
-- Yon ta'siri (ATAYLAB): to'yxona o'chirilganda (on delete set null) bir necha eski
-- band bir xil (sana, slot) ga tushib qolsa, indeks buzilib DELETE yiqilishi
-- mumkin — bunday holatda avval o'sha bandlarni boshqa to'yxonaga ko'chiring yoki
-- 'bekor' qiling. Ikki marta sotilgan sanadan ko'ra bu ancha arzon.
-- DIQQAT — `if not exists` BU YERDA ISHLATILMAYDI: u indeksni NOM bo'yicha
-- taqqoslaydi. Agar shu nomli boshqacha (masalan coalesce'siz yoki `where`siz)
-- eski indeks allaqachon mavjud bo'lsa, Postgres shunchaki NOTICE chiqarib
-- yangi ta'rifni JIMGINA qo'llamas edi — to'yxonasiz egalar himoyasiz qolib,
-- buni hech kim sezmasdi. Shuning uchun avval DROP, keyin CREATE:
-- ta'rif har doim aynan quyidagicha bo'lishi KAFOLATLANADI.
-- (Drop xavfsiz: indeks ma'lumot saqlamaydi, qayta quriladi.)
drop index if exists public.bookings_slot_uidx;
create unique index bookings_slot_uidx
  on public.bookings (
    user_id,
    (coalesce(hall_id, '00000000-0000-0000-0000-000000000000'::uuid)),
    event_date,
    slot
  )
  where status <> 'bekor';

-- ---------------------------------------------------------------------
-- 4) QO'SHIMCHA XIZMATLAR (booking_items) — musiqa, fotograf, tort, bezak, salyut.
--    amount — BIR DONA narxi; jami = amount * qty.
-- ---------------------------------------------------------------------
create table if not exists public.booking_items (
  id         uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  title      text not null,
  amount     bigint not null check (amount > 0),
  qty        int not null default 1 check (qty > 0),
  created_at timestamptz default now()
);

create index if not exists booking_items_booking_idx on public.booking_items (booking_id);

-- ---------------------------------------------------------------------
-- 5) TO'LOVLAR (booking_payments) — 'avans' (sanani ushlaydi) / 'yakuniy'.
--    paid_at — HAQIQIY to'lov sanasi (created_at dan farq qilishi mumkin:
--    egasi kechagi avansni bugun kiritishi normal).
-- ---------------------------------------------------------------------
create table if not exists public.booking_payments (
  id         uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  amount     bigint not null check (amount > 0),
  kind       text not null default 'avans' check (kind in ('avans','yakuniy')),
  paid_at    timestamptz default now(),
  note       text,
  created_at timestamptz default now()
);

create index if not exists booking_payments_booking_idx on public.booking_payments (booking_id);

-- ---------------------------------------------------------------------
-- 6) RLS — 012/020 naqshi: RLS YOQILGAN, policy ATAYLAB YO'Q, anon/authenticated
--    uchun GRANT ham yo'q. Ya'ni bu jadvallarga FAQAT service_role (backend,
--    supabaseAdmin) tegadi; klient hamma narsani /api/toyxona orqali oladi.
--    Egalik KODDA tekshiriladi (har so'rov user_id bo'yicha filtrlanadi).
-- ---------------------------------------------------------------------
alter table public.halls            enable row level security;
alter table public.hall_menus       enable row level security;
alter table public.bookings         enable row level security;
alter table public.booking_items    enable row level security;
alter table public.booking_payments enable row level security;

revoke all on public.halls            from anon, authenticated;
revoke all on public.hall_menus       from anon, authenticated;
revoke all on public.bookings         from anon, authenticated;
revoke all on public.booking_items    from anon, authenticated;
revoke all on public.booking_payments from anon, authenticated;

insert into public.schema_migrations(version) values ('021') on conflict do nothing;

-- =====================================================================
-- QO'LDA TEKSHIRISH (skriptdan keyin alohida ishga tushiring)
-- =====================================================================
-- 0) QALQON TA'RIFI HAQIQATAN QO'LLANDIMI (eng muhim tekshiruv — buni O'TKAZIB
--    YUBORMANG). Natijada `coalesce`, `event_date`, `slot` VA `WHERE status <> 'bekor'`
--    ko'rinishi SHART; ko'rinmasa eski ta'rif qolib ketgan:
--      select indexdef from pg_indexes
--       where schemaname = 'public' and indexname = 'bookings_slot_uidx';
--    Ustunlar to'liq tushdimi (menu_id / menu_title / price_per_guest check):
--      select column_name, data_type, is_nullable, column_default
--        from information_schema.columns
--       where table_schema = 'public' and table_name = 'bookings'
--       order by ordinal_position;
--      select conname, pg_get_constraintdef(oid) from pg_constraint
--       where conrelid = 'public.bookings'::regclass;
--
-- 1) Qalqon ishlayaptimi (ikkinchisi 23505 bilan yiqilishi KERAK):
--      insert into public.bookings(user_id, event_date, slot, client_name, guests)
--        values ('<user-uuid>', '2026-09-01', 'kechki', 'Test A', 100);
--      insert into public.bookings(user_id, event_date, slot, client_name, guests)
--        values ('<user-uuid>', '2026-09-01', 'kechki', 'Test B', 100);  -- xato berishi shart
-- 2) Bekor qilingan band joyni bo'shatadimi:
--      update public.bookings set status = 'bekor' where client_name = 'Test A';
--      -- endi 'Test B' insert'i o'tishi kerak
-- 3) Ikki TO'YXONA bir sanani bemalol sotadimi (konflikt BO'LMASLIGI kerak):
--      -- hall_id ni ikki xil zalga qo'yib, 1-banddagi kabi insert qiling
-- 4) Tozalash:  delete from public.bookings where client_name in ('Test A','Test B');

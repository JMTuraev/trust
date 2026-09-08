-- 023 — IJARA: pul birligi (currency) va oylik to'lov kuni (due_day).
--
--   Mahsulot sababi (PO 2026-09-08): O'zbekistonda ijara ikki xil valyutada
--   kelishiladi — so'm yoki dollar. Bitta egada ikkalasi ham bo'lishi mumkin,
--   shuning uchun valyuta PROFILDA emas, HAR UYDA saqlanadi.
--   due_day — oyning nechanchi kunida to'lov kutiladi (1..31). Bu rent_charges
--   yaratishda due_date ni avtomatik to'ldirish uchun DEFAULT; o'tgan
--   yozuvlarga TA'SIR QILMAYDI (rent_amount bilan bir xil falsafa).
--
--   MUHIM: rent_amount ma'nosi o'zgarmadi — u BUTUN SON, valyutasi shu
--   qatordagi currency bilan o'qiladi. Eski qatorlar 'UZS' bo'lib qoladi
--   (default), ya'ni migratsiya hech qanday summani qayta hisoblamaydi.
--
-- Idempotent. Supabase SQL Editor'da QO'LDA ishga tushiring (022 kabi).
-- Backend bu ustunlarsiz ham ishlaydi (currency/due_day shunchaki null
-- qaytadi), shuning uchun deploy tartibi qat'iy emas — lekin avval qo'llang.

create table if not exists public.schema_migrations (
  version    text primary key,
  applied_at timestamptz not null default now()
);
alter table public.schema_migrations enable row level security;

-- ---------------------------------------------------------------------
-- 1) currency — 'UZS' | 'USD'. NOT NULL + default: mobil hech qachon
--    "valyutasiz" uy ko'rmasin (null bo'lsa UI qaysi belgini chizishni
--    bilmay qoladi va summa noto'g'ri o'qiladi — pul xatosi).
-- ---------------------------------------------------------------------
alter table public.rent_houses
  add column if not exists currency text not null default 'UZS';

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'public.rent_houses'::regclass
       and conname  = 'rent_houses_currency_chk'
  ) then
    alter table public.rent_houses
      add constraint rent_houses_currency_chk check (currency in ('UZS','USD'));
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 2) due_day — oylik to'lov kuni (1..31) yoki NULL ("kelishilmagan").
--    NULL ATAYLAB RUXSAT: eski uylarda bu ma'lumot yo'q va uni o'ylab
--    topib qo'yish (masalan 1-kun) egani yolg'on kechikish bildirishnomasi
--    bilan bezovta qilardi. NULL = eslatma yo'q.
--    29/30/31 kunlar: qisqa oyda oyning OXIRGI kuniga siqiladi — bu
--    dasturda (src/routes/ijara.js dueDateFor) hal qilinadi, DB da emas.
-- ---------------------------------------------------------------------
alter table public.rent_houses
  add column if not exists due_day int;

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'public.rent_houses'::regclass
       and conname  = 'rent_houses_due_day_chk'
  ) then
    alter table public.rent_houses
      add constraint rent_houses_due_day_chk
      check (due_day is null or (due_day >= 1 and due_day <= 31));
  end if;
end $$;

insert into public.schema_migrations(version) values ('023') on conflict do nothing;

-- =====================================================================
-- QO'LDA TEKSHIRISH
-- =====================================================================
-- 0) Ustunlar tushdimi:
--      select column_name, data_type, is_nullable, column_default
--        from information_schema.columns
--       where table_schema='public' and table_name='rent_houses'
--         and column_name in ('currency','due_day');
-- 1) Eski qatorlar UZS bo'ldimi (0 qator qaytishi SHART):
--      select count(*) from public.rent_houses where currency is null;
-- 2) Cheklovlar ishlayaptimi (ikkalasi ham xato berishi SHART):
--      update public.rent_houses set currency = 'EUR' where id = '<house-uuid>';
--      update public.rent_houses set due_day  = 32    where id = '<house-uuid>';
-- 3) NULL due_day ruxsat etiladimi (O'TISHI shart):
--      update public.rent_houses set due_day = null where id = '<house-uuid>';

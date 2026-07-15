-- 006: telefon qidiruv indeksi + FK ON DELETE
-- Maqsad:
--   1) Ro'yxatdan o'tmagan kontragentni telefon bo'yicha qidirish (otp.js linkPartners,
--      004 trigger, POST /partners dublikat tekshiruvi) — full-scan o'rniga indeks.
--   2) Profil/akkaunt o'chirilganda bog'liq yozuvlar o'chishni BLOKLAMASIN (RESTRICT o'rniga
--      SET NULL): bog'lanish/audit maydonlari NULL bo'ladi, tarix (operatsiya/xarajat) saqlanadi.
-- Idempotent: qayta ishga tushirilsa xato bermaydi (drop ... if exists / create ... if not exists).

-- 1) Qisman indeks: aynan so'rov predikatiga mos (counterparty_id is null bo'lgan pending qatorlar)
create index if not exists partners_cp_phone_idx
  on public.partners (counterparty_phone)
  where counterparty_id is null;

-- 2) FK'larni ON DELETE SET NULL ga o'tkazish -------------------------------------------------

-- partners.counterparty_id (nullable) — bog'lanish uziladi, sotuvchi daftari qoladi
alter table public.partners drop constraint if exists partners_counterparty_id_fkey;
alter table public.partners
  add constraint partners_counterparty_id_fkey
  foreign key (counterparty_id) references public.profiles(id) on delete set null;

-- operations.counterparty_id (nullable)
alter table public.operations drop constraint if exists operations_counterparty_id_fkey;
alter table public.operations
  add constraint operations_counterparty_id_fkey
  foreign key (counterparty_id) references public.profiles(id) on delete set null;

-- operations.created_by (002'da NOT NULL) — SET NULL uchun avval nullable qilamiz.
-- Muallif o'chsa ham operatsiya yozuvi (dalil) saqlanishi kerak.
alter table public.operations alter column created_by drop not null;
alter table public.operations drop constraint if exists operations_created_by_fkey;
alter table public.operations
  add constraint operations_created_by_fkey
  foreign key (created_by) references public.profiles(id) on delete set null;

-- op_history.changed_by (nullable) — audit maydoni
alter table public.op_history drop constraint if exists op_history_changed_by_fkey;
alter table public.op_history
  add constraint op_history_changed_by_fkey
  foreign key (changed_by) references public.profiles(id) on delete set null;

-- edit_requests.requested_by (002'da NOT NULL) — nullable + SET NULL
alter table public.edit_requests alter column requested_by drop not null;
alter table public.edit_requests drop constraint if exists edit_requests_requested_by_fkey;
alter table public.edit_requests
  add constraint edit_requests_requested_by_fkey
  foreign key (requested_by) references public.profiles(id) on delete set null;

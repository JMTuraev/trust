-- =====================================================================
-- 018 — 2026-08-02 audit tuzatishlari (Supabase SQL Editor'da ishga tushiring)
--
-- Bu migratsiya IDEMPOTENT: xavfsiz qayta ishga tushirsa bo'ladi.
-- Har blok nima uchun kerakligi izohlangan — keyingi sessiyalar uchun.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0) MIGRATSIYA HISOBI
-- Loyihada migratsiya runner yo'q — fayllar SQL Editor'ga qo'lda qo'yiladi.
-- Shu sabab 003 ni tasodifan qayta ishga tushirish MUMKIN, u esa
-- `drop table public.debts cascade` qiladi — ya'ni BUTUN QARZ DAFTARI yo'qoladi.
-- Quyidagi jadval "qaysi migratsiya qo'llangan" ni yozib boradi.
-- ---------------------------------------------------------------------
create table if not exists public.schema_migrations (
  version    text primary key,
  applied_at timestamptz not null default now()
);
alter table public.schema_migrations enable row level security;

insert into public.schema_migrations(version) values
  ('001'),('002'),('003'),('004'),('005'),('006'),('007'),('008'),
  ('009'),('010'),('011'),('012'),('013'),('014'),('015'),('016'),('017')
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 1) 006 MIGRATSIYASI HECH QACHON QO'LLANMAGAN (audit topilmasi)
-- 006 ichida `alter table public.edit_requests ...` bor, lekin o'sha jadval
-- 004 da drop qilingan. ALTER'da IF EXISTS yo'q -> xato -> SQL Editor butun
-- skriptni ORQAGA QAYTARADI. Ya'ni 006 va'da qilgan hamma narsa yo'q:
-- indeks ham, ON DELETE qoidalari ham. Quyida ularni qayta qo'llaymiz.
-- ---------------------------------------------------------------------

-- 1a) LOGIN yo'lidagi indeks. linkPartners() HAR BIR kirishda
-- `update partners ... where counterparty_phone = ?` bajaradi. Indekssiz bu
-- to'liq jadval skani + qator qulflari — partners o'sgan sari login sekinlashadi.
create index if not exists partners_cp_phone_idx
  on public.partners (counterparty_phone) where counterparty_id is null;

-- 1b) Profil o'chirilganda bog'liq yozuvlar BLOKLAMASIN (006 ning maqsadi).
do $$ begin
  alter table public.partners drop constraint if exists partners_counterparty_id_fkey;
  alter table public.partners add constraint partners_counterparty_id_fkey
    foreign key (counterparty_id) references public.profiles(id) on delete set null;

  alter table public.operations drop constraint if exists operations_counterparty_id_fkey;
  alter table public.operations add constraint operations_counterparty_id_fkey
    foreign key (counterparty_id) references public.profiles(id) on delete set null;

  alter table public.operations alter column created_by drop not null;
  alter table public.operations drop constraint if exists operations_created_by_fkey;
  alter table public.operations add constraint operations_created_by_fkey
    foreign key (created_by) references public.profiles(id) on delete set null;

  alter table public.op_history drop constraint if exists op_history_changed_by_fkey;
  alter table public.op_history add constraint op_history_changed_by_fkey
    foreign key (changed_by) references public.profiles(id) on delete set null;
end $$;

-- ---------------------------------------------------------------------
-- 2) RLS: profiles UPDATE siyosatida WITH CHECK yo'q edi (audit topilmasi)
-- Bu — sxemadagi YAGONA yozish siyosati va u faqat USING bilan yozilgan.
-- Anon kalit ochiq (mobil klientda yo'q, lekin .env.example'da URL bor va anon
-- kalit Supabase dizayni bo'yicha "public"). Supabase Auth orqali ro'yxatdan
-- o'tgan istalgan odam o'z qatoriga `premium_until = '2099-01-01'` yozib,
-- BEPUL premium olishi mumkin edi. To'g'ri yechim — ustun darajasidagi GRANT.
-- ---------------------------------------------------------------------
drop policy if exists "own profile update" on public.profiles;
create policy "own profile update" on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

revoke update on public.profiles from anon, authenticated;
grant  update (full_name, avatar_url, notif_enabled) on public.profiles to authenticated;

-- ---------------------------------------------------------------------
-- 3) QARZ DAFTARI YAXLITLIGI (dastur mantiqini baza darajasida mustahkamlash)
-- NOT VALID bilan qo'shamiz: uzoq qulf bo'lmaydi va eski qatorlar deployni
-- bloklamaydi. Buzilgan qator yo'qligini tekshirgach VALIDATE qilinadi (pastda).
-- ---------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'debts_paid_le_amount') then
    alter table public.debts add constraint debts_paid_le_amount
      check (paid >= 0 and paid <= amount) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'debts_forgiven_le_amount') then
    alter table public.debts add constraint debts_forgiven_le_amount
      check (forgiven >= 0 and forgiven <= amount) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'debts_direction_required') then
    alter table public.debts add constraint debts_direction_required
      check (kind <> 'debt' or direction is not null) not valid;
  end if;
end $$;

-- Bitta qarzda bir vaqtda faqat BITTA tasdiqlanmagan amal bo'lishi mumkin.
-- Dasturda tekshiruv bor, lekin u "o'qi -> yoz" ko'rinishida: ikki marta bosilsa
-- yoki so'rov qayta yuborilsa ikkita pending amal yaratilardi va ulardan biri
-- tasdiqlangach hisobga TUSHMAY qolardi (foydalanuvchi pulini yo'qotardi).
create unique index if not exists debts_one_pending_op_idx
  on public.debts (ref_id)
  where kind in ('repay','settle') and status = 'pending';

-- Kvota hisobi (subscription.js -> countUsage) uchun indeks: har bir yangi
-- qarz/xarajat yozuvida bu so'rov ishlaydi.
create index if not exists debts_created_by_kind_idx
  on public.debts (created_by) where kind = 'debt';

-- ---------------------------------------------------------------------
-- 4) DOIRA (circles) — bitta odam ikki o'rin egallay olmasin (audit topilmasi)
-- Havola orqali qo'shilgan a'zoning invited_phone'i NULL bo'ladi, shuning uchun
-- egasi keyin uni TELEFON orqali ham taklif qilsa, ikkinchi qator yaratilardi:
-- u har aylanada IKKI marta to'laydi, lekin faqat bittasini yopa oladi va
-- qozonni IKKI marta oladi.
-- ---------------------------------------------------------------------
create unique index if not exists circle_members_circle_user_uidx
  on public.circle_members (circle_id, user_id) where user_id is not null;
create unique index if not exists circle_members_circle_phone_uidx
  on public.circle_members (circle_id, invited_phone)
  where invited_phone is not null and status <> 'declined';

-- ---------------------------------------------------------------------
-- 5) OPERATIONS.status DEFAULT o'z CHECK'iga zid edi (002 default 'pending',
-- 004 esa CHECK'ni ('active','archived','cancelled') ga o'zgartirgan).
-- Hozir kod har doim 'active' yuboradi, lekin har qanday yangi yozish yo'li
-- (backfill, admin skript, COPY) darhol yiqilardi.
-- ---------------------------------------------------------------------
alter table public.operations alter column status set default 'active';

-- ---------------------------------------------------------------------
-- 6) TOIFALAR: UNIQUE registrga sezgir edi, kod esa registrsiz taqqoslaydi.
-- 'Transport' va 'transport' ikkalasi ham saqlanardi; keyin nom o'zgartirish
-- (aniq moslik bo'yicha) papkani IKKIGA bo'lib yuborardi.
-- ---------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_indexes
                 where schemaname = 'public' and indexname = 'categories_user_lower_name_uidx') then
    -- Avval dublikatlarni birlashtiramiz (eng eskisi qoladi)
    with dups as (
      select id, row_number() over (partition by user_id, lower(name) order by created_at, id) rn
      from public.categories
    )
    delete from public.categories c using dups d where c.id = d.id and d.rn > 1;

    alter table public.categories drop constraint if exists categories_user_id_name_key;
    create unique index categories_user_lower_name_uidx
      on public.categories (user_id, lower(name));
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 7) YORDAM CHATI: tg_message_id UNIQUE emas edi -> maybeSingle() bir nechta
-- qator topsa xato beradi va admin javobi JIMGINA yo'qoladi (foydalanuvchi
-- javob olmaydi, admin esa yuborilgan deb o'ylaydi).
-- ---------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_indexes
                 where schemaname = 'public' and indexname = 'support_tgmsg_uidx') then
    with dups as (
      select id, row_number() over (partition by tg_message_id order by created_at, id) rn
      from public.support_messages where tg_message_id is not null
    )
    update public.support_messages s set tg_message_id = null
    from dups d where s.id = d.id and d.rn > 1;

    create unique index support_tgmsg_uidx
      on public.support_messages (tg_message_id) where tg_message_id is not null;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 8) OTP: takroriy yozuvlarga qarshi + eski kodlarni tozalash
-- ---------------------------------------------------------------------
create index if not exists otp_phone_created_idx on public.otp_codes (phone, created_at desc);
delete from public.otp_codes where expires_at < now() - interval '1 day';

-- =====================================================================
-- QO'LDA TEKSHIRISH (bu skriptdan keyin alohida ishga tushiring)
-- =====================================================================
-- 1) Yaxlitlik cheklovlarini tasdiqlash (buzilgan qator yo'q bo'lsa):
--      select count(*) from public.debts where paid < 0 or paid > amount;       -- 0 bo'lishi kerak
--      select count(*) from public.debts where forgiven < 0 or forgiven > amount; -- 0 bo'lishi kerak
--      select count(*) from public.debts where kind = 'debt' and direction is null; -- 0 bo'lishi kerak
--    Hammasi 0 bo'lsa:
--      alter table public.debts validate constraint debts_paid_le_amount;
--      alter table public.debts validate constraint debts_forgiven_le_amount;
--      alter table public.debts validate constraint debts_direction_required;
--
-- 2) 006 tuzatilganini tekshirish (confdeltype 'n' = SET NULL):
--      select conname, confdeltype from pg_constraint
--       where conrelid in ('public.partners'::regclass,'public.operations'::regclass);
--      select indexname from pg_indexes where tablename = 'partners';
--
-- 3) Doira dublikatlari bo'lsa indeks yaratilmaydi — avval tekshiring:
--      select circle_id, user_id, count(*) from public.circle_members
--       where user_id is not null group by 1,2 having count(*) > 1;
-- =====================================================================

insert into public.schema_migrations(version) values ('018') on conflict do nothing;

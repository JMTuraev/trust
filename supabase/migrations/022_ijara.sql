-- 022 — IJARADAGI UYLAR (ijara) moduli. Modul kaliti: 'ijarachi' (020 dagi
--   check-constraint'da qatnashadi — NOMINI O'ZGARTIRMANG; ko'rinadigan nom l10n'dan).
--
--   Mahsulot modeli (PO 2026-08-04): uy EGASI (ijaraga beruvchi) ijaradagi uylarini
--   yuritadi. Har uyda IJARACHI ism + telefon sifatida saqlanadi — ijarachiga
--   AKKAUNT KERAK EMAS (v1), aynan to'yxonadagi mijoz kabi.
--
--   Pul oqimi ikki bosqichli:
--     1) HISOBLANDI (rent_charges) — oy uchun hisoblangan to'lov: ijara haqi,
--        kommunal, boshqa. Bu "accrual" — hali pul emas, talab.
--     2) TO'LANDI  (rent_payments) — haqiqiy tushum. To'lov bitta hisob-kitobga
--        biriktirilishi (charge_id) YOKI biriktirilmasdan tushishi mumkin
--        (charge_id NULL — "avans/oldindan", keyin egasi taqsimlaydi).
--   Uy bo'yicha qoldiq = Σ(hisoblangan, bekor emas) − Σ(to'langan).
--
--   QAT'IY CHEGARA — BITTA HISOBDA 5 TA UY (PO 2026-08-04, MODULES.ijarachi.max_units).
--   Sabab: do'konlar (Play/App Store) miqdorli obunani qo'llab-quvvatlamaydi, shuning
--   uchun "har uyga $N" o'rniga bitta $13/oy obuna + qat'iy chegara tanlandi. Ko'proq
--   uy kerak bo'lsa foydalanuvchi BOSHQA TELEFON RAQAMI bilan alohida hisob ochadi
--   (PO: "bu bizga muammo emas"). Chegara IKKI QATLAMDA majburlanadi:
--     1) dastur (src/routes/ijara.js — chiroyli 403 xabar),
--     2) shu fayldagi TRIGGER — parallel ikki so'rov dastur tekshiruvini chetlab
--        o'tsa ham (ikkalasi ham "4 ta bor" deb ko'radi) 6-uy YOZILMAYDI.
--   021 dagi ikki-marta-band qalqoni bilan bir xil falsafa: pulga ta'sir qiladigan
--   invariant faqat dastur darajasida qolmasin.
--
--   BEPUL TARIF: FREE_IJARA_CHARGES (env, default 5) ta hisob-kitob yozuvi.
--   Kvota `rent_charges` da user_id bo'yicha, status <> 'bekor' qatorlar bilan
--   sanaladi (src/lib/subscription.js: countIjaraCharges) — ya'ni BEKOR QILINGAN
--   yozuv kvotani YEMAYDI (to'yxona bilan bir xil qoida).
--
-- Idempotent. Supabase SQL Editor'da QO'LDA ishga tushiring (019/020/021 kabi).
-- Backend bu jadvallarsiz ham ishga tushadi (faqat /api/ijara 500 qaytaradi),
-- shuning uchun migratsiyani deploy'dan OLDIN qo'llang.

-- Oldingi migratsiyalar qo'llanmagan bo'lsa ham skript yiqilmasin (018 da yaratiladi)
create table if not exists public.schema_migrations (
  version    text primary key,
  applied_at timestamptz not null default now()
);
alter table public.schema_migrations enable row level security;

-- ---------------------------------------------------------------------
-- 1) UYLAR (rent_houses) — bitta qator = bitta ijaraga berilgan uy/kvartira.
--    IJARACHI shu qatorda (tenant_name / tenant_phone) — alohida jadval ham,
--    akkaunt ham yo'q (v1). Ijarachi almashsa egasi shu ikki maydonni yangilaydi;
--    o'tgan oylarning hisob-kitobi (rent_charges) TEGILMAYDI.
--    rent_amount — oylik ijara haqi (UZS, butun son) — YANGI hisob-kitob
--    yaratishda DEFAULT sifatida ishlatiladi, o'tgan yozuvlarga ta'sir qilmaydi.
--    O'CHIRISH YO'Q — faqat archived = true (tarix va pul yakuni yo'qolmasin).
-- ---------------------------------------------------------------------
create table if not exists public.rent_houses (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  name         text not null,                 -- uy nomi yoki manzili
  tenant_name  text,                          -- ijarachi ismi (akkaunt emas)
  tenant_phone text,                          -- ijarachi telefoni (akkaunt emas)
  rent_amount  bigint not null default 0 check (rent_amount >= 0),  -- UZS, butun son
  -- NOT NULL ATAYLAB: trigger NULL ni coalesce bilan "faol" deb qaraydi, sanoq
  -- so'rovlari esa `archived = false` yozadi — NULL qator ikkalasida BOSHQACHA
  -- talqin qilinib, chegaradan sirg'alib chiqardi. NULL umuman bo'lmasin.
  archived     boolean not null default false,
  sort         int not null default 0,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

create index if not exists rent_houses_user_idx on public.rent_houses (user_id, sort);
-- 5-uy chegarasi sanog'i uchun (trigger va route ikkalasi ham shu so'rovni qiladi)
create index if not exists rent_houses_user_active_idx
  on public.rent_houses (user_id) where archived = false;

-- ===== 5 TA UY QALQONI =====
-- Nega trigger, nega oddiy CHECK emas: CHECK faqat BIR qatorni ko'radi, bu yerda
-- esa "shu egadagi arxivlanmagan qatorlar soni" kerak. Nega partial unique indeks
-- emas: uy qatorida tabiiy "slot raqami" yo'q (bo'lsa ham egasi uyni arxivlab-tiklab
-- teshiklar qoldirardi).
--
-- ADVISORY LOCK SHART: oddiy `select count(*)` READ COMMITTED da ikki parallel
-- tranzaksiyani TO'XTATMAYDI — ikkalasi ham "4 ta bor" deb ko'rib, ikkalasi ham
-- insert qilardi (natija: 6 ta uy, ya'ni to'lanmagan quvvat). Ega bo'yicha
-- xact-lock shu sanoqni ketma-ket qiladi va tranzaksiya oxirida o'zi bo'shaydi.
--
-- Chegara (5) shu yerda VA src/lib/subscription.js (MODULES.ijarachi.max_units)
-- da takrorlanadi — birini o'zgartirsangiz IKKINCHISINI HAM o'zgartiring.
create or replace function public.rent_houses_limit_guard()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $fn$
declare
  n int;
begin
  -- Arxivlangan uy chegaraga kirmaydi (egasi uyni arxivlab, o'rniga yangisini ochadi)
  if coalesce(new.archived, false) then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtext('rent_houses'), hashtext(new.user_id::text));
  select count(*) into n
    from public.rent_houses
   where user_id = new.user_id
     and archived = false
     and id <> new.id;          -- UPDATE'da qatorning O'ZI sanalmasin
  if n >= 5 then
    -- Xabardagi 'IJARA_HOUSE_LIMIT' — route uchun BELGI (isHouseLimitError):
    -- xom Postgres matni mijozga chiqmaydi, 403 + o'zbekcha xabarga aylanadi.
    raise exception 'IJARA_HOUSE_LIMIT: bitta hisobda ko''pi bilan 5 ta uy bo''lishi mumkin'
      using errcode = '23514';   -- check_violation
  end if;
  return new;
end
$fn$;

-- DIQQAT — ustun ro'yxatisiz (`update of ...` emas): PostgREST faqat o'zgargan
-- ustunlarni yuboradi, ustun ro'yxati bilan trigger ba'zi PATCH'larda umuman
-- ishlamay qolardi. Qator ≤ 5 ta bo'lgani uchun har update'dagi sanoq arzon.
drop trigger if exists rent_houses_limit_trg on public.rent_houses;
create trigger rent_houses_limit_trg
  before insert or update on public.rent_houses
  for each row execute function public.rent_houses_limit_guard();

-- ---------------------------------------------------------------------
-- 2) HISOB-KITOB (rent_charges) — "hisoblangan to'lov" (accrual).
--    period — OY, 'YYYY-MM' MATN ko'rinishida. Nega sana emas: yozuv butun OYGA
--    tegishli (10-avgustda kiritilgan avgust ijarasi ham avgustniki), mobil ham
--    oy bo'yicha guruhlaydi. due_date (to'lov muddati) ALOHIDA va IXTIYORIY —
--    shuning uchun oraliq filtri period bo'yicha ishlaydi: muddat qo'yilmagan
--    yozuv oylik ko'rinishdan JIMGINA tushib qolmaydi.
--    kind: 'ijara' (ijara haqi) · 'kommunal' (kommunal xizmatlar) · 'boshqa'.
--    status: 'kutilmoqda' -> 'tolangan' (to'liq to'landi) · 'bekor' (bekor qilingan).
--
--    MUHIM (kvota kontrakti): `user_id` VA `status` ustunlari
--    src/lib/subscription.js dagi countIjaraCharges tomonidan O'QILADI —
--    nomlarini o'zgartirmang.
--
--    house_id ON DELETE CASCADE: dasturda uy QAT'IY o'chirilmaydi (faqat arxiv),
--    shuning uchun bu yo'l amalda faqat qo'lda tozalashda ishlaydi va orfan
--    qatorlar qoldirmaydi. ARXIVLASH kvotani BO'SHATMAYDI (qatorlar joyida
--    qoladi) — "uyni arxivlab bepul kvotani tiklash" yo'li yopiq.
-- ---------------------------------------------------------------------
create table if not exists public.rent_charges (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  house_id   uuid not null references public.rent_houses(id) on delete cascade,
  period     text not null check (period ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),  -- 'YYYY-MM'
  kind       text not null default 'ijara' check (kind in ('ijara','kommunal','boshqa')),
  title      text,                                    -- ixtiyoriy izoh/nom
  amount     bigint not null check (amount > 0),      -- UZS, butun son
  due_date   date,                                    -- to'lov muddati (ixtiyoriy)
  status     text not null default 'kutilmoqda'
             check (status in ('kutilmoqda','tolangan','bekor')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Oylik ko'rinish: where user_id = ? and period between ? and ?
create index if not exists rent_charges_user_period_idx on public.rent_charges (user_id, period);
-- Bitta uy hisobi (GET /charges?house_id=..., /summary?house_id=...)
create index if not exists rent_charges_user_house_period_idx
  on public.rent_charges (user_id, house_id, period);
-- Kvota sanog'i (status <> 'bekor')
create index if not exists rent_charges_user_status_idx on public.rent_charges (user_id, status);

-- ---------------------------------------------------------------------
-- 3) TO'LOVLAR (rent_payments) — haqiqiy tushum.
--    charge_id NULL bo'lishi MUMKIN: ijarachi oldindan/aralash to'lasa egasi uni
--    hech qaysi hisob-kitobga biriktirmasdan yozadi ("taqsimlanmagan to'lov").
--    Shuning uchun house_id ALOHIDA saqlanadi (charge_id orqali hosil qilinmaydi).
--    paid_at — HAQIQIY to'lov vaqti (created_at dan farq qilishi normal:
--    egasi kechagi pulni bugun kiritadi).
--    charge_id ON DELETE SET NULL — hisob-kitob qat'iy o'chirilsa ham PUL
--    YO'QOLMAYDI (dastur uni faqat 'bekor' qiladi, lekin qalqon bo'lib turadi).
-- ---------------------------------------------------------------------
create table if not exists public.rent_payments (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  house_id   uuid not null references public.rent_houses(id) on delete cascade,
  charge_id  uuid references public.rent_charges(id) on delete set null,
  amount     bigint not null check (amount > 0),   -- UZS, butun son
  paid_at    timestamptz default now(),
  note       text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists rent_payments_user_paid_idx on public.rent_payments (user_id, paid_at);
create index if not exists rent_payments_charge_idx on public.rent_payments (charge_id);
create index if not exists rent_payments_house_idx on public.rent_payments (user_id, house_id);

-- ---------------------------------------------------------------------
-- 4) RLS — 012/020/021 naqshi: RLS YOQILGAN, policy ATAYLAB YO'Q, anon/authenticated
--    uchun GRANT ham yo'q. Ya'ni bu jadvallarga FAQAT service_role (backend,
--    supabaseAdmin) tegadi; klient hamma narsani /api/ijara orqali oladi.
--    Egalik KODDA tekshiriladi (har so'rov user_id bo'yicha filtrlanadi).
-- ---------------------------------------------------------------------
alter table public.rent_houses   enable row level security;
alter table public.rent_charges  enable row level security;
alter table public.rent_payments enable row level security;

revoke all on public.rent_houses   from anon, authenticated;
revoke all on public.rent_charges  from anon, authenticated;
revoke all on public.rent_payments from anon, authenticated;

insert into public.schema_migrations(version) values ('022') on conflict do nothing;

-- =====================================================================
-- QO'LDA TEKSHIRISH (skriptdan keyin alohida ishga tushiring)
-- =====================================================================
-- 0) Trigger o'rnatildimi (eng muhim tekshiruv — buni O'TKAZIB YUBORMANG):
--      select tgname, tgenabled from pg_trigger
--       where tgrelid = 'public.rent_houses'::regclass and not tgisinternal;
--    Ustunlar va cheklovlar to'liq tushdimi:
--      select column_name, data_type, is_nullable, column_default
--        from information_schema.columns
--       where table_schema = 'public' and table_name = 'rent_charges'
--       order by ordinal_position;
--      select conname, pg_get_constraintdef(oid) from pg_constraint
--       where conrelid = 'public.rent_charges'::regclass;
--
-- 1) 5-uy qalqoni ishlayaptimi (6-chisi 23514 bilan yiqilishi KERAK):
--      insert into public.rent_houses(user_id, name) values
--        ('<user-uuid>','Test 1'), ('<user-uuid>','Test 2'), ('<user-uuid>','Test 3'),
--        ('<user-uuid>','Test 4'), ('<user-uuid>','Test 5');
--      insert into public.rent_houses(user_id, name) values ('<user-uuid>','Test 6');  -- xato SHART
-- 2) Arxivlangan uy chegaraga kirmaydimi:
--      update public.rent_houses set archived = true where name = 'Test 1';
--      insert into public.rent_houses(user_id, name) values ('<user-uuid>','Test 6'); -- endi O'TADI
-- 3) Arxivdan qaytarish 6-uyga aylantirmaydimi (xato SHART):
--      update public.rent_houses set archived = false where name = 'Test 1';
-- 4) period formati qo'riqlanadimi (xato SHART):
--      insert into public.rent_charges(user_id, house_id, period, amount)
--        values ('<user-uuid>', '<house-uuid>', '2026-13', 100000);
-- 5) Tozalash:  delete from public.rent_houses where name like 'Test %';

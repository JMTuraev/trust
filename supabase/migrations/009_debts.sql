-- 009 — Qarz daftari (ledger) modeli.
-- Har qarz/qaytarish/hisob-kitob ALOHIDA yozuv (netting yo'q), ikki tomonlama tasdiq
-- (istisno: oneSided = off-Trust, tasdiqsiz darhol kuchga kiradi).
-- YANGI 'debts' jadval — eski 'operations' jadvaliga TEGILMAYDI (u link-model uchun ishlatiladi).
-- Eski v1 'debts' jadvali 003 migratsiyada drop qilingan — nom bo'sh.
-- Idempotent. Supabase SQL Editor'da ishga tushiring.

-- ============================================================
-- 1. DEBTS: qarz daftari yozuvlari
--    kind: debt (qarz) | repay (qaytarish) | settle (hisob-kitob)
--    direction (faqat debt): 'toMe' (u menga qarzdor) | 'fromMe' (men unga) — created_by nuqtai nazaridan
--    prov: twoSided (ikki tomonlama tasdiq) | oneSided (off-Trust, tasdiqsiz)
-- ============================================================
create table if not exists public.debts (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete cascade,
  kind text not null check (kind in ('debt','repay','settle')),
  direction text check (direction in ('toMe','fromMe')),
  created_by uuid not null references public.profiles(id),
  amount bigint not null check (amount > 0),
  currency text not null default 'UZS' check (currency in ('UZS','USD','EUR','RUB')),
  acted_at date not null default current_date,     -- amal sanasi (backdating mumkin, kelajak taqiq)
  due date,                                         -- faqat debt (o'tmish taqiq)
  note text,
  status text not null check (status in ('pending','active','closed','rejected','cancelled','ok','disputed')),
  paid bigint not null default 0,                   -- faqat debt: jami yopilgan (<= amount)
  forgiven bigint not null default 0,               -- faqat debt: shundan kechilgani
  reason text check (reason in ('returned','forgiven')),   -- yopilishda
  ref_id uuid references public.debts(id) on delete set null,  -- repay/settle -> tegishli debt.id
  prov text not null default 'twoSided' check (prov in ('twoSided','oneSided')),
  pending_edit jsonb,                               -- faol qarzning tasdiqlanmagan taxriri {amount,due,note,requested_at}
  under_review boolean not null default false,      -- join'dan keyin ko'rib chiqish navbatida
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Tahrir tarixi (versions) — alohida jadval
create table if not exists public.debt_versions (
  id uuid primary key default gen_random_uuid(),
  debt_id uuid not null references public.debts(id) on delete cascade,
  amount bigint,
  due date,
  note text,
  edited_at timestamptz default now()
);

-- Indekslar
create index if not exists debts_partner_created_idx on public.debts(partner_id, created_at);
create index if not exists debts_partner_open_idx on public.debts(partner_id) where status in ('active','pending');
create index if not exists debts_ref_idx on public.debts(ref_id);
create index if not exists debt_versions_debt_idx on public.debt_versions(debt_id, edited_at);

-- RLS yoqiladi (backend service_role bilan ishlaydi — RLS chetlab o'tadi; huquq KODDA tekshiriladi,
-- klientlar to'g'ridan-to'g'ri kira olmasin). Policy'lar yo'q — boshqa jadvallardagi naqsh bilan bir xil.
alter table public.debts enable row level security;
alter table public.debt_versions enable row level security;

-- ============================================================
-- 2. NOTIFICATIONS: qarz daftari turlari (mavjud ro'yxatni BUZMASDAN kengaytirish)
--    Mavjud (004+007): req,ok,rem,edit,rej,link_new,link_acc,link_rej,op_new,msg
--    Qo'shiladi: debt_new,debt_confirm,debt_reject,repay_new,settle_new,edit_req,review_req
-- ============================================================
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in (
    'req','ok','rem','edit','rej','link_new','link_acc','link_rej','op_new','msg',
    'debt_new','debt_confirm','debt_reject','repay_new','settle_new','edit_req','review_req'
  ));

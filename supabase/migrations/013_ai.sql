-- 013: Trust AI — moliyaviy hamroh chat (docs/ai-character.md).
-- Jadvallar: ai_messages (tarix), ai_usage (token/xarajat auditi),
--            ai_profile (keshlangan agregat kontekst), ai_flags (Play shikoyati).
-- RLS yoqilgan, policy ATAYLAB YO'Q — faqat service_role (backend) kiradi (012 naqshi).
-- Idempotent: qayta yurgizish xavfsiz.

-- ============================================================
-- 1. AI_MESSAGES — suhbat tarixi
--    content : matn (foydalanuvchi xabari YOKI AI javobining matn qismi) — ASL holida,
--              ya'ni REAL ismlar bilan (psevdonimlashtirish faqat model yo'nalishida).
--    blocks  : AI javobining to'liq interaktiv bloklari (§11) — mobil shundan chizadi.
-- ============================================================
create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('user','assistant')),
  content text not null default '',
  blocks jsonb,                                      -- faqat assistant uchun
  provider text,                                     -- anthropic | groq | fallback
  created_at timestamptz not null default now()
);
create index if not exists ai_messages_user_idx on public.ai_messages(user_id, created_at desc);

-- ============================================================
-- 2. AI_USAGE — har model chaqiruvi (token + xarajat auditi).
--    Kunlik/oylik limit SHU JADVALDAN sanaladi (provider='fallback' hisobga olinmaydi:
--    ikkala provayder yiqilganda foydalanuvchi limiti yeyilmasin).
--    PO real ma'lumot bilan AI_DAILY_LIMIT/AI_MONTHLY_LIMIT ni keyin sozlaydi.
-- ============================================================
create table if not exists public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null default 'anthropic',
  model text not null,
  input_tokens int not null default 0,               -- keshlanmagan (yangi) input
  cached_input_tokens int not null default 0,        -- keshdan o'qilgan (~0.1x narx)
  cache_write_tokens int not null default 0,         -- keshga yozilgan (~1.25x narx)
  output_tokens int not null default 0,
  cost_usd numeric(12,6) not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists ai_usage_user_idx on public.ai_usage(user_id, created_at desc);

-- ============================================================
-- 3. AI_PROFILE — keshlangan agregat kontekst (docs/ai-character.md §7).
--    summary : modelga yuboriladigan ~600 tokenlik matn (HAMKOR_n/YOZUV_n belgilari bilan).
--    tokens  : belgi -> real qiymat xaritasi, masalan
--              {"HAMKOR_1":{"id":"<uuid>","name":"Anvar","to_me":2000000,"days":87,...},
--               "YOZUV_1":{"id":"<uuid>","note":"taksi","amount":30000}}
--              MAXFIYLIK: real ismlar FAQAT shu yerda (bizning DB) qoladi — modelga
--              hech qachon yuborilmaydi. Model javobidagi belgilar serverda tiklanadi.
--    computed_at : TTL (AI_PROFILE_TTL_HOURS, default 6) — eskirsa qayta hisoblanadi.
-- ============================================================
create table if not exists public.ai_profile (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  summary text not null default '',
  tokens jsonb not null default '{}'::jsonb,
  computed_at timestamptz not null default now()
);

-- ============================================================
-- 4. AI_FLAGS — "noto'g'ri javob" shikoyati.
--    Google Play 2026 AI-Generated Content siyosati bo'yicha MAJBURIY: har AI javobi
--    ostida flag tugmasi bo'lishi va shikoyat qabul qilinishi shart.
--    unique(user_id, message_id): takror bosish yangi qator yaratmaydi (idempotent).
-- ============================================================
create table if not exists public.ai_flags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  message_id uuid not null references public.ai_messages(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  unique (user_id, message_id)
);
create index if not exists ai_flags_user_idx on public.ai_flags(user_id, created_at desc);
create index if not exists ai_flags_msg_idx on public.ai_flags(message_id);

-- ============================================================
-- 5. RLS — yoqilgan, policy yo'q (faqat backend service_role). 012 bilan bir xil naqsh.
-- ============================================================
alter table public.ai_messages enable row level security;
alter table public.ai_usage enable row level security;
alter table public.ai_profile enable row level security;
alter table public.ai_flags enable row level security;

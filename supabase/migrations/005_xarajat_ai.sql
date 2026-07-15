-- 005: Xarajat AI qatlami — XOTIRA-ovoz-va-kategoriya.md 2-bosqich
-- Toifa CRUD + o'z-o'zini to'ldiruvchi kalit so'z lug'ati + tuzatishlar (few-shot).
-- Idempotent — qayta yurgizish xavfsiz.

-- 1. TOIFALAR (per-user; baza 7 tasi birinchi so'rovda backend tomonidan seed qilinadi)
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  is_base boolean not null default false,    -- baza toifa (seed) — belgilash uchun
  archived boolean not null default false,   -- o'chirish yo'q, arxivlash bor (tarix buzilmasin)
  created_at timestamptz not null default now(),
  unique (user_id, name)
);
create index if not exists cat_user_idx on public.categories(user_id) where not archived;

-- 2. KALIT SO'Z LUG'ATI (o'z-o'zini to'ldiruvchi): so'z -> toifa, per-user
-- Har tasdiqlangan yozuvdan to'ldiriladi. "Korzinka" bir marta to'g'irlandi ->
-- keyingi safar LLM'siz to'g'ri tushadi. Global foyda: barcha userlar bo'yicha agregat.
create table if not exists public.word_map (
  user_id uuid not null references public.profiles(id) on delete cascade,
  word text not null,                        -- kichik harfda, normalizatsiya qilingan
  category text not null,
  hits int not null default 1,               -- necha marta shu juftlik tasdiqlangan
  updated_at timestamptz not null default now(),
  primary key (user_id, word, category)
);
create index if not exists wm_word_idx on public.word_map(word);

-- 3. TUZATISHLAR (few-shot xotira): user LLM natijasini o'zgartirgan holatlar.
-- LLM promptiga oxirgi N ta misol bo'lib qaytadi — tizim foydalanuvchiga moslashadi.
create table if not exists public.corrections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  text text not null,                        -- asl aytilgan/yozilgan gap
  parsed jsonb not null,                     -- AI taklifi
  final jsonb not null,                      -- user tasdiqlagan yakuniy holat
  created_at timestamptz not null default now()
);
create index if not exists corr_user_idx on public.corrections(user_id, created_at desc);

-- 4. expenses'ga AI meta ustunlari
alter table public.expenses add column if not exists source text not null default 'text'
  check (source in ('text','voice'));
alter table public.expenses add column if not exists confidence numeric(3,2);
alter table public.expenses add column if not exists raw_text text;  -- asl gap (audit/o'rganish)

-- RLS
alter table public.categories enable row level security;
alter table public.word_map enable row level security;
alter table public.corrections enable row level security;

drop policy if exists "own categories" on public.categories;
create policy "own categories" on public.categories for select using (auth.uid() = user_id);

drop policy if exists "own word_map" on public.word_map;
create policy "own word_map" on public.word_map for select using (auth.uid() = user_id);

drop policy if exists "own corrections" on public.corrections;
create policy "own corrections" on public.corrections for select using (auth.uid() = user_id);

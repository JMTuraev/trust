-- 014: FCM qurilma tokenlari (push bildirishnomalar)
-- Har qator = bitta qurilma. token UNIQUE: qurilmada akkaunt almashsa backend upsert
-- (onConflict: token) qatorni yangi user_id ga qayta bog'laydi.
-- Yozish/o'qish FAQAT service role (backend) orqali — RLS yoqiq, klient policy YO'Q.

create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  token text not null unique,
  platform text not null default 'android' check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_idx on device_tokens(user_id);

alter table device_tokens enable row level security;

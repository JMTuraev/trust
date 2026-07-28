-- 017: Yordam chati (support -> Telegram ko'prigi)
-- direction: 'in' = userdan bizga; 'out' = bizdan (Telegram reply) userga.
-- tg_message_id: admin Telegramidagi forward xabar id — reply'ni userga bog'lash uchun.

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  direction text not null check (direction in ('in', 'out')),
  body text not null,
  tg_message_id bigint,
  created_at timestamptz not null default now()
);

create index if not exists support_user_idx on public.support_messages(user_id, created_at);
create index if not exists support_tgmsg_idx on public.support_messages(tg_message_id) where tg_message_id is not null;

alter table public.support_messages enable row level security;

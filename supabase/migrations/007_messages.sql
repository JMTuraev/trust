-- 007 — REAL chat: matn va ovozli xabarlar (messages jadvali + voice storage bucket).
-- Huquq KODDA tekshiriladi (service_role RLS chetlab o'tadi): owner yoki accepted counterparty.
-- Idempotent. Supabase SQL Editor'da ishga tushiring.

-- ============================================================
-- 1. MESSAGES: hamkor (partner/link) doirasidagi yozishmalar
-- ============================================================
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  kind text not null check (kind in ('text','audio')),
  body text,                -- matn xabari (kind='text')
  audio_path text,          -- storage'dagi yo'l: <partnerId>/<uuid>.m4a (kind='audio')
  duration_sec int,         -- ovozli xabar davomiyligi (soniya)
  created_at timestamptz default now(),
  read_at timestamptz       -- qarshi tomon o'qigan payt (null = o'qilmagan)
);

-- Polling (after=<iso>) va tarix uchun
create index if not exists messages_partner_created_idx
  on public.messages(partner_id, created_at);
-- O'qilmagan hisoblagich uchun qisman indeks
create index if not exists messages_unread_idx
  on public.messages(partner_id) where read_at is null;

alter table public.messages enable row level security;

-- ============================================================
-- 2. STORAGE: ovozli xabarlar uchun yopiq bucket (signed URL bilan o'qiladi)
-- ============================================================
insert into storage.buckets (id, name, public) values ('voice','voice', false) on conflict do nothing;

-- ============================================================
-- 3. NOTIFICATIONS: yangi 'msg' turi (004 dagi ro'yxatga qo'shiladi)
-- ============================================================
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in ('req','ok','rem','edit','rej','link_new','link_acc','link_rej','op_new','msg'));

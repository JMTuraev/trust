-- 028 — To'yxona: STOL RASMLARI (2026-09-09). hall_menus.images jsonb — 5 tagacha
-- Storage URL (toyxona bucket, servis rasmlari bilan bir xil qoida). Birinchisi muqova.
alter table public.hall_menus add column if not exists images jsonb not null default '[]'::jsonb;

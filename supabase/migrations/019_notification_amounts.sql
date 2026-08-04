-- 019 — Per-partner notification badge (hamkor kartasidagi o'qilmagan hisob).
-- Sxemada partner atributsiyasi (link_id -> partners.id, 004) va o'qilganlik (read, 002)
-- ALLAQACHON bor. Yetishmagani:
--   1) notifications.amount/currency — badge'da "so'nggi summalar" va yig'indi.
--      Summani detail matnidan parse qilmaymiz (lokalizatsiya/format sinishi) —
--      alohida ustunda saqlaymiz. NULL = summasiz bildirishnoma (link_new va h.k.).
--   2) O'qilmaganlarni user+partner bo'yicha tez sanash uchun partial indeks
--      (GET /api/notifications/counts har ochilishda so'raladi).
-- Idempotent. Supabase SQL Editor'da ishga tushiring.
-- DIQQAT: backend deploy'idan OLDIN qo'llang — kod amount ustuniga yozadi
-- (ustun bo'lmasa summasiz fallback ishlaydi, lekin badge summalari yo'qoladi).

alter table public.notifications add column if not exists
  amount bigint check (amount is null or amount > 0);

alter table public.notifications add column if not exists
  currency text check (currency in ('UZS','USD','EUR','RUB'));

-- O'qilmagan + hamkorga bog'langan qatorlar uchun partial indeks
create index if not exists notif_unread_partner_idx
  on public.notifications(user_id, link_id)
  where read = false and link_id is not null;

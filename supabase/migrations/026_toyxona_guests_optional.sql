-- 026 — To'yxona: "butun to'yxona" (price_mode = 'total') rejimida mehmonlar
-- soni SO'RALMAYDI. Bron formasi 2 bosqichga bo'lindi (2026-09-09) va shu
-- rejimda guests maydoni ko'rsatilmaydi, shuning uchun 0 saqlanishi kerak.
-- 'guest' rejimida 1..MAX qoidasini backend (src/routes/toyxona.js) tekshiradi.
alter table public.bookings drop constraint if exists bookings_guests_check;
alter table public.bookings add constraint bookings_guests_check check (guests >= 0);

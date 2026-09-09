-- 027 — To'yxona: STOL KO'RINISHI (2026-09-09).
-- hall_menu_items endi hisoblanadigan mahsulot qatori: miqdor (amount) × birlik
-- (unit: kg/g/dona/l/porsiya/paket) × birlik narxi (unit_price) = qator jami.
-- Stol jami = Σ qator; 1 kishiga narx = stol jami ÷ seats (yuqoriga yaxlitlab).
-- Eski qatorlar (faqat qty matni) BUZILMAYDI: amount/unit NULL, unit_price 0 —
-- ular ro'yxatda ko'rinadi, hisobga kirmaydi.
-- To'liq stol tarkibi bitta joyda kiritiladi, bronda stol tanlanadi (o'zbek
-- to'ylari amaliyoti: stol ustidagi hamma narsa oldindan kelishiladi).
alter table public.hall_menu_items add column if not exists amount     numeric(12,3);
alter table public.hall_menu_items add column if not exists unit       text;
alter table public.hall_menu_items add column if not exists unit_price bigint not null default 0;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'hall_menu_items_amount_chk') then
    alter table public.hall_menu_items add constraint hall_menu_items_amount_chk
      check (amount is null or (amount >= 0 and amount <= 1000000));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'hall_menu_items_unit_chk') then
    alter table public.hall_menu_items add constraint hall_menu_items_unit_chk
      check (unit is null or unit in ('kg','g','dona','l','porsiya','paket'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'hall_menu_items_unit_price_chk') then
    alter table public.hall_menu_items add constraint hall_menu_items_unit_price_chk
      check (unit_price >= 0);
  end if;
end $$;

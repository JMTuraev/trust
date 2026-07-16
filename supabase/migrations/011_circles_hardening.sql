-- 011 — Circles hardening (010 dan keyin ishga tushiring; idempotent).
-- 1) circles.status: 'closed' — muddatidan oldin yopilgan doira. Dalil (done roundlar,
--    confirmed to'lovlar) O'CHIRILMAYDI — status bilan yopiladi (soft-close).
--    Hard delete faqat hech bir round yopilmagan (dalil yo'q) doiralar uchun.
-- 2) notifications.type: 'circle_closed' — doira yopilgani haqida xabar.
-- 3) FK indekslari: cascade delete va recipient qidiruvlari uchun.

-- ============================================================
-- 1. circles.status check — 'closed' qo'shiladi
-- ============================================================
alter table public.circles drop constraint if exists circles_status_check;
alter table public.circles add constraint circles_status_check
  check (status in ('active','complete','closed'));

-- ============================================================
-- 2. notifications.type check — 'circle_closed' qo'shiladi
--    (010 dagi to'liq ro'yxat + yangi tur)
-- ============================================================
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in (
    'req','ok','rem','edit','rej','link_new','link_acc','link_rej','op_new','msg',
    'debt_new','debt_confirm','debt_reject','repay_new','settle_new','edit_req','review_req',
    'circle_invite','circle_turn','circle_paid','circle_confirm','circle_due','circle_joined',
    'circle_closed'
  ));

-- ============================================================
-- 3. FK indekslari (yo'q bo'lsa)
--    circle_rounds.recipient_member_id — a'zo o'chirilganda cascade tez ishlashi
--    va decline-siqish uchun; circle_payments.member_id — xuddi shunday.
-- ============================================================
create index if not exists circle_rounds_recipient_idx on public.circle_rounds(recipient_member_id);
create index if not exists circle_payments_member_idx on public.circle_payments(member_id);

-- 015: qarz muddati (due) avto-eslatma belgisi
-- services/dueReminder.js sweeper'i shu ustun orqali "bir qarzga bir eslatma"
-- kafolatini beradi (atomik update ... where due_reminder_sent_at is null).

alter table public.debts add column if not exists due_reminder_sent_at timestamptz;

-- Sweep so'rovi uchun tor partial indeks
create index if not exists debts_due_reminder_idx
  on public.debts(due)
  where kind = 'debt' and status = 'active' and due_reminder_sent_at is null;

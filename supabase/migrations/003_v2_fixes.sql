-- 003 — v2 tuzatishlar: statuslar, hamkor bog'lash trigger, eslatma sender,
-- eski (v1) jadvallarni olib tashlash. Supabase SQL Editor'da ishga tushiring.

-- 1. OPERATSIYA STATUSLARI: 'unconfirmed' (bir tomonlama daftar yozuvi, dalil emas)
--    va 'archived' (dalil yashirilgan, balansda qoladi)
alter table public.operations drop constraint if exists operations_status_check;
alter table public.operations add constraint operations_status_check
  check (status in ('pending','confirmed','unconfirmed','archived','cancelled','disputed'));

-- 2. BILDIRISHNOMAGA YUBORUVCHI (eslatma cooldown'i uchun)
alter table public.notifications add column if not exists
  sender_id uuid references public.profiles(id) on delete set null;
create index if not exists notif_sender_idx
  on public.notifications(sender_id, type, created_at);

-- 3. YANGI FOYDALANUVCHINI MAVJUD HAMKORLARGA BOG'LASH
--    Kimdir uni telefon raqami bo'yicha hamkor qilib qo'shgan bo'lsa —
--    counterparty_id to'ldiriladi, on_trust yoqiladi, egasiga xabar boradi.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  norm_phone text := regexp_replace(coalesce(new.phone, ''), '\D', '', 'g');
  p record;
begin
  insert into public.profiles (id, phone)
  values (new.id, norm_phone)
  on conflict (id) do nothing;

  if norm_phone <> '' then
    for p in
      update public.partners
        set counterparty_id = new.id, on_trust = true, updated_at = now()
      where counterparty_phone = norm_phone and counterparty_id is null
      returning id, owner_id, name
    loop
      insert into public.notifications (user_id, type, title, detail)
      values (p.owner_id, 'ok', 'Hamkor Trust''ga qo''shildi',
              p.name || ' endi Trust''da — yozuvlar ikki tomonlama tasdiqlanadi');
    end loop;
  end if;

  return new;
end;
$$;

-- (trigger 001 da yaratilgan — funksiya yangilandi, qayta bog'lash shart emas,
--  lekin xavfsizlik uchun qayta e'lon qilamiz)
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. ESKI (V1) JADVALLARNI OLIB TASHLASH — backend v2 ularni ishlatmaydi
drop table if exists public.payments cascade;
drop table if exists public.reminders cascade;
drop table if exists public.debts cascade;

-- 5. OTP jadvalini tozalab turish uchun indeks (muddati o'tganlarni o'chirish oson bo'lsin)
create index if not exists otp_expires_idx on public.otp_codes(expires_at);

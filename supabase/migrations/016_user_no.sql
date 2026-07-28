-- 016: 8 xonali unikal foydalanuvchi raqami (profiles.user_no)
-- PO 2026-07-28: har bir userga qisqa ID — kelajakda qidirish/qo'llab-quvvatlash/kengayish uchun.
-- Diapazon: 10000000–99999999 (90 mln), tasodifiy — o'sish sonini oshkor qilmaydi.
-- GET /api/profile/me select('*') bo'lgani uchun backend o'zgarishsiz qaytaradi.

alter table public.profiles add column if not exists user_no bigint unique;

-- Yangi profilga avto raqam (band bo'lmagan tasodifiy)
create or replace function public.assign_user_no()
returns trigger language plpgsql as $$
declare n bigint;
begin
  if new.user_no is not null then return new; end if;
  loop
    n := floor(random() * 90000000 + 10000000)::bigint;
    exit when not exists (select 1 from public.profiles where user_no = n);
  end loop;
  new.user_no := n;
  return new;
end $$;

drop trigger if exists profiles_user_no on public.profiles;
create trigger profiles_user_no before insert on public.profiles
  for each row execute function public.assign_user_no();

-- Mavjud profillarga backfill (qatorma-qator, kolliziyasiz)
do $$
declare r record; n bigint;
begin
  for r in select id from public.profiles where user_no is null loop
    loop
      n := floor(random() * 90000000 + 10000000)::bigint;
      exit when not exists (select 1 from public.profiles where user_no = n);
    end loop;
    update public.profiles set user_no = n where id = r.id;
  end loop;
end $$;

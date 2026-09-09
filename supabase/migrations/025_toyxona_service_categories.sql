-- 025 — TO'YXONA servislari v3 (PO 2026-09-09): KATEGORIYA + RASM.
--
--   MUAMMO: 024 dagi `hall_services` — tekis ro'yxat (nom + narx). Mijozga
--   ko'rsatiladigan qismi zerikarli matn qatori bo'lib qolgan.
--
--   YECHIM: ikki qatlam.
--     1) KATEGORIYA — PLATFORMA belgilaydi (17 ta + 'boshqa'). Bazada JADVAL YO'Q:
--        ro'yxat backend konstantasida (src/lib/toyxonaCategories.js) va Flutter'da
--        (kToyServiceCats) turadi — ikkalasi bir xil slug'larni ishlatadi. Sabab:
--        kategoriya nomi 6 TILDA ko'rsatiladi va IKONKA/GRADIENT ilova ichida
--        (assets) yashaydi — DB qatori bularning hech birini saqlay olmaydi, faqat
--        ikkinchi haqiqat manbai bo'lib qolardi. Shuning uchun bu yerda faqat
--        `category` — ERKIN matn ustuni, ro'yxat BACKEND'da tekshiriladi.
--        Noma'lum slug kelsa (eski ilova / kelajakdagi kategoriya) qator YO'QOLMAYDI —
--        mobil uni 'boshqa' sifatida ko'rsatadi.
--     2) ITEM — TO'YXONACHI to'ldiradi: nom, narx, tavsif va RASMLAR.
--        Masalan "Musiqa" kategoriyasi biznikidir, ichidagi 3 xonanda — eganiki.
--
--   RASMLAR: `images` jsonb massivi (URL matnlari, ko'pi bilan 5 ta, [0] = muqova).
--   Fayllar Supabase Storage'ning `toyxona` bucket'ida; yuklash BACKEND orqali
--   (service_role) — klient Storage'ga TO'G'RIDAN-TO'G'RI chiqmaydi, chunki
--   O'zbekiston tarmoqlari ba'zan supabase.co ga ulanolmaydi (shu sabab API ham
--   api.trustbook.uz / Cloudflare ortida). Bucket PUBLIC O'QILADI: rasm bron
--   varaqasida mijozga ham ko'rsatiladi va u yerda Authorization sarlavhasi yo'q.
--
--   SNAPSHOT QOIDASI (021/024 bilan bir xil) booking_items'ga ham tarqaldi:
--   bandga qo'shilgan xizmatning kategoriyasi va muqova rasmi NUSXA olinadi —
--   katalogdagi item keyin o'chsa yoki rasmi almashsa, O'TGAN bandning varaqasi
--   o'zgarmaydi.
--
-- Idempotent. Supabase SQL Editor'da QO'LDA ishga tushiring (021/022/023/024 kabi),
-- deploy'dan OLDIN. Eski qatorlar: category='boshqa', images=[] — xulq o'zgarmaydi.

create table if not exists public.schema_migrations (
  version    text primary key,
  applied_at timestamptz not null default now()
);
alter table public.schema_migrations enable row level security;

-- ---------------------------------------------------------------------
-- 1) hall_services — kategoriya, tavsif, rasmlar
-- ---------------------------------------------------------------------
alter table public.hall_services add column if not exists category    text  not null default 'boshqa';
-- `note` (200 belgi) qisqa izoh bo'lib qoladi; `description` — mijozga ko'rsatiladigan
-- to'liq matn (repertuar, nima kiradi, shartlar). Ikkisi ALOHIDA: note ega uchun
-- ichki eslatma, description mijoz ko'radigan matn.
alter table public.hall_services add column if not exists description text;
-- ["https://.../a.jpg", ...] — [0] muqova. Ko'pi bilan 5 ta (backend tekshiradi).
alter table public.hall_services add column if not exists images      jsonb not null default '[]'::jsonb;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'hall_services_images_arr') then
    alter table public.hall_services add constraint hall_services_images_arr
      check (jsonb_typeof(images) = 'array' and jsonb_array_length(images) <= 5);
  end if;
  -- Kategoriya slug'i: faqat kichik lotin harflari (ro'yxat backend'da)
  if not exists (select 1 from pg_constraint where conname = 'hall_services_category_fmt') then
    alter table public.hall_services add constraint hall_services_category_fmt
      check (category ~ '^[a-z][a-z0-9_]{0,23}$');
  end if;
end $$;

-- Kategoriya bo'yicha ro'yxat: where user_id = ? and category = ? order by sort
create index if not exists hall_services_cat_idx on public.hall_services (user_id, category, sort);

-- ESKI QATORLAR → 'boshqa' (default allaqachon shunday; NULL qolganlar uchun zaxira).
update public.hall_services set category = 'boshqa' where category is null or category = '';

-- ---------------------------------------------------------------------
-- 2) booking_items — SNAPSHOT: kategoriya + muqova rasmi
--    (katalogdagi item o'chsa/almashsa o'tgan band varaqasi o'zgarmaydi)
-- ---------------------------------------------------------------------
alter table public.booking_items add column if not exists category  text;
alter table public.booking_items add column if not exists image_url text;

-- Mavjud qatorlar uchun katalogdan bir martalik to'ldirish (service_id bor bo'lsa).
update public.booking_items bi
   set category = s.category
  from public.hall_services s
 where bi.service_id = s.id and bi.category is null;

-- ---------------------------------------------------------------------
-- 3) STORAGE — `toyxona` bucket (PUBLIC o'qish, yozish faqat service_role).
--    Yo'l shakli: toyxona/<user_id>/<service_id yoki 'tmp'>/<random>.jpg
--    Supabase'da storage.buckets/objects — oddiy jadvallar, shuning uchun
--    bucket'ni SQL bilan yaratamiz (Dashboard'ga kirish shart emas).
--    file_size_limit 3 MB — mobil rasmni yuklashdan oldin siqadi (~200 KB).
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('toyxona', 'toyxona', true, 3145728, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public             = true,
      file_size_limit    = 3145728,
      allowed_mime_types = array['image/jpeg','image/png','image/webp'];

-- O'QISH hammaga ochiq (bron varaqasidagi <img> Authorization yubormaydi).
-- YOZISH/O'CHIRISH uchun policy ATAYLAB YO'Q — service_role RLS'ni chetlab o'tadi,
-- ya'ni faqat backend yozadi (021 dagi "policy yo'q" naqshi bilan bir xil).
do $$ begin
  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'toyxona_public_read'
  ) then
    create policy toyxona_public_read on storage.objects
      for select to public using (bucket_id = 'toyxona');
  end if;
end $$;

insert into public.schema_migrations (version) values ('025') on conflict do nothing;

-- ===== QO'LDA TEKSHIRISH =====
-- select column_name, data_type, column_default from information_schema.columns
--  where table_name = 'hall_services' and column_name in ('category','description','images');
-- select id, public, file_size_limit from storage.buckets where id = 'toyxona';
-- select policyname from pg_policies where tablename = 'objects' and policyname = 'toyxona_public_read';
-- select category, count(*) from public.hall_services group by 1;

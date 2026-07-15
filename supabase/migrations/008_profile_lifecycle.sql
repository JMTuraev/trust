-- 008: profil hayot sikli — soft-delete + trial/premium maydonlari
-- Maqsad:
--   1) deleted_at — App Store/Play "akkauntni o'chirish" talabi uchun SOFT delete.
--      Ma'lumotlar O'CHIRILMAYDI (link modeli — qarshi tomonda daftar saqlanib qoladi),
--      qayta kirishda (OTP tasdig'ida, src/services/otp.js) deleted_at=null bilan tiklanadi.
--   2) premium_until — pullik obuna tugash vaqti (to'lov integratsiyasi keyinroq ulanadi).
--   Eslatma: trial uchun alohida ustun YO'Q — trial_ends_at = created_at + 7 kun,
--   API javobida hisoblanadi (profiles.created_at 001 migratsiyada default now() bilan mavjud).
-- Idempotent: qayta ishga tushirilsa xato bermaydi.

alter table public.profiles add column if not exists deleted_at timestamptz;
alter table public.profiles add column if not exists premium_until timestamptz;

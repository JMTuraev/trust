// Toifalar — XOTIRA §4: baza 7 toifa + foydalanuvchi CRUD (o'chirish yo'q, arxivlash bor).
import { supabaseAdmin } from './supabase.js';

export const BASE_CATEGORIES = [
  'Oziq-ovqat', 'Transport', 'Kommunal', "Ko'ngilochar", 'Kiyim', 'Salomatlik', 'Boshqa',
];

// Foydalanuvchining toifalari yo'q bo'lsa baza 7 tasini seed qiladi, faollarini qaytaradi.
export async function ensureCategories(userId) {
  const { data, error } = await supabaseAdmin
    .from('categories').select('id, name, is_base, archived').eq('user_id', userId);
  if (error) throw new Error(error.message);
  let rows = data || [];
  if (rows.length === 0) {
    const seed = BASE_CATEGORIES.map((name) => ({ user_id: userId, name, is_base: true }));
    const { data: ins, error: e2 } = await supabaseAdmin
      .from('categories').insert(seed).select('id, name, is_base, archived');
    if (e2 && !/duplicate/i.test(e2.message)) throw new Error(e2.message);
    rows = ins || seed.map((s) => ({ ...s, archived: false }));
  }
  return rows.filter((r) => !r.archived);
}

import { createClient } from '@supabase/supabase-js';
import { config } from '../config.js';

// MUHIM (2026-08-02 audit): ilgari bu yerda 'http://localhost' / 'placeholder' zaxira
// qiymatlari turardi. Ular tufayli noto'g'ri sozlangan server MUAMMOSIZ ko'tarilib,
// /health yashil qaytarardi — xato esa faqat foydalanuvchi kirmoqchi bo'lganda
// (500/502 bo'lib) chiqardi. Endi konfiguratsiya buzuq bo'lsa server umuman
// ko'tarilmaydi (assertConfig production'da process.exit qiladi).
const url = config.supabase.url;
const serviceKey = config.supabase.serviceRoleKey;
const anonKey = config.supabase.anonKey;

// Service role — server tomonda to'liq huquq (RLS chetlab o'tadi)
export const supabaseAdmin = createClient(
  url || 'http://localhost',
  serviceKey || 'placeholder-service-key',
  { auth: { autoRefreshToken: false, persistSession: false } }
);

// Anon — Supabase'ning o'z OTP oqimi uchun (xalqaro raqamlar)
export const supabaseAnon = createClient(
  url || 'http://localhost',
  anonKey || 'placeholder-anon-key',
  { auth: { autoRefreshToken: false, persistSession: false } }
);

import { createClient } from '@supabase/supabase-js';
import { config } from '../config.js';

// Service role — server tomonda to'liq huquq (RLS chetlab o'tadi)
export const supabaseAdmin = createClient(
  config.supabase.url || 'http://localhost',
  config.supabase.serviceRoleKey || 'placeholder',
  { auth: { autoRefreshToken: false, persistSession: false } }
);

// Anon — Supabase'ning o'z OTP oqimi uchun (xalqaro raqamlar)
export const supabaseAnon = createClient(
  config.supabase.url || 'http://localhost',
  config.supabase.anonKey || 'placeholder',
  { auth: { autoRefreshToken: false, persistSession: false } }
);

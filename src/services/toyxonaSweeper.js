// To'yxona sweeper'i (024) — ikkita ish, har soat (dueReminder.js naqshi):
//   1) HOLD MUDDATI O'TDI: status='band', hold_until < now, to'lov YO'Q → 'bekor'
//      (cancel_reason 'Avans muddati o'tdi', jarima 0 — pul tushmagan), egaga
//      in-app + push ('toy_hold'). Sana bo'shaydi — boshqa mijozga sotiladi.
//      To'lovi bor band hech qachon avto-bekor QILINMAYDI (hold POST /payments'da
//      o'chiriladi, lekin poyga bo'lsa ham bu yerda qayta tekshiriladi).
//   2) TO'Y ARAFASI QOLDIQ: 'tasdiq'/'band' band, event_date ≤ bugun + FINAL_DAYS,
//      left > 0, hali eslatilmagan → egaga 'toy_due' (bir marta).
//   Faqat kunduzi (09:00–20:00 Toshkent) — dueReminder bilan bir xil siyosat.
//   024 migratsiya shart (hold_until, hold_reminder_sent_at, final_reminder_sent_at).
//   Jadval/ustun bo'lmasa xato loglanadi, server yiqilmaydi.
import { supabaseAdmin } from '../lib/supabase.js';
import { notifEnabled } from '../lib/links.js';
import { pushToUser } from './push.js';
import { computeTotals } from '../routes/toyxona.js';

const TASHKENT_OFFSET_H = 5;
const FINAL_DAYS = parseInt(process.env.TOY_FINAL_REMINDER_DAYS || '3', 10);
const fmt = (n) => Number(n || 0).toLocaleString('ru-RU');

async function notifyOwner(userId, type, title, detail, data) {
  const { error } = await supabaseAdmin.from('notifications')
    .insert({ user_id: userId, type, title, detail });
  if (error) {
    // 024 qo'llanmagan bo'lsa (type check) — 'rem' bilan qayta urinamiz, eslatma yo'qolmasin
    const { error: e2 } = await supabaseAdmin.from('notifications')
      .insert({ user_id: userId, type: 'rem', title, detail });
    if (e2) { console.error('toyxonaSweeper notif xatosi:', e2.message); return false; }
  }
  pushToUser(userId, { title, body: detail, data: { type, ...data } });
  return true;
}

async function loadChildrenOf(bookingId) {
  const [{ data: items }, { data: pays }] = await Promise.all([
    supabaseAdmin.from('booking_items').select('amount, qty, is_bonus').eq('booking_id', bookingId),
    supabaseAdmin.from('booking_payments').select('amount, kind').eq('booking_id', bookingId),
  ]);
  return { items: items || [], pays: pays || [] };
}

async function sweepHolds(nowIso) {
  const { data: rows, error } = await supabaseAdmin.from('bookings')
    .select('id, user_id, client_name, event_date, slot, hold_until')
    .eq('status', 'band').not('hold_until', 'is', null).lt('hold_until', nowIso)
    .limit(100);
  if (error) { console.error('toyxonaSweeper hold so\'rovi:', error.message); return; }
  for (const b of rows || []) {
    const { pays } = await loadChildrenOf(b.id);
    const paid = pays.reduce((s, p) => s + (p.kind === 'qaytarim' ? -p.amount : p.amount), 0);
    if (paid > 0) {
      // Pul bor — hold shunchaki tozalanadi (poyga holati), bekor QILINMAYDI
      await supabaseAdmin.from('bookings').update({ hold_until: null }).eq('id', b.id);
      continue;
    }
    // Atomik: faqat hali 'band' va hold o'tgan bo'lsa bekor qilamiz
    const { data: done } = await supabaseAdmin.from('bookings').update({
      status: 'bekor', cancelled_at: nowIso, cancel_reason: "Avans muddati o'tdi (avto)",
      cancel_penalty: 0, hold_until: null, hold_reminder_sent_at: nowIso, updated_at: nowIso,
    }).eq('id', b.id).eq('status', 'band').not('hold_until', 'is', null).select('id');
    if (!done?.length) continue;
    if (!(await notifEnabled(b.user_id))) continue;
    await notifyOwner(b.user_id, 'toy_hold', "To'yxona: band bekor qilindi",
      `${b.client_name} — ${b.event_date} (${b.slot}): avans kelmadi, sana bo'shatildi`,
      { booking_id: b.id, event_date: b.event_date });
  }
}

async function sweepFinal(today) {
  const until = new Date(Date.parse(`${today}T00:00:00Z`) + FINAL_DAYS * 86_400_000)
    .toISOString().slice(0, 10);
  const { data: rows, error } = await supabaseAdmin.from('bookings')
    .select('id, user_id, client_name, event_date, slot, guests, price_per_guest, price_mode, total_price, status')
    .in('status', ['band', 'tasdiq']).is('final_reminder_sent_at', null)
    .gte('event_date', today).lte('event_date', until)
    .limit(100);
  if (error) { console.error('toyxonaSweeper final so\'rovi:', error.message); return; }
  for (const b of rows || []) {
    const { items, pays } = await loadChildrenOf(b.id);
    const t = computeTotals(b, items, pays);
    if (t.left <= 0) {
      await supabaseAdmin.from('bookings').update({ final_reminder_sent_at: new Date().toISOString() }).eq('id', b.id);
      continue;
    }
    if (!(await notifEnabled(b.user_id))) continue;
    const { data: marked } = await supabaseAdmin.from('bookings')
      .update({ final_reminder_sent_at: new Date().toISOString() })
      .eq('id', b.id).is('final_reminder_sent_at', null).select('id');
    if (!marked?.length) continue;
    const ok = await notifyOwner(b.user_id, 'toy_due', "To'yxona: qoldiq bor",
      `${b.client_name} — ${b.event_date} (${b.slot}): qoldiq ${fmt(t.left)} so'm`,
      { booking_id: b.id, event_date: b.event_date, amount: t.left });
    if (!ok) await supabaseAdmin.from('bookings').update({ final_reminder_sent_at: null }).eq('id', b.id);
  }
}

async function sweep() {
  try {
    const nowTk = new Date(Date.now() + TASHKENT_OFFSET_H * 3600_000);
    const hour = nowTk.getUTCHours();
    if (hour < 9 || hour >= 20) return;
    const today = nowTk.toISOString().slice(0, 10);
    await sweepHolds(new Date().toISOString());
    await sweepFinal(today);
  } catch (e) {
    console.error('toyxonaSweeper xatosi:', e.message);
  }
}

export function startToyxonaSweeper() {
  const interval = parseInt(process.env.TOY_SWEEP_INTERVAL_MS || '3600000', 10);
  setTimeout(sweep, 25_000).unref();
  setInterval(sweep, interval).unref();
}

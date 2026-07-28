// Qarz muddati (due) avto-eslatma sweeper'i — mahsulotning yadro va'dasi ("eslatish").
// Har soat: kind='debt', status='active', due <= bugun (Asia/Tashkent) va hali
// eslatilmagan (due_reminder_sent_at is null) yozuvlarni topib, QARZDORGA in-app
// bildirishnoma + telefonga push yuboradi. Faqat kunduzi (09:00–20:00 Toshkent).
// Dublikatga qarshi: avval due_reminder_sent_at belgilanadi (atomik), keyin yuboriladi.
// 015 migratsiya shart: debts.due_reminder_sent_at ustuni.
import { supabaseAdmin } from '../lib/supabase.js';
import { notifEnabled } from '../lib/links.js';
import { pushToUser } from './push.js';

// O'zbekistonda DST yo'q — qat'iy UTC+5
const TASHKENT_OFFSET_H = 5;

async function sweep() {
  try {
    const nowTk = new Date(Date.now() + TASHKENT_OFFSET_H * 3600_000);
    const hour = nowTk.getUTCHours();
    if (hour < 9 || hour >= 20) return; // tunda bezovta qilmaymiz
    const today = nowTk.toISOString().slice(0, 10);

    const { data: dueList } = await supabaseAdmin
      .from('debts')
      .select('id, partner_id, direction, created_by, amount, paid, currency, due')
      .eq('kind', 'debt').eq('status', 'active')
      .is('due_reminder_sent_at', null)
      .not('due', 'is', null)
      .lte('due', today)
      .limit(100);

    for (const d of dueList || []) {
      // Atomik belgi: parallel sweep yoki restartda ikki marta yubormaslik uchun
      const { data: marked } = await supabaseAdmin.from('debts')
        .update({ due_reminder_sent_at: new Date().toISOString() })
        .eq('id', d.id).is('due_reminder_sent_at', null)
        .select('id');
      if (!marked?.length) continue;

      const { data: p } = await supabaseAdmin
        .from('partners').select('owner_id, counterparty_id, link_status')
        .eq('id', d.partner_id).maybeSingle();
      if (!p) continue;

      // Qarzdor kim? direction created_by nuqtai nazaridan:
      // 'fromMe' = created_by qarzdor; 'toMe' = qarshi tomon qarzdor.
      const other = p.owner_id === d.created_by ? p.counterparty_id : p.owner_id;
      const debtor = d.direction === 'fromMe' ? d.created_by : other;
      if (!debtor) continue; // off-Trust kontragent — akkaunti yo'q
      // Qarshi tomonga faqat QABUL QILINGAN bog'lanishda xabar boradi (link modeli)
      if (debtor === other && p.link_status !== 'accepted') continue;

      const remaining = (d.amount || 0) - (d.paid || 0);
      if (remaining <= 0) continue;
      if (!(await notifEnabled(debtor))) continue;

      const detail = `Qarz muddati keldi: ${remaining.toLocaleString('ru-RU')} ${d.currency} — hisobni ko'rib chiqing`;
      await supabaseAdmin.from('notifications').insert({
        user_id: debtor, type: 'rem', title: 'Eslatma', detail, link_id: d.partner_id,
      });
      pushToUser(debtor, { title: 'Eslatma', body: detail, data: { type: 'rem', link_id: d.partner_id } });
    }
  } catch (e) {
    console.error('dueReminder sweep xatosi:', e.message);
  }
}

export function startDueReminderSweeper() {
  // Default 1 soat; test uchun DUE_SWEEP_INTERVAL_MS bilan kichraytirsa bo'ladi
  const interval = parseInt(process.env.DUE_SWEEP_INTERVAL_MS || '3600000', 10);
  setTimeout(sweep, 15_000).unref(); // startdan keyin ham bir tekshiruv
  setInterval(sweep, interval).unref();
}

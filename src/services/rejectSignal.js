// Kechiktirilgan rad signali: mijoz bog'lanishni rad etganda sotuvchiga xabar
// darhol emas, konfiguratsiya qilinadigan kechikish bilan boradi (default 24 soat).
// Kechikish oynasida mijoz tiklasa — signal umuman yuborilmaydi (xato bosishdan himoya).
import { supabaseAdmin } from '../lib/supabase.js';

async function sweep() {
  try {
    const { data: due } = await supabaseAdmin
      .from('reject_signals')
      .select('id, partner_id, seller_id')
      .eq('sent', false)
      .lte('due_at', new Date().toISOString())
      .limit(100);
    for (const s of due || []) {
      const { data: link } = await supabaseAdmin
        .from('partners').select('link_status, name').eq('id', s.partner_id).maybeSingle();
      if (!link || link.link_status !== 'rejected') {
        // Mijoz oynada tiklagan — signal bekor
        await supabaseAdmin.from('reject_signals').delete().eq('id', s.id);
        continue;
      }
      await supabaseAdmin.from('notifications').insert({
        user_id: s.seller_id,
        type: 'link_rej',
        title: "Bog'lanish rad etildi",
        detail: `${link.name} — raqam egasi bog'lanishni rad etdi. Yozuvlaringiz o'z daftaringizda qoladi.`,
        link_id: s.partner_id,
      });
      await supabaseAdmin.from('reject_signals').update({ sent: true }).eq('id', s.id);
    }
  } catch (e) {
    console.error('rejectSignal sweep xatosi:', e.message);
  }
}

export function startRejectSignalSweeper() {
  // Interval sozlanadigan (test: kichik qiymat); default 5 daqiqa
  const interval = parseInt(process.env.REJECT_SWEEP_INTERVAL_MS || '300000', 10);
  setTimeout(sweep, 5_000).unref(); // startdan keyin ham bir tekshiruv
  setInterval(sweep, interval).unref();
}

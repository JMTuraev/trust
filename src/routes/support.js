// Yordam chati (PO 2026-07-28 #10): foydalanuvchi <-> jamoa, Telegram orqali.
// Oqim: user ilovada yozadi -> bazaga 'in' + admin Telegramiga forward (user_no bilan).
//       Admin Telegramda o'sha xabarga REPLY qiladi -> webhook -> bazaga 'out' + userga push.
// Realtime: mobil chat ochiq payt 4s polling (chat naqshi bilan bir xil).
import { Router } from 'express';
import crypto from 'node:crypto';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { config } from '../config.js';
import { tgEnabled, tgSend } from '../services/telegram.js';
import { pushToUser } from '../services/push.js';

const router = Router();

/** Vaqt bo'yicha xavfsiz taqqoslash (timing attack'ga qarshi). */
function timingSafeEq(a, b) {
  const ba = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}

// ---- Telegram webhook — AUTH YO'Q (Telegram chaqiradi), secret header bilan himoya ----
// DIQQAT: requireAuth'dan OLDIN turishi shart.
router.post('/telegram-webhook', async (req, res) => {
  res.json({ ok: true }); // Telegramga darhol 200 — retry bo'roni bo'lmasin
  try {
    // MUHIM (2026-08-02 audit): ilgari `if (secret && ...)` edi — ya'ni secret
    // o'rnatilmagan bo'lsa tekshiruv BUTUNLAY o'chib qolardi va webhook ochiq bo'lardi.
    // Bunda istalgan odam admin nomidan yozib, ketma-ket message_id larni sinab,
    // barcha foydalanuvchilarga "Trustbook yordam" nomli soxta push yubora olardi.
    // Endi secret MAJBURIY: yo'q bo'lsa webhook umuman ishlamaydi.
    const secret = config.support.webhookSecret;
    if (!secret) {
      console.error("SUPPORT: SUPPORT_TG_WEBHOOK_SECRET o'rnatilmagan — webhook rad etildi");
      return;
    }
    const got = req.get('X-Telegram-Bot-Api-Secret-Token') || '';
    if (got.length !== secret.length || !timingSafeEq(got, secret)) return;
    const msg = req.body?.message;
    if (!msg || !msg.text) return;
    const chatId = String(msg.chat?.id ?? '');

    // Admin chat id hali sozlanmagan — logga chiqaramiz (bir martalik sozlash yordami)
    if (!config.support.adminChatId) {
      console.log(`SUPPORT: SUPPORT_TG_CHAT_ID o'rnatilmagan. Sizning chat id'ingiz: ${chatId} — Render env'ga qo'ying.`);
      return;
    }
    if (chatId !== String(config.support.adminChatId)) return; // faqat admin gapiradi

    const replyTo = msg.reply_to_message?.message_id;
    if (!replyTo) {
      tgSend(chatId, "Javob berish uchun foydalanuvchi xabariga REPLY qiling (aks holda kimga ekani noma'lum).");
      return;
    }
    const { data: orig } = await supabaseAdmin
      .from('support_messages').select('user_id')
      .eq('tg_message_id', replyTo).maybeSingle();
    if (!orig) {
      tgSend(chatId, 'Bu xabar bazadan topilmadi — foydalanuvchining o\'z xabariga reply qiling.');
      return;
    }
    await supabaseAdmin.from('support_messages').insert({
      user_id: orig.user_id, direction: 'out', body: msg.text,
    });
    // Telefonga push — javob keldi (ilova yopiq bo'lsa ham ko'rsin)
    pushToUser(orig.user_id, {
      title: 'Trustbook yordam',
      body: msg.text.length > 120 ? `${msg.text.slice(0, 117)}...` : msg.text,
      data: { type: 'support' },
    });
  } catch (e) {
    console.error('support webhook xatosi:', e.message);
  }
});

router.use(requireAuth);

// GET /api/support/messages?after=<iso> — o'z chat tarixi (polling: after'dan keyingilar)
router.get('/messages', async (req, res, next) => {
  try {
    let q = supabaseAdmin
      .from('support_messages')
      .select('id, direction, body, created_at')
      .eq('user_id', req.user.id)
      .order('created_at', { ascending: true })
      .limit(200);
    if (req.query.after) {
      const a = new Date(req.query.after);
      if (!Number.isNaN(a.getTime())) q = q.gt('created_at', a.toISOString());
    }
    const { data, error } = await q;
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/support/messages { body } — user xabari + Telegramga forward
router.post('/messages', async (req, res, next) => {
  try {
    const body = String(req.body?.body || '').trim();
    if (!body) return res.status(400).json({ success: false, error: "Xabar bo'sh" });
    if (body.length > 2000) return res.status(400).json({ success: false, error: 'Xabar juda uzun (maks. 2000 belgi)' });

    const { data: row, error } = await supabaseAdmin
      .from('support_messages')
      .insert({ user_id: req.user.id, direction: 'in', body })
      .select().single();
    if (error) throw new Error(error.message);

    // Telegramga forward (fail-soft; message_id reply-bog'lash uchun saqlanadi)
    if (tgEnabled() && config.support.adminChatId) {
      const { data: prof } = await supabaseAdmin
        .from('profiles').select('full_name, phone, user_no').eq('id', req.user.id).maybeSingle();
      const who = `${(prof?.full_name || '').trim() || 'Foydalanuvchi'} · +${prof?.phone || '?'} · ID ${prof?.user_no || '?'}`;
      tgSend(config.support.adminChatId, `💬 ${who}\n\n${body}`).then(async (sent) => {
        if (!sent?.message_id) {
          // tg_message_id yozilmasa, admin javobi bu xabarga BOG'LANMAYDI (reply topilmaydi).
          console.error('support forward: tg message_id olinmadi, row', row.id);
          return;
        }
        const { error: uErr } = await supabaseAdmin.from('support_messages')
          .update({ tg_message_id: sent.message_id }).eq('id', row.id);
        if (uErr) console.error('support forward: tg_message_id yozilmadi:', uErr.message);
      }).catch((e) => console.error('support forward xatosi:', e?.message || e));
    }
    res.status(201).json({ success: true, data: row });
  } catch (e) { next(e); }
});

export default router;

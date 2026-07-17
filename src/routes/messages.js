// REAL chat: hamkor (link) doirasida FAQAT MATN xabarlari.
// Huquq: partner.owner_id YOKI (partner.counterparty_id va link_status='accepted').
// 2026-07-17: ovozli xabarlar butunlay olib tashlandi (mahsulot qarori — docs/ai-character.md §11).
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
// Obuna read-only qoidasi: xabar YUBORISH — 402; o'qish va read-belgilash OCHIQ
import { requireActiveSub } from '../lib/subscription.js';
import { displayName, notifEnabled } from '../lib/links.js';

const router = Router();
router.use(requireAuth);

// Hamkorni yuklab, so'rovchining chatga huquqini tekshiradi.
// Ruxsat bo'lsa partner qatorini, bo'lmasa null qaytaradi.
async function chatPartner(req, partnerId) {
  const { data: p } = await supabaseAdmin
    .from('partners').select('*').eq('id', partnerId).maybeSingle();
  if (!p) return null;
  const isOwner = p.owner_id === req.user.id;
  const isAcceptedCp = p.counterparty_id === req.user.id && p.link_status === 'accepted';
  return isOwner || isAcceptedCp ? p : null;
}

// Xabar qatorini klient shakliga o'tkazadi.
// mine'ni server hisoblamaydi — sender_id qaytariladi, klient o'zi solishtiradi.
function toClient(m) {
  return {
    id: m.id,
    sender_id: m.sender_id,
    kind: 'text',
    body: m.body,
    created_at: m.created_at,
    read_at: m.read_at,
  };
}

// Qarshi tomonga 'msg' bildirishnomasi (aniqlangan bo'lsa; sozlamaga bo'ysunadi).
// Rad etgan mijozga yubormaymiz (operations.js dagi naqsh bilan bir xil).
async function notifyMessage(partner, senderId, preview) {
  const recipient = partner.owner_id === senderId ? partner.counterparty_id : partner.owner_id;
  if (!recipient) return;
  if (partner.link_status === 'rejected') return;
  if (!(await notifEnabled(recipient))) return;
  const { data: me } = await supabaseAdmin
    .from('profiles').select('full_name, phone').eq('id', senderId).maybeSingle();
  await supabaseAdmin.from('notifications').insert({
    user_id: recipient,
    sender_id: senderId,
    type: 'msg',
    title: `${displayName(me)} xabar yubordi`,
    // Bog'lanish qabul qilinmagan bo'lsa matn OSHKOR QILINMAYDI (link modeli)
    detail: partner.link_status === 'accepted' ? preview : 'Yangi xabar — ko\'rish uchun bog\'lanishni qabul qiling',
    link_id: partner.id,
  });
}

// GET /api/messages/unread/counts — {partner_id: count} (menga kelgan, o'qilmagan)
// DIQQAT: '/:partnerId' dan OLDIN turishi shart (Express tartib bilan moslaydi)
router.get('/unread/counts', async (req, res, next) => {
  try {
    // Men kira oladigan chatlar: o'z daftarim + qabul qilingan bog'lanishlar
    const [mine, accepted] = await Promise.all([
      supabaseAdmin.from('partners').select('id').eq('owner_id', req.user.id),
      supabaseAdmin.from('partners').select('id')
        .eq('counterparty_id', req.user.id).eq('link_status', 'accepted'),
    ]);
    const ids = [...(mine.data || []), ...(accepted.data || [])].map((p) => p.id);
    const counts = {};
    if (ids.length) {
      const { data, error } = await supabaseAdmin
        .from('messages').select('partner_id')
        .in('partner_id', ids)
        .neq('sender_id', req.user.id)
        .is('read_at', null);
      if (error) throw new Error(error.message);
      for (const m of data || []) counts[m.partner_id] = (counts[m.partner_id] || 0) + 1;
    }
    res.json({ success: true, data: counts });
  } catch (e) { next(e); }
});

// GET /api/messages/:partnerId?after=<iso> — xabarlar (polling: after'dan keyingilar)
router.get('/:partnerId', async (req, res, next) => {
  try {
    const p = await chatPartner(req, req.params.partnerId);
    if (!p) return res.status(404).json({ success: false, error: 'Topilmadi' });

    let q = supabaseAdmin
      .from('messages').select('*')
      .eq('partner_id', p.id)
      .order('created_at', { ascending: true });
    if (req.query.after) {
      const after = new Date(req.query.after);
      if (Number.isNaN(after.getTime()))
        return res.status(400).json({ success: false, error: 'after noto\'g\'ri sana formatida' });
      q = q.gt('created_at', after.toISOString());
    }
    const { data, error } = await q;
    if (error) throw new Error(error.message);

    // Eski ovozli xabarlar (2026-07-17 gacha) endi ko'rsatilmaydi — ovoz mahsulotdan olib tashlandi.
    const rows = (data || []).filter((m) => m.kind !== 'audio').map(toClient);
    res.json({ success: true, data: rows });
  } catch (e) { next(e); }
});

// POST /api/messages/:partnerId  { kind:'text', body } — matn xabari
router.post('/:partnerId', requireActiveSub, async (req, res, next) => {
  try {
    const p = await chatPartner(req, req.params.partnerId);
    if (!p) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const { kind, body } = req.body || {};
    if (kind !== 'text' || !body || !String(body).trim())
      return res.status(400).json({ success: false, error: "kind:'text' va bo'sh bo'lmagan body kerak" });
    const text = String(body).trim();
    if (text.length > 2000)
      return res.status(400).json({ success: false, error: 'Xabar juda uzun (maks. 2000 belgi)' });

    const { data, error } = await supabaseAdmin.from('messages').insert({
      partner_id: p.id,
      sender_id: req.user.id,
      kind: 'text',
      body: text,
    }).select().single();
    if (error) throw new Error(error.message);

    await notifyMessage(p, req.user.id, text.length > 80 ? `${text.slice(0, 77)}...` : text);
    res.status(201).json({ success: true, data: toClient(data) });
  } catch (e) { next(e); }
});

// POST /api/messages/:partnerId/read — qarshi tomon yuborganlarini o'qildi deb belgilash
router.post('/:partnerId/read', async (req, res, next) => {
  try {
    const p = await chatPartner(req, req.params.partnerId);
    if (!p) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const { error } = await supabaseAdmin.from('messages')
      .update({ read_at: new Date().toISOString() })
      .eq('partner_id', p.id)
      .neq('sender_id', req.user.id)
      .is('read_at', null);
    if (error) throw new Error(error.message);

    res.json({ success: true });
  } catch (e) { next(e); }
});

export default router;

import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { deltaFor, typeLabel } from '../lib/ops.js';
import { displayName, notifEnabled } from '../lib/links.js';

const router = Router();
router.use(requireAuth);

const fmt = (n) => Number(n).toLocaleString('ru-RU');

// Mijozga yangi yozuv xabari (profil sozlamasiga bo'ysunadi).
// accepted — to'liq tafsilot (tur · summa); pending — UMUMIY xabar (summa OSHKOR QILINMAYDI,
// chunki mijoz tafsilotni faqat bog'lanishni qabul qilgach ko'radi — link modeli).
async function notifyCounterparty(partner, sellerId, title, detail, operationId) {
  if (!partner?.counterparty_id) return;
  if (partner.link_status === 'rejected') return; // rad etgan mijozga xabar yubormaymiz
  if (!(await notifEnabled(partner.counterparty_id))) return;
  const accepted = partner.link_status === 'accepted';
  await supabaseAdmin.from('notifications').insert({
    user_id: partner.counterparty_id,
    sender_id: sellerId,
    type: 'op_new',
    title,
    detail: accepted ? detail : "Yangi yozuv kiritildi — ko'rish uchun bog'lanishni qabul qiling",
    operation_id: accepted ? (operationId ?? null) : null,
    link_id: partner.id,
  });
}

// POST /api/operations  { partner_id, type, amount, currency?, note? }
// Bir tomonlama da'vo: sotuvchi yozadi, hech qanday tasdiq talab qilinmaydi.
router.post('/', async (req, res, next) => {
  try {
    const { partner_id, type, amount, currency, note } = req.body || {};
    const types = ['qarz_berdim', 'qarz_oldim', 'qaytardim', 'menga_qaytarildi'];
    if (!partner_id || !types.includes(type)) return res.status(400).json({ success: false, error: "partner_id va to'g'ri type kerak" });
    if (!amount || Number(amount) <= 0) return res.status(400).json({ success: false, error: 'amount musbat bo\'lishi kerak' });

    const { data: p } = await supabaseAdmin.from('partners').select('*').eq('id', partner_id).maybeSingle();
    if (!p || p.owner_id !== req.user.id) return res.status(404).json({ success: false, error: 'Hamkor topilmadi' });

    const { data, error } = await supabaseAdmin.from('operations').insert({
      owner_id: req.user.id,
      partner_id,
      counterparty_id: p.counterparty_id,
      type,
      amount: Number(amount),
      delta: deltaFor(type, amount),
      currency: currency || 'UZS',
      note: note || null,
      status: 'active',
      created_by: req.user.id,
    }).select().single();
    if (error) throw new Error(error.message);

    const { data: me } = await supabaseAdmin.from('profiles').select('full_name, phone').eq('id', req.user.id).maybeSingle();
    await notifyCounterparty(p, req.user.id, `${displayName(me)} yozuv kiritdi`,
      `${typeLabel(type)} · ${fmt(amount)} ${currency || 'UZS'}`, data.id);

    res.status(201).json({ success: true, data });
  } catch (e) { next(e); }
});

// PATCH /api/operations/:id  { amount?, note? }
// Yaratuvchi o'z yozuvini tuzatadi; har o'zgarish op_history'ga yoziladi (audit).
router.patch('/:id', async (req, res, next) => {
  try {
    const { data: op } = await supabaseAdmin.from('operations').select('*').eq('id', req.params.id).maybeSingle();
    if (!op || op.owner_id !== req.user.id) return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (op.created_by !== req.user.id)
      return res.status(403).json({ success: false, error: 'Faqat yozuv muallifi tuzatadi' });
    if (!['active', 'archived'].includes(op.status))
      return res.status(400).json({ success: false, error: 'Bekor qilingan yozuv tuzatilmaydi' });

    const patch = { updated_at: new Date().toISOString() };
    let histText = null;
    if (req.body?.amount !== undefined) {
      const newA = Number(req.body.amount);
      if (!newA || newA <= 0) return res.status(400).json({ success: false, error: 'amount musbat bo\'lishi kerak' });
      if (newA !== Number(op.amount)) {
        patch.amount = newA;
        patch.delta = deltaFor(op.type, newA);
        histText = `${fmt(op.amount)} -> ${fmt(newA)}`;
      }
    }
    if (req.body?.note !== undefined) patch.note = req.body.note || null;
    if (!histText && req.body?.note === undefined)
      return res.status(400).json({ success: false, error: 'O\'zgarish kiritilmadi' });

    const { data, error } = await supabaseAdmin.from('operations').update(patch).eq('id', op.id).select().single();
    if (error) throw new Error(error.message);

    if (histText) {
      await supabaseAdmin.from('op_history').insert({
        operation_id: op.id, change_text: histText, changed_by: req.user.id,
      });
      const { data: p } = await supabaseAdmin.from('partners').select('*').eq('id', op.partner_id).maybeSingle();
      const { data: me } = await supabaseAdmin.from('profiles').select('full_name, phone').eq('id', req.user.id).maybeSingle();
      await notifyCounterparty(p, req.user.id, `${displayName(me)} yozuvni tuzatdi`, histText, op.id);
    }

    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/operations/:id/cancel — muallif o'z yozuvini bekor qiladi
router.post('/:id/cancel', async (req, res, next) => {
  try {
    const { data: op } = await supabaseAdmin.from('operations').select('*').eq('id', req.params.id).maybeSingle();
    if (!op || op.owner_id !== req.user.id)
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (op.status !== 'active')
      return res.status(400).json({ success: false, error: 'Faqat faol yozuv bekor qilinadi' });
    const { data, error } = await supabaseAdmin.from('operations')
      .update({ status: 'cancelled', updated_at: new Date().toISOString() }).eq('id', op.id).select().single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/operations/:id/archive — ro'yxatdan yashiriladi, balansda qoladi
router.post('/:id/archive', async (req, res, next) => {
  try {
    const { data: op } = await supabaseAdmin.from('operations').select('*').eq('id', req.params.id).maybeSingle();
    if (!op || op.owner_id !== req.user.id)
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (op.status !== 'active')
      return res.status(400).json({ success: false, error: 'Faqat faol yozuv arxivlanadi' });
    const { data, error } = await supabaseAdmin.from('operations')
      .update({ status: 'archived', updated_at: new Date().toISOString() }).eq('id', op.id).select().single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// GET /api/operations/:id  (tarix bilan) — sotuvchi yoki QABUL QILGAN mijoz
router.get('/:id', async (req, res, next) => {
  try {
    const { data: op } = await supabaseAdmin.from('operations').select('*, op_history(*)').eq('id', req.params.id).maybeSingle();
    if (!op || (op.owner_id !== req.user.id && op.counterparty_id !== req.user.id))
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (op.counterparty_id === req.user.id && op.owner_id !== req.user.id) {
      const { data: p } = await supabaseAdmin.from('partners').select('link_status').eq('id', op.partner_id).maybeSingle();
      if (p?.link_status !== 'accepted')
        return res.status(403).json({ success: false, error: 'Avval bog\'lanishni qabul qiling' });
    }
    res.json({ success: true, data: op });
  } catch (e) { next(e); }
});

export default router;

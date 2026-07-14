import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { deltaFor, typeLabel, genCode } from '../lib/ops.js';

const router = Router();
router.use(requireAuth);

async function notify(userId, type, title, detail, operationId) {
  if (!userId) return;
  await supabaseAdmin.from('notifications').insert({ user_id: userId, type, title, detail, operation_id: operationId ?? null });
}

// POST /api/operations  { partner_id, type, amount, currency?, note? }
// Yaratuvchi yozadi -> pending + confirm_code; 2-tomon kod bilan tasdiqlaydi
router.post('/', async (req, res, next) => {
  try {
    const { partner_id, type, amount, currency, note } = req.body || {};
    const types = ['qarz_berdim', 'qarz_oldim', 'qaytardim', 'menga_qaytarildi'];
    if (!partner_id || !types.includes(type)) return res.status(400).json({ success: false, error: "partner_id va to'g'ri type kerak" });
    if (!amount || Number(amount) <= 0) return res.status(400).json({ success: false, error: 'amount musbat bo\'lishi kerak' });

    const { data: p } = await supabaseAdmin.from('partners').select('*').eq('id', partner_id).maybeSingle();
    if (!p || p.owner_id !== req.user.id) return res.status(404).json({ success: false, error: 'Hamkor topilmadi' });

    const code = p.on_trust ? genCode() : null;
    const status = p.on_trust ? 'pending' : 'confirmed'; // Trust'da bo'lmasa bir tomonlama (tasdiqsiz), lekin darhol yoziladi
    const { data, error } = await supabaseAdmin.from('operations').insert({
      owner_id: req.user.id,
      partner_id,
      counterparty_id: p.counterparty_id,
      type,
      amount: Number(amount),
      delta: deltaFor(type, amount),
      currency: currency || 'UZS',
      note: note || null,
      status,
      confirm_code: code,
      confirmed_at: status === 'confirmed' ? new Date().toISOString() : null,
      created_by: req.user.id,
    }).select().single();
    if (error) throw new Error(error.message);

    if (p.on_trust && p.counterparty_id) {
      await notify(p.counterparty_id, 'req', `${p.name} tasdiq so'radi`,
        `${typeLabel(type)} · ${Number(amount).toLocaleString('ru-RU')} ${currency || 'UZS'}`, data.id);
    }
    // Yaratuvchiga kodni ko'rsatamiz (2-tomon kiritishi uchun)
    res.status(201).json({ success: true, data: { ...data, confirm_code: code } });
  } catch (e) { next(e); }
});

// POST /api/operations/:id/confirm  { code }
router.post('/:id/confirm', async (req, res, next) => {
  try {
    const { data: op } = await supabaseAdmin.from('operations').select('*').eq('id', req.params.id).maybeSingle();
    if (!op) return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (op.status !== 'pending') return res.status(400).json({ success: false, error: `Holat 'pending' emas: ${op.status}` });
    if (String(req.body?.code || '') !== String(op.confirm_code || ''))
      return res.status(400).json({ success: false, error: "Kod noto'g'ri" });
    // Tasdiqlovchi 2-tomon bo'lishi kerak (yaratuvchi emas)
    if (op.created_by === req.user.id)
      return res.status(403).json({ success: false, error: "O'zingiz yaratgan yozuvni o'zingiz tasdiqlay olmaysiz" });

    const { data, error } = await supabaseAdmin.from('operations')
      .update({ status: 'confirmed', confirmed_at: new Date().toISOString(), updated_at: new Date().toISOString() })
      .eq('id', op.id).select().single();
    if (error) throw new Error(error.message);
    await notify(op.owner_id, 'ok', 'Yozuv tasdiqlandi', `${typeLabel(op.type)} · dalil bo'ldi`, op.id);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/operations/:id/cancel
router.post('/:id/cancel', async (req, res, next) => {
  try {
    const { data: op } = await supabaseAdmin.from('operations').select('*').eq('id', req.params.id).maybeSingle();
    if (!op || (op.owner_id !== req.user.id && op.counterparty_id !== req.user.id))
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (!['pending', 'confirmed'].includes(op.status))
      return res.status(400).json({ success: false, error: 'Bu holatda bekor qilib bo\'lmaydi' });
    const { data, error } = await supabaseAdmin.from('operations')
      .update({ status: 'cancelled', updated_at: new Date().toISOString() }).eq('id', op.id).select().single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// GET /api/operations/:id  (dalil — tarix bilan)
router.get('/:id', async (req, res, next) => {
  try {
    const { data: op } = await supabaseAdmin.from('operations').select('*, op_history(*), edit_requests(*)').eq('id', req.params.id).maybeSingle();
    if (!op || (op.owner_id !== req.user.id && op.counterparty_id !== req.user.id))
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    res.json({ success: true, data: op });
  } catch (e) { next(e); }
});

// POST /api/operations/:id/edit-request  { new_amount, new_note? }
router.post('/:id/edit-request', async (req, res, next) => {
  try {
    const { new_amount, new_note } = req.body || {};
    if (!new_amount || Number(new_amount) <= 0) return res.status(400).json({ success: false, error: 'new_amount kerak' });
    const { data: op } = await supabaseAdmin.from('operations').select('*').eq('id', req.params.id).maybeSingle();
    if (!op || (op.owner_id !== req.user.id && op.counterparty_id !== req.user.id))
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (op.status !== 'confirmed') return res.status(400).json({ success: false, error: "Faqat tasdiqlangan yozuvni o'zgartirish mumkin" });

    const { data, error } = await supabaseAdmin.from('edit_requests').insert({
      operation_id: op.id, new_amount: Number(new_amount), new_note: new_note || null, requested_by: req.user.id,
    }).select().single();
    if (error) throw new Error(error.message);
    const other = op.owner_id === req.user.id ? op.counterparty_id : op.owner_id;
    await notify(other, 'edit', "O'zgartirish so'rovi",
      `${Number(op.amount).toLocaleString('ru-RU')} -> ${Number(new_amount).toLocaleString('ru-RU')}`, op.id);
    res.status(201).json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/operations/:id/edit-request/:reqId/resolve  { approve: true|false }
router.post('/:id/edit-request/:reqId/resolve', async (req, res, next) => {
  try {
    const approve = !!req.body?.approve;
    const { data: er } = await supabaseAdmin.from('edit_requests').select('*').eq('id', req.params.reqId).maybeSingle();
    if (!er || er.operation_id !== req.params.id) return res.status(404).json({ success: false, error: 'So\'rov topilmadi' });
    if (er.status !== 'pending') return res.status(400).json({ success: false, error: 'So\'rov allaqachon hal qilingan' });
    const { data: op } = await supabaseAdmin.from('operations').select('*').eq('id', er.operation_id).maybeSingle();
    if (!op || (op.owner_id !== req.user.id && op.counterparty_id !== req.user.id))
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (er.requested_by === req.user.id)
      return res.status(403).json({ success: false, error: "O'z so'rovingizni o'zingiz hal qila olmaysiz" });

    await supabaseAdmin.from('edit_requests')
      .update({ status: approve ? 'approved' : 'rejected', resolved_at: new Date().toISOString() }).eq('id', er.id);

    if (approve) {
      const fmt = (n) => Number(n).toLocaleString('ru-RU');
      await supabaseAdmin.from('op_history').insert({
        operation_id: op.id, change_text: `${fmt(op.amount)} -> ${fmt(er.new_amount)}`, changed_by: req.user.id,
      });
      await supabaseAdmin.from('operations').update({
        amount: er.new_amount, delta: (op.delta < 0 ? -1 : 1) * Number(er.new_amount),
        note: er.new_note ?? op.note, updated_at: new Date().toISOString(),
      }).eq('id', op.id);
      await notify(er.requested_by, 'ok', "O'zgartirish tasdiqlandi", `${fmt(op.amount)} -> ${fmt(er.new_amount)}`, op.id);
    } else {
      await notify(er.requested_by, 'rej', "O'zgartirish rad etildi", null, op.id);
    }
    res.json({ success: true, data: { approved: approve } });
  } catch (e) { next(e); }
});

export default router;

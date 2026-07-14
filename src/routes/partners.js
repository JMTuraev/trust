import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { normalizePhone } from '../lib/phone.js';

const router = Router();
router.use(requireAuth);

// Hamkorning balansini hisoblash (tasdiqlangan operatsiyalar yig'indisi)
async function balanceOf(partnerId) {
  const { data } = await supabaseAdmin
    .from('operations')
    .select('delta, status')
    .eq('partner_id', partnerId)
    .eq('status', 'confirmed');
  return (data || []).reduce((s, o) => s + Number(o.delta), 0);
}

async function pendingCount(partnerId) {
  const { count } = await supabaseAdmin
    .from('operations')
    .select('id', { count: 'exact', head: true })
    .eq('partner_id', partnerId)
    .eq('status', 'pending');
  return count || 0;
}

// GET /api/partners
router.get('/', async (req, res, next) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('partners')
      .select('*')
      .eq('owner_id', req.user.id)
      .order('updated_at', { ascending: false });
    if (error) throw new Error(error.message);
    const rows = await Promise.all((data || []).map(async (p) => ({
      ...p,
      balance: await balanceOf(p.id),
      pending: await pendingCount(p.id),
    })));
    res.json({ success: true, data: rows });
  } catch (e) { next(e); }
});

// POST /api/partners  { name, counterparty_phone, on_trust }
router.post('/', async (req, res, next) => {
  try {
    const { name, counterparty_phone, on_trust } = req.body || {};
    const phone = normalizePhone(counterparty_phone);
    if (!name || !phone) return res.status(400).json({ success: false, error: 'name va telefon kerak' });
    const { data: cp } = await supabaseAdmin.from('profiles').select('id').eq('phone', phone).maybeSingle();
    const { data, error } = await supabaseAdmin.from('partners').insert({
      owner_id: req.user.id,
      counterparty_id: cp?.id ?? null,
      counterparty_phone: phone,
      name,
      on_trust: !!on_trust && !!cp,
    }).select().single();
    if (error) throw new Error(error.message);
    res.status(201).json({ success: true, data });
  } catch (e) { next(e); }
});

// GET /api/partners/:id  (operatsiyalari bilan)
router.get('/:id', async (req, res, next) => {
  try {
    const { data: p } = await supabaseAdmin.from('partners').select('*').eq('id', req.params.id).maybeSingle();
    if (!p || (p.owner_id !== req.user.id && p.counterparty_id !== req.user.id))
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { data: ops } = await supabaseAdmin
      .from('operations').select('*').eq('partner_id', p.id).order('created_at', { ascending: false });
    res.json({ success: true, data: { ...p, balance: await balanceOf(p.id), pending: await pendingCount(p.id), operations: ops || [] } });
  } catch (e) { next(e); }
});

// PATCH /api/partners/:id  { name?, archived? }
router.patch('/:id', async (req, res, next) => {
  try {
    const { data: p } = await supabaseAdmin.from('partners').select('owner_id').eq('id', req.params.id).maybeSingle();
    if (!p || p.owner_id !== req.user.id) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const patch = { updated_at: new Date().toISOString() };
    if (req.body?.name !== undefined) patch.name = req.body.name;
    if (req.body?.archived !== undefined) patch.archived = !!req.body.archived;
    const { data, error } = await supabaseAdmin.from('partners').update(patch).eq('id', req.params.id).select().single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

export default router;
export { balanceOf };

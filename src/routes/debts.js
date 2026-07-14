import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { normalizePhone } from '../lib/phone.js';

const router = Router();
router.use(requireAuth);

// GET /api/debts?role=lender|borrower&status=...
router.get('/', async (req, res, next) => {
  try {
    let q = supabaseAdmin
      .from('debts')
      .select('*, payments(*)')
      .or(`lender_id.eq.${req.user.id},borrower_id.eq.${req.user.id}`)
      .order('created_at', { ascending: false });
    if (req.query.status) q = q.eq('status', req.query.status);
    const { data, error } = await q;
    if (error) throw new Error(error.message);
    let rows = data;
    if (req.query.role === 'lender') rows = rows.filter((d) => d.lender_id === req.user.id);
    if (req.query.role === 'borrower') rows = rows.filter((d) => d.borrower_id === req.user.id);
    res.json({ success: true, data: rows });
  } catch (e) {
    next(e);
  }
});

// POST /api/debts
// { "direction": "lent"|"borrowed", "counterparty_phone": "+998...", "amount": 100000,
//   "currency": "UZS", "note": "...", "due_date": "2026-08-01" }
router.post('/', async (req, res, next) => {
  try {
    const { direction, counterparty_phone, amount, currency, note, due_date } = req.body || {};
    if (!['lent', 'borrowed'].includes(direction))
      return res.status(400).json({ success: false, error: "direction 'lent' yoki 'borrowed' bo'lishi kerak" });
    const phone = normalizePhone(counterparty_phone);
    if (!phone) return res.status(400).json({ success: false, error: "counterparty_phone noto'g'ri" });
    if (!amount || Number(amount) <= 0)
      return res.status(400).json({ success: false, error: "amount musbat son bo'lishi kerak" });

    // Qarama-qarshi taraf ro'yxatdan o'tganmi?
    const { data: cp } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('phone', phone)
      .maybeSingle();

    const isLender = direction === 'lent';
    const { data, error } = await supabaseAdmin
      .from('debts')
      .insert({
        lender_id: isLender ? req.user.id : cp?.id ?? null,
        borrower_id: isLender ? cp?.id ?? null : req.user.id,
        counterparty_phone: phone,
        amount: Number(amount),
        currency: currency || 'UZS',
        note: note || null,
        due_date: due_date || null,
        created_by: req.user.id,
        status: 'pending',
      })
      .select()
      .single();
    if (error) throw new Error(error.message);
    res.status(201).json({ success: true, data });
  } catch (e) {
    next(e);
  }
});

// GET /api/debts/:id
router.get('/:id', async (req, res, next) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('debts')
      .select('*, payments(*)')
      .eq('id', req.params.id)
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (!data || (data.lender_id !== req.user.id && data.borrower_id !== req.user.id))
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    res.json({ success: true, data });
  } catch (e) {
    next(e);
  }
});

// POST /api/debts/:id/confirm — ikkinchi taraf tasdiqlaydi
router.post('/:id/confirm', async (req, res, next) => {
  try {
    const { data: debt } = await supabaseAdmin
      .from('debts')
      .select('*')
      .eq('id', req.params.id)
      .maybeSingle();
    if (!debt) return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (debt.status !== 'pending')
      return res.status(400).json({ success: false, error: `Holat 'pending' emas: ${debt.status}` });
    if (debt.created_by === req.user.id)
      return res.status(403).json({ success: false, error: "O'zingiz yaratgan qarzni o'zingiz tasdiqlay olmaysiz" });

    // Agar taraf hali bog'lanmagan bo'lsa - telefon orqali bog'laymiz
    const { data: me } = await supabaseAdmin
      .from('profiles')
      .select('id, phone')
      .eq('id', req.user.id)
      .maybeSingle();
    const patch = { status: 'active', confirmed_at: new Date().toISOString() };
    if (!debt.lender_id && me?.phone === debt.counterparty_phone) patch.lender_id = req.user.id;
    if (!debt.borrower_id && me?.phone === debt.counterparty_phone) patch.borrower_id = req.user.id;
    if (debt.lender_id !== req.user.id && debt.borrower_id !== req.user.id && me?.phone !== debt.counterparty_phone)
      return res.status(403).json({ success: false, error: 'Bu qarz sizga tegishli emas' });

    const { data, error } = await supabaseAdmin
      .from('debts')
      .update(patch)
      .eq('id', req.params.id)
      .select()
      .single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) {
    next(e);
  }
});

// POST /api/debts/:id/cancel
router.post('/:id/cancel', async (req, res, next) => {
  try {
    const { data: debt } = await supabaseAdmin
      .from('debts').select('*').eq('id', req.params.id).maybeSingle();
    if (!debt || (debt.lender_id !== req.user.id && debt.borrower_id !== req.user.id && debt.created_by !== req.user.id))
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (!['pending', 'active'].includes(debt.status))
      return res.status(400).json({ success: false, error: 'Bu holatda bekor qilib bo\'lmaydi' });
    const { data, error } = await supabaseAdmin
      .from('debts')
      .update({ status: 'cancelled', updated_at: new Date().toISOString() })
      .eq('id', req.params.id)
      .select()
      .single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) {
    next(e);
  }
});

// POST /api/debts/:id/payments  { "amount": 50000, "note": "..." }
router.post('/:id/payments', async (req, res, next) => {
  try {
    const { amount, note } = req.body || {};
    if (!amount || Number(amount) <= 0)
      return res.status(400).json({ success: false, error: "amount musbat son bo'lishi kerak" });

    const { data: debt } = await supabaseAdmin
      .from('debts').select('*, payments(amount)').eq('id', req.params.id).maybeSingle();
    if (!debt || (debt.lender_id !== req.user.id && debt.borrower_id !== req.user.id))
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (debt.status !== 'active')
      return res.status(400).json({ success: false, error: "Faqat 'active' qarzga to'lov kiritiladi" });

    const { data: payment, error } = await supabaseAdmin
      .from('payments')
      .insert({ debt_id: debt.id, payer_id: req.user.id, amount: Number(amount), note: note || null })
      .select()
      .single();
    if (error) throw new Error(error.message);

    // To'liq to'langan bo'lsa - qarz yopiladi
    const paid = (debt.payments || []).reduce((s, p) => s + Number(p.amount), 0) + Number(amount);
    if (paid >= Number(debt.amount)) {
      await supabaseAdmin
        .from('debts')
        .update({ status: 'paid', updated_at: new Date().toISOString() })
        .eq('id', debt.id);
    }

    res.status(201).json({ success: true, data: { payment, total_paid: paid, debt_amount: Number(debt.amount) } });
  } catch (e) {
    next(e);
  }
});

export default router;

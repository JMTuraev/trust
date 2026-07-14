import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();
router.use(requireAuth);

// GET /api/expenses?from=ISO&to=ISO
router.get('/', async (req, res, next) => {
  try {
    let q = supabaseAdmin.from('expenses').select('*').eq('user_id', req.user.id).order('occurred_at', { ascending: false });
    if (req.query.from) q = q.gte('occurred_at', req.query.from);
    if (req.query.to) q = q.lte('occurred_at', req.query.to);
    const { data, error } = await q;
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/expenses  { income, amount, category?, note? }
router.post('/', async (req, res, next) => {
  try {
    const { income, amount, category, note } = req.body || {};
    if (!amount || Number(amount) <= 0) return res.status(400).json({ success: false, error: 'amount kerak' });
    const { data, error } = await supabaseAdmin.from('expenses').insert({
      user_id: req.user.id, income: !!income, amount: Number(amount), category: category || null, note: note || null,
    }).select().single();
    if (error) throw new Error(error.message);
    res.status(201).json({ success: true, data });
  } catch (e) { next(e); }
});

// GET /api/expenses/summary  (bu oy: daromad, xarajat, sof, toifalar, limit)
router.get('/summary/month', async (req, res, next) => {
  try {
    const start = new Date(); start.setDate(1); start.setHours(0, 0, 0, 0);
    const { data } = await supabaseAdmin.from('expenses').select('income, amount, category')
      .eq('user_id', req.user.id).gte('occurred_at', start.toISOString());
    const rows = data || [];
    const income = rows.filter((r) => r.income).reduce((s, r) => s + Number(r.amount), 0);
    const expense = rows.filter((r) => !r.income).reduce((s, r) => s + Number(r.amount), 0);
    const cats = {};
    rows.filter((r) => !r.income).forEach((r) => { const k = r.category || 'Boshqa'; cats[k] = (cats[k] || 0) + Number(r.amount); });
    const { data: lim } = await supabaseAdmin.from('limits').select('monthly_limit').eq('user_id', req.user.id).maybeSingle();
    res.json({ success: true, data: { income, expense, net: income - expense,
      categories: Object.entries(cats).map(([name, amt]) => ({ name, amt })).sort((a, b) => b.amt - a.amt),
      limit: Number(lim?.monthly_limit || 0), spent: expense } });
  } catch (e) { next(e); }
});

export default router;

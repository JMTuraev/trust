import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { parseText, learnFrom, isQarz, DIRECTIONS } from '../services/parse.js';
import { ensureCategories } from '../lib/categories.js';

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

// POST /api/expenses/parse  { text, source? }
// Uch signal (LLM + qoida + lug'at) -> { actions[], needs_confirm, provider }
// Hech narsa saqlanmaydi — saqlash /confirm orqali (tasdiqlash kartasi oqimi).
router.post('/parse', rateLimit({ windowMs: 60_000, max: 30 }), async (req, res, next) => {
  try {
    const text = String(req.body?.text || '').trim();
    if (text.length < 2 || text.length > 300) {
      return res.status(400).json({ success: false, error: "Matn 2–300 belgi bo'lsin" });
    }
    const r = await parseText(text, req.user.id);
    if (r.errors?.length) console.warn('parse fallback:', r.errors.join(' | '));
    res.json({ success: true, data: { actions: r.actions, needs_confirm: r.needs_confirm, provider: r.provider } });
  } catch (e) { next(e); }
});

// POST /api/expenses/confirm  { text, source?, actions: [...], parsed?: [...] }
// actions — user tasdiqlagan yakuniy holat (kartada tahrirlangan bo'lishi mumkin).
// daromad/xarajat -> expenses'ga yoziladi; qarz_* -> saqlanmaydi, `routed` bo'lib qaytadi
// (mobil Hamkorlar oqimiga yo'naltiradi). O'rganish: lug'at + tuzatishlar (few-shot).
router.post('/confirm', async (req, res, next) => {
  try {
    const text = String(req.body?.text || '').trim();
    const source = req.body?.source === 'voice' ? 'voice' : 'text';
    const list = Array.isArray(req.body?.actions) ? req.body.actions : [];
    if (!list.length) return res.status(400).json({ success: false, error: 'actions kerak' });
    if (list.length > 5) return res.status(400).json({ success: false, error: "Bitta gapda ko'pi bilan 5 amal" });

    const cats = await ensureCategories(req.user.id);
    const saved = []; const routed = []; const finals = [];
    for (const raw of list) {
      const direction = DIRECTIONS.includes(raw?.direction) ? raw.direction : 'xarajat';
      const amount = Math.round(Number(raw?.amount) || 0);
      if (amount <= 0) return res.status(400).json({ success: false, error: "Summa noto'g'ri" });
      const note = String(raw?.note || text).trim().slice(0, 200);
      const action = { direction, amount, currency: 'UZS', note, person: raw?.person ? String(raw.person).trim() : null };

      if (isQarz(direction)) { routed.push(action); finals.push(action); continue; }

      let category = direction === 'daromad' ? 'Daromad' : String(raw?.category || 'Boshqa').trim();
      if (direction === 'xarajat') {
        const hit = cats.find((c) => c.name.toLowerCase() === category.toLowerCase());
        if (!hit && raw?.accept_new_category === true && category.length >= 2 && category.length <= 40) {
          // Yangi toifa — faqat user "qo'shilsin" degan holatda (jimgina yaratilmaydi)
          const { error: ce } = await supabaseAdmin.from('categories')
            .insert({ user_id: req.user.id, name: category });
          if (ce && !/duplicate/i.test(ce.message)) throw new Error(ce.message);
        } else if (!hit) category = 'Boshqa';
        else category = hit.name;
      }
      action.category = category;

      const { data, error } = await supabaseAdmin.from('expenses').insert({
        user_id: req.user.id, income: direction === 'daromad', amount,
        category, note: note || null, source, raw_text: text || null,
        confidence: raw?.confidence != null ? Math.max(0, Math.min(1, Number(raw.confidence))) : null,
      }).select().single();
      if (error) throw new Error(error.message);
      saved.push(data); finals.push(action);
    }

    // O'rganish — bloklamaydi, xatosi asosiy oqimni buzmaydi
    const parsed = Array.isArray(req.body?.parsed) ? req.body.parsed : null;
    learnFrom(req.user.id, text, finals, parsed);

    res.status(201).json({ success: true, data: { saved, routed } });
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

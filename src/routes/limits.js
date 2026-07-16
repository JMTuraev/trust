import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();
router.use(requireAuth);

// DIQQAT: bu foydalanuvchining O'Z oylik xarajat byudjeti (limits jadvali) —
// obuna/tarif chegarasi EMAS. Obuna holati: lib/subscription.js + /api/profile/me.

router.get('/', async (req, res, next) => {
  try {
    const { data } = await supabaseAdmin.from('limits').select('*').eq('user_id', req.user.id).maybeSingle();
    res.json({ success: true, data: data || { user_id: req.user.id, monthly_limit: 0 } });
  } catch (e) { next(e); }
});

// PUT /api/limits  { "monthly_limit": 5000000 }  — 0 = limit o'chirilgan
router.put('/', async (req, res, next) => {
  try {
    const val = Math.round(Number(req.body?.monthly_limit));
    // Validatsiya: son bo'lsin, manfiy emas, aqlga sig'adigan chegarada (numeric(18,2) toshmasin)
    if (!Number.isFinite(val) || val < 0 || val > 1e13) {
      return res.status(400).json({ success: false, error: "Limit 0 yoki musbat son bo'lsin" });
    }
    const { data, error } = await supabaseAdmin.from('limits')
      .upsert({ user_id: req.user.id, monthly_limit: val, updated_at: new Date().toISOString() }).select().single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

export default router;

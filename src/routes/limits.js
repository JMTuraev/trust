import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();
router.use(requireAuth);

router.get('/', async (req, res, next) => {
  try {
    const { data } = await supabaseAdmin.from('limits').select('*').eq('user_id', req.user.id).maybeSingle();
    res.json({ success: true, data: data || { user_id: req.user.id, monthly_limit: 0 } });
  } catch (e) { next(e); }
});

router.put('/', async (req, res, next) => {
  try {
    const val = Number(req.body?.monthly_limit || 0);
    const { data, error } = await supabaseAdmin.from('limits')
      .upsert({ user_id: req.user.id, monthly_limit: val, updated_at: new Date().toISOString() }).select().single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

export default router;

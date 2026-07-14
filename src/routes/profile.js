import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();
router.use(requireAuth);

// GET /api/profile/me
router.get('/me', async (req, res, next) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .select('*')
      .eq('id', req.user.id)
      .maybeSingle();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) {
    next(e);
  }
});

// PUT /api/profile/me  { "full_name": "...", "avatar_url": "..." }
router.put('/me', async (req, res, next) => {
  try {
    const { full_name, avatar_url } = req.body || {};
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .update({ full_name, avatar_url, updated_at: new Date().toISOString() })
      .eq('id', req.user.id)
      .select()
      .single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) {
    next(e);
  }
});

export default router;

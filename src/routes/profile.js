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

// PUT /api/profile/me  { "full_name": "...", "avatar_url": "...", "notif_enabled": true|false }
router.put('/me', async (req, res, next) => {
  try {
    const { full_name, avatar_url, notif_enabled } = req.body || {};
    const patch = { updated_at: new Date().toISOString() };
    if (full_name !== undefined) patch.full_name = full_name;
    if (avatar_url !== undefined) patch.avatar_url = avatar_url;
    if (notif_enabled !== undefined) patch.notif_enabled = !!notif_enabled;
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .update(patch)
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

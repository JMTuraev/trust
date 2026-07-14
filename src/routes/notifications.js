import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();
router.use(requireAuth);

router.get('/', async (req, res, next) => {
  try {
    const { data, error } = await supabaseAdmin.from('notifications').select('*')
      .eq('user_id', req.user.id).order('created_at', { ascending: false }).limit(100);
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

router.post('/:id/read', async (req, res, next) => {
  try {
    await supabaseAdmin.from('notifications').update({ read: true }).eq('id', req.params.id).eq('user_id', req.user.id);
    res.json({ success: true });
  } catch (e) { next(e); }
});

router.post('/read-all', async (req, res, next) => {
  try {
    await supabaseAdmin.from('notifications').update({ read: true }).eq('user_id', req.user.id).eq('read', false);
    res.json({ success: true });
  } catch (e) { next(e); }
});

export default router;

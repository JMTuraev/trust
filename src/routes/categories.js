// Toifa CRUD — XOTIRA §4: qo'shish/qayta nomlash/arxivlash. O'chirish YO'Q (tarix buzilmasin).
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { ensureCategories } from '../lib/categories.js';

const router = Router();
router.use(requireAuth);

// GET /api/categories — faollar (birinchi so'rovda baza 7 tasi seed bo'ladi)
router.get('/', async (req, res, next) => {
  try {
    const cats = await ensureCategories(req.user.id);
    res.json({ success: true, data: cats });
  } catch (e) { next(e); }
});

// POST /api/categories  { name }
router.post('/', async (req, res, next) => {
  try {
    const name = String(req.body?.name || '').trim();
    if (name.length < 2 || name.length > 40) {
      return res.status(400).json({ success: false, error: "Toifa nomi 2–40 belgi bo'lsin" });
    }
    await ensureCategories(req.user.id);
    const { data, error } = await supabaseAdmin.from('categories')
      .insert({ user_id: req.user.id, name }).select().single();
    if (error) {
      if (/duplicate/i.test(error.message)) {
        return res.status(409).json({ success: false, error: 'Bunday toifa allaqachon bor' });
      }
      throw new Error(error.message);
    }
    res.status(201).json({ success: true, data });
  } catch (e) { next(e); }
});

// PATCH /api/categories/:id  { name? , archived? }
router.patch('/:id', async (req, res, next) => {
  try {
    const patch = {};
    if (req.body?.name != null) {
      const name = String(req.body.name).trim();
      if (name.length < 2 || name.length > 40) {
        return res.status(400).json({ success: false, error: "Toifa nomi 2–40 belgi bo'lsin" });
      }
      patch.name = name;
    }
    if (req.body?.archived != null) patch.archived = !!req.body.archived;
    if (!Object.keys(patch).length) {
      return res.status(400).json({ success: false, error: "O'zgartirish yo'q" });
    }
    const { data, error } = await supabaseAdmin.from('categories')
      .update(patch).eq('id', req.params.id).eq('user_id', req.user.id).select().maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) return res.status(404).json({ success: false, error: 'Toifa topilmadi' });
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

export default router;

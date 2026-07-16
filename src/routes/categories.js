// Toifa CRUD — XOTIRA §4: qo'shish/qayta nomlash/arxivlash. O'chirish YO'Q (tarix buzilmasin).
// Qayta nomlashda TARIX KO'CHADI: expenses.category va word_map lug'ati yangi nomga o'tadi
// (aks holda papka ikkiga bo'linib, eski yozuvlar "yo'qolgan" ko'rinardi).
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { ensureCategories } from '../lib/categories.js';
import { requireActiveSub } from '../lib/subscription.js';

const router = Router();
router.use(requireAuth);

// 'Boshqa' — parserning zaxira papkasi (topilmagan toifa shu yerga tushadi).
// Qayta nomlansa/arxivlansa fallback yozuvlari "egasiz" qolardi — qat'iy himoya.
const norm = (s) => String(s || '').toLowerCase().replace(/[’'`ʼ]/g, "'").trim();
const isBoshqa = (name) => norm(name) === 'boshqa';

// GET /api/categories        — faollar (birinchi so'rovda baza 7 tasi seed bo'ladi)
// GET /api/categories?all=1  — arxivlanganlar bilan (papka tahriri kartasi uchun)
router.get('/', async (req, res, next) => {
  try {
    const all = req.query.all === '1' || req.query.all === 'true';
    if (!all) {
      return res.json({ success: true, data: await ensureCategories(req.user.id) });
    }
    await ensureCategories(req.user.id); // baza toifalar seed bo'lsin
    const { data, error } = await supabaseAdmin.from('categories')
      .select('id, name, is_base, archived').eq('user_id', req.user.id)
      .order('created_at', { ascending: true });
    if (error) throw new Error(error.message);
    res.json({ success: true, data: data || [] });
  } catch (e) { next(e); }
});

// POST /api/categories  { name }
// Obuna: expired user yangi toifa yarata olmaydi (402 SUB_EXPIRED) — o'qish ochiq qoladi.
router.post('/', requireActiveSub, async (req, res, next) => {
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

// PATCH /api/categories/:id  { name?, archived? }
// name: qayta nomlash — expenses (tarix) va word_map (lug'at) yangi nomga KO'CHADI.
// archived: arxivlash/qaytarish — yozuvlar joyida qoladi, AI taklif qilmay qo'yadi.
router.patch('/:id', requireActiveSub, async (req, res, next) => {
  try {
    const { data: cat, error: ce } = await supabaseAdmin.from('categories')
      .select('*').eq('id', req.params.id).eq('user_id', req.user.id).maybeSingle();
    if (ce) throw new Error(ce.message);
    if (!cat) return res.status(404).json({ success: false, error: 'Toifa topilmadi' });

    const patch = {};
    let renameFrom = null;
    if (req.body?.name != null) {
      const name = String(req.body.name).trim();
      if (name.length < 2 || name.length > 40) {
        return res.status(400).json({ success: false, error: "Toifa nomi 2–40 belgi bo'lsin" });
      }
      if (isBoshqa(cat.name)) {
        return res.status(400).json({ success: false, error: "«Boshqa» — zaxira papka, nomi o'zgartirilmaydi" });
      }
      if (isBoshqa(name)) {
        return res.status(400).json({ success: false, error: "«Boshqa» nomi band — zaxira papka" });
      }
      if (name !== cat.name) { patch.name = name; renameFrom = cat.name; }
    }
    if (req.body?.archived != null) {
      const arch = !!req.body.archived;
      if (arch && isBoshqa(cat.name)) {
        return res.status(400).json({ success: false, error: '«Boshqa» arxivlanmaydi — aniqlanmagan yozuvlar shu yerga tushadi' });
      }
      patch.archived = arch;
    }
    if (!Object.keys(patch).length) {
      return res.status(400).json({ success: false, error: "O'zgartirish yo'q" });
    }

    const { data, error } = await supabaseAdmin.from('categories')
      .update(patch).eq('id', cat.id).eq('user_id', req.user.id).select().maybeSingle();
    if (error) {
      if (/duplicate/i.test(error.message)) {
        return res.status(409).json({ success: false, error: 'Bunday nomli toifa allaqachon bor' });
      }
      throw new Error(error.message);
    }
    if (!data) return res.status(404).json({ success: false, error: 'Toifa topilmadi' });

    // Qayta nomlash kaskadi — tarix yangi nom ostida davom etadi
    if (renameFrom) {
      // 1) Yozuvlar: eski toifadagi barcha CHIQIMLAR yangi nomga (papka bo'linmasin)
      const { error: ee } = await supabaseAdmin.from('expenses')
        .update({ category: data.name })
        .eq('user_id', req.user.id).eq('category', renameFrom).eq('income', false);
      if (ee) console.error('categories rename -> expenses:', ee.message);

      // 2) Lug'at (word_map): old -> new, PK to'qnashuvida hits birlashtiriladi
      try {
        const { data: wmOld } = await supabaseAdmin.from('word_map')
          .select('word, hits').eq('user_id', req.user.id).eq('category', renameFrom);
        for (const w of wmOld || []) {
          const { data: ex } = await supabaseAdmin.from('word_map').select('hits')
            .match({ user_id: req.user.id, word: w.word, category: data.name }).maybeSingle();
          await supabaseAdmin.from('word_map').upsert(
            { user_id: req.user.id, word: w.word, category: data.name,
              hits: (ex?.hits || 0) + w.hits, updated_at: new Date().toISOString() },
            { onConflict: 'user_id,word,category' });
        }
        if ((wmOld || []).length) {
          await supabaseAdmin.from('word_map').delete()
            .eq('user_id', req.user.id).eq('category', renameFrom);
        }
      } catch (we) {
        console.error('categories rename -> word_map:', we.message); // lug'at ikkilamchi — oqim buzilmaydi
      }
    }

    res.json({ success: true, data });
  } catch (e) { next(e); }
});

export default router;

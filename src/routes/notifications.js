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

// Hamkor kartasi badge'iga kiradigan turlar: qarz oqimi + eslatma + eski daftar (op_new).
// 'msg' (chat o'chiq) va link_* (alohida qabul-qilish oqimi, summasiz) KIRMAYDI.
const PARTNER_BADGE_TYPES = [
  'debt_new', 'debt_confirm', 'debt_reject', 'repay_new', 'settle_new',
  'edit_req', 'review_req', 'rem', 'op_new',
];

async function unreadPartnerRows(userId, cols) {
  return supabaseAdmin.from('notifications')
    .select(cols)
    .eq('user_id', userId).eq('read', false)
    .not('link_id', 'is', null)
    .in('type', PARTNER_BADGE_TYPES)
    .order('created_at', { ascending: false })
    .limit(1000);
}

// GET /api/notifications/counts — o'qilmagan, hamkorga tegishli bildirishnomalar
// bo'yicha per-partner hisob: { counts: { [partner_id]: {count, total_amount, last_amounts} } }
// last_amounts — eng so'nggi 3 ta summa (yangisi birinchi). Bitta so'rov (N+1 yo'q).
router.get('/counts', async (req, res, next) => {
  try {
    // amount ustuni 019 migratsiyada qo'shilgan — hali qo'llanmagan bo'lsa
    // summasiz (count'lar baribir to'g'ri) javob beramiz.
    let { data: rows, error } = await unreadPartnerRows(req.user.id, 'link_id, amount, created_at');
    if (error) ({ data: rows, error } = await unreadPartnerRows(req.user.id, 'link_id, created_at'));
    if (error) throw new Error(error.message);
    const counts = {};
    for (const n of rows || []) {
      const c = counts[n.link_id] || (counts[n.link_id] = { count: 0, total_amount: 0, last_amounts: [] });
      c.count += 1;
      const amt = Number(n.amount || 0);
      if (amt > 0) {
        c.total_amount += amt;
        if (c.last_amounts.length < 3) c.last_amounts.push(amt); // rows: yangisi birinchi
      }
    }
    res.json({ success: true, counts });
  } catch (e) { next(e); }
});

// POST /api/notifications/read { partner_id } — 1:1 ekran ochilganda shu hamkorning
// badge'ga kiradigan bildirishnomalarini o'qilgan qiladi (counts bilan simmetrik).
router.post('/read', async (req, res, next) => {
  try {
    const partnerId = req.body?.partner_id;
    if (!partnerId) return res.status(400).json({ success: false, error: 'partner_id kerak' });
    const { error } = await supabaseAdmin.from('notifications')
      .update({ read: true })
      .eq('user_id', req.user.id)
      .eq('link_id', partnerId)
      .in('type', PARTNER_BADGE_TYPES)
      .eq('read', false);
    if (error) throw new Error(error.message);
    res.json({ success: true });
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

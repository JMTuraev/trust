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
// bo'yicha per-partner hisob:
//   { counts: { [partner_id]: { count, total_amount, last_amounts, last } } }
//   count        — barcha o'qilmaganlar (valyutadan qat'i nazar)
//   total_amount — FAQAT UZS yoki currency NULL (eski/019gacha qator, default UZS)
//                  bo'yicha yig'indi — valyutalar ARALASHMAYDI (periodAggregates'dagi
//                  2026-08-04 review qoidasi bilan bir xil: 20 USD "20 so'm" bo'lmasin)
//   last_amounts — eng so'nggi ≤3 summa, YASSI raqamlar (orqaga moslik, valyutasiz)
//   last         — o'sha ≤3 summa {amount, currency} bilan (currency null = eski qator
//                  yoki ustun hali yo'q). Ikkalasi ham yangisi birinchi.
// Bitta so'rov (N+1 yo'q).
router.get('/counts', async (req, res, next) => {
  try {
    // amount/currency ustunlari 019 migratsiyada qo'shilgan — hali qo'llanmagan
    // bo'lsa summasiz (count'lar baribir to'g'ri) javob beramiz, 500 YO'Q.
    let { data: rows, error } = await unreadPartnerRows(req.user.id, 'link_id, amount, currency, created_at');
    if (error) ({ data: rows, error } = await unreadPartnerRows(req.user.id, 'link_id, created_at'));
    if (error) throw new Error(error.message);
    const counts = {};
    for (const n of rows || []) {
      const c = counts[n.link_id]
        || (counts[n.link_id] = { count: 0, total_amount: 0, last_amounts: [], last: [] });
      c.count += 1;
      const amt = Number(n.amount || 0);
      if (amt > 0) {
        if (!n.currency || n.currency === 'UZS') c.total_amount += amt; // UZS-only qoida
        if (c.last_amounts.length < 3) { // rows: yangisi birinchi
          c.last_amounts.push(amt);
          c.last.push({ amount: amt, currency: n.currency ?? null });
        }
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

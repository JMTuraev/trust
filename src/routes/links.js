// Mijoz tomoni: menga kelgan bog'lanishlar (meni kontragent qilib qo'shganlar).
// Qaror faqat mijoz qo'lida: qabul / rad / tiklash / aloqani uzish, cheksiz marta.
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { config } from '../config.js';
import { setLinkStatus, displayName, notifEnabled } from '../lib/links.js';

const router = Router();
router.use(requireAuth);

// Linkni yuklash — faqat mijoz (counterparty) uchun
async function myLink(req) {
  const { data: p } = await supabaseAdmin
    .from('partners').select('*').eq('id', req.params.id).maybeSingle();
  if (!p || p.counterparty_id !== req.user.id) return null;
  return p;
}

// Operatsiyalar xulosasi (minimal preview uchun): soni + summa (mijoz nuqtai nazarida).
// Valyutalar ARALASHMAYDI: totals — valyuta bo'yicha obyekt, total — UZS (orqaga moslik).
async function opsSummary(partnerId) {
  const map = await opsSummaryFor([partnerId]);
  return map.get(partnerId) || { ops_count: 0, total: 0, totals: {} };
}

// Ko'p link uchun ops xulosasi BITTA so'rovda — ro'yxatdagi N+1 o'rniga.
// Natija: Map<partnerId, {ops_count, total (UZS), totals: {UZS: -x, USD: y, ...}}>
async function opsSummaryFor(partnerIds) {
  const map = new Map(partnerIds.map((id) => [id, { ops_count: 0, total: 0, totals: {} }]));
  if (!partnerIds.length) return map;
  const { data } = await supabaseAdmin
    .from('operations')
    .select('partner_id, delta, currency, status')
    .in('partner_id', partnerIds)
    .in('status', ['active', 'archived']);
  for (const o of data || []) {
    const e = map.get(o.partner_id) || { ops_count: 0, total: 0, totals: {} };
    const cur = o.currency || 'UZS';
    e.ops_count += 1;
    // Mijoz nuqtai nazari: sotuvchi deltasining teskarisi (+ = sotuvchi mijozga qarzdor)
    e.totals[cur] = (e.totals[cur] || 0) - Number(o.delta);
    map.set(o.partner_id, e);
  }
  // total (UZS) — orqaga moslik; yopilgan (nolga teng) valyutalar olib tashlanadi
  for (const e of map.values()) {
    e.total = e.totals.UZS || 0;
    for (const cur of Object.keys(e.totals)) if (e.totals[cur] === 0) delete e.totals[cur];
  }
  return map;
}

// GET /api/links — menga kelgan barcha bog'lanishlar
// pending uchun ham shu minimal ma'lumot ko'rinadi: kim, nechta yozuv, umumiy summa
router.get('/', async (req, res, next) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('partners')
      .select('*, profiles!partners_owner_id_fkey(full_name, phone)')
      .eq('counterparty_id', req.user.id)
      .order('updated_at', { ascending: false });
    if (error) throw new Error(error.message);
    const ids = (data || []).map((p) => p.id);
    const summaries = await opsSummaryFor(ids);
    const rows = (data || []).map((p) => {
      const seller = p.profiles;
      const sum = summaries.get(p.id) || { ops_count: 0, total: 0, totals: {} };
      return {
        id: p.id,
        status: p.link_status,
        seller_name: (seller?.full_name || '').trim() || null,
        seller_phone: seller?.phone || p.counterparty_phone,
        seller_label: displayName(seller),
        my_alias: p.client_alias,
        ops_count: sum.ops_count,
        total: sum.total, // orqaga moslik: faqat UZS
        totals: sum.totals, // valyuta bo'yicha, masalan {"UZS": -150000}
        created_at: p.created_at,
        status_changed_at: p.status_changed_at,
      };
    });
    res.json({ success: true, data: rows });
  } catch (e) { next(e); }
});

// Status o'tishlari. restore = rejected->accepted, disconnect = accepted->rejected.
async function transition(req, res, next, allowedFrom, toStatus) {
  try {
    const p = await myLink(req);
    if (!p) return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (!allowedFrom.includes(p.link_status))
      return res.status(400).json({ success: false, error: `Holat '${p.link_status}' — bu amal qo'llanmaydi` });

    const data = await setLinkStatus(p, toStatus, req.user.id);

    if (toStatus === 'rejected') {
      // Sotuvchiga signal kechikish bilan (oynada tiklansa — umuman bormaydi)
      await supabaseAdmin.from('reject_signals').upsert({
        partner_id: p.id,
        seller_id: p.owner_id,
        due_at: new Date(Date.now() + config.links.rejectSignalDelayMs).toISOString(),
        sent: false,
      }, { onConflict: 'partner_id' });
    } else if (toStatus === 'accepted') {
      // Yuborilmagan rad signali bekor bo'ladi
      await supabaseAdmin.from('reject_signals').delete().eq('partner_id', p.id).eq('sent', false);
      // Sotuvchiga ijobiy xabar (sozlamaga bo'ysunadi)
      if (await notifEnabled(p.owner_id)) {
        const { data: me } = await supabaseAdmin.from('profiles').select('full_name, phone').eq('id', req.user.id).maybeSingle();
        await supabaseAdmin.from('notifications').insert({
          user_id: p.owner_id,
          sender_id: req.user.id,
          type: 'link_acc',
          title: 'Bog\'lanish qabul qilindi',
          detail: `${displayName(me)} bog'lanishni qabul qildi — yozuvlar ikki tomonda ko'rinadi`,
          link_id: p.id,
        });
      }
    }
    res.json({ success: true, data });
  } catch (e) { next(e); }
}

router.post('/:id/accept', (req, res, next) => transition(req, res, next, ['pending', 'rejected'], 'accepted'));
router.post('/:id/restore', (req, res, next) => transition(req, res, next, ['rejected'], 'accepted'));
router.post('/:id/reject', (req, res, next) => transition(req, res, next, ['pending', 'accepted'], 'rejected'));
router.post('/:id/disconnect', (req, res, next) => transition(req, res, next, ['accepted'], 'rejected'));

// PATCH /api/links/:id  { alias } — mijoz sotuvchiga o'zi uchun nom qo'yadi
router.patch('/:id', async (req, res, next) => {
  try {
    const p = await myLink(req);
    if (!p) return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (req.body?.alias === undefined) return res.status(400).json({ success: false, error: 'alias kerak' });
    const { data, error } = await supabaseAdmin.from('partners')
      .update({ client_alias: req.body.alias || null, updated_at: new Date().toISOString() })
      .eq('id', p.id).select().single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// GET /api/links/:id/operations — faqat qabul qilingan bog'lanishda to'liq tarix
router.get('/:id/operations', async (req, res, next) => {
  try {
    const p = await myLink(req);
    if (!p) return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (p.link_status !== 'accepted')
      return res.status(403).json({ success: false, error: 'Avval bog\'lanishni qabul qiling' });
    const { data: ops } = await supabaseAdmin
      .from('operations').select('*').eq('partner_id', p.id)
      .in('status', ['active', 'archived'])
      .order('created_at', { ascending: false });
    const sum = await opsSummary(p.id);
    res.json({ success: true, data: { ...sum, operations: ops || [] } });
  } catch (e) { next(e); }
});

// POST /api/links/:id/block — sotuvchini bloklash (bog'lanish rad holatiga o'tadi)
router.post('/:id/block', async (req, res, next) => {
  try {
    const p = await myLink(req);
    if (!p) return res.status(404).json({ success: false, error: 'Topilmadi' });
    await supabaseAdmin.from('blocks').upsert(
      { client_id: req.user.id, seller_id: p.owner_id },
      { onConflict: 'client_id,seller_id' }
    );
    if (p.link_status !== 'rejected') {
      await setLinkStatus(p, 'rejected', req.user.id);
      await supabaseAdmin.from('reject_signals').upsert({
        partner_id: p.id,
        seller_id: p.owner_id,
        due_at: new Date(Date.now() + config.links.rejectSignalDelayMs).toISOString(),
        sent: false,
      }, { onConflict: 'partner_id' });
    }
    res.json({ success: true });
  } catch (e) { next(e); }
});

// POST /api/links/:id/unblock — blok yechiladi (holat rejected bo'lib qolaveradi; tiklash alohida)
router.post('/:id/unblock', async (req, res, next) => {
  try {
    const p = await myLink(req);
    if (!p) return res.status(404).json({ success: false, error: 'Topilmadi' });
    await supabaseAdmin.from('blocks').delete()
      .eq('client_id', req.user.id).eq('seller_id', p.owner_id);
    res.json({ success: true });
  } catch (e) { next(e); }
});

export default router;

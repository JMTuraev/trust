// Mijoz tomoni: menga kelgan bog'lanishlar (meni kontragent qilib qo'shganlar).
// Qaror faqat mijoz qo'lida: qabul / rad / tiklash / aloqani uzish, cheksiz marta.
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { config } from '../config.js';
import { setLinkStatus, displayName, notifEnabled } from '../lib/links.js';
import { invalidateProfile } from '../services/ai-context.js';

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
// Eski 'operations' daftari + YANGI qarz daftari ('debts') birga hisoblanadi —
// sotuvchi ledger'da yozsa ham mijoz previewda haqiqiy son/summani ko'rsin.
// Natija: Map<partnerId, {ops_count, total (UZS), totals: {UZS: -x, USD: y, ...}}>
async function opsSummaryFor(partnerIds) {
  const map = new Map(partnerIds.map((id) => [id, { ops_count: 0, total: 0, totals: {} }]));
  if (!partnerIds.length) return map;
  const [ops, debts] = await Promise.all([
    supabaseAdmin
      .from('operations')
      .select('partner_id, delta, currency, status')
      .in('partner_id', partnerIds)
      .in('status', ['active', 'archived']),
    supabaseAdmin
      .from('debts')
      .select('partner_id, kind, status, direction, created_by, amount, paid, currency')
      .in('partner_id', partnerIds)
      .not('status', 'in', '(cancelled,rejected)'),
  ]);
  for (const o of ops.data || []) {
    const e = map.get(o.partner_id) || { ops_count: 0, total: 0, totals: {} };
    const cur = o.currency || 'UZS';
    e.ops_count += 1;
    // Mijoz nuqtai nazari: sotuvchi deltasining teskarisi (+ = sotuvchi mijozga qarzdor)
    e.totals[cur] = (e.totals[cur] || 0) - Number(o.delta);
    map.set(o.partner_id, e);
  }
  // Qarz daftari: ko'rinadigan yozuvlar soni + FAOL qarzlar qoldig'i (mijoz nuqtai nazari).
  // direction created_by nuqtai nazarida saqlanadi; mijoz uchun sotuvchi (owner)
  // yo'nalishining teskarisi kerak. Bu funksiya mijoz (counterparty) uchun ishlaydi,
  // shuning uchun created_by === mijoz bo'lsa yo'nalish o'z holicha, aks holda flip.
  const ownerOf = new Map(); // partner_id -> owner_id (debts.created_by bilan solishtirish uchun)
  if ((debts.data || []).length) {
    const { data: prows } = await supabaseAdmin
      .from('partners').select('id, owner_id').in('id', partnerIds);
    for (const p of prows || []) ownerOf.set(p.id, p.owner_id);
  }
  for (const d of debts.data || []) {
    const e = map.get(d.partner_id) || { ops_count: 0, total: 0, totals: {} };
    e.ops_count += 1;
    if (d.kind === 'debt' && d.status === 'active') {
      const remaining = Math.max(0, Number(d.amount) - Number(d.paid || 0));
      if (remaining > 0) {
        const cur = d.currency || 'UZS';
        // Owner nuqtai nazarida: created_by === owner bo'lsa direction o'z holicha
        const ownerDir = d.created_by === ownerOf.get(d.partner_id)
          ? d.direction
          : (d.direction === 'toMe' ? 'fromMe' : 'toMe');
        // Mijoz nuqtai nazari — teskarisi: owner 'toMe' => mijoz qarzdor (manfiy)
        const signed = ownerDir === 'toMe' ? -remaining : remaining;
        e.totals[cur] = (e.totals[cur] || 0) + signed;
      }
    }
    map.set(d.partner_id, e);
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
        // Fallback OLIB TASHLANDI: counterparty_phone mijozning O'Z raqami edi —
        // sotuvchi profili topilmasa (o'chirilgan) telefon ko'rsatilmaydi.
        seller_phone: seller?.phone || null,
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

    // Bog'lanish holati o'zgardi -> ikkala tomonning AI psevdonim xaritasi eskirishi
    // mumkin (qabul qilingach mijoz bu hamkorni ko'radi; rad/uzishda chiqib ketadi).
    // MAXFIYLIK: yangi ism keyingi AI so'rovida xom ketmasin (2026-07-18 review).
    await invalidateProfile(req.user.id);
    if (p.owner_id && p.owner_id !== req.user.id) await invalidateProfile(p.owner_id);

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
      // JOIN oqimi (ledger spec 5.1): off-Trust davri (oneSided) qarzlari endi ko'rib chiqish
      // navbatiga tushadi — mijoz ularni tasdiqlaydi (twoSided) yoki rad etadi (disputed).
      const { data: reviewRows } = await supabaseAdmin.from('debts')
        .update({ under_review: true, updated_at: new Date().toISOString() })
        .eq('partner_id', p.id).eq('prov', 'oneSided').eq('under_review', false)
        .in('status', ['active', 'closed']).select('id');
      if (reviewRows?.length && (await notifEnabled(req.user.id))) {
        const { data: seller } = await supabaseAdmin.from('profiles').select('full_name, phone').eq('id', p.owner_id).maybeSingle();
        await supabaseAdmin.from('notifications').insert({
          user_id: req.user.id,
          sender_id: p.owner_id,
          type: 'review_req',
          title: 'Eski yozuvlarni ko\'rib chiqing',
          detail: `${displayName(seller)} bilan ${reviewRows.length} ta tasdiqsiz yozuv — tasdiqlang yoki rad eting`,
          link_id: p.id,
        });
      }
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

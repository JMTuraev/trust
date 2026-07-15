import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { normalizePhone } from '../lib/phone.js';
import { config } from '../config.js';
import { logLinkEvent, displayName, notifEnabled } from '../lib/links.js';

const router = Router();
router.use(requireAuth);

// Hamkor balansi — sotuvchining O'Z daftari: active + archived hisobga kiradi
// (link statusi sotuvchi daftariga ta'sir qilmaydi; u faqat mijoz ko'rinishini boshqaradi)
// Valyutalar ARALASHMAYDI — har biri alohida yig'iladi.
// Natija: { balance: UZS yig'indisi (orqaga moslik), balances: {UZS: 150000, USD: -20, ...} }
async function balanceOf(partnerId) {
  const map = await balancesFor([partnerId]);
  const balances = map.get(partnerId) || {};
  return { balance: balances.UZS || 0, balances };
}

// Ko'p hamkor balansini BITTA so'rovda — ro'yxat uchun N+1 o'rniga.
// Barcha operatsiyalar bir marta olinadi, kodda partner_id + VALYUTA bo'yicha yig'iladi.
// Natija: Map<partnerId, {UZS: sum, USD: sum, ...}> — faqat nolga teng bo'lmagan valyutalar.
async function balancesFor(partnerIds) {
  const map = new Map(partnerIds.map((id) => [id, {}]));
  if (!partnerIds.length) return map;
  const { data } = await supabaseAdmin
    .from('operations')
    .select('partner_id, delta, currency, status')
    .in('partner_id', partnerIds)
    .in('status', ['active', 'archived']);
  for (const o of data || []) {
    const cur = o.currency || 'UZS';
    const b = map.get(o.partner_id) || {};
    b[cur] = (b[cur] || 0) + Number(o.delta);
    map.set(o.partner_id, b);
  }
  // Yopilgan (nolga teng) valyutalarni olib tashlaymiz — javob toza bo'lsin
  for (const b of map.values()) {
    for (const cur of Object.keys(b)) if (b[cur] === 0) delete b[cur];
  }
  return map;
}

// Eslatma matni uchun asosiy valyuta — absolyut qiymati eng kattasi (bo'sh bo'lsa UZS/0)
function mainBalance(balances) {
  let cur = 'UZS', val = balances.UZS || 0;
  for (const [c, v] of Object.entries(balances)) {
    if (Math.abs(v) > Math.abs(val)) { cur = c; val = v; }
  }
  return { cur, val };
}

// Sotuvchiga rad DARHOL ko'rinmasligi kerak — signal yuborilgunicha 'pending' deb ko'rsatamiz.
// (Embed o'rniga alohida so'rov: PostgREST sxema keshiga bog'lanmaymiz.)
async function sentSignalIds(partnerIds) {
  if (!partnerIds.length) return new Set();
  const { data } = await supabaseAdmin
    .from('reject_signals')
    .select('partner_id')
    .eq('sent', true)
    .in('partner_id', partnerIds);
  return new Set((data || []).map((s) => s.partner_id));
}

function maskStatus(p, sentIds) {
  const masked = p.link_status === 'rejected' && !sentIds.has(p.id) ? 'pending' : p.link_status;
  return { ...p, link_status: masked };
}

// GET /api/partners
router.get('/', async (req, res, next) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('partners')
      .select('*')
      .eq('owner_id', req.user.id)
      .order('updated_at', { ascending: false });
    if (error) throw new Error(error.message);
    const ids = (data || []).map((p) => p.id);
    const [sentIds, balances] = await Promise.all([sentSignalIds(ids), balancesFor(ids)]);
    const rows = (data || []).map((p) => {
      const b = balances.get(p.id) || {};
      return {
        ...maskStatus(p, sentIds),
        balance: b.UZS || 0, // orqaga moslik: faqat UZS yig'indisi
        balances: b, // valyuta bo'yicha, masalan {"UZS": 150000, "USD": -20}
      };
    });
    res.json({ success: true, data: rows });
  } catch (e) { next(e); }
});

// Yangi kontragent yaratishdan oldingi himoya tekshiruvlari.
// Xato bo'lsa {status, error} qaytaradi, hammasi joyida bo'lsa {cp} (profil yoki null).
async function creationGuards(req, phone) {
  if (phone === req.user.phone) {
    return { status: 400, error: "O'z raqamingizni kontragent qilib qo'sha olmaysiz" };
  }

  // Raqam egasi ro'yxatdan o'tganmi?
  const { data: cp } = await supabaseAdmin
    .from('profiles').select('id, full_name, phone').eq('phone', phone).maybeSingle();

  // Blok: raqam egasi bu sotuvchini bloklagan bo'lsa — yaratib bo'lmaydi
  if (cp) {
    const { data: blocked } = await supabaseAdmin
      .from('blocks').select('id')
      .eq('client_id', cp.id).eq('seller_id', req.user.id).limit(1);
    if (blocked?.length) {
      return { status: 403, error: 'Raqam egasi sizni bloklagan — kontragent qo\'shib bo\'lmaydi' };
    }
  }

  // Kunlik limit (oxirgi 24 soatda yaratilgan kontragentlar)
  const daily = config.links.partnerDailyLimit;
  const { count: todayCount } = await supabaseAdmin
    .from('partners').select('id', { count: 'exact', head: true })
    .eq('owner_id', req.user.id)
    .gte('created_at', new Date(Date.now() - 24 * 3600_000).toISOString());
  if ((todayCount || 0) >= daily) {
    return { status: 429, error: `Kunlik limit: 24 soatda ko'pi bilan ${daily} ta yangi kontragent` };
  }

  // Rad-flag: qisqa davrda ko'p rad olgan sotuvchi vaqtincha bloklanadi
  const { data: myPartners } = await supabaseAdmin
    .from('partners').select('id').eq('owner_id', req.user.id);
  const ids = (myPartners || []).map((x) => x.id);
  if (ids.length) {
    const since = new Date(Date.now() - config.links.rejectFlagWindowMs).toISOString();
    const { count: rejects } = await supabaseAdmin
      .from('link_events').select('id', { count: 'exact', head: true })
      .in('partner_id', ids)
      .eq('to_status', 'rejected')
      .not('changed_by', 'is', null) // faqat mijoz harakati (tizim/migratsiya emas)
      .gte('created_at', since);
    if ((rejects || 0) >= config.links.rejectFlagCount) {
      return { status: 429, error: 'Yangi kontragent qo\'shish vaqtincha cheklangan — so\'nggi so\'rovlaringiz rad etilgan' };
    }
  }

  return { cp };
}

// Mijozga "sizni qo'shishdi" bildirishnomasi (link_new — har doim boradi, sozlamaga bog'liq emas)
async function notifyLinkNew(sellerId, cpId, partnerId) {
  const { data: seller } = await supabaseAdmin
    .from('profiles').select('full_name, phone').eq('id', sellerId).maybeSingle();
  await supabaseAdmin.from('notifications').insert({
    user_id: cpId,
    sender_id: sellerId,
    type: 'link_new',
    title: 'Sizni kontragent qilib qo\'shishdi',
    detail: `${displayName(seller)} sizni kontragent qilib qo'shgan — qabul qilasizmi?`,
    link_id: partnerId,
  });
}

// POST /api/partners  { name, counterparty_phone }
router.post('/', async (req, res, next) => {
  try {
    const { name, counterparty_phone } = req.body || {};
    const phone = normalizePhone(counterparty_phone);
    if (!name || !phone) return res.status(400).json({ success: false, error: 'name va telefon kerak' });

    // Shu raqam bilan link bormi? Rad etilganini sotuvchi qayta so'rov bilan tiklay olmaydi.
    const { data: existing } = await supabaseAdmin
      .from('partners').select('id, link_status')
      .eq('owner_id', req.user.id).eq('counterparty_phone', phone).maybeSingle();
    if (existing) {
      const msg = existing.link_status === 'rejected'
        ? 'Raqam egasi bog\'lanishni rad etgan — tiklash faqat uning qo\'lida'
        : 'Bu raqam allaqachon kontragentlaringizda bor';
      return res.status(409).json({ success: false, error: msg });
    }

    const guard = await creationGuards(req, phone);
    if (guard.error) return res.status(guard.status).json({ success: false, error: guard.error });

    const { data, error } = await supabaseAdmin.from('partners').insert({
      owner_id: req.user.id,
      counterparty_id: guard.cp?.id ?? null,
      counterparty_phone: phone,
      name,
      link_status: 'pending',
      status_changed_at: new Date().toISOString(),
    }).select().single();
    if (error) throw new Error(error.message);

    await logLinkEvent(data.id, null, 'pending', req.user.id);
    if (guard.cp) await notifyLinkNew(req.user.id, guard.cp.id, data.id);

    res.status(201).json({ success: true, data });
  } catch (e) { next(e); }
});

// GET /api/partners/:id  (operatsiyalari bilan — sotuvchi yoki mijoz)
router.get('/:id', async (req, res, next) => {
  try {
    const { data: p } = await supabaseAdmin
      .from('partners').select('*').eq('id', req.params.id).maybeSingle();
    if (!p || (p.owner_id !== req.user.id && p.counterparty_id !== req.user.id))
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    // Mijoz faqat qabul qilingan bog'lanishning tarixini ko'radi
    if (p.counterparty_id === req.user.id && p.owner_id !== req.user.id && p.link_status !== 'accepted')
      return res.status(403).json({ success: false, error: 'Avval bog\'lanishni qabul qiling' });
    const { data: ops } = await supabaseAdmin
      .from('operations').select('*').eq('partner_id', p.id)
      .in('status', ['active', 'archived', 'cancelled'])
      .order('created_at', { ascending: false });
    const [sentIds, { balance, balances }] = await Promise.all([sentSignalIds([p.id]), balanceOf(p.id)]);
    res.json({
      success: true,
      data: { ...maskStatus(p, sentIds), balance, balances, operations: ops || [] },
    });
  } catch (e) { next(e); }
});

// POST /api/partners/:id/move  { new_phone } — xato kiritilgan raqamni to'g'rilash:
// yozuvlar yangi raqamga ko'chadi (yangi bog'lanish, yangi notification), eski qator arxivlanadi
router.post('/:id/move', async (req, res, next) => {
  try {
    const phone = normalizePhone(req.body?.new_phone);
    if (!phone) return res.status(400).json({ success: false, error: 'new_phone kerak' });
    const { data: old } = await supabaseAdmin
      .from('partners').select('*').eq('id', req.params.id).maybeSingle();
    if (!old || old.owner_id !== req.user.id)
      return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (phone === old.counterparty_phone)
      return res.status(400).json({ success: false, error: 'Raqam o\'zgarmadi' });

    const { data: existing } = await supabaseAdmin
      .from('partners').select('id, link_status')
      .eq('owner_id', req.user.id).eq('counterparty_phone', phone).maybeSingle();
    if (existing) {
      const msg = existing.link_status === 'rejected'
        ? 'Yangi raqam egasi bog\'lanishni rad etgan — tiklash faqat uning qo\'lida'
        : 'Bu raqam allaqachon kontragentlaringizda bor';
      return res.status(409).json({ success: false, error: msg });
    }

    const guard = await creationGuards(req, phone);
    if (guard.error) return res.status(guard.status).json({ success: false, error: guard.error });

    // Yangi link
    const { data: fresh, error } = await supabaseAdmin.from('partners').insert({
      owner_id: req.user.id,
      counterparty_id: guard.cp?.id ?? null,
      counterparty_phone: phone,
      name: old.name,
      link_status: 'pending',
      status_changed_at: new Date().toISOString(),
    }).select().single();
    if (error) throw new Error(error.message);
    await logLinkEvent(fresh.id, null, 'pending', req.user.id);

    // Operatsiyalarni ko'chirish
    await supabaseAdmin.from('operations')
      .update({ partner_id: fresh.id, counterparty_id: guard.cp?.id ?? null, updated_at: new Date().toISOString() })
      .eq('partner_id', old.id);

    // Eski qator arxivlanadi (ma'lumot o'chirilmaydi)
    await supabaseAdmin.from('partners')
      .update({ archived: true, updated_at: new Date().toISOString() }).eq('id', old.id);

    if (guard.cp) await notifyLinkNew(req.user.id, guard.cp.id, fresh.id);

    res.status(201).json({ success: true, data: fresh });
  } catch (e) { next(e); }
});

// POST /api/partners/:id/remind — eslatma (faqat qabul qilingan bog'lanishda, 3 soat cooldown)
router.post('/:id/remind', async (req, res, next) => {
  try {
    const { data: p } = await supabaseAdmin.from('partners').select('*').eq('id', req.params.id).maybeSingle();
    if (!p || p.owner_id !== req.user.id) return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (!p.counterparty_id || p.link_status !== 'accepted')
      return res.status(400).json({ success: false, error: 'Eslatma faqat qabul qilingan bog\'lanishda yuboriladi' });
    if (!(await notifEnabled(p.counterparty_id)))
      return res.status(400).json({ success: false, error: 'Qarshi tomon bildirishnomalarni o\'chirgan' });

    const { data: last } = await supabaseAdmin.from('notifications')
      .select('id, created_at')
      .eq('user_id', p.counterparty_id).eq('type', 'rem').eq('sender_id', req.user.id)
      .gte('created_at', new Date(Date.now() - 3 * 3600_000).toISOString())
      .limit(1);
    if (last?.length) return res.status(429).json({ success: false, error: 'Eslatma yaqinda yuborilgan — 3 soatdan keyin qayta yuboriladi' });

    const { balances } = await balanceOf(p.id);
    const main = mainBalance(balances); // asosiy (eng katta absolyut) valyuta
    const { error } = await supabaseAdmin.from('notifications').insert({
      user_id: p.counterparty_id,
      sender_id: req.user.id,
      type: 'rem',
      title: 'Eslatma',
      detail: `${Math.abs(main.val).toLocaleString('ru-RU')} ${main.cur} — hisobni ko'rib chiqing`,
      link_id: p.id,
    });
    if (error) throw new Error(error.message);
    res.json({ success: true });
  } catch (e) { next(e); }
});

// PATCH /api/partners/:id  { name?, archived? } — sotuvchining o'z ko'rinishi
router.patch('/:id', async (req, res, next) => {
  try {
    const { data: p } = await supabaseAdmin.from('partners').select('owner_id').eq('id', req.params.id).maybeSingle();
    if (!p || p.owner_id !== req.user.id) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const patch = { updated_at: new Date().toISOString() };
    if (req.body?.name !== undefined) patch.name = req.body.name;
    if (req.body?.archived !== undefined) patch.archived = !!req.body.archived;
    const { data, error } = await supabaseAdmin.from('partners').update(patch).eq('id', req.params.id).select().single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

export default router;
export { balanceOf };

// Qarz daftari (ledger) — har qarz ALOHIDA yozuv, ikki tomonlama tasdiq.
// Istisno: oneSided (off-Trust hamkor) — tasdiqsiz DARHOL kuchga kiradi.
// Huquq KODDA tekshiriladi (service_role RLS chetlab o'tadi): owner yoki accepted counterparty.
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { displayName, notifEnabled } from '../lib/links.js';
import {
  rem, remEff, isLockedByPending, isOverdue, applyRepaySettle, canonicalDir,
} from '../lib/ledger.js';

const router = Router();
router.use(requireAuth);

const CURRENCIES = ['UZS', 'USD', 'EUR', 'RUB'];
const fmt = (n) => Number(n).toLocaleString('ru-RU');
const nowIso = () => new Date().toISOString();
const todayStr = () => new Date().toISOString().slice(0, 10);

function validateAmount(a) {
  const n = Number(a);
  if (!Number.isInteger(n) || n <= 0) return "summa musbat butun son bo'lishi kerak";
  if (n > Number.MAX_SAFE_INTEGER) return 'summa juda katta';
  return null;
}
const isDate = (s) => typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(s));

// Hamkorni yuklash + huquq: owner_id yoki (counterparty_id AND link_status='accepted').
async function loadPartnerForUser(partnerId, userId) {
  const { data: p } = await supabaseAdmin.from('partners').select('*').eq('id', partnerId).maybeSingle();
  if (!p) return null;
  const isOwner = p.owner_id === userId;
  const isCp = p.counterparty_id === userId && p.link_status === 'accepted';
  return isOwner || isCp ? p : null;
}

// Yozuvni + hamkorni yuklash (huquq bilan). :id endpointlar uchun.
async function loadDebtWithPartner(debtId, userId) {
  const { data: d } = await supabaseAdmin.from('debts').select('*').eq('id', debtId).maybeSingle();
  if (!d) return null;
  const p = await loadPartnerForUser(d.partner_id, userId);
  if (!p) return null;
  return { debt: d, partner: p };
}

// Hamkor Trust'da va bog'lanish qabul qilinganmi -> twoSided; aks holda oneSided (off-Trust).
const provOf = (p) => (p.counterparty_id && p.link_status === 'accepted') ? 'twoSided' : 'oneSided';
// Amalni bajaruvchidan boshqa taraf (xabar oluvchi).
const otherParty = (p, actorId) => (p.owner_id === actorId ? p.counterparty_id : p.owner_id);

async function meName(userId) {
  const { data } = await supabaseAdmin.from('profiles').select('full_name, phone').eq('id', userId).maybeSingle();
  return displayName(data);
}

// Bildirishnoma (profil sozlamasiga bo'ysunadi, op_new naqshi bilan bir xil). link_id = partner_id.
async function notify(userId, senderId, type, title, detail, partnerId) {
  if (!userId) return;
  if (!(await notifEnabled(userId))) return;
  await supabaseAdmin.from('notifications').insert({
    user_id: userId, sender_id: senderId, type, title, detail, link_id: partnerId || null,
  });
}

// Shu qarzga bog'liq repay/settle bolalari (band tekshiruvi uchun).
async function childrenOf(debtId) {
  const { data } = await supabaseAdmin.from('debts')
    .select('id, kind, status, amount, ref_id')
    .eq('ref_id', debtId).in('kind', ['repay', 'settle']);
  return data || [];
}

// ============================================================
// GET /api/debts/:partnerId — shu hamkorning barcha yozuvlari (created_at, chronologik)
// ============================================================
router.get('/:partnerId', async (req, res, next) => {
  try {
    const p = await loadPartnerForUser(req.params.partnerId, req.user.id);
    if (!p) return res.status(404).json({ success: false, error: 'Hamkor topilmadi' });

    const { data: rows, error } = await supabaseAdmin.from('debts').select('*')
      .eq('partner_id', p.id).order('created_at', { ascending: true });
    if (error) throw new Error(error.message);
    const all = rows || [];

    // versions'ni bitta so'rovda olib, qarz bo'yicha guruhlash
    const versByDebt = new Map();
    const ids = all.map((r) => r.id);
    if (ids.length) {
      const { data: vers } = await supabaseAdmin.from('debt_versions').select('*')
        .in('debt_id', ids).order('edited_at', { ascending: true });
      for (const v of vers || []) {
        const arr = versByDebt.get(v.debt_id) || [];
        arr.push({ amount: v.amount, due: v.due, note: v.note, edited_at: v.edited_at });
        versByDebt.set(v.debt_id, arr);
      }
    }

    const today = todayStr();
    const out = all.map((d) => {
      const base = { ...d, versions: versByDebt.get(d.id) || [] };
      if (d.kind === 'debt') {
        base.remaining = rem(d);
        base.remainingEff = remEff(d, all);
        base.isLockedByPending = isLockedByPending(d, all);
        base.isOverdue = isOverdue(d, today);
      }
      return base;
    });
    res.json({ success: true, data: out });
  } catch (e) { next(e); }
});

// ============================================================
// POST /api/debts/:partnerId — yangi qarz {direction, amount, currency, acted_at, due, note}
// ============================================================
router.post('/:partnerId', async (req, res, next) => {
  try {
    const p = await loadPartnerForUser(req.params.partnerId, req.user.id);
    if (!p) return res.status(404).json({ success: false, error: 'Hamkor topilmadi' });

    const { direction, amount, currency, acted_at, due, note } = req.body || {};
    if (!['toMe', 'fromMe'].includes(direction))
      return res.status(400).json({ success: false, error: "direction 'toMe' yoki 'fromMe' bo'lishi kerak" });
    const amtErr = validateAmount(amount);
    if (amtErr) return res.status(400).json({ success: false, error: amtErr });
    const cur = currency || 'UZS';
    if (!CURRENCIES.includes(cur))
      return res.status(400).json({ success: false, error: 'currency faqat UZS, USD, EUR yoki RUB bo\'lishi mumkin' });

    const today = todayStr();
    const act = acted_at || today;
    if (!isDate(act)) return res.status(400).json({ success: false, error: 'acted_at noto\'g\'ri sana' });
    if (act > today) return res.status(400).json({ success: false, error: 'amal sanasi kelajakda bo\'lmaydi' });
    let dueVal = null;
    if (due !== undefined && due !== null && due !== '') {
      if (!isDate(due)) return res.status(400).json({ success: false, error: 'due noto\'g\'ri sana' });
      if (due < today) return res.status(400).json({ success: false, error: 'muddat o\'tmishda bo\'lmaydi' });
      dueVal = due;
    }

    // Qarama-qarshi yo'nalish taqiqi — faqat FAOL qarzlar bo'yicha, EGA (owner) nuqtai nazarida.
    const newCanon = canonicalDir({ direction, created_by: req.user.id }, p.owner_id);
    const oppCanon = newCanon === 'toMe' ? 'fromMe' : 'toMe';
    const { data: actives } = await supabaseAdmin.from('debts')
      .select('id, direction, created_by')
      .eq('partner_id', p.id).eq('kind', 'debt').eq('status', 'active');
    if ((actives || []).some((d) => canonicalDir(d, p.owner_id) === oppCanon)) {
      return res.status(400).json({
        success: false,
        error: 'Bu hamkorda qarama-qarshi yo\'nalishda faol qarz bor — bir vaqtda ikkala yo\'nalishda qarz bo\'lmaydi. '
          + 'Avval mavjudini yoping (qaytarish yoki hisob-kitob).',
      });
    }

    const prov = provOf(p);
    const status = prov === 'oneSided' ? 'active' : 'pending'; // oneSided -> DARHOL active
    const { data, error } = await supabaseAdmin.from('debts').insert({
      partner_id: p.id, kind: 'debt', direction, created_by: req.user.id,
      amount: Number(amount), currency: cur, acted_at: act, due: dueVal,
      note: note || null, status, prov,
    }).select().single();
    if (error) throw new Error(error.message);

    if (prov === 'twoSided') {
      const name = await meName(req.user.id);
      await notify(otherParty(p, req.user.id), req.user.id, 'debt_new',
        `${name} yangi qarz kiritdi`, `Qarz yozuvi · ${fmt(amount)} ${cur} — tasdiqlaysizmi?`, p.id);
    }
    res.status(201).json({ success: true, data });
  } catch (e) { next(e); }
});

// ============================================================
// Holat o'tishlari — CAS (faqat kutilgan from-holatdan). Idempotent qayta bosishga bardosh.
// ============================================================

// POST /api/debts/:id/confirm — qarshi tomon pending qarzni tasdiqlaydi -> active
router.post('/:id/confirm', async (req, res, next) => {
  try {
    const ctx = await loadDebtWithPartner(req.params.id, req.user.id);
    if (!ctx) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { debt, partner } = ctx;
    if (debt.kind !== 'debt') return res.status(400).json({ success: false, error: 'Faqat qarz yozuvi tasdiqlanadi' });
    if (debt.status !== 'pending') return res.status(400).json({ success: false, error: 'Faqat tasdiqlanmagan qarz tasdiqlanadi' });
    if (debt.created_by === req.user.id) return res.status(403).json({ success: false, error: 'O\'z yozuvingizni tasdiqlay olmaysiz' });

    const { data, error } = await supabaseAdmin.from('debts')
      .update({ status: 'active', updated_at: nowIso() })
      .eq('id', debt.id).eq('status', 'pending').select().maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) return res.status(409).json({ success: false, error: 'Yozuv holati o\'zgargan' });

    const name = await meName(req.user.id);
    await notify(debt.created_by, req.user.id, 'debt_confirm', `${name} qarzni tasdiqladi`,
      `${fmt(debt.amount)} ${debt.currency} — faollashdi`, partner.id);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/debts/:id/reject — qarshi tomon pending qarzni rad etadi -> rejected
router.post('/:id/reject', async (req, res, next) => {
  try {
    const ctx = await loadDebtWithPartner(req.params.id, req.user.id);
    if (!ctx) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { debt, partner } = ctx;
    if (debt.kind !== 'debt') return res.status(400).json({ success: false, error: 'Faqat qarz yozuvi rad etiladi' });
    if (debt.status !== 'pending') return res.status(400).json({ success: false, error: 'Faqat tasdiqlanmagan qarz rad etiladi' });
    if (debt.created_by === req.user.id) return res.status(403).json({ success: false, error: 'O\'z yozuvingizni rad eta olmaysiz' });

    const { data, error } = await supabaseAdmin.from('debts')
      .update({ status: 'rejected', updated_at: nowIso() })
      .eq('id', debt.id).eq('status', 'pending').select().maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) return res.status(409).json({ success: false, error: 'Yozuv holati o\'zgargan' });

    const name = await meName(req.user.id);
    await notify(debt.created_by, req.user.id, 'debt_reject', `${name} qarzni rad etdi`,
      `${fmt(debt.amount)} ${debt.currency}`, partner.id);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/debts/:id/cancel — muallif o'z pending (yoki disputed) yozuvini bekor qiladi -> cancelled
router.post('/:id/cancel', async (req, res, next) => {
  try {
    const ctx = await loadDebtWithPartner(req.params.id, req.user.id);
    if (!ctx) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { debt } = ctx;
    if (debt.created_by !== req.user.id) return res.status(403).json({ success: false, error: 'Faqat yozuv muallifi bekor qiladi' });
    if (!['pending', 'disputed'].includes(debt.status))
      return res.status(400).json({ success: false, error: 'Faqat tasdiqlanmagan yoki bahsli yozuv bekor qilinadi' });

    const { data, error } = await supabaseAdmin.from('debts')
      .update({ status: 'cancelled', updated_at: nowIso() })
      .eq('id', debt.id).in('status', ['pending', 'disputed']).select().maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) return res.status(409).json({ success: false, error: 'Yozuv holati o\'zgargan' });
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// ============================================================
// repay / settle — qaytarish va hisob-kitob (pending; oneSided bo'lsa darhol ok + qo'llash)
// ============================================================
async function createRepaySettle(req, res, next, kind) {
  const p = await loadPartnerForUser(req.params.partnerId, req.user.id);
  if (!p) return res.status(404).json({ success: false, error: 'Hamkor topilmadi' });

  const { ref_id, amount, note } = req.body || {};
  const amtErr = validateAmount(amount);
  if (amtErr) return res.status(400).json({ success: false, error: amtErr });

  let reason = null;
  if (kind === 'settle') {
    reason = req.body?.reason || 'returned';
    if (!['returned', 'forgiven'].includes(reason))
      return res.status(400).json({ success: false, error: "reason 'returned' yoki 'forgiven' bo'lishi kerak" });
  }

  const { data: ref } = await supabaseAdmin.from('debts').select('*').eq('id', ref_id).maybeSingle();
  if (!ref || ref.partner_id !== p.id || ref.kind !== 'debt')
    return res.status(404).json({ success: false, error: 'Qarz topilmadi' });
  if (ref.status !== 'active')
    return res.status(400).json({ success: false, error: 'Faqat faol qarz bo\'yicha amal bajariladi' });

  // Band tekshiruvi: shu qarzda boshqa pending amal (repay/settle/edit) bo'lmasin
  const children = await childrenOf(ref.id);
  if (isLockedByPending(ref, children))
    return res.status(409).json({ success: false, error: 'Bu qarzda tasdiqlanmagan amal bor — avval uni yakunlang' });

  const remaining = remEff(ref, children);
  if (Number(amount) > remaining)
    return res.status(400).json({ success: false, error: `Summa qoldiqdan oshmasligi kerak (qoldiq: ${fmt(remaining)} ${ref.currency})` });

  const prov = provOf(p);
  const baseRow = {
    partner_id: p.id, kind, created_by: req.user.id, amount: Number(amount),
    currency: ref.currency, acted_at: todayStr(), note: note || null,
    reason: kind === 'settle' ? reason : null, ref_id: ref.id, prov,
  };

  if (prov === 'oneSided') {
    // DARHOL ok + qarzga qo'llash. Yozuv oldin (dalil), keyin qarz yangilanadi.
    const applied = applyRepaySettle(ref, { kind, amount: Number(amount), reason });
    const { data: rec, error } = await supabaseAdmin.from('debts')
      .insert({ ...baseRow, status: 'ok' }).select().single();
    if (error) throw new Error(error.message);
    const { error: uerr } = await supabaseAdmin.from('debts').update({
      paid: applied.paid, forgiven: applied.forgiven, status: applied.status,
      reason: applied.reason, updated_at: nowIso(),
    }).eq('id', ref.id);
    if (uerr) throw new Error(uerr.message);
    return res.status(201).json({ success: true, data: rec });
  }

  // twoSided: pending yaratamiz, qarshi tomonga xabar
  const { data: rec, error } = await supabaseAdmin.from('debts')
    .insert({ ...baseRow, status: 'pending' }).select().single();
  if (error) throw new Error(error.message);
  const name = await meName(req.user.id);
  await notify(otherParty(p, req.user.id), req.user.id, kind === 'repay' ? 'repay_new' : 'settle_new',
    `${name} ${kind === 'repay' ? 'qaytarish' : 'hisob-kitob'} kiritdi`,
    `${fmt(amount)} ${ref.currency} — tasdiqlaysizmi?`, p.id);
  res.status(201).json({ success: true, data: rec });
}
router.post('/:partnerId/repay', (req, res, next) => createRepaySettle(req, res, next, 'repay').catch(next));
router.post('/:partnerId/settle', (req, res, next) => createRepaySettle(req, res, next, 'settle').catch(next));

// POST /api/debts/:id/confirm-op — repay/settle pendingni tasdiqlash -> ok + ref qarzga qo'llash
router.post('/:id/confirm-op', async (req, res, next) => {
  try {
    const ctx = await loadDebtWithPartner(req.params.id, req.user.id);
    if (!ctx) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { debt: op, partner } = ctx;
    if (!['repay', 'settle'].includes(op.kind))
      return res.status(400).json({ success: false, error: 'Bu yozuv qaytarish/hisob-kitob emas' });
    if (op.status !== 'pending') return res.status(400).json({ success: false, error: 'Faqat tasdiqlanmagan amal tasdiqlanadi' });
    if (op.created_by === req.user.id) return res.status(403).json({ success: false, error: 'O\'z amalingizni tasdiqlay olmaysiz' });

    const { data: ref } = await supabaseAdmin.from('debts').select('*').eq('id', op.ref_id).maybeSingle();
    if (!ref) return res.status(404).json({ success: false, error: 'Bog\'liq qarz topilmadi' });

    // CAS: amalni ok qilamiz (qayta qo'llanishning oldini oladi). Faqat pending'dan.
    const { data: okRow, error: e1 } = await supabaseAdmin.from('debts')
      .update({ status: 'ok', updated_at: nowIso() })
      .eq('id', op.id).eq('status', 'pending').select().maybeSingle();
    if (e1) throw new Error(e1.message);
    if (!okRow) return res.status(409).json({ success: false, error: 'Amal allaqachon qayta ishlangan' });

    // Endi ref qarzga qo'llaymiz (op ok bo'lgani uchun ikki marta qo'llanmaydi).
    const applied = applyRepaySettle(ref, { kind: op.kind, amount: Number(op.amount), reason: op.reason });
    const { error: e2 } = await supabaseAdmin.from('debts').update({
      paid: applied.paid, forgiven: applied.forgiven, status: applied.status,
      reason: applied.reason, updated_at: nowIso(),
    }).eq('id', ref.id);
    if (e2) throw new Error(e2.message);

    const name = await meName(req.user.id);
    await notify(op.created_by, req.user.id, 'debt_confirm', `${name} amalni tasdiqladi`,
      `${fmt(op.amount)} ${ref.currency} — qarzga qo'llandi`, partner.id);
    res.json({ success: true, data: okRow });
  } catch (e) { next(e); }
});

// ============================================================
// PATCH /api/debts/:id — tahrir (faqat o'z debt yozuvi, pending/active)
//   pending yoki oneSided: to'g'ridan-to'g'ri + versions'ga eski
//   active twoSided: pending_edit qatlamiga (qarshi tomonga edit_req)
// ============================================================
router.patch('/:id', async (req, res, next) => {
  try {
    const ctx = await loadDebtWithPartner(req.params.id, req.user.id);
    if (!ctx) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { debt, partner } = ctx;
    if (debt.kind !== 'debt') return res.status(400).json({ success: false, error: 'Faqat qarz yozuvi tahrirlanadi' });
    if (debt.created_by !== req.user.id) return res.status(403).json({ success: false, error: 'Faqat yozuv muallifi tahrirlaydi' });
    if (!['pending', 'active'].includes(debt.status))
      return res.status(400).json({ success: false, error: 'Bu holatdagi yozuv tahrirlanmaydi' });

    // O'zgarishlarni yig'ish (faqat berilgan va haqiqatan farqli maydonlar)
    const today = todayStr();
    const changes = {};
    if (req.body?.amount !== undefined) {
      const amtErr = validateAmount(req.body.amount);
      if (amtErr) return res.status(400).json({ success: false, error: amtErr });
      if (Number(req.body.amount) !== Number(debt.amount)) changes.amount = Number(req.body.amount);
    }
    if (req.body?.due !== undefined) {
      let dueVal = null;
      if (req.body.due !== null && req.body.due !== '') {
        if (!isDate(req.body.due)) return res.status(400).json({ success: false, error: 'due noto\'g\'ri sana' });
        if (req.body.due < today) return res.status(400).json({ success: false, error: 'muddat o\'tmishda bo\'lmaydi' });
        dueVal = req.body.due;
      }
      if (dueVal !== (debt.due || null)) changes.due = dueVal;
    }
    if (req.body?.note !== undefined) {
      const noteVal = req.body.note || null;
      if (noteVal !== (debt.note || null)) changes.note = noteVal;
    }
    if (!Object.keys(changes).length) return res.status(400).json({ success: false, error: 'O\'zgarish kiritilmadi' });

    // Band tekshiruvi (pending repay/settle yoki mavjud pending_edit)
    const children = await childrenOf(debt.id);
    if (isLockedByPending(debt, children))
      return res.status(409).json({ success: false, error: 'Bu qarzda tasdiqlanmagan amal bor — avval uni yakunlang' });

    const direct = debt.status === 'pending' || debt.prov === 'oneSided';
    if (direct) {
      // Eski qiymat versions'ga
      await supabaseAdmin.from('debt_versions').insert({
        debt_id: debt.id, amount: debt.amount, due: debt.due, note: debt.note,
      });
      const patch = { updated_at: nowIso() };
      if ('amount' in changes) {
        patch.amount = changes.amount;
        patch.paid = Math.min(Number(debt.paid || 0), changes.amount); // paid <= amount
      }
      if ('due' in changes) patch.due = changes.due;
      if ('note' in changes) patch.note = changes.note;
      // Kamaytirish paid'ni yopib qo'ysa — qarz yopiladi
      const newAmount = patch.amount ?? Number(debt.amount);
      const newPaid = patch.paid ?? Number(debt.paid || 0);
      if (debt.status === 'active' && newPaid >= newAmount) {
        patch.status = 'closed';
        patch.reason = debt.reason || 'returned';
      }
      const { data, error } = await supabaseAdmin.from('debts').update(patch).eq('id', debt.id).select().single();
      if (error) throw new Error(error.message);
      return res.json({ success: true, data });
    }

    // active twoSided -> pending_edit (qarz eski qiymatlari bilan faol qoladi)
    const pe = { requested_at: nowIso() };
    if ('amount' in changes) pe.amount = changes.amount;
    if ('due' in changes) pe.due = changes.due;
    if ('note' in changes) pe.note = changes.note;
    const { data, error } = await supabaseAdmin.from('debts')
      .update({ pending_edit: pe, updated_at: nowIso() }).eq('id', debt.id).select().single();
    if (error) throw new Error(error.message);
    const name = await meName(req.user.id);
    await notify(otherParty(partner, req.user.id), req.user.id, 'edit_req', `${name} tahrir so'radi`,
      `${fmt(debt.amount)} ${debt.currency} yozuviga o'zgartirish — tasdiqlaysizmi?`, partner.id);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/debts/:id/edit-confirm — qarshi tomon pending_edit'ni tasdiqlaydi -> yangi qiymat qo'llanadi
router.post('/:id/edit-confirm', async (req, res, next) => {
  try {
    const ctx = await loadDebtWithPartner(req.params.id, req.user.id);
    if (!ctx) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { debt, partner } = ctx;
    if (!debt.pending_edit) return res.status(400).json({ success: false, error: 'Tasdiqlanadigan tahrir yo\'q' });
    if (debt.created_by === req.user.id) return res.status(403).json({ success: false, error: 'O\'z tahrringizni tasdiqlay olmaysiz' });

    const pe = debt.pending_edit;
    // Eski qiymat versions'ga
    await supabaseAdmin.from('debt_versions').insert({
      debt_id: debt.id, amount: debt.amount, due: debt.due, note: debt.note,
    });
    const patch = { pending_edit: null, updated_at: nowIso() };
    if (pe.amount !== undefined) {
      patch.amount = Number(pe.amount);
      patch.paid = Math.min(Number(debt.paid || 0), Number(pe.amount)); // paid <= yangiAmount
    }
    if (pe.due !== undefined) patch.due = pe.due;
    if (pe.note !== undefined) patch.note = pe.note;
    const newAmount = patch.amount ?? Number(debt.amount);
    const newPaid = patch.paid ?? Number(debt.paid || 0);
    if (newPaid >= newAmount) { patch.status = 'closed'; patch.reason = debt.reason || 'returned'; }

    const { data, error } = await supabaseAdmin.from('debts').update(patch)
      .eq('id', debt.id).not('pending_edit', 'is', null).select().maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) return res.status(409).json({ success: false, error: 'Tahrir holati o\'zgargan' });

    const name = await meName(req.user.id);
    await notify(debt.created_by, req.user.id, 'debt_confirm', `${name} tahrirni tasdiqladi`,
      `Yangi qiymat qo'llandi`, partner.id);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/debts/:id/edit-reject — pending_edit'ni rad etadi (qarz eski holida qoladi)
router.post('/:id/edit-reject', async (req, res, next) => {
  try {
    const ctx = await loadDebtWithPartner(req.params.id, req.user.id);
    if (!ctx) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { debt, partner } = ctx;
    if (!debt.pending_edit) return res.status(400).json({ success: false, error: 'Rad etiladigan tahrir yo\'q' });
    if (debt.created_by === req.user.id) return res.status(403).json({ success: false, error: 'O\'z tahrringizni rad eta olmaysiz' });

    const { data, error } = await supabaseAdmin.from('debts')
      .update({ pending_edit: null, updated_at: nowIso() })
      .eq('id', debt.id).not('pending_edit', 'is', null).select().maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) return res.status(409).json({ success: false, error: 'Tahrir holati o\'zgargan' });

    const name = await meName(req.user.id);
    await notify(debt.created_by, req.user.id, 'debt_reject', `${name} tahrirni rad etdi`,
      `${fmt(debt.amount)} ${debt.currency} — eski holida qoldi`, partner.id);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// ============================================================
// JOIN ko'rib chiqish (under_review) — oneSided yozuvni twoSided qilish yoki disputed
// ============================================================

// POST /api/debts/:partnerId/review-confirm { debt_id } — qarz + bog'liq yozuvlar twoSided, under_review=false
router.post('/:partnerId/review-confirm', async (req, res, next) => {
  try {
    const p = await loadPartnerForUser(req.params.partnerId, req.user.id);
    if (!p) return res.status(404).json({ success: false, error: 'Hamkor topilmadi' });
    const { debt_id } = req.body || {};
    const { data: d } = await supabaseAdmin.from('debts').select('*').eq('id', debt_id).maybeSingle();
    if (!d || d.partner_id !== p.id) return res.status(404).json({ success: false, error: 'Qarz topilmadi' });
    if (!d.under_review) return res.status(400).json({ success: false, error: 'Bu yozuv ko\'rib chiqishda emas' });
    if (d.created_by === req.user.id) return res.status(403).json({ success: false, error: 'O\'z yozuvingizni ko\'rib chiqa olmaysiz' });

    const { data, error } = await supabaseAdmin.from('debts')
      .update({ prov: 'twoSided', under_review: false, updated_at: nowIso() })
      .eq('id', d.id).eq('under_review', true).select().maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) return res.status(409).json({ success: false, error: 'Yozuv holati o\'zgargan' });
    // Bog'liq (ref_id) repay/settle yozuvlarini ham twoSided qilamiz
    await supabaseAdmin.from('debts')
      .update({ prov: 'twoSided', under_review: false, updated_at: nowIso() })
      .eq('ref_id', d.id);

    const name = await meName(req.user.id);
    await notify(d.created_by, req.user.id, 'debt_confirm', `${name} yozuvni tasdiqladi`,
      `${fmt(d.amount)} ${d.currency} — ikki tomonlama bo'ldi`, p.id);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/debts/:id/review-reject — under_review yozuvni rad etadi -> disputed (balansdan chiqadi)
router.post('/:id/review-reject', async (req, res, next) => {
  try {
    const ctx = await loadDebtWithPartner(req.params.id, req.user.id);
    if (!ctx) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { debt, partner } = ctx;
    if (!debt.under_review) return res.status(400).json({ success: false, error: 'Bu yozuv ko\'rib chiqishda emas' });
    if (debt.created_by === req.user.id) return res.status(403).json({ success: false, error: 'O\'z yozuvingizni rad eta olmaysiz' });

    const { data, error } = await supabaseAdmin.from('debts')
      .update({ status: 'disputed', under_review: false, updated_at: nowIso() })
      .eq('id', debt.id).eq('under_review', true).select().maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) return res.status(409).json({ success: false, error: 'Yozuv holati o\'zgargan' });

    const name = await meName(req.user.id);
    await notify(debt.created_by, req.user.id, 'debt_reject', `${name} yozuvni rad etdi`,
      `${fmt(debt.amount)} ${debt.currency} — bahsli (balansdan chiqdi)`, partner.id);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

export default router;

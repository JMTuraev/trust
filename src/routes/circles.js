// Circles (guruhli navbatli jamg'arma / ROSCA) — server-avtoritar.
// Huquq KODDA tekshiriladi (service_role RLS chetlab o'tadi). Ikki tomonlama to'lov:
// a'zo 'to'ladim' (pay) -> oluvchi 'oldim' (confirm) -> round yopiladi. Soxta "hamma to'ladi" YO'Q.
// Yopish semantikasi: dalil (done round) bor bo'lsa SOFT-close (status='closed'),
// aks holda hard delete — tasdiqlangan to'lov dalillari hech qachon o'chirilmaydi.
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { requireActiveSub } from '../lib/subscription.js';
import { displayName, notifEnabled } from '../lib/links.js';

const router = Router();
router.use(requireAuth);

// Obuna siyosati (mahsulot qarori, 2026-07-16): muddati tugagan foydalanuvchi READ-ONLY.
// requireActiveSub (402 SUB_EXPIRED) faqat YANGI qiymat yaratadigan endpointlarda:
//   POST /            (doira yaratish)
//   POST /join/:token (kod orqali qo'shilish = yangi a'zolik yaratish)
//   POST /:id/invite  (yangi a'zo/round yaratish)
//   POST /:id/pay     (to'lov boshlash)
// ATAYLAB qo'yilmaydi: barcha GET'lar, confirm/accept/decline/remind, PATCH, DELETE —
// muddati tugagan foydalanuvchining QARSHI TOMONI hech qachon qotib qolmasin
// (masalan, taklifga javob berish yoki qabulni tasdiqlash ochiq qoladi).

const CURRENCIES = ['UZS', 'USD', 'EUR', 'RUB', 'GBP', 'KZT'];
const FREQ = ['monthly', 'custom'];
const ORDER = ['inTurn', 'random', 'iPick'];
const MAX_MEMBERS = 24;
const normPhone = (s) => String(s || '').replace(/\D/g, '');
const clip = (s, n) => String(s || '').trim().slice(0, n);

function validAmount(a) {
  const n = Number(a);
  return Number.isInteger(n) && n > 0 && n <= Number.MAX_SAFE_INTEGER;
}

async function notify(userId, senderId, type, title, detail, circleId) {
  if (!userId || userId === senderId) return;
  if (!(await notifEnabled(userId))) return;
  // Insert xatosi (masalan, type constraint hali yangilanmagan) so'rovni yiqitmasin
  await supabaseAdmin.from('notifications').insert({
    user_id: userId, sender_id: senderId, type, title, detail, circle_id: circleId,
  });
}

async function meName(userId) {
  const { data } = await supabaseAdmin.from('profiles').select('full_name, phone').eq('id', userId).maybeSingle();
  return displayName(data);
}

// Circle + a'zolar + roundlar + to'lovlarni bitta funksiyada yuklaydi.
async function loadFull(circleId) {
  const { data: circle } = await supabaseAdmin.from('circles').select('*').eq('id', circleId).maybeSingle();
  if (!circle) return null;
  const [{ data: members }, { data: rounds }] = await Promise.all([
    supabaseAdmin.from('circle_members').select('*').eq('circle_id', circleId).order('payout_position'),
    supabaseAdmin.from('circle_rounds').select('*').eq('circle_id', circleId).order('idx'),
  ]);
  const roundIds = (rounds || []).map((r) => r.id);
  let payments = [];
  if (roundIds.length) {
    const { data: pays } = await supabaseAdmin.from('circle_payments').select('*').in('round_id', roundIds);
    payments = pays || [];
  }
  return { circle, members: members || [], rounds: rounds || [], payments };
}

// Foydalanuvchi shu circle a'zosimi? (active user_id yoki telefon bo'yicha invited)
function memberOf(full, userId, phone) {
  return full.members.find(
    (m) => (m.user_id && m.user_id === userId) || (m.status === 'invited' && m.invited_phone && m.invited_phone === phone)
  ) || null;
}

// Rad etmagan (hisobga kiradigan) a'zolar
const countedMembers = (full) => full.members.filter((m) => m.status !== 'declined');

// Klient modeliga mos JSON. tint/initials klient tomonda hosil qilinadi.
function mapCircle(full, meId, mePhone) {
  const { circle, members, rounds, payments } = full;
  const payByRound = new Map();
  for (const p of payments) {
    const arr = payByRound.get(p.round_id) || [];
    if (p.status === 'paid' || p.status === 'confirmed') arr.push(p.member_id);
    payByRound.set(p.round_id, arr);
  }
  const meMember = memberOf(full, meId, mePhone);
  return {
    id: circle.id,
    name: circle.name,
    amount: circle.amount,
    currency: circle.currency,
    frequency: circle.frequency,
    payout_order: circle.payout_order,
    status: circle.status,
    current_round: circle.current_round,
    period: circle.period || '',
    created_at: circle.created_at,
    join_token: circle.owner_id === meId ? circle.join_token : null,
    is_owner: circle.owner_id === meId,
    my_status: meMember ? meMember.status : null,
    my_member_id: meMember ? meMember.id : null,
    members: members.map((m) => ({
      id: m.id,
      name: m.display_name,
      payout_position: m.payout_position,
      is_admin: m.is_admin,
      // is_you: haqiqiy a'zo (user_id) YOKI telefon bo'yicha taklif qilingan (hali qabul qilmagan) men
      is_you: !!(m.user_id && m.user_id === meId) ||
        (m.status === 'invited' && !!m.invited_phone && m.invited_phone === mePhone),
      status: m.status,
      on_app: !!m.user_id,
    })),
    rounds: rounds.map((r) => ({
      idx: r.idx,
      recipient_id: r.recipient_member_id,
      due_date: r.due_date || '',
      status: r.status,
      receipt_confirmed: r.receipt_confirmed,
      paid_ids: payByRound.get(r.id) || [],
    })),
  };
}

// Joriy round yozuvi
const currentRoundRow = (full) => full.rounds.find((r) => r.idx === full.circle.current_round) || null;

// Round uchun har a'zoga pending to'lov yozuvi yaratadi (yo'q bo'lsa).
// Oluvchining o'zi to'lamaydi; rad etganlar hisobga olinmaydi.
async function ensurePendingPayments(circle, round, members) {
  const { data: existing } = await supabaseAdmin.from('circle_payments').select('member_id').eq('round_id', round.id);
  const have = new Set((existing || []).map((x) => x.member_id));
  const rows = members
    .filter((m) => !have.has(m.id) && m.id !== round.recipient_member_id && m.status !== 'declined')
    .map((m) => ({ round_id: round.id, member_id: m.id, amount: circle.amount, status: 'pending' }));
  if (rows.length) await supabaseAdmin.from('circle_payments').insert(rows);
}

// ============================================================
// GET /api/circles — men a'zo (yoki telefon bo'yicha taklif qilingan) circle'lar
// ============================================================
router.get('/', async (req, res, next) => {
  try {
    const meId = req.user.id;
    const mePhone = normPhone(req.user.phone);
    // Mening a'zoliklarim: user_id=me YOKI invited_phone=mePhone
    const { data: mine } = await supabaseAdmin
      .from('circle_members')
      .select('circle_id')
      .or(`user_id.eq.${meId}${mePhone ? `,invited_phone.eq.${mePhone}` : ''}`);
    const ids = [...new Set((mine || []).map((m) => m.circle_id))];
    if (!ids.length) return res.json({ success: true, data: [] });
    const fulls = await Promise.all(ids.map((id) => loadFull(id)));
    // Rad etilgan (declined) a'zolik — endi a'zo emas: ro'yxatga KIRMAYDI (ma'lumot sizmasin)
    const out = fulls
      .filter((f) => f && memberOf(f, meId, mePhone))
      .map((f) => mapCircle(f, meId, mePhone));
    // Faol birinchi, so'ng yangi -> eski
    out.sort((a, b) =>
      ((a.status !== 'active' ? 1 : 0) - (b.status !== 'active' ? 1 : 0)) ||
      String(b.created_at || '').localeCompare(String(a.created_at || '')));
    res.json({ success: true, data: out });
  } catch (e) { next(e); }
});

// ============================================================
// POST /api/circles — yangi circle. body:
//   { name, amount, currency, frequency, payout_order, period?,
//     members: [{ name, phone?, payout_position, is_you? }], due_dates?: [str] }
// ============================================================
router.post('/', requireActiveSub, async (req, res, next) => {
  try {
    const meId = req.user.id;
    const mePhone = normPhone(req.user.phone);
    const b = req.body || {};
    const name = clip(b.name, 60) || 'New Circle';
    if (!validAmount(b.amount)) return res.status(400).json({ success: false, error: "amount musbat butun bo'lsin" });
    const currency = CURRENCIES.includes(b.currency) ? b.currency : 'UZS';
    const frequency = FREQ.includes(b.frequency) ? b.frequency : 'monthly';
    const payout_order = ORDER.includes(b.payout_order) ? b.payout_order : 'inTurn';
    const members = Array.isArray(b.members) ? b.members : [];
    if (members.length < 2 || members.length > MAX_MEMBERS)
      return res.status(400).json({ success: false, error: `A'zolar 2..${MAX_MEMBERS} orasida bo'lsin` });
    // payout_position 1..N to'liq permutatsiya bo'lishi kerak
    const positions = members.map((m) => Number(m.payout_position));
    const want = new Set(Array.from({ length: members.length }, (_, i) => i + 1));
    if (positions.some((p) => !want.has(p)) || new Set(positions).size !== members.length)
      return res.status(400).json({ success: false, error: 'payout_position 1..N to\'liq bo\'lsin' });
    // Telefonlar: dublikat va o'z raqami taqiqlanadi
    const phones = members.map((m) => normPhone(m.phone)).filter(Boolean);
    if (new Set(phones).size !== phones.length)
      return res.status(400).json({ success: false, error: 'Bir xil raqam ikki marta kiritilgan' });
    if (mePhone && phones.includes(mePhone))
      return res.status(400).json({ success: false, error: "O'z raqamingizni a'zo sifatida kiritmang — siz allaqachon a'zosiz" });

    // Circle
    const { data: circle, error: ce } = await supabaseAdmin.from('circles').insert({
      owner_id: meId, name, amount: Number(b.amount), currency, frequency, payout_order,
      status: 'active', current_round: 1, period: b.period ? clip(b.period, 40) : null,
    }).select().single();
    if (ce) throw new Error(ce.message);

    // A'zolar. is_you -> user_id=me; phone -> invited; aks holda nomli (app'da emas).
    let sawYou = false;
    const memberRows = members.map((m, i) => {
      const isYou = m.is_you === true && !sawYou;
      if (isYou) sawYou = true;
      const phone = normPhone(m.phone);
      return {
        circle_id: circle.id,
        user_id: isYou ? meId : null,
        invited_phone: !isYou && phone ? phone : null,
        display_name: clip(m.name, 60) || (isYou ? 'You' : `Member ${i + 1}`),
        payout_position: Number(m.payout_position),
        is_admin: isYou,
        status: isYou ? 'active' : (phone ? 'invited' : 'active'),
      };
    });
    // Agar hech kim is_you bo'lmasa — birinchi 1-pozitsiyani me qilamiz
    if (!sawYou) {
      const first = memberRows.find((r) => r.payout_position === 1) || memberRows[0];
      first.user_id = meId; first.is_admin = true; first.status = 'active'; first.invited_phone = null;
      first.display_name = first.display_name || 'You';
    }
    const { data: insMembers, error: me2 } = await supabaseAdmin.from('circle_members').insert(memberRows).select();
    if (me2) throw new Error(me2.message);
    const byPos = new Map(insMembers.map((m) => [m.payout_position, m]));

    // Roundlar: recipient = payout_position == idx; 1 = current, qolgani upcoming.
    const due = Array.isArray(b.due_dates) ? b.due_dates : [];
    const roundRows = insMembers.map((_, i) => {
      const idx = i + 1;
      return {
        circle_id: circle.id,
        idx,
        recipient_member_id: byPos.get(idx).id,
        due_date: due[idx - 1] ? clip(due[idx - 1], 24) : null,
        status: idx === 1 ? 'current' : 'upcoming',
      };
    });
    const { data: insRounds } = await supabaseAdmin.from('circle_rounds').insert(roundRows).select();

    // 1-round uchun pending to'lovlar (oluvchidan tashqari)
    const round1 = (insRounds || []).find((r) => r.idx === 1);
    if (round1) await ensurePendingPayments(circle, round1, insMembers);

    // Taklif qilingan (invited) a'zolarga bildirishnoma
    const meNm = await meName(meId);
    for (const m of insMembers.filter((x) => x.status === 'invited' && x.invited_phone)) {
      const { data: u } = await supabaseAdmin.from('profiles').select('id').eq('phone', m.invited_phone).maybeSingle();
      if (u?.id) await notify(u.id, meId, 'circle_invite', `${meNm} sizni "${name}" doirasiga taklif qildi`, "Taklifni ko'rish uchun bosing", circle.id);
    }

    const full = await loadFull(circle.id);
    res.status(201).json({ success: true, data: mapCircle(full, meId, mePhone) });
  } catch (e) { next(e); }
});

// ============================================================
// GET /api/circles/join/:token — taklif havolasi PREVIEW (a'zolik shart emas).
// Minimal ma'lumot: circle ichki holati (to'lovlar, a'zo ro'yxati) sizib chiqmaydi.
// ============================================================
router.get('/join/:token', async (req, res, next) => {
  try {
    const token = clip(req.params.token, 64);
    if (!token) return res.status(400).json({ success: false, error: 'Token kerak' });
    const { data: circle } = await supabaseAdmin.from('circles').select('*').eq('join_token', token).maybeSingle();
    if (!circle) return res.status(404).json({ success: false, error: 'Taklif topilmadi' });
    const full = await loadFull(circle.id);
    const mePhone = normPhone(req.user.phone);
    const meMember = memberOf(full, req.user.id, mePhone);
    const counted = countedMembers(full);
    const { data: ownerProf } = await supabaseAdmin.from('profiles').select('full_name, phone').eq('id', circle.owner_id).maybeSingle();
    res.json({
      success: true,
      data: {
        id: circle.id,
        name: circle.name,
        amount: circle.amount,
        currency: circle.currency,
        frequency: circle.frequency,
        status: circle.status,
        members_count: counted.length,
        rounds_total: full.rounds.length,
        owner_name: displayName(ownerProf),
        next_position: full.rounds.length + 1,
        already_member: !!meMember && meMember.status === 'active',
        invited: meMember?.status === 'invited',
      },
    });
  } catch (e) { next(e); }
});

// ============================================================
// POST /api/circles/join/:token — havola orqali qo'shilish.
// Telefon bo'yicha taklif bo'lsa — o'sha o'rin faollashadi; aks holda oxiriga qo'shiladi.
// ============================================================
router.post('/join/:token', requireActiveSub, async (req, res, next) => {
  try {
    const token = clip(req.params.token, 64);
    if (!token) return res.status(400).json({ success: false, error: 'Token kerak' });
    const { data: circle } = await supabaseAdmin.from('circles').select('*').eq('join_token', token).maybeSingle();
    if (!circle) return res.status(404).json({ success: false, error: 'Taklif topilmadi' });
    if (circle.status !== 'active') return res.status(400).json({ success: false, error: 'Doira yakunlangan' });
    const meId = req.user.id;
    const mePhone = normPhone(req.user.phone);
    const full = await loadFull(circle.id);
    const meMember = memberOf(full, meId, mePhone);

    if (meMember && meMember.user_id === meId && meMember.status === 'active') {
      // Allaqachon a'zo — idempotent
      return res.json({ success: true, data: mapCircle(full, meId, mePhone) });
    }
    if (meMember && meMember.status === 'invited') {
      // Telefon bo'yicha taklif bor — o'sha o'rinni faollashtiramiz (accept bilan bir xil)
      await supabaseAdmin.from('circle_members')
        .update({ user_id: meId, status: 'active', joined_at: new Date().toISOString() }).eq('id', meMember.id);
    } else {
      if (countedMembers(full).length >= MAX_MEMBERS)
        return res.status(400).json({ success: false, error: "Doira to'lgan" });
      const maxPos = full.members.reduce((s, m) => Math.max(s, m.payout_position), 0);
      const maxIdx = full.rounds.reduce((s, r) => Math.max(s, r.idx), 0);
      const { data: nm, error: em } = await supabaseAdmin.from('circle_members').insert({
        circle_id: circle.id, user_id: meId, display_name: clip(await meName(meId), 60) || 'Member',
        payout_position: maxPos + 1, status: 'active',
      }).select().single();
      if (em) throw new Error(em.message);
      await supabaseAdmin.from('circle_rounds').insert({
        circle_id: circle.id, idx: maxIdx + 1, recipient_member_id: nm.id, status: 'upcoming',
      });
    }
    const meNm = await meName(meId);
    await notify(circle.owner_id, meId, 'circle_joined', `${meNm} "${circle.name}" doirasiga qo'shildi`, '', circle.id);
    const fresh = await loadFull(circle.id);
    res.json({ success: true, data: mapCircle(fresh, meId, mePhone) });
  } catch (e) { next(e); }
});

// ============================================================
// GET /api/circles/:id — detal (a'zo bo'lish shart)
// ============================================================
router.get('/:id', async (req, res, next) => {
  try {
    const full = await loadFull(req.params.id);
    if (!full) return res.status(404).json({ success: false, error: 'Doira topilmadi' });
    const mePhone = normPhone(req.user.phone);
    if (!memberOf(full, req.user.id, mePhone)) return res.status(403).json({ success: false, error: "Siz bu doira a'zosi emassiz" });
    res.json({ success: true, data: mapCircle(full, req.user.id, mePhone) });
  } catch (e) { next(e); }
});

// ============================================================
// POST /api/circles/:id/pay — joriy round uchun "to'ladim"
// ============================================================
router.post('/:id/pay', requireActiveSub, async (req, res, next) => {
  try {
    const full = await loadFull(req.params.id);
    if (!full) return res.status(404).json({ success: false, error: 'Doira topilmadi' });
    if (full.circle.status !== 'active') return res.status(400).json({ success: false, error: 'Doira yakunlangan' });
    const mePhone = normPhone(req.user.phone);
    const me = memberOf(full, req.user.id, mePhone);
    if (!me || me.status !== 'active') return res.status(403).json({ success: false, error: "Siz bu doira a'zosi emassiz" });
    const round = currentRoundRow(full);
    if (!round || round.status !== 'current') return res.status(400).json({ success: false, error: 'Joriy round topilmadi' });
    if (round.recipient_member_id === me.id) return res.status(400).json({ success: false, error: "Bu round sizniki — to'lov kutasiz" });

    // Tasdiqlangan (confirmed) to'lov ortga qaytmasin — dalil o'zgarmas
    const existing = full.payments.find((p) => p.round_id === round.id && p.member_id === me.id);
    if (existing?.status === 'confirmed')
      return res.status(400).json({ success: false, error: "To'lovingiz allaqachon tasdiqlangan" });

    await supabaseAdmin.from('circle_payments').upsert({
      round_id: round.id, member_id: me.id, amount: full.circle.amount, status: 'paid', paid_at: new Date().toISOString(),
    }, { onConflict: 'round_id,member_id' });

    // Oluvchiga bildirishnoma (faqat birinchi belgilashda — qayta bosishda spam yo'q)
    if (existing?.status !== 'paid') {
      const recip = full.members.find((m) => m.id === round.recipient_member_id);
      if (recip?.user_id) {
        const meNm = await meName(req.user.id);
        await notify(recip.user_id, req.user.id, 'circle_paid', `${meNm} "${full.circle.name}" uchun to'ladi`, `${full.circle.amount} ${full.circle.currency}`, full.circle.id);
      }
    }
    const fresh = await loadFull(req.params.id);
    res.json({ success: true, data: mapCircle(fresh, req.user.id, mePhone) });
  } catch (e) { next(e); }
});

// ============================================================
// POST /api/circles/:id/confirm — oluvchi "oldim" (round yopiladi, keyingisiga o'tadi)
//   FAQAT haqiqatan to'langan (paid) to'lovlar 'confirmed' bo'ladi — soxta emas.
// ============================================================
router.post('/:id/confirm', async (req, res, next) => {
  try {
    const full = await loadFull(req.params.id);
    if (!full) return res.status(404).json({ success: false, error: 'Doira topilmadi' });
    if (full.circle.status !== 'active') return res.status(400).json({ success: false, error: 'Doira yakunlangan' });
    const mePhone = normPhone(req.user.phone);
    const me = memberOf(full, req.user.id, mePhone);
    const round = currentRoundRow(full);
    if (!me || me.status !== 'active' || !round) return res.status(403).json({ success: false, error: 'Ruxsat yo\'q' });
    if (round.recipient_member_id !== me.id) return res.status(403).json({ success: false, error: 'Faqat shu round oluvchisi tasdiqlaydi' });

    // Atomik yopish: receipt_confirmed=false bo'lgandagina yopiladi (ikki marta bosish/poyga himoyasi)
    const { data: closedRows } = await supabaseAdmin.from('circle_rounds')
      .update({ status: 'done', receipt_confirmed: true })
      .eq('id', round.id).eq('receipt_confirmed', false).select();
    if (!closedRows || !closedRows.length)
      return res.status(400).json({ success: false, error: 'Allaqachon tasdiqlangan' });

    // Faqat 'paid' -> 'confirmed'
    await supabaseAdmin.from('circle_payments').update({ status: 'confirmed', confirmed_at: new Date().toISOString() })
      .eq('round_id', round.id).eq('status', 'paid');

    const total = full.rounds.length;
    let nextRound = null;
    if (round.idx < total) {
      const next = full.rounds.find((r) => r.idx === round.idx + 1);
      await supabaseAdmin.from('circles').update({ current_round: round.idx + 1, updated_at: new Date().toISOString() }).eq('id', full.circle.id);
      await supabaseAdmin.from('circle_rounds').update({ status: 'current' }).eq('id', next.id);
      // Keyingi round uchun pending to'lov yozuvlari (oluvchidan tashqari)
      await ensurePendingPayments(full.circle, next, full.members);
      nextRound = next;
    } else {
      await supabaseAdmin.from('circles').update({ status: 'complete', updated_at: new Date().toISOString() }).eq('id', full.circle.id);
    }

    // A'zolarga bildirishnoma (round yopildi) + keyingi round oluvchisiga navbat
    const meNm = await meName(req.user.id);
    for (const m of full.members) {
      if (m.user_id) await notify(m.user_id, req.user.id, 'circle_confirm', `${meNm} to'lovni tasdiqladi — round ${round.idx} yopildi`, full.circle.name, full.circle.id);
    }
    if (nextRound) {
      const nextRecip = full.members.find((m) => m.id === nextRound.recipient_member_id);
      if (nextRecip?.user_id) await notify(nextRecip.user_id, req.user.id, 'circle_turn', `Keyingi navbat sizniki — "${full.circle.name}"`, `${full.circle.amount * countedMembers(full).length} ${full.circle.currency}`, full.circle.id);
    }

    const fresh = await loadFull(req.params.id);
    res.json({ success: true, data: mapCircle(fresh, req.user.id, mePhone) });
  } catch (e) { next(e); }
});

// ============================================================
// POST /api/circles/:id/remind — to'lamaganlarga eslatma (oluvchi yoki egasi)
// ============================================================
router.post('/:id/remind', async (req, res, next) => {
  try {
    const full = await loadFull(req.params.id);
    if (!full) return res.status(404).json({ success: false, error: 'Doira topilmadi' });
    if (full.circle.status !== 'active') return res.status(400).json({ success: false, error: 'Doira yakunlangan' });
    const mePhone = normPhone(req.user.phone);
    const me = memberOf(full, req.user.id, mePhone);
    const round = currentRoundRow(full);
    if (!me || me.status !== 'active' || !round) return res.status(403).json({ success: false, error: 'Ruxsat yo\'q' });
    const isRecipient = round.recipient_member_id === me.id;
    if (!isRecipient && full.circle.owner_id !== req.user.id)
      return res.status(403).json({ success: false, error: 'Faqat oluvchi yoki egasi eslatadi' });

    const paidSet = new Set(full.payments
      .filter((p) => p.round_id === round.id && (p.status === 'paid' || p.status === 'confirmed'))
      .map((p) => p.member_id));
    const unpaid = full.members.filter((m) =>
      m.status === 'active' && m.user_id && m.id !== round.recipient_member_id && m.user_id !== req.user.id && !paidSet.has(m.id));
    for (const m of unpaid) {
      await notify(m.user_id, req.user.id, 'circle_due', `To'lov vaqti — "${full.circle.name}"`, `${full.circle.amount} ${full.circle.currency} · round ${round.idx}`, full.circle.id);
    }
    res.json({ success: true, data: { reminded: unpaid.length } });
  } catch (e) { next(e); }
});

// ============================================================
// POST /api/circles/:id/accept — telefon bo'yicha taklifni qabul qilish
// POST /api/circles/:id/decline
// ============================================================
router.post('/:id/accept', async (req, res, next) => {
  try {
    const full = await loadFull(req.params.id);
    if (!full) return res.status(404).json({ success: false, error: 'Doira topilmadi' });
    if (full.circle.status !== 'active') return res.status(400).json({ success: false, error: 'Doira yakunlangan' });
    const mePhone = normPhone(req.user.phone);
    const inv = full.members.find((m) => m.status === 'invited' && m.invited_phone === mePhone);
    if (!inv) return res.status(404).json({ success: false, error: 'Sizga taklif topilmadi' });
    await supabaseAdmin.from('circle_members').update({ user_id: req.user.id, status: 'active', joined_at: new Date().toISOString() }).eq('id', inv.id);
    const meNm = await meName(req.user.id);
    await notify(full.circle.owner_id, req.user.id, 'circle_joined', `${meNm} "${full.circle.name}" doirasiga qo'shildi`, '', full.circle.id);
    const fresh = await loadFull(req.params.id);
    res.json({ success: true, data: mapCircle(fresh, req.user.id, mePhone) });
  } catch (e) { next(e); }
});

// Rad etish: agar a'zoning round'i hali 'upcoming' bo'lsa — o'rindiq VA round olib tashlanib,
// keyingi pozitsiyalar siqiladi (aks holda navbat "arvoh" a'zoga yetib, doira qotib qolardi).
router.post('/:id/decline', async (req, res, next) => {
  try {
    const full = await loadFull(req.params.id);
    if (!full) return res.status(404).json({ success: false, error: 'Doira topilmadi' });
    const mePhone = normPhone(req.user.phone);
    const inv = full.members.find((m) => m.status === 'invited' && m.invited_phone === mePhone);
    if (inv) {
      const myRound = full.rounds.find((r) => r.recipient_member_id === inv.id);
      if (!myRound || myRound.status === 'upcoming') {
        // Xavfsiz: taklif qilingan a'zo hech narsa to'lamagan (pay 'active' talab qiladi)
        await supabaseAdmin.from('circle_members').delete().eq('id', inv.id); // cascade: pending payments
        if (myRound) {
          await supabaseAdmin.from('circle_rounds').delete().eq('id', myRound.id);
          // idx siqish — o'sish tartibida (unique(circle_id, idx) buzilmaydi)
          const rAfter = full.rounds.filter((r) => r.idx > myRound.idx).sort((a, b) => a.idx - b.idx);
          for (const r of rAfter) await supabaseAdmin.from('circle_rounds').update({ idx: r.idx - 1 }).eq('id', r.id);
        }
        // payout_position siqish — o'sish tartibida
        const mAfter = full.members.filter((m) => m.payout_position > inv.payout_position).sort((a, b) => a.payout_position - b.payout_position);
        for (const m of mAfter) await supabaseAdmin.from('circle_members').update({ payout_position: m.payout_position - 1 }).eq('id', m.id);
      } else {
        // Kam uchraydigan holat: taklif qilingan a'zo JORIY round oluvchisi — belgilab qo'yamiz
        await supabaseAdmin.from('circle_members').update({ status: 'declined' }).eq('id', inv.id);
      }
    }
    res.json({ success: true, data: { ok: true } });
  } catch (e) { next(e); }
});

// ============================================================
// POST /api/circles/:id/invite — egasi yangi a'zo(lar) qo'shadi (oxiriga)
//   body: { members: [{ name, phone? }] }  — yangi pozitsiyalar + roundlar qo'shiladi
// ============================================================
router.post('/:id/invite', requireActiveSub, async (req, res, next) => {
  try {
    const full = await loadFull(req.params.id);
    if (!full) return res.status(404).json({ success: false, error: 'Doira topilmadi' });
    if (full.circle.owner_id !== req.user.id) return res.status(403).json({ success: false, error: 'Faqat egasi taklif qiladi' });
    if (full.circle.status !== 'active') return res.status(400).json({ success: false, error: 'Doira yakunlangan' });
    const add = Array.isArray(req.body?.members) ? req.body.members : [];
    if (!add.length) return res.status(400).json({ success: false, error: "A'zo yo'q" });
    if (countedMembers(full).length + add.length > MAX_MEMBERS)
      return res.status(400).json({ success: false, error: `A'zolar soni ${MAX_MEMBERS} dan oshmasin` });
    // Dublikat telefonlar (mavjud a'zolar va yangi ro'yxat ichida)
    const knownPhones = new Set(full.members.filter((m) => m.status !== 'declined' && m.invited_phone).map((m) => m.invited_phone));
    const mePhone = normPhone(req.user.phone);
    if (mePhone) knownPhones.add(mePhone);
    for (const m of add) {
      const ph = normPhone(m.phone);
      if (ph && knownPhones.has(ph))
        return res.status(400).json({ success: false, error: 'Bu raqam allaqachon doirada' });
      if (ph) knownPhones.add(ph);
    }

    let pos = full.members.reduce((s, m) => Math.max(s, m.payout_position), 0);
    let idx = full.rounds.reduce((s, r) => Math.max(s, r.idx), 0);
    const meNm = await meName(req.user.id);
    for (const m of add) {
      pos += 1; idx += 1;
      const phone = normPhone(m.phone);
      const { data: nm, error: em } = await supabaseAdmin.from('circle_members').insert({
        circle_id: full.circle.id, invited_phone: phone || null,
        display_name: clip(m.name, 60) || `Member ${pos}`,
        payout_position: pos, status: phone ? 'invited' : 'active',
      }).select().single();
      if (em) throw new Error(em.message);
      await supabaseAdmin.from('circle_rounds').insert({
        circle_id: full.circle.id, idx, recipient_member_id: nm.id, status: 'upcoming',
      });
      if (phone) {
        const { data: u } = await supabaseAdmin.from('profiles').select('id').eq('phone', phone).maybeSingle();
        if (u?.id) await notify(u.id, req.user.id, 'circle_invite', `${meNm} sizni "${full.circle.name}" doirasiga taklif qildi`, "Taklifni ko'rish uchun bosing", full.circle.id);
      }
    }
    const fresh = await loadFull(req.params.id);
    res.json({ success: true, data: mapCircle(fresh, req.user.id, normPhone(req.user.phone)) });
  } catch (e) { next(e); }
});

// ============================================================
// PATCH /api/circles/:id — egasi nomni tahrirlaydi
// ============================================================
router.patch('/:id', async (req, res, next) => {
  try {
    const { data: c } = await supabaseAdmin.from('circles').select('owner_id').eq('id', req.params.id).maybeSingle();
    if (!c) return res.status(404).json({ success: false, error: 'Doira topilmadi' });
    if (c.owner_id !== req.user.id) return res.status(403).json({ success: false, error: 'Faqat egasi tahrirlaydi' });
    const patch = { updated_at: new Date().toISOString() };
    if (req.body?.name !== undefined) {
      const nm = String(req.body.name).trim();
      if (!nm || nm.length > 60) return res.status(400).json({ success: false, error: 'Nom 1..60 belgi' });
      patch.name = nm;
    }
    await supabaseAdmin.from('circles').update(patch).eq('id', req.params.id);
    const fresh = await loadFull(req.params.id);
    res.json({ success: true, data: mapCircle(fresh, req.user.id, normPhone(req.user.phone)) });
  } catch (e) { next(e); }
});

// ============================================================
// DELETE /api/circles/:id — egasi doirani yopadi.
//   Dalil (done round) BOR -> soft-close (status='closed', yozuvlar saqlanadi).
//   Dalil YO'Q (hech bir round yopilmagan) -> hard delete (cascade).
// ============================================================
router.delete('/:id', async (req, res, next) => {
  try {
    const full = await loadFull(req.params.id);
    if (!full) return res.status(404).json({ success: false, error: 'Doira topilmadi' });
    if (full.circle.owner_id !== req.user.id) return res.status(403).json({ success: false, error: 'Faqat egasi yopadi' });
    const anyDone = full.rounds.some((r) => r.status === 'done');
    const meNm = await meName(req.user.id);
    if (anyDone) {
      // Dalil bor — hech qachon hard delete qilinmaydi
      if (full.circle.status !== 'active')
        return res.status(400).json({ success: false, error: "Doira allaqachon yopilgan — yozuvlar dalil sifatida saqlanadi" });
      await supabaseAdmin.from('circles').update({ status: 'closed', updated_at: new Date().toISOString() }).eq('id', req.params.id);
      for (const m of full.members) {
        if (m.user_id) await notify(m.user_id, req.user.id, 'circle_closed', `${meNm} "${full.circle.name}" doirasini yopdi`, 'Yozuvlar dalil sifatida saqlanadi', full.circle.id);
      }
      const fresh = await loadFull(req.params.id);
      return res.json({ success: true, data: mapCircle(fresh, req.user.id, normPhone(req.user.phone)) });
    }
    for (const m of full.members) {
      if (m.user_id) await notify(m.user_id, req.user.id, 'circle_closed', `${meNm} "${full.circle.name}" doirasini o'chirdi`, '', null);
    }
    await supabaseAdmin.from('circles').delete().eq('id', req.params.id);
    res.json({ success: true, data: { ok: true } });
  } catch (e) { next(e); }
});

export default router;

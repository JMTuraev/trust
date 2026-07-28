// Obuna (subscription) — YAGONA haqiqat manbai (server-side).
//
// YANGI TARIF (PO 2026-07-28) — vaqtga asoslangan 7 kunlik trial OLIB TASHLANDI:
//   Bepul kvota: 3 ta QARZ yozuvi (debts, kind='debt', o'zi yaratgan, bekor/rad
//   qilinganlar sanalmaydi) + 3 ta XARAJAT yozuvi (expenses jadvalidagi yozuvlar).
//   Kvota tugagach — $9/oy premium (premium_until, Play Billing keyin ulanadi).
//   Limitlar FAQAT serverda (env): FREE_DEBT_ENTRIES, FREE_EXPENSE_ENTRIES (default 3).
//   UI hech narsa hardcode qilmaydi — o'zgartirsak update shart emas.
//
// Kim to'laydi (PO):
//   - Daftar (partner) EGASI to'laydi. Egasi premium yoki kvota ichida bo'lsa —
//     kontragent o'sha daftarda BEPUL ishlaydi (tasdiqlash, qaytarish, yozuv).
//   - Egasining kvotasi tugagan va premium yo'q — YANGI qarz yozuvini hech kim
//     kirita olmaydi (egasi ham, kontragent ham) — 402 + tushunarli xabar.
//   - Kontragent O'ZI daftar ochsa — o'z kvotasi/premiumi bilan oddiy ega kabi.
//   - Mavjud qarzga repay/settle/tasdiq — HAR DOIM ochiq (pul qaytishi bloklanmasin).
import { supabaseAdmin } from './supabase.js';

export const PRICE_USD_MONTHLY = 9;
export const PREMIUM_PRODUCT_ID = 'trust_premium_monthly';
// ≤ WARN_DAYS kun qolganda mobil "To'lov muddati yaqinlashdi" bannerini ko'rsatadi (faqat premium)
export const WARN_DAYS = 3;
const DAY_MS = 24 * 60 * 60 * 1000;

// Bepul kvotalar — faqat env orqali boshqariladi (UI'da yo'q)
export const FREE_DEBT_ENTRIES = Math.max(0, parseInt(process.env.FREE_DEBT_ENTRIES || '3', 10) || 3);
export const FREE_EXPENSE_ENTRIES = Math.max(0, parseInt(process.env.FREE_EXPENSE_ENTRIES || '3', 10) || 3);

// Orqaga moslik: eski kod TRIAL_DAYS import qilsa yiqilmasin (endi ma'nosi yo'q)
export const TRIAL_DAYS = 0;

/** profiles qatori -> obuna holati (sof funksiya — testlash oson).
 *  YANGI: status 'premium' | 'free' (vaqt bo'yicha 'expired' YO'Q — gating kvota bilan,
 *  har bir yozuv endpointida alohida tekshiriladi). Maydon nomlari mobil bilan mos. */
export function computeSubscription(profile, now = new Date()) {
  const premiumUntil = profile.premium_until ? new Date(profile.premium_until) : null;
  const isPremium = !!(premiumUntil && premiumUntil > now);
  const daysLeft = isPremium
    ? Math.max(0, Math.ceil((premiumUntil.getTime() - now.getTime()) / DAY_MS))
    : null;
  return {
    status: isPremium ? 'premium' : 'free',
    trial_ends_at: null, // trial modeli olib tashlandi
    premium_until: premiumUntil ? premiumUntil.toISOString() : null,
    active_until: isPremium ? premiumUntil.toISOString() : null,
    days_left: daysLeft,
    // Faqat premium tugashiga ≤3 kun qolganda ogohlantiramiz
    warn_expiring: isPremium && daysLeft != null && daysLeft <= WARN_DAYS,
    // Vaqt bo'yicha bloklash yo'q — yozuv kvotasi endpointlarda tekshiriladi
    can_write: true,
    price: {
      monthly_usd: PRICE_USD_MONTHLY,
      currency: 'USD',
      period: 'month',
      trial_days: 0,
      free_debt_entries: FREE_DEBT_ENTRIES,
      free_expense_entries: FREE_EXPENSE_ENTRIES,
      product_id: PREMIUM_PRODUCT_ID,
    },
  };
}

/** Foydalanuvchining ishlatilgan kvotasi (server hisobi). */
export async function countUsage(userId) {
  const [d, e] = await Promise.all([
    supabaseAdmin
      .from('debts')
      .select('id', { count: 'exact', head: true })
      .eq('created_by', userId)
      .eq('kind', 'debt')
      .not('status', 'in', '(cancelled,rejected)'),
    supabaseAdmin
      .from('expenses')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId),
  ]);
  return { debts_used: d.count || 0, expenses_used: e.count || 0 };
}

/** Foydalanuvchi obunasi: profiles'dan o'qib hisoblaydi. null = profil topilmadi. */
export async function getSubscription(userId) {
  const { data, error } = await supabaseAdmin
    .from('profiles')
    .select('id, created_at, premium_until, deleted_at')
    .eq('id', userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) return null;
  return { profile: data, sub: computeSubscription(data) };
}

/** userId premiummi? (tez, bitta select) */
async function isPremiumUser(userId) {
  const { data } = await supabaseAdmin
    .from('profiles').select('premium_until').eq('id', userId).maybeSingle();
  return !!(data?.premium_until && new Date(data.premium_until) > new Date());
}

// ============ Express middleware'lar ============

/** ESKI vaqt-gate endi PASS-THROUGH: faqat o'chirilgan profil bloklanadi.
 *  (Partner yaratish, chat, AI va h.k. — bepul; pullik joylar quyidagi
 *  kvota-middleware'lar bilan ANIQ nuqtalarda gate qilinadi.) */
export function requireActiveSub(req, res, next) {
  if (req.method === 'GET' || req.method === 'HEAD' || req.method === 'OPTIONS') return next();
  getSubscription(req.user.id)
    .then((r) => {
      if (!r) return res.status(403).json({ success: false, error: 'Profil topilmadi' });
      if (r.profile.deleted_at) {
        return res
          .status(403)
          .json({ success: false, error: "Profil o'chirilgan — qayta kirsangiz tiklanadi" });
      }
      next();
    })
    .catch(next);
}
export const requireWriteAccess = requireActiveSub;

/** XARAJAT yozuvi kvotasi: premium YOKI expenses soni < FREE_EXPENSE_ENTRIES. */
export function requireExpenseQuota(req, res, next) {
  (async () => {
    if (await isPremiumUser(req.user.id)) return next();
    const { expenses_used } = await countUsage(req.user.id);
    if (expenses_used < FREE_EXPENSE_ENTRIES) return next();
    return res.status(402).json({
      success: false,
      code: 'SUB_EXPIRED',
      error: `Bepul ${FREE_EXPENSE_ENTRIES} ta xarajat yozuvi ishlatildi — davom etish uchun obuna kerak ($${PRICE_USD_MONTHLY}/oy)`,
    });
  })().catch(next);
}

/** YANGI QARZ yozuvi kvotasi — daftar EGASI bo'yicha (PO qoidasi).
 *  POST /api/debts/:partnerId dan OLDIN turadi. */
export function requireNewDebtQuota(req, res, next) {
  (async () => {
    const { data: p } = await supabaseAdmin
      .from('partners').select('owner_id').eq('id', req.params.partnerId).maybeSingle();
    // Hamkor topilmasa handler o'zi 404 beradi — bu yerda bloklamaymiz
    if (!p) return next();
    if (await isPremiumUser(p.owner_id)) return next();
    const { debts_used } = await countUsage(p.owner_id);
    if (debts_used < FREE_DEBT_ENTRIES) return next();
    const isOwner = p.owner_id === req.user.id;
    return res.status(402).json({
      success: false,
      code: 'SUB_EXPIRED',
      error: isOwner
        ? `Bepul ${FREE_DEBT_ENTRIES} ta qarz yozuvi ishlatildi — davom etish uchun obuna kerak ($${PRICE_USD_MONTHLY}/oy)`
        : "Daftar egasining obunasi faol emas — bu daftarga hozircha yangi yozuv kiritib bo'lmaydi",
    });
  })().catch(next);
}

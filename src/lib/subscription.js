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

// Test hook (node:test): unit tests stub the DB instead of hitting live Supabase.
// Production code path is untouched — db stays supabaseAdmin unless a test swaps it.
let db = supabaseAdmin;
export function __setDbForTests(stub) {
  db = stub || supabaseAdmin;
}

export const PRICE_USD_MONTHLY = 9;
export const PREMIUM_PRODUCT_ID = 'trust_premium_monthly';
// ≤ WARN_DAYS kun qolganda mobil "To'lov muddati yaqinlashdi" bannerini ko'rsatadi (faqat premium)
export const WARN_DAYS = 3;
const DAY_MS = 24 * 60 * 60 * 1000;

// Bepul kvotalar — faqat env orqali boshqariladi (UI'da yo'q).
// VAQTINCHA (PO 2026-08-03): default 300 — jonli TEST davri uchun (avval 30 edi).
// Test tugagach 3 ga qaytariladi (env FREE_*=3 qo'yish YOKI defaultlarni tushirish).
// MUHIM (2026-08-02 audit): ilgari `parseInt(env || '30') || 30` yozilgan edi — parseInt('0')
// = 0 va u FALSY, shuning uchun FREE_DEBT_ENTRIES=0 qo'yilsa ham jimgina 30 bo'lib qolardi
// (ya'ni "bepul tarifni yopish" sozlamasi umuman ishlamas edi).
function intEnv(name, def) {
  const raw = process.env[name];
  if (raw === undefined || raw === null || String(raw).trim() === '') return def;
  const n = Number.parseInt(String(raw), 10);
  if (!Number.isFinite(n) || n < 0) {
    console.warn(`[config] ${name} noto'g'ri ("${raw}") — default ${def} ishlatildi`);
    return def;
  }
  return n;
}
// PO 2026-08-03: sinov davri uchun 30 -> 300 (auditda operations ham kvotaga
// qo'shilgani sabab mavjud foydalanuvchilar paywallga urilmasin).
export const FREE_DEBT_ENTRIES = intEnv('FREE_DEBT_ENTRIES', 300);
export const FREE_EXPENSE_ENTRIES = intEnv('FREE_EXPENSE_ENTRIES', 300);

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

/** Daftar EGASI bo'yicha qarz yozuvlari soni.
 *  MUHIM (2026-08-02 audit): ilgari faqat `created_by = userId` sanalardi. Kontragent
 *  o'sha daftarga yozgan qarzlar HECH KIMGA sanalmasdi (egasiga — created_by boshqa,
 *  yozuvchiga — u ega emas). Ikki foydalanuvchi bir-birining daftariga yozib, ikkalasi
 *  ham cheksiz bepul ishlata olardi. Endi kvota daftar EGALIGI bo'yicha hisoblanadi —
 *  bu "daftar egasi to'laydi" qoidasiga ham aynan mos. */
async function countOwnerDebts(ownerId) {
  const { data: partners } = await db
    .from('partners').select('id').eq('owner_id', ownerId).limit(2000);
  const ids = (partners || []).map((p) => p.id);
  if (!ids.length) return 0;
  // `operations` ham SANALADI (2026-08-02 audit): mobil "Yangi operatsiya" varag'i
  // aynan shu jadvalga yozadi va u hamkor balansiga qo'shiladi. Ilgari kvota faqat
  // `debts` bo'yicha edi, ya'ni bepul foydalanuvchi cheksiz oldi-berdi kiritaverardi
  // va paywall hech qachon ko'rinmasdi.
  const [d, o] = await Promise.all([
    db
      .from('debts')
      .select('id', { count: 'exact', head: true })
      .in('partner_id', ids)
      .eq('kind', 'debt')
      .not('status', 'in', '(cancelled,rejected)'),
    db
      .from('operations')
      .select('id', { count: 'exact', head: true })
      .eq('owner_id', ownerId)
      .neq('status', 'cancelled'),
  ]);
  return (d.count || 0) + (o.count || 0);
}

/** Foydalanuvchining ishlatilgan kvotasi (server hisobi). */
export async function countUsage(userId) {
  const [debts_used, e] = await Promise.all([
    countOwnerDebts(userId),
    db
      .from('expenses')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId),
  ]);
  return { debts_used, expenses_used: e.count || 0 };
}

/** Foydalanuvchi obunasi: profiles'dan o'qib hisoblaydi. null = profil topilmadi. */
export async function getSubscription(userId) {
  const { data, error } = await db
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
  const { data } = await db
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

/** YANGI OPERATSIYA kvotasi — POST /api/operations uchun (partner_id BODY'da).
 *  MUHIM (2026-08-02 audit): bu endpoint mobil ilovaning asosiy "yangi yozuv" yo'li,
 *  lekin unda kvota tekshiruvi UMUMAN yo'q edi — paywall hech qachon ishlamasdi. */
export function requireNewOpQuota(req, res, next) {
  (async () => {
    const partnerId = req.body?.partner_id;
    if (!partnerId) return next(); // handler o'zi 400 beradi
    const { data: p } = await db
      .from('partners').select('owner_id').eq('id', partnerId).maybeSingle();
    if (!p) return next();
    if (await isPremiumUser(p.owner_id)) return next();
    const { debts_used } = await countUsage(p.owner_id);
    if (debts_used < FREE_DEBT_ENTRIES) return next();
    const isOwner = p.owner_id === req.user.id;
    return res.status(402).json({
      success: false,
      code: isOwner ? 'SUB_EXPIRED' : 'OWNER_SUB_EXPIRED',
      error: isOwner
        ? `Bepul ${FREE_DEBT_ENTRIES} ta yozuv ishlatildi — davom etish uchun obuna kerak ($${PRICE_USD_MONTHLY}/oy)`
        : "Daftar egasining obunasi faol emas — bu daftarga hozircha yangi yozuv kiritib bo'lmaydi",
    });
  })().catch(next);
}

/** YANGI QARZ yozuvi kvotasi — daftar EGASI bo'yicha (PO qoidasi).
 *  POST /api/debts/:partnerId dan OLDIN turadi. */
export function requireNewDebtQuota(req, res, next) {
  (async () => {
    const { data: p } = await db
      .from('partners').select('owner_id').eq('id', req.params.partnerId).maybeSingle();
    // Hamkor topilmasa handler o'zi 404 beradi — bu yerda bloklamaymiz
    if (!p) return next();
    if (await isPremiumUser(p.owner_id)) return next();
    const { debts_used } = await countUsage(p.owner_id);
    if (debts_used < FREE_DEBT_ENTRIES) return next();
    const isOwner = p.owner_id === req.user.id;
    // MUHIM (2026-08-02 audit): kod AJRATILDI. Ilgari ikkala holat ham 'SUB_EXPIRED'
    // qaytarardi, mobil esa uni "MENING obunam tugadi" deb qabul qilib, butun ilovada
    // qizil banner ko'rsatardi — holbuki kvota tugagani QARSHI TOMONNIKI edi.
    return res.status(402).json({
      success: false,
      code: isOwner ? 'SUB_EXPIRED' : 'OWNER_SUB_EXPIRED',
      error: isOwner
        ? `Bepul ${FREE_DEBT_ENTRIES} ta qarz yozuvi ishlatildi — davom etish uchun obuna kerak ($${PRICE_USD_MONTHLY}/oy)`
        : "Daftar egasining obunasi faol emas — bu daftarga hozircha yangi yozuv kiritib bo'lmaydi",
    });
  })().catch(next);
}

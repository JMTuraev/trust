// Obuna (subscription) — YAGONA haqiqat manbai (server-side).
// Model (008 migratsiya): trial = profiles.created_at + 7 kun (alohida ustun YO'Q),
// premium = profiles.premium_until kelajakda bo'lsa. To'lov integratsiyasi hali yo'q —
// premium_until faqat admin/DEV-stub orqali o'zgaradi (routes/profile.js /subscription/verify).
//
// Chegara semantikasi routes/profile.js dagi eski hisob bilan AYNAN bir xil:
//   premium : premium_until > now        (qat'iy katta)
//   trial   : now < created_at + 7 kun   (qat'iy kichik)
//   expired : aks holda
// Hamma taqqoslash UTC epoch-millisda — timezone'ga bog'liq emas (Postgres timestamptz
// ISO-UTC qaytaradi, new Date() ham UTC epoch bilan ishlaydi).
//
// Grace: SUB_GRACE_DAYS (default 0) — muddat tugaganidan keyin ham yozishga ruxsat
// qolinadigan yumshoq davr (Play Billing yangilanishi kechikkanda foydalanuvchi
// birdan qulflanib qolmasin). 0 = hozirgi qat'iy xatti-harakat o'zgarmaydi.
import { supabaseAdmin } from './supabase.js';

export const TRIAL_DAYS = 7;
// Narx — mahsulot qarori (product owner): 7 kun bepul sinov -> $9/oy.
// Play Billing ulanganida shu product_id ishlatiladi (docs hisobotda reja).
export const PRICE_USD_MONTHLY = 9;
export const PREMIUM_PRODUCT_ID = 'trust_premium_monthly';
// ≤ WARN_DAYS kun qolganda mobil "To'lov muddati yaqinlashdi" bannerini ko'rsatadi
export const WARN_DAYS = 3;
const DAY_MS = 24 * 60 * 60 * 1000;
const GRACE_DAYS = Math.max(0, parseInt(process.env.SUB_GRACE_DAYS || '0', 10) || 0);

/** profiles qatori -> obuna holati (sof funksiya — testlash oson). */
export function computeSubscription(profile, now = new Date()) {
  const createdAt = new Date(profile.created_at);
  const trialEndsAt = new Date(createdAt.getTime() + TRIAL_DAYS * DAY_MS);
  const premiumUntil = profile.premium_until ? new Date(profile.premium_until) : null;
  const status =
    premiumUntil && premiumUntil > now ? 'premium' : now < trialEndsAt ? 'trial' : 'expired';
  // active_until — yozish huquqi tugaydigan sana: premiumda premium_until, aks holda trial oxiri
  const activeUntil = status === 'premium' ? premiumUntil : trialEndsAt;
  // Grace oxiri: eng kech tugagan muddat (premium_until yoki trial) + GRACE_DAYS
  const lastEnd = premiumUntil && premiumUntil > trialEndsAt ? premiumUntil : trialEndsAt;
  const graceUntil = new Date(lastEnd.getTime() + GRACE_DAYS * DAY_MS);
  const daysLeft = Math.max(0, Math.ceil((activeUntil.getTime() - now.getTime()) / DAY_MS));
  return {
    status,
    trial_ends_at: trialEndsAt.toISOString(),
    premium_until: premiumUntil ? premiumUntil.toISOString() : null,
    active_until: activeUntil.toISOString(),
    days_left: daysLeft,
    // ≤3 kun qoldi (trial YOKI premium) — mobil ogohlantirish banneri shu flag bilan
    warn_expiring: status !== 'expired' && daysLeft <= WARN_DAYS,
    // Yozish mumkinmi: premium/trial — ha; expired — faqat grace ichida (default: yo'q)
    can_write: status !== 'expired' || now < graceUntil,
    // Narx ma'lumoti — UI serverdan oladi (hardcode bitta joyda qolsin)
    price: {
      monthly_usd: PRICE_USD_MONTHLY,
      currency: 'USD',
      period: 'month',
      trial_days: TRIAL_DAYS,
      product_id: PREMIUM_PRODUCT_ID,
    },
  };
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

// Express middleware — READ-ONLY model: obunasi tugagan user hamma narsani KO'RADI,
// lekin YANGI qiymat yarata olmaydi. Shuning uchun bu middleware faqat yangi qiymat
// yaratadigan endpointlarga qo'yiladi (POST /partners, /operations, /debts/:partnerId,
// /expenses, /expenses/confirm, /expenses/parse, /circles, /circles/:id/invite).
// 402 SUB_EXPIRED — mijoz paywall/obuna bannerini ko'rsatadi.
// ATAYLAB qo'yilmaydi:
//   - GET/HEAD/OPTIONS — o'qish har doim ochiq (quyida himoya sifatida ham skip qilinadi);
//   - qarshi tomon JAVOB amallari (debts confirm/reject/cancel/review-*,
//     circles confirm/accept/decline, links'ning barcha endpointlari) — kontragent
//     hech qachon boshqa tomonning to'lovi tufayli qotib qolmasligi kerak.
// PO qarori (2026-07-16): repay/settle (debts) va pay (circles) — YANGI yozuv
// yaratadi, shuning uchun ular ham GATE qilinadi (read-only qat'iy: "yozuv kirita
// olmaysiz"). messages POST ham gate'da (chat UI hozircha yashirin).
export function requireActiveSub(req, res, next) {
  // Himoya: adashib GET route'ga ulansa ham o'qish bloklanmasin (read-only kafolati)
  if (req.method === 'GET' || req.method === 'HEAD' || req.method === 'OPTIONS') return next();
  getSubscription(req.user.id)
    .then((r) => {
      if (!r) return res.status(403).json({ success: false, error: 'Profil topilmadi' });
      if (r.profile.deleted_at) {
        return res
          .status(403)
          .json({ success: false, error: "Profil o'chirilgan — qayta kirsangiz tiklanadi" });
      }
      if (!r.sub.can_write) {
        return res.status(402).json({
          success: false,
          code: 'SUB_EXPIRED',
          error: "To'lov muddati tugagan — yangi yozuv kirita olmaysiz. Obunani yangilang ($9/oy)",
        });
      }
      next();
    })
    .catch(next);
}

// Muqobil nom — ba'zi route'lar semantik aniqroq "yozish huquqi" nomini ishlatishi
// mumkin; ikkalasi ham bitta middleware (orqaga moslik: requireActiveSub saqlanadi).
export const requireWriteAccess = requireActiveSub;

import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { computeSubscription, getSubscription, PREMIUM_PRODUCT_ID } from '../lib/subscription.js';
import { appleConfigured, verifyAppleReceipt } from '../lib/appleIap.js';
import { sendOtp, checkOtpCode } from '../services/otp.js';

const router = Router();
router.use(requireAuth);

// GET /api/profile/me — profil + hayot sikli maydonlari (soft-delete/trial/premium).
// Obuna chegaralari lib/subscription.js da — BUTUN backend bir joydan hisoblaydi.
router.get('/me', async (req, res, next) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .select('*')
      .eq('id', req.user.id)
      .maybeSingle();
    if (error) throw new Error(error.message);

    let out = data;
    if (data) {
      const sub = computeSubscription(data);
      out = {
        ...data,
        deleted_at: data.deleted_at ?? null,
        // Mavjud mijozlar kutadigan maydonlar (mobil store._tryResume) — o'zgarmagan:
        trial_ends_at: sub.trial_ends_at,
        premium_until: sub.premium_until,
        status: sub.status,
        // Yangi (qo'shimcha, orqaga mos): UI "N kun qoldi" ni serverdan ham oladi
        days_left: sub.days_left,
        active_until: sub.active_until,
        // ≤3 kun qoldi (trial YOKI premium) — mobil "To'lov muddati yaqinlashdi" banneri
        warn_expiring: sub.warn_expiring,
        // Narx: 7 kun bepul -> $9/oy (mahsulot qarori; bitta manba lib/subscription.js)
        price: sub.price,
      };
    }
    res.json({ success: true, data: out });
  } catch (e) {
    next(e);
  }
});

// GET /api/profile/me/subscription — faqat obuna holati (profil qatori / paywall).
router.get('/me/subscription', async (req, res, next) => {
  try {
    const r = await getSubscription(req.user.id);
    if (!r) return res.status(404).json({ success: false, error: 'Profil topilmadi' });
    res.json({ success: true, data: r.sub });
  } catch (e) {
    next(e);
  }
});

// POST /api/profile/me/subscription/verify — obuna xaridini server tomonda tasdiqlash.
// Ikki platforma (mobil `platform` yuboradi):
//   • app_store   — TIRIK: Apple verifyReceipt (lib/appleIap.js). `receipt_data` (base64)
//                   tekshiriladi -> profiles.premium_until = Apple bergan tugash vaqti.
//                   APPLE_SHARED_SECRET (Render env) kerak; o'rnatilmasa 501.
//   • google_play — STUB: Play Billing hali ulanmagan. DEV rejim (PLAY_BILLING_DEV_MODE=true)
//                   'DEV.' prefiksli token premium'ni 30 kunga uzaytiradi (QA/E2E). Aks holda 501.
// To'liq Google ulash (kelajak): androidpublisher subscriptionsv2.get -> expiryTime + RTDN webhook.
const DEV_MODE = process.env.PLAY_BILLING_DEV_MODE === 'true';
const PREMIUM_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

// Idempotent audit yozuvi + profiles.premium_until ni newUntilIso ga o'rnatish.
// Mavjud (kelajakdagi) premium_until ni QISQARTIRMAYDI — max(joriy, yangi) olinadi
// (boshqa platformadagi uzoqroq obuna tasodifan kesilmasin).
async function grantPremium(userId, curSub, provider, productId, token, newUntilMs) {
  const now = Date.now();
  const curUntil = curSub.premium_until ? new Date(curSub.premium_until).getTime() : 0;
  const finalMs = Math.max(curUntil, newUntilMs);
  const newUntilIso = new Date(finalMs).toISOString();

  // Audit — purchase_token bo'yicha UNIQUE; takror bo'lsa jimgina o'tkazamiz (idempotent).
  if (token) {
    await supabaseAdmin
      .from('subscription_events')
      .upsert(
        {
          user_id: userId,
          provider,
          product_id: productId,
          purchase_token: token,
          premium_until_after: newUntilIso,
        },
        { onConflict: 'purchase_token', ignoreDuplicates: true }
      );
  }

  // premium_until faqat oldinga siljisa yozamiz (bekorga updated_at o'zgarmasin)
  if (finalMs > curUntil) {
    const { data: upd, error: updErr } = await supabaseAdmin
      .from('profiles')
      .update({ premium_until: newUntilIso, updated_at: new Date().toISOString() })
      .eq('id', userId)
      .select('id, created_at, premium_until, deleted_at')
      .single();
    if (updErr) throw new Error(updErr.message);
    return computeSubscription(upd);
  }
  return curSub;
}

router.post(
  '/me/subscription/verify',
  rateLimit({ windowMs: 60_000, max: 10 }),
  async (req, res, next) => {
    try {
      const { platform, product_id } = req.body || {};
      const pid = String(product_id ?? '').trim() || PREMIUM_PRODUCT_ID;
      if (pid.length > 100) {
        return res.status(400).json({ success: false, error: 'product_id juda uzun' });
      }

      // ===================== Apple App Store (TIRIK) =====================
      if (platform === 'app_store') {
        if (!appleConfigured()) {
          return res.status(501).json({
            success: false,
            error: "Apple to'lovi hali sozlanmagan — tez orada ishlaydi",
          });
        }
        // Mobil `receipt_data` yuboradi; `purchase_token` — orqaga moslik uchun alias.
        const receipt = String(req.body?.receipt_data ?? req.body?.purchase_token ?? '').trim();
        if (!receipt || receipt.length > 200_000) {
          return res.status(400).json({ success: false, error: 'receipt_data kerak' });
        }
        let ver;
        try {
          ver = await verifyAppleReceipt(receipt, pid);
        } catch (e) {
          console.error('Apple verifyReceipt xato:', e?.message || e);
          return res.status(502).json({ success: false, error: "Apple bilan aloqa xatosi — qayta urinib ko'ring" });
        }
        if (!ver.ok) {
          return res.status(400).json({ success: false, error: `Chek yaroqsiz (Apple status ${ver.status})` });
        }
        if (!ver.expiryMs) {
          return res.status(400).json({ success: false, error: 'Bu chekda faol obuna topilmadi' });
        }
        const r = await getSubscription(req.user.id);
        if (!r) return res.status(403).json({ success: false, error: 'Profil topilmadi' });
        const sub = await grantPremium(
          req.user.id,
          r.sub,
          'app_store',
          pid,
          ver.txnId ? `apple:${ver.txnId}` : null,
          ver.expiryMs
        );
        return res.json({ success: true, data: sub });
      }

      // ===================== Google Play (STUB / DEV) =====================
      if (platform === 'google_play') {
        const tok = String(req.body?.purchase_token ?? '').trim();
        if (!tok || tok.length > 1000) {
          return res.status(400).json({ success: false, error: 'purchase_token kerak' });
        }
        if (!DEV_MODE || !tok.startsWith('DEV.')) {
          return res.status(501).json({
            success: false,
            error: "To'lov hali ulanmagan — obuna tez orada Google Play orqali ishlaydi",
          });
        }
        const r = await getSubscription(req.user.id);
        if (!r) return res.status(403).json({ success: false, error: 'Profil topilmadi' });
        const sub = await grantPremium(
          req.user.id,
          r.sub,
          'google_play_dev',
          pid,
          tok,
          Date.now() + PREMIUM_DAYS * DAY_MS
        );
        return res.json({ success: true, data: sub });
      }

      return res.status(400).json({
        success: false,
        error: "platform 'app_store' yoki 'google_play' bo'lishi kerak",
      });
    } catch (e) {
      next(e);
    }
  }
);

// PUT /api/profile/me  { "full_name": "...", "avatar_url": "...", "notif_enabled": true|false }
router.put('/me', async (req, res, next) => {
  try {
    const { full_name, avatar_url, notif_enabled } = req.body || {};
    const patch = { updated_at: new Date().toISOString() };
    if (full_name !== undefined) {
      const n = String(full_name).trim();
      if (n.length > 80) return res.status(400).json({ success: false, error: "Ism 80 belgidan oshmasin" });
      // Bo'sh ism -> null: UI telefon raqamiga qaytadi (bo'sh satr saqlanmasin)
      patch.full_name = n || null;
    }
    if (avatar_url !== undefined) {
      const u = String(avatar_url).trim();
      if (u && (!/^https?:\/\//i.test(u) || u.length > 500))
        return res.status(400).json({ success: false, error: "avatar_url yaroqsiz" });
      patch.avatar_url = u || null;
    }
    if (notif_enabled !== undefined) patch.notif_enabled = !!notif_enabled;
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .update(patch)
      .eq('id', req.user.id)
      .select()
      .single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) {
    next(e);
  }
});

// ---- Push token (FCM) ----
// POST /api/profile/push-token { token, platform } — qurilma tokenini akkauntga bog'lash.
// token UNIQUE (014 migratsiya): qurilmada akkaunt almashsa upsert qatorni yangi
// user_id ga qayta bog'laydi — eski akkauntga push ketmaydi.
router.post('/push-token', async (req, res, next) => {
  try {
    const token = String(req.body?.token ?? '').trim();
    const platform = ['android', 'ios'].includes(req.body?.platform) ? req.body.platform : 'android';
    if (!token || token.length > 4096)
      return res.status(400).json({ success: false, error: 'token kerak' });
    const { error } = await supabaseAdmin.from('device_tokens').upsert(
      { token, user_id: req.user.id, platform, updated_at: new Date().toISOString() },
      { onConflict: 'token' }
    );
    if (error) throw new Error(error.message);
    res.json({ success: true });
  } catch (e) { next(e); }
});

// DELETE /api/profile/push-token { token } — logout: shu qurilmani ro'yxatdan chiqarish.
// Token topilmasa ham success — idempotent (mobil fire-and-forget chaqiradi).
router.delete('/push-token', async (req, res, next) => {
  try {
    const token = String(req.body?.token ?? '').trim();
    if (token) {
      await supabaseAdmin.from('device_tokens')
        .delete().eq('token', token).eq('user_id', req.user.id);
    }
    res.json({ success: true });
  } catch (e) { next(e); }
});

// POST /api/profile/me/delete-otp — profil o'chirishni TASDIQLASH kodi (SMS).
// Telefon bazadagi profil raqami (mijoz qayta yozmaydi). sendOtp o'z limitlariga ega
// (raqam boshiga 60s dedupe + global soatlik cap) — bu yerda qo'shimcha 3/min IP limiti.
router.post(
  '/me/delete-otp',
  rateLimit({ windowMs: 60_000, max: 3 }),
  async (req, res, next) => {
    try {
      const { data: prof, error } = await supabaseAdmin
        .from('profiles').select('phone').eq('id', req.user.id).maybeSingle();
      if (error) throw new Error(error.message);
      if (!prof?.phone) return res.status(404).json({ success: false, error: 'Profil topilmadi' });
      const r = await sendOtp(String(prof.phone));
      // Raqam niqoblanadi: +99890***4567 (UI xabar uchun)
      const ph = String(prof.phone);
      const masked = ph.length > 7 ? `+${ph.slice(0, 5)}***${ph.slice(-4)}` : `+${ph}`;
      res.json({ success: true, data: { phone_masked: masked, expires_in: r.expires_in } });
    } catch (e) { next(e); }
  }
);

// DELETE /api/profile/me — akkauntni SOFT delete qilish (App Store/Play siyosati talabi).
// PO 2026-07-29: endi SMS KOD bilan tasdiqlanadi (body.code) — ikki bosqichli bosish o'rniga.
// Ma'lumotlar O'CHIRILMAYDI: link modelida qarshi tomonning daftari saqlanib qolishi kerak.
// Faqat profiles.deleted_at belgilanadi; qayta kirish (OTP tasdig'i, src/services/otp.js
// reactivateIfDeleted) profilni avtomatik tiklaydi (deleted_at=null) — tiklash oynasi cheksiz.
router.delete('/me', async (req, res, next) => {
  try {
    const code = String(req.body?.code ?? '').trim();
    if (!code) {
      return res.status(400).json({ success: false, error: 'Tasdiqlash kodi kerak — SMS kodni kiriting' });
    }
    const { data: prof, error: pe } = await supabaseAdmin
      .from('profiles').select('phone').eq('id', req.user.id).maybeSingle();
    if (pe) throw new Error(pe.message);
    if (!prof?.phone) return res.status(404).json({ success: false, error: 'Profil topilmadi' });
    await checkOtpCode(String(prof.phone), code); // noto'g'ri kod -> 400 (xabari o'zbekcha)

    const nowIso = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('profiles')
      .update({ deleted_at: nowIso, updated_at: nowIso })
      .eq('id', req.user.id);
    if (error) throw new Error(error.message);

    // 2026-07-17: AI suhbat tarixi soft-delete'da HAQIQATAN o'chiriladi.
    // Sabab: on-delete-cascade faqat HARD delete'da ishlaydi, biz esa soft qilamiz —
    // privacy-policy.html §3 shuni va'da qiladi, kod bilan mos bo'lishi SHART (Play Data Safety).
    // Daftar/qarzlar TEGILMAYDI (qarshi tomonning yozuvi saqlanishi kerak — link modeli).
    // Qayta kirsa (reactivateIfDeleted) AI suhbati toza boshlanadi — bu kutilgan xatti-harakat.
    // ai_usage QOLADI: bu moliyaviy/token auditi, shaxsiy suhbat mazmuni emas.
    await supabaseAdmin.from('ai_messages').delete().eq('user_id', req.user.id);
    await supabaseAdmin.from('ai_profile').delete().eq('user_id', req.user.id);

    res.json({ success: true, data: { deleted_at: nowIso } });
  } catch (e) {
    next(e);
  }
});

export default router;

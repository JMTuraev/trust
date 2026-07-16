import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { computeSubscription, getSubscription } from '../lib/subscription.js';

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
// HOZIRCHA STUB: Google Play Billing ulanmagan (008 migratsiya izohi: "to'lov keyinroq").
// To'liq ulash uchun kerak bo'ladi (docs/team-reports/2026-07-16-profile.md da batafsil):
//   1) Play Console'da obuna mahsuloti (masalan trust_premium_monthly, $9/oy);
//   2) Google Cloud service account (androidpublisher scope) + kaliti Render env'da;
//   3) purchases.subscriptionsv2.get(packageName, purchaseToken) -> expiryTime ->
//      profiles.premium_until = expiryTime; RTDN (Pub/Sub webhook) bilan uzaytirish/bekor.
// DEV rejim (faqat PLAY_BILLING_DEV_MODE=true env bilan): 'DEV.' prefiksli token
// premium'ni 30 kunga uzaytiradi — QA/E2E uchun. Productionda flag yo'q = har doim 501.
const DEV_MODE = process.env.PLAY_BILLING_DEV_MODE === 'true';
const PREMIUM_DAYS = 30;

router.post(
  '/me/subscription/verify',
  rateLimit({ windowMs: 60_000, max: 10 }),
  async (req, res, next) => {
    try {
      const { platform, product_id, purchase_token } = req.body || {};
      if (platform !== 'google_play') {
        return res.status(400).json({ success: false, error: "platform 'google_play' bo'lishi kerak" });
      }
      const pid = String(product_id ?? '').trim();
      const tok = String(purchase_token ?? '').trim();
      if (!pid || pid.length > 100 || !tok || tok.length > 1000) {
        return res.status(400).json({ success: false, error: 'product_id va purchase_token kerak' });
      }

      if (!DEV_MODE || !tok.startsWith('DEV.')) {
        return res.status(501).json({
          success: false,
          error: "To'lov hali ulanmagan — obuna tez orada Google Play orqali ishlaydi",
        });
      }

      // ---- DEV grant (idempotent: bitta token faqat bir marta premium beradi) ----
      const r = await getSubscription(req.user.id);
      if (!r) return res.status(403).json({ success: false, error: 'Profil topilmadi' });
      const { data: existing, error: exErr } = await supabaseAdmin
        .from('subscription_events')
        .select('id')
        .eq('purchase_token', tok)
        .maybeSingle();
      if (exErr) throw new Error(`subscription_events o'qishda xato (012 migratsiya yurgizilganmi?): ${exErr.message}`);
      if (existing) return res.json({ success: true, data: r.sub }); // takroriy so'rov — joriy holat

      // Uzaytirish bazasi: amaldagi premium_until (kelajakda bo'lsa) yoki hozir
      const now = Date.now();
      const curUntil = r.sub.premium_until ? new Date(r.sub.premium_until).getTime() : 0;
      const base = curUntil > now ? curUntil : now;
      const newUntil = new Date(base + PREMIUM_DAYS * 24 * 60 * 60 * 1000).toISOString();

      const { error: insErr } = await supabaseAdmin.from('subscription_events').insert({
        user_id: req.user.id,
        provider: 'google_play_dev',
        product_id: pid,
        purchase_token: tok,
        premium_until_after: newUntil,
      });
      if (insErr) {
        // 23505 = unique buzilishi (parallel takroriy so'rov) — joriy holatni qaytaramiz
        if (insErr.code === '23505') return res.json({ success: true, data: r.sub });
        throw new Error(insErr.message);
      }
      const { data: upd, error: updErr } = await supabaseAdmin
        .from('profiles')
        .update({ premium_until: newUntil, updated_at: new Date().toISOString() })
        .eq('id', req.user.id)
        .select('id, created_at, premium_until, deleted_at')
        .single();
      if (updErr) throw new Error(updErr.message);
      res.json({ success: true, data: computeSubscription(upd) });
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

// DELETE /api/profile/me — akkauntni SOFT delete qilish (App Store/Play siyosati talabi).
// Ma'lumotlar O'CHIRILMAYDI: link modelida qarshi tomonning daftari saqlanib qolishi kerak.
// Faqat profiles.deleted_at belgilanadi; qayta kirish (OTP tasdig'i, src/services/otp.js
// reactivateIfDeleted) profilni avtomatik tiklaydi (deleted_at=null) — tiklash oynasi cheksiz.
router.delete('/me', async (req, res, next) => {
  try {
    const nowIso = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('profiles')
      .update({ deleted_at: nowIso, updated_at: nowIso })
      .eq('id', req.user.id);
    if (error) throw new Error(error.message);
    res.json({ success: true, data: { deleted_at: nowIso } });
  } catch (e) {
    next(e);
  }
});

export default router;

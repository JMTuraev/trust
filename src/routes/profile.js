import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();
router.use(requireAuth);

// Trial davomiyligi: ro'yxatdan o'tgandan boshlab 7 kun
const TRIAL_DAYS = 7;

// GET /api/profile/me — profil + hayot sikli maydonlari (soft-delete/trial/premium)
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
      const now = new Date();
      // trial_ends_at = created_at + 7 kun (profiles.created_at 001 migratsiyada default now() bilan bor)
      const trialEndsAt = new Date(new Date(data.created_at).getTime() + TRIAL_DAYS * 24 * 60 * 60 * 1000);
      const premiumUntil = data.premium_until ? new Date(data.premium_until) : null;
      // status: premium (obuna amal qilmoqda) -> trial (7 kun ichida) -> expired
      const status =
        premiumUntil && premiumUntil > now
          ? 'premium'
          : now < trialEndsAt
            ? 'trial'
            : 'expired';
      out = {
        ...data,
        deleted_at: data.deleted_at ?? null,
        trial_ends_at: trialEndsAt.toISOString(),
        premium_until: data.premium_until ?? null,
        status,
      };
    }
    res.json({ success: true, data: out });
  } catch (e) {
    next(e);
  }
});

// PUT /api/profile/me  { "full_name": "...", "avatar_url": "...", "notif_enabled": true|false }
router.put('/me', async (req, res, next) => {
  try {
    const { full_name, avatar_url, notif_enabled } = req.body || {};
    const patch = { updated_at: new Date().toISOString() };
    if (full_name !== undefined) patch.full_name = full_name;
    if (avatar_url !== undefined) patch.avatar_url = avatar_url;
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
// Faqat profiles.deleted_at belgilanadi; qayta kirish (OTP tasdig'i, src/services/otp.js)
// profilni avtomatik tiklaydi (deleted_at=null).
router.delete('/me', async (req, res, next) => {
  try {
    const nowIso = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('profiles')
      .update({ deleted_at: nowIso, updated_at: nowIso })
      .eq('id', req.user.id);
    if (error) throw new Error(error.message);
    res.json({ success: true });
  } catch (e) {
    next(e);
  }
});

export default router;

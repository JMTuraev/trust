// Modul obunalari (PO 2026-08-04) — mobil hub kartalari uchun yagona holat endpointi.
// Har modul alohida oylik obuna: xarajat $5 · qarz $8 · ijarachi $13 · toyxona $24 (har zal).
// Eski $9 premium (profiles.premium_until) — muddati tugaguncha BARCHA modullarga kirish.
// Sotib olish tekshiruvi bu yerda EMAS — u /api/profile/purchase'da (bitta chek oqimi).
import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { getModulesStatus, getSubscription } from '../lib/subscription.js';

const router = Router();
router.use(requireAuth);
// Ilovadagi eng "og'ir" o'qish (profil + module_subs + daftar skani + 3 ta count) —
// mobil buni hydrate'da chaqiradi, shuning uchun alohida cheklov (profile.js naqshi).
router.use(rateLimit({ windowMs: 60_000, max: 30 }));

// GET /api/subs/status — MOBIL KONTRAKT (o'zgartirsangiz mobil store.dart bilan sinxron):
// { success, legacy_premium: { active, until },
//   modules: [{ module, active, active_until, soon, price_usd, product_id, used, free_limit }] }
router.get('/status', async (req, res, next) => {
  try {
    const [r, modules] = await Promise.all([
      getSubscription(req.user.id),
      getModulesStatus(req.user.id),
    ]);
    if (!r) return res.status(403).json({ success: false, error: 'Profil topilmadi' });
    res.json({
      success: true,
      legacy_premium: {
        active: r.sub.status === 'premium',
        until: r.sub.premium_until,
      },
      modules,
    });
  } catch (e) { next(e); }
});

export default router;

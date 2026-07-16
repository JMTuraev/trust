import { Router } from 'express';
import { normalizePhone } from '../lib/phone.js';
import { sendOtp, verifyOtp } from '../services/otp.js';

const router = Router();

// Himoya qatlamlari (src/index.js + services/otp.js):
//   send-otp: IP 3/min (index.js) + per-telefon 60s dedup + butun-servis soatlik SMS cap.
//   verify-otp: IP 10/min (index.js) + DB'da kod boshiga OTP_MAX_ATTEMPTS (default 5) urinish,
//   kod TTL OTP_TTL_SECONDS (default 300s), kod sha256-hash holida saqlanadi.

// POST /api/auth/send-otp  { "phone": "+998901234567" }
router.post('/send-otp', async (req, res, next) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    if (!phone) return res.status(400).json({ success: false, error: "Telefon raqam noto'g'ri" });
    const result = await sendOtp(phone);
    res.json({ success: true, data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/auth/verify-otp  { "phone": "+998901234567", "code": "12345" }
// Muvaffaqiyat: HS256 JWT (sub, phone, role/aud='authenticated', exp=7 kun) — services/otp.js
router.post('/verify-otp', async (req, res, next) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    // Kod: faqat 4-8 xonali raqam (devsms 5, Supabase 6) — begona payloadlar shu yerda to'xtaydi
    const code = String(req.body?.code ?? '').trim();
    if (!phone || !code) return res.status(400).json({ success: false, error: 'phone va code kerak' });
    if (!/^\d{4,8}$/.test(code)) {
      return res.status(400).json({ success: false, error: "Kod noto'g'ri formatda" });
    }
    const session = await verifyOtp(phone, code);
    res.json({ success: true, data: session });
  } catch (e) {
    next(e);
  }
});

export default router;

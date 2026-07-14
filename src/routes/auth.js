import { Router } from 'express';
import { normalizePhone } from '../lib/phone.js';
import { sendOtp, verifyOtp } from '../services/otp.js';

const router = Router();

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

// POST /api/auth/verify-otp  { "phone": "+998901234567", "code": "123456" }
router.post('/verify-otp', async (req, res, next) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    const code = req.body?.code;
    if (!phone || !code) return res.status(400).json({ success: false, error: 'phone va code kerak' });
    const session = await verifyOtp(phone, code);
    res.json({ success: true, data: session });
  } catch (e) {
    next(e);
  }
});

export default router;

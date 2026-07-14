import { Router } from 'express';
import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { transcribe, sttReady } from '../services/stt.js';

const router = Router();
router.use(requireAuth);
router.use(rateLimit({ windowMs: 60_000, max: 20 })); // STT qimmatroq — alohida limit

// POST /api/stt/transcribe  (body: xom audio bayтlar, Content-Type: audio/wav|audio/m4a|...)
// Javob: { success, data: { text, confidence, provider } }
router.post(
  '/transcribe',
  express.raw({ type: () => true, limit: '10mb' }),
  async (req, res, next) => {
    try {
      if (!sttReady()) {
        return res.status(503).json({
          success: false,
          error: "STT sozlanmagan — Render'da GROQ_API_KEY (console.groq.com, bepul) qo'shing",
        });
      }
      const bytes = req.body;
      if (!Buffer.isBuffer(bytes) || bytes.length < 1000) {
        return res.status(400).json({ success: false, error: 'Audio kelmadi yoki juda qisqa' });
      }
      const r = await transcribe(bytes, req.headers['content-type'], req.user.id);
      res.json({ success: true, data: r });
    } catch (e) {
      if (e.detail) console.error('STT detail:', e.detail);
      next(e);
    }
  }
);

export default router;

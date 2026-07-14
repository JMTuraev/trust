import express from 'express';
import cors from 'cors';
import { config, assertConfig } from './config.js';
import { rateLimit } from './middleware/rateLimit.js';
import authRoutes from './routes/auth.js';
import profileRoutes from './routes/profile.js';
import partnerRoutes from './routes/partners.js';
import operationRoutes from './routes/operations.js';
import expenseRoutes from './routes/expenses.js';
import limitRoutes from './routes/limits.js';
import notifRoutes from './routes/notifications.js';

assertConfig();

const app = express();
app.set('trust proxy', 1); // Render/NGINX ortida to'g'ri req.ip uchun
app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '256kb' }));

app.get('/health', (_req, res) => res.json({ ok: true, service: 'trust-backend', version: '2.1' }));

// Auth — qattiqroq limit (SMS xarajati va brute-force'dan himoya)
app.use('/api/auth', rateLimit({ windowMs: 60_000, max: 10 }), authRoutes);
app.use('/api', rateLimit({ windowMs: 60_000, max: 120 }));
app.use('/api/profile', profileRoutes);
app.use('/api/partners', partnerRoutes);
app.use('/api/operations', operationRoutes);
app.use('/api/expenses', expenseRoutes);
app.use('/api/limits', limitRoutes);
app.use('/api/notifications', notifRoutes);

app.use((_req, res) => res.status(404).json({ success: false, error: 'Endpoint topilmadi' }));
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({ success: false, error: err.message || 'Server xatosi' });
});

const server = app.listen(config.port, () =>
  console.log(`trust-backend ${config.port}-portda ishga tushdi (v2.1)`)
);

// Render/Docker SIGTERM yuboradi — ochiq so'rovlarni yakunlab chiqamiz
for (const sig of ['SIGTERM', 'SIGINT']) {
  process.on(sig, () => {
    console.log(`${sig} qabul qilindi — server yopilmoqda...`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10_000).unref();
  });
}

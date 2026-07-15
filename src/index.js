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
import sttRoutes from './routes/stt.js';
import categoryRoutes from './routes/categories.js';
import linkRoutes from './routes/links.js';
import messageRoutes from './routes/messages.js';
import debtRoutes from './routes/debts.js';
import { startRejectSignalSweeper } from './services/rejectSignal.js';

assertConfig();

const app = express();
app.set('trust proxy', true); // Render bir necha proxy hop ortida — leftmost X-Forwarded-For (haqiqiy client) uchun
app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '256kb' }));

app.get('/health', (_req, res) => res.json({ ok: true, service: 'trust-backend', version: '3.2' }));

// So'rov kuzatuvi — health'dan tashqari har so'rov usuli+yo'li (parse/expenses kabi jonli ko'rinadi)
app.use((req, _res, next) => { if (req.path !== '/health') console.log(`→ ${req.method} ${req.path}`); next(); });

// Auth limitlar (ko'p qatlamli, toll-fraud + brute-force himoyasi):
//  - send-otp: IP bo'yicha 3/min — botni sekinlashtiradi, axlat so'rovlarni to'sadi.
//    BUTUN-servis SMS capi endi otp.js ichida, HAQIQIY yuborishdan oldin sanaladi
//    (middleware'da bo'lgani login-DoS ochardi: axlat so'rovlar global byudjetni yeyardi).
//  - qolgan auth: IP bo'yicha 10/min.
app.use('/api/auth/send-otp', rateLimit({ windowMs: 60_000, max: 3 }));
app.use('/api/auth', rateLimit({ windowMs: 60_000, max: 10 }), authRoutes);
app.use('/api', rateLimit({ windowMs: 60_000, max: 120 }));
app.use('/api/profile', profileRoutes);
app.use('/api/partners', partnerRoutes);
app.use('/api/operations', operationRoutes);
app.use('/api/expenses', expenseRoutes);
app.use('/api/limits', limitRoutes);
app.use('/api/notifications', notifRoutes);
app.use('/api/stt', sttRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/links', linkRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/debts', debtRoutes);

app.use((_req, res) => res.status(404).json({ success: false, error: 'Endpoint topilmadi' }));
app.use((err, _req, res, _next) => {
  console.error(err);
  const status = err.status || 500;
  // 4xx — bizning validatsiya xabarlarimiz (foydalanuvchiga tushunarli, o'zbekcha).
  // 5xx — ichki xato: DB/sxema tafsilotlari mijozga oshkor bo'lmasin (info disclosure).
  const clientMsg = status < 500 ? (err.message || 'So\'rov xato') : 'Server xatosi — birozdan keyin urinib ko\'ring';
  res.status(status).json({ success: false, error: clientMsg });
});

const server = app.listen(config.port, () =>
  console.log(`trust-backend ${config.port}-portda ishga tushdi (v3.0)`)
);

// Kechiktirilgan rad signallari (link modeli)
startRejectSignalSweeper();

// Render/Docker SIGTERM yuboradi — ochiq so'rovlarni yakunlab chiqamiz
for (const sig of ['SIGTERM', 'SIGINT']) {
  process.on(sig, () => {
    console.log(`${sig} qabul qilindi — server yopilmoqda...`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10_000).unref();
  });
}

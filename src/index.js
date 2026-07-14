import express from 'express';
import cors from 'cors';
import { config, assertConfig } from './config.js';
import authRoutes from './routes/auth.js';
import profileRoutes from './routes/profile.js';
import debtRoutes from './routes/debts.js';

assertConfig();

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.json({ ok: true, service: 'trust-backend' }));

app.use('/api/auth', authRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/debts', debtRoutes);

// 404
app.use((_req, res) => res.status(404).json({ success: false, error: 'Endpoint topilmadi' }));

// Xatolik handleri
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({ success: false, error: err.message || 'Server xatosi' });
});

app.listen(config.port, () => {
  console.log(`trust-backend ${config.port}-portda ishga tushdi`);
});

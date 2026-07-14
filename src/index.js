import express from 'express';
import cors from 'cors';
import { config, assertConfig } from './config.js';
import authRoutes from './routes/auth.js';
import profileRoutes from './routes/profile.js';
import partnerRoutes from './routes/partners.js';
import operationRoutes from './routes/operations.js';
import expenseRoutes from './routes/expenses.js';
import limitRoutes from './routes/limits.js';
import notifRoutes from './routes/notifications.js';

assertConfig();

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.json({ ok: true, service: 'trust-backend', version: '2.0' }));

app.use('/api/auth', authRoutes);
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

app.listen(config.port, () => console.log(`trust-backend ${config.port}-portda ishga tushdi (v2.0)`));

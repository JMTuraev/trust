import jwt from 'jsonwebtoken';
import { config } from '../config.js';

export function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ success: false, error: 'Token kerak' });
  try {
    const payload = jwt.verify(token, config.app.jwtSecret, { audience: 'authenticated' });
    req.user = { id: payload.sub, phone: payload.phone };
    next();
  } catch {
    return res.status(401).json({ success: false, error: "Token yaroqsiz yoki muddati o'tgan" });
  }
}

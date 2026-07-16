#!/usr/bin/env node
// TEST JWT imzolash — faqat E2E tekshiruv uchun. .env'ni O'ZI o'qiydi (dotenv),
// hech qanday sir chop etilmaydi — chiqishda FAQAT imzolangan token.
//
// Ishlatish (REPO ROOT'dan, .env va node_modules shu yerda):
//   node docs/team-reports/e2e/sign-test-jwt.mjs <user_id> [phone]
// Misollar (fixture userlar, qarang: docs/team-reports/2026-07-16-partners.md):
//   node docs/team-reports/e2e/sign-test-jwt.mjs 11111111-1111-4111-8111-111111111101 998900000001
//   node docs/team-reports/e2e/sign-test-jwt.mjs 11111111-1111-4111-8111-111111111102 998900000002
import 'dotenv/config';
import jwt from 'jsonwebtoken';

const [, , sub, phone] = process.argv;
if (!sub) {
  console.error('Foydalanish: node docs/team-reports/e2e/sign-test-jwt.mjs <user_id> [phone]');
  process.exit(1);
}
const secret = process.env.APP_JWT_SECRET;
if (!secret) {
  console.error(".env da APP_JWT_SECRET topilmadi — repo root'dan ishga tushiring");
  process.exit(1);
}

const now = Math.floor(Date.now() / 1000);
// src/services/otp.js issueSession bilan BIR XIL claim'lar (auth middleware talablari:
// HS256, aud='authenticated', sub=<profiles.id>, phone=<raqamlar, + siz>). exp: 2 soat.
const token = jwt.sign(
  {
    sub,
    phone: phone || '998900000001',
    role: 'authenticated',
    aud: 'authenticated',
    iat: now,
    exp: now + 2 * 3600,
  },
  secret
);
console.log(token);

// Haqiqiy klient IP'si — rate limit kaliti uchun (middleware/rateLimit.js).
//
// 2026-09-08: backend api.trustbook.uz orqali Cloudflare proxy ortiga qo'yildi
// (O'zbekiston tarmoqlari onrender.com'ga ba'zan ulanolmaydi). Endi zanjir:
//   klient -> Cloudflare -> Render proxy -> Express.
// `trust proxy = 1` bilan req.ip = CLOUDFLARE chekka IP'si bo'lib qoladi — barcha
// foydalanuvchilar bir nechta IP'ga yig'iladi va per-IP limitlar (OTP 3/min!)
// hammani birdan bloklaydi. Cloudflare haqiqiy IP'ni `cf-connecting-ip` sarlavhasida
// beradi, LEKIN bu sarlavhaga faqat so'rov ROSTDAN Cloudflare'dan kelganda ishonamiz:
// req.ip (Render ko'rgan eng yaqin manzil) Cloudflare diapazonida bo'lsa. Aks holda
// (to'g'ridan-to'g'ri onrender.com) sarlavha spoof qilinishi mumkin — e'tiborsiz.
//
// Diapazonlar: https://www.cloudflare.com/ips/ (kamdan-kam o'zgaradi).
import { BlockList, isIP } from 'node:net';

const CF_V4 = [
  '173.245.48.0/20', '103.21.244.0/22', '103.22.200.0/22', '103.31.4.0/22',
  '141.101.64.0/18', '108.162.192.0/18', '190.93.240.0/20', '188.114.96.0/20',
  '197.234.240.0/22', '198.41.128.0/17', '162.158.0.0/15', '104.16.0.0/13',
  '104.24.0.0/14', '172.64.0.0/13', '131.0.72.0/22',
];
const CF_V6 = [
  '2400:cb00::/32', '2606:4700::/32', '2803:f800::/32', '2405:b500::/32',
  '2405:8100::/32', '2a06:98c0::/29', '2c0f:f248::/32',
];

const cf = new BlockList();
for (const c of CF_V4) { const [a, p] = c.split('/'); cf.addSubnet(a, Number(p), 'ipv4'); }
for (const c of CF_V6) { const [a, p] = c.split('/'); cf.addSubnet(a, Number(p), 'ipv6'); }

/** "::ffff:1.2.3.4" -> "1.2.3.4" (Express IPv4-mapped IPv6 qaytarishi mumkin). */
function norm(ip) {
  if (!ip) return '';
  return ip.startsWith('::ffff:') ? ip.slice(7) : ip;
}

/** Manzil Cloudflare chekka diapazonida bo'lsa true. */
export function isCloudflareIp(ip) {
  const a = norm(ip);
  const fam = isIP(a);
  if (fam === 4) return cf.check(a, 'ipv4');
  if (fam === 6) return cf.check(a, 'ipv6');
  return false;
}

/** Rate limit uchun klient IP'si. Cloudflare orqali kelsa — cf-connecting-ip, aks holda req.ip. */
export function clientIp(req) {
  const near = norm(req.ip);
  if (isCloudflareIp(near)) {
    const real = norm(req.get?.('cf-connecting-ip') || req.headers?.['cf-connecting-ip']);
    if (isIP(real)) return real;
  }
  return near || 'unknown';
}

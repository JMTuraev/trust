// Oddiy xotira-ichi rate limit (bitta instans uchun yetarli — Render/VPS).
// Har rateLimit() O'Z bucket'iga ega — endpoint chegaralari bir-birini yemaydi
// (aks holda global /api limiter va /parse limiter bitta bucketni ikki marta sanardi).
const allBuckets = [];

// global:true — IP bo'yicha emas, BUTUN servis bo'yicha yagona hisoblagich.
// SMS toll-fraud himoyasi: botnet turli IP/raqam bilan ham umumiy capdan osha olmaydi.
export function rateLimit({ windowMs = 60_000, max = 10, global = false } = {}) {
  const buckets = new Map();
  allBuckets.push(buckets);
  return (req, res, next) => {
    const key = global ? '__all__' : (req.ip || 'unknown');
    const now = Date.now();
    let b = buckets.get(key);
    if (!b || now - b.start > windowMs) {
      b = { start: now, count: 0 };
      buckets.set(key, b);
    }
    b.count += 1;
    if (b.count > max) {
      return res.status(429).json({ success: false, error: "So'rovlar juda ko'p — birozdan keyin urinib ko'ring" });
    }
    next();
  };
}

// Xotira o'smasligi uchun barcha bucket'lardagi eski yozuvlarni tozalash
setInterval(() => {
  const now = Date.now();
  for (const buckets of allBuckets) {
    for (const [k, b] of buckets) {
      if (now - b.start > 10 * 60_000) buckets.delete(k);
    }
  }
}, 5 * 60_000).unref();

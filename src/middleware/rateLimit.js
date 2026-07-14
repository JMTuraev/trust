// Oddiy xotira-ichi rate limit (bitta instans uchun yetarli — Render/VPS).
// Har IP uchun oynada eng ko'p `max` ta so'rov.
const buckets = new Map();

export function rateLimit({ windowMs = 60_000, max = 10 } = {}) {
  return (req, res, next) => {
    const key = req.ip || 'unknown';
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

// Xotira o'smasligi uchun eski yozuvlarni vaqti-vaqti bilan tozalash
setInterval(() => {
  const now = Date.now();
  for (const [k, b] of buckets) {
    if (now - b.start > 10 * 60_000) buckets.delete(k);
  }
}, 5 * 60_000).unref();

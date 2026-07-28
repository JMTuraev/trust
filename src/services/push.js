// FCM push yuborish (Firebase Admin SDK, HTTP v1).
// Fail-soft: kalit berilmagan / paket o'rnatilmagan bo'lsa server ISHLAYVERADI,
// faqat push yuborilmaydi (AI kaliti naqshi bilan bir xil — config.js assertConfig izohi).
// Kalit QIYMATI hech qachon loglanmaydi.
import { config } from '../config.js';
import { supabaseAdmin } from '../lib/supabase.js';

let _messaging = null;
let _tried = false;

async function messaging() {
  if (_messaging || _tried) return _messaging;
  _tried = true;
  const hasInline = !!config.fcm.serviceAccountJson;
  const hasFile = !!process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!hasInline && !hasFile) {
    console.warn("FCM o'chiq: FCM_SERVICE_ACCOUNT_JSON yoki GOOGLE_APPLICATION_CREDENTIALS yo'q — push yuborilmaydi");
    return null;
  }
  try {
    // Dinamik import: firebase-admin o'rnatilmagan bo'lsa ham server ko'tarilsin
    const admin = (await import('firebase-admin')).default;
    const cred = hasInline
      ? admin.credential.cert(JSON.parse(config.fcm.serviceAccountJson))
      : admin.credential.applicationDefault(); // GOOGLE_APPLICATION_CREDENTIALS fayl yo'li
    admin.initializeApp({ credential: cred });
    _messaging = admin.messaging();
    console.log('FCM push tayyor');
  } catch (e) {
    console.error("FCM init xatosi (push o'chiq):", e.message);
  }
  return _messaging;
}

// Foydalanuvchining BARCHA qurilmalariga push. HECH QACHON throw qilmaydi —
// chaqiruvchi joylar await'siz (fire-and-forget) ishlatadi, javob kechikmaydi.
export async function pushToUser(userId, { title, body, data = {} }) {
  try {
    const m = await messaging();
    if (!m || !userId) return;
    const { data: rows, error } = await supabaseAdmin
      .from('device_tokens').select('token').eq('user_id', userId);
    if (error || !rows?.length) return;

    const res = await m.sendEachForMulticast({
      tokens: rows.map((r) => r.token),
      notification: { title, body },
      // FCM data qiymatlari FAQAT string bo'lishi kerak
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      android: { priority: 'high' },
    });

    // O'lik tokenlarni tozalash (ilova o'chirilgan / token bekor qilingan qurilmalar)
    const dead = [];
    res.responses.forEach((r, i) => {
      const code = r.error?.code || '';
      if (!r.success && (code.includes('registration-token-not-registered') || code.includes('invalid-argument'))) {
        dead.push(rows[i].token);
      }
    });
    if (dead.length) await supabaseAdmin.from('device_tokens').delete().in('token', dead);
  } catch (e) {
    console.error('push xatosi:', e.message);
  }
}

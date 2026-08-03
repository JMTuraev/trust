import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { supabaseAdmin, supabaseAnon } from '../lib/supabase.js';
import { sendOtpSms } from './devsms.js';
import { isUzbekPhone } from '../lib/phone.js';

const hash = (s) => crypto.createHash('sha256').update(s).digest('hex');

function generateCode() {
  // 5 xonali — mobil ilovadagi OTP kataklari (5 ta) bilan mos
  return String(crypto.randomInt(10000, 100000));
}

// ---------- Global SMS toll-fraud capi ----------
// MUHIM: faqat HAQIQATAN yuboriladigan SMS'lar sanaladi (validatsiya + per-telefon dedupdan KEYIN).
// Shu bois axlat/takroriy so'rovlar butun tizim byudjetini yeb, haqiqiy foydalanuvchilarni
// OTP'siz qoldirolmaydi (bu — capni middleware sifatida qo'yishdagi login-DoS xatosini yopadi).
const SMS_GLOBAL_CAP = parseInt(process.env.SMS_GLOBAL_HOURLY_CAP || '200', 10);
let smsWindow = { start: 0, count: 0 };
function reserveGlobalSmsSlot() {
  const now = Date.now();
  if (now - smsWindow.start > 3600_000) smsWindow = { start: now, count: 0 };
  if (smsWindow.count >= SMS_GLOBAL_CAP) {
    const e = new Error("Tizim vaqtincha band — birozdan keyin qayta urinib ko'ring");
    e.status = 503;
    throw e;
  }
  smsWindow.count++;
}

// ---------- OTP yuborish ----------
export async function sendOtp(phone) {
  // Do'kon review test-login: aynan shu raqamga HAQIQIY SMS yuborilmaydi (kod qat'iy,
  // config.otp.reviewCode). Faqat REVIEW_TEST_PHONE bilan bir xil raqamga ta'sir qiladi.
  if (config.otp.reviewPhone && phone === config.otp.reviewPhone) {
    return { provider: 'review', expires_in: config.otp.ttlSeconds };
  }

  // Per-telefon 60s dedup — MUHIM (2026-08-02 audit): ilgari bu tekshiruv FAQAT
  // isUzbekPhone shoxida edi, ya'ni xalqaro raqamlar uchun na dedup, na global cap
  // ishlardi. Botnet 3/min/IP bilan cheksiz xalqaro SMS "yoqib" yuborishi mumkin edi.
  const { data: recent } = await supabaseAdmin
    .from('otp_codes')
    .select('id, created_at')
    .eq('phone', phone)
    .gte('created_at', new Date(Date.now() - 60_000).toISOString())
    .limit(1);
  if (recent?.length) {
    const err = new Error("Iltimos, 1 daqiqadan keyin qayta urinib ko'ring");
    err.status = 429;
    throw err;
  }

  if (isUzbekPhone(phone)) {
    // O'zbekiston: devsms.uz (AllClubs shabloni)
    const code = generateCode();
    const expiresAt = new Date(Date.now() + config.otp.ttlSeconds * 1000).toISOString();

    // Eski kodlarni o'chirish va yangisini yozish
    await supabaseAdmin.from('otp_codes').delete().eq('phone', phone);
    const { error } = await supabaseAdmin.from('otp_codes').insert({
      phone,
      code_hash: hash(code),
      expires_at: expiresAt,
    });
    if (error) throw new Error(`DB xatosi: ${error.message}`);

    // Global cap — endi, haqiqiy SMS yuborishdan bevosita oldin (validatsiya+dedupdan keyin).
    reserveGlobalSmsSlot();
    await sendOtpSms(phone, code);
    return { provider: 'devsms', expires_in: config.otp.ttlSeconds };
  }

  // Boshqa davlatlar: Supabase'ning o'z OTP servisi.
  // Dedup yozuvi (kod hash'isiz — tekshirishni Supabase qiladi) + global cap:
  // ikkalasi ham xalqaro yo'nalishda ham toll-fraud'ni cheklaydi.
  reserveGlobalSmsSlot();
  const { error } = await supabaseAnon.auth.signInWithOtp({ phone: `+${phone}` });
  if (error) {
    const err = new Error(`Supabase OTP xatosi: ${error.message}`);
    err.status = 502;
    throw err;
  }
  // Muvaffaqiyatli yuborilgandan KEYIN dedup markerini yozamiz (provayder tushib qolsa
  // foydalanuvchi 60 soniyaga bekorga bloklanmasin).
  await supabaseAdmin.from('otp_codes').delete().eq('phone', phone);
  await supabaseAdmin.from('otp_codes').insert({
    phone,
    code_hash: `supabase:${crypto.randomUUID()}`, // bu yo'lda kod bizda saqlanmaydi
    expires_at: new Date(Date.now() + 60_000).toISOString(),
  });
  return { provider: 'supabase', expires_in: 60 };
}

// ---------- Do'kon-review bypass himoyasi ----------
// MUHIM (2026-08-02 audit): review kodi otp_codes'ga yozilmaydi, ya'ni unga urinishlar
// limiti, muddat va bloklash UMUMAN qo'llanmasdi — faqat 10/min/IP limiter qolardi.
// 5 xonali kod uchun bu yetarli emas. Quyida butun servis bo'yicha soatlik urinish capi
// va vaqt bo'yicha xavfsiz taqqoslash qo'shildi (kod uzunligi o'zgartirilmaydi —
// jonli App Store review'ini buzmaslik uchun).
const REVIEW_TRY_CAP = parseInt(process.env.REVIEW_TRY_HOURLY_CAP || '20', 10);
let reviewWindow = { start: 0, count: 0 };
function reviewCodeMatches(code) {
  const expected = config.otp.reviewCode;
  if (!expected) return false;
  const now = Date.now();
  if (now - reviewWindow.start > 3600_000) reviewWindow = { start: now, count: 0 };
  reviewWindow.count++;
  if (reviewWindow.count > REVIEW_TRY_CAP) {
    const e = new Error("Urinishlar soni tugadi. Birozdan keyin qayta urinib ko'ring.");
    e.status = 429;
    throw e;
  }
  const a = Buffer.from(String(code));
  const b = Buffer.from(String(expected));
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}
if (config.otp.reviewCode && String(config.otp.reviewCode).length < 8) {
  console.warn('[xavfsizlik] REVIEW_TEST_CODE juda qisqa — review tugagach uni Render '
    + "Dashboard'dan o'chiring yoki kamida 12 belgili tasodifiy qiymatga almashtiring");
}

// ---------- Urinishni ATOMAR "band qilish" ----------
// MUHIM (2026-08-02 audit): ilgari attempts oddiy read-modify-write bilan oshirilardi
// (select -> hisobla -> update). 10 ta PARALLEL so'rov hammasi attempts=0 ni ko'rib,
// hammasi capdan o'tib ketardi — ya'ni 5 urinish limiti amalda ishlamas edi
// (5 xonali kod = 90 000 variant, limit ishlamasa brute-force real bo'lib qoladi).
// Endi urinish TAQQOSLASHDAN OLDIN, shartli (CAS) update bilan band qilinadi:
// bir vaqtda faqat bittasi `attempts` ni oshira oladi, qolganlari 429 oladi.
async function reserveOtpAttempt(rec, fail) {
  if (rec.attempts >= config.otp.maxAttempts) {
    throw fail("Urinishlar soni tugadi. Qaytadan so'rang.", 429);
  }
  const { data: won, error } = await supabaseAdmin
    .from('otp_codes')
    .update({ attempts: rec.attempts + 1 })
    .eq('id', rec.id)
    .eq('attempts', rec.attempts) // <- CAS: kutilgan qiymat
    .select('id');
  if (error) throw new Error(`DB xatosi: ${error.message}`);
  if (!won?.length) {
    // Poyga yutqazildi (boshqa so'rov ayni shu paytda oshirdi) yoki yozuv o'chdi.
    throw fail("Juda ko'p urinish — birozdan keyin qayta urinib ko'ring", 429);
  }
}

// ---------- OTP tekshirish ----------
export async function verifyOtp(phone, code) {
  // Do'kon review test-login: aynan shu raqam + qat'iy kod => darhol session.
  // SMS/DB kod tekshiruvidan o'tmaydi; boshqa raqamlarga umuman ta'sir qilmaydi.
  if (config.otp.reviewPhone && phone === config.otp.reviewPhone) {
    if (reviewCodeMatches(code)) {
      const user = await findOrCreateUser(phone);
      await reactivateIfDeleted(user.id);
      return issueSession(user);
    }
    const e = new Error("Kod noto'g'ri");
    e.status = 400;
    throw e;
  }

  if (isUzbekPhone(phone)) {
    const { data: rows, error } = await supabaseAdmin
      .from('otp_codes')
      .select('*')
      .eq('phone', phone)
      .order('created_at', { ascending: false })
      .limit(1);
    if (error) throw new Error(`DB xatosi: ${error.message}`);

    const rec = rows?.[0];
    const fail = (msg, status = 400) => {
      const e = new Error(msg);
      e.status = status;
      return e;
    };
    if (!rec) throw fail("Kod topilmadi. Qaytadan so'rang.");
    if (new Date(rec.expires_at) < new Date()) throw fail("Kod muddati tugagan. Qaytadan so'rang.");

    // Urinishni AVVAL band qilamiz — taqqoslashdan oldin (yuqoridagi izohga qarang).
    await reserveOtpAttempt(rec, fail);
    if (rec.code_hash !== hash(String(code))) throw fail("Kod noto'g'ri");

    await supabaseAdmin.from('otp_codes').delete().eq('id', rec.id);
    const user = await findOrCreateUser(phone);
    await reactivateIfDeleted(user.id); // qayta kirish = qayta faollashish
    return issueSession(user);
  }

  // Xalqaro: Supabase OTP ni tekshiradi, biz o'z session tokenimizni beramiz
  const { data, error } = await supabaseAnon.auth.verifyOtp({
    phone: `+${phone}`,
    token: String(code),
    type: 'sms',
  });
  if (error) {
    const err = new Error(error.message);
    err.status = 400;
    throw err;
  }
  const user = await findOrCreateUser(phone);
  await reactivateIfDeleted(user.id); // qayta kirish = qayta faollashish
  return issueSession(user);
}

// ---------- Yordamchilar ----------

// Soft-delete'ni tiklash: foydalanuvchi akkauntini o'chirgan bo'lsa (profiles.deleted_at,
// 008 migratsiya), muvaffaqiyatli OTP bilan qayta kirish = akkauntni qayta faollashtirish.
// Soft-delete'da ma'lumotlar o'chirilmagani uchun daftar/bog'lanishlar joyida qoladi (link modeli).
async function reactivateIfDeleted(userId) {
  await supabaseAdmin
    .from('profiles')
    .update({ deleted_at: null, updated_at: new Date().toISOString() })
    .eq('id', userId)
    .not('deleted_at', 'is', null); // faqat o'chirilgan profilga tegamiz
}

// Yangi ro'yxatdan o'tgan foydalanuvchini uni oldindan kontragent qilib qo'shganlarga bog'lash.
// (004 migratsiyadagi trigger ham shu ishni qiladi — bu kod eski profillar uchun zaxira.)
// Qaror mijozda: unga har bir pending bog'lanish uchun 'link_new' bildirishnoma boradi.
async function linkPartners(user) {
  const { data: linked } = await supabaseAdmin
    .from('partners')
    .update({ counterparty_id: user.id, updated_at: new Date().toISOString() })
    .eq('counterparty_phone', user.phone)
    .is('counterparty_id', null)
    .select('id, owner_id, link_status');
  for (const p of linked || []) {
    if (p.link_status !== 'pending') continue;
    const { data: exists } = await supabaseAdmin.from('notifications')
      .select('id').eq('link_id', p.id).eq('type', 'link_new').limit(1);
    if (exists?.length) continue;
    const { data: seller } = await supabaseAdmin
      .from('profiles').select('full_name, phone').eq('id', p.owner_id).maybeSingle();
    const who = (seller?.full_name || '').trim() || `+${seller?.phone || ''}`;
    await supabaseAdmin.from('notifications').insert({
      user_id: user.id,
      sender_id: p.owner_id,
      type: 'link_new',
      title: 'Sizni kontragent qilib qo\'shishdi',
      detail: `${who} sizni kontragent qilib qo'shgan — qabul qilasizmi?`,
      link_id: p.id,
    });
  }
}

async function findOrCreateUser(phone) {
  // Profiles jadvalidan qidirish
  const { data: prof } = await supabaseAdmin
    .from('profiles')
    .select('id, phone')
    .eq('phone', phone)
    .maybeSingle();
  if (prof) {
    await linkPartners({ id: prof.id, phone });
    return { id: prof.id, phone };
  }

  // Auth'da yaratish (profil trigger orqali yaratiladi)
  const { data, error } = await supabaseAdmin.auth.admin.createUser({
    phone: `+${phone}`,
    phone_confirm: true,
  });
  if (error) {
    // Allaqachon mavjud bo'lsa - topamiz
    if (String(error.message).toLowerCase().includes('already')) {
      const { data: list } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 });
      const u = list?.users?.find((x) => (x.phone || '').replace(/\D/g, '') === phone);
      if (u) {
        await linkPartners({ id: u.id, phone });
        return { id: u.id, phone };
      }
    }
    throw new Error(`Foydalanuvchi yaratishda xato: ${error.message}`);
  }
  const user = { id: data.user.id, phone };
  await linkPartners(user);
  return user;
}

function issueSession(user) {
  const now = Math.floor(Date.now() / 1000);
  const access_token = jwt.sign(
    {
      sub: user.id,
      phone: user.phone,
      role: 'authenticated',
      aud: 'authenticated',
      iat: now,
      exp: now + 60 * 60 * 24 * 7, // 7 kun
    },
    config.app.jwtSecret
  );
  return { access_token, refresh_token: null, user };
}

// ---------- Kodni faqat TEKSHIRISH (sessiya YARATMAYDI) ----------
// Profil o'chirish kabi "tasdiqlash" oqimlari uchun: kod to'g'ri bo'lsa true,
// aks holda xato otadi (verifyOtp bilan bir xil xabarlar). Urinishlar hisobi,
// muddat va bir-martalik (kod o'chishi) verifyOtp bilan AYNAN bir xil.
export async function checkOtpCode(phone, code) {
  if (config.otp.reviewPhone && phone === config.otp.reviewPhone) {
    if (reviewCodeMatches(code)) return true;
    const e = new Error("Kod noto'g'ri");
    e.status = 400;
    throw e;
  }
  if (isUzbekPhone(phone)) {
    const { data: rows, error } = await supabaseAdmin
      .from('otp_codes')
      .select('*')
      .eq('phone', phone)
      .order('created_at', { ascending: false })
      .limit(1);
    if (error) throw new Error(`DB xatosi: ${error.message}`);
    const rec = rows?.[0];
    const fail = (msg, status = 400) => {
      const e = new Error(msg);
      e.status = status;
      return e;
    };
    if (!rec) throw fail("Kod topilmadi. Qaytadan so'rang.");
    if (new Date(rec.expires_at) < new Date()) throw fail("Kod muddati tugagan. Qaytadan so'rang.");
    await reserveOtpAttempt(rec, fail);
    if (rec.code_hash !== hash(String(code))) throw fail("Kod noto'g'ri");
    await supabaseAdmin.from('otp_codes').delete().eq('id', rec.id);
    return true;
  }
  // Xalqaro: Supabase tekshiradi (qaytgan sessiya ishlatilmaydi)
  const { error } = await supabaseAnon.auth.verifyOtp({
    phone: `+${phone}`,
    token: String(code),
    type: 'sms',
  });
  if (error) {
    const err = new Error(error.message);
    err.status = 400;
    throw err;
  }
  return true;
}

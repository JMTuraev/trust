import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { supabaseAdmin, supabaseAnon } from '../lib/supabase.js';
import { sendOtpSms } from './devsms.js';
import { isUzbekPhone } from '../lib/phone.js';

const hash = (s) => crypto.createHash('sha256').update(s).digest('hex');

function generateCode() {
  return String(crypto.randomInt(100000, 1000000)); // 6 xonali
}

// ---------- OTP yuborish ----------
export async function sendOtp(phone) {
  if (isUzbekPhone(phone)) {
    // O'zbekiston: devsms.uz (AllClubs shabloni)
    // Rate limit: oxirgi 60 soniyada yuborilgan bo'lsa - rad
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

    await sendOtpSms(phone, code);
    return { provider: 'devsms', expires_in: config.otp.ttlSeconds };
  }

  // Boshqa davlatlar: Supabase'ning o'z OTP servisi
  const { error } = await supabaseAnon.auth.signInWithOtp({ phone: `+${phone}` });
  if (error) {
    const err = new Error(`Supabase OTP xatosi: ${error.message}`);
    err.status = 502;
    throw err;
  }
  return { provider: 'supabase', expires_in: 60 };
}

// ---------- OTP tekshirish ----------
export async function verifyOtp(phone, code) {
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
    if (rec.attempts >= config.otp.maxAttempts) throw fail("Urinishlar soni tugadi. Qaytadan so'rang.", 429);

    if (rec.code_hash !== hash(String(code))) {
      await supabaseAdmin
        .from('otp_codes')
        .update({ attempts: rec.attempts + 1 })
        .eq('id', rec.id);
      throw fail("Kod noto'g'ri");
    }

    await supabaseAdmin.from('otp_codes').delete().eq('id', rec.id);
    const user = await findOrCreateUser(phone);
    return issueSession(user);
  }

  // Xalqaro: Supabase o'zi tekshiradi va session qaytaradi
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
  return {
    access_token: data.session.access_token,
    refresh_token: data.session.refresh_token,
    user: { id: data.user.id, phone: data.user.phone },
  };
}

// ---------- Yordamchilar ----------
async function findOrCreateUser(phone) {
  // Profiles jadvalidan qidirish
  const { data: prof } = await supabaseAdmin
    .from('profiles')
    .select('id, phone')
    .eq('phone', phone)
    .maybeSingle();
  if (prof) return { id: prof.id, phone };

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
      if (u) return { id: u.id, phone };
    }
    throw new Error(`Foydalanuvchi yaratishda xato: ${error.message}`);
  }
  return { id: data.user.id, phone };
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
    config.supabase.jwtSecret
  );
  return { access_token, refresh_token: null, user };
}

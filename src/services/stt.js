// STT (ovoz -> matn) — XOTIRA-ovoz-va-kategoriya.md bo'yicha:
// ASOSIY: Groq whisper-large-v3; ZAXIRA: OpenAI gpt-4o-transcribe.
// Interfeys: transcribe(bytes, mime) -> { text, confidence, provider }
// Ikkalasi yiqilsa: audio Supabase Storage'ga saqlanadi (keyin qayta ishlash uchun).
import { config } from '../config.js';
import { supabaseAdmin } from '../lib/supabase.js';

export function sttReady() {
  return !!(config.stt.groqKey || config.stt.openaiKey);
}

async function callWhisper({ url, key, model, bytes, mime, verbose, timeoutMs }) {
  const fd = new FormData();
  fd.append('file', new Blob([bytes], { type: mime || 'audio/wav' }), 'audio.wav');
  fd.append('model', model);
  fd.append('language', 'uz');
  fd.append('temperature', '0');
  if (verbose) fd.append('response_format', 'verbose_json');
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}` },
    body: fd,
    signal: AbortSignal.timeout(timeoutMs),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data?.error?.message || `HTTP ${res.status}`);
  // avg_logprob -> taxminiy ishonch (0..1)
  const segs = Array.isArray(data.segments) ? data.segments : [];
  const avg = segs.length
    ? segs.reduce((s, x) => s + (typeof x.avg_logprob === 'number' ? x.avg_logprob : -1), 0) / segs.length
    : null;
  const confidence = avg === null ? 0.9 : Math.max(0, Math.min(1, Math.exp(avg)));
  return { text: String(data.text || '').trim(), confidence };
}

async function saveForLater(bytes, userId, mime) {
  try {
    await supabaseAdmin.storage.createBucket('voice', { public: false }).catch(() => {});
    const { error } = await supabaseAdmin.storage
      .from('voice')
      .upload(`${userId}/${Date.now()}.wav`, Buffer.from(bytes), {
        contentType: mime || 'audio/wav',
        upsert: false,
      });
    return !error;
  } catch {
    return false;
  }
}

export async function transcribe(bytes, mime, userId) {
  const errors = [];

  // 1) Groq (asosiy) — ~8s timeout, past ishonch/bo'sh matnda zaxiraga o'tamiz
  let groqRes = null;
  if (config.stt.groqKey) {
    try {
      groqRes = await callWhisper({
        url: 'https://api.groq.com/openai/v1/audio/transcriptions',
        key: config.stt.groqKey,
        model: 'whisper-large-v3',
        bytes, mime, verbose: true, timeoutMs: 8000,
      });
      if (groqRes.text && (groqRes.confidence >= 0.5 || !config.stt.openaiKey)) {
        return { ...groqRes, provider: 'groq' };
      }
      errors.push(groqRes.text ? 'groq: past ishonch' : "groq: bo'sh matn");
    } catch (e) {
      errors.push(`groq: ${e.message}`);
    }
  }

  // 2) OpenAI (zaxira) — og'ir holatlar uchun to'liq model
  if (config.stt.openaiKey) {
    try {
      const r = await callWhisper({
        url: 'https://api.openai.com/v1/audio/transcriptions',
        key: config.stt.openaiKey,
        model: 'gpt-4o-transcribe',
        bytes, mime, verbose: false, timeoutMs: 15000,
      });
      if (r.text) return { ...r, provider: 'openai' };
      errors.push("openai: bo'sh matn");
    } catch (e) {
      errors.push(`openai: ${e.message}`);
    }
  }

  // Groq matn bergan bo'lsa (past ishonch bilan) — baribir qaytaramiz, ilova tasdiqlatadi
  if (groqRes?.text) return { ...groqRes, provider: 'groq' };

  // 3) Hammasi yiqildi — audio saqlab qo'yamiz, foydalanuvchiga aniq xabar
  const saved = userId ? await saveForLater(bytes, userId, mime) : false;
  const err = new Error(
    `Ovozni matnga aylantirib bo'lmadi — qayta ayting yoki yozing.${saved ? ' (Audio saqlandi)' : ''}`
  );
  err.status = 502;
  err.detail = errors.join(' | ');
  throw err;
}

// Trust AI — model qatlami: Anthropic Messages API (asosiy) -> Groq (zaxira).
// Uslub services/parse.js bilan bir xil: xom `fetch` + AbortSignal.timeout, SDK'siz.
// (Sabab: parsing/STT qatlamida ham shunday; qo'shimcha bog'liqlik = qo'shimcha xavf.
//  Anthropic Messages API — oddiy JSON POST, SDK bermaydigan hech narsa kerak emas.)
//
// UCH ASOSIY QAROR:
// 1) PROMPT CACHING — eng katta xarajat richagi (kesh o'qish ~0.1x narx).
//    system 2 blok: [PERSONA (statik, hamma userga umumiy)] + [kontekst (per-user,
//    ai_profile TTL ichida bayt-barqaror)] — ikkalasiga ham cache_control:ephemeral.
//    DIQQAT: kesh minimumi ~1024 token; PERSONA o'zbekcha ~1.2–1.6k token -> sig'adi.
//    Sig'masa ham xato bermaydi — shunchaki 2-nuqta (persona+kontekst) keshlanadi.
// 2) max_tokens: 800 — output input'dan ~5x qimmat; javob suhbatli, lekin mavzu talab qilsa
//    insight + vizual bloklar (chart/progress/debt_card) uchun joy qoldiradi (config.ai.maxTokens).
// 3) STRUCTURED OUTPUT — tool_choice bilan MAJBURIY `render_blocks`. Xom model JSON'iga
//    ishonilmaydi: validateBlocks() serverda qat'iy tekshiradi (sxema + chegaralar).
import { config } from '../config.js';
import { PERSONA, FALLBACK_TEXT } from '../services/ai-persona.js';

const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';
const ANTHROPIC_VERSION = '2023-06-01';
const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';

export const BLOCK_TYPES = ['text', 'stat', 'chart', 'chips', 'debt_card', 'budget_set', 'category_move', 'progress'];
const TONES = ['good', 'warn', 'bad', 'neutral'];
const CHART_KINDS = ['bar', 'line'];
const MAX_BLOCKS = 6;

// LLM asbobi — javob FAQAT shu orqali keladi (docs/ai-character.md §11).
export const BLOCKS_TOOL = {
  name: 'render_blocks',
  description: 'Foydalanuvchiga ko\'rsatiladigan javob bloklari. Javobni FAQAT shu asbob orqali qaytar.',
  input_schema: {
    type: 'object',
    properties: {
      blocks: {
        type: 'array',
        description: 'Odatda 2–5 blok, mavzuga qarab. Vizual bloklardan saxiy foydalan: taqqoslash->chart, streak/limit temp->progress, qarz->debt_card, katta raqam->stat; oxirida chips.',
        items: {
          type: 'object',
          properties: {
            type: { type: 'string', enum: BLOCK_TYPES },
            text: { type: 'string', description: 'type=text uchun: iliq javob — odatda ixcham, mavzu talab qilsa 3–6 gap.' },
            label: { type: 'string', description: 'stat/progress/budget_set sarlavhasi.' },
            value: { type: 'string', description: 'stat qiymati, masalan "1.2 mln".' },
            delta: { type: 'string', description: 'stat o\'zgarishi, masalan "+25%".' },
            tone: { type: 'string', enum: TONES, description: 'stat rangi (brend qizil/yashil).' },
            kind: { type: 'string', enum: CHART_KINDS, description: 'chart turi.' },
            title: { type: 'string', description: 'chart sarlavhasi.' },
            data: {
              type: 'array',
              description: 'chart uchun: [["Oziq-ovqat",2100000],["Transport",1200000]] — ko\'pi bilan 6 nuqta.',
              items: { type: 'array' },
            },
            items: { type: 'array', items: { type: 'string' }, description: 'chips: 2–3 qisqa tugma matni.' },
            partner_id: { type: 'string', description: 'debt_card: kontekstdagi HAMKOR_n belgisi (real ism/UUID emas).' },
            expense_id: { type: 'string', description: 'category_move: kontekstdagi YOZUV_n belgisi.' },
            to: { type: 'string', description: 'category_move: yangi toifa (kontekstdagi ro\'yxatdan).' },
            amount: { type: 'number', description: 'budget_set: taklif qilinayotgan OYLIK UMUMIY chegara (so\'m).' },
            progress_value: { type: 'number', description: 'progress: 0..100.' },
            caption: { type: 'string', description: 'progress izohi.' },
          },
          required: ['type'],
        },
      },
    },
    required: ['blocks'],
  },
};

const s = (v, max) => (typeof v === 'string' ? v.trim().slice(0, max) : '');

/**
 * Model JSON'ini QAT'IY tekshiradi — xom natijaga hech qachon ishonilmaydi.
 * Yaroqsiz blok TASHLANADI (butun javob emas). Bo'sh massiv -> chaqiruvchi
 * matnli fallback'ka tushadi.
 */
export function validateBlocks(raw) {
  const list = Array.isArray(raw) ? raw : Array.isArray(raw?.blocks) ? raw.blocks : [];
  const out = [];
  for (const b of list) {
    if (!b || typeof b !== 'object' || !BLOCK_TYPES.includes(b.type)) continue;
    if (out.length >= MAX_BLOCKS) break;
    switch (b.type) {
      case 'text': {
        const text = s(b.text, 1200);
        if (text) out.push({ type: 'text', text });
        break;
      }
      case 'stat': {
        const label = s(b.label, 60); const value = s(b.value, 40);
        if (!label || !value) break;
        const o = { type: 'stat', label, value };
        const delta = s(b.delta, 20); if (delta) o.delta = delta;
        o.tone = TONES.includes(b.tone) ? b.tone : 'neutral';
        out.push(o);
        break;
      }
      case 'chart': {
        const data = (Array.isArray(b.data) ? b.data : [])
          .map((d) => (Array.isArray(d) ? [s(d[0], 30), Number(d[1])] : null))
          .filter((d) => d && d[0] && Number.isFinite(d[1]))
          .slice(0, 6);
        if (!data.length) break;
        out.push({
          type: 'chart',
          kind: CHART_KINDS.includes(b.kind) ? b.kind : 'bar',
          title: s(b.title, 60),
          data,
        });
        break;
      }
      case 'chips': {
        const items = (Array.isArray(b.items) ? b.items : [])
          .map((i) => s(i, 40)).filter(Boolean).slice(0, 4);
        if (items.length) out.push({ type: 'chips', items });
        break;
      }
      case 'debt_card': {
        // Faqat belgi qabul qilinadi — real UUID/ismni model bermaydi (restoreBlocks qo'yadi)
        if (/^HAMKOR_\d+$/.test(s(b.partner_id, 20))) out.push({ type: 'debt_card', partner_id: b.partner_id.trim() });
        break;
      }
      case 'budget_set': {
        const amount = Math.round(Number(b.amount) || 0);
        if (amount > 0 && amount <= 1e13) out.push({ type: 'budget_set', amount, label: s(b.label, 60) });
        break;
      }
      case 'category_move': {
        const to = s(b.to, 40);
        if (/^YOZUV_\d+$/.test(s(b.expense_id, 20)) && to) {
          out.push({ type: 'category_move', expense_id: b.expense_id.trim(), to });
        }
        break;
      }
      case 'progress': {
        const v = Number(b.progress_value ?? b.value);
        if (!Number.isFinite(v)) break;
        out.push({
          type: 'progress',
          label: s(b.label, 60),
          value: Math.max(0, Math.min(100, Math.round(v))),
          caption: s(b.caption, 80),
        });
        break;
      }
      default: break;
    }
  }
  return out;
}

/** ai_usage uchun narx ($). Tariflar env'dan (config.ai.price) — PO real tarifga sozlaydi. */
export function costOf({ input_tokens = 0, cache_write_tokens = 0, cached_input_tokens = 0, output_tokens = 0 }) {
  const p = config.ai.price;
  const usd = (input_tokens * p.inPerMTok
    + cache_write_tokens * p.cacheWritePerMTok
    + cached_input_tokens * p.cacheReadPerMTok
    + output_tokens * p.outPerMTok) / 1_000_000;
  return Math.round(usd * 1e6) / 1e6;
}

// 5xx/429/529 va timeout -> zaxiraga o'tamiz. 4xx (400/401/403) -> bizning xato,
// zaxira ham tuzatmaydi, lekin foydalanuvchi javobsiz qolmasin -> baribir urinib ko'ramiz.
async function callAnthropic({ contextText, history, message }) {
  const res = await fetch(ANTHROPIC_URL, {
    method: 'POST',
    headers: {
      'x-api-key': config.ai.anthropicKey,
      'anthropic-version': ANTHROPIC_VERSION,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: config.ai.model,
      max_tokens: config.ai.maxTokens,
      // DIQQAT: `temperature` YUBORILMAYDI — claude-opus-4-8 (Claude 4.5+ avlodi) uchun
      // deprecated: API 400 invalid_request_error qaytaradi. Aynan shu parametr tufayli
      // ishga tushirilgandan beri BARCHA Anthropic chaqiruvlar yiqilib, chat Groq'da
      // ishlab kelgan (2026-07-17 diagnostikasi, ai_usage.model'dagi xato matni).
      // Model o'z default temperaturasida ishlaydi — ohang persona bilan boshqariladi.
      system: [
        // 1-kesh nuqtasi: statik persona (+ tools) — hamma foydalanuvchi uchun umumiy
        { type: 'text', text: PERSONA, cache_control: { type: 'ephemeral' } },
        // 2-kesh nuqtasi: per-user agregat (ai_profile TTL ichida o'zgarmaydi)
        { type: 'text', text: contextText, cache_control: { type: 'ephemeral' } },
      ],
      tools: [BLOCKS_TOOL],
      tool_choice: { type: 'tool', name: BLOCKS_TOOL.name }, // erkin matn EMAS — majburiy bloklar
      messages: [...history, { role: 'user', content: message }],
    }),
    signal: AbortSignal.timeout(config.ai.timeoutMs),
  });

  const data = await res.json().catch(() => ({}));
  // Kalit/token qiymatlari HECH QACHON loglanmaydi — faqat status va API validatsiya xabari.
  // error.message diagnostika uchun SHART (2026-07-17: 400 invalid_request_error'ning
  // sababi faqat type bilan aniqlanmadi). Bu Anthropic'ning o'z xabari — sir emas.
  if (!res.ok) {
    const t = data?.error?.type || 'xato';
    const m = String(data?.error?.message || '').slice(0, 300);
    throw new Error(`anthropic HTTP ${res.status}: ${t}${m ? ` — ${m}` : ''}`);
  }

  const toolUse = (data.content || []).find((c) => c.type === 'tool_use' && c.name === BLOCKS_TOOL.name);
  const blocks = validateBlocks(toolUse?.input);
  const u = data.usage || {};
  return {
    provider: 'anthropic',
    model: data.model || config.ai.model,
    // stop_reason='max_tokens' = javob KESILGAN (tool input chala/bo'sh bo'lishi mumkin) —
    // diagnostika uchun yuqoriga uzatiladi va [ai] logida ko'rinadi.
    stop: data.stop_reason,
    blocks,
    usage: {
      input_tokens: u.input_tokens || 0,
      cache_write_tokens: u.cache_creation_input_tokens || 0,
      cached_input_tokens: u.cache_read_input_tokens || 0,
      output_tokens: u.output_tokens || 0,
    },
  };
}

// Zaxira: mavjud Groq kaliti (parse.js bilan bir xil). Tool-calling o'rniga JSON rejimi —
// natija baribir validateBlocks()dan o'tadi, ya'ni xavfsizlik shartnomasi bir xil.
async function callGroq({ contextText, history, message }) {
  const sys = `${PERSONA}\n\n${contextText}\n\nMUHIM: javobni FAQAT quyidagi JSON ko'rinishida qaytar, boshqa hech narsa yozma:\n{"blocks":[{"type":"text","text":"..."}]}`;
  const res = await fetch(GROQ_URL, {
    method: 'POST',
    headers: { Authorization: `Bearer ${config.llm.groqKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: config.llm.groqModel,
      temperature: 0.7,
      max_tokens: config.ai.maxTokens,
      response_format: { type: 'json_object' },
      messages: [{ role: 'system', content: sys }, ...history, { role: 'user', content: message }],
    }),
    signal: AbortSignal.timeout(config.ai.fallbackTimeoutMs),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`groq HTTP ${res.status}: ${data?.error?.type || 'xato'}`);
  let parsed = {};
  try { parsed = JSON.parse(data.choices?.[0]?.message?.content || '{}'); } catch { parsed = {}; }
  const u = data.usage || {};
  return {
    provider: 'groq',
    model: config.llm.groqModel,
    blocks: validateBlocks(parsed),
    usage: {
      input_tokens: u.prompt_tokens || 0,
      cache_write_tokens: 0,
      cached_input_tokens: 0,
      output_tokens: u.completion_tokens || 0,
    },
  };
}

/**
 * Javob olish: Anthropic -> Groq zaxira -> iliq o'zbekcha xato.
 * HECH QACHON tashlamaydi (chat uzilmasin) — har doim { blocks: [...] } qaytadi.
 * history: [{role:'user'|'assistant', content:'...'}] — PSEVDONIMLASHGAN bo'lishi shart.
 */
export async function askAI({ contextText, history = [], message }) {
  const errors = [];
  if (config.ai.anthropicKey) {
    try {
      const r = await callAnthropic({ contextText, history, message });
      if (r.blocks.length) return { ...r, errors };
      // stop=max_tokens -> javob kesilgan (tool-JSON chala); boshqa stop -> sxema muammosi
      errors.push(`anthropic: bloklar bo'sh yoki sxemaga mos emas (stop=${r.stop || '?'}, out=${r.usage.output_tokens})`);
    } catch (e) { errors.push(`anthropic: ${e.message}`); }
  } else {
    errors.push('anthropic: ANTHROPIC_API_KEY yo\'q');
  }
  if (config.llm.groqKey) {
    try {
      const r = await callGroq({ contextText, history, message });
      if (r.blocks.length) return { ...r, errors };
      errors.push('groq: bloklar bo\'sh yoki sxemaga mos emas');
    } catch (e) { errors.push(`groq: ${e.message}`); }
  }
  // Ikkala provayder ham yiqildi — foydalanuvchi baribir insoniy javob ko'radi
  return {
    provider: 'fallback',
    model: 'none',
    blocks: [{ type: 'text', text: FALLBACK_TEXT }],
    usage: { input_tokens: 0, cache_write_tokens: 0, cached_input_tokens: 0, output_tokens: 0 },
    errors,
  };
}

/** AI umuman sozlanganmi (kamida bitta provayder kaliti bor). */
export function aiReady() {
  return !!(config.ai.anthropicKey || config.llm.groqKey);
}

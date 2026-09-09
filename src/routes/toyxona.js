// TO'YXONA moduli — to'yxona / banket zali boshqaruvi (021 migratsiya).
//
// Mahsulot modeli: egasi SANA + SLOT sotadi. Kunda 3 slot — 'nahor' (nahorgi osh),
// 'tushlik', 'kechki'. Pul: mehmon soni × bir mehmon narxi (food) + qo'shimcha
// xizmatlar (booking_items: musiqa, fotograf, tort, bezak, salyut) − to'lovlar
// (booking_payments: 'avans' sanani ushlaydi, 'yakuniy' to'y kuni).
//
// KO'P TO'YXONA — ASOSIY HOLAT: `halls` qatori = bitta TO'YXONA (bandlanadigan
// obyekt), har biri ALOHIDA HISOB yuritadi. GET /bookings va GET /summary
// ixtiyoriy ?hall_id= filtri bilan aynan bitta to'yxona hisobini beradi;
// filtrsiz — barcha to'yxonalar birgalikda.
//
// NARX TOIFALARI (hall_menus): ega "Oddiy — 150 000", "Lyuks — 200 000" kabi
// toifalarni BIR MARTA belgilaydi, band qilishda bittasini tanlaydi.
// SNAPSHOT QOIDASI: bandning price_per_guest va menu_title — band qilingan
// paytdagi NUSXA. Narx ro'yxati keyin o'zgarsa ham o'tgan bandlar puli
// O'ZGARMAYDI (aks holda avans/qoldiq hisobi orqaga qarab buziladi).
//
// ENG KATTA XATAR — IKKI MARTA BAND QILISH. Ikki qatlamli himoya:
//   1) dastur oldindan tekshiradi (SLOT_TAKEN — chiroyli, mijoz nomi bilan xabar),
//   2) DB'da partial unique indeks (021, bookings_slot_uidx) — parallel ikki
//      so'rov "read-then-write" tekshiruvini chetlab o'tsa ham insert YIQILADI.
//   Shuning uchun 23505 (unique violation) ham SLOT_TAKEN ga aylantiriladi.
//
// Egalik: har so'rov req.user.id bo'yicha filtrlanadi; bola yozuvlar (items /
// payments) ota-band EGASI tekshirilgandan keyingina yoziladi/o'chiriladi.
// Pul: FAQAT UZS, butun son (tiyin yo'q), cheklov 1e13.
import { Router, raw as rawBody } from 'express';
import { randomUUID } from 'crypto';
import { supabaseAdmin } from '../lib/supabase.js';
import { config } from '../config.js';
import {
  TOY_SERVICE_CATEGORIES, TOY_DEFAULT_CATEGORY, TOY_CATEGORY_NAMES,
  normToyCategory, toyCategoryOrder,
} from '../lib/toyxonaCategories.js';
import { requireAuth } from '../middleware/auth.js';
import {
  isModuleActive, MODULES, FREE_TOYXONA_BOOKINGS, isQuotaEnforceable, requireActiveSub,
  activeUnits,
} from '../lib/subscription.js';

const router = Router();
router.use(requireAuth);
// O'CHIRILGAN PROFIL YOZA OLMASIN (debts.js/expenses.js bilan bir xil qatlam).
// requireActiveSub pass-through: GET/HEAD/OPTIONS'ga DB'siz next, yozuvda faqat
// soft-delete (profiles.deleted_at) profil 403 oladi — oddiy foydalanuvchiga
// hech qanday ta'sir yo'q, obuna ham bu yerda TEKSHIRILMAYDI (kvota alohida).
router.use(requireActiveSub);

// ============================ Doimiylar ============================

export const SLOTS = ['nahor', 'tushlik', 'kechki'];
export const STATUSES = ['band', 'tasdiq', 'yakun', 'bekor'];
// 'qaytarim' (024) — mijozga QAYTARILGAN pul: paid'dan AYIRILADI (manfiy summa yo'q).
export const KINDS = ['avans', 'yakuniy', 'qaytarim'];
// 024: 'guest' = kishi boshiga (mehmon × narx), 'total' = butun to'yxona "podklyuch"
export const PRICE_MODES = ['guest', 'total'];
const MAX_SERVICES = 200;        // egadagi servislar katalogi
// 025: servis item'i — mijozga ko'rsatiladigan tavsif va rasmlar
const MAX_SVC_DESC = 600;        // mijoz ko'radigan to'liq matn (note = ega uchun ichki izoh)
const MAX_SVC_IMAGES = 5;        // [0] = muqova
const IMG_BUCKET = 'toyxona';
const IMG_MIME = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };
const MAX_IMAGE_BYTES = 3 * 1024 * 1024;
// Rasm URL'i FAQAT o'z bucket'imizdan bo'lsin. Aks holda ega (yoki buzilgan klient)
// ixtiyoriy tashqi manzilni yozib qo'yardi: bron varaqasi begona serverga so'rov
// yuborib mijozning IP'sini oshkor qilardi va rasm istalgan payt almashib ketardi.
const MAX_MENU_ITEMS = 60;
// 027: stol mahsuloti birliklari (DB CHECK bilan bir xil ro'yxat)
export const MENU_UNITS = ['kg', 'g', 'dona', 'l', 'porsiya', 'paket'];
const MAX_ITEM_AMOUNT = 1_000_000;       // bir stol turidagi taom/mahsulot qatorlari
const MAX_POLICY_ROWS = 10;      // bekor siyosati pog'onalari
// Avans kelmasa sana shuncha soat ushlab turiladi (POST /bookings hold_hours override, 1..720)
export const DEFAULT_HOLD_HOURS = 48;

const MAX_MONEY = 1e13;      // UZS butun son shifti (expenses.js bilan bir xil)
const MAX_GUESTS = 100_000;  // eng katta to'yxona ham bunchaga yaqinlashmaydi
const MAX_QTY = 10_000;
const MAX_RANGE_DAYS = 366;  // bitta so'rovda ko'pi bilan bir yil
const MAX_BOOKINGS = 500;    // RO'YXAT javobi hajmi chegarasi (expenses.js naqshi)
// YAKUN uchun chegara yuqoriroq: /summary faqat 4 ta kichik ustunni tortadi va
// natijasi bitta son — ro'yxat kabi javob hajmi muammosi yo'q. 500 da qolsa
// ko'p to'yxonali ega YIL oralig'ini so'raganda (3 slot × 365 × N zal) daromad
// JIMGINA kam ko'rsatilardi, bu esa pul xatosi.
const MAX_SUMMARY_BOOKINGS = 2000;
const MAX_HALLS = 100;            // bitta egadagi to'yxonalar
const MAX_MENUS_PER_HALL = 50;    // bitta to'yxonadagi narx toifalari
const MAX_MENUS_TOTAL = MAX_HALLS * MAX_MENUS_PER_HALL;   // GET /halls embed chegarasi
const MAX_SEARCH_RESULTS = 50;    // GET /bookings/search javobi chegarasi
const DEF_SEARCH_RESULTS = 20;    // ?limit berilmasa
// Raqamli qidiruvda JS-normallashtirilgan skan chegarasi (route izohiga qarang):
// telefonlar bazada KIRITILGANIDEK ("+998 90 123-45-67") turadi, ilike esa faqat
// ketma-ket raqamlarni topadi — shu sabab so'nggi N band JS'da ham tekshiriladi.
const MAX_SEARCH_SCAN = 1000;
// Takror to'lovni to'sish oynasi: shu vaqt ichida kelgan AYNAN bir xil to'lov
// (band + summa + tur) yangi qator yaratmaydi — band mavjud holicha qaytariladi
// (ijara.js POST /payments bilan bir xil qoida va qiymat).
// Sabab: mobil timeout (20s) + Render sovuq starti + "qayta urinib ko'ring" xabari.
export const DEDUP_MS = 90_000;
// .in(...) bo'laklari — URL UZUNLIGI cheklovi uchun. 200 ta uuid ≈ 7.5 KB so'rov
// satri berardi, bu ko'p proksi/serverlarning 8 KB sarlavha chegarasiga juda yaqin
// (414 xavfi). 100 ta ≈ 3.7 KB — xavfsiz zaxira bilan.
const CHILD_CHUNK = 100;

// Toshkent UTC+5 — default "shu oy" oralig'i EGA vaqtida hisoblanadi, aks holda
// server UTC'da oyning 1-sanasi mahalliy 05:00 gacha "o'tgan oy" bo'lib ko'rinardi.
const TZ_OFFSET_MS = 5 * 60 * 60 * 1000;

// Eslatma: 021 dagi qalqon indeksi hall_id NULL ni nol-UUID ga aylantiradi
// (coalesce) — bu yerda esa NULL uchun `.is('hall_id', null)` ishlatiladi;
// ikkalasi bir xil guruhni bildiradi.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUuid = (v) => typeof v === 'string' && UUID_RE.test(v);

const SLOT_TAKEN_BODY = {
  success: false,
  code: 'SLOT_TAKEN',
  error: 'Bu sana va vaqt band — boshqa zal yoki vaqt tanlang',
};

// ============================ Validatsiya ============================
// expenses.js madaniyati: butun son Math.round orqali, musbatlik tekshiruvi,
// uzunlik chegarasi, boshqaruv belgilarini olib tashlash, aniq 400 (o'zbekcha).

/** Boshqaruv belgilarini olib tashlaydi, bo'shliqlarni siqadi, n belgiga kesadi. */
function clean(v, n) {
  if (v == null) return null;
  const s = String(v)
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return s ? s.slice(0, n) : null;
}

/** Pul (UZS, butun son). null = noto'g'ri. allowZero — narx 0 bo'lishi mumkin.
 *
 *  TURGA QAT'IY (2026-08-04 review topilmasi — PUL YO'QOTUVCHI xato edi):
 *  ilgari faqat `Math.round(Number(v))` ishlatilardi, lekin JS'da
 *    Number(null) === 0, Number('') === 0, Number(false) === 0, Number([]) === 0
 *  ya'ni PATCH {price_per_guest: null} yoki {price_per_guest: ""} kelishilgan
 *  shartnoma narxini JIMGINA 0 ga tushirardi — 400 ham, iz ham qolmasdi.
 *  Endi FAQAT haqiqiy son yoki sof raqamli satr qabul qilinadi; qolgani -> null -> 400.
 *  (Bo'sh/null qiymatni "tegmaslik" deb talqin qilish CHAQIRUVCHIning ishi —
 *  handler'lar buni `!== undefined` tekshiruvi bilan o'zi hal qiladi.) */
export function money(v, { allowZero = false } = {}) {
  let n;
  if (typeof v === 'number') {
    if (!Number.isFinite(v)) return null;          // NaN / Infinity
    n = Math.round(v);
  } else if (typeof v === 'string' && /^\s*\d+(\.\d+)?\s*$/.test(v)) {
    n = Math.round(Number(v));                     // "150000" yoki "150000.00"
  } else {
    return null;                                   // null, '', false, [], {}, '12abc'
  }
  if (!Number.isInteger(n) || n > MAX_MONEY) return null;
  if (n < 0 || (!allowZero && n === 0)) return null;
  return n;
}

/** KO'PAYTMA chegarasi. Har omil alohida chegarada bo'lsa ham ko'paytmasi
 *  Number.MAX_SAFE_INTEGER (~9.007e15) dan oshishi mumkin edi — masalan
 *  100 000 mehmon × 1e13 narx = 1e18. Bunda JS float arifmetikasi summani
 *  NaN bermasdan JIMGINA noto'g'ri yaxlitlaydi (butun hisob-kitob buziladi).
 *  Shuning uchun ko'paytma ham MAX_MONEY bilan cheklanadi. */
export function overMax(a, b) {
  return (Number(a) || 0) * (Number(b) || 0) > MAX_MONEY;
}

/** 'YYYY-MM-DD' — kalendar jihatdan HAQIQIY sana (2026-02-31 rad etiladi). */
export function isDateStr(v) {
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return false;
  const [y, m, d] = v.split('-').map(Number);
  if (y < 2000 || y > 2100) return false;
  const dt = new Date(Date.UTC(y, m - 1, d));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === m - 1 && dt.getUTCDate() === d;
}

/** Ikki 'YYYY-MM-DD' orasidagi kunlar (to - from). */
export function daysBetween(from, to) {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
}

/** Default oraliq — Toshkent vaqtidagi joriy oy. { from, to } (ikkalasi ham inklyuziv). */
export function monthBounds(now = new Date()) {
  const t = new Date(now.getTime() + TZ_OFFSET_MS);
  const y = t.getUTCFullYear();
  const m = t.getUTCMonth();
  const p = (n) => String(n).padStart(2, '0');
  const last = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
  return { from: `${y}-${p(m + 1)}-01`, to: `${y}-${p(m + 1)}-${p(last)}` };
}

/** ?hall_id= (ixtiyoriy to'yxona filtri).
 *   - berilmagan / bo'sh -> BARCHA to'yxonalar ("Hammasi" ko'rinishi), shu jumladan
 *     hall_id NULL bo'lgan bandlar (to'yxonasiz ega yoki o'chirilgan to'yxona);
 *   - <uuid>            -> aynan o'sha to'yxona;
 *   - 'none'            -> FAQAT to'yxonasiz (hall_id NULL) bandlar.
 *  Egalik alohida tekshirilmaydi — so'rov baribir user_id bo'yicha filtrlanadi,
 *  begona ID shunchaki bo'sh natija beradi (enumeratsiya yo'q). */
export function readHallFilter(query) {
  const raw = query.hall_id;
  if (raw === undefined || raw === null || raw === '') return { hallId: null, nullOnly: false };
  const id = String(raw);
  if (id === 'none') return { hallId: null, nullOnly: true };
  if (!isUuid(id)) return { error: "hall_id noto'g'ri" };
  return { hallId: id, nullOnly: false };
}

/** hall_id filtrini so'rovga qo'llaydi (bookings va summary bir xil mantiq). */
function applyHallFilter(q, filter) {
  if (filter.nullOnly) return q.is('hall_id', null);
  if (filter.hallId) return q.eq('hall_id', filter.hallId);
  return q;
}

/** ?from/?to ni o'qiydi. Xato bo'lsa { error } qaytaradi (handler 400 beradi). */
function readRange(query) {
  const def = monthBounds();
  const from = query.from === undefined || query.from === '' ? def.from : String(query.from);
  const to = query.to === undefined || query.to === '' ? def.to : String(query.to);
  if (!isDateStr(from)) return { error: "from noto'g'ri sana (YYYY-MM-DD)" };
  if (!isDateStr(to)) return { error: "to noto'g'ri sana (YYYY-MM-DD)" };
  const days = daysBetween(from, to);
  if (days < 0) return { error: "from sanasi to dan keyin bo'lmasin" };
  if (days > MAX_RANGE_DAYS) return { error: `Oraliq ${MAX_RANGE_DAYS} kundan oshmasin` };
  return { from, to };
}

// ============================ Sof hisob-kitob ============================
// (Sof funksiyalar — DB'siz test qilinadi: src/routes/toyxona.test.js)

/** Bir bandning pul yakuni.
 *  food  = mehmon soni × bir mehmon narxi
 *  extras= Σ(qo'shimcha xizmat narxi × soni)
 *  total = food + extras · paid = Σ(to'lovlar) · left = total − paid (manfiy bo'lishi mumkin) */
export function computeTotals(booking, items = [], payments = []) {
  const guests = Number(booking?.guests) || 0;
  const ppg = Number(booking?.price_per_guest) || 0;
  // 024: 'total' rejimida ovqat/zal puli = bitta kelishilgan summa (podklyuch),
  // mehmon soni faqat sig'im/ko'rsatkich uchun.
  const food = booking?.price_mode === 'total'
    ? (Number(booking?.total_price) || 0)
    : (guests > 0 && ppg > 0 ? guests * ppg : 0);
  let extras = 0; let bonus = 0;
  for (const it of items) {
    const v = (Number(it?.amount) || 0) * (Number(it?.qty) || 0);
    if (it?.is_bonus) bonus += v; else extras += v;   // bonus — ko'rinadi, jamiga kirmaydi
  }
  let paid = 0; let refunded = 0;
  for (const p of payments) {
    const v = Number(p?.amount) || 0;
    if (p?.kind === 'qaytarim') refunded += v; else paid += v;
  }
  paid -= refunded;
  const total = food + extras;
  const penalty = Number(booking?.cancel_penalty) || 0;
  return {
    food, extras, bonus, total, paid, refunded, left: total - paid, penalty,
    // bekor qilingan bandda mijozga QAYTARILISHI KERAK bo'lgan pul (jarimadan keyin)
    refundDue: booking?.status === 'bekor' ? Math.max(0, paid - penalty) : 0,
  };
}

/** Minimal avans (024): jamining deposit_pct foizi, yuqoriga yaxlitlab. */
export function depositMin(total, pct) {
  const p = Number(pct) || 0;
  if (p <= 0 || !(total > 0)) return 0;
  return Math.ceil(total * p / 100);
}

/** Bekor siyosatini tekshirib normallashtiradi (024). Kirish: [{days, pct}].
 *  Chiqish: days KAMAYISH tartibida, takror days yo'q. Bo'sh = jarima yo'q.
 *  Xato bo'lsa { error }. */
export function parseCancelPolicy(raw) {
  if (raw == null) return { policy: [] };
  if (!Array.isArray(raw)) return { error: "Bekor siyosati ro'yxat bo'lsin" };
  if (raw.length > MAX_POLICY_ROWS) return { error: `Siyosat ${MAX_POLICY_ROWS} pog'onadan oshmasin` };
  const out = [];
  const seen = new Set();
  for (const r of raw) {
    const days = Math.round(Number(r?.days));
    const pct = Math.round(Number(r?.pct));
    if (!Number.isInteger(days) || days < 0 || days > 3650) return { error: "Siyosatda kun noto'g'ri (0–3650)" };
    if (!Number.isInteger(pct) || pct < 0 || pct > 100) return { error: "Siyosatda foiz noto'g'ri (0–100)" };
    if (seen.has(days)) return { error: 'Siyosatda bir xil kun ikki marta' };
    seen.add(days);
    out.push({ days, pct });
  }
  out.sort((a, b) => b.days - a.days);
  return { policy: out };
}

/** Jarima summasi (024): siyosatdan to'ygacha qolgan kunga MOS pog'ona topiladi
 *  (days <= daysLeft bo'lgan ENG KATTA days), foiz TUSHGAN pulga (paid) qo'llanadi.
 *  Pog'ona topilmasa (daysLeft barcha pog'onalardan katta) — jarima yo'q.
 *  O'tib ketgan to'y (daysLeft < 0) 0 kun pog'onasiga tushadi. */
export function cancelPenalty(policy, paid, daysLeft) {
  const p = Number(paid) || 0;
  if (p <= 0 || !Array.isArray(policy) || !policy.length) return 0;
  const d = Math.max(0, Number(daysLeft) || 0);
  const rows = [...policy].sort((a, b) => b.days - a.days);
  const row = rows.find((r) => Number(r.days) <= d);
  if (!row) return 0;
  return Math.min(p, Math.round(p * (Number(row.pct) || 0) / 100));
}

/** Telefonni FAQAT raqamlarga keltiradi (024): "+998 90 123-45-67" → "998901234567".
 *  Mobil masqa bilan ko'rsatadi. 7–15 raqam; bo'sh/qisqa → null. */
export function normPhone(v) {
  const d = String(v ?? '').replace(/\D/g, '');
  if (!d) return null;
  if (d.length < 7 || d.length > 15) return false;   // false = noto'g'ri (400)
  return d;
}

/** AQLLI STATUS QOIDALARI (deterministik, faqat TO'LOV QO'SHILGANDA ishlaydi):
 *   1) 'band' + birinchi to'lov  -> 'tasdiq'   (avans olindi = sana tasdiqlandi)
 *   2) 'tasdiq' + left <= 0      -> 'yakun'    (to'liq to'landi)
 *   3) 'bekor' va 'yakun' — TEGILMAYDI (bekor qilingan bandga to'lov kiritish
 *      qaytarim/jarima hisobi bo'lishi mumkin, uni tiriltirmaymiz)
 *   4) TO'LOV O'CHIRILGANDA statusni PASAYTIRMAYMIZ — egasi nazoratda qoladi
 *      (xato summani tuzatish uchun o'chirib-qayta kiritish odatiy ish).
 *   5) Qo'lda PATCH status har doim USTUN — u avtomatik qoidalarni chaqirmaydi. */
export function autoStatusAfterPayment(current, left) {
  if (current === 'bekor' || current === 'yakun') return current;
  const s = current === 'band' ? 'tasdiq' : current;
  return s === 'tasdiq' && left <= 0 ? 'yakun' : s;
}

/** Davr yakuni — SOF yig'ish (DB'siz test qilinadi).
 *
 *  MUHIM ASIMMETRIYA (ataylab): pul yig'indilari 'bekor' bandlarni hisobga OLMAYDI
 *  (bekor qilingan to'y daromad emas), `count` esa oraliqdagi BARCHA qatorlarni
 *  sanaydi. Ikkalasini bitta sarlavhada ko'rsatganda ("N to'y · <total>") bu
 *  o'zaro zid ko'rinardi, shuning uchun `countActive` ham qaytariladi —
 *  bu AYNAN pul yig'indisiga kirgan bandlar soni (mijoz o'zi ayirmasin).
 *
 *  `cancelledPaid` (2026-08-04 review) — BEKOR qilingan bandlarga HAQIQATAN
 *  tushgan pul. O'zbekistonda odatiy holat: mijoz to'yni bekor qiladi, AVANS
 *  egada QOLADI. Ilgari bu summa `paid` dan chiqib ketib, ekranda hech qanday
 *  iz qoldirmasdi — oyning "olingan puli" kassadagi naqd bilan mos kelmasdi.
 *  Endi u ALOHIDA qator bo'lib chiqadi: `paid` semantikasi o'zgarmaydi
 *  (faol bandlar puli), lekin pul KO'RINMAY qolmaydi.
 *  DIQQAT: to'lov qatori bandiga BOG'LIQ qoladi (FK uzilmaydi) — har so'm qaysi
 *  to'ydan kelganini har doim kuzatib bo'ladi (audit izi buzilmaydi). */
export function foldSummary(rows, itemsBy = new Map(), paysBy = new Map()) {
  const byStatus = { band: 0, tasdiq: 0, yakun: 0, bekor: 0 };
  let total = 0; let paid = 0; let cancelledPaid = 0;
  let penalties = 0; let refunded = 0; let bonus = 0; let guests = 0;
  const services = new Map();   // title -> { count, amount }
  for (const b of rows) {
    if (byStatus[b.status] !== undefined) byStatus[b.status] += 1;
    const items = itemsBy.get(b.id) || [];
    const t = computeTotals(b, items, paysBy.get(b.id) || []);
    refunded += t.refunded;
    if (b.status === 'bekor') {
      // Bekor qilingan band: faqat TUSHGAN pul sanaladi (uning `total`i daromad
      // emas — to'y bo'lmadi; lekin olingan avans real pul).
      cancelledPaid += t.paid;
      penalties += t.penalty;
      continue;
    }
    total += t.total; paid += t.paid; bonus += t.bonus;
    guests += Number(b.guests) || 0;
    for (const it of items) {
      const k = it.title || '?';
      const cur = services.get(k) || { title: k, count: 0, amount: 0, bonus: 0 };
      cur.count += Number(it.qty) || 0;
      const v = (Number(it.amount) || 0) * (Number(it.qty) || 0);
      if (it.is_bonus) cur.bonus += v; else cur.amount += v;
      services.set(k, cur);
    }
  }
  const countActive = rows.length - byStatus.bekor;
  return {
    count: rows.length,
    countActive,                                 // pul yig'indisi qamragan bandlar
    total,
    paid,
    left: total - paid,
    cancelledPaid,                               // bekor qilinganlardan qolgan pul
    byStatus,
    // 024 analitika
    penalties,                                   // bekor jarimalari (ushlab qolingan)
    refunded,                                    // mijozlarga qaytarilgan
    bonus,                                       // bepul berilgan servislar qiymati
    guests,                                      // faol bandlardagi jami mehmon
    avgCheck: countActive ? Math.round(total / countActive) : 0,
    topServices: [...services.values()].sort((a, b) => b.count - a.count).slice(0, 10),
  };
}

/** Kalendar tartibi: sana bo'yicha, keyin slot bo'yicha (nahor -> tushlik -> kechki).
 *  DB'da slot MATN — `order('slot')` alifbo tartibi berardi (kechki, nahor, tushlik). */
export function sortBookings(rows) {
  return [...rows].sort((a, b) =>
    String(a.event_date).localeCompare(String(b.event_date))
    || SLOTS.indexOf(a.slot) - SLOTS.indexOf(b.slot)
    || String(a.created_at || '').localeCompare(String(b.created_at || '')));
}

/** Qidiruv kiritmasini PostgREST `.or(...)` uchun XAVFSIZ tayyorlaydi (sof
 *  funksiya — DB'siz test qilinadi). `.or` satrida `,` shartlarni, `(`/`)`
 *  guruhlarni ajratadi, `%` esa ILIKE jokeri — foydalanuvchi kiritmasida bu
 *  belgilar qolsa filtr sintaksisi BUZILADI (SQL injection emas — PostgREST
 *  parametrlaydi — lekin 400/soxta natija ham xato). Shu belgilar OLIB
 *  TASHLANADI, boshqaruv belgilariga clean() qoidasi qo'llanadi.
 *  Qaytadi { text, digits }:
 *    text   — mijoz NOMI uchun qidiruv matni (tozalangandan keyin kamida 2
 *             belgi qolsa, aks holda null);
 *    digits — TELEFON uchun kiritmadagi FAQAT raqamlar (kamida 3 ta bo'lsa,
 *             aks holda null): "90-123 45 67" ham "+998901234567" ham bir xil
 *             raqam qatoriga tushadi (saqlangan telefon qanday terilgan bo'lsa
 *             shundoq qidiriladi — raqamlar KETMA-KET bo'lishi kutiladi).
 *  Ikkalasi ham null bo'lsa — qidirib bo'lmaydi (route 400 beradi). */
export function searchTerms(raw) {
  const text = String(raw ?? '')
    .replace(/[\u0000-\u001f\u007f]/g, ' ')   // clean() bilan bir xil boshqaruv-belgilar
    .replace(/[%,()]/g, '')                    // PostgREST .or sintaksis belgilari
    .replace(/\s+/g, ' ')
    .trim();
  const digits = String(raw ?? '').replace(/\D/g, '');
  return {
    text: text.length >= 2 ? text.slice(0, 80) : null,      // client_name ham 80 belgi
    digits: digits.length >= 3 ? digits.slice(0, 20) : null, // client_phone ham 20 belgi
  };
}

// ============================ Obuna gate'i ============================
// Monetizatsiya SIMLARI src/lib/subscription.js va src/routes/subs.js EGASIDA —
// bu fayl ularga TEGMAYDI, faqat READ-ONLY import qiladi.
// FREE_TOYXONA_BOOKINGS ilgari shu yerda TAKRORLANGAN edi (o'z intEnv nusxasi
// bilan). Endi umumiy manbadan import qilinadi: getModulesStatus() ham AYNAN shu
// konstantani `free_limit` sifatida qaytaradi, ya'ni mobil kartadagi "0/5"
// hisoblagichi va bu yerdagi majburlash BIR-BIRIDAN AJRALIB KETA OLMAYDI.
// Qolgan kechiktirilgan qism: $21/oy HAR TO'YXONAGA (MODULES.toyxona.per_unit) —
// to'yxona soni bo'yicha hisob-kitob hali yo'q, u ham subs sessiyasida.

/** YANGI BAND kvotasi. O'qish (GET) hech qachon bloklanmaydi; zal/xizmat/to'lov
 *  qo'shish ham ochiq — pul kirishi hech qachon to'sib qo'yilmasin (circles.js
 *  siyosati). Faqat POST /bookings sanaladi. 'bekor' bandlar kvota yemaydi. */
function requireBookingQuota(req, res, next) {
  (async () => {
    // XAVFSIZLIK KLAPANI: 020 va 021 migratsiyalarini EGA QO'LDA qo'llaydi, ya'ni
    // 021 birinchi tushishi mumkin. Bunday holatda module_subs jadvali yo'q —
    // obunani SOTIB BO'LMAYDI — lekin kvota 5 dan keyin bloklab, egani to'lash
    // imkoniyatisiz qulflab qo'yardi. Sotish mumkin bo'lmasa — bloklamaymiz.
    if (!(await isQuotaEnforceable(req.user.id))) return next();
    if (await isModuleActive(req.user.id, 'toyxona')) return next();
    const { count, error } = await supabaseAdmin
      .from('bookings')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', req.user.id)
      .neq('status', 'bekor');
    if (error) throw new Error(error.message);
    if ((count || 0) < FREE_TOYXONA_BOOKINGS) return next();
    return res.status(402).json({
      success: false,
      code: 'SUB_EXPIRED',
      module: 'toyxona',
      error: `Bepul ${FREE_TOYXONA_BOOKINGS} ta band ishlatildi — davom etish uchun obuna kerak ($${MODULES.toyxona.price_usd}/oy)`,
    });
  })().catch(next);
}

// ============================ DB yordamchilari ============================

/** 23505 — unique buzilishi (bookings_slot_uidx). Xom Postgres matni mijozga chiqmaydi. */
export function isUniqueViolation(error) {
  return error?.code === '23505' || /duplicate key|unique constraint/i.test(error?.message || '');
}

/** Band EGA'nikimi? Yo'q/begona bo'lsa null (404 "Topilmadi" — enumeratsiya yo'q). */
async function ownedBooking(userId, id) {
  if (!isUuid(id)) return null;
  const { data, error } = await supabaseAdmin
    .from('bookings').select('*').eq('id', id).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data || data.user_id !== userId) return null;
  return data;
}

/** Faol (arxivlanmagan) to'yxonalar soni chegaradan oshdimi?
 *  Oshgan bo'lsa tayyor xato obyektini, aks holda null qaytaradi.
 *  Chegara — MODULES.toyxona.max_units (PO 2026-08-04: $21 (2026-09-08 gacha $24) = BITTA to'yxona;
 *  do'konlar obunada miqdorni qo'llamaydi, shuning uchun ko'proq zal SOTIB
 *  BO'LMAYDI — ega alohida akkaunt ochadi). Katalogda max_units yo'q/0 bo'lsa
 *  chegara qo'llanmaydi (kelajakda pog'onali SKU'ga o'tilsa shu yerda ishlaydi). */
async function hallLimitError(userId) {
  // 024 / PO 2026-09-08: HAR ZAL $21/oy. Chegara = faol obuna qoplagan zal soni
  // (module_subs.units, SKU'dan). Obunasiz — 1 ta zal (bepul kvota 5 bron shu zalda).
  // Eng ko'pi MODULES.toyxona.max_units (5 ta SKU). 403, 402 EMAS — mobil "yana zal"
  // uchun paywall'ni O'ZI ochadi (code HALL_LIMIT + units/max_units bilan).
  const max = MODULES?.toyxona?.max_units || 1;
  const units = Math.max(1, await activeUnits(userId, 'toyxona'));
  const allowed = Math.min(units, max);
  const { count, error } = await supabaseAdmin
    .from('halls').select('id', { count: 'exact', head: true })
    .eq('user_id', userId).eq('archived', false);
  if (error) throw new Error(error.message);   // sanoq yiqilsa chegara JIMGINA ochilib qolmasin
  if ((count || 0) < allowed) return null;
  return {
    success: false,
    code: 'HALL_LIMIT',
    module: 'toyxona',
    units: allowed,
    max_units: max,
    price_usd: MODULES.toyxona.price_usd,
    error: allowed >= max
      ? `Bitta akkauntda ko'pi bilan ${max} ta to'yxona — ko'proq uchun alohida akkaunt`
      : `Obuna ${allowed} ta to'yxonani qoplaydi — yana zal uchun obunani kengaytiring ($${MODULES.toyxona.price_usd}/oy har zal)`,
  };
}

/** To'yxona EGA'nikimi? (band yaratishda begona zal ID'si berilmasin) */
async function ownedHall(userId, id) {
  if (!isUuid(id)) return null;
  const { data, error } = await supabaseAdmin
    .from('halls').select('*').eq('id', id).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data || data.user_id !== userId) return null;
  return data;
}

/** Narx toifasi EGA'nikimi? */
async function ownedMenu(userId, id) {
  if (!isUuid(id)) return null;
  const { data, error } = await supabaseAdmin
    .from('hall_menus').select('*').eq('id', id).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data || data.user_id !== userId) return null;
  return data;
}

/** Bandga toifa biriktirish tekshiruvi: toifa EGA'niki VA AYNAN SHU to'yxonaniki
 *  bo'lishi shart (aks holda "Lyuks" narxi boshqa to'yxonaga o'tib ketardi).
 *  { menu } yoki { error } qaytaradi — handler 400 beradi. */
async function resolveMenu(userId, menuId, hallId) {
  const menu = await ownedMenu(userId, menuId);
  if (!menu) return { error: 'Narx toifasi topilmadi' };
  if ((menu.hall_id || null) !== (hallId || null)) {
    return { error: "Narx toifasi boshqa to'yxonaga tegishli" };
  }
  return { menu };
}

/** Slot bandmi? exceptId — PATCH'da bandning O'ZI hisobga olinmasin.
 *  hall_id NULL bo'lsa `.is(null)` — 021 dagi coalesce indeksi bilan bir xil mantiq. */
async function findSlotConflict(userId, { hallId, date, slot, exceptId }) {
  let q = supabaseAdmin
    .from('bookings').select('id, client_name')
    .eq('user_id', userId).eq('event_date', date).eq('slot', slot)
    .neq('status', 'bekor');
  q = hallId ? q.eq('hall_id', hallId) : q.is('hall_id', null);
  if (exceptId) q = q.neq('id', exceptId);
  const { data, error } = await q.limit(1);
  if (error) throw new Error(error.message);
  return data?.[0] || null;
}

/** Bolalarni TO'PLAB yuklaydi — N+1 YO'Q. Oylik ko'rinishda (≤200 band) jami
 *  2 ta so'rov; kattaroq oraliqda 200 talik bo'laklarga bo'linadi. */
async function loadChildren(bookingIds) {
  const itemsBy = new Map();
  const paysBy = new Map();
  if (!bookingIds.length) return { itemsBy, paysBy };
  const chunks = [];
  for (let i = 0; i < bookingIds.length; i += CHILD_CHUNK) {
    chunks.push(bookingIds.slice(i, i + CHILD_CHUNK));
  }
  const results = await Promise.all(chunks.flatMap((ids) => [
    supabaseAdmin.from('booking_items')
      .select('id, booking_id, title, amount, qty, service_id, is_bonus, created_at')
      .in('booking_id', ids).order('created_at'),
    supabaseAdmin.from('booking_payments')
      .select('id, booking_id, amount, kind, paid_at, note, created_at')
      .in('booking_id', ids).order('paid_at'),
  ]));
  results.forEach((r, i) => {
    if (r.error) throw new Error(r.error.message);
    const bucket = i % 2 === 0 ? itemsBy : paysBy;
    for (const row of r.data || []) {
      const arr = bucket.get(row.booking_id) || [];
      arr.push(row);
      bucket.set(row.booking_id, arr);
    }
  });
  return { itemsBy, paysBy };
}

/** Foydalanuvchining zallari: id -> nomi (bitta kichik so'rov). */
async function hallNameMap(userId) {
  const { data, error } = await supabaseAdmin
    .from('halls').select('id, name').eq('user_id', userId).limit(200);
  if (error) throw new Error(error.message);
  return new Map((data || []).map((h) => [h.id, h.name]));
}

/** Mobil KONTRAKTI — bitta to'yxona JSON'i. `menus` HAR DOIM massiv (yo'q bo'lsa
 *  bo'sh) — mobil bir xil shaklni parse qilsin, `null` tekshiruvi kerak bo'lmasin. */
function mapHall(h, menus = []) {
  return {
    id: h.id,
    name: h.name,
    capacity: h.capacity == null ? null : Number(h.capacity),
    price_per_guest: Number(h.price_per_guest) || 0,   // toifasiz egalar uchun zaxira narx
    sort: Number(h.sort) || 0,
    archived: !!h.archived,
    created_at: h.created_at,
    // 024
    price_mode: PRICE_MODES.includes(h.price_mode) ? h.price_mode : 'guest',
    total_price: Number(h.total_price) || 0,
    deposit_pct: Number(h.deposit_pct) || 0,
    cancel_policy: Array.isArray(h.cancel_policy) ? h.cancel_policy : [],
    menus,
  };
}

/** Mobil KONTRAKTI — servis katalogi qatori (024). */
function mapService(sv) {
  // 025: `category` — ro'yxatdan tashqari qiymat DB'da qolishi mumkin (kelajakdagi
  // kategoriya, keyin olib tashlangan slug). Mobil tanimagan slug'ni ko'rsata
  // olmagani uchun bu yerda 'boshqa' ga tushiramiz — qator hech qachon YO'QOLMAYDI.
  const cat = normToyCategory(sv.category) || TOY_DEFAULT_CATEGORY;
  const images = Array.isArray(sv.images) ? sv.images.filter((u) => typeof u === 'string') : [];
  return {
    id: sv.id,
    hall_id: sv.hall_id || null,
    category: cat,
    title: sv.title,
    price: Number(sv.price) || 0,
    note: sv.note || null,
    description: sv.description || null,
    images,
    image: images[0] || null,          // muqova — ro'yxat kartochkasi shuni chizadi
    sort: Number(sv.sort) || 0,
    archived: !!sv.archived,
    created_at: sv.created_at,
  };
}

/** Mobil KONTRAKTI — bitta narx toifasi JSON'i. */
function mapMenu(m, items = []) {
  return {
    id: m.id,
    hall_id: m.hall_id,
    title: m.title,
    price_per_guest: Number(m.price_per_guest) || 0,
    seats: m.seats == null ? null : Number(m.seats),          // 024: bir stolda necha kishi
    note: m.note || null,
    sort: Number(m.sort) || 0,
    archived: !!m.archived,
    created_at: m.created_at,
    // 024: stol ustidagi taom/mahsulotlar — HAR DOIM massiv
    // 027: amount × unit_price = line_total; stol jami va 1 kishiga hisob
    items: items.map(mapMenuItem),
    table_total: menuTableTotal(items),
    per_guest_calc: menuPerGuest(items, m.seats),
  };
}

function mapMenuItem(it) {
  const amount = it.amount == null ? null : Number(it.amount);
  const unit_price = Number(it.unit_price) || 0;
  return {
    id: it.id,
    title: it.title,
    qty: it.qty || null,
    sort: Number(it.sort) || 0,
    amount,
    unit: MENU_UNITS.includes(it.unit) ? it.unit : null,
    unit_price,
    line_total: lineTotal(amount, unit_price),
  };
}

/** 027: qator jami — miqdor × birlik narxi, butun so'mga yaxlitlanadi. Buzuq kirish 0. */
export function lineTotal(amount, unitPrice) {
  const a = Number(amount); const u = Number(unitPrice);
  if (!Number.isFinite(a) || !Number.isFinite(u) || a <= 0 || u <= 0) return 0;
  return Math.round(a * u);
}
/** 027: stol jami = Σ qator jami. */
export function menuTableTotal(items = []) {
  return (items || []).reduce((s, it) => s + lineTotal(it.amount, it.unit_price), 0);
}
/** 027: 1 kishiga narx — stol jami ÷ o'rindiq, YUQORIGA yaxlitlab (ega zarar ko'rmasin). seats yo'q = 0. */
export function menuPerGuest(items, seats) {
  const t = menuTableTotal(items); const n = Number(seats) || 0;
  if (t <= 0 || n <= 0) return 0;
  return Math.ceil(t / n);
}

/** Stol turlari uchun taomlarni TO'PLAB yuklaydi (N+1 yo'q). menu_id -> rows[] */
async function loadMenuItems(userId, menuIds = null) {
  let q = supabaseAdmin.from('hall_menu_items').select('id, menu_id, title, qty, sort, amount, unit, unit_price')
    .eq('user_id', userId).order('sort').order('created_at').limit(MAX_MENUS_TOTAL);
  if (menuIds) q = q.in('menu_id', menuIds);
  const { data, error } = await q;
  if (error) throw new Error(error.message);
  const by = new Map();
  for (const r of data || []) {
    const arr = by.get(r.menu_id) || []; arr.push(r); by.set(r.menu_id, arr);
  }
  return by;
}

/** Bitta stol turini taomlari bilan. */
async function loadOneMenu(userId, menuId) {
  const m = await ownedMenu(userId, menuId);
  if (!m) return null;
  const by = await loadMenuItems(userId, [m.id]);
  return mapMenu(m, by.get(m.id) || []);
}

/** Mobil KONTRAKTI — bitta band JSON'i. */
function mapBooking(b, hallName, items = [], payments = []) {
  return {
    id: b.id,
    hall_id: b.hall_id,
    hall_name: hallName || null,
    menu_id: b.menu_id || null,
    menu_title: b.menu_title || null,   // SNAPSHOT — toifa o'chsa ham qoladi
    event_date: b.event_date,
    slot: b.slot,
    client_name: b.client_name,
    client_phone: b.client_phone,
    guests: Number(b.guests) || 0,
    price_per_guest: Number(b.price_per_guest) || 0,
    note: b.note,
    status: b.status,
    created_at: b.created_at,
    updated_at: b.updated_at,
    // 024
    price_mode: PRICE_MODES.includes(b.price_mode) ? b.price_mode : 'guest',
    total_price: Number(b.total_price) || 0,
    hold_until: b.hold_until || null,
    cancelled_at: b.cancelled_at || null,
    cancel_reason: b.cancel_reason || null,
    cancel_penalty: Number(b.cancel_penalty) || 0,
    client_user_id: b.client_user_id || null,   // mijoz Trustbook'da bo'lsa
    items: items.map((it) => ({
      id: it.id, title: it.title, amount: Number(it.amount) || 0, qty: Number(it.qty) || 0,
      service_id: it.service_id || null, is_bonus: !!it.is_bonus,
      // 025 SNAPSHOT: katalogdagi item o'chsa ham bandning varaqasi o'zgarmaydi
      category: normToyCategory(it.category) || TOY_DEFAULT_CATEGORY,
      image: it.image_url || null,
    })),
    payments: payments.map((p) => ({
      id: p.id, amount: Number(p.amount) || 0, kind: p.kind, paid_at: p.paid_at, note: p.note,
    })),
    totals: computeTotals(b, items, payments),
  };
}

/** Bitta bandni bolalari bilan qayta yuklab, mobil ko'rinishida qaytaradi
 *  (mutatsiyalardan keyin: mobil ro'yxatdagi qatorni shundoq almashtiradi). */
async function loadOneBooking(userId, bookingId) {
  const { data: b, error } = await supabaseAdmin
    .from('bookings').select('*').eq('id', bookingId).maybeSingle();
  if (error) throw new Error(error.message);
  if (!b || b.user_id !== userId) return null;
  const [{ itemsBy, paysBy }, halls] = await Promise.all([
    loadChildren([b.id]),
    b.hall_id ? hallNameMap(userId) : Promise.resolve(new Map()),
  ]);
  return mapBooking(b, halls.get(b.hall_id), itemsBy.get(b.id) || [], paysBy.get(b.id) || []);
}

// ============================ ZALLAR (halls) ============================

// GET /api/toyxona/halls — arxivlanganlar ham qaytadi (mobil o'zi filtrlaydi).
// Har to'yxona narx toifalarini (menus[]) O'ZI BILAN olib keladi — mobil zallar
// ro'yxatini ochganda har zal uchun alohida so'rov yubormasin (2 so'rov, N+1 emas).
router.get('/halls', async (req, res, next) => {
  try {
    const [hallsRes, menusRes] = await Promise.all([
      supabaseAdmin.from('halls').select('*').eq('user_id', req.user.id)
        .order('sort').order('created_at').limit(200),
      // Chegara limitlarga MOS: 100 zal × 50 toifa = 5000 (ilgari 1000 edi va
      // toifalar jimgina yo'qolardi — mobil ularni "o'chirilgan" deb ko'rsatardi)
      supabaseAdmin.from('hall_menus').select('*').eq('user_id', req.user.id)
        .order('sort').order('created_at').limit(MAX_MENUS_TOTAL),
    ]);
    if (hallsRes.error) throw new Error(hallsRes.error.message);
    if (menusRes.error) throw new Error(menusRes.error.message);

    const itemsBy = await loadMenuItems(req.user.id);
    const menusBy = new Map();
    for (const m of menusRes.data || []) {
      const arr = menusBy.get(m.hall_id) || [];
      arr.push(mapMenu(m, itemsBy.get(m.id) || []));
      menusBy.set(m.hall_id, arr);
    }
    res.json({
      success: true,
      data: (hallsRes.data || []).map((h) => mapHall(h, menusBy.get(h.id) || [])),
    });
  } catch (e) { next(e); }
});

/** 024 to'yxona maydonlari (POST/PATCH umumiy): price_mode, total_price, deposit_pct,
 *  cancel_policy. `patch`ga yozadi; xato bo'lsa matn qaytaradi. */
function readHallExtras(body, patch) {
  if (body?.price_mode !== undefined) {
    const m = String(body.price_mode || '');
    if (!PRICE_MODES.includes(m)) return "Narx rejimi noto'g'ri (guest / total)";
    patch.price_mode = m;
  }
  if (body?.total_price !== undefined) {
    const t = money(body.total_price, { allowZero: true });
    if (t == null) return "To'yxona narxi noto'g'ri";
    patch.total_price = t;
  }
  if (body?.deposit_pct !== undefined) {
    const d = Math.round(Number(body.deposit_pct));
    if (!Number.isInteger(d) || d < 0 || d > 100) return "Minimal avans foizi 0–100 bo'lsin";
    patch.deposit_pct = d;
  }
  if (body?.cancel_policy !== undefined) {
    const r = parseCancelPolicy(body.cancel_policy);
    if (r.error) return r.error;
    patch.cancel_policy = r.policy;
  }
  return null;
}

// POST /api/toyxona/halls  { name, capacity?, price_per_guest?, price_mode?, total_price?, deposit_pct?, cancel_policy? }
router.post('/halls', async (req, res, next) => {
  try {
    const name = clean(req.body?.name, 60);
    if (!name) return res.status(400).json({ success: false, error: 'Zal nomi kerak' });
    const extras = {};
    const exErr = readHallExtras(req.body, extras);
    if (exErr) return res.status(400).json({ success: false, error: exErr });

    let capacity = null;
    if (req.body?.capacity != null && req.body.capacity !== '') {
      capacity = Math.round(Number(req.body.capacity));
      if (!Number.isInteger(capacity) || capacity < 0 || capacity > MAX_GUESTS) {
        return res.status(400).json({ success: false, error: `Sig'im 0–${MAX_GUESTS} oralig'ida bo'lsin` });
      }
    }
    let ppg = 0;
    if (req.body?.price_per_guest != null && req.body.price_per_guest !== '') {
      ppg = money(req.body.price_per_guest, { allowZero: true });
      if (ppg == null) return res.status(400).json({ success: false, error: "Narx noto'g'ri" });
    }
    // sort — ro'yxat oxiriga (mobil keyin PATCH bilan qayta tartiblashi mumkin)
    const { count, error: ce } = await supabaseAdmin
      .from('halls').select('id', { count: 'exact', head: true }).eq('user_id', req.user.id);
    if (ce) throw new Error(ce.message);   // sanoq yiqilsa limit JIMGINA chetlab o'tilmasin
    if ((count || 0) >= MAX_HALLS) {
      return res.status(400).json({ success: false, error: `To'yxonalar soni ${MAX_HALLS} tadan oshmasin` });
    }
    // BITTA TO'YXONA QOIDASI (PO 2026-08-04): obuna FAQAT bitta to'yxonani
    // qoplaydi — do'konlar obunada "miqdor"ni qo'llamaydi (2026-08-04-iap-per-unit-research).
    // Ko'proq kerak bo'lsa ega alohida akkaunt ochadi. Yagona manba —
    // MODULES.toyxona.max_units (subscription.js), majburlash SHU YERDA.
    // 403, 402 EMAS: ortiqcha zalni SOTIB BO'LMAYDI, shuning uchun mobil paywall
    // ochmasligi kerak (402 -> Api.onPaymentRequired -> paywall).
    const limitErr = await hallLimitError(req.user.id);
    if (limitErr) return res.status(403).json(limitErr);

    const { data, error } = await supabaseAdmin.from('halls').insert({
      user_id: req.user.id, name, capacity, price_per_guest: ppg, sort: count || 0, ...extras,
    }).select().single();
    if (error) throw new Error(error.message);
    res.status(201).json({ success: true, data: mapHall(data, []) });   // yangi to'yxonada toifa yo'q
  } catch (e) { next(e); }
});

// PATCH /api/toyxona/halls/:id  { name?, capacity?, price_per_guest?, archived?, sort? }
router.patch('/halls/:id', async (req, res, next) => {
  try {
    const hall = await ownedHall(req.user.id, req.params.id);
    if (!hall) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const patch = {};
    if (req.body?.name !== undefined) {
      const name = clean(req.body.name, 60);
      if (!name) return res.status(400).json({ success: false, error: 'Zal nomi kerak' });
      patch.name = name;
    }
    if (req.body?.capacity !== undefined) {
      if (req.body.capacity === null || req.body.capacity === '') patch.capacity = null;
      else {
        const c = Math.round(Number(req.body.capacity));
        if (!Number.isInteger(c) || c < 0 || c > MAX_GUESTS) {
          return res.status(400).json({ success: false, error: `Sig'im 0–${MAX_GUESTS} oralig'ida bo'lsin` });
        }
        patch.capacity = c;
      }
    }
    if (req.body?.price_per_guest !== undefined) {
      const p = money(req.body.price_per_guest, { allowZero: true });
      if (p == null) return res.status(400).json({ success: false, error: "Narx noto'g'ri" });
      patch.price_per_guest = p;
    }
    if (req.body?.archived !== undefined) {
      patch.archived = !!req.body.archived;
      // Arxivdan QAYTARISH ham chegaraga bo'ysunadi — aks holda qoidani chetlab
      // o'tish yo'li ochiq qolardi: A'ni arxivla -> B yarat -> A'ni qaytar = 2 faol.
      if (patch.archived === false && hall.archived === true) {
        const limitErr = await hallLimitError(req.user.id);
        if (limitErr) return res.status(403).json(limitErr);
      }
    }
    if (req.body?.sort !== undefined) {
      const s = Math.round(Number(req.body.sort));
      if (!Number.isInteger(s) || s < 0 || s > 1000) {
        return res.status(400).json({ success: false, error: "Tartib noto'g'ri" });
      }
      patch.sort = s;
    }
    const exErr = readHallExtras(req.body, patch);
    if (exErr) return res.status(400).json({ success: false, error: exErr });
    if (!Object.keys(patch).length) {
      return res.status(400).json({ success: false, error: "O'zgarish yo'q" });
    }
    const { data, error } = await supabaseAdmin
      .from('halls').update(patch).eq('id', hall.id).select().single();
    if (error) throw new Error(error.message);
    // Toifalar ham qaytadi — GET /halls bilan bir xil shakl (mobil qatorni almashtiradi).
    // Xato JIMGINA yutilmaydi: bo'sh menus[] qaytarsak mobil "toifalar o'chib ketdi"
    // deb ko'rsatardi — bu ma'lumot yo'qolgandek tuyuladi.
    const { data: menus, error: me } = await supabaseAdmin.from('hall_menus').select('*')
      .eq('user_id', req.user.id).eq('hall_id', hall.id).order('sort').order('created_at');
    if (me) throw new Error(me.message);
    const mi = await loadMenuItems(req.user.id, (menus || []).map((m) => m.id));
    res.json({ success: true, data: mapHall(data, (menus || []).map((m) => mapMenu(m, mi.get(m.id) || []))) });
  } catch (e) { next(e); }
});

// ============================ NARX TOIFALARI (menus) ============================

// GET /api/toyxona/halls/:hallId/menus
router.get('/halls/:hallId/menus', async (req, res, next) => {
  try {
    const hall = await ownedHall(req.user.id, req.params.hallId);
    if (!hall) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { data, error } = await supabaseAdmin
      .from('hall_menus').select('*')
      .eq('user_id', req.user.id).eq('hall_id', hall.id)
      .order('sort').order('created_at').limit(100);
    if (error) throw new Error(error.message);
    const mi = await loadMenuItems(req.user.id, (data || []).map((m) => m.id));
    res.json({ success: true, data: (data || []).map((m) => mapMenu(m, mi.get(m.id) || [])) });
  } catch (e) { next(e); }
});

/** 024 stol turi maydonlari: seats (1..100 yoki null), note. */
function readMenuExtras(body, patch) {
  if (body?.seats !== undefined) {
    if (body.seats === null || body.seats === '') patch.seats = null;
    else {
      const n = Math.round(Number(body.seats));
      if (!Number.isInteger(n) || n <= 0 || n > 100) return "Stol sig'imi 1–100 bo'lsin";
      patch.seats = n;
    }
  }
  if (body?.note !== undefined) patch.note = clean(body.note, 200);
  return null;
}

/** items[] ni tekshiradi: [{title, qty?, amount?, unit?, unit_price?}] → normallashgan massiv yoki { error }.
 *  027: amount (0..1e6, kasr mumkin), unit (MENU_UNITS), unit_price (so'm, 0 mumkin). */
export function readMenuItems(raw) {
  if (raw === undefined) return { items: undefined };
  if (!Array.isArray(raw)) return { error: "Taomlar ro'yxat bo'lsin" };
  if (raw.length > MAX_MENU_ITEMS) return { error: `Bir stol turida ${MAX_MENU_ITEMS} tadan ortiq qator bo'lmasin` };
  const items = [];
  for (const r of raw) {
    const title = clean(typeof r === 'string' ? r : r?.title, 60);
    if (!title) continue;   // bo'sh qator — o'tkazib yuboriladi (mobil bo'sh input qoldirishi mumkin)
    let amount = null;
    if (r?.amount != null && r.amount !== '') {
      const a = Number(String(r.amount).replace(',', '.'));
      if (!Number.isFinite(a) || a < 0 || a > MAX_ITEM_AMOUNT) return { error: `"${title}": miqdor noto'g'ri` };
      amount = Math.round(a * 1000) / 1000;
    }
    let unit = null;
    if (r?.unit != null && r.unit !== '') {
      unit = String(r.unit);
      if (!MENU_UNITS.includes(unit)) return { error: `"${title}": birlik noto'g'ri (${MENU_UNITS.join('/')})` };
    }
    let unit_price = 0;
    if (r?.unit_price != null && r.unit_price !== '') {
      unit_price = money(r.unit_price, { allowZero: true });
      if (unit_price == null) return { error: `"${title}": birlik narxi noto'g'ri` };
    }
    items.push({ title, qty: clean(r?.qty, 30), amount, unit, unit_price });
  }
  return { items };
}

/** Stol turi taomlarini TO'LIQ almashtiradi (PUT semantikasi). Tranzaksiya yo'q:
 *  avval yangi qatorlar yoziladi, keyin eskilari o'chiriladi — yozish yiqilsa eski
 *  ro'yxat buzilmay qoladi. */
async function replaceMenuItems(userId, menuId, items) {
  const { data: old, error: oe } = await supabaseAdmin.from('hall_menu_items')
    .select('id').eq('menu_id', menuId);
  if (oe) throw new Error(oe.message);
  if (items.length) {
    const { error } = await supabaseAdmin.from('hall_menu_items').insert(
      items.map((it, i) => ({
        user_id: userId, menu_id: menuId, title: it.title, qty: it.qty, sort: i,
        amount: it.amount ?? null, unit: it.unit ?? null, unit_price: it.unit_price || 0,
      })));
    if (error) throw new Error(error.message);
  }
  if (old?.length) {
    const { error } = await supabaseAdmin.from('hall_menu_items').delete()
      .in('id', old.map((r) => r.id));
    if (error) throw new Error(error.message);
  }
}

// POST /api/toyxona/halls/:hallId/menus  { title, price_per_guest, seats?, note?, items?: [{title, qty?}] }
router.post('/halls/:hallId/menus', async (req, res, next) => {
  try {
    const hall = await ownedHall(req.user.id, req.params.hallId);
    if (!hall) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const title = clean(req.body?.title, 60);
    if (!title) return res.status(400).json({ success: false, error: 'Toifa nomi kerak' });
    const extras = {};
    const exErr = readMenuExtras(req.body, extras);
    if (exErr) return res.status(400).json({ success: false, error: exErr });
    const ri = readMenuItems(req.body?.items);
    if (ri.error) return res.status(400).json({ success: false, error: ri.error });
    // 027: narx berilmasa — mahsulotlardan hisoblanadi (stol jami ÷ o'rindiq)
    let price;
    if (req.body?.price_per_guest == null || req.body.price_per_guest === '') {
      price = menuPerGuest(ri.items || [], extras.seats);
    } else {
      price = money(req.body.price_per_guest, { allowZero: true });
      if (price == null) return res.status(400).json({ success: false, error: "Narx noto'g'ri" });
    }

    const { count, error: ce } = await supabaseAdmin.from('hall_menus')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', req.user.id).eq('hall_id', hall.id);
    if (ce) throw new Error(ce.message);
    if ((count || 0) >= MAX_MENUS_PER_HALL) {
      return res.status(400).json({
        success: false, error: `Bitta to'yxonada ${MAX_MENUS_PER_HALL} tadan ortiq toifa bo'lmasin`,
      });
    }
    const { data, error } = await supabaseAdmin.from('hall_menus').insert({
      user_id: req.user.id, hall_id: hall.id, title, price_per_guest: price, sort: count || 0, ...extras,
    }).select().single();
    if (error) throw new Error(error.message);
    if (ri.items?.length) await replaceMenuItems(req.user.id, data.id, ri.items);
    res.status(201).json({ success: true, data: await loadOneMenu(req.user.id, data.id) });
  } catch (e) { next(e); }
});

// PATCH /api/toyxona/menus/:id  { title?, price_per_guest?, seats?, note?, items?, archived?, sort? }
// items berilsa — ro'yxat TO'LIQ almashtiriladi (bo'sh [] = hammasini tozalash).
// DIQQAT: narxni o'zgartirish FAQAT kelajakdagi bandlarga ta'sir qiladi —
// mavjud bandlarda narx SNAPSHOT bo'lib saqlangan (021 dagi qoida).
router.patch('/menus/:id', async (req, res, next) => {
  try {
    const menu = await ownedMenu(req.user.id, req.params.id);
    if (!menu) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const patch = {};
    if (req.body?.title !== undefined) {
      const t = clean(req.body.title, 60);
      if (!t) return res.status(400).json({ success: false, error: 'Toifa nomi kerak' });
      patch.title = t;
    }
    if (req.body?.price_per_guest !== undefined) {
      const p = money(req.body.price_per_guest, { allowZero: true });
      if (p == null) return res.status(400).json({ success: false, error: "Narx noto'g'ri" });
      patch.price_per_guest = p;
    }
    if (req.body?.archived !== undefined) patch.archived = !!req.body.archived;
    if (req.body?.sort !== undefined) {
      const s = Math.round(Number(req.body.sort));
      if (!Number.isInteger(s) || s < 0 || s > 1000) {
        return res.status(400).json({ success: false, error: "Tartib noto'g'ri" });
      }
      patch.sort = s;
    }
    const exErr = readMenuExtras(req.body, patch);
    if (exErr) return res.status(400).json({ success: false, error: exErr });
    const ri = readMenuItems(req.body?.items);
    if (ri.error) return res.status(400).json({ success: false, error: ri.error });
    if (!Object.keys(patch).length && ri.items === undefined) {
      return res.status(400).json({ success: false, error: "O'zgarish yo'q" });
    }
    if (Object.keys(patch).length) {
      const { error } = await supabaseAdmin.from('hall_menus').update(patch).eq('id', menu.id);
      if (error) throw new Error(error.message);
    }
    if (ri.items !== undefined) await replaceMenuItems(req.user.id, menu.id, ri.items);
    res.json({ success: true, data: await loadOneMenu(req.user.id, menu.id) });
  } catch (e) { next(e); }
});

// DELETE /api/toyxona/menus/:id — qat'iy o'chirish.
// Bandlar YO'QOLMAYDI: bookings.menu_id NULL bo'ladi, menu_title/price_per_guest
// esa SNAPSHOT sifatida qoladi (o'tgan shartnoma summasi o'zgarmaydi).
// Ro'yxatdan yashirish uchun PATCH { archived: true } afzal.
router.delete('/menus/:id', async (req, res, next) => {
  try {
    const menu = await ownedMenu(req.user.id, req.params.id);
    if (!menu) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { error } = await supabaseAdmin.from('hall_menus').delete().eq('id', menu.id);
    if (error) throw new Error(error.message);
    res.json({ success: true });
  } catch (e) { next(e); }
});

// ============================ SERVISLAR KATALOGI (024) ============================
// Video, sahna bezagi, shou, tamada... — ega BIR MARTA kiritadi, bandga bosib qo'shadi.
// hall_id NULL = barcha to'yxonalar uchun. Bandga qo'shilganda booking_items ga
// SNAPSHOT (title/amount) — katalog narxi keyin o'zgarsa eski band o'zgarmaydi.

// Bucket'ning ochiq prefiksi: faqat shu bilan boshlanadigan URL saqlanadi.
const PUBLIC_PREFIX = `${(config.supabase.url || '').replace(/\/+$/, '')}/storage/v1/object/public/${IMG_BUCKET}/`;

/** Ochiq URL -> bucket ichidagi yo'l (begona URL bo'lsa null). */
function storagePathOf(url) {
  if (typeof url !== 'string' || !PUBLIC_PREFIX.startsWith('https://')) return null;
  if (!url.startsWith(PUBLIC_PREFIX)) return null;
  const path = url.slice(PUBLIC_PREFIX.length).split('?')[0];
  return path && !path.includes('..') ? decodeURIComponent(path) : null;
}

/** Storage'dan fayllarni o'chirish. XATOSI YUTILADI (best-effort): rasm qolib
 *  ketgani yomon, lekin uning uchun servis o'chirishni to'xtatish BATTAR — ega
 *  qatorni umuman yo'qota olmay qolardi. Yetim fayllar bucket'da kichik. */
async function removeImages(urls) {
  const paths = (urls || []).map(storagePathOf).filter(Boolean);
  if (!paths.length) return;
  try { await supabaseAdmin.storage.from(IMG_BUCKET).remove(paths); } catch (_) { /* jim */ }
}

/** `images` massivini o'qish: faqat O'Z bucket'imizdagi URL'lar, ko'pi bilan 5 ta.
 *  Qaytadi: { images } yoki { error }. */
function readImages(raw) {
  if (raw == null) return { images: [] };
  if (!Array.isArray(raw)) return { error: "Rasmlar ro'yxat bo'lsin" };
  if (raw.length > MAX_SVC_IMAGES) return { error: `Ko'pi bilan ${MAX_SVC_IMAGES} ta rasm` };
  const out = [];
  for (const u of raw) {
    if (typeof u !== 'string' || !u) return { error: "Rasm manzili noto'g'ri" };
    if (!storagePathOf(u)) return { error: "Rasm manzili noto'g'ri" };
    if (!out.includes(u)) out.push(u);
  }
  return { images: out };
}

// ============================ KATEGORIYALAR (025) ============================
// GET /api/toyxona/service-categories — PLATFORMA ro'yxati (ega o'zgartira olmaydi).
// Mobil ilova o'z lug'atidan chizadi va bu endpointga BOG'LIQ EMAS; u kelajakdagi
// veb bron sahifasi va integratsiyalar uchun (nomlar uz/ru/en).
router.get('/service-categories', (_req, res) => {
  res.json({
    success: true,
    data: TOY_SERVICE_CATEGORIES.map((c, i) => ({
      slug: c.slug, unit: c.unit, order: i, names: TOY_CATEGORY_NAMES[c.slug] || null,
    })),
  });
});

// ============================ RASM YUKLASH (025) ============================
// POST /api/toyxona/uploads/service-image — TANA = rasm BAYTLARI (base64 EMAS),
// Content-Type: image/jpeg | image/png | image/webp. Javob: { url }.
//
// NEGA BACKEND ORQALI: klient Supabase Storage'ga to'g'ridan-to'g'ri chiqmaydi —
// O'zbekiston tarmoqlari ba'zan supabase.co ga ulanolmaydi (API ham shu sabab
// api.trustbook.uz / Cloudflare ortida). Bayt sifatida yuboriladi, chunki base64
// hajmni 33% oshiradi va global express.json chegarasi 256 KB.
//
// YETIM FAYL: ega rasm yuklab, formani BEKOR qilsa fayl bucket'da qoladi. Buni
// ataylab qabul qilamiz — muqobili "avval servisni saqlang, keyin rasm qo'shing"
// degan bo'g'iq oqim edi. Servis o'chirilganda/rasmi almashtirilganda eski fayllar
// o'chiriladi (removeImages).
router.post('/uploads/service-image',
  rawBody({ type: Object.keys(IMG_MIME), limit: MAX_IMAGE_BYTES }),
  async (req, res, next) => {
    try {
      const mime = String(req.headers['content-type'] || '').split(';')[0].trim().toLowerCase();
      const ext = IMG_MIME[mime];
      if (!ext) return res.status(415).json({ success: false, error: 'Faqat JPEG, PNG yoki WEBP rasm' });
      const buf = req.body;
      if (!Buffer.isBuffer(buf) || buf.length === 0) {
        return res.status(400).json({ success: false, error: "Rasm bo'sh" });
      }
      if (buf.length > MAX_IMAGE_BYTES) {
        return res.status(413).json({ success: false, error: 'Rasm 3 MB dan katta' });
      }
      // Yo'l: <user_id>/<uuid>.<ext> — user_id prefiksi qo'lda tekshirishni
      // osonlashtiradi (kim yukladi) va nomlar to'qnashmaydi.
      const path = `${req.user.id}/${randomUUID()}.${ext}`;
      const { error } = await supabaseAdmin.storage.from(IMG_BUCKET)
        .upload(path, buf, { contentType: mime, upsert: false, cacheControl: '31536000' });
      if (error) throw new Error(error.message);
      const { data } = supabaseAdmin.storage.from(IMG_BUCKET).getPublicUrl(path);
      res.status(201).json({ success: true, data: { url: data?.publicUrl || null } });
    } catch (e) { next(e); }
  });

/** Servis EGA'nikimi? */
async function ownedService(userId, id) {
  if (!isUuid(id)) return null;
  const { data, error } = await supabaseAdmin
    .from('hall_services').select('*').eq('id', id).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data || data.user_id !== userId) return null;
  return data;
}

// GET /api/toyxona/services?hall_id=<uuid>  — filtr berilsa: o'sha to'yxona + umumiy (NULL)
router.get('/services', async (req, res, next) => {
  try {
    const f = readHallFilter(req.query);
    if (f.error) return res.status(400).json({ success: false, error: f.error });
    let q = supabaseAdmin.from('hall_services').select('*').eq('user_id', req.user.id);
    if (f.hallId) q = q.or(`hall_id.eq.${f.hallId},hall_id.is.null`);
    // 025: ?category=musiqa — bitta kategoriya ichi
    if (req.query.category != null && req.query.category !== '') {
      const cat = normToyCategory(req.query.category);
      if (!cat) return res.status(400).json({ success: false, error: "Kategoriya noto'g'ri" });
      q = q.eq('category', cat);
    }
    const { data, error } = await q.order('sort').order('created_at').limit(MAX_SERVICES);
    if (error) throw new Error(error.message);
    // Kategoriya tartibi PLATFORMA ro'yxatidan (DB'da tartib raqami yo'q), ichida
    // esa eganing `sort`i saqlanadi — shuning uchun saralash BARQAROR bo'lishi shart.
    const rows = (data || []).map(mapService);
    rows.sort((a, b) => toyCategoryOrder(a.category) - toyCategoryOrder(b.category));
    res.json({ success: true, data: rows });
  } catch (e) { next(e); }
});

// POST /api/toyxona/services  { title, price?, note?, hall_id? }
router.post('/services', async (req, res, next) => {
  try {
    const title = clean(req.body?.title, 60);
    if (!title) return res.status(400).json({ success: false, error: 'Servis nomi kerak' });
    let price = 0;
    if (req.body?.price != null && req.body.price !== '') {
      price = money(req.body.price, { allowZero: true });
      if (price == null) return res.status(400).json({ success: false, error: "Narx noto'g'ri" });
    }
    let hall_id = null;
    if (req.body?.hall_id != null && req.body.hall_id !== '') {
      const hall = await ownedHall(req.user.id, req.body.hall_id);
      if (!hall) return res.status(400).json({ success: false, error: "To'yxona topilmadi" });
      hall_id = hall.id;
    }
    const { count, error: ce } = await supabaseAdmin.from('hall_services')
      .select('id', { count: 'exact', head: true }).eq('user_id', req.user.id);
    if (ce) throw new Error(ce.message);
    if ((count || 0) >= MAX_SERVICES) {
      return res.status(400).json({ success: false, error: `Servislar ${MAX_SERVICES} tadan oshmasin` });
    }
    // 025: kategoriya (majburiy emas — berilmasa 'boshqa'), tavsif, rasmlar
    const category = normToyCategory(req.body?.category);
    if (!category) return res.status(400).json({ success: false, error: "Kategoriya noto'g'ri" });
    const im = readImages(req.body?.images);
    if (im.error) return res.status(400).json({ success: false, error: im.error });
    const { data, error } = await supabaseAdmin.from('hall_services').insert({
      user_id: req.user.id, hall_id, title, price, note: clean(req.body?.note, 200), sort: count || 0,
      category, description: clean(req.body?.description, MAX_SVC_DESC), images: im.images,
    }).select().single();
    if (error) throw new Error(error.message);
    res.status(201).json({ success: true, data: mapService(data) });
  } catch (e) { next(e); }
});

// PATCH /api/toyxona/services/:id  { title?, price?, note?, archived?, sort? }
router.patch('/services/:id', async (req, res, next) => {
  try {
    const sv = await ownedService(req.user.id, req.params.id);
    if (!sv) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const patch = {};
    if (req.body?.title !== undefined) {
      const t = clean(req.body.title, 60);
      if (!t) return res.status(400).json({ success: false, error: 'Servis nomi kerak' });
      patch.title = t;
    }
    if (req.body?.price !== undefined) {
      const p = money(req.body.price, { allowZero: true });
      if (p == null) return res.status(400).json({ success: false, error: "Narx noto'g'ri" });
      patch.price = p;
    }
    if (req.body?.note !== undefined) patch.note = clean(req.body.note, 200);
    if (req.body?.description !== undefined) patch.description = clean(req.body.description, MAX_SVC_DESC);
    if (req.body?.category !== undefined) {
      const c = normToyCategory(req.body.category);
      if (!c) return res.status(400).json({ success: false, error: "Kategoriya noto'g'ri" });
      patch.category = c;
    }
    // Rasmlar to'liq ALMASHTIRILADI (mobil doim to'liq ro'yxat yuboradi).
    // Ro'yxatdan chiqib ketgan fayllar Storage'dan ham o'chiriladi — aks holda
    // bucket ega tashlab yuborgan rasmlar bilan cheksiz to'lib borardi.
    let dropped = [];
    if (req.body?.images !== undefined) {
      const im = readImages(req.body.images);
      if (im.error) return res.status(400).json({ success: false, error: im.error });
      patch.images = im.images;
      const oldImgs = Array.isArray(sv.images) ? sv.images : [];
      dropped = oldImgs.filter((u) => typeof u === 'string' && !im.images.includes(u));
    }
    if (req.body?.archived !== undefined) patch.archived = !!req.body.archived;
    if (req.body?.sort !== undefined) {
      const s = Math.round(Number(req.body.sort));
      if (!Number.isInteger(s) || s < 0 || s > 1000) return res.status(400).json({ success: false, error: "Tartib noto'g'ri" });
      patch.sort = s;
    }
    if (!Object.keys(patch).length) return res.status(400).json({ success: false, error: "O'zgarish yo'q" });
    const { data, error } = await supabaseAdmin.from('hall_services').update(patch).eq('id', sv.id).select().single();
    if (error) throw new Error(error.message);
    // Fayllarni FAQAT yozuv muvaffaqiyatli yangilangandan keyin o'chiramiz
    // (aks holda update yiqilsa rasm yo'q, havola esa qatorda qolib ketardi).
    await removeImages(dropped);
    res.json({ success: true, data: mapService(data) });
  } catch (e) { next(e); }
});

// DELETE /api/toyxona/services/:id — bandlardagi qatorlar QOLADI (service_id NULL, snapshot).
router.delete('/services/:id', async (req, res, next) => {
  try {
    const sv = await ownedService(req.user.id, req.params.id);
    if (!sv) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { error } = await supabaseAdmin.from('hall_services').delete().eq('id', sv.id);
    if (error) throw new Error(error.message);
    // Bandlardagi qatorlar QOLADI (service_id NULL), lekin ularning rasmi
    // booking_items.image_url da SNAPSHOT bo'lib turadi — shuning uchun katalog
    // faylini o'chirish o'tgan bron varaqasini BUZADI. Shu sabab faqat HECH BIR
    // bandda ishlatilmagan rasmlar o'chiriladi.
    const imgs = (Array.isArray(sv.images) ? sv.images : []).filter((u) => typeof u === 'string');
    if (imgs.length) {
      const { data: used } = await supabaseAdmin.from('booking_items')
        .select('image_url').in('image_url', imgs).limit(imgs.length);
      const keep = new Set((used || []).map((r) => r.image_url));
      await removeImages(imgs.filter((u) => !keep.has(u)));
    }
    res.json({ success: true });
  } catch (e) { next(e); }
});

// ============================ MIJOZ AUTOFILL (024) ============================
// GET /api/toyxona/clients?phone=<raqam> — shu telefon bilan OXIRGI band: ism + soni.
// Mobil: bron formasida avval telefon, keyin ism avto-to'ladi (tahrirlash mumkin).
router.get('/clients', async (req, res, next) => {
  try {
    const digits = normPhone(req.query.phone);
    if (!digits) return res.status(400).json({ success: false, error: 'Telefon kerak' });
    const { data, error } = await supabaseAdmin.from('bookings')
      .select('client_name, client_phone, event_date, client_user_id')
      .eq('user_id', req.user.id).eq('client_phone', digits)
      .order('event_date', { ascending: false }).limit(50);
    if (error) throw new Error(error.message);
    const rows = data || [];
    if (!rows.length) return res.json({ success: true, data: null });
    res.json({
      success: true,
      data: {
        client_name: rows[0].client_name,
        client_phone: digits,
        bookings: rows.length,
        last_event_date: rows[0].event_date,
        in_trustbook: rows.some((r) => !!r.client_user_id),
      },
    });
  } catch (e) { next(e); }
});

/** 024: band uchun servislar ro'yxatini tekshiradi. Har element:
 *    { service_id } — katalogdan (title/amount SNAPSHOT), yoki
 *    { title, amount } — erkin xizmat;
 *    qty? (default 1), is_bonus? (bepul — jamiga kirmaydi).
 *  Qaytadi { items: [{title, amount, qty, service_id, is_bonus}] } yoki { error }. */
async function readBookingItems(userId, raw) {
  if (raw == null) return { items: [] };
  if (!Array.isArray(raw)) return { error: "Servislar ro'yxat bo'lsin" };
  if (raw.length > 50) return { error: "Bitta bandga 50 tadan ortiq xizmat qo'shib bo'lmaydi" };
  const items = [];
  for (const r of raw) {
    const is_bonus = !!r?.is_bonus;
    let qty = 1;
    if (r?.qty != null && r.qty !== '') {
      qty = Math.round(Number(r.qty));
      if (!Number.isInteger(qty) || qty <= 0 || qty > MAX_QTY) return { error: `Soni 1–${MAX_QTY} bo'lsin` };
    }
    let title; let amount; let service_id = null;
    let snapCat = TOY_DEFAULT_CATEGORY; let snapImg = null;   // 025 snapshot
    if (r?.service_id) {
      const sv = await ownedService(userId, r.service_id);
      if (!sv) return { error: 'Servis topilmadi' };
      service_id = sv.id;
      title = clean(r.title, 60) || sv.title;
      // Narx: aniq berilsa o'sha, bo'lmasa katalog narxi
      if (r.amount != null && r.amount !== '') {
        amount = money(r.amount, { allowZero: true });
        if (amount == null) return { error: `"${title}" narxi noto'g'ri` };
      } else amount = Number(sv.price) || 0;
      snapCat = normToyCategory(sv.category) || TOY_DEFAULT_CATEGORY;
      snapImg = (Array.isArray(sv.images) ? sv.images : []).find((u) => typeof u === 'string') || null;
    } else {
      title = clean(r?.title, 60);
      if (!title) return { error: 'Xizmat nomi kerak' };
      amount = money(r?.amount, { allowZero: true });
      if (amount == null) return { error: `"${title}" narxi noto'g'ri` };
    }
    // Pullik xizmat 0 so'm bo'lmasin (bonus 0 bo'lishi mumkin)
    if (!is_bonus && amount <= 0) return { error: `"${title}" narxi kerak (yoki bonus deb belgilang)` };
    if (overMax(amount, qty)) return { error: 'Xizmat summasi juda katta' };
    items.push({ title, amount, qty, service_id, is_bonus, category: snapCat, image_url: snapImg });
  }
  return { items };
}

/** 024: telefon bo'yicha Trustbook profili (mijoz ilovada bo'lsa bog'lash). */
async function profileIdByPhone(digits) {
  const { data, error } = await supabaseAdmin.from('profiles').select('id')
    .eq('phone', digits).is('deleted_at', null).maybeSingle();
  if (error) return null;   // profil qidiruvi yiqilsa band yaratish to'xtamasin
  return data?.id || null;
}

/** 024: bekor qilish hisob-kitobi. Jarima: aniq `penaltyOverride` (ega qo'lda),
 *  aks holda to'yxona siyosati bo'yicha. Qaytadi { paid, penalty, refund, daysLeft, policy }. */
async function cancelPreview(userId, cur, penaltyOverride = undefined) {
  const [{ itemsBy, paysBy }, hall] = await Promise.all([
    loadChildren([cur.id]),
    cur.hall_id ? ownedHall(userId, cur.hall_id) : Promise.resolve(null),
  ]);
  const t = computeTotals({ ...cur, cancel_penalty: 0, status: 'band' },
    itemsBy.get(cur.id) || [], paysBy.get(cur.id) || []);
  const todayTk = new Date(Date.now() + TZ_OFFSET_MS).toISOString().slice(0, 10);
  const daysLeft = daysBetween(todayTk, cur.event_date);
  const policy = Array.isArray(hall?.cancel_policy) ? hall.cancel_policy : [];
  let penalty = penaltyOverride !== undefined ? penaltyOverride : cancelPenalty(policy, t.paid, daysLeft);
  penalty = Math.min(Math.max(0, penalty), Math.max(0, t.paid));
  return { paid: t.paid, penalty, refund: Math.max(0, t.paid - penalty), daysLeft, policy, total: t.total };
}

/** 024: bandni BEKOR qiladi — jarima SNAPSHOT, sana bo'shaydi. */
async function applyCancel(userId, cur, { reason, penaltyOverride } = {}) {
  const pv = await cancelPreview(userId, cur, penaltyOverride);
  const { error } = await supabaseAdmin.from('bookings').update({
    status: 'bekor',
    cancelled_at: new Date().toISOString(),
    cancel_reason: reason || null,
    cancel_penalty: pv.penalty,
    hold_until: null,
    updated_at: new Date().toISOString(),
  }).eq('id', cur.id);
  if (error) throw new Error(error.message);
  return pv;
}

// ============================ BANDLAR (bookings) ============================

// GET /api/toyxona/bookings?from=YYYY-MM-DD&to=YYYY-MM-DD&hall_id=<uuid>
// from/to berilmasa — Toshkent vaqtidagi JORIY OY.
// hall_id — AYNAN BITTA to'yxona hisobi; berilmasa barcha to'yxonalar birgalikda.
router.get('/bookings', async (req, res, next) => {
  try {
    const range = readRange(req.query);
    if (range.error) return res.status(400).json({ success: false, error: range.error });
    const hallFilter = readHallFilter(req.query);
    if (hallFilter.error) return res.status(400).json({ success: false, error: hallFilter.error });

    let q = supabaseAdmin
      .from('bookings').select('*')
      .eq('user_id', req.user.id)
      .gte('event_date', range.from).lte('event_date', range.to);
    q = applyHallFilter(q, hallFilter);
    const { data, error } = await q.order('event_date').limit(MAX_BOOKINGS);
    if (error) throw new Error(error.message);

    const rows = sortBookings(data || []);
    const [{ itemsBy, paysBy }, halls] = await Promise.all([
      loadChildren(rows.map((b) => b.id)),
      hallNameMap(req.user.id),
    ]);
    res.json({
      success: true,
      data: rows.map((b) => mapBooking(b, halls.get(b.hall_id), itemsBy.get(b.id) || [], paysBy.get(b.id) || [])),
      range: { from: range.from, to: range.to, hall_id: hallFilter.hallId },
      // Chegaraga tegdi — mobil oraliqni toraytirishi yoki hall_id qo'yishi kerak
      // (JIMGINA kesilgan ro'yxat pul yakunini kam ko'rsatardi)
      truncated: rows.length >= MAX_BOOKINGS,
    });
  } catch (e) { next(e); }
});

// POST /api/toyxona/bookings
// { hall_id?, menu_id?, event_date, slot, client_name, client_phone?, guests,
//   price_per_guest?, note?, advance? }
// Narx ustuvorligi: aniq price_per_guest > tanlangan toifa (menu) > to'yxona defaulti > 0.
router.post('/bookings', requireBookingQuota, async (req, res, next) => {
  try {
    const b = req.body || {};

    const event_date = String(b.event_date || '');
    if (!isDateStr(event_date)) {
      return res.status(400).json({ success: false, error: "Sana noto'g'ri (YYYY-MM-DD)" });
    }
    const slot = String(b.slot || '');
    if (!SLOTS.includes(slot)) {
      return res.status(400).json({ success: false, error: "Vaqt noto'g'ri (nahor / tushlik / kechki)" });
    }
    const client_name = clean(b.client_name, 80);
    if (!client_name) return res.status(400).json({ success: false, error: 'Mijoz ismi kerak' });
    // 024: telefon FAQAT raqam holida saqlanadi (autofill va off-app bog'lash uchun)
    const client_phone = normPhone(b.client_phone);
    if (client_phone === false) return res.status(400).json({ success: false, error: "Telefon raqami noto'g'ri" });

    // 026: 'total' rejimida mehmonlar soni SO'RALMAYDI (0 = ko'rsatilmagan);
    // 'guest' rejimida avvalgidek 1..MAX. Rejim pastda hisoblanadi — 0 tekshiruvi o'sha yerda.
    const guests = Math.round(Number(b.guests ?? 0));
    if (!Number.isInteger(guests) || guests < 0 || guests > MAX_GUESTS) {
      return res.status(400).json({ success: false, error: `Mehmonlar soni 1–${MAX_GUESTS} bo'lsin` });
    }

    let hall = null;
    if (b.hall_id != null && b.hall_id !== '') {
      hall = await ownedHall(req.user.id, b.hall_id);
      if (!hall) return res.status(400).json({ success: false, error: "To'yxona topilmadi" });
    }

    // Narx toifasi (menyu) — EGA'niki va AYNAN shu to'yxonaniki bo'lishi shart
    let menu = null;
    if (b.menu_id != null && b.menu_id !== '') {
      const r = await resolveMenu(req.user.id, b.menu_id, hall?.id || null);
      if (r.error) return res.status(400).json({ success: false, error: r.error });
      menu = r.menu;
    }

    // SNAPSHOT: narx bandga NUSXA olinadi — toifa/to'yxona narxi keyin o'zgarsa
    // yoki toifa o'chirilsa ham bu bandning puli o'zgarmaydi.
    let price_per_guest;
    if (b.price_per_guest != null && b.price_per_guest !== '') {
      price_per_guest = money(b.price_per_guest, { allowZero: true });
      if (price_per_guest == null) {
        return res.status(400).json({ success: false, error: "Bir mehmon narxi noto'g'ri" });
      }
    } else if (menu) {
      price_per_guest = Number(menu.price_per_guest) || 0;
    } else {
      price_per_guest = Number(hall?.price_per_guest) || 0;
    }
    if (overMax(guests, price_per_guest)) {
      return res.status(400).json({ success: false, error: 'Umumiy summa juda katta' });
    }
    const note = clean(b.note, 300);

    // 024: narx rejimi — bandda aniq berilsa o'sha, bo'lmasa to'yxona defaulti, bo'lmasa 'guest'.
    // 'total' rejimida total_price = butun to'yxona narxi (berilmasa to'yxona defaulti).
    let price_mode = 'guest';
    if (b.price_mode != null && b.price_mode !== '') {
      price_mode = String(b.price_mode);
      if (!PRICE_MODES.includes(price_mode)) return res.status(400).json({ success: false, error: "Narx rejimi noto'g'ri (guest / total)" });
    } else if (hall && PRICE_MODES.includes(hall.price_mode)) {
      price_mode = hall.price_mode;
    }
    if (guests === 0 && price_mode !== 'total') {
      return res.status(400).json({ success: false, error: `Mehmonlar soni 1–${MAX_GUESTS} bo'lsin` });
    }
    let total_price = 0;
    if (price_mode === 'total') {
      if (b.total_price != null && b.total_price !== '') {
        total_price = money(b.total_price, { allowZero: true });
        if (total_price == null) return res.status(400).json({ success: false, error: "To'yxona narxi noto'g'ri" });
      } else {
        total_price = Number(hall?.total_price) || 0;
      }
    }

    // 024: katalogdan servislar — [{service_id?, title?, amount?, qty?, is_bonus?}]
    const ri = await readBookingItems(req.user.id, b.items);
    if (ri.error) return res.status(400).json({ success: false, error: ri.error });

    let advance = 0;
    if (b.advance != null && b.advance !== '') {
      advance = money(b.advance, { allowZero: true });
      if (advance == null) return res.status(400).json({ success: false, error: "Avans noto'g'ri" });
    }

    // 024: avans yo'q → sana HOLD (default 48 soat, hold_hours 1..720). Muddat o'tsa
    // sweeper avto-bekor qiladi (toyxonaSweeper.js). Avans bor → hold yo'q.
    let hold_until = null;
    if (advance <= 0) {
      let hours = DEFAULT_HOLD_HOURS;
      if (b.hold_hours != null && b.hold_hours !== '') {
        hours = Math.round(Number(b.hold_hours));
        if (!Number.isInteger(hours) || hours < 0 || hours > 720) return res.status(400).json({ success: false, error: 'Hold 0–720 soat oralig\'ida bo\'lsin' });
      }
      if (hours > 0) hold_until = new Date(Date.now() + hours * 3600_000).toISOString();
    }

    // 024: mijoz Trustbook'da bormi? (telefon bo'yicha) — bog'lab qo'yamiz
    const client_user_id = client_phone ? await profileIdByPhone(client_phone) : null;

    // 1-qatlam: oldindan tekshiruv (chiroyli xabar, mijoz nomi bilan)
    const clash = await findSlotConflict(req.user.id, { hallId: hall?.id || null, date: event_date, slot });
    if (clash) {
      return res.status(409).json({
        ...SLOT_TAKEN_BODY,
        detail: `Band: ${clash.client_name}`,
      });
    }

    // 2-qatlam: DB indeksi (parallel so'rovlar) — 23505 ham SLOT_TAKEN
    const { data: created, error } = await supabaseAdmin.from('bookings').insert({
      user_id: req.user.id,
      hall_id: hall?.id || null,
      menu_id: menu?.id || null,
      menu_title: menu?.title || null,   // SNAPSHOT
      event_date, slot, client_name, client_phone, guests, price_per_guest, note,
      price_mode, total_price, hold_until, client_user_id,
    }).select().single();
    if (error) {
      if (isUniqueViolation(error)) return res.status(409).json(SLOT_TAKEN_BODY);
      throw new Error(error.message);
    }

    // 024: servislar (SNAPSHOT). Yiqilsa band o'chiriladi (avans bilan bir xil siyosat).
    if (ri.items.length) {
      const { error: ie } = await supabaseAdmin.from('booking_items')
        .insert(ri.items.map((it) => ({ booking_id: created.id, ...it })));
      if (ie) {
        await supabaseAdmin.from('bookings').delete().eq('id', created.id).eq('user_id', req.user.id);
        throw new Error(ie.message);
      }
    }

    // Avans > 0 — birinchi to'lov + AQLLI STATUS ('band' -> 'tasdiq').
    // QO'LDA ORTGA QAYTARISH: bu yerda tranzaksiya yo'q (PostgREST har chaqiruvni
    // alohida commit qiladi). To'lov yozilmasa BAND QOLIB KETARDI — mijoz "xato"
    // ko'radi, lekin sana band bo'lib, bepul kvotadan ham bittasi yeb qo'yilardi.
    // Shuning uchun to'lov yiqilsa yangi bandni O'CHIRAMIZ va xatoni qaytaramiz.
    if (advance > 0) {
      const { error: pe } = await supabaseAdmin.from('booking_payments')
        .insert({ booking_id: created.id, amount: advance, kind: 'avans' });
      if (pe) {
        // Ortga qaytarishning O'ZI ham yiqilishi mumkin. Ilgari uning xatosi
        // e'tiborsiz qolardi: mijoz "hech narsa yaratilmadi" degan 500 olardi,
        // ammo band QOLIB KETARDI va o'sha sana abadiy SLOT_TAKEN berardi —
        // egasi uchun chiqish yo'li yo'q edi. Endi baland ovozda log qilamiz
        // (booking id bilan — qo'lda tozalash uchun). user_id — qo'shimcha
        // himoya qatlami: bu delete faqat O'Z bandimizga tegishi kafolatlanadi.
        const { error: de } = await supabaseAdmin.from('bookings')
          .delete().eq('id', created.id).eq('user_id', req.user.id);
        if (de) {
          console.error(`[toyxona] JIDDIY: avans yozilmadi va band ham o'chmadi — `
            + `qo'lda tozalash kerak (booking=${created.id}, user=${req.user.id}):`, de.message);
        }
        throw new Error(pe.message);
      }
      const totals = computeTotals(created, ri.items, [{ amount: advance }]);
      const next = autoStatusAfterPayment(created.status, totals.left);
      if (next !== created.status) {
        const { error: ue } = await supabaseAdmin.from('bookings')
          .update({ status: next, updated_at: new Date().toISOString() }).eq('id', created.id);
        // Status yangilanmasa band + to'lov O'RNIDA qoladi (pul yo'qolmaydi) —
        // faqat status 'band' bo'lib qoladi, egasi qo'lda tuzatadi. O'chirmaymiz.
        if (ue) console.warn('[toyxona] avans statusi yangilanmadi:', ue.message);
      }
    }

    const full = await loadOneBooking(req.user.id, created.id);
    // 024: minimal avans — BLOKLAMAYDI (avans keyin kelishi normal), faqat ko'rsatiladi
    const depMin = depositMin(full.totals.total, hall?.deposit_pct);
    res.status(201).json({
      success: true, data: full,
      deposit_min: depMin,
      deposit_short: depMin > 0 && advance < depMin,
    });
  } catch (e) { next(e); }
});

// GET /api/toyxona/bookings/search?q=<matn>&limit=<n>
// Mijoz NOMI yoki TELEFONI bo'yicha qidiruv (kamida 2 belgi; limit ≤ 50, default 20).
// Telefon uchun kiritmadagi RAQAMLAR olinadi (kamida 3 ta bo'lsa) — "90 123" ham
// "90-123" ham bir xil ishlaydi (searchTerms izohiga qarang). Natija GET /bookings
// bilan AYNAN bir xil shakl (mapBooking: hall_name + items/payments/totals) —
// mobil bir xil kartani chizadi. Tartib: event_date DESC (eng yangi to'y birinchi).
// YO'L TO'QNASHUVI YO'Q: '/bookings/:id' ko'rinishidagi GET route umuman mavjud
// emas (PATCH/DELETE alohida metodlar), shuning uchun 'search' hech qachon id deb
// o'qilmaydi; baribir aniqlik uchun shu yerda — bookings bloki ichida — turadi.
router.get('/bookings/search', async (req, res, next) => {
  try {
    const raw = String(req.query.q ?? '').trim();
    if (raw.length < 2) {
      return res.status(400).json({ success: false, error: 'Qidiruv uchun kamida 2 ta belgi kiriting' });
    }
    const { text, digits } = searchTerms(raw);
    // Faqat sintaksis belgilaridan iborat kiritma ("%%", "()" ...) — qidirib bo'lmaydi
    if (!text && !digits) {
      return res.status(400).json({ success: false, error: "Qidiruv so'zi yaroqsiz — harf yoki raqam kiriting" });
    }
    const lim = parseInt(req.query.limit, 10);
    const limit = Number.isFinite(lim) && lim > 0 ? Math.min(lim, MAX_SEARCH_RESULTS) : DEF_SEARCH_RESULTS;

    // .or() ga FAQAT searchTerms tozalagan qiymatlar kiradi (%, `,`, `(`, `)`
    // olib tashlangan) — foydalanuvchi kiritmasi filtr sintaksisini buza olmaydi.
    const ors = [];
    if (text) ors.push(`client_name.ilike.%${text}%`);
    if (digits) ors.push(`client_phone.ilike.%${digits}%`);
    const { data, error } = await supabaseAdmin
      .from('bookings').select('*')
      .eq('user_id', req.user.id)
      .or(ors.join(','))
      .order('event_date', { ascending: false })
      .limit(limit);
    if (error) throw new Error(error.message);

    let rows = data || [];
    // 2026-08-10 review: telefon bazada KIRITILGANIDEK saqlanadi ("+998 90 123-45-67"),
    // ilike'dagi %<raqamlar>% esa faqat KETMA-KET raqamlarni topadi — real qatorlarning
    // ko'pi o'tkazib yuborilardi. Shu sabab raqamli qidiruvda so'nggi MAX_SEARCH_SCAN
    // band JS'da raqam-normallashtirib ham tekshiriladi (chegaralangan, indeksli tartib).
    if (digits && rows.length < limit) {
      const { data: scan, error: se } = await supabaseAdmin
        .from('bookings').select('*')
        .eq('user_id', req.user.id)
        .not('client_phone', 'is', null)
        .order('event_date', { ascending: false })
        .limit(MAX_SEARCH_SCAN);
      if (se) throw new Error(se.message);
      const seen = new Set(rows.map((b) => b.id));
      for (const b of scan || []) {
        if (seen.has(b.id)) continue;
        const ph = String(b.client_phone || '').replace(/\D/g, '');
        if (ph.includes(digits)) { rows.push(b); seen.add(b.id); }
      }
      rows.sort((a, b) => (a.event_date < b.event_date ? 1 : a.event_date > b.event_date ? -1 : 0));
      rows = rows.slice(0, limit);
    }
    const [{ itemsBy, paysBy }, halls] = await Promise.all([
      loadChildren(rows.map((b) => b.id)),
      hallNameMap(req.user.id),
    ]);
    res.json({
      success: true,
      data: rows.map((b) => mapBooking(b, halls.get(b.hall_id), itemsBy.get(b.id) || [], paysBy.get(b.id) || [])),
    });
  } catch (e) { next(e); }
});

// PATCH /api/toyxona/bookings/:id
// { hall_id?, menu_id?, event_date?, slot?, client_name?, client_phone?, guests?,
//   price_per_guest?, note?, status? }
// Sana / slot / zal o'zgarsa — konflikt QAYTA tekshiriladi (409).
// QO'LDA berilgan status HAR DOIM ustun (avtomatik qoidalar bu yerda ishlamaydi).
router.patch('/bookings/:id', async (req, res, next) => {
  try {
    const cur = await ownedBooking(req.user.id, req.params.id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const b = req.body || {};
    const patch = {};

    if (b.event_date !== undefined) {
      const d = String(b.event_date || '');
      if (!isDateStr(d)) return res.status(400).json({ success: false, error: "Sana noto'g'ri (YYYY-MM-DD)" });
      patch.event_date = d;
    }
    if (b.slot !== undefined) {
      const s = String(b.slot || '');
      if (!SLOTS.includes(s)) {
        return res.status(400).json({ success: false, error: "Vaqt noto'g'ri (nahor / tushlik / kechki)" });
      }
      patch.slot = s;
    }
    if ('hall_id' in b) {
      if (b.hall_id == null || b.hall_id === '') patch.hall_id = null;
      else {
        const hall = await ownedHall(req.user.id, b.hall_id);
        if (!hall) return res.status(400).json({ success: false, error: "To'yxona topilmadi" });
        patch.hall_id = hall.id;
      }
    }
    if (b.client_name !== undefined) {
      const n = clean(b.client_name, 80);
      if (!n) return res.status(400).json({ success: false, error: 'Mijoz ismi kerak' });
      patch.client_name = n;
    }
    if (b.client_phone !== undefined) {
      const ph = normPhone(b.client_phone);
      if (ph === false) return res.status(400).json({ success: false, error: "Telefon raqami noto'g'ri" });
      patch.client_phone = ph;
      patch.client_user_id = ph ? await profileIdByPhone(ph) : null;   // 024: qayta bog'lash
    }
    if (b.note !== undefined) patch.note = clean(b.note, 300);
    // 024: narx rejimi / podklyuch summasi
    if (b.price_mode !== undefined) {
      const m = String(b.price_mode || '');
      if (!PRICE_MODES.includes(m)) return res.status(400).json({ success: false, error: "Narx rejimi noto'g'ri (guest / total)" });
      patch.price_mode = m;
    }
    if (b.total_price !== undefined) {
      const t = money(b.total_price, { allowZero: true });
      if (t == null) return res.status(400).json({ success: false, error: "To'yxona narxi noto'g'ri" });
      patch.total_price = t;
    }
    if (b.hold_until !== undefined) {
      if (b.hold_until === null || b.hold_until === '') patch.hold_until = null;
      else {
        const ts = Date.parse(String(b.hold_until).slice(0, 40));
        if (Number.isNaN(ts)) return res.status(400).json({ success: false, error: "Hold muddati noto'g'ri" });
        patch.hold_until = new Date(ts).toISOString();
      }
    }
    if (b.guests !== undefined) {
      const g = Math.round(Number(b.guests));
      // 026: 0 faqat 'total' rejimida (yangi yoki joriy) ruxsat etiladi
      const mode = patch.price_mode ?? cur.price_mode ?? 'guest';
      if (!Number.isInteger(g) || g < 0 || g > MAX_GUESTS || (g === 0 && mode !== 'total')) {
        return res.status(400).json({ success: false, error: `Mehmonlar soni 1–${MAX_GUESTS} bo'lsin` });
      }
      patch.guests = g;
    }
    if (b.price_per_guest !== undefined) {
      const p = money(b.price_per_guest, { allowZero: true });
      if (p == null) return res.status(400).json({ success: false, error: "Bir mehmon narxi noto'g'ri" });
      patch.price_per_guest = p;
    }
    // Narx toifasi — YANGI to'yxona (agar o'zgargan bo'lsa) bo'yicha tekshiriladi
    const effHallId = patch.hall_id !== undefined ? patch.hall_id : (cur.hall_id || null);
    if ('menu_id' in b) {
      if (b.menu_id == null || b.menu_id === '') {
        patch.menu_id = null;
        patch.menu_title = null;   // toifani ATAYLAB uzdi — narx o'zgarmaydi
      } else {
        const r = await resolveMenu(req.user.id, b.menu_id, effHallId);
        if (r.error) return res.status(400).json({ success: false, error: r.error });
        patch.menu_id = r.menu.id;
        patch.menu_title = r.menu.title;              // yangi SNAPSHOT
        // Aniq narx berilmagan bo'lsa — yangi toifa narxi ko'chiriladi
        if (b.price_per_guest === undefined) patch.price_per_guest = Number(r.menu.price_per_guest) || 0;
      }
    } else if (patch.hall_id !== undefined && cur.menu_id) {
      // To'yxona o'zgardi, toifa berilmadi — eski toifa boshqa to'yxonaniki bo'lishi
      // mumkin. Bog'lanish uziladi, LEKIN menu_title va narx SNAPSHOT bo'lib qoladi
      // (mijozga nima sotilgani tarixi va shartnoma summasi yo'qolmasin).
      const old = await ownedMenu(req.user.id, cur.menu_id);
      if (!old || (old.hall_id || null) !== effHallId) patch.menu_id = null;
    }
    // Yakuniy (mehmon × narx) ko'paytmasi ham chegarada bo'lsin
    if (overMax(patch.guests ?? cur.guests, patch.price_per_guest ?? cur.price_per_guest)) {
      return res.status(400).json({ success: false, error: 'Umumiy summa juda katta' });
    }
    if (b.status !== undefined) {
      const s = String(b.status || '');
      if (!STATUSES.includes(s)) return res.status(400).json({ success: false, error: "Holat noto'g'ri" });
      patch.status = s;
    }
    if (!Object.keys(patch).length) {
      return res.status(400).json({ success: false, error: "O'zgarish yo'q" });
    }

    // Konflikt qayta tekshiruvi: sana/slot/zal yoki 'bekor' dan qaytish holatida
    const nextStatus = patch.status ?? cur.status;
    const touchesSlot = patch.event_date !== undefined || patch.slot !== undefined
      || patch.hall_id !== undefined || (cur.status === 'bekor' && nextStatus !== 'bekor');
    if (touchesSlot && nextStatus !== 'bekor') {
      const clash = await findSlotConflict(req.user.id, {
        hallId: patch.hall_id !== undefined ? patch.hall_id : cur.hall_id,
        date: patch.event_date ?? cur.event_date,
        slot: patch.slot ?? cur.slot,
        exceptId: cur.id,
      });
      if (clash) {
        return res.status(409).json({ ...SLOT_TAKEN_BODY, detail: `Band: ${clash.client_name}` });
      }
    }

    // 024: 'bekor'ga o'tish — jarima hisobi (POST /cancel bilan bir xil yo'l);
    // 'bekor'dan qaytish — bekor maydonlari tozalanadi.
    let cancelInfo = null;
    if (patch.status === 'bekor' && cur.status !== 'bekor') {
      delete patch.status;
      cancelInfo = await applyCancel(req.user.id, cur, { reason: clean(b.cancel_reason, 200) });
    } else if (cur.status === 'bekor' && nextStatus !== 'bekor') {
      patch.cancelled_at = null; patch.cancel_reason = null; patch.cancel_penalty = 0;
    }
    if (!Object.keys(patch).length && cancelInfo) {
      return res.json({ success: true, data: await loadOneBooking(req.user.id, cur.id), cancel: cancelInfo });
    }
    patch.updated_at = new Date().toISOString();
    const { error } = await supabaseAdmin.from('bookings').update(patch).eq('id', cur.id);
    if (error) {
      if (isUniqueViolation(error)) return res.status(409).json(SLOT_TAKEN_BODY);
      throw new Error(error.message);
    }
    const out = { success: true, data: await loadOneBooking(req.user.id, cur.id) };
    if (cancelInfo) out.cancel = cancelInfo;
    res.json(out);
  } catch (e) { next(e); }
});

// GET /api/toyxona/bookings/:id/cancel-preview — bekor qilsak nima bo'ladi? (024)
// { paid, penalty, refund, daysLeft, policy } — mobil "Bekor qilish" varag'ida ko'rsatadi.
router.get('/bookings/:id/cancel-preview', async (req, res, next) => {
  try {
    const cur = await ownedBooking(req.user.id, req.params.id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (cur.status === 'bekor') {
      return res.status(409).json({ success: false, code: 'ALREADY_CANCELLED', error: 'Band allaqachon bekor qilingan' });
    }
    res.json({ success: true, data: await cancelPreview(req.user.id, cur) });
  } catch (e) { next(e); }
});

// POST /api/toyxona/bookings/:id/cancel  { reason?, penalty?, refund_now? } (024)
//   penalty    — ega qo'lda o'zgartirgan jarima (siyosat o'rniga); tushgan puldan oshmaydi
//   refund_now — true bo'lsa qaytariladigan summa DARHOL 'qaytarim' to'lovi sifatida yoziladi
//                (ega mijozga pulni shu yerning o'zida qaytardi). Aks holda keyin
//                POST /payments {kind:'qaytarim'} bilan yoziladi.
router.post('/bookings/:id/cancel', async (req, res, next) => {
  try {
    const cur = await ownedBooking(req.user.id, req.params.id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });
    if (cur.status === 'bekor') {
      return res.status(409).json({ success: false, code: 'ALREADY_CANCELLED', error: 'Band allaqachon bekor qilingan' });
    }
    let penaltyOverride;
    if (req.body?.penalty != null && req.body.penalty !== '') {
      penaltyOverride = money(req.body.penalty, { allowZero: true });
      if (penaltyOverride == null) return res.status(400).json({ success: false, error: "Jarima summasi noto'g'ri" });
    }
    const info = await applyCancel(req.user.id, cur, {
      reason: clean(req.body?.reason, 200), penaltyOverride,
    });
    if (req.body?.refund_now && info.refund > 0) {
      const { error } = await supabaseAdmin.from('booking_payments')
        .insert({ booking_id: cur.id, amount: info.refund, kind: 'qaytarim', note: 'Bekor — qaytarim' });
      if (error) console.warn(`[toyxona] qaytarim yozilmadi (booking=${cur.id}):`, error.message);
    }
    res.json({ success: true, data: await loadOneBooking(req.user.id, cur.id), cancel: info });
  } catch (e) { next(e); }
});

// DELETE /api/toyxona/bookings/:id — QAT'IY o'chirish, FAQAT TO'LOVSIZ band uchun
// (xato kiritilgan bandni tozalash). TO'LOVI BOR band o'chirilmaydi (409
// HAS_PAYMENTS): cascade to'lov qatorlarini ham JIMGINA yo'q qilardi — egasi
// QO'LIGA OLGAN pul barcha yakunlardan izsiz yo'qolardi (kassadagi naqd bilan
// hisob mos kelmay qolardi). Bunday band uchun yagona yo'l — yumshoq bekor:
// PATCH { status: 'bekor' } (sanani bo'shatadi, pul tarixi cancelledPaid'da
// ko'rinib qoladi — foldSummary izohiga qarang).
router.delete('/bookings/:id', async (req, res, next) => {
  try {
    const cur = await ownedBooking(req.user.id, req.params.id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { count, error: ce } = await supabaseAdmin
      .from('booking_payments').select('id', { count: 'exact', head: true }).eq('booking_id', cur.id);
    if (ce) throw new Error(ce.message);   // sanoq yiqilsa himoya JIMGINA ochilib qolmasin
    if ((count || 0) > 0) {
      return res.status(409).json({
        success: false,
        code: 'HAS_PAYMENTS',
        error: "To'lovlari bor bandni o'chirib bo'lmaydi — avval 'bekor' qiling (pul tarixi saqlanadi)",
      });
    }
    const { error } = await supabaseAdmin.from('bookings').delete().eq('id', cur.id);
    if (error) throw new Error(error.message);
    res.json({ success: true });
  } catch (e) { next(e); }
});

// ============================ XIZMATLAR (items) ============================

// POST /api/toyxona/bookings/:id/items  { service_id? | title, amount?, qty?, is_bonus? }
// 024: service_id berilsa katalogdan SNAPSHOT (title/amount), is_bonus = bepul.
router.post('/bookings/:id/items', async (req, res, next) => {
  try {
    const cur = await ownedBooking(req.user.id, req.params.id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const ri = await readBookingItems(req.user.id, [req.body || {}]);
    if (ri.error) return res.status(400).json({ success: false, error: ri.error });
    const item = ri.items[0];
    const { count, error: ce } = await supabaseAdmin
      .from('booking_items').select('id', { count: 'exact', head: true }).eq('booking_id', cur.id);
    if (ce) throw new Error(ce.message);
    if ((count || 0) >= 50) {
      return res.status(400).json({ success: false, error: "Bitta bandga 50 tadan ortiq xizmat qo'shib bo'lmaydi" });
    }
    const { error } = await supabaseAdmin.from('booking_items')
      .insert({ booking_id: cur.id, ...item });
    if (error) throw new Error(error.message);
    // INVARIANT (ataylab tanlangan, mobil shunga qarab chizsin): status — EGA
    // boshqaradigan ish holati, `left` dan HOSIL QILINMAYDI. Xizmat qo'shish
    // statusni o'zgartirmaydi, shuning uchun 'yakun' bandga keyin xizmat
    // qo'shilsa `left > 0` bo'lib qolishi MUMKIN va bu buzuq holat EMAS —
    // "to'y o'tdi, lekin salyut alohida hisoblandi" degani.
    // Avtomatik ko'tarish faqat TO'LOVDA ishlaydi (autoStatusAfterPayment), chunki
    // bu yerda uni chaqirish hech qachon foyda bermaydi: xizmat `left` ni
    // OSHIRADI, ko'tarish sharti esa left <= 0 ni talab qiladi.
    // Mobil qoidasi: qoldiqni HAR DOIM `totals.left` bo'yicha ko'rsating, statusga
    // qarab emas. Egasi xohlasa statusni oddiy PATCH bilan qaytaradi.
    res.status(201).json({ success: true, data: await loadOneBooking(req.user.id, cur.id) });
  } catch (e) { next(e); }
});

// DELETE /api/toyxona/items/:itemId — ota-band EGA tekshiriladi (cross-user yo'q)
// PATCH /api/toyxona/items/:itemId  { is_bonus?, qty?, amount? } — 024 (bonusni yoqish/o'chirish)
router.patch('/items/:itemId', async (req, res, next) => {
  try {
    if (!isUuid(req.params.itemId)) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { data: item, error: ie } = await supabaseAdmin
      .from('booking_items').select('*').eq('id', req.params.itemId).maybeSingle();
    if (ie) throw new Error(ie.message);
    if (!item) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const cur = await ownedBooking(req.user.id, item.booking_id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const patch = {};
    if (req.body?.is_bonus !== undefined) patch.is_bonus = !!req.body.is_bonus;
    if (req.body?.qty !== undefined) {
      const q = Math.round(Number(req.body.qty));
      if (!Number.isInteger(q) || q <= 0 || q > MAX_QTY) return res.status(400).json({ success: false, error: `Soni 1–${MAX_QTY} bo'lsin` });
      patch.qty = q;
    }
    if (req.body?.amount !== undefined) {
      const a = money(req.body.amount, { allowZero: true });
      if (a == null) return res.status(400).json({ success: false, error: "Narx noto'g'ri" });
      patch.amount = a;
    }
    if (!Object.keys(patch).length) return res.status(400).json({ success: false, error: "O'zgarish yo'q" });
    const bonus = patch.is_bonus ?? item.is_bonus;
    const amount = patch.amount ?? Number(item.amount);
    if (!bonus && amount <= 0) return res.status(400).json({ success: false, error: 'Pullik xizmat narxi kerak' });
    const { error } = await supabaseAdmin.from('booking_items').update(patch).eq('id', item.id);
    if (error) throw new Error(error.message);
    res.json({ success: true, data: await loadOneBooking(req.user.id, cur.id) });
  } catch (e) { next(e); }
});

router.delete('/items/:itemId', async (req, res, next) => {
  try {
    if (!isUuid(req.params.itemId)) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { data: item, error: ie } = await supabaseAdmin
      .from('booking_items').select('id, booking_id').eq('id', req.params.itemId).maybeSingle();
    if (ie) throw new Error(ie.message);
    if (!item) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const cur = await ownedBooking(req.user.id, item.booking_id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const { error } = await supabaseAdmin.from('booking_items').delete().eq('id', item.id);
    if (error) throw new Error(error.message);
    res.json({ success: true, data: await loadOneBooking(req.user.id, cur.id) });
  } catch (e) { next(e); }
});

// ============================ TO'LOVLAR (payments) ============================

// POST /api/toyxona/bookings/:id/payments  { amount, kind?, note?, paid_at? }
// AQLLI STATUS shu yerda ishlaydi (autoStatusAfterPayment).
router.post('/bookings/:id/payments', async (req, res, next) => {
  try {
    const cur = await ownedBooking(req.user.id, req.params.id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const amount = money(req.body?.amount);
    if (amount == null) {
      return res.status(400).json({ success: false, error: "Summa musbat butun son bo'lishi kerak" });
    }
    const kind = req.body?.kind == null || req.body.kind === '' ? 'avans' : String(req.body.kind);
    if (!KINDS.includes(kind)) {
      return res.status(400).json({ success: false, error: "To'lov turi noto'g'ri (avans / yakuniy / qaytarim)" });
    }
    // 024: qaytarim tushgan puldan oshmasin (manfiy kassa bo'lmasin)
    if (kind === 'qaytarim') {
      const before = await loadOneBooking(req.user.id, cur.id);
      if (amount > before.totals.paid) {
        return res.status(400).json({
          success: false, code: 'REFUND_OVER',
          error: `Qaytarim tushgan puldan (${before.totals.paid.toLocaleString('ru-RU')}) oshmasin`,
        });
      }
    }
    const note = clean(req.body?.note, 200);
    let paid_at = null;
    if (req.body?.paid_at != null && req.body.paid_at !== '') {
      const raw = String(req.body.paid_at).slice(0, 40);
      const ts = Date.parse(raw);
      if (Number.isNaN(ts)) return res.status(400).json({ success: false, error: "To'lov sanasi noto'g'ri" });
      paid_at = new Date(ts).toISOString();
    }
    const { count, error: ce } = await supabaseAdmin
      .from('booking_payments').select('id', { count: 'exact', head: true }).eq('booking_id', cur.id);
    if (ce) throw new Error(ce.message);
    if ((count || 0) >= 50) {
      return res.status(400).json({ success: false, error: "Bitta bandga 50 tadan ortiq to'lov qo'shib bo'lmaydi" });
    }

    // TAKROR TO'LOVDAN HIMOYA (ijara.js POST /payments bilan bir xil oyna).
    // Render sovuq startda javob mobil timeout'idan (20s) kechikishi mumkin;
    // mobil esa foydalanuvchiga ATAYLAB "qayta urinib ko'ring" deydi. So'rov
    // aslida bajarilgan bo'lsa, takror urinish AYNAN o'sha to'lovni IKKINCHI
    // marta yozardi — avans ikki barobar ko'rinardi. Shu bois qisqa oynada
    // (DEDUP_MS) bir xil (band + summa + tur) to'lov qayta yozilmaydi: band
    // mavjud holicha qaytariladi (idempotent), avto-status ham QAYTA ishlamaydi.
    // booking_payments'da user_id YO'Q — egalik yuqorida ownedBooking bilan
    // tekshirilgan, booking_id filtri o'zi yetarli.
    // Haqiqatan ikkita bir xil to'lovni ketma-ket kiritish kerak bo'lsa —
    // oynadan keyin kiritiladi; pulni ikki marta sanagandan ko'ra shu yaxshiroq.
    const dupSince = new Date(Date.now() - DEDUP_MS).toISOString();
    const { data: dup } = await supabaseAdmin
      .from('booking_payments').select('id')
      .eq('booking_id', cur.id).eq('amount', amount).eq('kind', kind)
      .gte('created_at', dupSince).limit(1);
    if (dup && dup.length) {
      return res.status(200).json({
        success: true,
        data: await loadOneBooking(req.user.id, cur.id),
        deduped: true,
      });
    }

    const row = { booking_id: cur.id, amount, kind, note };
    if (paid_at) row.paid_at = paid_at;
    const { error } = await supabaseAdmin.from('booking_payments').insert(row);
    if (error) throw new Error(error.message);

    // Yangi yakun bo'yicha avtomatik status (faqat KO'TARILADI, hech qachon pasaymaydi)
    const full = await loadOneBooking(req.user.id, cur.id);
    // Qaytarim statusni o'zgartirmaydi (pul chiqishi — tasdiq emas)
    const next = kind === 'qaytarim' ? cur.status : autoStatusAfterPayment(cur.status, full.totals.left);
    if (next !== cur.status) {
      const { error: ue } = await supabaseAdmin.from('bookings')
        .update({ status: next, updated_at: new Date().toISOString() }).eq('id', cur.id);
      // TAKROR TO'LOVGA QARSHI (2026-08-04 review): ilgari bu yerda `throw` bor edi.
      // To'lov qatori ALLAQACHON yozilgandan keyin status yangilanmasa mijoz 500
      // olardi, qayta yuborardi va PUL IKKI MARTA yozilardi. Endi POST /bookings
      // dagi avans yo'li bilan BIR XIL: ogohlantirib, 201 qaytaramiz — status
      // 'band' bo'lib qoladi, egasi oddiy PATCH bilan tuzatadi.
      if (ue) console.warn(`[toyxona] status yangilanmadi (booking=${cur.id}):`, ue.message);
      else full.status = next;
    }
    // 024: pul keldi — hold endi kerak emas
    if (kind !== 'qaytarim' && cur.hold_until) {
      await supabaseAdmin.from('bookings').update({ hold_until: null }).eq('id', cur.id);
      full.hold_until = null;
    }
    res.status(201).json({ success: true, data: full });
  } catch (e) { next(e); }
});

// DELETE /api/toyxona/payments/:payId
// Status ATAYLAB pasaytirilmaydi (qoida 4) — egasi qo'lda PATCH qiladi.
router.delete('/payments/:payId', async (req, res, next) => {
  try {
    if (!isUuid(req.params.payId)) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { data: pay, error: pe } = await supabaseAdmin
      .from('booking_payments').select('id, booking_id').eq('id', req.params.payId).maybeSingle();
    if (pe) throw new Error(pe.message);
    if (!pay) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const cur = await ownedBooking(req.user.id, pay.booking_id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const { error } = await supabaseAdmin.from('booking_payments').delete().eq('id', pay.id);
    if (error) throw new Error(error.message);
    res.json({ success: true, data: await loadOneBooking(req.user.id, cur.id) });
  } catch (e) { next(e); }
});

// ============================ YAKUN (summary) ============================

// GET /api/toyxona/summary?from=&to=&hall_id=
//   -> { count, countActive, total, paid, left, cancelledPaid, byStatus }
// hall_id — AYNAN BITTA to'yxona hisobi (har to'yxona alohida hisob yuritadi);
// berilmasa barcha to'yxonalar birgalikda.
// PUL yig'indilari 'bekor' bandlarni HISOBGA OLMAYDI (bekor qilingan to'y daromad
// emas), `count` esa ularni ham sanaydi — shu sababli `countActive` (= count −
// bekor) ham qaytariladi: sarlavhada "N to'y · <total>" ko'rsatgan mijoz o'zi
// ayirish qilmasin (foldSummary izohiga qarang).
// Bekor qilinganlarga tushgan AVANS `cancelledPaid` da alohida chiqadi — u
// `paid` ga QO'SHILMAYDI, lekin ekranda ko'rinib turadi (egada qolgan real pul).
router.get('/summary', async (req, res, next) => {
  try {
    const range = readRange(req.query);
    if (range.error) return res.status(400).json({ success: false, error: range.error });
    const hallFilter = readHallFilter(req.query);
    if (hallFilter.error) return res.status(400).json({ success: false, error: hallFilter.error });

    let q = supabaseAdmin
      .from('bookings').select('id, guests, price_per_guest, status, price_mode, total_price, cancel_penalty')
      .eq('user_id', req.user.id)
      .gte('event_date', range.from).lte('event_date', range.to);
    q = applyHallFilter(q, hallFilter);
    // `.order()` SHART: `.limit()` tartibsiz qo'llanilsa Postgres ixtiyoriy
    // qatorlarni qaytaradi — /summary va /bookings bir oraliq uchun HAR XIL pul
    // ko'rsatishi mumkin edi. Endi ikkalasi ham event_date bo'yicha tartiblangan,
    // ya'ni kesilganda ham AYNAN bir xil to'plamni ko'radi.
    const { data, error } = await q.order('event_date').limit(MAX_SUMMARY_BOOKINGS);
    if (error) throw new Error(error.message);

    const rows = data || [];
    const truncated = rows.length >= MAX_SUMMARY_BOOKINGS;
    // Kesilgan bo'lsa rows.length HAQIQIY sonni bildirmaydi (u shunchaki shift) —
    // "N to'y" sarlavhasi jimgina yolg'on gapirardi. Haqiqiy sonni alohida
    // head-so'rov bilan olamiz (faqat kesilganda — ortiqcha so'rov qilmaymiz).
    let realCount = null;
    if (truncated) {
      let cq = supabaseAdmin
        .from('bookings').select('id', { count: 'exact', head: true })
        .eq('user_id', req.user.id)
        .gte('event_date', range.from).lte('event_date', range.to);
      cq = applyHallFilter(cq, hallFilter);
      const { count, error: ce } = await cq;
      if (ce) throw new Error(ce.message);
      realCount = count || 0;
    }
    const { itemsBy, paysBy } = await loadChildren(rows.map((b) => b.id));
    const summary = foldSummary(rows, itemsBy, paysBy);
    // count — oraliqdagi HAQIQIY band soni; countActive/total/paid esa faqat
    // o'qilgan qatorlar bo'yicha (truncated=true bo'lsa ular to'liq emas).
    if (realCount != null) summary.count = realCount;
    // 024 analitika: bandlik % = faol bandlar / (kunlar × 3 slot × faol to'yxonalar)
    let hallsN = 1;
    if (!hallFilter.hallId) {
      const { count: hc } = await supabaseAdmin.from('halls').select('id', { count: 'exact', head: true })
        .eq('user_id', req.user.id).eq('archived', false);
      hallsN = Math.max(1, hc || 0);
    }
    const slots = (daysBetween(range.from, range.to) + 1) * SLOTS.length * hallsN;
    summary.occupancyPct = slots > 0 ? Math.round(summary.countActive * 1000 / slots) / 10 : 0;
    res.json({
      success: true,
      data: summary,
      range: { from: range.from, to: range.to, hall_id: hallFilter.hallId },
      truncated,   // yakun to'liq emasligi belgisi
    });
  } catch (e) { next(e); }
});

export default router;

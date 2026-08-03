// Parse pipeline stress test — 112 realistic human inputs across 14 groups.
// READ-ONLY: parseText only (no learnFrom, no inserts). Run from repo root:
//   node docs/team-reports/e2e/parse-combos.mjs
// Sequential, ~1100ms between LLM calls (Groq free tier is shared with prod).
import { writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..', '..', '..');
const RESULTS_PATH = join(HERE, 'parse-combos-results.json');

const { config } = await import(pathToFileURL(join(ROOT, 'src', 'config.js')).href);
const { supabaseAdmin } = await import(pathToFileURL(join(ROOT, 'src', 'lib', 'supabase.js')).href);
const { parseText, amountSpans, isQarz } = await import(pathToFileURL(join(ROOT, 'src', 'services', 'parse.js')).href);

if (!config.llm.groqKey) {
  console.error('FATAL: GROQ_API_KEY yo\'q — LLM testi mumkin emas.');
  process.exit(1);
}

// ---------- test user: most recent expenses row (read-only) ----------
const { data: expRows, error: expErr } = await supabaseAdmin
  .from('expenses').select('user_id').order('created_at', { ascending: false }).limit(1);
if (expErr || !expRows?.length) {
  console.error('FATAL: expenses dan user topilmadi:', expErr?.message || 'bo\'sh');
  process.exit(1);
}
const USER_ID = expRows[0].user_id;
console.log('Test user:', String(USER_ID).slice(0, 8) + '…');

// Safety: user must already have categories (so parseText's ensureCategories never inserts)
const { data: catRows } = await supabaseAdmin
  .from('categories').select('name, archived').eq('user_id', USER_ID);
if (!catRows?.length) {
  console.error('FATAL: bu userda categories yo\'q — ensureCategories INSERT qilardi. To\'xtatildi.');
  process.exit(1);
}
const USER_CATS = catRows.filter((c) => !c.archived).map((c) => c.name);
console.log('User categories:', USER_CATS.join(', '));

// ---------- helpers ----------
const NBSP = ' ';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const ci = (s) => String(s || '').trim().toLowerCase();

// ---------- PART A: pure amountSpans regression (no LLM, free) ----------
const SPAN_CASES = [
  { text: "120 000 so'm", expect: [120000] },
  { text: `400${NBSP}000`, expect: [400000] },                 // NBSP-grouped (mobile _NumGroupFmt)
  { text: `1${NBSP}500${NBSP}000 remont`, expect: [1500000] }, // NBSP double group
  { text: '25,000', expect: [25000] },
  { text: '1,200,000 telefon', expect: [1200000] },
  { text: '1.5 mln', expect: [1500000] },
  { text: '200k', expect: [200000] },
  { text: '200к taksi', expect: [200000] },                    // cyrillic к
  { text: '4m', expect: [4000000] },
  { text: '4 млн', expect: [4000000] },
  { text: '3 тыс', expect: [3000] },
  { text: '2 миллион uy', expect: [2000000] },
  { text: '5000 kofe', expect: [5000] },                       // k of kofe is NOT a multiplier
  { text: 'чой 10 минг', expect: [10000] },
  { text: '10 dollar obed', expect: [10] },                    // no UZS conversion in rules
  { text: 'obedga 35.5 ming ketdi', expect: [35500] },
  { text: 'svetga 80000som', expect: [80000] },
  { text: 'tkasi 15ming', expect: [15000] },                   // glued multiplier
  { text: 'taksga 12 mng ketdi', expect: [12] },               // broken mult is NOT a multiplier
  { text: 'kamunalga 120 ping toladim', expect: [120] },       // "ping" typo is NOT a multiplier
  { text: 'mingta odam keldi', expect: [] },                   // no digits at all
  { text: 'bozorga 200 ming taksiga 30 ming', expect: [200000, 30000] },
  { text: 'nonushta 25k obed 40k kechki 60k', expect: [25000, 40000, 60000] },
];

const spanResults = [];
for (const c of SPAN_CASES) {
  const got = amountSpans(c.text).map((s) => s.amount);
  const pass = JSON.stringify(got) === JSON.stringify(c.expect);
  spanResults.push({ text: c.text.replace(new RegExp(NBSP, 'g'), '<NBSP>'), expect: c.expect, got, pass });
  if (!pass) console.log(`SPAN FAIL: "${c.text}" expect ${JSON.stringify(c.expect)} got ${JSON.stringify(got)}`);
}
console.log(`amountSpans: ${spanResults.filter((r) => r.pass).length}/${spanResults.length} pass`);

// ---------- PART B: full pipeline cases ----------
// Case shape:
//  text, group
//  accept: acceptable categories (single-action, non-qarz)
//  acceptNew: regex sources for acceptable new_category_suggestion themes (also matched
//             against the chosen category — user may already own such a folder) | null
//  amounts: expected amounts (multiset) | amountsAnyOf: list of acceptable multisets
//  qarz: expected qarz direction | undefined
//  person: substring expected in action.person (qarz only) | undefined
//  multi: [{ amount, accept: [...] }] for multi-action cases
//  incomeOk: true — 'daromad' direction is acceptable-but-noteworthy
//  mustXarajat: true — direction MUST be xarajat (income words present but spending)
//  usd: N — amount may be N (raw) or N*10000..N*16000 (converted)
const CASES = [
  // ---- 1. Toshkent og'zaki ----
  { group: '1-toshkent', text: 'obed qivoldik 35 ming', accept: ['Oziq-ovqat'], amounts: [35000] },
  { group: '1-toshkent', text: 'marshrutkaga 3 ming ketti', accept: ['Transport'], amounts: [3000] },
  { group: '1-toshkent', text: 'ishga borishga taksi chaqirdim 18 ming', accept: ['Transport'], amounts: [18000] },
  { group: '1-toshkent', text: 'magazindan narsa-qarsa olib keldim 95 ming', accept: ['Oziq-ovqat', 'Boshqa'], acceptNew: ["uy|ro'zg'or|rozg'or"], amounts: [95000] },
  { group: '1-toshkent', text: "choyxonada o'tirdik 60 ming chiqdi", accept: ['Oziq-ovqat', "Ko'ngilochar"], amounts: [60000] },
  { group: '1-toshkent', text: 'telefonimga pul soldim 20 ming', accept: ['Kommunal'], amounts: [20000] },
  { group: '1-toshkent', text: 'bolalarga muzqaymoq oldim 12 ming', accept: ['Oziq-ovqat'], amounts: [12000] },
  { group: '1-toshkent', text: 'kechqurun kabobxonaga chiqdik 85 ming ketti', accept: ['Oziq-ovqat', "Ko'ngilochar"], amounts: [85000] },
  // ---- 2. Farg'ona/Andijon ----
  { group: '2-fargona', text: "bozorga chiqib 80 mingni ishlatvordim", accept: ['Oziq-ovqat'], amounts: [80000] },
  { group: '2-fargona', text: "somsa yeb keldik 20 ming bo'pti", accept: ['Oziq-ovqat'], amounts: [20000] },
  { group: '2-fargona', text: "mashinaga moy aldirdim 120 ming bo'ldi", accept: ['Transport'], acceptNew: ["avto|remont|ta'mir|tamir"], amounts: [120000] },
  { group: '2-fargona', text: "to'yga o'tqizdik 300 ming berdik", accept: ['Boshqa', "Ko'ngilochar"], acceptNew: ["to'y|toy|sovg'a|sovga|marosim"], amounts: [300000] },
  { group: '2-fargona', text: "palov damladik masalliq 70 ming bo'pti", accept: ['Oziq-ovqat'], amounts: [70000] },
  { group: '2-fargona', text: "adirga chiqib ketuvdik yo'lkira 25 ming bo'pti", accept: ['Transport', "Ko'ngilochar"], amounts: [25000] },
  { group: '2-fargona', text: "do'konga tushib bugun 45 mingni ishlatvordim", accept: ['Oziq-ovqat', 'Boshqa'], amounts: [45000] },
  { group: '2-fargona', text: 'choyxonaga chiqib 90 ming sochvordik', accept: ['Oziq-ovqat', "Ko'ngilochar"], amounts: [90000] },
  // ---- 3. Xorazm ----
  { group: '3-xorazm', text: 'ekin dori aldim 60 ming', accept: ['Boshqa'], acceptNew: ["dehqon|qishloq|ekin|agro|bog'|hosil"], amounts: [60000] },
  { group: '3-xorazm', text: 'bazarga barib 100 ming savdo etdim', accept: ['Oziq-ovqat', 'Boshqa'], amounts: [100000] },
  { group: '3-xorazm', text: 'taksa minib galdim 15 ming berdim', accept: ['Transport'], amounts: [15000] },
  { group: '3-xorazm', text: "o'g'limga kitob aldim 40 ming", accept: ['Boshqa'], acceptNew: ["ta'lim|talim|kitob|maktab|o'quv"], amounts: [40000] },
  { group: '3-xorazm', text: 'gazing pulini tuladim 95 ming', accept: ['Kommunal'], amounts: [95000] },
  { group: '3-xorazm', text: "shipoxonaga barib 50 ming to'ladim", accept: ['Salomatlik'], amounts: [50000] },
  { group: '3-xorazm', text: 'nabiramga shirinlik aldim 10 ming', accept: ['Oziq-ovqat', 'Boshqa'], acceptNew: ["sovg'a|sovga"], amounts: [10000] },
  { group: '3-xorazm', text: 'moshinga benzin quydirdim 150 ming boldi', accept: ['Transport'], amounts: [150000] },
  // ---- 4. Qashqadaryo/Surxondaryo ----
  { group: '4-qashqadaryo', text: "mol bozoriga borib 50 ming yo'l kira berdim", accept: ['Transport'], amounts: [50000] },
  { group: '4-qashqadaryo', text: "qo'y sotib oldim 2 mln berdim", accept: ['Boshqa', 'Oziq-ovqat'], acceptNew: ["chorva|mol|qishloq|hayvon"], amounts: [2000000] },
  { group: '4-qashqadaryo', text: "bozor-o'char qildik 250 ming ketdi", accept: ['Oziq-ovqat'], amounts: [250000] },
  { group: '4-qashqadaryo', text: 'usta chaqirtirdim tom yopishga 400 ming berdim', accept: ['Boshqa', 'Kommunal'], acceptNew: ["remont|ta'mir|tamir|uy|qurilish"], amounts: [400000] },
  { group: '4-qashqadaryo', text: 'toyga bordik 200 ming solduk', accept: ['Boshqa', "Ko'ngilochar"], acceptNew: ["to'y|toy|sovg'a|sovga|marosim"], amounts: [200000] },
  { group: '4-qashqadaryo', text: "bolamning maktabiga 100 ming to'lab keldim", accept: ['Boshqa'], acceptNew: ["ta'lim|talim|maktab|o'quv"], amounts: [100000] },
  { group: '4-qashqadaryo', text: 'chorvaga yem oldim 180 ming', accept: ['Boshqa'], acceptNew: ["chorva|yem|qishloq|hayvon"], amounts: [180000] },
  { group: '4-qashqadaryo', text: 'shahardan kelishga 30 ming kira haqi berdim', accept: ['Transport'], amounts: [30000] },
  // ---- 5. Kirill-o'zbek ----
  { group: '5-kirill', text: 'нонга 5 минг кетди', accept: ['Oziq-ovqat'], amounts: [5000] },
  { group: '5-kirill', text: 'таксига 15 минг тўладим', accept: ['Transport'], amounts: [15000] },
  { group: '5-kirill', text: 'дорихонага 45 минг кетди', accept: ['Salomatlik'], amounts: [45000] },
  { group: '5-kirill', text: 'болаларга кийим олдим 350 минг', accept: ['Kiyim'], amounts: [350000] },
  { group: '5-kirill', text: 'светга 60 минг тўладим', accept: ['Kommunal'], amounts: [60000] },
  { group: '5-kirill', text: 'бозордан мева олдим 75 минг', accept: ['Oziq-ovqat'], amounts: [75000] },
  { group: '5-kirill', text: 'кинога бордик 50 минг сарфладик', accept: ["Ko'ngilochar"], amounts: [50000] },
  { group: '5-kirill', text: 'интернетга 89 минг тўладим', accept: ['Kommunal'], amounts: [89000] },
  // ---- 6. Rus aralash ----
  { group: '6-rus-aralash', text: 'заправкага 200 ming benzin quydim', accept: ['Transport'], amounts: [200000] },
  { group: '6-rus-aralash', text: 'обед 40k stolovoyda', accept: ['Oziq-ovqat'], amounts: [40000] },
  { group: '6-rus-aralash', text: 'проездга 10 минг кетди', accept: ['Transport'], amounts: [10000] },
  { group: '6-rus-aralash', text: 'продукти olib keldim 320 ming', accept: ['Oziq-ovqat'], amounts: [320000] },
  { group: '6-rus-aralash', text: 'аптекадан лекарство oldim 55 ming', accept: ['Salomatlik'], amounts: [55000] },
  { group: '6-rus-aralash', text: "за квартиру 1.2 mln to'ladim", accept: ['Kommunal'], amounts: [1200000] },
  { group: '6-rus-aralash', text: 'detskiy sadga 500 ming oplatit qildim', accept: ['Boshqa'], acceptNew: ["ta'lim|talim|bog'cha|bogcha"], amounts: [500000] },
  { group: '6-rus-aralash', text: 'мороженое bolalarga 18 ming', accept: ['Oziq-ovqat'], amounts: [18000] },
  // ---- 7. Qisqa emotsional ----
  { group: '7-emotsional', text: 'uf 20k taksi', accept: ['Transport'], amounts: [20000] },
  { group: '7-emotsional', text: 'voy 150 ming ketti kiyimga', accept: ['Kiyim'], amounts: [150000] },
  { group: '7-emotsional', text: 'yana dori 30k \u{1F629}', accept: ['Salomatlik'], amounts: [30000] },
  { group: '7-emotsional', text: 'eh 500 ming ketdi bir pasda', accept: ['Boshqa'], amounts: [500000] },
  { group: '7-emotsional', text: 'ufff obed 45k', accept: ['Oziq-ovqat'], amounts: [45000] },
  { group: '7-emotsional', text: 'yana benzin 250k \u{1F4B8}', accept: ['Transport'], amounts: [250000] },
  { group: '7-emotsional', text: 'internet tugadi yana 25k \u{1F62D}', accept: ['Kommunal'], amounts: [25000] },
  { group: '7-emotsional', text: 'bugun 90k ket di kafega', accept: ['Oziq-ovqat', "Ko'ngilochar"], amounts: [90000] },
  // ---- 8. Xato/typo ----
  { group: '8-typo', text: 'tkasi 15ming', accept: ['Transport'], amounts: [15000] },
  { group: '8-typo', text: "kamunalga 120 ping to'ladim", accept: ['Kommunal'], amountsAnyOf: [[120000], [120]] },
  { group: '8-typo', text: 'svetga 80000som', accept: ['Kommunal'], amounts: [80000] },
  { group: '8-typo', text: 'aptkaga 25 mig dori oldim', accept: ['Salomatlik'], amountsAnyOf: [[25000], [25]] },
  { group: '8-typo', text: 'taksga 12 mng ketdi', accept: ['Transport'], amountsAnyOf: [[12000], [12]] },
  { group: '8-typo', text: 'obetga 38 ming ishlatim', accept: ['Oziq-ovqat'], amounts: [38000] },
  { group: '8-typo', text: 'bozorga borip 65 min ishlatdim', accept: ['Oziq-ovqat'], amountsAnyOf: [[65000], [65]] },
  { group: '8-typo', text: 'kiyimga 220 000 som berdim', accept: ['Kiyim'], amounts: [220000] },
  // ---- 9. Ko'p amalli ----
  { group: '9-kop-amal', text: 'bozorga 200 ming taksiga 30 ming berdim', multi: [{ amount: 200000, accept: ['Oziq-ovqat'] }, { amount: 30000, accept: ['Transport'] }] },
  { group: '9-kop-amal', text: 'nonushta 25k obed 40k kechki 60k', multi: [{ amount: 25000, accept: ['Oziq-ovqat'] }, { amount: 40000, accept: ['Oziq-ovqat'] }, { amount: 60000, accept: ['Oziq-ovqat'] }] },
  { group: '9-kop-amal', text: "svetga 80 ming gazga 60 ming to'ladim", multi: [{ amount: 80000, accept: ['Kommunal'] }, { amount: 60000, accept: ['Kommunal'] }] },
  { group: '9-kop-amal', text: 'dorixonaga 45 ming va taksiga 20 ming ketdi', multi: [{ amount: 45000, accept: ['Salomatlik'] }, { amount: 20000, accept: ['Transport'] }] },
  { group: '9-kop-amal', text: "bola kiyimiga 150 ming o'zimga futbolka 80 ming oldim", multi: [{ amount: 150000, accept: ['Kiyim'] }, { amount: 80000, accept: ['Kiyim'] }] },
  { group: '9-kop-amal', text: 'kinoga 60 ming popkorn 35 ming', multi: [{ amount: 60000, accept: ["Ko'ngilochar"] }, { amount: 35000, accept: ['Oziq-ovqat', "Ko'ngilochar"] }] },
  { group: '9-kop-amal', text: 'internetga 89 ming telefonga 30 ming soldim', multi: [{ amount: 89000, accept: ['Kommunal'] }, { amount: 30000, accept: ['Kommunal'] }] },
  { group: '9-kop-amal', text: 'ertalab non 6 ming tushlik 42 ming', multi: [{ amount: 6000, accept: ['Oziq-ovqat'] }, { amount: 42000, accept: ['Oziq-ovqat'] }] },
  // ---- 10. Qarz (va qarz-himoya) ----
  { group: '10-qarz', text: 'Anvarga qarz berdim 500 ming', qarz: 'qarz_berdim', person: 'anvar', amounts: [500000] },
  { group: '10-qarz', text: 'akamdan 1 mln qarz oldim', qarz: 'qarz_oldim', amounts: [1000000] },
  { group: '10-qarz', text: 'Dilshod 200 mingni qaytardi', qarz: 'menga_qaytarildi', person: 'dilshod', amounts: [200000] },
  { group: '10-qarz', text: 'Sardor bergan qarzimni qaytarib berdi 350 ming', qarz: 'menga_qaytarildi', person: 'sardor', amounts: [350000] },
  { group: '10-qarz', text: 'Jasurdan olgan 400 ming qarzimni qaytardim', qarz: 'qaytardim', person: 'jasur', amounts: [400000] },
  { group: '10-qarz', text: "qo'shnimga 250 ming qarz berib turdim", qarz: 'qarz_berdim', amounts: [250000] },
  { group: '10-qarz', text: 'Karimga qarzga 300 ming berdim', qarz: 'qarz_berdim', person: 'karim', amounts: [300000] },
  // himoya: "qarz" so'zi YO'Q -> oddiy xarajat bo'lishi SHART (sanitize guard)
  { group: '10-qarz', text: 'Anvarga 200 ming berdim', accept: ['Boshqa'], acceptNew: ["sovg'a|sovga"], amounts: [200000], mustXarajat: true },
  { group: '10-qarz', text: 'singlimga 100 ming berdim', accept: ['Boshqa'], acceptNew: ["sovg'a|sovga|oila"], amounts: [100000], mustXarajat: true },
  // ---- 11. Daromad so'zli ----
  { group: '11-daromad-soz', text: 'oylikdan 50 ming ishlatdim', accept: ['Boshqa', 'Oziq-ovqat'], amounts: [50000], mustXarajat: true },
  { group: '11-daromad-soz', text: 'oylik oldim 4 mln', accept: ['Daromad', 'Boshqa'], amounts: [4000000], incomeOk: true },
  { group: '11-daromad-soz', text: 'mijozdan 300 ming keldi', accept: ['Daromad', 'Boshqa'], amounts: [300000], incomeOk: true },
  { group: '11-daromad-soz', text: 'avans oldim 1.5 mln', accept: ['Daromad', 'Boshqa'], amounts: [1500000], incomeOk: true },
  { group: '11-daromad-soz', text: 'sotuvdan 800 ming tushdi', accept: ['Daromad', 'Boshqa'], amounts: [800000], incomeOk: true },
  { group: '11-daromad-soz', text: 'bonusdan 200 mingini bolalarga sarfladim', accept: ['Boshqa', 'Oziq-ovqat', 'Kiyim', "Ko'ngilochar"], amounts: [200000], mustXarajat: true },
  // ---- 12. Yangi papka taklifi ----
  { group: '12-yangi-papka', text: "kursga 500 ming to'ladim", accept: ['Boshqa'], acceptNew: ["ta'lim|talim|kurs|o'quv"], amounts: [500000] },
  { group: '12-yangi-papka', text: 'mashinamni remontiga 800 ming ketdi', accept: ['Boshqa', 'Transport'], acceptNew: ["remont|ta'mir|tamir|avto|usta"], amounts: [800000] },
  { group: '12-yangi-papka', text: "singlimga sovg'a oldim 150 ming", accept: ['Boshqa'], acceptNew: ["sovg'a|sovga|tuhfa"], amounts: [150000] },
  { group: '12-yangi-papka', text: 'it ovqati 45 ming', accept: ['Boshqa', 'Oziq-ovqat'], acceptNew: ["hayvon|uy hayvon|pet|it "], amounts: [45000] },
  { group: '12-yangi-papka', text: 'ukol qildirdim 25 ming', accept: ['Salomatlik'], amounts: [25000] },
  { group: '12-yangi-papka', text: 'parikmaxerga 50 ming', accept: ['Boshqa'], acceptNew: ["go'zallik|gozallik|soch|salon|sartarosh"], amounts: [50000] },
  { group: '12-yangi-papka', text: 'sport zalga obuna 300 ming', accept: ['Salomatlik'], acceptNew: ['sport'], amounts: [300000] },
  { group: '12-yangi-papka', text: 'telegram premium 60 ming', accept: ["Ko'ngilochar", 'Kommunal', 'Boshqa'], acceptNew: ['obuna|premium|internet'], amounts: [60000] },
  { group: '12-yangi-papka', text: "bog'chaga oylik to'lov 450 ming", accept: ['Boshqa'], acceptNew: ["bog'cha|bogcha|ta'lim|talim"], amounts: [450000], mustXarajat: true },
  // ---- 13. Summa formatlari ----
  { group: '13-format', text: "120 000 so'm ishlatdim bozorda", accept: ['Oziq-ovqat'], amounts: [120000] },
  { group: '13-format', text: '25,000 taksi', accept: ['Transport'], amounts: [25000] },
  { group: '13-format', text: '1.5 mln kiyimga', accept: ['Kiyim'], amounts: [1500000] },
  { group: '13-format', text: '200k obed qildik', accept: ['Oziq-ovqat'], amounts: [200000] },
  { group: '13-format', text: '4m mashina remontiga berdim', accept: ['Boshqa', 'Transport'], acceptNew: ["remont|ta'mir|tamir|avto"], amounts: [4000000] },
  { group: '13-format', text: '5000 kofe', accept: ['Oziq-ovqat'], amounts: [5000] },
  { group: '13-format', text: 'чой 10 минг', accept: ['Oziq-ovqat'], amounts: [10000] },
  { group: '13-format', text: '1,200,000 telefon oldim', accept: ['Boshqa', 'Kommunal'], acceptNew: ['texnika|telefon|elektron|gadjet'], amounts: [1200000] },
  { group: '13-format', text: 'obedga 35.5 ming ketdi', accept: ['Oziq-ovqat'], amounts: [35500] },
  // ---- 14. Valyuta / burilish ----
  { group: '14-valyuta', text: '10 dollar obed', accept: ['Oziq-ovqat'], usd: 10 },
  { group: '14-valyuta', text: '100$ ga kurtka oldim', accept: ['Kiyim'], usd: 100 },
  { group: '14-valyuta', text: '20 baks taksi', accept: ['Transport'], usd: 20 },
  { group: '14-valyuta', text: "yarim million to'y uchun", accept: ['Boshqa', "Ko'ngilochar"], acceptNew: ["to'y|toy|sovg'a|sovga|marosim"], amounts: [500000] },
  { group: '14-valyuta', text: 'ikki yuz ming benzinga ketdi', accept: ['Transport'], amounts: [200000] },
  { group: '14-valyuta', text: "besh ming so'mga non oldim", accept: ['Oziq-ovqat'], amounts: [5000] },
  { group: '14-valyuta', text: 'bir yarim million divan oldim', accept: ['Boshqa'], acceptNew: ["mebel|uy|ro'zg'or|jihoz"], amounts: [1500000] },
];

// ---------- scoring ----------
const themeMatch = (patterns, value) => {
  if (!patterns || !value) return false;
  return patterns.some((p) => new RegExp(p, 'i').test(String(value)));
};
const catOk = (c, action) => {
  const cat = action.category;
  if (c.accept?.some((a) => ci(a) === ci(cat))) return true;
  if (themeMatch(c.acceptNew, cat)) return true; // user already owns such a folder
  if (action.new_category_suggestion && themeMatch(c.acceptNew, action.new_category_suggestion)
      && ci(cat) === 'boshqa') return true;
  return false;
};
const sameMultiset = (a, b) => {
  if (a.length !== b.length) return false;
  const s = [...a].sort((x, y) => x - y), t = [...b].sort((x, y) => x - y);
  return s.every((v, i) => v === t[i]);
};

function score(c, res) {
  const actions = res.actions || [];
  const fails = [];
  const got = actions.map((a) => ({
    direction: a.direction, amount: a.amount, category: a.category,
    suggestion: a.new_category_suggestion, person: a.person, confidence: a.confidence,
  }));
  if (!actions.length) return { pass: false, fails: ['actions bo\'sh'], got };

  if (c.multi) {
    const wantAmounts = c.multi.map((m) => m.amount);
    if (!sameMultiset(actions.map((a) => a.amount), wantAmounts)) {
      fails.push(`amounts: kutildi ${JSON.stringify(wantAmounts)}, olindi ${JSON.stringify(actions.map((a) => a.amount))}`);
    } else {
      const used = new Set();
      for (const m of c.multi) {
        const idx = actions.findIndex((a, i) => !used.has(i) && a.amount === m.amount
          && (m.accept.some((x) => ci(x) === ci(a.category))));
        if (idx === -1) fails.push(`${m.amount} uchun toifa: kutildi ${m.accept.join('/')}, olindi ${JSON.stringify(actions.filter((a) => a.amount === m.amount).map((a) => a.category))}`);
        else used.add(idx);
      }
    }
    for (const a of actions) if (a.direction !== 'xarajat') fails.push(`direction: ${a.direction} (xarajat kutildi)`);
    return { pass: !fails.length, fails, got };
  }

  if (c.qarz) {
    if (actions.length !== 1) fails.push(`${actions.length} ta action (1 kutildi)`);
    const a = actions[0];
    if (a.direction !== c.qarz) fails.push(`direction: kutildi ${c.qarz}, olindi ${a.direction}`);
    if (!sameMultiset(actions.map((x) => x.amount), c.amounts)) fails.push(`amount: kutildi ${JSON.stringify(c.amounts)}, olindi ${JSON.stringify(actions.map((x) => x.amount))}`);
    if (c.person && !ci(a.person).includes(c.person)) fails.push(`person: kutildi "${c.person}", olindi "${a.person}"`);
    return { pass: !fails.length, fails, got };
  }

  // single-action expense/income
  if (actions.length !== 1) fails.push(`${actions.length} ta action (1 kutildi)`);
  const a = actions[0];

  if (c.usd) {
    const okRaw = a.amount === c.usd;
    const okConv = a.amount >= c.usd * 10000 && a.amount <= c.usd * 16000;
    if (!okRaw && !okConv) fails.push(`amount: kutildi ${c.usd} yoki ${c.usd}$ kursda, olindi ${a.amount}`);
  } else if (c.amountsAnyOf) {
    if (!c.amountsAnyOf.some((set) => sameMultiset(actions.map((x) => x.amount), set))) {
      fails.push(`amount: kutildi ${JSON.stringify(c.amountsAnyOf)}, olindi ${JSON.stringify(actions.map((x) => x.amount))}`);
    }
  } else if (!sameMultiset(actions.map((x) => x.amount), c.amounts)) {
    fails.push(`amount: kutildi ${JSON.stringify(c.amounts)}, olindi ${JSON.stringify(actions.map((x) => x.amount))}`);
  }

  if (isQarz(a.direction)) fails.push(`direction: ${a.direction} (qarz EMAS kutildi)`);
  let noteworthy = null;
  if (c.mustXarajat && a.direction !== 'xarajat') fails.push(`direction: ${a.direction} (xarajat SHART edi)`);
  if (!c.mustXarajat && a.direction === 'daromad') {
    if (c.incomeOk) noteworthy = 'daromad chiqdi (mobil xarajatga aylantiradi)';
    else fails.push(`direction: daromad (xarajat kutildi)`);
  }
  if (a.direction === 'xarajat' && !catOk(c, a)) {
    fails.push(`category: kutildi ${c.accept?.join('/')}${c.acceptNew ? ` yoki taklif~/${c.acceptNew.join('|')}/` : ''}, olindi "${a.category}" (taklif: ${a.new_category_suggestion ?? '—'})`);
  }
  if (a.direction === 'daromad' && c.incomeOk === undefined && !c.mustXarajat) { /* handled above */ }
  return { pass: !fails.length, fails, got, noteworthy };
}

// ---------- runner ----------
const results = [];
const save = () => writeFileSync(RESULTS_PATH, JSON.stringify({
  meta: {
    date: new Date().toISOString(),
    user: String(USER_ID).slice(0, 8) + '…',
    userCategories: USER_CATS,
    groqModel: config.llm.groqModel,
    openaiFallback: !!config.llm.openaiKey,
  },
  spanResults, results,
}, null, 2));

let i = 0;
for (const c of CASES) {
  i++;
  let res = null; let attempts = 0;
  for (const backoff of [0, 2500, 6000]) {
    if (backoff) await sleep(backoff);
    attempts++;
    try {
      res = await parseText(c.text, USER_ID);
    } catch (e) {
      res = { actions: [], provider: 'error', errors: [e.message] };
    }
    if (res.provider === 'groq' || res.provider === 'openai') break;
  }
  const s = score(c, res);
  results.push({
    n: i, group: c.group, text: c.text,
    provider: res.provider, attempts, errors: res.errors || [],
    needs_confirm: res.needs_confirm,
    pass: s.pass, fails: s.fails, noteworthy: s.noteworthy || null,
    got: s.got,
  });
  console.log(`${String(i).padStart(3)}/${CASES.length} ${s.pass ? 'PASS' : 'FAIL'} [${res.provider}${attempts > 1 ? ' x' + attempts : ''}] ${c.text}${s.pass ? '' : '  => ' + s.fails.join(' | ')}`);
  save();
  await sleep(1100);
}

// ---------- summary ----------
const total = results.length;
const passed = results.filter((r) => r.pass).length;
const nonLlm = results.filter((r) => r.provider !== 'groq' && r.provider !== 'openai').length;
console.log('\n==== YAKUN ====');
console.log(`Umumiy: ${passed}/${total} (${(passed / total * 100).toFixed(1)}%)`);
console.log(`amountSpans: ${spanResults.filter((r) => r.pass).length}/${spanResults.length}`);
console.log(`Non-LLM provider (rules/error): ${nonLlm} (${(nonLlm / total * 100).toFixed(1)}%)${nonLlm / total > 0.2 ? '  <<< 20% DAN KO\'P — LLM YIQILGAN, NATIJA ISHONCHSIZ' : ''}`);
const groups = [...new Set(results.map((r) => r.group))];
for (const g of groups) {
  const gr = results.filter((r) => r.group === g);
  console.log(`  ${g}: ${gr.filter((r) => r.pass).length}/${gr.length}`);
}
save();
console.log('Natijalar:', RESULTS_PATH);

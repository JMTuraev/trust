// Trust AI — BILIM KUTUBXONASI (persona "UMUMIY BILIM" bo'limining manbasi).
//
// Muammo (PO, 2026-07-17): model har suhbatda bir xil 2–3 metodga yopishib olardi
// (50/30/20, latte-faktor) — javoblar bashorat qilinadigan bo'lib qolgan edi.
// Yechim: katta kutubxona (40+ karta) + KUNLIK DETERMINISTIK ROTATSIYA. Har kuni
// har foydalanuvchiga 3 ta "bilim kartasi" tanlanadi va kontekst blokining oxiriga
// qo'shiladi (services/ai-persona.js contextBlock -> routes/ai.js).
//
// KESH SHARTNOMASI (muhim, buzilmasin):
//   pickKnowledge() natijasi BIR KUN ichida BIR USER uchun BAYT-BARQAROR bo'lishi
//   SHART — kontekst bloki 2-kesh nuqtasi (lib/anthropic.js), Anthropic prompt-cache
//   faqat bayt bir xil bo'lsa uriladi. Kun almashganda to'plam bir marta o'zgaradi —
//   bu kuniga bitta kesh yozuvi, maqbul narx. SHU SABAB Date.now() YO'Q: sana faqat
//   `date` parametrdan olinadi. Sof funksiya — DB ham, tarmoq ham yo'q.
//
// KARTA MATNI QOIDALARI:
//   - TASHQI ANIQ RAQAM YO'Q (valyuta kursi, foiz stavkasi, statistika) — eskiradi.
//     Metodning O'Z raqamlari (50/30/20, 52-hafta, 3–6 oy) — nomning bir qismi, mumkin.
//   - Har karta foydalanuvchining REAL raqamiga bog'lab aytsa bo'ladigan o'git —
//     persona quruq nazariyani taqiqlaydi.
//   - 1–2 gap, o'zbekcha. tag: method (usul) | fact (xulq-iqtisodiyot fakti) |
//     habit (odat) | uz (o'zbek konteksti).

// ai-context.js bilan sinxron: O'zbekiston UTC+5, DST yo'q — "kun" mahalliy hisoblanadi.
const TZ_OFFSET_MS = 5 * 3600_000;
const DAY_MS = 24 * 3600_000;

export const KNOWLEDGE = [
  // ---------- Jamg'arma usullari ----------
  { id: 'm-52week', tag: 'method', text: "52-hafta challenge: birinchi hafta eng kichik summadan boshlanadi, har hafta bir pog'ona oshirib boriladi — yil oxirida sezdirmas qadamlar salmoqli jamg'armaga aylanadi." },
  { id: 'm-pay-first', tag: 'method', text: "\"Avval o'zingga to'la\": daromad kelgan KUNI avval jamg'armaga ulush ajratiladi, qolgani sarflanadi — \"oy oxirida qolsa qo'yaman\" deganda odatda hech narsa qolmaydi." },
  { id: 'm-auto', tag: 'method', text: "Avto-o'tkazma — irodaga ishonmaslik san'ati: jamg'arma avtomatik ketsa, har oy \"qo'yish-qo'ymaslik\" qarori umuman tug'ilmaydi va odat o'z-o'zidan qoladi." },
  { id: 'm-envelope', tag: 'method', text: "Konvert usuli (cash stuffing): har xarajat toifasiga oy boshida o'z \"konverti\" ajratiladi; konvert bo'shadimi — o'sha toifa shu oyga yopiladi." },
  { id: 'm-kakeibo', tag: 'method', text: "Kakeibo — yaponlarning byudjet daftari: oy boshida to'rt savol (qancha pulim bor, qancha saqlamoqchiman, qancha sarflayman, nimani yaxshilayman) va har xaridni qo'lda yozish odati." },
  { id: 'm-24h', tag: 'method', text: "24 soat qoidasi: rejada bo'lmagan katta xarid darhol olinmaydi, bir kun kutiladi — ko'p istaklar ertasiga o'z-o'zidan so'nadi." },
  { id: 'm-10s', tag: 'method', text: "10 soniya qoidasi: mayda xaridda to'lashdan oldin 10 soniya to'xtab \"bu menga chindan kerakmi?\" deb so'rash impulsning kuchini sindiradi." },
  { id: 'm-no-spend', tag: 'method', text: "\"Xarajatsiz kun\" challenge: haftada bitta kun ataylab hech narsa sotib olinmaydi — tejash mushak kabi mashq bilan kuchayadi." },
  { id: 'm-roundup', tag: 'method', text: "Yaxlitlash usuli: har xariddan keyin summa yuqoriga yaxlitlanib, farqi jamg'armaga o'tkaziladi — sezilmaydigan, lekin to'xtovsiz oqim." },
  { id: 'm-30day-list', tag: 'method', text: "30 kun ro'yxati: xohlagan narsa darhol olinmaydi, ro'yxatga yoziladi — 30 kundan keyin ham kerak bo'lib tursa, bu chindan kerak narsa." },
  // ---------- Qarz strategiyalari ----------
  { id: 'm-snowball', tag: 'method', text: "Qarzda \"qor koptok\" usuli: eng KICHIK qarzdan boshlab yopiladi — tez keladigan g'alabalar davom etishga kuch beradi." },
  { id: 'm-avalanche', tag: 'method', text: "Qarzda \"ko'chki\" usuli: eng og'ir (eng katta yoki eng qimmatga tushayotgan) qarzdan boshlanadi — hisob-kitob jihatdan eng tejamkor yo'l." },
  { id: 'm-debt-list', tag: 'method', text: "Qarzlarni bitta ro'yxatga tushirishning o'zi yengillik beradi: kim, qancha, qachongacha — hammasi ko'z oldida bo'lsa, noaniq qo'rquv aniq rejaga aylanadi." },
  // ---------- Byudjet ramkalari ----------
  { id: 'm-503020', tag: 'method', text: "50/30/20 qoidasi: daromadning yarmi zaruratga, 30 foizi xohishlarga, 20 foizi jamg'arma va qarz to'lashga — sodda, lekin kuchli boshlang'ich ramka." },
  { id: 'm-zero-based', tag: 'method', text: "Zero-based budget: oy boshida har bir so'mga \"vazifa\" beriladi — daromaddan rejalar ayirilganda nol qolishi kerak; \"egasiz\" pul o'z-o'zidan sarflanib ketadi." },
  { id: 'm-1pct', tag: 'method', text: "Katta xaridda 1% qoidasi: narxi oylik daromadning taxminan yuzdan biridan oshgan xaridni kamida bir kun o'ylab ko'rish arziydi." },
  { id: 'm-cushion', tag: 'method', text: "Xavfsizlik yostig'i: 3–6 oylik xarajatga teng zaxira — ish, salomatlik yoki kutilmagan zarbada qarzga yugurmaslik imkonini beradi." },
  // ---------- Xulq-iqtisodiyot faktlari ----------
  { id: 'f-latte', tag: 'fact', text: "Latte-faktor: kunlik mayda odat xarajati alohida arzimas ko'rinadi, lekin 365 kunga ko'paytirilganda yillik salmoqli summa chiqadi — kichik oqimlar ham daryo bo'ladi." },
  { id: 'f-lifestyle', tag: 'fact', text: "Turmush shishishi (lifestyle inflation): daromad oshgani sari xarajat ham bilinmay o'sib boradi — oxirida ko'proq topib ham xuddi avvalgidek \"pul yetmaydi\" bo'lib qolinadi." },
  { id: 'f-cash-pain', tag: 'fact', text: "Naqd pulda \"to'lov og'rig'i\" kuchliroq: qog'oz pulni sanab berish miyaga xarajatni his qildiradi, karta esa bu og'riqni yumshatib, sarfni osonlashtiradi." },
  { id: 'f-mental-acc', tag: 'fact', text: "Mental accounting: odam pulni xayolida \"cho'ntaklarga\" bo'ladi — sovg'a puli oson sovriladi, mehnat puli qattiqroq turadi; vaholanki hammasi bitta pul." },
  { id: 'f-anchor', tag: 'fact', text: "Lang'ar narx effekti: do'kondagi \"avval qimmat edi, endi arzon\" yorlig'i miyani chegirma katta deb ishontiradi — to'g'ri savol \"qancha tushdi\" emas, \"menga o'zi kerakmi\"." },
  { id: 'f-impulse', tag: 'fact', text: "Impulsiv xaridning ildizi ko'pincha hissiyot: charchoq, stress yoki och qoringa qilingan xarid ertasiga pushaymonga aylanadi." },
  { id: 'f-diderot', tag: 'fact', text: "Diderot effekti: bitta yangi buyum o'ziga \"mos\" boshqa xaridlarni ergashtirib keladi — yangi telefon yangi g'ilof, quloqchin va obunalar degani." },
  { id: 'f-small-leaks', tag: 'fact', text: "Katta bir martalik xarajatdan ko'ra mayda takroriy xarajatlar xavfliroq — ular ko'zga ko'rinmaydi, lekin oy davomida jimgina yig'ilib boradi." },
  { id: 'f-measure', tag: 'fact', text: "Kuzatuv effekti: xarajatni shunchaki yozib borishning o'zi uni kamaytiradi — o'lchanayotgan narsa o'zgaradi." },
  { id: 'f-free-trap', tag: 'fact', text: "\"Bepul\" tuzog'i: bepul yetkazib berish yoki \"ikkinchisi tekin\" uchun rejadan ortiq xarid qilish — tejash niqobidagi qo'shimcha xarajat." },
  { id: 'f-sunk-cost', tag: 'fact', text: "Cho'kkan xarajat tuzog'i: \"shuncha pul to'lab qo'ydim-ku\" deb foydasiz narsani davom ettirish — ketgan pul qaytmaydi, qaror faqat bugungi foydaga qarab qilinadi." },
  { id: 'f-present-bias', tag: 'fact', text: "Hozir-yaxshi og'ishi (present bias): bugungi kichik rohat ertangi katta foydadan kuchliroq tortadi — shuning uchun jamg'arma irodaga emas, avtomatikaga qurilishi kerak." },
  { id: 'f-eye-level', tag: 'fact', text: "Do'kon tokchalari bejiz terilmagan: ko'z balandligida odatda do'konga eng foydali mahsulot turadi — pastki va yuqori tokchalarga ham qarash odati tejaydi." },
  { id: 'f-german-cash', tag: 'fact', text: "Nemislarda naqd pulga mehr kuchli — bu texnologiyadan qochish emas, xarajatni qo'lda his qilib nazoratda ushlash madaniyati sifatida qadrlanadi." },
  // ---------- Odatlar ----------
  { id: 'h-evening-log', tag: 'habit', text: "Kechki 2 daqiqa odati: har oqshom kunning xarajatlarini yozib qo'yish — kichik marosim, lekin oy oxirida to'liq manzara beradi." },
  { id: 'h-month-retro', tag: 'habit', text: "Oy oxiri retro: oyning eng katta 3 xarajatini ochib, har biriga \"bunga arzidimi?\" deb so'rash — keyingi oy rejasini shu javoblar yozadi." },
  { id: 'h-goal-name', tag: 'habit', text: "Maqsadga ism qo'yish ishlaydi: shunchaki \"jamg'arma\" emas, \"to'yga\", \"uy uchun\", \"qishki zaxira\" — nomlangan pulga qo'l tegizish qiyinroq." },
  { id: 'h-shop-list', tag: 'habit', text: "Do'konga ro'yxat bilan kirish odati: ro'yxatsiz xarid — do'kon rejasiga o'ynash; ro'yxat esa o'z rejangda qolish demak." },
  { id: 'h-milestones', tag: 'habit', text: "Katta maqsadni bosqichlarga bo'lish: avval birinchi kichik cho'qqi, keyin kattarog'i — har bosqich nishonlansa, uzoq yo'l charchatmaydi." },
  { id: 'h-streak', tag: 'habit', text: "Zanjir psixologiyasi: ketma-ket kunlar streak'ini uzmaslik istagi kuchli motivator — bir kun o'tkazib yuborilsa ham, muhimi ikkinchi kunni o'tkazmaslik." },
  { id: 'h-out-of-sight', tag: 'habit', text: "Jamg'armani ko'zdan uzoq saqlash: alohida hisob yoki kartada turgan pul \"yo'q pul\" kabi seziladi — qo'l yetmagan pul sarflanmaydi." },
  { id: 'h-partner', tag: 'habit', text: "Sherik effekti: maqsadni yaqin odamga aytish yoki birga yig'ish javobgarlik hissini oshiradi — yolg'iz iroda o'rniga ijtimoiy va'da ishlaydi." },
  // ---------- O'zbek konteksti ----------
  { id: 'u-gap', tag: 'uz', text: "\"Gap\" — o'zbekcha jamoaviy jamg'arma an'anasi: davra a'zolari har oy yig'ib, navbat bilan bir kishiga beradi. Kuchi — intizom va ijtimoiy va'da; xavfi — davra ishonchsiz bo'lsa, navbati kelmaganlar yutqazadi." },
  { id: 'u-toy-season', tag: 'uz', text: "To'y mavsumi kalendarda oldindan ko'rinib turadi — mavsumdan bir necha oy oldin alohida \"to'y konverti\" ochib borish oxirgi haftada qarz izlashdan qutqaradi." },
  { id: 'u-family-budget', tag: 'uz', text: "Oilaviy byudjetni birga yuritish odati: oyda bir marta oilaviy \"moliya gapi\" — kim nimaga sarflaganini xotirjam gaplashish pul mavzusidagi kelishmovchiliklarni kamaytiradi." },
  { id: 'u-daftar', tag: 'uz', text: "Oldi-berdini daftarga yozish — o'zbek savdo madaniyatining qadimiy odati: yozilgan qarz unutilmaydi, unutilmagan qarz esa oradagi hurmatni saqlaydi." },
  { id: 'u-bayram', tag: 'uz', text: "Bayram va Ramazon xarajatlari kutilmagan hodisa emas — sanasi bir yil oldin ma'lum. Oldindan oz-ozdan yig'ilgan \"bayram fondi\" bayram quvonchini qarz tashvishisiz qoldiradi." },
  { id: 'u-family-loan', tag: 'uz', text: "Oiladan yoki yaqindan qarz olish bizda tabiiy odat — lekin aynan yaqin odam bilan yozib qo'yilgan qarz munosabatni asraydi: og'zaki qarz unutiladi, yozilgani ishonchni saqlaydi." },
];

/** FNV-1a 32-bit — barqaror, tez, bog'liqliksiz (crypto shart emas: bu xavfsizlik emas, taqsimlash). */
function hashStr(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/**
 * Kunlik deterministik tanlov: `date` kuni (Toshkent bo'yicha) `userId` uchun n ta karta.
 *
 * Rotatsiya mexanikasi:
 *   start = (kunIndeksi + hash(userId)) mod LEN, keyin QADAMLI n ta element:
 *   indekslar start + i*floor(LEN/n) — kutubxona toifa bo'yicha tartiblangani uchun
 *   ketma-ket olish 3 ta bir xil tag berardi; qadam toifalarni aralashtiradi
 *   (masalan method + fact + uz).
 *   - BIR KUN + BIR USER -> bir xil massiv (bayt-barqaror => prompt-cache omon qoladi);
 *   - kun almashsa start 1 ga siljiydi -> har kuni yangi to'plam, LEN kun ichida
 *     start BARCHA indekslarni bosib o'tadi => butun kutubxona kafolatli qamraladi
 *     (1 qadam har qanday LEN bilan o'zaro tub — n qadamda LEN 3 ga karrali bo'lsa
 *     kutubxonaning bir qismi hech chiqmay qolardi);
 *   - turli user -> hash tufayli turli boshlanish nuqtasi (bir kunda har xil to'plam).
 *
 * @param {string} userId  foydalanuvchi UUID'si
 * @param {Date|string|number} date  so'rov vaqti (Date.now EMAS — kesh shartnomasi)
 * @param {number} n  nechta karta (default 3)
 * @returns {{id:string, tag:string, text:string}[]}
 */
export function pickKnowledge(userId, date, n = 3) {
  const len = KNOWLEDGE.length;
  if (!len) return []; // bo'sh kutubxona — % 0 NaN'dan himoya (kelajakdagi refaktorlar uchun)
  const count = Math.max(1, Math.min(Math.floor(n) || 1, len));
  const dayIndex = Math.floor((new Date(date).getTime() + TZ_OFFSET_MS) / DAY_MS);
  if (!Number.isFinite(dayIndex)) return KNOWLEDGE.slice(0, count); // yaroqsiz sana — baribir barqaror javob
  const start = ((dayIndex + hashStr(String(userId || ''))) % len + len) % len;
  const stride = Math.max(1, Math.floor(len / count)); // toifalar aralashsin (ketma-ket emas)
  const out = [];
  for (let i = 0; i < count; i++) out.push(KNOWLEDGE[(start + i * stride) % len]);
  return out;
}

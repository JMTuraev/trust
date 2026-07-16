# INTEGRATSIYA hisoboti — shared-file patchlar + enforcement wiring (2026-07-16)

Agent: INTEGRATOR/REVIEWER. Vazifa: 4 ta hudud hisobotidagi (partners / expenses / circles / profile)
umumiy (shared) fayllar uchun taklif qilingan patchlarni AYNAN qo'llash, `expenses.js`/`categories.js`da
obuna enforcement wiring, 011→012 migratsiya havolalarini tuzatish va hududlararo ziddiyat tekshiruvi.

Tegilgan fayllar (faqat menga ruxsat etilganlar): `mobile/lib/store.dart`, `mobile/lib/l10n.dart`,
`mobile/lib/api.dart`, `src/services/parse.js`, `src/routes/expenses.js`, `src/routes/categories.js`,
`docs/team-reports/2026-07-16-profile.md` (faqat 011→012 satri), shu hisobot.
`main.dart`, `ui.dart`, `theme.dart`, `src/index.js`, `src/config.js` — o'zgartirish talab qilinmadi.

---

## 1. PATCH JADVALI

### 1.1 PARTNERS §3 (store.dart)

| Patch | Mazmun | Holat |
|---|---|---|
| S1a | `openIncoming` → `openLedger_(linkId)` chaqiruvi | **APPLIED** (~737-qator) |
| S1b-1 | `openLedger_` — hamkor almashganda `ledgerPid` guard + qatorlarni tozalash | **APPLIED** (~1013) |
| S1b-2 | ledger poll: `S['inLinkId'] == partnerId` ham qamraldi | **APPLIED** (~1028) |
| S1c | `_ledPid()` helper + 8 ta ledger amali, `ledgerReviewAll_`, `chOpen_`(close), `chSubmit_`, `histEditStart_`, `histEditSave_` — barchasi `_ledPid()` orqali | **APPLIED** (qoldiq `S['clientId'] as String` faqat ro'yxatda YO'Q joylarda: `renSave_`, `chatMicEnd`, `toOps`) |
| S2 | `npCreate` → yangi hamkordan keyin `openLedger_` | **APPLIED** (~3212) |
| S3-1 | `_notifKind`: debt_new/debt_confirm/debt_reject/repay_new/settle_new/edit_req/review_req → 'debt', msg → 'msg' | **APPLIED** |
| S3-2 | `openFromNotif`: debt/msg → hamkor daftariga marshrut (linkacc/linkrej blokidan keyin) | **APPLIED** (~2089) |
| S3-3 | `notifRows`: `isReq: linknew\|\|msg`, `isEdit: k=='debt'` | **APPLIED** |
| S4-1 | `_mapPartner`: `srvBal` (server `balances` — operations+debts) | **APPLIED** |
| S4-2 | `bal()`: server balansi ustuvor, lokal fallback | **APPLIED** (moliya eslatmalari ham avtomatik tuzaladi) |
| S5-1 | `_routeQarz` → NewTxSheet o'rniga ledger input panelini to'ldirish | **APPLIED** |
| S5-2 | `npCreate` qarzDraft → ledger input paneli | **APPLIED** |
| S6-1 | `money()` → EUR/RUB switch | **APPLIED** |
| S6-2 | `chCurs` default 4 valyuta | **APPLIED** |
| S7 | `inRows` — `'unread'` badge kaliti (data-qatlam) | **APPLIED** — qarang §3.1 (chat-hide bilan zid EMAS) |

### 1.2 EXPENSES §4

| Patch | Fayl | Holat |
|---|---|---|
| 4.1 | l10n.dart — 21 papka-tahriri kaliti + har til (uz/ru/en aynan hisobotdan; **es/fr/zh — inglizchadan tarjima qilindi**, hisobot ruxsatiga ko'ra) | **APPLIED** — kalit-parity tekshirildi: 22 kalit × 6 til (grep bilan) |
| 4.2 | store.dart `_xarVals` tafsilot qatoriga `'id','a'` | **APPLIED** (xarajat.dart `r['id']` bevosita ishlatadi — moslik tekshirildi) |
| 4.3 | store.dart `_xfMergeAsk` kirim↔chiqim guard | **APPLIED** (toast matni hisobotdagidek hardcoded o'zbekcha — l10n'lashtirish keyingi iteratsiya) |
| 4.4 | api.dart `categoriesAll()` | **APPLIED** (xarajat.dart hozircha o'z fallback'i bilan — o'tkazish ixtiyoriy, owner qaroriga) |
| 4.5 | parse.js INC/EXP lug'at sinxroni (kiril + en + qaytardi\b) | **APPLIED** |
| 4.6 | XOTIRA-ovoz-va-kategoriya.md §7 STT_ENABLED jumlasi | **QO'LLANMADI** — fayl mening ruxsat ro'yxatimda yo'q; lead yoki hujjat egasi yangilasin |

### 1.3 CIRCLES §5 (store.dart 3 patch)

| Patch | Mazmun | Holat |
|---|---|---|
| 5.1 | `loadCircles` fon yangilash → `.then((_) => set({}))` rebuild | **APPLIED** |
| 5.2 | `_mapNotif` `'circle': n['circle_id']` + `_notifKind` circle_* turlari + `openFromNotif` circle marshruti (invited → Join, aks holda detal) | **APPLIED** — `notifications.js` `select('*')` qilgani tekshirildi (circle_id payload'da bor); `circlesRepo.byId`/`myStatus` mavjudligi tekshirildi |
| 5.3 | circle toastlari → `cf('toast*')` (import `circles_l10n.dart`) | **APPLIED** — `cf`/kalitlar circles_l10n.dart'da borligi tekshirildi. Ishlatilmaydigan stublar (`circleCreate`, `circleRemindUnpaid`, `circleCopyLink`) hisobot ruxsati bilan olib tashlandi — butun mobile/lib bo'ylab iste'molchi yo'qligi grep bilan isbotlandi (circle_create.dart repo'ni bevosita chaqiradi) |
| 5.4 | api.dart circleRemind/JoinPreview/JoinByToken | **QO'LLANMADI (ixtiyoriy)** — hisobotda "ixtiyoriy konsolidatsiya"; qo'llansa circles egasi `circles_data.dart._circlesPost`ni almashtirishi kerak edi (u parallel ishlayapti). Keyingi iteratsiya |

### 1.4 PROFILE §7

| Patch | Mazmun | Holat |
|---|---|---|
| 7.1-a | S seed `premUntil` | **APPLIED** |
| 7.1-b | `_loginSuccess` — subStatus/trialEnd/premUntil/notifOn birinchi kirishda | **APPLIED** (bug fix) |
| 7.1-c | `_tryResume` — `premUntil` | **APPLIED** |
| 7.1-d | profRows — «Premium · dd.mm.yyyy» | **APPLIED** |
| 7.1-e | `logout_` — obuna/avatar tozalash + `trust_avatar` prefs remove | **APPLIED** |
| 7.1-f | hydrate'da obuna yangilash | **QO'LLANMADI (ixtiyoriy)** — hisobotda ixtiyoriy deb belgilangan |
| 7.2 | l10n `otpSentTo` ×6 til | **APPLIED** (onboarding.dart allaqachon iste'mol qiladi — fallback'dan real matnga o'tdi) |
| 7.3-b | expenses.js enforcement | **APPLIED** — §2 pastda |
| 7.3-a/c/d/e | partners/operations/debts/circles route'lari | **MEN QO'LLAMADIM** (boshqa egalarники) — tekshiruvda ma'lum bo'ldi: egalari O'ZLARI qo'llab bo'lishgan (§3.2) |
| 7.4/7.5 | README jadvali, .env.example/render.yaml | **QO'LLANMADI** — ro'yxatimda yo'q; lead yakuniy bosqichda (README'ga circles/debts/messages jadvali ham kerak — circles hisobot §7.3) |

**FAILED-PATCHES: YO'Q** — barcha old-snippetlar joriy kod bilan aynan mos keldi (drift kuzatilmadi).

---

## 2. ENFORCEMENT WIRING (mening zimmamdagi 2 fayl)

Mahsulot qarori: **expired user = READ-ONLY**. Import: `import { requireActiveSub } from '../lib/subscription.js';`
(export nomi subscription.js'dan o'qib tasdiqlandi; faylga tegilmadi).

`src/routes/expenses.js`:
- `POST /` — **qo'shildi** (yangi yozuv)
- `POST /parse` — **qo'shildi** (LLM sarfi, rateLimit'dan OLDIN)
- `POST /confirm` — **qo'shildi** (yozuvlarni saqlaydi)
- `PATCH /:id` — **qo'shildi** (tahrir = yozish; lead ko'rsatmasi bo'yicha)
- `POST /preview` — **ochiq qoldirildi**: hech narsa yozmaydi; expired user baribir saqlay olmaydi, input rangi esa ishlashda davom etadi. (LLM byudjeti xavotiri bo'lsa lead qo'shishi mumkin — 1 qator.)
- `DELETE /:id` — **ochiq qoldirildi**: ko'rsatmadagi ro'yxatda yo'q; o'chirish "yangi qiymat yaratish/tahrirlash" emas, foydalanuvchining o'z ma'lumotini tozalash huquqi (privacy). Lead qat'iy READ-ONLY istasa — 1 qator.
- `GET` hammasi ochiq.

`src/routes/categories.js`:
- `POST /` (yaratish) — **qo'shildi**
- `PATCH /:id` (qayta nomlash/arxivlash) — **qo'shildi**
- `GET /` (?all=1 bilan) ochiq.

`src/routes/stt.js` — **TEGILMADI** (boshqa egasi). `POST /api/stt/transcribe`da requireActiveSub YO'Q —
hozir mobil kSttEnabled=false (mic yopiq) va chat-audio messages.js orqali gated, shuning uchun amaliy teshik
minimal; STT qayta yoqilsa egasi gate qo'shsin.

---

## 3. REVIEW PASS — hududlararo topilmalar

### 3.1 Chat-hide ↔ S7/S3 (ziddiyat EMAS, hujjatlash)
- `inRows.'unread'` (S7) faqat data-qatlamda. Grep: hozirda **hech bir ekran** `unread` kalitini iste'mol
  qilmaydi (partners agenti badge ko'rsatishни ekran darajasida olib tashlagan). Chat UI qaytarilsa badge
  data tayyor turadi.
- S3 'msg' bildirishnomasi endi hamkor daftariga (`tab: 'chat'` = hozirgi sof-ledger ekran) olib boradi —
  foydalanuvchi xabar MATNini hali ko'rmaydi (chat yashirilgan), lekin "hech qayerga bormaydi" holati tuzaldi.
  Partners hisobot §5.1'dagi "badge o'chmaydi (openChat_ chaqirilmaydi)" muammosi kuchda — chat UI qarori bilan yechiladi.

### 3.2 Enforcement — egalar §7.3'dan TASHQARIGA chiqqan joylar (LEAD QARORI KERAK)
Boshqa agentlar o'z route'lariga requireActiveSub'ni parallel ravishda o'zlari qo'shган (import nomi bir xil — to'qnashuv yo'q). Profile hisobotidagi "ataylab ochiq qoladi" ro'yxatiga zid joylar:

| Fayl | Endpoint | Profile hisobot qarori | Amalda | Izoh |
|---|---|---|---|---|
| debts.js | `POST /:partnerId/repay`, `/settle` | **OCHIQ qolsin** ("pul qaytdi — daftar yangilanishi shart, bloklash ikkala tomonga zarar") | **GATED** | Eng muhim ziddiyat: expired qarzdor "qaytardim"ni yoza olmaydi → kreditor daftari yangilanmaydi |
| circles.js | `POST /:id/pay` | **OCHIQ qolsin** (ishtirok — boshqa a'zolar puliga bog'liq) | **GATED** | Expired a'zo to'lovini belgilay olmaydi → doira round'i boshqalar uchun ham qotib qolishi mumkin |
| circles.js | `POST /join/:token` | (yangi endpoint — hisobotda yo'q) | GATED | accept (telefon-taklif) ochiq, join-token gated — nomuvofiq semantika, lekin xavfsiz default |
| messages.js | `POST /:partnerId` (+audio) | ochiq qolsin (muloqot) | **GATED** | Chat UI yashirilgani uchun amaliy ta'sir hozircha 0 |
| partners.js | `/:id/move`, `/:id/remind` | faqat POST / ko'rsatilgan | GATED | READ-ONLY talqiniga mos (yozish amallari) — qabul qilsa bo'ladi |
| operations.js | `PATCH /:id` | faqat POST / ko'rsatilgan | GATED | Tahrir=yozish — mening expenses PATCH qarorim bilan uyg'un |

Ikkala talqin ham himoyalanadigan: (A) qat'iy READ-ONLY (hozirgi kod holati) vs (B) "qarshi tomon/ishtirok
amallari ochiq" (profile audit). **Lead bitta chiziq tanlasin** — ayniqsa repay/settle va circles pay uchun,
chunki bular ikkinchi (to'lagan!) foydalanuvchining daftariga ta'sir qiladi. Men cross-area kodga tegmadim.

### 3.3 KRITIK production risk (profile P2 endi keskinlashdi)
Enforcement endi BARCHA yozish endpointlarida faol, lekin **to'lov yo'li hali yo'q** (verify = 501 stub).
Deploy qilinsa 7 kundan eski har bir user yozishdan butunlay qulflanadi va pul to'lash imkoni yo'q.
Profile hisobot tavsiyasi kuchda: yo Play Billing bilan BIRGA deploy, yo `SUB_GRACE_DAYS` (masalan 30)
bilan yumshatib deploy. Bu bitta env o'zgaruvchisi — kod o'zgarishi kerak emas.

### 3.4 Boshqa kuzatuvlar
- `notifications.js` `select('*')` — `circle_id` mobilga yetadi (5.2 patch to'liq ishlaydi). Debt/msg
  notiflarda `link_id` = partner id ekani partners backend'iga bog'liq (ularning hududi, hisobotiga ishondim).
- S5'dan keyin NewTxSheet/`createTx` qarz-marshrutdan uzildi, lekin `openSheetClient` orqali hali ochiladi —
  olib tashlash partners hisobotida ham "alohida qaror" deyilgan. Backlog.
- `_mapLink.total` faqat UZS (partners §5.6 cross-finding) — S6 valyutalari bilan birga keyingi iteratsiya.
- Migratsiya tartibi deploy'da: **011_circles_hardening → 012_subscription_events → backend** (ikkala hudud
  hisobotidagi "migratsiya avval" talabi birlashtirildi).
- profile.md'dagi P5 xavfi HAL: lead 012 deb qayta nomlagan; profil agenti hisobotdagi qolgan "011" kontekst
  havolalarini ham o'zi 012'ga yangilab bo'ldi (parallel). `e2e/profile.browser.js`da 011 havolasi yo'q edi.

---

## 4. TEKSHIRUV NATIJALARI

Backend (`node --check`, Node 22):
- `src/routes/expenses.js` — **PASS**
- `src/routes/categories.js` — **PASS**
- `src/services/parse.js` — o'zgargan 4 regex-qator alohida faylda **PASS** (+ runtime kompilatsiya OK);
  faylning qolgan qismi o'zgartirilмади (avvalgi PASS holati saqlanadi)
- `src/lib/subscription.js` — tegilmadi (faqat export nomi o'qildi)

DIQQAT (sandbox cheklovi): bash mount D:\ faylларни KESILGAN (truncated) holda ko'rsatdi — shuning uchun
tekshiruv boshqa agentlar amaliyotidagidek aynan-nusxalarda bajarildi: `outputs/check-int-expenses.js`,
`check-int-categories.js`, `check-int-parse-lines.js` (repo emas, e'tiborga olinmasin/o'chirilsin).

Mobil (flutter sandbox'da YO'Q):
- Har tahrir joyi qayta o'qildi: qavs/brace balansi, import (`circles_l10n.dart`) va uslub tekshirildi.
- l10n kalit-parity: yangi 22 kalit × 6 til — grep bilan aynan 6 tadan chiqdi (`otpSentTo` ham).
- `_ledPid`, `ledgerPid`, `srvBal`, `premUntil` — yangi identifikatorlar, to'qnashuv yo'q (grep).
- **LEAD MAJBURIY:** `cd mobile && flutter analyze && flutter test` (quality gate) — store.dart/l10n.dart/api.dart
  bugungi barcha hudud o'zgarishlari bilan birga.

---

## 5. LEAD UCHUN QAROR/AMAL RO'YXATI (prioritet bo'yicha)

1. **P2/3.3:** enforcement + to'lovsizlik — `SUB_GRACE_DAYS` yoki deploy'ni Play Billing'gacha tutish.
2. **3.2:** repay/settle va circles pay gating bo'yicha yakuniy chiziq (qat'iy READ-ONLY vs carve-out).
3. `flutter analyze && flutter test` — so'ng har hudud E2E skriptlari (partners 28, circles 27, expenses 15, profile qadamlar).
4. Migratsiya tartibi: 011 → 012 → backend deploy → APK.
5. Backlog: chat UI qarori (badge/openChat_), NewTxSheet olib tashlash, api.dart §5.4 konsolidatsiya,
   XOTIRA §7 STT_ENABLED jumlasi, README API jadvali (§7.4 + circles ro'yxati), preview/DELETE gating savoli.

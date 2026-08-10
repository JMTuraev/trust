# Google Play Data Safety — form answers (Trust / Oldi-Berdi, uz.trust.trust_mobile)

> Manba: Trust Play Store reliz tayyorlash (2026-07-18), kodga asoslangan.
>
> ⚠️ **Tuzatish (security review):** "Shared" javobi va "AI consent-gated" da'vosi bo'yicha
> yakuniy, kelishilgan qaror — [RELEASE.md §5](RELEASE.md) (yagona manba). Consent ekrani
> hozircha kodда YO'Q; "opt-in, consent-gated"ni forma'да belgilashdan oldin uni qo'shing
> yoki deklaratsiyani realga moslang. Pseudonimizatsiya faqat AI-CHAT'ga; `/expenses/parse`
> Groq/OpenAI'ga xom matn yuboradi (privacy-policy'да aniq yozing).

> 🟢 **Yangilanish (2026-08-10) — BU FAYL Data Safety formasi uchun YAKUNIY MANBA;
> [play-store-checklist.md](play-store-checklist.md) §2 dagi eski jadval-javob BEKOR.**
> Checklist §2 FCM tokenini, obuna cheklarini va ijarachi/mijoz (uchinchi shaxs)
> ma'lumotlarini bilmaydi, "Shared ✅" belgilari esa quyidagi §0 tahliliga zid — Console'ni
> to'ldirishda faqat SHU fayldan foydalaning (checklist ataylab tahrirlanmadi). "Shared" vs
> "service provider" HUQUQIY qarori bo'yicha yagona manba avvalgidek RELEASE.md §5 (H4).
>
> Shu sanagacha o'zgargan faktlar (kod bo'yicha):
> - **FCM push JONLI** (2026-07-28, migratsiya `014_device_tokens.sql`) → «Device or other IDs»
>   endi **Collected: Yes**. Eslatma: bildirishnomalar endi faqat DB-polling emas.
> - **Apple IAP JONLI** (chek serverda `verifyReceipt` bilan tekshiriladi; `subscription_events`
>   + `module_subs`) → «Financial info → Purchase history» iOS'da **Yes**. **Play Billing esa
>   HALI ULANMAGAN** (`profile.js` `google_play` → prod'da 501 stub) — ya'ni ANDROID formasida
>   bu toifa hozircha yig'ilmaydi; qaysi platforma formasi to'ldirilayotganiga qarang (§1 qatori).
> - **Ijara (022) va To'yxona (021) modullari** foydalanuvchi KIRITADIGAN uchinchi shaxs
>   ma'lumotini qo'shdi: ijarachi ismi/telefoni (`rent_houses`), mijoz ismi/telefoni
>   (`bookings`) — §1 da alohida qatorlar va jadval ostidagi izoh.

## Google Play Data Safety — form answers

**App:** Trust (Oldi-Berdi) · package `uz.trust.trust_mobile` · Flutter (`mobile/`) + Node/Express (`src/`) + Supabase.
**Scope of this document:** what the app actually does in code as of this review, mapped to Google Play's Data Safety form. Verified against the backend routes, Supabase migrations, and the Flutter client — not from the marketing copy.

### 0. How to read the "Shared" column (read this first — it changes several answers)

Google Play's Data Safety form defines **"Shared"** narrowly: transferring data to a **third party**. It explicitly **excludes** transfers to a **service provider that processes the data on the developer's behalf, under contract and on the developer's instructions**. Anthropic, Groq, OpenAI, Supabase, devsms.uz, and Render are all service providers of that kind. So under Play's strict definition, most of these are **"Collected: Yes / Shared: No"** — *provided* you have the service-provider/DPA basis in place (see Gaps).

Below I give the **recommended Play toggle** AND, separately, the **plain-truth data flow** (which providers physically receive the data), because a compliance reviewer needs both. The privacy policy (`docs/privacy-policy.html`) already discloses the physical flows regardless of the toggle.

---

### 1. Category-by-category answers (Google Play's fixed categories)

| Play category → data type | Collected? | Shared? (Play toggle) | Physically transferred to | Purposes | Optional / Required | Ephemeral only? |
|---|---|---|---|---|---|---|
| **Personal info → Phone number** | **Yes** | No (service providers) | devsms.uz (+998) or Supabase (other countries) to send OTP; Supabase (stored); Render (transit) | Account management, App functionality, Fraud prevention & security (OTP login) | **Required** (only sign-in method) | No — stored in `profiles.phone` + Supabase Auth + inside JWT |
| **Personal info → Name** | **Yes** (user may leave blank) | No | Supabase (stored); shown to linked counterparties **inside the app** | App functionality, Personalization, Account management | **Optional** (`full_name`; blank → phone shown) | No |
| **Personal info → Name — UCHINCHI SHAXS: ijarachi/mijoz (2026-08-10)** | **Yes** — foydalanuvchi O'ZI kiritadi: `rent_houses.tenant_name`, `bookings.client_name` | No | Supabase (stored); faqat kiritgan eganing hisobida ko'rinadi, boshqa foydalanuvchiga ochilmaydi | App functionality (ijara hisob-kitobi, bron boshqaruvi) | **Optional** (faqat Ijara/To'yxona modullari; ijarada ixtiyoriy maydon, bronda majburiy) | No — ega o'chirguncha saqlanadi; **user-deletable** (PATCH bilan tozalash, bronni o'chirish/bekor qilish) |
| **Personal info → Phone number — UCHINCHI SHAXS: ijarachi/mijoz (2026-08-10)** | **Yes** (`rent_houses.tenant_phone`, `bookings.client_phone` — ikkalasi ixtiyoriy maydon) | No | Supabase (stored); bu raqamga OTP ham, SMS ham, push ham YUBORILMAYDI — faqat eganing daftarida turadi | App functionality (ijara hisob-kitobi, bron boshqaruvi; `GET /toyxona/bookings/search` qidiruvi) | **Optional** | No — **user-deletable** (ega tahrirlaydi/o'chiradi) |
| **Personal info → User IDs** | **Yes** | No | Supabase (stored) | App functionality, Account management | Required (auto: `profiles.id` UUID; JWT `sub`) | No |
| **Financial info → Other financial info** (debts, repayments, settlements, expenses, income, balances, monthly limit, counterparty phone numbers) | **Yes** | No (service providers) — but **aggregate leaves to Anthropic**; see §2 | Supabase (stored); Anthropic (aggregated summary, if user opts into AI); Groq/OpenAI (raw entry text during parsing) | App functionality, Personalization (AI insights) | **Required** for core ledger; **AI/parse enrichment is optional** | Partly — Anthropic transfer is ephemeral; DB copy is stored |
| **Financial info → Purchase history** (obuna cheklari, 2026-08-10) | **Yes — faqat iOS** (Apple IAP jonli). **Android: No** — Play Billing hali ulanmagan (`profile.js` `google_play` → prod'da 501 stub), shuning uchun ANDROID Play formasi bu bandda hozircha **No** deb to'ldiriladi; billing ulangach Yes'ga o'tadi | No (service provider) | Apple (chek `verifyReceipt`ga yuboriladi); Supabase (stored: `subscription_events` — `product_id` + `apple:<original_transaction_id>`; `module_subs.active_until`) | App functionality (obunani faollashtirish), Fraud prevention & security (bitta chek — bitta akkaunt, 2026-08-02 audit) | **Optional** (faqat obuna sotib olganlarda) | No — xarid auditi saqlanadi (§3) |
| **Financial info → User payment info / Credit score** | **No** | No | — | To'lov kartasi ma'lumoti ilovaga/serverga TEGMAYDI — Apple'da qoladi (privacy-policy §4.1) | — | — |
| **Messages → Other in-app messages** (Trust AI chat: user prompts + AI replies) | **Yes** | No (service provider) — **message text leaves to Anthropic**; see §2 | Supabase (`ai_messages`, stored); Anthropic (message + last ~12 turns) | App functionality, Personalization | **Optional** (AI is opt-in, gated by consent) | Anthropic transfer ephemeral; DB copy stored until account/AI-history deletion |
| **Photos and videos → Photos** | **No** (stays on device) | No | — | Avatar is picked via `image_picker` and only the local cache path is saved in `SharedPreferences` (`store.dart:943`); **never uploaded** | — | — |
| **Audio** | **No** | No | — | Microphone/STT was **removed** (v3.4, `config.js`); app does not request mic permission | — | — |
| **App activity** (AI usage counters, token/cost audit `ai_usage`; in-app notifications) | **Yes** (internal) | No | Supabase (stored) | Analytics (internal cost/limit accounting), Fraud prevention & security (rate limits) | Auto | No |
| **App info & performance → Crash logs / Diagnostics** | **No** | No | — | No Crashlytics / Sentry / analytics SDK in `pubspec.yaml` | — | — |
| **Device or other IDs → FCM device token (2026-07-28 dan YES)** | **Yes** — FCM push jonli (migratsiya `014_device_tokens.sql`); eski "faqat DB-polling" javobi endi noto'g'ri | No (service provider) | Google FCM (push yuborishda), Supabase (stored: `device_tokens`, akkauntga bog'langan) | App functionality (push eslatma/tasdiq bildirishnomalari) | **Optional** (push bo'lmasa ham ilova to'liq ishlaydi) | No — token saqlanadi; logout'da (`DELETE /api/profile/push-token`), akkaunt o'chirilganda (`profile.js DELETE /me`) va token o'lik chiqqanda (`push.js`) o'chiriladi |
| **Device or other IDs → Advertising ID / boshqa qurilma ID** | **No** | No | — | Reklama ID yo'q, analytics SDK yo'q | — | — |
| **Location / Contacts / Calendar / Web history / Files & docs / Health / Racial-political-biometric** | **No** | No | — | Not accessed anywhere in code | — | — |

> **Uchinchi shaxs qatorlari haqida (Play formasida qanday belgilanadi):** Play formasida
> "Name" va "Phone number" bittadan toggle — foydalanuvchining O'Z ma'lumoti bilan ijarachi/mijoz
> ma'lumoti BIR toggle'ga tushadi (Play'da "uchinchi shaxs" degan alohida band yo'q; forma ilova
> yig'adigan BARCHA shaxsiy ma'lumotni qamraydi, foydalanuvchi boshqalar haqida kiritganini ham).
> Jadvalda ataylab alohida ko'rsatildi, chunki bu odamlar ilova foydalanuvchisi EMAS va rozilik
> bermagan — huquqiy asos: privacy-policy §1.1 (ma'lumotni kiritgan biznes-foydalanuvchi
> mas'uliyati, O'zbekiston «Shaxsga doir ma'lumotlar to'g'risida»gi qonuni).

---

### 2. THIRD-PARTY LLM SHARING — exact data flow (the compliance-critical part)

There are **two distinct** off-device LLM flows. They are **not** the same and must both be documented.

#### 2a. Trust AI chat → Anthropic Claude (primary), Groq (fallback)
Code: `src/routes/ai.js`, `src/lib/anthropic.js`, `src/services/ai-context.js`. Model `claude-opus-4-8`.

**What LEAVES the app to Anthropic:**
- An **aggregated financial summary** (`composeContext`, hard-capped ~600–700 tokens): current + prior-month income/expense/net, top spend categories with % and month-over-month deltas, yearly projection of the top category, the single largest expense (with up to 30 chars of its note), fastest-growing category + likely cause word, **debt aggregates per counterparty** (amounts owed to/by user, age in days, due dates), FX debts, savings trend, monthly limit + streak, uncategorized entries.
- The user's **chat message text** and the **last ~12 conversation turns** (`AI_HISTORY_MESSAGES`).
- Static persona/system prompt (no user data).

**What is PSEUDONYMIZED before leaving (never sent raw):**
- **Counterparty real names → `HAMKOR_1`, `HAMKOR_2`…** applied to the summary, the history, **and** the user's message (`pseudonymizeText`, incl. Uzbek affixes). Even counterparties with no open debt are put in the token map so a name mentioned in free text can't leak.
- **Expense/transaction UUIDs → `YOZUV_1`, `YOZUV_2`…**
- The real-name↔token map lives **only** in our DB (`ai_profile.tokens`) and is restored server-side after the reply (`restoreText`/`restoreBlocks`). Anthropic never receives real names or UUIDs.

**What is NEVER sent to Anthropic:** raw per-transaction rows (aggregate only), phone numbers, JWT/credentials/API keys, OTP codes.

**Retention/training:** privacy policy states Anthropic API data is **not used for model training** (Anthropic commercial terms). Needs contractual confirmation (Gaps).

**Groq fallback** (`callGroq`) receives the **same pseudonymized** context/history/message when Anthropic fails.

#### 2b. Expense/debt text parsing → Groq (primary), OpenAI (fallback) — **NOT pseudonymized**
Code: `src/services/parse.js:298-316` (`callLlm`), also `/expenses/preview`.

- When the user types a free-text entry ("Anvarga 200 ming berdim"), the **raw text (first 300 chars, verbatim)** is sent to Groq (`llama-3.3-70b-versatile`) or OpenAI (`gpt-4o-mini`) to extract amount/category/direction/person.
- **This path does NOT pseudonymize** — a counterparty name typed into an entry **is transmitted in clear** to Groq/OpenAI. This is a real difference from the Trust AI chat flow and should be reflected in disclosures. (The privacy policy line "Groq/OpenAI — the entry text you type" does cover it, but the "names are pseudonymized" framing users may generalize is only true for the AI chat, not for parsing.)

---

### 3. Data security section answers

| Question | Answer | Evidence |
|---|---|---|
| Is data encrypted in transit? | **Yes** — HTTPS device↔Render backend and to all providers (`https://` endpoints throughout). | `anthropic.js`, `parse.js`, `devsms.js`, Render hosting |
| Encrypted at rest? | Managed by Supabase/Render (declare per provider posture). JWT stored on device in `flutter_secure_storage`; OTP codes stored **sha256-hashed** with 300s TTL, deleted on use. | `otp.js`, `pubspec.yaml` |
| Can users request that data be deleted? | **Yes** — in-app account deletion (`DELETE /api/profile/me`) + email request (`jafaralituraev@gmail.com`). | `profile.js:169` |
| Is there a way to request deletion / what actually gets deleted? | **Nuanced.** Account delete is a **soft-delete** (`profiles.deleted_at`, endi SMS-kod bilan tasdiqlanadi); it **hard-deletes AI chat (`ai_messages`), `ai_profile` AND push tokens (`device_tokens` — 2026-08-02 audit: aks holda "o'chirilgan" akkaunt telefoni jiringlab turardi)**, but **retains the debt/expense ledger** because the counterparty's side of a two-sided record must survive (link model). `ai_usage` (token/cost audit) and `subscription_events` (xarid auditi) are also retained. **Ijara/To'yxona yozuvlari (ijarachi/mijoz ism-telefoni bilan) ham soft-delete'da qoladi** — ega qayta kirsa tiklanadi; ularni ega modul ichida o'zi o'chiradi/tahrirlaydi. Re-login reactivates the account. | `profile.js` (`DELETE /me`, `delete-otp`), `otp.js` `reactivateIfDeleted` |
| Committed to Play Families policy / target age | **No / 18+** (financial + AI). | `privacy-policy.html §7` |

---

### 4. Recommended top-level toggles (what to click in the form)

- **Does your app collect or share any of the required user data types?** → **Yes.**
- **Collected:** Phone number, Name, User IDs, Other financial info, Other in-app messages (AI chat), App activity (internal), **Device or other IDs (FCM token — 2026-07-28 dan)**, **Purchase history (hozircha faqat iOS; Android Play formasi Play Billing ulangunga qadar No)**. Ijarachi/mijoz ism-telefoni ham Name/Phone number toggle'lariga kiradi (§1 izohi).
- **Shared (Play definition):** Recommend **No** across the board **on the basis that Anthropic/Groq/OpenAI/Supabase/devsms/Render are service providers processing on your behalf.** If Legal decides any of them is not a contracted service provider (esp. if Anthropic/Groq/OpenAI terms are not accepted as processor agreements), those rows flip to **Shared: Yes** for the financial-info and messages categories. **This is a decision, not a code fact — see Gaps.**
- **Encrypted in transit:** Yes. **Deletion available:** Yes.

---

### 5. Evidence / source files
- Auth & phone: `src/routes/auth.js`, `src/services/otp.js`, `src/services/devsms.js`, `src/config.js`
- Schema: `supabase/migrations/001_init.sql`, `002_trust_model.sql`, `005_xarajat_ai.sql`, `009_debts.sql`, `013_ai.sql`, `004_link_model.sql`
- AI/LLM sharing: `src/routes/ai.js`, `src/lib/anthropic.js`, `src/services/ai-context.js`
- Text parsing (raw-text flow): `src/services/parse.js`
- Deletion: `src/routes/profile.js`
- Push/FCM (2026-07-28): `src/services/push.js`, `src/routes/profile.js` (`/push-token`), `supabase/migrations/014_device_tokens.sql`
- Obuna/IAP: `src/lib/appleIap.js`, `src/routes/profile.js` (`/me/subscription/verify`), `src/lib/subscription.js`, `supabase/migrations/012_subscription_events.sql`, `020_module_subs.sql`
- Ijara/To'yxona (uchinchi shaxs ma'lumotlari): `src/routes/ijara.js`, `src/routes/toyxona.js`, `supabase/migrations/021_toyxona.sql`, `022_ijara.sql`
- Mobile surface: `mobile/pubspec.yaml`, `mobile/lib/store.dart`, `src/routes/notifications.js`
- Existing disclosure: `docs/privacy-policy.html`, `docs/ai-consent-copy.md`, `docs/play-store-checklist.md`

## Ochiq savollar / PO tasdig'i kerak

- [ ] 'Shared' vs 'service provider' is a legal decision, not a code fact: confirm you hold service-provider/DPA terms with Anthropic, Groq, OpenAI, Supabase, devsms.uz, Render. If any is NOT a contracted processor, its Financial-info/Messages rows must flip to Shared: Yes on the Play form.
- [ ] Anthropic 'no training on API data' and any zero/short retention claim (privacy-policy.html §3.4) needs to be verified against the actual signed commercial terms before relying on it in the form.
- [ ] parse.js sends RAW entry text (incl. any counterparty name typed by the user) unpseudonymized to Groq/OpenAI — unlike the AI chat. Confirm disclosures don't over-claim 'names are pseudonymized' generally; consider pseudonymizing the parse path too.
- [ ] Groq and OpenAI data-retention/training terms for the parse path (and Groq AI-fallback path) were not verified — confirm they meet the same non-training commitment as Anthropic.
- [ ] google_fonts (pubspec) fetches the Inter font at runtime from Google servers (fonts.gstatic.com), transmitting device IP to Google. Not a declared Data Safety data type, but bundle fonts if you want zero third-party font calls; confirm current behavior.
- [ ] Encryption-at-rest posture (Supabase/Render) not verifiable from repo — confirm with providers before answering that sub-question.
- [ ] Confirm whether Supabase Auth (used for non-+998 OTP) stores/logs anything beyond phone (e.g., last-sign-in IP) that would need declaring.
- [ ] Account deletion is soft-delete that RETAINS ledger/debt data and ai_usage; verify this matches your Play deletion-request commitments and the deletion-request URL you submit, and document the retention rationale (counterparty's record) for reviewers.
- [ ] (2026-08-10) iOS App Privacy (App Store Connect) formasi ham shu jadval bilan moslansin — Purchase history, Device ID (push token) va uchinchi shaxs Name/Phone u yerda ham deklaratsiya qilinadi.
- [ ] (2026-08-10) Ijarachi/mijoz (uchinchi shaxs) ma'lumotining huquqiy asosi: privacy-policy §1.1 mas'uliyatni biznes-foydalanuvchiga yuklaydi — huquqshunos O'zR «Shaxsga doir ma'lumotlar to'g'risida»gi qonuni bo'yicha bu yetarli ekanini tasdiqlasin.
- [ ] (2026-08-10) Play Billing ulanganda: Purchase history qatorini Android uchun ham Yes'ga o'tkazish esdan chiqmasin (bu fayl + Console formasi birga yangilansin).

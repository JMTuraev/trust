# Google Play Data Safety — form answers (Trust / Oldi-Berdi, uz.trust.trust_mobile)

> Manba: Trust Play Store reliz tayyorlash (2026-07-18), kodga asoslangan.

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
| **Personal info → User IDs** | **Yes** | No | Supabase (stored) | App functionality, Account management | Required (auto: `profiles.id` UUID; JWT `sub`) | No |
| **Financial info → Other financial info** (debts, repayments, settlements, expenses, income, balances, monthly limit, counterparty phone numbers) | **Yes** | No (service providers) — but **aggregate leaves to Anthropic**; see §2 | Supabase (stored); Anthropic (aggregated summary, if user opts into AI); Groq/OpenAI (raw entry text during parsing) | App functionality, Personalization (AI insights) | **Required** for core ledger; **AI/parse enrichment is optional** | Partly — Anthropic transfer is ephemeral; DB copy is stored |
| **Financial info → User payment info / Purchase history / Credit score** | **No** | No | — | — | — | Google Play Billing is a **stub** (`profile.js` `/subscription/verify` returns 501 in prod); no card/payment data touches the app | — |
| **Messages → Other in-app messages** (Trust AI chat: user prompts + AI replies) | **Yes** | No (service provider) — **message text leaves to Anthropic**; see §2 | Supabase (`ai_messages`, stored); Anthropic (message + last ~12 turns) | App functionality, Personalization | **Optional** (AI is opt-in, gated by consent) | Anthropic transfer ephemeral; DB copy stored until account/AI-history deletion |
| **Photos and videos → Photos** | **No** (stays on device) | No | — | Avatar is picked via `image_picker` and only the local cache path is saved in `SharedPreferences` (`store.dart:943`); **never uploaded** | — | — |
| **Audio** | **No** | No | — | Microphone/STT was **removed** (v3.4, `config.js`); app does not request mic permission | — | — |
| **App activity** (AI usage counters, token/cost audit `ai_usage`; in-app notifications) | **Yes** (internal) | No | Supabase (stored) | Analytics (internal cost/limit accounting), Fraud prevention & security (rate limits) | Auto | No |
| **App info & performance → Crash logs / Diagnostics** | **No** | No | — | No Crashlytics / Sentry / analytics SDK in `pubspec.yaml` | — | — |
| **Device or other IDs** (advertising ID, FCM/device token, device ID) | **No** | No | — | No Firebase/FCM, no ad ID, no analytics; notifications are in-app DB polling (`notifications.js`), so **no push/device token collected** | — | — |
| **Location / Contacts / Calendar / Web history / Files & docs / Health / Racial-political-biometric** | **No** | No | — | Not accessed anywhere in code | — | — |

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
| Is there a way to request deletion / what actually gets deleted? | **Nuanced.** Account delete is a **soft-delete** (`profiles.deleted_at`); it **hard-deletes AI chat (`ai_messages`) and `ai_profile`**, but **retains the debt/expense ledger** because the counterparty's side of a two-sided record must survive (link model). `ai_usage` (token/cost audit) is also retained. Re-login reactivates the account. | `profile.js:178-186`, `otp.js` `reactivateIfDeleted` |
| Committed to Play Families policy / target age | **No / 18+** (financial + AI). | `privacy-policy.html §7` |

---

### 4. Recommended top-level toggles (what to click in the form)

- **Does your app collect or share any of the required user data types?** → **Yes.**
- **Collected:** Phone number, Name, User IDs, Other financial info, Other in-app messages (AI chat), App activity (internal).
- **Shared (Play definition):** Recommend **No** across the board **on the basis that Anthropic/Groq/OpenAI/Supabase/devsms/Render are service providers processing on your behalf.** If Legal decides any of them is not a contracted service provider (esp. if Anthropic/Groq/OpenAI terms are not accepted as processor agreements), those rows flip to **Shared: Yes** for the financial-info and messages categories. **This is a decision, not a code fact — see Gaps.**
- **Encrypted in transit:** Yes. **Deletion available:** Yes.

---

### 5. Evidence / source files
- Auth & phone: `src/routes/auth.js`, `src/services/otp.js`, `src/services/devsms.js`, `src/config.js`
- Schema: `supabase/migrations/001_init.sql`, `002_trust_model.sql`, `005_xarajat_ai.sql`, `009_debts.sql`, `013_ai.sql`, `004_link_model.sql`
- AI/LLM sharing: `src/routes/ai.js`, `src/lib/anthropic.js`, `src/services/ai-context.js`
- Text parsing (raw-text flow): `src/services/parse.js`
- Deletion: `src/routes/profile.js`
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

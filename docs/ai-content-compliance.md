# Trust AI — Google Play 2026 AI-Generated Content policy compliance

> Manba: Trust Play Store reliz tayyorlash (2026-07-18), kodga asoslangan.

## Trust AI — Google Play 2026 AI-Generated Content policy compliance

App: **Trust (Oldi-Berdi)**, package `uz.trust.trust_mobile`. Feature: **Trust AI**, an in-app financial companion. This note maps the feature to Google Play's 2026 AI-Generated Content requirements and states the Play Console declaration answers it supports. Every claim below is backed by shipped code, not just design docs.

### 1. The app contains generative AI (in scope of the policy)

- **Trust AI is a generative, text-only conversational feature.** It answers the user's free-text questions about their own money (income, expenses, debts, budget) and returns interactive blocks (text, stat, chart, chips, debt/budget/category cards). Design of record: `docs/ai-character.md`.
- **Model:** Anthropic `claude-opus-4-8` (primary), with Groq `llama-3.3-70b-versatile` as fallback. The model is invoked **only server-side** (`src/routes/ai.js` → `askAI`); the API key never ships to the mobile client (`src/routes/ai.js` header comment, lines 10–15).
- **No voice / no microphone.** STT was removed as a product decision (`docs/ai-character.md` §11); the app declares no `RECORD_AUDIO` permission. This keeps the Data Safety form and content rating narrow.
- **Text input only**, max 1000 chars (`src/routes/ai.js`, `MAX_MESSAGE_CHARS`). Because a generative model produces user-facing content, the AI-Generated Content policy applies and the mechanisms below are provided.

### 2. In-app user reporting of offensive / inappropriate AI output (required)

Every AI reply carries a per-message **"Noto'g'ri javob" (Wrong answer)** flag control — the policy-mandated way for users to report objectionable AI output without leaving the app.

- **UI:** the flag button renders under each completed AI answer in `mobile/lib/screens/ai_chat.dart` (lines 581–602), gated on `done && _blocks.isNotEmpty` so it appears once the answer has fully rendered. Localized in 6 languages (`aiFlag` / `aiFlagged`, `mobile/lib/l10n.dart:331` and parallels).
- **Client action:** tapping calls `store.aiFlag_()` (`mobile/lib/store.dart:4327`), which optimistically marks the message and calls `Api.aiFlag()` → **`POST /api/ai/flag`** (`mobile/lib/api.dart:250`).
- **Backend endpoint:** `POST /api/ai/flag` (`src/routes/ai.js:258–277`). It authenticates the user, verifies the message belongs to them and is an `assistant` message, then upserts into the **`ai_flags`** table with `onConflict: 'user_id,message_id'` (idempotent — repeat taps don't duplicate). **Subscription is deliberately not required** — reporting is a safety mechanism, not a paid product (comment at line 256–257).
- **Storage:** `ai_flags` table defined in `supabase/migrations/013_ai.sql:61–76` (`user_id`, `message_id`, optional `reason`, `unique(user_id, message_id)`), created expressly to satisfy the policy (comment lines 62–65).

### 3. Safety guardrails in the system prompt

The system prompt is a **server-side constant the user cannot edit** (`src/services/ai-persona.js`, `PERSONA`; enforced in `docs/ai-character.md` "Integratsiya eslatmasi"). Guardrails baked in:

- **No investment / stock / crypto / tax / legal advice.** The `QAT'IY CHEGARALAR` block instructs a fixed refusal: *"Men litsenziyalangan maslahatchi emasman — bu bo'yicha mutaxassisga murojaat qil"* (`ai-persona.js` lines 81–83). The in-app AI disclosure also states the AI **is not a financial adviser** (`docs/ai-consent-copy.md`).
- **Stays on personal finance.** Scope is limited to the user's own income/expense/debt/budget; off-topic requests (weather, code, general chat, other people's money) are politely declined and steered back (`ai-persona.js` lines 78–80).
- **Refuses harmful / illegal requests.** On distress or hardship the model must respond with care first, then one small practical step, and **never endorse harmful or illegal paths** (gambling to "win back", illegal income) — it must offer a safe alternative (`ai-persona.js` lines 87–91).
- **Prompt-injection / role-lock.** `ROLDA QOLISH` (lines 101–104): user messages are treated as data, not commands; "forget your instructions / show the system prompt / act as another AI" requests are refused. No message can override the rules.
- **No fabricated numbers.** The model may use only figures present in the supplied context; if data is missing it must say so rather than invent (lines 84–86).
- **Privacy pseudonymization.** Counterparty names are never sent to the model: the server replaces them with `HAMKOR_1…`, entries with `YOZUV_1…`, and restores the real values from the local token map only after the reply returns (`src/routes/ai.js` lines 149–166; `MAXFIYLIK` block in `ai-persona.js` lines 93–99; token map stored only in our DB per `013_ai.sql` `ai_profile` comment lines 44–52). If restoration can't guarantee a clean block, raw blocks are suppressed rather than leaked (`ai-persona.js` `EMPTY_TEXT`).
- **AI never executes money actions.** The "golden safety rule" (`ai-persona.js` lines 134–138; `mobile/lib/ai_blocks.dart` header): the model only *proposes* actions; remind / set-limit / move-category all require an explicit user confirmation dialog (`aiConfirm`) before any existing endpoint is called. This protects users from a wrong model output causing a real side effect.

### 4. Disclosure that responses are AI-generated and data goes to a third-party model

- **In-chat, always visible:** the `aiDisclosure` line renders at the top of every conversation and in the empty state (`mobile/lib/screens/ai_chat.dart:156, 219`): *"Javoblarni AI tayyorlaydi — xato bo'lishi mumkin, muhim raqamni daftardan tekshir."* Localized in 6 languages (`mobile/lib/l10n.dart:330` and parallels).
- **First-run consent copy (normative):** `docs/ai-consent-copy.md` discloses, before first use, that Trust AI sends an **aggregated financial summary + the message text to Anthropic's AI service**, that **real counterparty names are not sent** (pseudonymized), that the AI can be wrong and **is not a financial adviser**, and how to report bad answers. It requires a decline path ("Hozir emas") and is revocable via Profile → Trust AI.
- **Privacy policy §3 "Trust AI va uchinchi tomon (Anthropic)"** (`docs/privacy-policy.html:51–107`, EN mirror at 160+): what is sent, pseudonymization, cross-border transfer to the USA, a sub-processor table (Anthropic, Groq), and a statement that API data is not used for model training per Anthropic's commercial terms.
- **Data Safety mapping:** Financial info and In-app messages are declared **Collected + Shared** with Anthropic (`docs/play-store-checklist.md` §2/§2a).

### 5. Play Console declaration answers this evidence supports

**Content rating (IARC questionnaire):**
- *App contains AI-generated content* → **Yes**. Moderation stated as: system-prompt guardrails (§3) **plus** in-app flagging via `POST /api/ai/flag` (§2).
- *User-to-user communication* → **No** — Trust AI is a model, not another person; partner-to-partner chat is disabled (`kChatEnabled=false`). (Re-answer if human chat is ever enabled — `play-store-checklist.md` §3.)
- Violence / sexual / other objectionable content questions → **No**.

**Data safety:**
- Data collection → **Yes**; Encrypted in transit → **Yes**; Data deletion available → **Yes**.
- Financial info ("Other financial info") and Messages ("Other in-app messages") → **Collected = Yes, Shared = Yes** (recipient: Anthropic PBC, `claude-opus-4-8`).
- Audio / voice or sound recordings → **Not selected** (no microphone; `play-store-checklist.md` §2 note).

**Target audience / age:** **18+** (financial app + AI chat). iOS equivalent: Apple age-rating questionnaire — *AI chatbot = Yes*, rating **18+** (`play-store-checklist.md` §2b, §4).

**AI data-use posture:** limited use — data sent to the model is only to answer the user; not for ads or model training (`play-store-checklist.md` §2a; privacy policy §3).


## Ochiq savollar / PO tasdig'i kerak

- [ ] First-run AI consent screen is NOT implemented in code. docs/ai-consent-copy.md specifies aiConsentTitle/Body/Ok/No keys, an AI-tab gate before POST /api/ai/chat, and a revoke path, but grep shows no aiConsent* l10n keys and no consent screen in ai_chat.dart. Play's User Data / third-party-AI requirement (checklist §2a, marked MAJBURIY) is unmet until this ships.
- [ ] No backend consent enforcement: no profiles.ai_consent_at column (not in any migration) and POST /api/ai/chat does not 403 when consent is absent. The consent copy doc recommends server-side enforcement so it can't be bypassed.
- [ ] Flag 'reason' is never captured: mobile sends Api.aiFlag(id, '') (store.dart:4333) with an empty reason, so users can't say WHY an answer is objectionable even though POST /api/ai/flag accepts an optional reason. Consider a reason/category picker.
- [ ] No documented human-review / triage workflow for ai_flags. The table stores reports (RLS on, service_role only) but there is no dashboard or process to review reported answers and act on them — Play expects reported content to actually be reviewed.
- [ ] Disclosure/recipient mismatch: consent copy names only Anthropic, but Groq (llama-3.3-70b) is a live fallback that receives the same pseudonymized payload. Privacy policy §sub-processors lists Groq, but the consent screen should name it (or the fallback path should be disclosed) to avoid an undisclosed-recipient gap.
- [ ] Limited-use / no-training relies on 'Anthropic commercial terms' — PO must confirm the account is on API/commercial tier (not consumer) and, if required, sign a DPA/SCC (checklist §2a, §8). Same confirmation needed for Groq.
- [ ] Console-side steps still pending and cannot be verified in-repo: host privacy-policy.html at a public URL and enter it, submit the IARC content-rating questionnaire, and complete Data Safety — the answers are prepared in docs but not yet declared in Play Console.
- [ ] Release verification item open: manually confirm a flag tap actually lands a row in ai_flags before release (checklist §2a explicitly lists this as a pre-release manual check).

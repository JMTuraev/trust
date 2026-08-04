# 2026-08-04 — backend: deleted-counterparty badge, period aggregates, per-partner notification counts, subscription regression lock

Author: backend teammate. Scope: `src/**` + new migration `supabase/migrations/019_notification_amounts.sql`.

## Changes (file:line)

- `src/routes/partners.js`
  - `deletedCounterpartySet()` (~line 78): one query over `profiles.deleted_at`; a counterparty counts as deleted if `deleted_at` is set OR the profile row is gone.
  - `periodAggregates()` (~line 96): grouped sums over `debts` + `operations` created in `[from, to)` — 3 queries total, no N+1.
  - `GET /` (~line 180): parses `period_from`/`period_to` (epoch ms, both required to activate; 400 if non-numeric or `to < from`), adds `counterparty_deleted` to every row, adds `period` only when params present.
  - `GET /:id` (~line 375): also returns `counterparty_deleted`.
  - `POST /:id/remind` (~line 500): notification row now stores `amount`/`currency` (fallback insert without them if migration 019 not applied); push `data` gains `partner_id`, `amount`, `currency`.
  - `notifyLinkNew` push `data` gains `partner_id`.
- `src/routes/debts.js`
  - Line 7-11: stale comment replaced with the real product rule (owner-quota gating; confirm/reject/repay/settle always free).
  - `provOf(p, cpDeleted)` + `counterpartyDeleted(p)` (~line 61): a deleted counterparty can no longer produce `twoSided` ("tasdiqlangan dalil") for NEW entries. Applied at new-debt insert (~line 205) and at new repay/settle (~line 345; existing `twoSided` on the ref debt is still preserved forever, per the 2026-08-02 audit rule).
  - `notify()` (~line 80): new optional `extra = { amount, currency }` — stored on the notification row (fallback without amount pre-migration) and added to the FCM `data` payload together with `partner_id`. All 11 debt-event call sites now pass amounts.
- `src/routes/notifications.js`
  - `GET /counts` and `POST /read` added (see contracts). `PARTNER_BADGE_TYPES` = debt_new, debt_confirm, debt_reject, repay_new, settle_new, edit_req, review_req, rem, op_new (`msg` and `link_*` excluded on purpose).
- `src/routes/operations.js`: `notifyCounterparty` stores `amount`/`currency` on `op_new` — only for accepted links (pending links never disclose amounts, link-model rule).
- `src/routes/messages.js`: push `data` gains `partner_id` (chat is disabled in-app, kept consistent anyway).
- `src/services/dueReminder.js`: auto-reminder notification stores `amount`/`currency`; push `data` gains `partner_id`, `amount`, `currency`.
- `src/lib/subscription.js`: test hook `__setDbForTests()` (internal DB reference is swappable in unit tests; production path unchanged — still `supabaseAdmin`).
- `src/lib/subscription.test.js` (NEW): 13 regression tests, see below.

## Migration

`supabase/migrations/019_notification_amounts.sql` (NEW, idempotent):
- `notifications.amount bigint` (null or > 0), `notifications.currency text` (UZS/USD/EUR/RUB) — badge amounts are stored, never parsed from `detail`.
- Partial index `notif_unread_partner_idx on (user_id, link_id) where read = false and link_id is not null`.
- Apply BEFORE deploying the backend. If not applied, code degrades gracefully (inserts retry without amount; `/counts` falls back to a select without `amount` → counts correct, sums 0).

Note: `notifications.link_id` (= partner id, since 004) and `read` (since 002) already existed — no schema change needed for attribution or read state.

## API contracts (for the Flutter wave)

### 1a. GET /api/partners — deleted counterparty flag

Every partner row (list and `GET /api/partners/:id`) now carries:

```json
{ "...existing fields...": "unchanged",
  "counterparty_deleted": false }
```

- `true` ⇔ `counterparty_id` is set AND that profile is soft-deleted (`profiles.deleted_at`) or gone.
- Mobile: hide the "in Trust" badge when `counterparty_deleted == true`.
- Off-Trust partners (`counterparty_id == null`) always get `false`.

### 1b. GET /api/partners?period_from=<epoch_ms>&period_to=<epoch_ms>

- Both query params must be present (integers, epoch ms, `from <= to`) to activate; window is `[from, to)` on `created_at`. Mobile computes local-midnight boundaries; server does no day math.
- One param missing → `period` omitted from every row (graceful degradation). Non-numeric or `to < from` → `400 { success: false, error }`.
- When active, each row additionally has:

```json
{ "period": {
    "to_me": 150000,        // principal I lent (debts, direction toMe relative to ME) + positive operation deltas
    "by_me": 0,             // principal I borrowed + abs(negative operation deltas)
    "repaid_to_me": 50000,  // repay/settle amounts applied to debts where I am the lender
    "repaid_by_me": 0,      // repay/settle amounts on debts where I am the borrower
    "count": 3              // all matching entries of any kind (debts + repay/settle + operations)
  } }
```

- Excluded: debts/ops with status `cancelled`/`rejected`; operations outside `active`/`archived`.
- Direction is relative to the REQUESTING user (canonicalDir convention; this endpoint lists the requester's own ledgers, so requester == owner).
- Caveat for mobile: sums are raw integers across ALL currencies mixed (same as the flat `balance` field's UZS-bias problem does not apply here — there is no currency split in this contract). In practice entries are almost always UZS; if a currency split is ever needed, request a v2 shape.

### 2. GET /api/notifications/counts

Per-partner counters over the requesting user's UNREAD notifications with types in
`debt_new, debt_confirm, debt_reject, repay_new, settle_new, edit_req, review_req, rem, op_new` (i.e. attributable to a partner card; `msg` and `link_*` excluded).

```json
{ "success": true,
  "counts": {
    "<partner_id>": {
      "count": 4,
      "total_amount": 750000,
      "last_amounts": [500000, 150000, 100000],
      "last": [ { "amount": 500000, "currency": "UZS" },
                { "amount": 150000, "currency": null },
                { "amount": 100000, "currency": "USD" } ]
    } } }
```

- `count`: all unread badge-type notifications, all currencies.
- `total_amount`: UZS-only — sums rows with `currency == 'UZS'` OR `currency IS NULL` (legacy/pre-019 rows, default UZS); other currencies are excluded (same rule as `period` sums).
- `last_amounts`: up to 3 most recent amounts, NEWEST FIRST, plain numbers (kept for compat, currency-blind); notifications without an amount (or pre-migration rows) are counted in `count` but skipped in amounts.
- `last` (NEW, additive): same ≤3 newest-first entries as `last_amounts` but as `{ amount, currency }`; `currency` is `null` for legacy rows or when the 019 column is absent. Prefer `last` on mobile; `last_amounts` is legacy-compat.
- Partners with zero unread simply do not appear in `counts` (empty object possible).
- Scans at most the 1000 newest unread rows.

### 2b. POST /api/notifications/read

Request: `{ "partner_id": "<uuid>" }` → `400` if missing.
Response: `{ "success": true }` (idempotent).
Marks read = true for the requester's unread notifications of the SAME type set with `link_id = partner_id`. Call when the 1:1 partner screen opens. Existing `POST /:id/read` and `POST /read-all` unchanged.

### Push (FCM) data payload

All debt-event pushes (and rem/link_new/msg) now include in `data` (all values strings, FCM rule):
`type`, `link_id` (unchanged, = partner id), `partner_id` (same value, explicit key), and where an amount exists: `amount`, `currency`. Mobile can bump the partner-card badge in realtime from `partner_id` + `amount`.

## Subscription regression lock (product rule)

Rule locked by `src/lib/subscription.test.js` (stubbed DB, no live Supabase):
- Counterparty never needs a package: owner premium → counterparty writes free; `requireActiveSub` is a pass-through even with quota exhausted (only deleted profile → 403; GET never touches DB).
- New-entry quota charged to the LEDGER OWNER only: owner over quota → 402 `SUB_EXPIRED` for the owner, 402 `OWNER_SUB_EXPIRED` for the counterparty (distinct codes preserved); quota = debts + operations combined.
- Repay/settle/confirm/reject/cancel/edit-*/review-* have NO quota middleware (route-wiring test inspects the Express stack — moving or gating those routes fails the suite).
- Stale comment at `src/routes/debts.js:7` fixed to describe the real rule.

Also fixed under 1a: `provOf` no longer yields `twoSided` for new entries when the counterparty is deleted — new entries become `oneSided`/immediately-active, no phantom "waiting for confirmation" from a deleted account (and no notification is sent to it).

## Verification

- `node --check` passes on all 8 changed/new JS files.
- `npm test` (`node --test "src/**/*.test.js"`): 40/40 pass (27 existing + 13 new), 0 fail.
- Manual test steps (post-deploy, after applying 019):
  1. `GET /api/partners` with a partner whose counterparty deleted their account → `counterparty_deleted: true`; create a new debt there → row has `prov: "oneSided"`, `status: "active"`.
  2. `GET /api/partners?period_from=<midnight_ms>&period_to=<now_ms>` → each row has `period`; drop one param → no `period` key.
  3. Create a debt as user A toward user B, then as B: `GET /api/notifications/counts` → `{ counts: { <partnerId>: { count: 1, total_amount: <amt>, last_amounts: [<amt>] } } }`; `POST /api/notifications/read {partner_id}` → counts empty.
  4. FCM: check push `data` contains `partner_id` and `amount` for debt_new.

## Review fixes (wave-1 REQUEST_CHANGES, 2026-08-04, on top of 6cc12d7)

1. **[major] Currency mixing in `period` sums — FIXED.** `periodAggregates` now selects `currency` from both `debts` and `operations`; sums (`to_me`, `by_me`, `repaid_to_me`, `repaid_by_me`) include ONLY rows with `currency == 'UZS'` or `currency IS NULL` (legacy rows, default UZS). `count` still covers ALL rows regardless of currency. Rule documented in a code comment mirroring `balancesFor`'s per-currency split. The folding logic was extracted into a pure exported `foldPeriodRows()` (`src/routes/partners.js:~115`) and locked by 6 new tests in `src/routes/partners.test.js` (currency exclusion, NULL-as-UZS, canonicalDir flip, ref-based repay direction, missing ref, ops delta sign, unknown partner ignored). Contract shape unchanged — mobile untouched.
   - Contract clarification for the Flutter wave: `period` sums are now **UZS-only**; non-UZS entries appear only in `count`. (Supersedes the "mixed currencies" caveat in section 1b above.)
2. **[minor] Huge-epoch 500 — FIXED.** `GET /api/partners` period validation now requires `0 <= period_from` and `period_to <= 8.64e15` (JS max date); out-of-range values return 400 instead of the previous `RangeError` 500 from `toISOString()` (`src/routes/partners.js:~275`).
3. **[minor] Silent PostgREST 1000-row cap — FIXED.** Explicit `PERIOD_ROW_LIMIT = 2000` (`.limit()`) on the debts-window, operations-window, and refs queries, with a `console.warn` when the limit is hit (aggregate acknowledged incomplete in the log; no user id-free secrets logged — only the uuid). Conscious-cap comment added.

Verification for this round: `node --check` on `src/routes/partners.js` + `src/routes/partners.test.js`; `npm test` → **46/46 pass** (40 previous + 6 new), 0 fail.

## Polish round (re-review APPROVED, one minor)

- `src/routes/notifications.js` `GET /counts` is no longer currency-blind: select now includes `currency`; `total_amount` sums only `currency == 'UZS'` / `currency IS NULL` rows (commented, same rule as `periodAggregates`); `last_amounts` kept as-is (plain numbers, compat); NEW additive `last: [{amount, currency}]` (≤3 newest-first, `currency: null` for legacy rows or when the 019 column is absent). Pre-migration fallback unchanged — no 500 when the columns are missing (retry select without them; sums 0, `last` empty, counts correct). Contract section 2 above updated to the final shape.
- Known limitation (deliberate): `notifications.amount` is `bigint` while `operations.amount` is `numeric(18,2)` — a fractional operation amount would fail the typed insert and fall back to an amount-less notification row (badge counts stay correct, that entry just contributes no sum). Fix in a future migration only if fractional amounts become real (current API rounds operation amounts to integers, so this path is theoretical today).
- Verification: `node --check src/routes/notifications.js`; `npm test` → **46/46 pass**, 0 fail.

## Open items for the lead

- README.md API table not updated (outside this teammate's exclusive file set) — needs rows for `GET /api/notifications/counts`, `POST /api/notifications/read`, and the `period_from/period_to` params + `counterparty_deleted` field on `GET /api/partners`.
- Migration 019 must be applied in Supabase before the next backend deploy (graceful fallback exists, but badge amounts stay empty until applied).
- Product question (non-blocking): `period` sums mix currencies into flat integers per the agreed contract; fine while UZS dominates.

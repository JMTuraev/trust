# 2026-08-04 — Partner-card notification badges + realtime "in Trust" + wave-1 review fixes

Teammate: **notif-ui** (wave 2). Base: `6cc12d7`. Not committed (per instructions).

## Features

### 1. Partner-card notification badge (unread debt events)

- `mobile/lib/api.dart`
  - `_req` success path now passes the full response body into `ApiRes.body`
    (some endpoints carry payload outside `data`).
  - New: `Api.notifCounts()` (GET `/api/notifications/counts`, read from
    `body['counts']`) and `Api.readPartnerNotifs(partnerId)`
    (POST `/api/notifications/read`, idempotent).
- `mobile/lib/store.dart`
  - New state `notifCounts`: partnerId -> `{count, total, last:[newest-first], cur?}`.
  - Pure helpers (top-level, unit-tested): `mapNotifCounts`, `bumpNotifCounts`,
    `notifBadgeText` (9+ cap), `partnerInTrust`.
  - `hydrate()`: dead `Api.unreadCounts()` (msgUnread, chat disabled) is now
    gated behind `kChatEnabled` (compile-time removed); `Api.notifCounts()`
    polled instead every 15s. The currently open 1:1 partner is dropped from
    the mapped counts so the optimistically-cleared badge cannot flash back.
    A failed counts request keeps the last known map.
  - `vals()` clientRows + inRows: `notifOn`, `notifCountTxt`, `notifAmtOn`,
    `notifAmtOff`, `notifAmtTxt` (latest `last_amounts` entry formatted with
    `money()`, currency from FCM bump when known, UZS fallback).
- `mobile/lib/screens/home.dart`: count bubble (ink-on-bg, 2px bg ring,
  min-width 17, top-right of the avatar, "9+" cap) + latest-amount chip
  (card2 pill) in the balSub area, replacing the balSub line only while
  count > 0.
- `mobile/prototype/template.html`: same bubble + chip added to `clientRows`
  (1:1 parity).

### 2. Mark read on 1:1 open

- `store.openLedger_()` now zeroes the partner's local count optimistically and
  fires `Api.readPartnerNotifs(partnerId)` without awaiting; failures are
  silent (next poll corrects). Covers all 1:1 entry paths (partner rows,
  incoming links via `openIncoming`, notification routing, new-partner create).

### 3. Realtime feel on foreground FCM

- `mobile/lib/push.dart`: new `PushService.onForegroundData` callback, invoked
  from `FirebaseMessaging.onMessage` with the `data` payload (works for
  data-only messages too).
- `mobile/lib/main.dart`: wired to `store.pushArrived_`.
- `store.pushArrived_()`: if `partner_id` present and the type is a debt event
  (or unknown), bumps that partner's count/amount optimistically via
  `bumpNotifCounts` — badge visible within a second — then triggers
  `hydrate(full:false)` to reconcile. If that partner's 1:1 is already open,
  it re-fires mark-read instead of bumping (user is watching the ledger live).

### 4. "in Trust" badge realtime-correct

- `partnerInTrust(p)` = `counterparty_id != null && counterparty_deleted != true`,
  used by `_mapPartner` (`inTrust`). Home rows (`clientRows.inTrust`) and the
  1:1 header (`cInTrust`, client_screen.dart:839/1022) all derive from that
  single field, so a deleted counterparty drops the badge everywhere on the
  next poll. `onTrust` (link accepted — ledger flow semantics) intentionally
  unchanged.

## Reviewer fixes (wave-1)

5. **[major] Skeleton flicker** — `homeSkel` now requires
   `homePeriodOk != true` in addition to `homePeriodLoading`; skeleton shows
   only on the FIRST period load, silent 15s refreshes keep the list stable.
6. **[minor] Period end boundary** — `homePeriodRange` `endOf` returns
   next-day 00:00 exactly (exclusive, no −1ms); doc updated to `[from, to)`;
   `home_filter_test.dart` expectations updated (adjacency test:
   `yesterday.to == today.from`).
7. **[minor] Silent-refresh failure jump** — `loadHomePeriod_` failure no
   longer clears `homePeriod`/`homePeriodOk`; last successful sums are kept,
   cleared only by `setHomeFilter_`.
8. **[minor] template m.isTx placeholders** — store `txRow` now emits
   `align/txw/txbg/txbd/txrad` per the documented convention
   (`by=='me'` → flex-end / var(--card2) / none / 14 14 5 14; else mirrored).
9. **[nit] homeFilterReset nesting** — reset × now sits beside the
   `homeFilterTap` label inside a shared pill wrapper (handlers are siblings;
   HTML reset tap no longer also opens the dropdown). Flutter side already
   correct; visual unchanged.

## l10n

No new keys — the badge is numeric ("9+" cap) and the chip is a formatted
amount; both language-neutral.

## Verification

- `flutter analyze` — **No issues found**.
- `flutter test` — **70/70 passed** (59 existing + 11 new in
  `mobile/test/notif_counts_test.dart`: partnerInTrust derivation incl.
  `counterparty_deleted`, badge cap, server-counts mapping, optimistic
  bump/reset purity; `home_filter_test.dart` updated for the exclusive
  boundary).

## Polish round (lead, post-APPROVE)

- **Currency TODO resolved** — the counts endpoint now additionally returns
  per-partner `last: [{amount, currency}]` (≤3 newest-first, currency may be
  null; legacy `last_amounts` kept for compat). `mapNotifCounts` prefers the
  rich rows and resolves the chip currency as: server value when non-null →
  prev (FCM-bump) cur when it refers to the same partner + same newest
  amount → no cur (chip renders UZS). `hydrate` passes the previous
  `notifCounts` as `prev`. Covered by 5 new tests (server currency wins,
  null → UZS fallback, prev-cur preservation, prev-cur drop on amount change,
  legacy shape).
- **Optimistic-bump filter widened** — `pushArrived_` now checks a local
  `_badgeTypes` const set mirroring the server's `PARTNER_BADGE_TYPES`
  (src/routes/notifications.js): the debt-event types plus `rem` and
  `op_new`, which previously never bumped optimistically.

## Notes / TODOs

- Manual device smoke (push → badge within 1s) not run in this session — no
  device attached; covered by unit tests + code path review.

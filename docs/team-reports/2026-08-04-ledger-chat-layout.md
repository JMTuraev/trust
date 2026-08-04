# 2026-08-04 — Ledger feed chat-style layout (ledger-ui)

## What changed

Chat-style left/right alignment for the 1:1 partner ledger feed. Alignment rule
(viewer-relative value flow): OUTFLOW from viewer -> right ("sent"), INFLOW ->
left ("received"). Repay/settle align by the flow of the repayment itself,
regardless of who recorded it (creditor self-closing a debt still shows left).
Flip (second-side view) mirrors automatically via the `flipped` parameter.

## Files

- `mobile/lib/ledger/debt_ledger.dart`
  - `enum LedgerSide { left, right }` + pure `sideFor(entry, {flipped, refDirection, mine})` (alignment decision, fully unit-tested).
  - `DebtLedger.sideOf(entry, {flipped})` — resolves the referenced debt's direction for repay/settle from `entries`.
- `mobile/lib/screens/client_screen.dart`
  - New public `LedgerFeedBubble` widget: Align + FractionallySizedBox (80% width, 92% override for interactive cards), right = `Pal.card2` tint / no border / small bottom-right corner, left = `Pal.bg` + hairline border / small bottom-left corner. Unknown side -> legacy full-width card (safe fallback until the store supplies `side`).
  - `_feedCard` now renders inside the bubble; all internals preserved (status dot/label, chips, progress bar, overdue, cancel). Neutral fills (progress track, reviewing/edited chips) switch `field -> barbg` on tinted right bubbles so they stay visible.
- Tests: `mobile/test/debt_ledger_test.dart` (+9), new `mobile/test/ledger_bubble_test.dart` (7).

## Verification

- `flutter analyze`: No issues found.
- `flutter test`: 30/30 pass (10 existing ledger + 9 new alignment + 7 bubble widget + 4 ai_reveal).

## Pending (lead)

- store.dart (owned by another teammate this wave): feed map needs
  `'side': led.sideOf(e).name` per entry — until then feed renders full-width
  (unchanged look, no breakage).
- template.html m.isTx patch spec sent to lead (flex wrapper + per-side
  width/bg/border/radius template vars).

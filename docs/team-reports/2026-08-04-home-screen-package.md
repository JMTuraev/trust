# 2026-08-04 — Home (Qarz daftari) screen package

Teammate: home-dev. Scope: debt-ledger HOME screen — header rename, period filter,
overflow menu, powerful search, swipe bug fix, prototype parity. Plus two fold-ins
requested by lead for ledger-ui.

## Changes

### mobile/lib/l10n.dart
- Added to ALL 6 languages (uz/ru/en/es/fr/zh), one block at the end of each map:
  `homeTitle` (Qarz daftari / Долговая книга / Debt ledger / Libro de deudas /
  Carnet de dettes / 欠款账本), `fltCap` (DAVR / ПЕРИОД / ...), `menuXar`
  (Xarajatlar / Расходы / Expenses / Gastos / Dépenses / 支出).
- Period option labels REUSE the pre-existing canonical keys `fltToday`,
  `fltYesterday`, `fltWeek`, `fltMonth`, `fltAll`, `fltCustom` (uz:319-324) —
  my initially-added duplicates were removed after the first analyze run flagged
  `equal_keys_in_const_map` (coordination note from lead confirmed the same).

### mobile/lib/store.dart
- Top-level pure functions (unit-tested): `searchNorm` (lowercase + apostrophe
  unification ’ʻʼ‘`´→' + Uzbek Cyrillic→Latin transliteration incl. digraphs),
  `digitsOf`, `partnerMatch` (name/phone≥3-digits/amount-digits),
  `homePeriodRange` (device-local day boundaries, inclusive [fromMs,toMs],
  week starts Monday, custom swaps reversed ranges, 'all'→[0,0]).
- State: `homeFilter`('all' default), `homeFilterFrom/To`, `homeFilterOpen`,
  `homeMenuOpen`, `homePeriod` (partnerId→period sums), `homePeriodOk`,
  `homePeriodLoading`.
- `_partnersPeriodReq(from,to)`: GET `/api/partners?period_from=&period_to=`
  local helper following the `circles_data._circlesReq` precedent (api.dart is
  shared/owned elsewhere — deliberately untouched; auth header + 401 handling kept).
- `loadHomePeriod_()`: race-guarded via `_periodSeq`; graceful degradation — on
  error or `period`-less rows (old backend) sets `homePeriodOk=false` → full list
  + overall sums, no crash. Refreshed by `hydrate()` polling while filter active.
- `setHomeFilter_()`: resets `homeVis` to 6 (same as search), closes dropdowns.
- `_homeClients()`: single filter source for vals() list AND `homeMore`
  pagination (search matcher + `period.count > 0` when filter active).
- vals(): `fActive` gating; SOF BALANS block switches to period sums
  (owedToMe=Σto_me, owedByMe=Σby_me, net=Σ((to_me−repaid_to_me)−(by_me−repaid_by_me)));
  skeleton shown while period sums load (`homeSkel`); incoming link rows use the
  strong matcher too and are HIDDEN while a period filter is active (see decisions);
  new keys: homeTitle, homeFilter*, homeMenu* (full list below).
- Fold-in for ledger-ui (lead request): `'side': led.sideOf(e).name` added to the
  ledger feed map builder (led.entries.map).

### mobile/lib/screens/home.dart
- Header: TrustMark + 'Trust' replaced with `homeTitle` ("Qarz daftari"), BackBtn
  kept; right side order [filter ▾][archive][bell][⋮], 34px round monochrome
  buttons, 8px gaps.
- `_filterBtn` (funnel bars + active dot, bellDot pattern), `_dotsBtn` (⋮),
  `_menuCard`/`_fltItem` (client_screen menu style), dropdown overlay with DAVR
  caption + 6 options, ⋮ overlay with "Xarajatlar" → goXarajat_ path.
- Active filter chip under search: filled ink pill "label + ×" (tap=reopen
  dropdown, ×=reset to Jami).
- `_pickCustomRange`: `showDateRangePicker` themed monochrome (ink/bg palette,
  light/dark aware); result → `homeFilterCustom(fromMs, toMs)`; boundaries then
  normalized device-locally in `homePeriodRange`.
- Swipe bug fix: `_SwipeRow` drag handlers and the black action panel are
  disabled when `actLabel` is empty (incoming rows) — no more empty panel.

### mobile/prototype/template.html
- Home header rebuilt 1:1 with the Flutter header (back chevron, {{ homeTitle }},
  filter/arxiv/bell/⋮ 34px circles, gap 8), active-filter chip, filter dropdown +
  ⋮ menu overlays (barrier + card, z-index 40/41), all in the file's inline-style
  idiom with sc-if/sc-for/sc-camel-on-click.
- Fold-in for ledger-ui (lead request): m.isTx block — wrapper now
  `display:flex;justify-content:{{ m.align }}`, card uses `{{ m.txw }}/{{ m.txbd }}/
  {{ m.txrad }}/{{ m.txbg }}`; conventions documented in an HTML comment at the block.

### mobile/test/ (new)
- `home_filter_test.dart` — 12 tests: today/yesterday/week (incl. month/year
  crossings, Monday edge)/month (incl. 1st day)/custom (inclusive, swapped,
  single-day)/all/adjacency.
- `home_search_test.dart` — 22 tests: apostrophe variants, Cyrillic↔Latin both
  directions, phone ≥3-digit rule, amount digits (separators, negative, multi-
  currency), non-matches, empty query.

## Verification
- `flutter analyze` (D:\trust\mobile): **No issues found**.
- `flutter test`: **All 59 tests passed** — includes my 34 new tests plus
  existing ai_reveal, debt_ledger, and ledger-ui's ledger_bubble tests (green
  after the 'side' addition).
- Screens remain non-const at Root (only header row internals changed;
  HomeScreen instantiation untouched).

## Decisions / deviations
- Incoming link rows are hidden while a period filter is active: `/api/links`
  carries no period sums, and showing unfilterable rows would break the "activity
  in period" promise. Reset (chip ×) restores them. Flag if product wants otherwise.
- Period summary semantics: "Sizga qarz"/"Qarzingiz" show debt CREATED in the
  period (Σto_me / Σby_me); NET is the net balance change (repayments deducted).
- Amount search uses server balances (`srvBal`); rows without server balances
  match by name/phone only.
- Filter button active state = corner dot (bellDot pattern) rather than filled
  circle — identical in Flutter and prototype; the filled CHIP under search is
  the primary active indication per spec.
- `menuXar` ("Xarajatlar") added as a new key: existing `navXar` is singular
  ("Xarajat") and `hubXarSec` is an uppercase caption — neither fits a menu item.
- api.dart NOT modified (outside owned set): period request implemented as a
  store-local helper mirroring the documented `_circlesReq` precedent.

## Remaining TODOs / notes for lead
- Backend contract: when `GET /api/partners?period_from&period_to` ships, rows
  must carry `period:{to_me,by_me,repaid_to_me,repaid_by_me,count}`; until then
  the filter degrades gracefully (full list, overall sums).
- Consider adding period support to `/api/links` later so incoming rows can
  participate in the filter.
- l10n keys added: `homeTitle`, `fltCap`, `menuXar` (×6 languages). Reused:
  `fltToday`, `fltYesterday`, `fltWeek`, `fltMonth`, `fltAll`, `fltCustom`.

## Filter dropdown unification (teammate: dropdown-fix)

Follow-up task: the Xarajat screen's period-filter menu was a dimmed CENTERED
modal (`_scrimCard`) — product owner rejected it. Rewritten as an anchored
dropdown matching this package's home.dart idiom 1:1.

### mobile/lib/screens/xarajat.dart (only file changed)
- `_perMenuModal` (was ~xarajat.dart:406) rewritten: transparent full-screen
  tap-away barrier (NO `p.dim` scrim) + `Positioned(top: 52, right: 66)` card
  under the header trigger. Geometry: header top pad 10 + 38px row = 48, trigger
  bottom 46 → top 52 keeps home's ~6px gap; right 66 = 20 (header right pad) +
  38 (jurnal btn) + 8 (gap) aligns the card's right edge with the trigger pill.
- Card styling copied from home's `_menuCard`: minWidth 186, `p.bg`,
  `Border.all(p.bd2)`, radius 12, `BoxShadow(0,10,28,0x29000000)`, ClipRRect +
  IntrinsicWidth.
- New `_perItem` row helper in home's `_fltItem` style: 13.5px w500 label left,
  selected = w600 + 6px `p.ink` dot right (replaces the old ✓ mark), hairline
  (`p.hair2`) top separators between rows; first row borderless (this menu has
  no DAVR caption row — no new l10n keys, labels come from `xfPerOpts`).
- Logic untouched: `_perPick`, `xfPerOpts`/`xfPerKind`/`xfPerPick`/`xfPerCustom`,
  custom range still via system `showDateRangePicker`. `_scrimCard`, `_menuModal`
  (row ⋮), and all other modals untouched. store.dart untouched.

### mobile/prototype/template.html — NOT changed (finding)
- The template's Xarajat section (template.html:553-740) is the OLD
  Hisobot/Chat design: period selection is inline chips (`xarPeriods`,
  template.html:566-568); there is no period-menu modal and no folder-based
  xarajat screen in the prototype at all (`xfPer*` appears nowhere). Nothing to
  convert; the anchored-dropdown idiom already present at template.html:474-501
  (home menus) is what the Flutter code now mirrors. Prototype parity for the
  folder-based Xarajat screen is a pre-existing gap — flagged to lead.

### Verification
- `flutter analyze`: No issues found.
- `flutter test`: All 75 tests passed.

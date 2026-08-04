# 2026-08-04 — Archive screen: title moved into header row

## Task

User report (Uzbek): on the Archive screen the "Arxiv" title was rendered below the
back button instead of in the header row. Fix requested.

## Change

- `mobile/lib/screens/archive.dart` — back button and "Arxiv" title merged into a
  single header Row (BackBtn + 8px gap + Expanded title, size 21, w700, ls -0.3,
  maxLines 1 + ellipsis), matching the header pattern of `home.dart` /
  `support_chat.dart`. Subtitle stays below with `fromLTRB(24, 8, 24, 8)`.

Note: `mobile/prototype/template.html` has no dedicated archive-screen section
(only the header archive button on home), so pixel-parity does not apply here;
sibling-screen consistency is the standard used.

## Verification

- `flutter analyze` — No issues found.
- `flutter test` — all 75 tests passed.
- Reviewer agent — APPROVE (layout valid, no overflow risk, closeArch behavior
  unchanged, style matches home.dart header).

## Follow-up (not done)

- `mobile/lib/screens/rejected_links.dart` has the identical old pattern
  (title on its own row below the back button) — flagged as a separate task.

# Trust (Oldi-Berdi) — Project Guide

Ikki tomonlama tasdiqli hisob-kitob ilovasi. The user communicates in **Uzbek — always respond to the user in Uzbek.** Code, comments, and commit messages in English.

## Layout

- `src/` — Node.js + Express backend (ESM, Node >= 18). Deploy: Render (`render.yaml`), Docker.
- `mobile/` — Flutter app (Android + iOS). UI must stay **1:1 with `mobile/prototype/template.html`**.
- `supabase/` — PostgreSQL migrations (Supabase: DB + Auth). OTP: devsms.uz for +998, Supabase for others. JWT.
- `docs/` — `play-store-checklist.md`, privacy policy. `store-screenshots/` — release assets.

## Commands

- Backend (repo root): `npm run dev`. Syntax check: `node --check <file>`.
- Mobile (inside `mobile/`): `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build appbundle`.
- iOS builds are impossible on this Windows machine — prepare CI (Codemagic / GitHub Actions) instead.

## Team orchestration

Agent teams is enabled via `.claude/settings.json`. The session the user opens is the **lead** (bosh sessiya).

Lead rules:

1. For any non-trivial task: write a short plan → split into independent workstreams → spawn teammates in parallel, one per workstream, using the roles in `.claude/agents/` (flutter-dev, backend-dev, reviewer, qa-tester, release-manager, researcher).
2. Delegate implementation to teammates. The lead coordinates, reviews, and integrates; it only edits files directly for trivial fixes.
3. At most 4 teammates at once. Give each a precise task with acceptance criteria and an exclusive set of files — no two teammates edit the same files.
4. Teammates: use subagents for parallelizable subtasks; report back with changes made + how they were verified.
5. Quality gate before any task is "done": `flutter analyze` + `flutter test` pass (mobile), `node --check` passes on changed backend files, and a reviewer has approved the diff.
6. After each completed task, write a short report to `docs/team-reports/<date>-<task>.md`.

## Hard rules

- Never print, log, commit, or copy secrets from `.env`. Only `.env.example` may be edited.
- No destructive git commands (`push --force`, `reset --hard`, `branch -D`) without explicit user confirmation.
- Mobile UI: pixel-parity with the prototype is a product requirement — read the relevant prototype section before changing UI.
- Database changes only as NEW files in `supabase/migrations/` — never edit existing migrations.

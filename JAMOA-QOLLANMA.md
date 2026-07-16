# Trust — Agent Teams qo'llanmasi

Tizim: **bosh sessiya (lead) → teammate'lar (sub-sessiyalar) → subagentlar**. Hammasi shu papkada sozlangan, hech qanday qo'shimcha o'rnatish kerak emas.

## Ishga tushirish

1. Windows Terminal oching: `cd D:\trust` → `claude`
2. Agent teams avtomatik yoqiladi (`.claude/settings.json` orqali).
3. Topshiriqni oddiy tilda yozing — lead o'zi jamoa tuzadi, ishni bo'lib beradi, natijalarni tekshirib birlashtiradi.

## Birinchi buyruq namunalari

Nusxalab ishlatishingiz mumkin:

- `Jamoa tuz: flutter-dev Circles UI ekranini prototip bo'yicha qursin (claude-code-prompt-circles-ui.md dagi talab), backend-dev kerakli API endpointlarni yozsin, reviewer ikkalasining diffini tekshirsin. Parallel ishlashsin.`
- `Jamoa bilan butun kodbazani audit qiling: xavfsizlik, xatolar, prototipga moslik, API-README mosligi. Natijani docs/team-reports/ ga yozinglar.`
- `Play Store relizga tayyorlaymiz: release-manager docs/play-store-checklist.md bo'yicha yursin, qa-tester regressiya testlarini o'tkazsin, reviewer yakuniy audit qilsin.`

## Boshqarish

- Teammate'lar paneli: **↑/↓** — tanlash, **Enter** — sessiyasiga kirish va xabar yozish, **x** — to'xtatish.
- Windows Terminalda in-process rejim ishlaydi (split-pane uchun tmux kerak, Windowsda yo'q — kerak emas ham).
- Teammate'lar loyihaning `CLAUDE.md` va `.claude/agents/` rollarini avtomatik oladi, lekin lead suhbatini ko'rmaydi — shuning uchun lead ularga to'liq kontekst beradi.

## Rollar (`.claude/agents/`)

flutter-dev · backend-dev · reviewer · qa-tester · release-manager · researcher. Lead shularni teammate sifatida ishga tushiradi; har biri katta ishda o'z subagentlarini yaratadi (3-daraja).

## Foydali

- Kuchliroq model bilan: `claude --model opus`
- Ruxsat so'rashlarini kamaytirish: sessiya ichida **Shift+Tab** (auto-accept rejimi).
- Chrome bilan test (ixtiyoriy, bir marta): `claude mcp add chrome-devtools -- npx chrome-devtools-mcp@latest`. Flutter webni ko'rish: `mobile/` ichida `flutter run -d chrome`.
- iOS build Windowsda chiqmaydi — release-manager CI (Codemagic / GitHub Actions) yo'riqnomasini tayyorlab beradi.
- Bir vaqtda 4 tadan ortiq teammate tavsiya etilmaydi (rate limit); lead shunga sozlangan.
- Sessiya tarixiga qaytish: `claude --resume` (ro'yxatdan tanlaysiz).

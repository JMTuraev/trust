# 2026-08-04 — UI polish: headerlar, menyu qatorlari, l10n va "..." tozalash

Bosh sessiya (lead) + 4 teammate (ledger-ui, hub-ui, l10n-sweep, rivals) + reviewer.

## Foydalanuvchi so'rovlari va bajarilishi

| So'rov | Holat | Qayerda |
|---|---|---|
| Qarz kartasida «Rad» bosilsa kontragentga ogohlantirish boradimi — logikani tekshirish | ✅ Tekshirildi: boradi | `src/routes/debts.js:251-268` — `debt_reject` in-app bildirishnoma + push (`pushToUser`); istisno: kontragent `notif_enabled=false` qilgan bo'lsa faqat daftar holati o'zgaradi |
| Headerdagi «+» o'rniga settings/more ikonka, dropdownga bog'liqligi ko'rinsin | ✅ | `client_screen.dart` — 34×34 doira ichida `Icons.more_horiz`; kontekst-menyu endi ikonka ostidan (top:56, right:16) ochiladi |
| Qarz daftar headeridagi ⋮ menyu va «Xarajatlar» bandini olib tashlash | ✅ | `home.dart` — ⋮ tugma + overlay o'chirildi; `store.dart` homeMenu* handlerlari, `l10n.dart` `menuXar` kaliti tozalandi |
| Hamma «...» bilan kesilgan yozuvlarni to'liq ko'rinadigan qilish (moliyaviy qoida) | ✅ | 10+ faylda: summalar `FittedBox(scaleDown)`, nom/sarlavhalar `maxLines:2` wrap. Qoida global xotirada |
| Arxivda «Qaytarish» → «Arxivdan chiqarish» | ✅ | `l10n.dart` `restoreBtn` 6 tilda yangilandi |
| Yozuvlar hard emas — lokalizatsiya, global xotirada saqlash | ✅ | Audit: profil.dart'ning 12 ta yetishmagan kaliti + debt_ledger'ning 4 ta hardcode xabari 6 tilga ko'chirildi; qoida `trust-l10n-no-truncation.md` xotirasida |
| Menyular bir qatorda bittadan (boyitib boramiz) | ✅ | `home_hub.dart` — Oldi-berdi to'liq qator; naqsh izohlangan (Ijarachi/To'yxona shu tartibda qo'shiladi) |
| AI menyuni asosiy headerga AI ikonka bilan chiqarish | ✅ | `home_hub.dart` `_aiBtn` (38×38, olmos glifi, `kAiEnabled`, `goAi`); AI karta o'chirildi |
| Raqobatchilarda qanaqa xizmatlar bor — aniqlash | ✅ | `docs/team-reports/2026-08-04-rivals-research.md` |
| Obuna modeli (Xarajat $5, Qarz $8, Ijarachi $13, To'yxona $24; 5 yozuv bepul 0/5; qulf) | 📝 Rejaga yozildi | `trust-subscriptions-roadmap.md` xotirasi — implementatsiya keyingi bosqich |

## Texnik o'zgarishlar

- **debt_ledger.dart** endi sof domen qatlami: matn o'rniga semantik kodlar (`giveDisabledCode` va h.k.), lokalizatsiya display-saytda (`store.dart` `lfb()` — bayt-aynan uz fallback bilan crash-safe).
- **store.dart**: o'lik hubAi* vals bloki olib tashlandi; `goAi`/`aiMsgs` oqimi saqlangan.
- **l10n.dart**: +16 yangi kalit (×6 til), −5 o'lik kalit; `restoreBtn` yangilandi.
- **Prototip parity**: `template.html` (⋮ menyu o'chdi, ⋯ glif, 2-qator wrap, menyu ankeri, «Arxivdan chiqarish») va `bosh-ekran.dc.html` (3 freymda AI header ikonka, Oldi-berdi span-2, TRUST AI karta o'chdi).
- **Skeleton/empty holatlar** yangi bir-qator geometriyaga moslandi (yuklanishda sakrash yo'q).

## Sifat darvozasi

- `flutter analyze` — No issues found.
- `flutter test` — 75/75 o'tdi (debt_ledger_test semantik API'ga yangilandi).
- Reviewer xulosasi: **APPROVE** (bloker yo'q). l10n pariteti dasturiy tekshirildi — har 6 xaritada aynan 504 kalit; `lfb` fallback'lari uz qiymatlariga bayt-mos; dangling reference nol; prototiplar strukturaviy sog'lom.
- Reviewer topgan 4 ta past-darajali topilma lead tomonidan tuzatildi (analyze/test qayta yashil):
  1. `_AnimNum`/`AiCountUp` chaqiruv joylari (xarajat.dart ×3, ai_blocks.dart ×1) `Flexible` bilan o'raldi — FittedBox scaleDown endi chegaralangan slotda real ishlaydi;
  2. debt_ledger.dart'dagi 2 ta o'zbekcha `StateError` dev-xabari inglizchaga o'tkazildi (sof domen matn-neytral);
  3. debt_ledger_test 5-testga `closeDisabledCode()` ning `noActive`/`pendingWait`/`null` shoxlari uchun assertlar qo'shildi;
  4. template.html 2-qator wrap'lari `-webkit-line-clamp:2`ga o'tkazildi (glif o'rtasidan kesilmasin).
- Qayd etilgan, ataylab qoldirilgan: Flutter `Icons.more_horiz` vs prototipdagi qo'lda chizilgan 3 nuqta (vizual yaqin, 1:1 emas — PO qaroriga havola); home filtr dropdown ankeri sarlavha 2 qatorga o'ssa statik qoladi (hozirgi 6 tilda sarlavhalar bir qatorli); `ledgerCantTake` kaliti API simmetriyasi uchun qo'shilgan, UI iste'molchisi «Qarz olish» tugmasi qaytsa ulanadi.

## Ochiq qoldi / keyingi qadamlar

- Obuna modeli implementatsiyasi (per-menyu IAP, 0/5 hisoblagich, qulf kartalari) — alohida loyiha bosqichi.
- Ijarachi va To'yxona modullari MVP dizayni — tadqiqot hisobotidagi tavsiyalar asosida.
- template.html'dagi PDF-mock blokida nowrap qoldirildi (A4 hujjat maketi, ekran emas — ataylab).

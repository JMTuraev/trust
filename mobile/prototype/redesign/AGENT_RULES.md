# Redizayn agentlari uchun umumiy qoidalar

Loyiha: /home/claude/trust/mobile (Flutter, Trustbook). Bu BULUTDAGI nusxa — Flutter SDK YO'Q,
`flutter analyze` ishlamaydi. Shuning uchun kod KOMPILYATSIYA XAVFSIZ yozilsin:
- Har bir ishlatilgan klass/parametr `lib/ui.dart` va `lib/theme.dart` da HAQIQATAN bor bo'lsin — avval ularni to'liq o'qing.
- Material ikonkalar faqat mavjud nomlar: `Icons.chevron_left_rounded`, `Icons.notifications_none_rounded`,
  `Icons.auto_awesome_rounded`, `Icons.search_rounded`, `Icons.check_rounded`, `Icons.close_rounded`,
  `Icons.more_horiz_rounded`, `Icons.send_rounded`, `Icons.headset_mic_rounded`, `Icons.lock_outline_rounded`,
  `Icons.ios_share_rounded`, `Icons.calendar_today_rounded`, `Icons.schedule_rounded`, `Icons.verified_user_outlined`,
  `Icons.archive_outlined`, `Icons.description_outlined`, `Icons.backspace_outlined`, `Icons.language_rounded`,
  `Icons.dark_mode_outlined`, `Icons.smartphone_rounded`, `Icons.workspace_premium_rounded`, `Icons.help_outline_rounded`,
  `Icons.logout_rounded`, `Icons.key_rounded`, `Icons.payments_outlined`, `Icons.apartment_rounded`, `Icons.refresh_rounded`,
  `Icons.error_outline_rounded`, `Icons.wb_sunny_outlined`, `Icons.north_east_rounded`, `Icons.south_west_rounded`,
  `Icons.account_balance_wallet_outlined`, `Icons.favorite_border_rounded`, `Icons.directions_car_outlined`,
  `Icons.restaurant_outlined`, `Icons.home_outlined`, `Icons.shopping_bag_outlined`, `Icons.check_circle_outline_rounded`,
  `Icons.add_rounded`, `Icons.edit_outlined`, `Icons.delete_outline_rounded`, `Icons.chevron_right_rounded`,
  `Icons.arrow_forward_rounded`, `Icons.folder_outlined`, `Icons.person_outline_rounded`, `Icons.people_outline_rounded`,
  `Icons.picture_as_pdf_outlined`, `Icons.copy_rounded`, `Icons.info_outline_rounded`, `Icons.warning_amber_rounded`,
  `Icons.local_fire_department_outlined`, `Icons.star_rounded`, `Icons.keyboard_arrow_down_rounded`, `Icons.keyboard_arrow_up_rounded`,
  `Icons.arrow_back_rounded`, `Icons.remove_rounded`, `Icons.event_available_outlined`, `Icons.event_busy_outlined`.
  Shubhali nomlarni ishlatmang.
- `Color.withValues(alpha: x)` ishlatiladi (`withOpacity` EMAS).
- `const` konstruktorlarga faqat const qiymatlar; `Tx` const bo'la oladi (rang const bo'lsa), `curPal()` const emas.
- Null-safety: `v['x'] as String?` kabi castlarga ehtiyot bo'ling; eski koddagi cast'larni o'zgartirmang.

## TEGILMAYDI
`lib/store.dart`, `lib/api.dart`, `lib/l10n.dart`, `lib/*_l10n.dart`, `lib/*_data.dart`, `lib/iap.dart`, `lib/push.dart`,
`lib/secure.dart`, `lib/flags.dart`, `lib/main.dart` (men o'zgartirdim), `lib/ui.dart`, `lib/theme.dart` (o'zgartirish
kerak bo'lsa — hisobotda ayting, o'zingiz tegmang; yangi kichik yordamchi widgetlarni O'Z faylingizda `_Private` sifatida yozing).

## SAQLANADI (mantiq)
- Ekran ichidagi HAMMA `store.vals()` kalitlari (`v['goHub']`, `v['openPaywall']`, …) va `store.*` chaqiruvlari — bir xil hodisa bir xil callback'ni chaqiradi.
- Barcha matnlar `store.L()['...']` lug'atidan (6 til!). Yangi matn kerak bo'lsa: dizayndagi o'zbekcha matnga ENG YAQIN mavjud kalitni ishlating; topilmasa faqat shu holatda qisqa o'zbekcha literal + `// TODO l10n` izohi.
- Modul obunalari mantig'i (modSubs / qulf / narx / paywall), pending bannerlar, skeleton/bo'sh holatlar, back-tugma xatti-harakati, `ValueKey`/`Key` lar (testlar ularga tayanadi).
- `test/` dagi tegishli testlarni o'qing: testlar `find.text` / `find.byKey` bilan nimani izlashini bilib, o'sha elementlarni saqlang. Test faqat vizual o'lchamni (masalan karta balandligi) tekshirsa — testni yangi qiymatga moslang (fayl nomini hisobotda ayting).

## DIZAYN
Manba: prototype/redesign/DESIGN_SPEC.md (to'liq o'qing — §1 tokenlar, §2 shrift, §4 primitivlar, §5 sizning ekraningiz).
Umumiy qoidalar:
- Fon: ekran `ScreenBg` ichida keladi (main.dart) — o'zingiz fon rangi bermang; kartalar `GlassCard`.
- Header: `ScreenHeader(title, subtitle, onBack, trailing)`; header ustida qo'shimcha bo'shliq shart emas (SafeArea bor).
- Tugmalar: asosiy → `GradientBtn`, mint/coral → `SolidBtn.mint/.coral`, ikkilamchi → `GlassBtn`, matnli → `TextBtn`, ikonka → `GlassIconBtn`.
- Summalar → `Tx(..., tab: true)` (Space Grotesk avtomatik). Sarlavha 20+/600 → avtomatik Inter Tight.
- Ranglar: `p.mint` (sizga qarz / kirim), `p.coral` (siz qarzdorsiz / chiqim), `p.amber` (kutilmoqda), `p.cyan` (AI/havola), `p.violet`.
  Matn darajalari: `p.ink`, `p.t1` (80%), `p.t2` (60%), `p.t3`, `p.t4` (50%, caption), `p.t5` (placeholder), `p.t6`.
- Eski `p.card2/p.field/p.bd/p.hair` ham ishlaydi (shisha ranglariga o'tkazilgan) — lekin yangi kodda `p.glass/p.glass2/p.glassBd/p.hairline` ishlating.
- Radius: karta 24, qator 20, ikonka qutisi 14, tugma/chip 999.
- Pul summasi hech qachon «…» bilan kesilmaydi (FittedBox / kichraytirish).
- Eski qo'lda chizilgan glif-painterlar (`_Glyph`, `CustomPainter` ikonkalar) o'rniga Material ikonkalar.

## HISOBOT
Yakunda: o'zgargan fayllar ro'yxati, saqlangan store kalitlari, yangilangan testlar, ehtimoliy kompilyatsiya xavfi bo'lgan joylar (2–3 jumla).

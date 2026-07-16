# Claude Code prompt — Trust "Circles" feature (UI only)

> Bu Claude Code uchun tayyor prompt. Trust loyihasi ildizida Claude Code'ni ochib, quyidagini paste qiling.
> Bosqich: faqat UI + mock ma'lumot (backend keyin). Dizayn 1:1 manba — `Trust_Circles_prototip.html`.

---

## Goal

Trust (Flutter + Node/Express + Supabase) ilovasida **Moliya (Finance) tab'ini yangi "Circles" bo'limi bilan almashtir**. Circles = guruhli navbatli jamg'arma (ROSCA / "gap"), globallashtirilgan. Bu vazifa **faqat UI**, **in-memory mock data** bilan — screenlar qurilmada ko'rinsin. Backend keyingi vazifada qilinadi va shu UI'ga ulanadi.

**Circle nima:** guruh a'zolari har round bir xil summa qo'shadi; har round bitta a'zo butun pulni oladi; navbat hammaga tegguncha aylanadi. Har to'lov Trust'ning ikki tomonlama tasdig'i bilan (to'lovchi "to'ladim" belgilaydi → qabul qiluvchi "oldim" tasdiqlaydi → round o'chirilmas dalil sifatida yopiladi) — mavjud `operations` modeli ruhida.

Global mahsulot: matnlar inglizcha, summa hozircha `$` bilan.

## Read first (konvensiyalarga aniq mos bo'l)

- **Piksel-daraja dizayn manbasi (13 ta screen, light + dark):** `Trust_Circles_prototip.html` (repo ildizi). Brauzerda och; har bir yorliqli frame = bitta screen/holat, 1:1 takrorla.
- **Arxitektura va uslub:**
  - `mobile/lib/main.dart` — `Root` screen router + z-tartibli `Stack`.
  - `mobile/lib/store.dart` — holat modeli: `store.S` (map), `store.set({...})`, `store.vals()`; asosiy screen `S['screen']` orqali (`isHome`/`isMoliya`/`isXarajat`/`isProfil` + `goHome`/`goMoliya`/...); overlay bayroqlari (`clientOpen`, `notifOpen`, `sheetOpen`, `npOpen`, `receiptOpen`, ...).
  - `mobile/lib/theme.dart` — `Pal`, `pal(dark)`, `curPal()`.
  - `mobile/lib/ui.dart` — umumiy widgetlar (pastda).
  - `mobile/lib/l10n.dart` — 6 til map'i.
- **Kod uslubini ko'chiradigan mavjud screenlar:** `screens/home.dart` (list + FAB + qidiruv), `screens/xarajat.dart`, `screens/moliya.dart` (almashtirilayotgan), `screens/tab_bar.dart`, `screens/notifs.dart`, `screens/client_screen.dart`, `screens/new_tx_sheet.dart`, `screens/new_partner_sheet.dart`.
- **Mahsulot konteksti (ixtiyoriy):** `XOTIRA-ovoz-va-kategoriya.md`, `TAVSIYA-texnologiya.md`, `README.md`.

## Design-system rules (chetga chiqma)

- `ui.dart` dagi mavjud widgetlarni QAYTA ISHLAT, yangisini yasama: `Tx`, `Cap`, `Tap`, `InkBtn`, `GhostBtn`, `TrustAvatar`, `SheetShell`, `CodeBoxes`, `BackChevron`, `ChevRight`, `StoreField`, `Skel`.
- Ranglar FAQAT `Pal` dan: `final p = curPal();` → `p.ink`, `p.t1/t2/t3`, `p.hair/hair2`, `p.field`, `p.bd`, `p.green`, `p.red`. Hardcoded hex YO'Q. Light va dark ikkalasi ham avtomatik ishlashi shart (`Pal` allaqachon almashadi).
- Prototipdagi spacing, hairline chiziqlar, CAP yorliqlar (`Cap`), 34px/700 hero raqamlar, pill `InkBtn`, pastki home indikator, avatar initsial tintlari (`TrustAvatar`) — barchasini moslashtir.
- Shrift butun ilovada Inter (GoogleFonts) — mavjud matn helperlaridan foydalan.

## Navigation wiring

Ilovada bitta asosiy-screen tanlagichi + stacked overlaylar bor. Circles'ni Moliya integratsiya qilingan tarzda ula.

**1. Asosiy tab slot — Moliya o'rniga Circles:**
- `store.dart`: screen qiymatlari `'home' | 'xarajat' | 'moliya' | 'profil'`. `'moliya'` → `'circles'`. `vals()` da `isCircles` (eski `isMoliya`) va `goCircles` (eski `goMoliya`, `set({'screen':'circles', ...})`) chiqar. Accent o'zgaruvchini saqla (`cMol` → `cCircle` deb qayta nomla yoki `cMol` qoldir).
- `screens/tab_bar.dart`: 3-tab hozir `v['goMoliya']`, `v['cMol']`, `L['navFin']` va ustun-diagramma ikonkasidan foydalanadi. Buni `v['goCircles']`, `L['navCircle']` va **aylanma (circular arrow / rotation)** ikonkasiga o'zgartir (prototip nav ikonkasiga qara). Qolgan 3 tab tegilmaydi.
- `main.dart` `Root`: `if (v['isMoliya']==true) ... MoliyaScreen()` → `CirclesScreen()`. Import'ni almashtir. `moliya.dart` ni routerdan chiqar (faylни referens uchun qoldir; uning "reminders" qismini Circle eslatma/bildirishnomalarga ko'chir).

**2. To'liq-ekran overlaylar** (`clientOpen`/`notifOpen` andozasi): `vals()` ga bayroq + open/close callback qo'sh, `main.dart` Stack'ida z-tartibga rioya qilib `Positioned.fill(child: Container(color: p.bg, child: ...))` bilan render qil:
- `circleOpen` + `circleId` → `CircleDetailScreen` ("boshqa a'zo navbati", "sizning navbatingiz" va "yakunlangan" holatlarini boshqaradi).
- `circleCreateOpen` → `CircleCreateScreen`.
- `circleHistoryOpen` → `CircleHistoryScreen`.
- `circleManageOpen` → `CircleManageScreen`.
- `circleJoinOpen` (+ invite payload) → `CircleJoinScreen`.
- go-funksiyalar: `openCircle(id)`, `closeCircle`, `openCircleCreate`, `openCircleHistory`, `openCircleManage`, `openCircleJoin` — har biri `set({...})`.

**3. Bottom sheetlar** (`sheetOpen`/`npOpen` andozasi, `SheetShell` ustida): `circlePayOpen`, `circleConfirmOpen`, `circleInviteOpen` → `CirclePaySheet`, `CircleConfirmSheet`, `CircleInviteSheet`.

## Screens (prototip frame'larini 1:1 takrorla)

`mobile/lib/screens/` ostida yarat:

1. **`circles.dart` → `CirclesScreen`** (asosiy tab). Sarlavha "Circles", xulosa qatori ("3 active · you're saving $150 / mo"), list qatorlari (nom, "8 members · $50 / mo", pool "$400", "round 3 of 8", avatar stack, navbat statusi — "Your turn next" yashil). Qora FAB (+) pastda-o'ngда → `openCircleCreate`. Qatorga bosish → `openCircle(id)`. Circle bo'lmasa — **empty state / "What is a Circle?"** (illyustratsiya + 3 qadam + proof qatori + "Create your first Circle"), prototip frame "Circle nima?".
2. **`circle_detail.dart` → `CircleDetailScreen`**. Header (orqaga + nom + a'zolar soni), hero ("POOL THIS ROUND" cap + $ + "round 3 of 8 · collected by …"), recipient karta, ikki-tomonlama banner ("3 of 8 paid · Maya confirms receipt …"), MEMBERS ro'yxati per-a'zo status bilan (`✓ Paid · got round 1` / `Pending · round 5` / `This round`), pastda `InkBtn`. Ma'lumotga qarab ikki variant: (a) boshqa a'zo navbati → tugma "Mark my payment · $50" → `circlePayOpen`; (b) **sizning navbatingiz** → yashil "You receive this round" hero, tugma "Confirm receipt · $600" → `circleConfirmOpen`, ikkilamchi "Remind unpaid (n)". `status == complete` bo'lsa — **yakunlangan** layout (yashil check, xulosa grid: total pooled / rounds / members / period, "Everyone got their turn" ro'yxati, "Start a new Circle").
3. **`circle_create.dart` → `CircleCreateScreen`**. Header (✕ / "New Circle" / Create), bo'limlar: Name (`StoreField`), Contribution (summa field + Weekly/Monthly segmented), Members (avatar stack + dashed add + soni), Payout order (In turn / Random / I pick segmented + tartib preview), xulosa karta ("$50 × 8 = $400 each round · 8 rounds · you receive in round 3"), pastda `InkBtn` "Create Circle".
4. **`circle_history.dart` → `CircleHistoryScreen`**. Header, roundlarning vertikal timeline'i (done = yashil nuqta + "✓ confirmed", current = ink nuqta + "in progress · 3 of 8 paid", upcoming = kulrang nuqta).
5. **`circle_manage.dart` → `CircleManageScreen`**. Sozlama qatorlari (Name / Contribution / Payout order / Members / Reminders, har biri `ChevRight` bilan), izoh "Only you can edit; amount/order changes need every member's approval", va qizil "Close Circle" qatori.
6. **`circle_join.dart` → `CircleJoinScreen`**. Taklif preview: circle ikonka, nom, "Invited by …", 2×2 stat grid (Members / Contribution / Duration / Your turn), 3-qadam how-it-works, pastda "Join Circle" + "Decline".
7. **`circle_pay_sheet.dart` → `CirclePaySheet`** (`SheetShell`). "Pay this round", subtitle, katta summa, "to <recipient>", ikki-tomonlama proof izoh, `InkBtn` "Confirm payment · $50", link "Cancel".
8. **`circle_confirm_sheet.dart` → `CircleConfirmSheet`** (`SheetShell`). "Confirm you received the pool", katta yashil summa, "from all 8 members", izoh (tasdiqlash round'ni yopadi va to'lovlarni dalil sifatida tekshiradi), `InkBtn` "Confirm receipt of $400". (Ixtiyoriy: mavjud operations oqimiga mos aniq tasdiq kodi kerak bo'lsa `CodeBoxes` ishlat.)
9. **`circle_invite_sheet.dart` → `CircleInviteSheet`** (`SheetShell`). Qidiruv field, "Share invite link" qatori, kontakt qatorlari Add / ✓ Added bilan, `InkBtn` "Add N members".
10. **Circle bildirishnomalari:** `screens/notifs.dart` (yoki uning ma'lumoti) ni circle hodisalari bilan kengaytir — "Your turn is next in Work Circle", "Diego paid $50", "Payment due", "Maya confirmed receipt — round 2 closed" — mavjud notif qator uslubi + unread nuqta bilan.

## Localization (`l10n.dart`)

6 map bor: `lUz, lRu, lEn, lEs, lFr, lZh`. HAR BIR map uchun:
- Moliya nav kalitini almashtir: `'navCircle'` qo'sh (uz "Kassa" yoki "Doira", ru "Круг", en "Circles", es "Círculos", fr "Cercles", zh "互助圈" — tabiiy ekvivalent tanla; `'navFin'` olib tashla yoki ishlatilmasin).
- Barcha Circle UI matnlarini qo'sh (sarlavhalar, cap'lar, tugmalar, statuslar, "What is a Circle?" matni, a'zo statuslari, create-forma yorliqlari). Inglizcha kanonik matnlar `Trust_Circles_prototip.html` dan. Qolgan 5 tilга to'g'ri tarjima ber. Kalitlar namespaced: `circlesTitle`, `circlePool`, `circleRoundOf`, `circleMembers`, `circlePayCta`, `circleConfirmCta`, `circleWhatIs1..3`, va h.k.
- Moliya-only kalitlarini (`finTitle`, `turnover`, `mlnHint`, `remindersCap`, `remind`) endi ishlatilmasa olib tashla (reminders qayta ishlatsa qoldir).

## Mock data (backend hali yo'q)

`mobile/lib/circles_data.dart` yarat — oddiy Dart modellar + in-memory repository, UI qurilmada renderlansin va keyin backend shu interfeys orqasiga tushsin:
- Modellar: `Circle { id, name, amount, currency, frequency, payoutOrder, status, members[], rounds[], currentRoundIndex }`, `CircleMember { id, name, initials, tint, payoutPosition, isYou }`, `CircleRound { index, recipientId, dueDate, status, receiptConfirmed }`, `CirclePayment { roundIndex, memberId, paid, confirmedByRecipient }`.
- `class CirclesRepo` (singleton): `List<Circle> all()`, `Circle byId(id)`, va mutatsiya stub'lari (`markPaid`, `confirmReceipt`, `createCircle`, `join`, `invite`) — in-memory holatni yangilaydi va `store` ni refresh qiladi. Prototip namunasi bilan seed qil: "Family Fund" (8 a'zo, $50/mo, round 3/8), "Work Circle" (6, $100/mo, round 2/6, sizning navbatingiz keyingi), "Trip 2026" (5, $80/mo, yakunlangan). Yagona data manbai — keyin real API'ga almashtirishga tayyor.

## Acceptance

- `cd mobile && flutter analyze` — yangi xatosiz o'tadi; ilova build bo'ladi va ishga tushadi.
- Circles tab pastki navda Finance'ni almashtiradi; list → detail (ikki variant) → pay/confirm sheet, create, history, manage, join, completed va empty state — hammasi mock data bilan renderlanadi va navigatsiya ishlaydi.
- Light va dark ikkalasi to'g'ri (mavjud dark sozlamasi orqali).
- Olib tashlangan Moliya route'iga osilib qolgan referens build'ni buzmaydi.
- Emulyator/qurilmada ishga tushir va hot-reload qil — ko'rib chiqamiz. Prototipda moslay olmagan joy bo'lsa xabar ber.

## Constraints

- Faqat UI + mock data — backend/Supabase/API'ni HALI qilma.
- Mavjud Partners/Expenses/Profile funksiyalarini buzma.
- `moliya.dart` ni daraxtda qoldir (faqat route'siz) — o'chirishni keyin tasdiqlaymiz.
- Kichik, ko'rib chiqiladigan commit'lar bilan ishla (data+nav → list+empty → detail+sheets → create/history/manage/join → l10n).

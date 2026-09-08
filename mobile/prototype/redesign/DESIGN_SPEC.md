# Trustbook v2 dizayn — "dark glass + gradient" (Claude Design, 2026-09-07)

Manba: https://claude.ai/design/p/7dd4a74b-5077-4a7c-be60-9aeee191a55f (Trustbook.dc.html).
Bu fayl — Flutter'ga ko'chirish uchun TO'LIQ spetsifikatsiya. Dizayn 390×844 (iPhone) uchun
chizilgan; Flutter'da o'lchamlar dp sifatida 1:1 olinadi, kengliklar esa `Expanded`/`double.infinity`.

## 1. Tokenlar (`lib/theme.dart` — `Pal` + `Tb`)

| Token | Qiymat | Ma'no |
|---|---|---|
| bg | #07080D | ekran foni |
| surface | #151823 | qattiq (shaffofsiz) karta — daftar qatorlari |
| surface2 | #12141C | avatar ichi, pastki panel (85% alpha) |
| sheetBg | #0F1119 (95%) | bottom sheet |
| glass | white 6% | shisha karta foni |
| glass2 | white 8% | ikkilamchi tugma / tanlanmagan chip |
| glassBd | white 10% | shisha chegarasi |
| hairline | white 6% | ro'yxat ajratgichi |
| ink | #FFFFFF | asosiy matn |
| t1 | white 80% | ikkilamchi matn (kuchli) |
| t2 | white 60% | ikkilamchi matn |
| t3 | white 55% | meta |
| t4 | white 50% | caption / bo'lim sarlavhasi |
| t5 | white 40% | placeholder |
| t6 | white 30% | juda xira |
| violet | #7C5CFF | brend gradient boshi |
| cyan | #22D3EE | brend gradient oxiri, AI, havolalar |
| mint | #34D399 | sizga qarz / pul kirdi / muvaffaqiyat |
| coral | #FB7185 | siz qarzdorsiz / pul chiqdi / xato |
| amber | #FBBF24 | tasdiq kutilmoqda |
| onMint | #052E1C | mint tugma ustidagi matn |
| onCoral | #2A0B12 | coral tugma ustidagi matn |

Gradientlar:
- `brand` = linear(violet → cyan), to'g'ri chiziq (tugmalar: chapdan o'ngga; avatar halqasi/ikonka qutisi: yuqori-chap → pastki-o'ng)
- `mintCyan` = mint → cyan (progress barlar)
- `amberCoral` = amber → coral (bepul limit progress)
- `coralRose` = #FB7185 → #F43F5E (badge)
- `userBubble` = #7C5CFF → #5B8DEF (mening AI/yordam xabarim)

Aurora fon (har ekranning ustki 460px'ida, pastga mask bilan so'nadi):
- doira 320px violet 40% blur 70 (top -90, left -70)
- doira 280px #2563EB 40% blur 70 (top -40, right -90)
- doira 220px mint 25% blur 70 (top 130, left 130)
- sekin harakat (14–20s), ixtiyoriy.

Soya/blur:
- Shisha karta: `backdrop-blur 20`, ichki chiziq `inset 0 1px 0 white 8%` (Flutter: yuqori chegarani 1px oqroq chizish yoki BoxShadow bilan taqlid).
- Brend tugma soyasi: `0 12px 36px rgba(124,92,255,.45)`.
- Pastki panel: `0 12px 40px rgba(0,0,0,.5)`.

Radiuslar: katta karta 24 · qator/karta 20 · ikonka qutisi 14 · klaviatura tugmasi 16 · kalendar kuni 12 · sheet ustki 32 · tugma/chip/pill 999 (to'liq yumaloq).

Chetlar: gorizontal 20 (px-5), header ustki 60 (status bar ostidan; SafeArea ichida ~16), pastki panel bottom 30–34.

## 2. Tipografiya (`Tx`)

- Asosiy: **Plus Jakarta Sans** (matn, tugmalar, qatorlar).
- Sarlavha: **Inter Tight** — ekran nomlari (20/600), katta sarlavhalar (26–30/600, tracking -0.5), karta nomlari (17/600).
- Raqamlar: **Space Grotesk** — barcha summalar, klaviatura, kod kataklari, avatar bosh harflari (`tab: true` yoki `font: TbFont.num`).
- OS shrift kattaligi e'tiborsiz (`TextScaler.noScaling`) — avvalgidek.

Shkala: 46/600 sheet summasi · 36/600 dalil/uy summasi · 32/600 xarajat jami · 30/600 balans · 28/600 onboarding/telefon sarlavhasi · 24/600 chat summasi · 20/600 ekran nomi · 17/600 karta nomi · 16/600 qator nomi · 15 matn · 14 ikkilamchi · 13 meta · 12 kichik · 11/700 pill.
Bo'lim sarlavhasi (Cap): 13/700, UPPERCASE, letter-spacing 0.12em (≈1.5px), t4.

## 3. Ikonkalar
Dizaynda Lucide (chiziqli, 2px). Flutter'da Material `Icons.*_rounded`/`*_outlined` bilan almashtiriladi (ikonka to'plami qo'shilmaydi). Moslik:
chevL → `Icons.chevron_left_rounded`, chevR → `chevron_right_rounded`, bell → `notifications_none_rounded`,
spark (AI) → `auto_awesome_rounded`, search → `search_rounded`, check → `check_rounded`, x → `close_rounded`,
more → `more_horiz_rounded`, send → `send_rounded`, support → `headset_mic_rounded`, lock → `lock_outline_rounded`,
share → `ios_share_rounded`, cal → `calendar_today_rounded`, clock → `schedule_rounded`, shield → `verified_user_outlined`,
archive → `archive_outlined`, file → `description_outlined`, del → `backspace_outlined`, globe → `language_rounded`,
moon → `dark_mode_outlined`, phone → `smartphone_rounded`, crown → `workspace_premium_rounded`, help → `help_outline_rounded`,
out → `logout_rounded`, key → `key_rounded`, banknote → `payments_outlined`, building → `apartment_rounded`,
refresh → `refresh_rounded`, alert → `error_outline_rounded`, sun → `wb_sunny_outlined`, upRight → `north_east_rounded`,
downLeft → `south_west_rounded`, wallet → `account_balance_wallet_outlined`, heart → `favorite_border_rounded`,
car → `directions_car_outlined`, food → `restaurant_outlined`, house → `home_outlined`, bag → `shopping_bag_outlined`.

## 4. Primitivlar (`lib/ui.dart`)
- `Tx(text, size, w, color, font: TbFont.body|head|num, tab)` — matn.
- `Tap(onTap, child)` — bosishda 0.97 + haptik (mavjud).
- `GlassCard({child, r=24, pad, color, border, glow})` — shisha karta (glass + glassBd + ustki 1px oq chiziq).
- `GradientBtn(label, onTap, {h=56, icon, loading, enabled})` — brend gradient pill, soya bilan; enabled=false → glass2, matn t5.
- `SolidBtn(label, onTap, {color: mint|coral, fg})` — mint/coral to'liq pill (Qarz berdim, Rad etish va yuborish).
- `GlassBtn(label, onTap, {h=44|48|52, icon})` — glass2 pill (Qaytarish, Rad etish, Bekor qilish).
- `GlassIconBtn(icon, onTap, {size=44, color, badge})` — dumaloq shisha ikonka tugmasi (header). badge → coralRose doira, 12/700, chegara bg 2px.
- `BackBtn(onTap)` — GlassIconBtn(chevron_left).
- `ScreenHeader(title, {subtitle, onBack, trailing, leading})` — [Back] [title 20/600 head, subtitle 13 t2] [trailing]; balandlik 44, chet 20.
- `RingAvatar(initials, {size=48, gradient, dot})` — gradient halqa 2px, ichi surface2, bosh harflar Space Grotesk; dot → pastki-o'ng 14px doira (mint/amber/coral/white30), chegara bg 2px.
- `PillBadge(text, {bg, fg})` — h24, px8, 11/700, r999. Variantlar: `PillBadge.pro()` (brend gradient, oq), `.mint('Faol')`, `.amber('Kutilmoqda')`, `.coral('Muddati o‘tdi')`, `.muted('Yopildi')` — fon rang 15%, matn rang.
- `Chip(label, selected, onTap)` — h40, px16, 14/600; tanlangan: oq fon + bg rangli matn; aks holda glass + glassBd + t1.
- `Cap(text)` — bo'lim sarlavhasi.
- `KeyPad(keys)` — 3×4, tugma h56, r16, glass 5% + chegara 6%, 24/500 Space Grotesk; del → `backspace_outlined`.
- `CodeBoxes` — 58×68, r20, 30/tab; to'lgan: white10 + violet chegara; joriy: cyan70 chegara; bo'sh: white4 + glassBd.
- `PinDots` — 16px doira; to'lgan: brend gradient (1.1×), bo'sh: white15.
- `SheetShell` — sheetBg 95%, ustki r32, ustki chegara glassBd, tutqich 40×6 white20; dim: bg 70%.
- `BottomPanel({children})` — pastki suzuvchi shisha panel: h72 (yoki 56), r999, surface2 85%, glassBd, soya; chetlar 16, bottom 30.
- `ToastView` — pill h48, px20, #1A1D28 95%, chegara white15, check_circle mint ikonka + 14/600.
- `SuccessOverlay(title, sub)` — bg 85% blur, mint doira 96px ichida check 52, ikki halqa "burst", sarlavha 24/600.
- `Aurora()` — fon (yuqorida).
- `Skel` — glass rangli skeleton.
- `Illustration(asset, fallbackIcon)` — `Image.asset` + errorBuilder → gradient qutidagi ikonka.

## 5. Ekranlar

### 5.1 Splash
Markazda 96px r28 brend-gradient kvadrat, ichida "T" 48/700 Space Grotesk, soya 0 20px 60px violet 50%, pulse; ostida "Trustbook" 28/600 Inter Tight.

### 5.2 Onboarding (3 slayd)
Ustki: 32px r10 gradient "T" (chap) · "O'tkazib yuborish" 14 t2 (o'ng). Slayd: rasm 300×270 (r32), sarlavha 30/600 head markaz, tavsif 16 t2 markaz (mt 16). Pastda: nuqtalar (faol: 28×8 gradient, boshqa: 8×8 white25), tugma `GradientBtn` h56 "Keyingi"/"Boshlash". Matnlar:
1. "Qarzni yodda emas, Trustbook'da saqlang" — "Kimga berdingiz, kimdan oldingiz — hammasi bir joyda, unutilmaydi."
2. "Ikki tomon tasdiqlaydi" — "Har bir yozuvni ikkala tomon tasdiqlaydi — bahs-munozara bo'lmaydi."
3. "Muddat va eslatma" — "Qaytarish muddatini belgilang, Trustbook o'zi eslatib turadi."
Rasmlar: assets/illustrations/onb_1.png … onb_3.png (yo'q bo'lsa fallback).

### 5.3 Telefon
BackBtn (pt 62, px 20). "Telefon raqamingiz" 28/600 head; "SMS orqali tasdiqlash kodi yuboramiz" 15 t2. Maydon: h68 r24 glass, px20, 26 Space Grotesk: "+998" t2 · kiritilgan raqam oq (`__ ___ __ __` maska qoldig'i white25). Pastda GradientBtn "Davom etish" (to'liq bo'lmasa o'chiq) va KeyPad.

### 5.4 SMS kod
Sarlavha "SMS kodini kiriting", sub "+998 xx xxx xx xx raqamiga yuborildi". 5 ta CodeBoxes (justify-between). Ostida "Qayta yuborish 0:42" (t4; 0 bo'lganda cyan 600). KeyPad pastda.

### 5.5 PIN
Markazda: 64px r22 glass qutida lock ikonkasi (cyan 28), sarlavha 26/600 ("PIN kod yarating"/"Yangi PIN kiriting"), 4 PinDots (gap 20). KeyPad pastda.

### 5.6 Bosh (Hub)
Header (px20, pt60): `RingAvatar(44, "JT")` bosilsa Profil · "Salom, {ism}" 20/600 head + sana "7-sentabr, dushanba" 13 t2 · `GlassIconBtn(auto_awesome, cyan)` → Trust AI · `GlassIconBtn(bell, badge: unread)` → Bildirishnomalar.
Tana: 2×2 grid (gap 12, px20, pt20, pb112), kartalar bo'sh joyni teng bo'lib to'ldiradi (Expanded qatorlar). Har karta `GlassCard(r24, pad16)`: yuqori-o'ng PRO badge (kerak bo'lsa), markazda illyustratsiya (max, contain, soya 0 12px 24px black45), pastda nom 17/600 head, sub 13 t2 tab.
- Xarajatlar — sub: shu oy jami ("2 340 000 so'm"); rasm assets/illustrations/xarajat.png
- Qarz daftar — sub: "{n} kutilmoqda"; PRO; rasm daftar.png
- Ijaradagi uylar — sub: "5 uy · 2 to'landi"; PRO; rasm ijara.png
- To'yxona — sub: "18 band · sentabr"; PRO; rasm toyxona.png
FAB: o'ng-past (right 20, bottom 40) 60px gradient doira, headset ikonkasi 28 oq, soya violet 50% → Yordam chati. Hub va Daftarda ko'rinadi.
Skeleton: shisha bloklar. Bo'sh holat: kartalar sub'siz.

### 5.7 Qarz daftar (ro'yxat)
ScreenHeader("Qarz daftar", sub "{n} hamkor · {m} kutilmoqda"). Qidiruv: h48 pill glass, search ikonka t2, placeholder "Ism bo'yicha qidirish" (fokus: violet60 chegara). Chiplar (gorizontal, gap 8): Hammasi · Sizga qarz · Siz qarzdorsiz · Kutilmoqda.
Qator (h76, r20, **surface** #151823, glassBd, gap 8): RingAvatar(48, dot=holat) · ism 16/600 + ostida badge ("Trustbook'da" — cyan12 fon, cyan30 chegara, check ikonka, cyan matn 12/600 | "Taklif qiling" — glass2, t3) · o'ngda summa 16/600 num (mint/coral/t2) + "Sizga qarz"/"Siz qarzdorsiz"/"Yopildi" 13 t3.
Chapga surish → o'ngda 76×52 coral r16 "Arxiv" tugmasi (archive ikonka + 14/700 onCoral).
Bo'sh: "Hech narsa topilmadi" 15 t3, py64. Pastki bo'shliq 120.

### 5.8 Hamkor chati (ledger)
Header: BackBtn · RingAvatar(40) · ism 17/600 head + "Trustbook'da ✓" 13 cyan / "SMS orqali" t3 · GlassIconBtn(more_horiz) → menyu sheet.
Lenta (teskari, gap 8, px16, pastki bo'sh 124): 
- Balans kartasi (markazda, o'z kengligida): glass r20 px24 py12: "{Ism} sizga qarz"/"Siz qarzdorsiz"/"Hisob yopiq" 13 t2 · summa 30/600 num (mint/coral/t1) · USD qatori 14 t1.
- Yozuv pufagi (270px keng, r20, px16 py12): men berdim → o'ngda, mint10 fon + mint25 chegara, pastki-o'ng r8; u berdi → chapda, coral8 + coral20, pastki-chap r8; qaytarish → o'ngda glass2. Ichida: qator [24px doira ikonka (mint15/coral15/white10) + "Siz berdingiz"/"{Ism} berdi"/"Siz qaytardingiz" 13 t2]; summa 24/600 num (+mint / −coral / oq; yopilgan t3); izoh 14 t1; progress (agar qisman qaytarilgan): "Qaytarildi 400 000" 12 t2 · "27%" · bar h6 white10 → mintCyan; meta qator: "20-avgust · muddat 20-sentabr" 12 t4 · PillBadge (Faol/Kutilmoqda/Yopildi/"Muddati o‘tdi · 12 kun").
- Tasdiq kartasi (chapda, 310px, amber10 fon amber30 chegara r20, pastki-chap r8): "● TASDIQ KUTILMOQDA" 12/700 amber tracking .08em (pulse nuqta) · "{Ism}: «sizga 500 000 so'm qarz berdim»" 15 · "5-sentabr · Bozor uchun" 13 t2 · 2 tugma h44: GlassBtn "Rad etish" · GradientBtn "✓ Tasdiqlash". Tasdiqlangach karta aylanib (flip) mint12 kartaga aylanadi: 48px mint doira check · "Tasdiqlandi" 18/600 mint · "500 000 so'm · Siz qarzdorsiz · yozuv faol" 13 t1.
Pastki panel `BottomPanel(h72)`: `SolidBtn(mint, north_east, "Qarz berdim")` flex · `GlassBtn(refresh, "Qaytarish")` flex · 52px gradient doira bell → eslatma.
Menyu sheet: ism 20/600; ro'yxat kartasi (glass r24): "Dalil (PDF)" (file cyan) · "Eslatma yuborish" (bell amber) · "Arxiv" (archive t1); har qator h56, chevron t6.
Rad etish sheet: "Rad etish sababi" 20/600; "{Ism}ga sabab bilan xabar boradi" 14 t2; chiplar h44 (Summa xato / Bunday bo'lmagan / Boshqa; tanlangan: coral fon onCoral matn); `SolidBtn(coral)` "Rad etish va yuborish"; "Bekor qilish" matnli h48 t1.

### 5.9 Yangi yozuv sheet
Sarlavha "Qarz berdim"/"Qarz oldim"/"Qaytarish" 20/600 + o'ngda 44px glass ✕. Hamkor tanlash chiplari (h40: 24px gradient avatar + ism; tanlangan oq) yoki "Hamkor: **Ism**" 14 t2. Summa 46/600 num (bo'sh: t6; berdim: mint; oldim: coral; qaytarish: oq) + o'ngda UZS|USD segment (h40 glass pill, tanlangan oq fon). Chiplar qatori: [cal ikonka t2] "Bugun, 7-sen" · [clock amber] "Muddat yo'q / 1 hafta / 1 oy / 3 oy". Izoh maydoni h48 pill glass. KeyPad (h52). `GradientBtn`(send) "Yozuvni yuborish" (summa yo'q → o'chiq). "Hamkor tasdiqlagach yozuv faol bo'ladi" 13 t4 markaz.
Yuborilgach `SuccessOverlay("Yozuv yuborildi", "Hamkor tasdig'ini kutmoqda")` 1.5s.

### 5.10 Dalil
ScreenHeader("Dalil"). GlassCard r24 pad20 (o'ng-yuqorida gradient blur dog' 160px 25%): "🔒 QULFLANGAN YOZUV" 13/700 cyan tracking .08em · "Yozuv kodi" 15 t2 · "TB-7F3A-91C2-E04D" 22/600 num tracking 1 · summa 36/600 mint · 2 ustunli grid (Kimdan / Kimga / Sana / Holat "Ikki tomon tasdiqladi" mint shield) 14 (label t3, qiymat 600) · ajratgich · izoh 13 t3. Pastda `GradientBtn(ios_share)` "PDF ulashish".

### 5.11 Xarajatlar
Header: BackBtn · "Xarajatlar" + "Sentabr 2026" 13 t2 · o'ngda h36 gradient pill "👑 PRO oling"/"PRO".
Jami kartasi (GlassCard r24 pad20, qator): chap — "Bu oy sarflandi" 14 t2, summa 32/600 num, "Limit 5 640 000 so'm" 14 t2, "Qoldi 3 300 000" 15/600 mint; o'ng — 110px halqa (stroke 10, fon white8, cyan progress, r46) ichida "41%" 22/600 num + "limitdan" 12 t3.
Cap "PAPKALAR" → 2 ustunli grid (gap 12): GlassCard r20 pad16: 44px r14 gradient ikonka qutisi (transport: brend; oziq-ovqat: mint→cyan; uy: #F472B6→violet; boshqa: amber→coral) · nom 15/600 · summa 15 num t1 · "12 ta xarajat" 13 t3. Qo'shilganda karta cyan halqa (ring 2) + 1.02 masshtab 0.9s.
Cap "ANIQLANMAGAN" + son → punktir chegarali (white15, r20) tray, ichida h40 pill chiplar "Nom · summa"; bo'sh: "AI tanimagan xarajatlar shu yerga tushadi" 14 t5.
Pastki panel (left 16 right 16 bottom 34): ustida "3/5 bepul yozuv ishlatildi" 13 t4 markaz; h56 pill surface2 85%: auto_awesome cyan · input "Taksi 15000" · 44px gradient doira send. Yuborilganda chip pastdan papkaga "uchadi" (0.72s).

### 5.12 Ijaradagi uylar
Header: "Ijaradagi uylar" + PRO badge. Oy chiplari (Iyul / Avgust / Sentabr). Xulosa kartasi (GlassCard r24 pad20, 2 ustun): "Kutilgan" 14 t2 / summa 24/600 num; "Kelgan" / summa mint; to'liq qator: bar h8 white10 → mintCyan · "2/5 uy to'landi · 1 kechikkan" 13 t2.
Uylar 2 ustunli grid: GlassCard r20 pad16: 40px r14 glass2 apartment ikonka · nom 15/600 · ijarachi 13 t2 · summa 16/600 num (+mint / −coral / amber) · PillBadge (To'langan / Kutilmoqda / "Kechikkan · 6 kun").
Uy tafsiloti: header (nom 18/600, ijarachi 13 t2); karta: "Oylik ijara" 14 t2 + PillBadge · summa 36/600 num · "Sentabr uchun · to'lov kuni har oyning 5-si" 14 t2. Cap "TO'LOVLAR" → GlassCard ro'yxati: qator h64: 36px doira ikonka (check mint / alert coral / clock amber) · "Sentabr 2026" 15/600 + sana 13 t2 · summa 15/600 num. Pastda `SolidBtn(mint, payments)` "To'lov keldi" (to'langan: glass2 "To'langan ✓").
To'lov sheet: "To'lov keldi" 20/600; "{uy} · {ijarachi}" 14 t2; summa 44/600 mint markaz; "Sentabr ijarasi · bugun" 14 t2; Naqd|Karta (h48 chiplar, tanlangan oq); `SolidBtn(mint, check)` "Tasdiqlash"; "Bekor qilish".

### 5.13 To'yxona
Header: "To'yxona" + PRO. "Sentabr 2026" 22/600 head + legenda (● violet Band · ● white20 Bo'sh). Kalendar GlassCard r24 pad12: hafta kunlari 12/700 t4 (Du Se Ch Pa Ju Sh Ya); kun tugmasi h52 r12: bugun — brend gradient; o'tgan — t6 matn; kelajak — white3 fon; ostida 3 nuqta (6px; band: violet, bo'sh: white15).
Cap "BUGUN · 7-SENTABR" → slotlar (h68 r20 glass): 44px r14 ikonka (Nahor: sun amber15; Tushlik: restaurant cyan15; Kechki: moon violet20/#B4A2FF) · "Nahor · 07:00" 15/600 (vaqt t4) · mijoz 14 t1 yoki "Bo'sh" mint · chevron t6.
Bron sheet: "{kun}-sentabr · bandlar" + ✕; slotlar h76 r20 glass; bo'sh → h40 gradient "Band qilish"; band → glass2 "Bog'lanish".

### 5.14 Trust AI
Header: BackBtn · 40px gradient doira auto_awesome · "Trust AI" 18/600 + "● onlayn" 13 mint. Lenta (px20, gap 12): AI pufagi chapda (max 300, r20 pastki-chap r8, glass), mening pufagim o'ngda (userBubble gradient, r20 pastki-o'ng r8), 15 matn. Boshlang'ich savollar: h44 pill violet50 chegara + violet10 fon, 14/500. Grafik kartasi (300px glass r20 pad16): "Oylik xarajat" 14/600 · "−12%" 13 mint · 6 ustunli bar (oxirgisi cyan→violet, qolgani white10→white25) · oy nomlari 12 t3. Amal tugmasi: h44 gradient pill "Yuna'ga yuborish". Yozmoqda: 3 nuqta. Pastki panel h56: input "Savol yozing…" + 44px gradient send.

### 5.15 Bildirishnomalar
Header: "Bildirishnomalar" · o'ngda "O'qilgan" 14/500 cyan. Guruhlar (Cap "BUGUN"/"KECHA") → GlassCard r24 ro'yxat: qator (px16 py14, ajratgich hairline): RingAvatar(44) · sarlavha 15/600 + sub 14 t2 · o'ngda vaqt 12 t4 + o'qilmagan → 10px gradient nuqta.

### 5.16 Profil
Header "Profil". Avatar 72 (halqa 3px) + "Jafar Tursunov" 20/600 head, telefon 15 t2 num, "✓ Tasdiqlangan hisob" 13 mint.
Cap "SOZLAMALAR" → GlassCard r24 ro'yxat (qator h56, ikonka 20 t1, nom 15/500, qiymat 14 t2, chevron t6): Til · Valyuta · Tungi rejim (toggle 52×32: faol gradient / white15, knob 26 oq) · PIN kod · Bildirishnomalar (toggle) · Qurilmalar.
Cap "OBUNA" → ro'yxat: har modul (wallet/apartment/heart ikonkalar) + o'ngda h28 pill "PRO" (gradient) / "Bepul" (white10 t1).
Uchinchi karta: Yordam · Onboarding'ni ko'rish · Chiqish (coral). Pastda "Trustbook v{versiya}" 13 t6.

### 5.17 Paywall sheet
64px r22 gradient qutida crown 30 (soya violet45) · "{Modul} PRO" 24/600 markaz · "Cheklovsiz yozuvlar va aqlli tahlil" 15 t2 · glass karta: "Bepul yozuvlar" / "3/5" + bar amberCoral · 4 foyda (32px mint15 doira check + 15 matn) · GradientBtn "Obuna bo'lish · {narx}/oy" · "Xaridni tiklash" 15 t1. (Apple 3.1.2 matn bloki saqlanadi — 12 t4.)

### 5.18 Yordam (feedback) sheet
44px gradient doira chat ikonka · "Fikr bildirish" 20/600 · "Trustbook jamoasi · odatda 1 soatda javob beradi" 13 t2 · xabarlar (mening: userBubble r18 pastki-o'ng r6; ularniki: glass2 r18 pastki-chap r6) + vaqt 11 t5 · input h56 pill + gradient send.

### 5.19 Umumiy holatlar
- Toast — pastdan 116px, markazda.
- Success overlay — 1.5s.
- Ekran o'tishlari: kirish 40px o'ngdan + fade 0.38s; orqaga chapdan 0.34s; sheet pastdan 0.42s.
- Light tema: dizaynda yo'q («Yorug' rejim tez orada») — Flutter'da toggle saqlanadi, light palitra = xuddi shu tuzilma, och fon (#F4F5FB), qora matn, shisha = qora 4–6%.

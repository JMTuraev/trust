// BOSH HUB — ilovaning ildiz ekrani (pastki navigatsiya o'rniga).
//
// Dizayn manbai: prototype/bosh-ekran.dc.html «4-tur · Papkalar uslubi» —
//   4a «Asosiy — Light», 4b «Asosiy — Dark», 4c «Bo'sh holat».
// Skelet freymi 4-turda yo'q, shuning uchun «Yuklanish — skelet» (3d) freymidan
// olindi va 4-tur tuzilmasiga moslandi (radius 16 -> 18): yuklangach sakrash bo'lmasin.
//
// Navigatsiya: hub -> karta bosiladi -> bo'lim TO'LIQ EKRAN ochiladi ->
// header'dagi orqaga (<) hub'ga qaytaradi (store: goHub_ / hubBack).
// Barcha raqam store.vals() dan (real ma'lumot) — mock yo'q.
import 'dart:io' show File;

import 'package:flutter/material.dart';

import '../flags.dart';
import '../sparkline.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';

// Kartalardagi ikonka turlari (prototipdagi inline SVG path'lari bilan 1:1)
enum _G { expense, swap, diamond }

class HomeHubScreen extends StatefulWidget {
  const HomeHubScreen({super.key});

  @override
  State<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends State<HomeHubScreen> {
  @override
  void initState() {
    super.initState();
    // Trust AI kartasidagi teaser uchun suhbat tarixi. loadAiMsgs() 'aiLoaded'
    // bilan himoyalangan — bir marta yuklanadi. build/vals() ichida EMAS:
    // hosilaviy qiymatlar nojo'ya effektsiz qolishi kerak.
    if (kAiEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => store.loadAiMsgs());
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final Pal p = curPal();
    final dark = store.S['dark'] == true;
    final skel = v['hubSkel'] == true;
    final empty = !skel && v['hubEmpty'] == true;

    // Prototip: skroller padding 6px 20px 28px
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      child: Column(
        // stretch — CSS blok oqimi kabi: kartalar doim to'liq kenglikda
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(v, p, empty),
          // Menga kelgan pending bog'lanish so'rovlari — salomlashuvdan keyin,
          // kartalardan tepada (ikki-tomonlama qabul, item 7).
          if (!skel && (v['hubPendingReq'] as int) > 0) ...[
            const SizedBox(height: 14),
            _pendingBanner(v, p),
          ],
          const SizedBox(height: 18), // grid margin-top:18
          // DIQQAT: `const` EMAS — const instance kanonik bo'lgani uchun qayta
          // qurishda Element rebuild'ni o'tkazib yuborardi (main.dart'dagi izoh).
          if (skel)
            _HubSkelBody()
          else if (empty)
            ..._emptyBody(v, p)
          else
            ..._body(v, p, dark),
        ],
      ),
    );
  }

  // Menga kelgan pending bog'lanish so'rovlari banneri (item 7) — brend uslubi:
  // p.field fon, r14, ink matn; bosilganda hubOpenReq (1 ta bo'lsa to'g'ridan
  // ochadi, ko'p bo'lsa Qarz Daftar ro'yxatiga o'tadi).
  Widget _pendingBanner(Map<String, dynamic> v, Pal p) {
    return Tap(
      onTap: () => v['hubOpenReq'](),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            _tintBox(p.card2, 15, _G.swap, p.ink, 1.4),
            const SizedBox(width: 11),
            Expanded(
              child: Tx(v['hubPendingReqTxt'] as String,
                  size: 13, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
            ),
            const SizedBox(width: 10),
            ChevRight(color: p.t3, size: 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── SARLAVHA ───────────────────────────
  // Prototip: margin-top:10; padding:0 4px; align-items:flex-start.
  // PO 2026-07-17: eng tepada brend qatori (TrustMark chapda, qo'ng'iroq+avatar
  // o'ngda), salomlashuv to'liq kenglikdagi alohida qatorda (ism qisqarmasin),
  // obuna mikro-nishoni sana qatoriga ko'chdi («juma»dan keyin).
  Widget _header(Map<String, dynamic> v, Pal p, bool empty) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // home.dart headeri bilan bir uslub: logo + «Trust» yozuvi (PO 2026-07-17)
              const TrustMark(size: 27, boxed: true),
              const SizedBox(width: 9),
              Tx('Trust', size: 21, w: FontWeight.w700, color: p.ink, ls: -0.3),
              const Spacer(),
              _bellBtn(v, p),
              const SizedBox(width: 10),
              _avatarBtn(v, p), // Profil kirish nuqtasi
            ],
          ),
          const SizedBox(height: 14),
          Tx(
            (empty ? v['hubGreetEmpty'] : v['hubGreet']) as String,
            size: 20, w: FontWeight.w600, color: p.ink, ls: -0.4,
            maxLines: 1, ellipsis: true,
          ),
          const SizedBox(height: 4),
          // Sana + obuna mikro-nishoni: sinov chipi (4a/4c) yoki «Premium» matni (3a).
          // Wrap — tor ekranda nishon keyingi qatorga tushadi, Row overflow bo'lmaydi.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Tx(v['hubDate'] as String, size: 13, color: p.t2, maxLines: 1, ellipsis: true),
              if (v['hubTrial'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Tx(v['hubTrialTxt'] as String,
                      size: 11, w: FontWeight.w600, color: p.t1, maxLines: 1),
                )
              else if (v['hubPrem'] == true)
                Tx(v['hubPremTxt'] as String, size: 11, color: p.t4, maxLines: 1),
            ],
          ),
        ],
      ),
    );
  }

  // Bildirishnomalar tugmasi — 38x38 dumaloq, ichida qo'ng'iroq (prototip: div'lar).
  // Nuqta (o'qilmagan) prototipda yo'q — home.dart bilan bir xil uslubda qo'shildi
  // (ildiz ekranda o'qilmagan bildirishnoma ko'rinmay qolmasligi uchun).
  Widget _bellBtn(Map<String, dynamic> v, Pal p) {
    return Tap(
      onTap: () => v['hubOpenNotifs'](),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.hair),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 9,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: p.ink, width: 1.5),
                          top: BorderSide(color: p.ink, width: 1.5),
                          right: BorderSide(color: p.ink, width: 1.5),
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ),
                    Container(
                      width: 16,
                      height: 1.5,
                      decoration:
                          BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(1)),
                    ),
                    Container(
                      width: 4,
                      height: 3,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: p.ink,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(3),
                          bottomRight: Radius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (v['hubBellDot'] == true)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: p.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.bg, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Avatar — 38x38, kontur phair, ichida bosh harflar yoki tanlangan rasm.
  Widget _avatarBtn(Map<String, dynamic> v, Pal p) {
    final path = v['hubAvatar'] as String?;
    // Kesh tozalansa fayl yo'qoladi — profil.dart bilan bir xil tekshiruv
    final File? f = (path != null && File(path).existsSync()) ? File(path) : null;
    return Tap(
      onTap: () => v['hubOpenProfil'](),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: p.hair),
          image: f != null ? DecorationImage(image: FileImage(f), fit: BoxFit.cover) : null,
        ),
        child: f == null
            ? Tx(v['hubIni'] as String, size: 12, w: FontWeight.w600, color: p.ink)
            : null,
      ),
    );
  }

  // ─────────────────────────── ASOSIY HOLAT ───────────────────────────
  List<Widget> _body(Map<String, dynamic> v, Pal p, bool dark) => [
        _heroCard(v, p, dark),
        const SizedBox(height: 10), // grid gap
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch, // grid: bir qatorda teng balandlik
            children: [
              Expanded(child: _debtCard(v, p, dark)),
              if (kAiEnabled) ...[
                const SizedBox(width: 10),
                Expanded(child: _aiCard(v, p)),
              ],
            ],
          ),
        ),
        // Action tugmalar qatori olib tashlandi (PO 2026-07-17): kartalarning
        // o'zi kirish nuqtasi. «SO'NGGI» tepasidagi 18px margin saqlanadi.
        const SizedBox(height: 18),
        _recent(v, p),
      ];

  // XARAJAT kartasi (grid-column: span 2)
  Widget _heroCard(Map<String, dynamic> v, Pal p, bool dark) {
    final hasLimit = v['hubHasLimit'] == true;
    final trend = v['hubTrendTxt'] as String;
    return Tap(
      onTap: () => v['hubOpenXar'](),
      child: Container(
        clipBehavior: Clip.antiAlias, // prototip: overflow:hidden (watermark)
        decoration: BoxDecoration(
          color: p.hov2,
          border: Border.all(color: p.hair),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            // Watermark: light 0.06, dark 0.07 (qora fonda bir xil sezilishi uchun)
            Positioned(
              right: -22,
              top: -18,
              child: Opacity(
                opacity: dark ? .07 : .06,
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(painter: _Glyph(_G.expense, p.red, 1.1)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bo'lim nomi — «TRUST AI» caption uslubida (PO: birinchi kirishda
                  // karta qaysi bo'limga olib borishi tushunarli bo'lsin)
                  Tx(v['hubXarSec'] as String, size: 11, w: FontWeight.w800, color: p.t1, ls: 1.4),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _tintBox(_tint(p.red, dark), 15, _G.expense, p.red, 1.5),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tx(v['hubXarCap'] as String, size: 13.5, color: p.t1,
                                maxLines: 1, ellipsis: true),
                            const SizedBox(height: 3),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Flexible(
                                  child: Tx(v['hubXarTxt'] as String,
                                      size: 27, w: FontWeight.w600, color: p.red,
                                      ls: -0.5, tab: true, maxLines: 1, ellipsis: true),
                                ),
                                const SizedBox(width: 4),
                                Tx(v['hubXarUnit'] as String, size: 14, color: p.t2),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (hasLimit || trend.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Streak-glif (ikki burilgan tomchi) olib tashlandi
                        // (PO 2026-07-17: ma'ni ajratmayapti) — raqamdan keyin bo'sh.
                        if (hasLimit) ...[
                          Tx(v['hubLeftCap'] as String, size: 12, color: p.t1),
                          Tx(v['hubLeftTxt'] as String,
                              size: 12,
                              w: FontWeight.w600,
                              color: v['hubLeftPos'] == true ? p.green : p.red,
                              tab: true),
                        ],
                        const Spacer(),
                        if (trend.isNotEmpty)
                          Tx(trend,
                              size: 11,
                              // Prototipda faqat o'sish holati bor (prd). Kamayish —
                              // yaxshi xabar, shuning uchun brend yashilida (§hisobot).
                              color: v['hubTrendUp'] == true ? p.red : p.green,
                              tab: true,
                              maxLines: 1,
                              ellipsis: true),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 46,
                    child: Sparkline(
                      values: (v['hubXarSpark'] as List).cast<double>(),
                      color: p.red,
                      stroke: 2.2,
                      dot: 3.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // OLDI-BERDI kartasi
  Widget _debtCard(Map<String, dynamic> v, Pal p, bool dark) {
    final spark = (v['hubDebtSpark'] as List).cast<double>();
    // Chet valyuta netlari (PO 2026-07-17): [{'cur':'USD','txt':'−2 000','pos':false}]
    final fx = (v['hubDebtFx'] as List).cast<Map<String, dynamic>>();
    return Tap(
      onTap: () => v['hubOpenDebt'](),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.hov2,
          border: Border.all(color: p.hair),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -26,
              top: -16,
              child: Opacity(
                opacity: dark ? .07 : .06,
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: CustomPaint(painter: _Glyph(_G.swap, p.green, 1.1)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bo'lim nomi — XARAJATLAR/TRUST AI kabi ikonkadan TEPADA (PO sinov 2026-07-17)
                  Tx(v['hubDebtSec'] as String, size: 11, w: FontWeight.w800, color: p.t1, ls: 1.4),
                  const SizedBox(height: 6),
                  _tintBox(_tint(p.green, dark), 16, _G.swap, p.green, 1.4),
                  const SizedBox(height: 10),
                  Tx(v['hubDebtCap'] as String, size: 13, color: p.t1, maxLines: 1, ellipsis: true),
                  const SizedBox(height: 3),
                  Tx(v['hubDebtTxt'] as String,
                      size: 19, w: FontWeight.w600, color: p.green, ls: -0.4,
                      tab: true, maxLines: 1, ellipsis: true),
                  const SizedBox(height: 2),
                  Tx(v['hubDebtSub'] as String, size: 11, color: p.t2, maxLines: 1, ellipsis: true),
                  // Chet valyuta bo'yicha net qatorlari (PO 2026-07-17): «USD: −2 000».
                  // Manfiy = sizning qarzingiz (p.red), musbat = sizga (p.green).
                  for (final f in fx) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Tx('${f['cur']}:', size: 12, color: p.t1),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Tx(f['txt'] as String,
                              size: 12,
                              w: FontWeight.w600,
                              color: f['pos'] == true ? p.green : p.red,
                              tab: true,
                              maxLines: 1,
                              ellipsis: true),
                        ),
                      ],
                    ),
                  ],
                  if (v['hubFrozen'] == true) ...[
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: p.red),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Tx(v['hubFrozenTxt'] as String,
                              size: 11, color: p.red, maxLines: 1, ellipsis: true),
                        ),
                      ],
                    ),
                  ],
                  // Tekis tarix (variatsiya yo'q) «yolg'iz nuqta» bo'lib chizilardi —
                  // store bunday holda [] beradi, blok butunlay yashirinadi va
                  // kartada ortiqcha bo'shliq qolmaydi (PO 2026-07-17).
                  if (spark.length >= 2) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 30,
                      child: Sparkline(values: spark, color: p.green, stroke: 2, dot: 3),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TRUST AI kartasi
  Widget _aiCard(Map<String, dynamic> v, Pal p) {
    return Tap(
      // goAi — vals()dagi mavjud o'tish (aiFrom='hub' saqlanadi, orqaga hub'ga qaytadi)
      onTap: () => v['goAi'](),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _tintBox(p.card2, 15, _G.diamond, p.ink, 1.4),
                const SizedBox(width: 9),
                Tx('TRUST AI', size: 11, w: FontWeight.w800, color: p.t1, ls: 1.4),
                const SizedBox(width: 6),
                _PulseDot(color: p.idle),
              ],
            ),
            const SizedBox(height: 11),
            Tx(v['hubAiTxt'] as String, size: 13, color: p.ink, lh: 20.15),
            const SizedBox(height: 8),
            Tx(v['hubAiSub'] as String, size: 11, color: p.t3, maxLines: 1, ellipsis: true),
            const SizedBox(height: 11),
            Tx(v['hubAiSee'] as String, size: 12, w: FontWeight.w600, color: p.ink),
          ],
        ),
      ),
    );
  }

  // «SO'NGGI» tasmasi
  Widget _recent(Map<String, dynamic> v, Pal p) {
    final rows = (v['hubRecentRows'] as List).cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Cap(v['hubRecentCap'] as String),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tx(v['hubTodayCap'] as String,
                      size: 11, w: FontWeight.w500, color: p.t1, tab: true),
                  Tx(v['hubTodayTxt'] as String,
                      size: 11, w: FontWeight.w500, color: p.red, tab: true),
                ],
              ),
            ],
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Tx(v['hubEmptyRecent'] as String, size: 12.5, color: p.t4),
            ),
          for (var i = 0; i < rows.length; i++)
            _recentRow(rows[i], p, last: i == rows.length - 1),
        ],
      ),
    );
  }

  Widget _recentRow(Map<String, dynamic> r, Pal p, {required bool last}) {
    return Tap(
      onTap: r['tap'] as VoidCallback,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: last
            ? null
            : BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.card2),
              child: Tx(r['ini'] as String, size: 10, w: FontWeight.w600, color: p.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(r['name'] as String,
                      size: 13, w: FontWeight.w500, color: p.ink, maxLines: 1, ellipsis: true),
                  const SizedBox(height: 1),
                  Tx(r['sub'] as String, size: 11, color: p.t3, maxLines: 1, ellipsis: true),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Tx(r['amt'] as String,
                size: 13,
                w: FontWeight.w500,
                color: r['inc'] == true ? p.green : p.red,
                tab: true,
                maxLines: 1),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── BO'SH HOLAT (4c) ───────────────────────────
  // «Rang faqat ma'lumot bilan keladi»: tintlar neytralga (card2/t1) tushadi,
  // sparkline o'rniga nuqtali «kutish» chizig'i — struktura tanish qoladi.
  List<Widget> _emptyBody(Map<String, dynamic> v, Pal p) => [
        Tap(
          onTap: () => v['hubOpenXar'](),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.hov2,
              border: Border.all(color: p.hair),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -22,
                  top: -18,
                  child: Opacity(
                    opacity: .05,
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: CustomPaint(painter: _Glyph(_G.expense, p.ink, 1.1)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _tintBox(p.card2, 15, _G.expense, p.t1, 1.5),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tx(v['hubEmptyXarCap'] as String, size: 13.5, color: p.t1),
                                const SizedBox(height: 3),
                                Tx(v['hubEmptyXarTitle'] as String,
                                    size: 17, w: FontWeight.w600, color: p.ink),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Tx(v['hubEmptyXarHint'] as String, size: 12, color: p.t3),
                      const SizedBox(height: 10),
                      SizedBox(height: 30, child: SparkDots(color: p.t6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Tap(
                  onTap: () => v['hubAddDebt'](),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    decoration: BoxDecoration(
                      color: p.hov2,
                      border: Border.all(color: p.hair),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bo'lim nomi — loaded karta bilan bir xil, ikonkadan TEPADA (PO sinov)
                        Tx(v['hubDebtSec'] as String, size: 11, w: FontWeight.w800, color: p.t1, ls: 1.4),
                        const SizedBox(height: 6),
                        _tintBox(p.card2, 16, _G.swap, p.t1, 1.4),
                        const SizedBox(height: 10),
                        Tx(v['hubEmptyDebtTitle'] as String,
                            size: 14, w: FontWeight.w600, color: p.ink, lh: 19.6),
                        const SizedBox(height: 5),
                        Tx(v['hubEmptyDebtHint'] as String, size: 11.5, color: p.t3, lh: 17.25),
                        const SizedBox(height: 13),
                        Tx(v['hubEmptyDebtBtn'] as String,
                            size: 12, w: FontWeight.w600, color: p.ink),
                      ],
                    ),
                  ),
                ),
              ),
              if (kAiEnabled) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    decoration:
                        BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _tintBox(p.card2, 15, _G.diamond, p.t1, 1.4),
                            const SizedBox(width: 9),
                            Tx('TRUST AI', size: 11, w: FontWeight.w800, color: p.t1, ls: 1.4),
                            const SizedBox(width: 6),
                            // Bo'sh holatda nuqta pulsatsiyalanmaydi (4c)
                            Container(
                              width: 6,
                              height: 6,
                              decoration:
                                  BoxDecoration(shape: BoxShape.circle, color: p.idle),
                            ),
                          ],
                        ),
                        const SizedBox(height: 11),
                        Tx(v['hubAiTxt'] as String, size: 13, color: p.t1, lh: 20.15),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Cap(v['hubRecentCap'] as String),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Tx(v['hubEmptyRecent'] as String, size: 12.5, color: p.t4),
              ),
            ],
          ),
        ),
      ];

  // Tint kvadrat: 34x34, radius 11 (prototipdagi ikonka fon-kvadrati)
  Widget _tintBox(Color tint, double icon, _G g, Color c, double sw) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(11)),
        child: SizedBox(
          width: icon,
          height: icon,
          child: CustomPaint(painter: _Glyph(g, c, sw)),
        ),
      );

  // --pgrT / --prdT: light rgba(...,0.09), dark rgba(...,0.14)
  Color _tint(Color c, bool dark) => c.withValues(alpha: dark ? .14 : .09);
}

/// Hub'dan ochilgan bo'lim uchun yengil qobiq: header'da faqat orqaga (<).
/// Hozir faqat profil.dart shu bilan o'raladi (main.dart). Hamkorlar (home.dart)
/// esa orqaga tugmasini O'Z header qatorida ko'rsatadi (PO 2026-07-17: bitta
/// ekranda ikkita header qatori bo'lmasin).
class HubSection extends StatelessWidget {
  final Widget child;
  const HubSection({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 12),
              BackBtn(onTap: () => store.vals()['goHub']()),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Trust AI «tirik» nuqtasi — prototip: animation trPulse 2.2s ease infinite
/// (0%,100% opacity 1; 50% opacity 0.25).
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Opacity(
        opacity: 1 - .75 * Curves.ease.transform(_c.value),
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
        ),
      ),
    );
  }
}

/// Ikonkalar — prototipdagi inline SVG path'lari (viewBox birligida) 1:1.
class _Glyph extends CustomPainter {
  final _G kind;
  final Color color;
  final double sw; // viewBox birligidagi stroke-width
  const _Glyph(this.kind, this.color, this.sw);

  @override
  void paint(Canvas canvas, Size size) {
    final vb = kind == _G.swap ? 16.0 : 14.0;
    final k = size.shortestSide / vb;
    if (k <= 0) return;
    final path = Path();
    if (kind == _G.expense) {
      // M3.5 10.5 L10.5 3.5 M5.5 3.5 H10.5 V8.5
      path
        ..moveTo(3.5 * k, 10.5 * k)
        ..lineTo(10.5 * k, 3.5 * k)
        ..moveTo(5.5 * k, 3.5 * k)
        ..lineTo(10.5 * k, 3.5 * k)
        ..lineTo(10.5 * k, 8.5 * k);
    } else if (kind == _G.swap) {
      // M2.5 5 H13 M10.5 2.5 L13 5 L10.5 7.5 M13.5 11 H3 M5.5 8.5 L3 11 L5.5 13.5
      path
        ..moveTo(2.5 * k, 5 * k)
        ..lineTo(13 * k, 5 * k)
        ..moveTo(10.5 * k, 2.5 * k)
        ..lineTo(13 * k, 5 * k)
        ..lineTo(10.5 * k, 7.5 * k)
        ..moveTo(13.5 * k, 11 * k)
        ..lineTo(3 * k, 11 * k)
        ..moveTo(5.5 * k, 8.5 * k)
        ..lineTo(3 * k, 11 * k)
        ..lineTo(5.5 * k, 13.5 * k);
    } else {
      // M7 1.5 L12.5 7 L7 12.5 L1.5 7 Z
      path
        ..moveTo(7 * k, 1.5 * k)
        ..lineTo(12.5 * k, 7 * k)
        ..lineTo(7 * k, 12.5 * k)
        ..lineTo(1.5 * k, 7 * k)
        ..close();
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Glyph old) =>
      old.kind != kind || old.color != color || old.sw != sw;
}

/// Yuklanish skeleti — «Yuklanish — skelet» (3d) freymi, 4-tur tuzilmasiga
/// moslangan (radius 18): yuklangach bloklar sakramaydi.
///
/// DIQQAT: ui.dart'dagi `Skel` bu yerda ishlatilmadi — u rangni p.card2 ga
/// qotirgan va pulsatsiya qilmaydi, prototip esa --pskel (Pal.skelDot) +
/// trSkel pulsini talab qiladi (hisobot §NEW-PATCHES: Skel'ga `color` qo'shish).
class _HubSkelBody extends StatefulWidget {
  const _HubSkelBody();

  @override
  State<_HubSkelBody> createState() => _HubSkelBodyState();
}

class _HubSkelBodyState extends State<_HubSkelBody> with SingleTickerProviderStateMixin {
  // Prototip: animation trSkel 1.4s ease infinite (0%,100% opacity .45; 50% opacity 1)
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Bitta skelet bloki. delay — prototipdagi animation-delay (soniyada).
  Widget _b({double? w, required double h, double r = 5, double delay = 0}) {
    final p = curPal();
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = (_c.value - delay / 1.4) % 1.0; // Dart: manfiy qoldiq musbatga keladi
        final k = Curves.easeInOut.transform(t < .5 ? t * 2 : (1 - t) * 2);
        return Opacity(
          opacity: .45 + .55 * k,
          child: Container(
            width: w ?? double.infinity,
            height: h,
            decoration:
                BoxDecoration(color: p.skelDot, borderRadius: BorderRadius.circular(r)),
          ),
        );
      },
    );
  }

  Widget _row(double w1, double w2, double d, {required bool last, required Pal p}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration:
          last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
      child: Row(
        children: [
          _b(w: 32, h: 32, r: 16, delay: d),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: w1,
                  alignment: Alignment.centerLeft,
                  child: _b(h: 9, delay: d + .1),
                ),
                const SizedBox(height: 7),
                FractionallySizedBox(
                  widthFactor: w2,
                  alignment: Alignment.centerLeft,
                  child: _b(h: 8, r: 4, delay: d + .15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _b(w: 52, h: 10, delay: d + .2),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Pal p = curPal();
    return Column(
      // stretch — asosiy holat bilan bir xil: bloklar to'liq kenglikda,
      // yuklangach karta o'lchami sakramaydi
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Xarajat kartasi (span 2)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border.all(color: p.hair),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _b(w: 120, h: 9),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _b(w: 140, h: 26, r: 8),
                      const SizedBox(height: 10),
                      _b(w: 95, h: 9, delay: .1),
                    ],
                  ),
                  _b(w: 110, h: 40, r: 10, delay: .15),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: p.hair),
              const SizedBox(height: 13),
              Row(
                children: [
                  _b(w: 62, h: 9, delay: .2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                          color: p.barbg, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _b(w: 30, h: 9, delay: .25),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Oldi-berdi kartasi
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                  decoration: BoxDecoration(
                    color: p.bg,
                    border: Border.all(color: p.hair),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _b(w: 72, h: 9),
                      const SizedBox(height: 14),
                      _b(w: 88, h: 18, r: 6, delay: .1),
                      const SizedBox(height: 9),
                      _b(w: 110, h: 9, delay: .15),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _b(w: 26, h: 26, r: 13),
                          const SizedBox(width: 4),
                          _b(w: 26, h: 26, r: 13, delay: .1),
                          const SizedBox(width: 4),
                          _b(w: 26, h: 26, r: 13, delay: .2),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _b(w: 80, h: 9, delay: .25),
                    ],
                  ),
                ),
              ),
              // Trust AI kartasi
              if (kAiEnabled) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    decoration:
                        BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _b(w: 58, h: 9),
                        const SizedBox(height: 14),
                        _b(h: 9, delay: .1),
                        const SizedBox(height: 8),
                        FractionallySizedBox(
                          widthFactor: .85,
                          alignment: Alignment.centerLeft,
                          child: _b(h: 9, delay: .15),
                        ),
                        const SizedBox(height: 8),
                        FractionallySizedBox(
                          widthFactor: .55,
                          alignment: Alignment.centerLeft,
                          child: _b(h: 9, delay: .2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _b(h: 50, r: 14, delay: .3),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              _row(.45, .60, 0, last: false, p: p),
              _row(.55, .40, .1, last: true, p: p),
            ],
          ),
        ),
      ],
    );
  }
}

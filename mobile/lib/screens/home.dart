// Hamkorlar (Home) ekrani — logo header, pill qidiruv, "in Trust" avatar-badge.
// Arxiv endi headerdagi tugma orqali alohida ekranda (screens/archive.dart).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../flags.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final L0 = v['L'] as Map<String, dynamic>;

    final listChildren = <Widget>[];
    if (v['skelHome'] == true) {
      for (final s in (v['skelRows'] as List)) {
        listChildren.add(_skelRow(p, s['w1'] as double, s['w2'] as double));
      }
    }
    for (final r in (v['clientRows'] as List)) {
      listChildren.add(_SwipeRow(key: ValueKey(r['id']), r: r as Map<String, dynamic>));
    }
    if (v['homeLoadingMore'] == true) {
      listChildren.add(_skelRow(p, 0.48, 0.30, border: false));
    }

    return Stack(
      children: [
        Column(
          children: [
            // Header — orqaga (<) shu qatorning o'zida (PO 2026-07-17: hub'dan
            // kirilganda alohida back-qator YO'Q, xarajat.dart headeri uslubi:
            // chap padding 16, chevron + logo bitta qatorda). Orqaga -> hub.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
              child: Row(
                children: [
                  BackBtn(onTap: () => v['goHub']()),
                  const SizedBox(width: 8),
                  // Sarlavha — menyu nomi (logo/brend hub headerida qoladi)
                  Expanded(
                    child: Tx(v['homeTitle'] as String,
                        size: 21, w: FontWeight.w700, color: p.ink, ls: -0.3,
                        maxLines: 1, ellipsis: true),
                  ),
                  const SizedBox(width: 8),
                  _filterBtn(v, p),
                  const SizedBox(width: 8),
                  _archBtn(v, p),
                  const SizedBox(width: 8),
                  _bellBtn(v, p),
                  const SizedBox(width: 8),
                  _dotsBtn(v, p),
                ],
              ),
            ),
            Padding(
              // 22 — avvalgi SizedBox(height:22) o'rnida: pastki blok o'lchamlari
              // pikselma-piksel saqlanadi (chap/o'ng 24 ham o'zgarmagan).
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Cap(L0['netCap'] as String, ls: 1.6),
                  const SizedBox(height: 6),
                  Tx(v['netText'], size: 34, w: FontWeight.w700, color: v['netColor'], ls: -0.8),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Tx('${L0['owedTo']}  ', size: 12, color: p.t2),
                        Tx(v['owedToMe'], size: 12, w: FontWeight.w600, color: p.ink),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Tx('${L0['owedBy']}  ', size: 12, color: p.t2),
                        Tx(v['owedByMe'], size: 12, w: FontWeight.w600, color: p.ink),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: p.field,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: p.hair2),
                    ),
                    child: Row(
                      children: [
                        SearchGlyph(color: p.t3, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StoreField(
                            value: v['search'],
                            onChanged: (t) => v['onSearch'](t),
                            hint: L0['searchPh'] as String,
                            style: GoogleFonts.inter(fontSize: 14, color: p.ink),
                          ),
                        ),
                        if ((v['search'] as String).isNotEmpty)
                          Tap(
                            onTap: () => v['onSearch'](''),
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: Center(child: _cross(10, p.t3)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Faol davr filtri — to'ldirilgan chip: yorliq (dropdown ochadi)
                  // + × (Jami'ga qaytarish)
                  if (v['homeFilterActive'] == true) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Tap(
                        onTap: () => v['homeFilterTap'](),
                        child: Container(
                          height: 28,
                          padding: const EdgeInsets.only(left: 12),
                          decoration: BoxDecoration(
                            color: p.ink,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Tx(v['homeFilterLabel'] as String,
                                size: 12, w: FontWeight.w600, color: p.bg),
                            Tap(
                              onTap: () => v['homeFilterReset'](),
                              child: SizedBox(
                                width: 30,
                                height: 28,
                                child: Center(child: _cross(9, p.bg)),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 140) {
                    v['homeMore']();
                  }
                  return false;
                },
                child: ListView(
                  padding: const EdgeInsets.only(top: 10, bottom: 76),
                  children: listChildren,
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 16,
          child: Tap(
            onTap: () => v['openSheetHome'](),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: p.ink,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(offset: Offset(0, 3), blurRadius: 10, color: Color(0x29000000))],
              ),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: Stack(
                    children: [
                      Positioned(left: 8, top: 0, child: Container(width: 2, height: 18, color: p.bg)),
                      Positioned(top: 8, left: 0, child: Container(width: 18, height: 2, color: p.bg)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Davr filtri dropdown — client_screen menyu uslubi (barrier + karta)
        if (v['homeFilterOpen'] == true) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => v['homeFilterClose'](),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: 56,
            right: 24,
            child: _menuCard(p, [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Cap(v['homeFilterCap'] as String, ls: 1.4),
              ),
              for (final o in (v['homeFilterOpts'] as List))
                _fltItem(p, (o as Map)['label'] as String, o['on'] == true,
                    () => o['pick']()),
              _fltItem(p, v['homeFilterCustomLabel'] as String,
                  v['homeFilterCustomOn'] == true, () {
                v['homeFilterCustomPick']();
                _pickCustomRange(context, v, p);
              }),
            ]),
          ),
        ],

        // ⋮ menyu — Xarajatlar
        if (v['homeMenuOpen'] == true) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => v['homeMenuClose'](),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: 56,
            right: 24,
            child: _menuCard(p, [
              Tap(
                onTap: () => v['homeMenuXar'](),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Tx(v['homeMenuXarLabel'] as String,
                      size: 13.5, w: FontWeight.w500, color: p.ink),
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  /// Dropdown/menyu kartasi (client_screen headeridagi menyu bilan bir uslub)
  Widget _menuCard(Pal p, List<Widget> children) {
    return Container(
      constraints: const BoxConstraints(minWidth: 186),
      decoration: BoxDecoration(
        color: p.bg,
        border: Border.all(color: p.bd2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(offset: Offset(0, 10), blurRadius: 28, color: Color(0x29000000))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }

  /// Davr varianti qatori — tanlangani nuqta bilan
  Widget _fltItem(Pal p, String label, bool on, VoidCallback onTap) {
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair2))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Tx(label, size: 13.5, w: on ? FontWeight.w600 : FontWeight.w500, color: p.ink),
            if (on) ...[
              const SizedBox(width: 12),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Maxsus davr — sana oralig'i tanlagichi (ilova palitrasida, monoxrom).
  /// Chegaralar epoch ms sifatida store'ga o'tadi; kun boshlari/oxirlari
  /// homePeriodRange'da QURILMA-LOKAL hisoblanadi.
  Future<void> _pickCustomRange(BuildContext context, Map<String, dynamic> v, Pal p) async {
    final now = DateTime.now();
    final from = v['homeFilterFrom'] as int, to = v['homeFilterTo'] as int;
    final dark = ThemeData.estimateBrightnessForColor(p.bg) == Brightness.dark;
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: (from > 0 && to > 0)
          ? DateTimeRange(
              start: DateTime.fromMillisecondsSinceEpoch(from),
              end: DateTime.fromMillisecondsSinceEpoch(to))
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
            primary: p.ink,
            onPrimary: p.bg,
            surface: p.bg,
            onSurface: p.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (r != null) {
      v['homeFilterCustom'](r.start.millisecondsSinceEpoch, r.end.millisecondsSinceEpoch);
    }
  }

  /// × belgisi (qidiruvni tozalash)
  Widget _cross(double s, Color c) {
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(angle: 0.785398, child: Container(width: s, height: 1.6, color: c)),
          Transform.rotate(angle: -0.785398, child: Container(width: s, height: 1.6, color: c)),
        ],
      ),
    );
  }

  /// Davr filtri tugmasi (header) — voronka-chiziqlar belgisi; filtr faol
  /// bo'lsa yuqori-o'ng burchakda nuqta (bell'dagi bellDot naqshi)
  Widget _filterBtn(Map<String, dynamic> v, Pal p) {
    Widget bar(double w) => Container(
          width: w,
          height: 1.6,
          decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(1)),
        );
    return Tap(
      onTap: () => v['homeFilterTap'](),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd2)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    bar(14),
                    const SizedBox(height: 2),
                    bar(9),
                    const SizedBox(height: 2),
                    bar(4),
                  ],
                ),
              ),
            ),
            if (v['homeFilterActive'] == true)
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

  /// ⋮ tugmasi (header) — qo'shimcha menyu (Xarajatlar)
  Widget _dotsBtn(Map<String, dynamic> v, Pal p) {
    Widget dot() => Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
        );
    return Tap(
      onTap: () => v['homeMenuTap'](),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd2)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              dot(),
              const SizedBox(height: 2.5),
              dot(),
              const SizedBox(height: 2.5),
              dot(),
            ],
          ),
        ),
      ),
    );
  }

  /// Arxiv tugmasi (header) — quti belgisi, bosilganda arxiv ekrani ochiladi
  Widget _archBtn(Map<String, dynamic> v, Pal p) {
    return Tap(
      onTap: () => v['openArch'](),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd2)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 4.5,
                decoration: BoxDecoration(
                  border: Border.all(color: p.ink, width: 1.4),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 1.5),
              Container(
                width: 11,
                height: 7,
                alignment: Alignment.topCenter,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: p.ink, width: 1.4),
                    right: BorderSide(color: p.ink, width: 1.4),
                    bottom: BorderSide(color: p.ink, width: 1.4),
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(2.5),
                    bottomRight: Radius.circular(2.5),
                  ),
                ),
                child: Container(
                  width: 4,
                  height: 1.4,
                  margin: const EdgeInsets.only(top: 1.4),
                  color: p.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bellBtn(Map<String, dynamic> v, Pal p) {
    return Tap(
      onTap: () => v['openNotifs'](),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd2)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 13,
                      height: 10,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: p.ink, width: 1.6),
                          top: BorderSide(color: p.ink, width: 1.6),
                          right: BorderSide(color: p.ink, width: 1.6),
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(7),
                          topRight: Radius.circular(7),
                        ),
                      ),
                    ),
                    Container(
                      width: 17,
                      height: 1.6,
                      decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(1)),
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
            if (v['bellDot'] == true)
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

  Widget _skelRow(Pal p, double w1, double w2, {bool border = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      decoration: border ? BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))) : null,
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skel(wf: w1, h: 12),
                const SizedBox(height: 8),
                Skel(wf: w2, h: 9, r: 5),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Skel(w: 64, h: 12),
        ],
      ),
    );
  }
}

/// Chapga surib arxivlash qatori.
class _SwipeRow extends StatefulWidget {
  final Map<String, dynamic> r;
  const _SwipeRow({super.key, required this.r});

  @override
  State<_SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<_SwipeRow> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final r = widget.r;
    // Kiruvchi (link) qatorlarda amal yo'q (actLabel bo'sh) — surish o'chiriladi,
    // aks holda bo'sh qora panel ochilardi (2026-08-04 audit topilmasi).
    final canSwipe = ((r['actLabel'] as String?) ?? '').isNotEmpty;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
      child: ClipRect(
        child: Stack(
          children: [
            if (canSwipe)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 96,
                child: Tap(
                  onTap: () => r['archTap'](),
                  child: Container(
                    color: p.ink,
                    alignment: Alignment.center,
                    child: Tx(r['actLabel'], size: 12, w: FontWeight.w600, color: p.bg),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset((r['tx'] as num).toDouble(), 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => r['open'](),
                onHorizontalDragStart: canSwipe
                    ? (_) {
                        _dx = 0;
                        store.swBegin(r['id']);
                      }
                    : null,
                onHorizontalDragUpdate: canSwipe
                    ? (d) {
                        _dx += d.delta.dx;
                        store.swMove(r['id'], _dx);
                      }
                    : null,
                onHorizontalDragEnd: canSwipe ? (_) => store.swEnd(r['id'], r['archAct']) : null,
                onHorizontalDragCancel: canSwipe ? () => store.swEnd(r['id'], r['archAct']) : null,
                child: Container(
                  color: p.bg,
                  child: _clientContent(p, r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clientContent(Pal p, Map<String, dynamic> r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      child: Row(
        children: [
          // Avatar + unread debt-event count bubble (top-right, «9+» cap) —
          // monochrome ink-on-bg, bellDot idiom scaled up to hold a number.
          Stack(
            clipBehavior: Clip.none,
            children: [
              TrustAvatar(initials: r['initials'] as String, size: 46, onTrust: r['inTrust'] == true),
              if (r['notifOn'] == true)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.ink,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: p.bg, width: 2),
                    ),
                    child: Tx(r['notifCountTxt'] as String,
                        size: 9.5, w: FontWeight.w700, color: p.bg),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(r['name'], size: 15.5, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                const SizedBox(height: 2),
                Tx(r['sub'], size: 12, color: p.t3),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // O'qilmagan xabarlar badge — chat UI yashirilganda KO'RSATILMAYDI (flags.dart)
          if (kChatEnabled && (r['unread'] as int? ?? 0) > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: p.green, borderRadius: BorderRadius.circular(999)),
              child: Tx('${r['unread']}', size: 10.5, w: FontWeight.w700, color: p.bg),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Tx(r['bal'], size: 15, w: FontWeight.w600, color: r['color'], tab: true),
              // Latest unread notification amount — compact chip in the balSub
              // area (only while count > 0); otherwise the plain balSub line.
              if (r['notifAmtOn'] == true) ...[
                const SizedBox(height: 3),
                Container(
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.card2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Tx(r['notifAmtTxt'] as String,
                      size: 10.5, w: FontWeight.w600, color: p.ink, tab: true),
                ),
              ] else if ((r['balSub'] as String).isNotEmpty) ...[
                const SizedBox(height: 2),
                Tx(r['balSub'], size: 11, color: p.t5),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

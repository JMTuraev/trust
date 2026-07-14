// Hamkorlar (Home) ekrani — prototype/template.html 315–418 bilan 1:1
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();

    final listChildren = <Widget>[];
    if (v['skelHome'] == true) {
      for (final s in (v['skelRows'] as List)) {
        listChildren.add(_skelRow(p, s['w1'] as double, s['w2'] as double));
      }
    }
    for (final r in (v['clientRows'] as List)) {
      listChildren.add(_SwipeRow(key: ValueKey(r['id']), r: r as Map<String, dynamic>, isArch: false));
    }
    if (v['homeLoadingMore'] == true) {
      listChildren.add(_skelRow(p, 0.48, 0.30, border: false));
    }
    if (v['hasArch'] == true) {
      listChildren.add(const Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 6),
        child: Cap('ARXIV', ls: 1.6),
      ));
      for (final ar in (v['archRows'] as List)) {
        listChildren.add(_SwipeRow(key: ValueKey(ar['id']), r: ar as Map<String, dynamic>, isArch: true));
      }
    }

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Tx('Trust', size: 22, w: FontWeight.w700, color: p.ink, ls: -0.3),
                      Row(
                        children: [
                          Tx('Ishonchli hisob-kitob', size: 11, w: FontWeight.w500, color: p.t4, ls: 0.4),
                          const SizedBox(width: 14),
                          _bellBtn(v, p),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Cap('SOF BALANS', ls: 1.6),
                  const SizedBox(height: 6),
                  Tx(v['netText'], size: 34, w: FontWeight.w700, color: v['netColor'], ls: -0.8),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Tx('Sizga qarz  ', size: 12, color: p.t2),
                        Tx(v['owedToMe'], size: 12, w: FontWeight.w600, color: p.ink),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Tx('Qarzingiz  ', size: 12, color: p.t2),
                        Tx(v['owedByMe'], size: 12, w: FontWeight.w600, color: p.ink),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(10)),
                    child: StoreField(
                      value: v['search'],
                      onChanged: (t) => v['onSearch'](t),
                      hint: 'Qidirish',
                      style: GoogleFonts.inter(fontSize: 14, color: p.ink),
                    ),
                  ),
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
      ],
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

/// Chapga surib arxivlash/qaytarish qatori.
class _SwipeRow extends StatefulWidget {
  final Map<String, dynamic> r;
  final bool isArch;
  const _SwipeRow({super.key, required this.r, required this.isArch});

  @override
  State<_SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<_SwipeRow> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final r = widget.r;
    final isArch = widget.isArch;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 96,
              child: Tap(
                onTap: () => (isArch ? r['restore'] : r['archTap'])(),
                child: Container(
                  color: p.ink,
                  alignment: Alignment.center,
                  child: Tx(isArch ? 'Qaytarish' : r['actLabel'], size: 12, w: FontWeight.w600, color: p.bg),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset((r['tx'] as num).toDouble(), 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => (isArch ? r['rowTap'] : r['open'])(),
                onHorizontalDragStart: (_) {
                  _dx = 0;
                  store.swBegin(r['id']);
                },
                onHorizontalDragUpdate: (d) {
                  _dx += d.delta.dx;
                  store.swMove(r['id'], _dx);
                },
                onHorizontalDragEnd: (_) => store.swEnd(r['id'], isArch ? r['restoreAct'] : r['archAct']),
                onHorizontalDragCancel: () => store.swEnd(r['id'], isArch ? r['restoreAct'] : r['archAct']),
                child: Container(
                  color: p.bg,
                  child: isArch ? _archContent(p, r) : _clientContent(p, r),
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
                child: Center(child: Tx(r['initials'], size: 14, w: FontWeight.w600, color: p.ink)),
              ),
              if (r['onTrust'] == true) const TrustBadge(),
              if (r['oneSided'] == true) const OneSidedBadge(),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Tx(r['bal'], size: 15, w: FontWeight.w600, color: r['color'], tab: true),
              const SizedBox(height: 2),
              Tx(r['balSub'], size: 11, color: p.t5),
            ],
          ),
        ],
      ),
    );
  }

  Widget _archContent(Pal p, Map<String, dynamic> r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 24),
      child: Opacity(
        opacity: 0.75,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
              child: Center(child: Tx(r['initials'], size: 11.5, w: FontWeight.w600, color: p.ink)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Tx(r['name'], size: 14, w: FontWeight.w500, color: p.t1, maxLines: 1, ellipsis: true),
            ),
            const SizedBox(width: 12),
            Tx('Arxivda', size: 11, color: p.t4),
          ],
        ),
      ),
    );
  }
}

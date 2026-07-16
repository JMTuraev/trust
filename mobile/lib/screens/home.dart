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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const TrustMark(size: 27, boxed: true),
                          const SizedBox(width: 9),
                          Tx('Trust', size: 21, w: FontWeight.w700, color: p.ink, ls: -0.3),
                        ],
                      ),
                      Row(
                        children: [
                          _archBtn(v, p),
                          const SizedBox(width: 10),
                          _bellBtn(v, p),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
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
                onHorizontalDragStart: (_) {
                  _dx = 0;
                  store.swBegin(r['id']);
                },
                onHorizontalDragUpdate: (d) {
                  _dx += d.delta.dx;
                  store.swMove(r['id'], _dx);
                },
                onHorizontalDragEnd: (_) => store.swEnd(r['id'], r['archAct']),
                onHorizontalDragCancel: () => store.swEnd(r['id'], r['archAct']),
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
          TrustAvatar(initials: r['initials'] as String, size: 46, onTrust: r['onTrust'] == true),
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
              const SizedBox(height: 2),
              Tx(r['balSub'], size: 11, color: p.t5),
            ],
          ),
        ],
      ),
    );
  }
}

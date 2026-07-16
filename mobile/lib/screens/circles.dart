// Circles — asosiy tab (ro'yxat + bo'sh holat). Prototip frame 1 va 4 bilan 1:1.
// + "Taklif orqali qo'shilish" kirish nuqtasi (kod bilan qo'shilish sheet'i).
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';
import '../circles_data.dart';
import '../circle_ui.dart';
import '../circles_l10n.dart';
import 'circle_join.dart' show showJoinByCode;

class CirclesScreen extends StatelessWidget {
  const CirclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final circles = circlesRepo.all();
    final loading = v['circlesLoading'] == true;

    if (circles.isEmpty) {
      if (loading) return _loading(p);
      // Tarmoq xatosi: marketing bo'sh-holati EMAS — aniq xato + qayta urinish
      if (v['circlesError'] != null && v['circlesLoaded'] != true) return _error(v, p);
      return _empty(context, v, p);
    }

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(cf('circlesTitle'), size: 22, w: FontWeight.w700, color: p.ink, ls: -0.3),
                  const SizedBox(height: 3),
                  Tx(
                    cf('listSummary', {
                      'n': '${circlesRepo.active().length}',
                      'amt': money(circlesRepo.monthlySaving, circlesRepo.savingSymbol),
                    }),
                    size: 12.5,
                    color: p.t2,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final c in circles) _row(c, v, p),
                  // Do'stidan kod olganlar uchun kirish nuqtasi (prototip .link uslubi)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: CircleLink(label: cf('joinWithInvite'), onTap: () => showJoinByCode(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 18,
          child: Tap(
            onTap: () => v['openCircleCreate'](),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: p.ink,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(offset: Offset(0, 3), blurRadius: 10, color: Color(0x29000000))],
              ),
              child: Center(child: Icon(Icons.add_rounded, size: 24, color: p.bg)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(Circle c, Map<String, dynamic> v, Pal p) {
    // Avatar to'plami boshqa a'zolarni ko'rsatadi (o'zini emas); +N esa qolganlar (o'zi ham kirib)
    final others = c.members.where((m) => !m.isYou).toList();
    final avs = <AvSpec>[for (final m in others.take(3)) AvSpec(m.initials, m.tint)];
    if (c.members.length > avs.length) avs.add(AvSpec('+${c.members.length - avs.length}', Tint.more));

    final invited = c.myStatus == 'invited';
    Widget turn;
    if (invited) {
      turn = Tx(cf('joinBtn'), size: 11.5, w: FontWeight.w600, color: p.green);
    } else if (c.status == CircleStatus.complete) {
      turn = Tx(cf('complete'), size: 11.5, color: p.t3);
    } else if (c.status == CircleStatus.closed) {
      turn = Tx(cf('closedTag'), size: 11.5, color: p.t3);
    } else if (c.isMyTurn) {
      turn = Tx(cf('yourTurnNext'), size: 11.5, w: FontWeight.w600, color: p.green);
    } else {
      turn = Tx(cf('receivesNext', {'name': firstName(c.currentRecipient?.name ?? '')}), size: 11.5, color: p.t1);
    }

    return Tap(
      onTap: () => invited ? v['openCircleJoin'](c.id) : v['openCircle'](c.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Tx(c.name, size: 14.5, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true)),
                const SizedBox(width: 10),
                Tx(money(c.pool, c.currency), size: 14, w: FontWeight.w600, color: p.ink, tab: true),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Tx(cf('membersLine', {'n': '${c.members.length}', 'amt': money(c.amount, c.currency)}), size: 12, color: p.t2),
                Tx(cf('roundOf', {'a': '${c.currentRound.index}', 'b': '${c.roundsTotal}'}), size: 11.5, color: p.t3),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AvStack(items: avs, size: 24),
                turn,
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Yuklab bo'lmadi (tarmoq/server) — xabar + qayta urinish tugmasi.
  Widget _error(Map<String, dynamic> v, Pal p) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tx(cf('circlesTitle'), size: 22, w: FontWeight.w700, color: p.ink, ls: -0.3),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 26, color: p.t3),
                    const SizedBox(height: 12),
                    Tx(cf('loadFailed'), size: 14, w: FontWeight.w600, color: p.ink, align: TextAlign.center),
                    const SizedBox(height: 5),
                    Tx('${v['circlesError'] ?? ''}', size: 12, color: p.t2, align: TextAlign.center, lh: 16.8),
                    const SizedBox(height: 16),
                    Tap(
                      onTap: () => v['reloadCircles'](),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                        decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(20)),
                        child: Tx(cf('retry'), size: 12.5, w: FontWeight.w600, color: p.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _loading(Pal p) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tx(cf('circlesTitle'), size: 22, w: FontWeight.w700, color: p.ink, ls: -0.3),
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4, color: p.t3)),
            ),
          ),
        ],
      );

  Widget _empty(BuildContext context, Map<String, dynamic> v, Pal p) {
    Widget step(String n, String text) => Padding(
          padding: const EdgeInsets.only(top: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                child: Tx(n, size: 12, w: FontWeight.w600, color: p.bg),
              ),
              const SizedBox(width: 11),
              Expanded(child: Tx(text, size: 12.5, color: p.t1, lh: 18.75)),
            ],
          ),
        );

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _illustration(p)),
                    const SizedBox(height: 16),
                    Center(child: Tx(cf('whatIs'), size: 18, w: FontWeight.w700, color: p.ink, ls: -0.3)),
                    const SizedBox(height: 6),
                    Tx(cf('whatIsSub'), size: 13, color: p.t1, lh: 20.15, align: TextAlign.center),
                    const SizedBox(height: 6),
                    step('1', cf('step1')),
                    step('2', cf('step2')),
                    step('3', cf('step3')),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: const EdgeInsets.only(top: 1), child: ShieldCheck(size: 15, color: p.t2)),
                        const SizedBox(width: 7),
                        Expanded(child: Tx(cf('proofLine'), size: 11.5, color: p.t2, lh: 16.7)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          child: Column(
            children: [
              CircleBtn(label: cf('createFirst'), onTap: () => v['openCircleCreate']()),
              // Kod bilan qo'shilish — do'sti taklif kodi yuborganlar birinchi
              // qadamda ham adashmasin (prototip .btn ostidagi .link uslubi)
              CircleLink(label: cf('joinWithInvite'), onTap: () => showJoinByCode(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _illustration(Pal p) {
    return SizedBox(
      width: 128,
      height: 112,
      child: Stack(
        children: [
          // Aylanma (rotation) motivi — dashli yoy + strelka (prototip frame 4 SVG)
          Positioned.fill(child: CustomPaint(painter: _RotArc(p.bd))),
          Positioned(
            left: 43,
            top: 35,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.field, shape: BoxShape.circle),
              child: Tx('\$', size: 19, w: FontWeight.w700, color: p.ink),
            ),
          ),
          const Positioned(left: 53, top: 4, child: CAvatar(initials: 'MR', size: 22, tint: Tint.warm)),
          const Positioned(left: 94, top: 61, child: CAvatar(initials: 'AK', size: 22, tint: Tint.green)),
          const Positioned(left: 53, top: 86, child: CAvatar(initials: 'DC', size: 22, tint: Tint.blue)),
          const Positioned(left: 12, top: 61, child: CAvatar(initials: 'You', size: 22, tint: Tint.me)),
        ],
      ),
    );
  }
}

/// Bo'sh holat illyustratsiyasi uchun dashli aylanma yoy + strelka.
class _RotArc extends CustomPainter {
  final Color color;
  _RotArc(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Yoy: (64,15) dan (103,43) gacha, radius 41 (prototip "a41 41 0 0 1 39 28")
    final arc = Path()
      ..moveTo(64, 15)
      ..arcToPoint(const Offset(103, 43), radius: const Radius.circular(41), clockwise: true);
    for (final metric in arc.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, (dist + 3).clamp(0.0, metric.length)), paint);
        dist += 7; // 3 dash + 4 gap
      }
    }
    // Strelka uchi (103,43): yuqoriga va chapga qisqa chiziqlar
    canvas.drawLine(const Offset(103, 43), const Offset(103, 37), paint);
    canvas.drawLine(const Offset(103, 43), const Offset(108, 42), paint);
  }

  @override
  bool shouldRepaint(covariant _RotArc old) => old.color != color;
}

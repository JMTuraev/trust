// Pastki navigatsiya paneli — prototype/template.html 684–720 bilan 1:1
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class TrustTabBar extends StatelessWidget {
  const TrustTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final Pal p = curPal();
    final L0 = v['L'] as Map<String, dynamic>;
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.hair)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 9, 6, 2),
            child: Row(
              children: [
                _tab(
                  onTap: () => v['goHome'](),
                  color: v['cMij'],
                  label: L0['navClients'] as String,
                  icon: SizedBox(
                    height: 20,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: v['cMij'], width: 1.6),
                          ),
                        ),
                        Container(
                          width: 16,
                          height: 7,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: v['cMij'], width: 1.6),
                              top: BorderSide(color: v['cMij'], width: 1.6),
                              right: BorderSide(color: v['cMij'], width: 1.6),
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                              bottomLeft: Radius.circular(2),
                              bottomRight: Radius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _tab(
                  onTap: () => v['goXarajat'](),
                  color: v['cXar'],
                  label: L0['navXar'] as String,
                  icon: SizedBox(
                    height: 20,
                    child: Center(
                      child: Container(
                        width: 18,
                        height: 14,
                        decoration: BoxDecoration(
                          border: Border.all(color: v['cXar'], width: 1.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 2,
                              bottom: -4,
                              child: CustomPaint(
                                size: const Size(4, 4),
                                painter: _TailPainter(v['cXar']),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _tab(
                  onTap: () => v['goMoliya'](),
                  color: v['cMol'],
                  label: L0['navFin'] as String,
                  icon: SizedBox(
                    height: 20,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bar(9, v['cMol']),
                          const SizedBox(width: 2.5),
                          _bar(15, v['cMol']),
                          const SizedBox(width: 2.5),
                          _bar(12, v['cMol']),
                        ],
                      ),
                    ),
                  ),
                ),
                _tab(
                  onTap: () => v['goProfil'](),
                  color: v['cProf'],
                  label: L0['navProfile'] as String,
                  icon: Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: v['cProf'], width: 1.6),
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: v['cProf']),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Center(
              child: Container(
                width: 120,
                height: 4,
                decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double h, Color c) => Container(
        width: 4,
        height: h,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(1.5)),
      );

  Widget _tab({
    required VoidCallback onTap,
    required Color color,
    required String label,
    required Widget icon,
  }) {
    return Expanded(
      child: Tap(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 4),
              Tx(label, size: 10, w: FontWeight.w600, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Xarajat ikonchasidagi kichik "dum" uchburchagi (CSS border-triangle o'rnida).
class _TailPainter extends CustomPainter {
  final Color color;
  const _TailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) => old.color != color;
}

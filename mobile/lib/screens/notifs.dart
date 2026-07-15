// Bildirishnomalar ekrani — prototype/template.html 1048–1096 bilan 1:1
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class NotifsScreen extends StatelessWidget {
  const NotifsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final rows = (v['notifRows'] as List).cast<Map<String, dynamic>>();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
          child: Row(
            children: [
              BackBtn(onTap: v['closeNotifs']),
              const SizedBox(width: 10),
              Tx('Bildirishnomalar', size: 16, w: FontWeight.w700, color: p.ink),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final n in rows)
                Tap(
                  onTap: n['tap'],
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 15, 20, 15),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(top: 1),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: p.bd2),
                          ),
                          child: _icon(n, p),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Tx(n['title'], size: 14, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                                  ),
                                  if (n['unread'] == true) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                                    ),
                                  ],
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Tx(n['detail'], size: 12.5, color: p.t3, lh: 18.1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Tx(n['time'], size: 11, color: p.t5, maxLines: 1),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _icon(Map<String, dynamic> n, Pal p) {
    if (n['isReq'] == true) {
      return Tx('?', size: 14, w: FontWeight.w700, color: p.ink);
    }
    if (n['isOk'] == true) {
      return Transform.translate(
        offset: const Offset(0, -3),
        child: Transform.rotate(
          angle: -0.785398,
          child: Container(
            width: 10,
            height: 5,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: p.ink, width: 2),
                bottom: BorderSide(color: p.ink, width: 2),
              ),
            ),
          ),
        ),
      );
    }
    if (n['isRem'] == true) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: p.ink, width: 1.6),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 5.5, top: 2.5, child: Container(width: 1.6, height: 4, color: p.ink)),
            Positioned(left: 5.5, top: 5.5, child: Container(width: 4, height: 1.6, color: p.ink)),
          ],
        ),
      );
    }
    if (n['isEdit'] == true) {
      return Tx('±', size: 13, w: FontWeight.w700, color: p.ink);
    }
    if (n['isRej'] == true) {
      return Transform.translate(
        offset: const Offset(0, -1),
        child: Tx('×', size: 15, w: FontWeight.w600, color: p.ink),
      );
    }
    return const SizedBox.shrink();
  }
}

// Dalil (receipt) ekrani — prototype/template.html 1132–1193 bilan 1:1
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final receipt = (v['receipt'] as Map).cast<String, dynamic>();

    Widget detailRow(String label, Widget value, {bool border = true}) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: border
            ? BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2)))
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Tx(label, size: 13, color: p.t2),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(alignment: Alignment.centerRight, child: value),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
          child: Row(
            children: [
              BackBtn(onTap: () => receipt['close']()),
              const SizedBox(width: 10),
              Tx('Dalil', size: 16, w: FontWeight.w700, color: p.ink),
              const Spacer(),
              Tx(receipt['id'] as String, size: 12, color: p.t3, tab: true),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            children: [
              Column(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 9,
                        decoration: BoxDecoration(
                          border: Border.all(color: p.ink, width: 1.6),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -1),
                        child: Container(
                          width: 18,
                          height: 13,
                          decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tx('QULFLANGAN YOZUV', size: 10.5, w: FontWeight.w600, color: p.t2, ls: 1.8),
                        if (receipt['corrected'] == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: p.bd),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: Tx('TUZATILDI', size: 9.5, w: FontWeight.w700, color: p.ink, ls: 1.2),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Tx(receipt['amount'] as String, size: 32, w: FontWeight.w700, color: p.ink, ls: -0.6, tab: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Tx(receipt['type'] as String, size: 14, color: p.t1),
                  ),
                  if (receipt['editPending'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: p.bd),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                        child: Tx("O'zgartirish kutilmoqda · ${receipt['editLine']}", size: 12, color: p.t1),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 6),
                child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashedLinePainter(color: p.bd)),
              ),
              detailRow('Kimdan', Tx(receipt['from'] as String, size: 13.5, w: FontWeight.w600, color: p.ink, maxLines: 1)),
              detailRow('Kimga', Tx(receipt['to'] as String, size: 13.5, w: FontWeight.w600, color: p.ink, maxLines: 1)),
              detailRow('Sana', Tx(receipt['date'] as String, size: 13.5, w: FontWeight.w600, color: p.ink, maxLines: 1)),
              detailRow('Holat', Tx('Daftar yozuvi — tarixi saqlanadi', size: 13.5, w: FontWeight.w600, color: p.ink, maxLines: 1), border: false),
              if (receipt['corrected'] == true) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashedLinePainter(color: p.bd)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Cap("O'ZGARISHLAR TARIXI", ls: 1.6),
                      for (final h in (receipt['histRows'] as List).cast<Map<String, dynamic>>())
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Tx(h['txt'] as String, size: 12.5, color: p.t1),
                        ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Tx(
                  "Ushbu yozuv o'chirib bo'lmaydi. O'zgartirish faqat ikki tomon roziligi bilan amalga oshiriladi.",
                  size: 11.5,
                  color: p.t4,
                  lh: 18.4,
                  align: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Column(
                  children: [
                    InkBtn(label: 'Ulashish (PDF)', onTap: () => receipt['share'](), h: 48, fs: 14.5),
                    const SizedBox(height: 10),
                    GhostBtn(label: "O'zgartirish so'rovi", onTap: () => receipt['change'](), h: 48, fs: 14.5),
                    const SizedBox(height: 10),
                    Tap(
                      onTap: () => receipt['archive'](),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        child: Tx('Arxivlash', size: 13.5, w: FontWeight.w500, color: p.t2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    double x = 0;
    const dash = 4.0, gap = 3.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => oldDelegate.color != color;
}

// Moliya ekrani — prototype/template.html 420–465 bilan 1:1
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class MoliyaScreen extends StatelessWidget {
  const MoliyaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final totals = (v['molTotals'] as List).cast<Map<String, dynamic>>();
    final bars = (v['bars'] as List).cast<Map<String, dynamic>>();
    final reminders = (v['reminders'] as List).cast<Map<String, dynamic>>();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Tx('Moliya', size: 22, w: FontWeight.w700, color: p.ink, ls: -0.3),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
            children: [
              for (final t in totals)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 24),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: p.hair2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Tx(t['label'], size: 13.5, color: p.t1),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Tx(t['value'], size: 15, w: FontWeight.w600, color: t['color'], tab: true),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Cap('OYLIK AYLANMA', ls: 1.6),
                    Container(
                      height: 120,
                      margin: const EdgeInsets.only(top: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < bars.length; i++) ...[
                            if (i > 0) const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Tx(bars[i]['val'], size: 10, color: p.t3, tab: true),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    constraints: const BoxConstraints(maxWidth: 30),
                                    height: bars[i]['h'],
                                    decoration: BoxDecoration(
                                      color: bars[i]['bg'],
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Tx(bars[i]['label'], size: 11, color: p.t3),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Tx("mln so'm hisobida", size: 11, color: p.t5),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: const Cap('ESLATMALAR', ls: 1.6),
                ),
              ),
              for (final rm in reminders)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 24),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: p.hair2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tx(rm['name'], size: 14.5, w: FontWeight.w600, color: p.ink),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Tx(rm['sub'], size: 12, color: p.t3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (rm['canRemind'] == true)
                        Tap(
                          onTap: rm['remind'],
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: p.bd),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Tx('Eslatish', size: 12, w: FontWeight.w600, color: p.ink),
                          ),
                        ),
                      if (rm['cooling'] == true)
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: p.hair2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Tx(rm['coolText'], size: 11, w: FontWeight.w500, color: p.t4, maxLines: 1),
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

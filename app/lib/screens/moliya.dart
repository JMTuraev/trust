import 'package:flutter/material.dart';
import '../nav.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class MoliyaScreen extends StatelessWidget {
  final Nav nav;
  const MoliyaScreen(this.nav);

  @override
  Widget build(BuildContext c) {
    final p = nav.p;
    final totals = [
      ['Umumiy sizga qarz', money(4230000), p.green],
      ['Umumiy qarzingiz', money(1930000), p.red],
      ['Bu oy daromad', money(6800000), p.green],
      ['Bu oy xarajat', money(2450000), p.red],
    ];
    final bars = [0.4, 0.7, 0.55, 0.9, 0.65, 1.0];
    final labels = ['Fev', 'Mar', 'Apr', 'May', 'Iyn', 'Iyl'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Text('Moliya', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.ink, letterSpacing: -0.3)),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
          for (final t in totals)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(t[0] as String, style: TextStyle(fontSize: 13.5, color: p.t1)),
                Text(t[1] as String, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t[2] as Color)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MicroLabel('OYLIK AYLANMA', p),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < bars.length; i++)
                      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text((bars[i] * 8).toStringAsFixed(1), style: TextStyle(fontSize: 10, color: p.t3)),
                        const SizedBox(height: 6),
                        Container(width: 30, height: 90 * bars[i],
                            decoration: BoxDecoration(color: p.ink, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))),
                        const SizedBox(height: 6),
                        Text(labels[i], style: TextStyle(fontSize: 11, color: p.t3)),
                      ])),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('mln so’m hisobida', style: TextStyle(fontSize: 11, color: p.t5)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
            child: MicroLabel('ESLATMALAR', p),
          ),
          for (final r in partners.where((x) => x.balance > 0).take(2))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: p.ink)),
                  const SizedBox(height: 2),
                  Text('${money(r.balance)} so’m · muddat o’tgan', style: TextStyle(fontSize: 12, color: p.t3)),
                ])),
                Container(
                  height: 32, padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Text('Eslatish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.ink)),
                ),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

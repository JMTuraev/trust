import 'package:flutter/material.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';

class NewOpSheet extends StatefulWidget {
  final Nav nav;
  const NewOpSheet(this.nav);
  @override
  State<NewOpSheet> createState() => _NewOpSheetState();
}

class _NewOpSheetState extends State<NewOpSheet> {
  int type = 0; // 0 daromad(men berdim) ... simple: types
  final types = const ['Qarz berdim', 'Qarz oldim', 'Qaytardim', 'Qaytarildi'];

  @override
  Widget build(BuildContext c) {
    final p = widget.nav.p;
    return Stack(children: [
      GestureDetector(onTap: widget.nav.closeSheet, child: Container(color: p.dim)),
      Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 26),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 38, height: 4,
                decoration: BoxDecoration(color: p.bd, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text('Yangi operatsiya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 20),
            MicroLabel('TURI', p),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 3.6,
              children: [
                for (int i = 0; i < types.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => type = i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: type == i ? p.ink : Colors.transparent,
                        border: Border.all(color: type == i ? p.ink : p.bd),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(types[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: type == i ? p.bg : p.ink)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            MicroLabel('SUMMA', p),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Container(
                height: 52,
                decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Text('0', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.t5)),
              )),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(width: 56, height: 52, alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.ink, borderRadius: const BorderRadius.horizontal(left: Radius.circular(11))),
                      child: Text('so’m', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.bg))),
                  Container(width: 56, height: 52, alignment: Alignment.center,
                      child: Text('\$', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.t2))),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            MicroLabel('IZOH', p),
            const SizedBox(height: 10),
            Container(height: 44,
                decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.centerLeft,
                child: Text('Masalan: mol savdosi uchun', style: TextStyle(fontSize: 14, color: p.t5))),
            const SizedBox(height: 24),
            InkButton('Yozuv qo’shish', widget.nav.closeSheet, p),
            const SizedBox(height: 12),
            Center(child: Text('Ikkinchi tomon tasdiqlagach dalil kuchiga ega bo’ladi',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: p.t4, height: 1.5))),
          ]),
        ),
      ),
    ]);
  }
}

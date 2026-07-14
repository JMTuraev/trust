import 'package:flutter/material.dart';
import '../nav.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class NewOpSheet extends StatefulWidget {
  final Nav nav;
  const NewOpSheet(this.nav);
  @override
  State<NewOpSheet> createState() => _NewOpSheetState();
}

class _NewOpSheetState extends State<NewOpSheet> {
  int type = 0;
  int cur = 0;
  int partner = 0;
  final types = const ['Qarz berdim', 'Qarz oldim', 'Qaytardim', 'Menga qaytarildi'];

  @override
  Widget build(BuildContext c) {
    final p = widget.nav.p;
    final showPartner = widget.nav.client == null;
    return BottomSheetShell(p: p, onClose: () => widget.nav.close('newop'), child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Yangi operatsiya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.ink)),
        if (widget.nav.client != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(7, 5, 12, 5),
            decoration: BoxDecoration(border: Border.all(color: p.bd2), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 22, height: 22, decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(widget.nav.client!.initials, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: p.bg))),
              const SizedBox(width: 7),
              Text('${widget.nav.client!.name} uchun', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.ink)),
            ]),
          ),
        ],
        if (showPartner) ...[
          const SizedBox(height: 20),
          MicroLabel('HAMKOR', p),
          const SizedBox(height: 10),
          SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (int i = 0; i < partners.length; i++) Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => partner = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: partner == i ? p.ink : Colors.transparent,
                    border: Border.all(color: partner == i ? p.ink : p.bd),
                    borderRadius: BorderRadius.circular(17)),
                  child: Text(partners[i].name.split(' ').first,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: partner == i ? p.bg : p.ink)),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => widget.nav.open('newpartner'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(17)),
                child: Text('＋ Yangi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.ink)),
              ),
            ),
          ])),
        ],
        const SizedBox(height: 20),
        MicroLabel('TURI', p),
        const SizedBox(height: 10),
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 3.6,
          children: [ for (int i = 0; i < types.length; i++)
            GestureDetector(onTap: () => setState(() => type = i),
              child: Container(
                decoration: BoxDecoration(color: type == i ? p.ink : Colors.transparent,
                    border: Border.all(color: type == i ? p.ink : p.bd), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(types[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: type == i ? p.bg : p.ink)),
              )) ]),
        const SizedBox(height: 20),
        MicroLabel('SUMMA', p),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Container(height: 52,
              decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.centerLeft,
              child: Text('0', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.t5)))),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              for (int i = 0; i < 2; i++) GestureDetector(
                onTap: () => setState(() => cur = i),
                child: Container(width: 56, height: 52, alignment: Alignment.center,
                    decoration: BoxDecoration(color: cur == i ? p.ink : Colors.transparent,
                        borderRadius: BorderRadius.horizontal(
                            left: i == 0 ? const Radius.circular(11) : Radius.zero,
                            right: i == 1 ? const Radius.circular(11) : Radius.zero)),
                    child: Text(i == 0 ? 'so’m' : '\$', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cur == i ? p.bg : p.t2))),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        MicroLabel('IZOH', p),
        const SizedBox(height: 10),
        Container(height: 44, decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.centerLeft,
            child: Text('Masalan: mol savdosi uchun', style: TextStyle(fontSize: 14, color: p.t5))),
        const SizedBox(height: 24),
        InkButton('Yozuv qo’shish', () => widget.nav.close('newop'), p),
        const SizedBox(height: 12),
        Center(child: Text('Ikkinchi tomon tasdiqlagach dalil kuchiga ega bo’ladi',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: p.t4, height: 1.5))),
      ]),
    );
  }
}

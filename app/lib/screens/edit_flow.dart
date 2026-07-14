import 'package:flutter/material.dart';
import '../nav.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class EditFormSheet extends StatelessWidget {
  final Nav nav;
  const EditFormSheet(this.nav);
  @override
  Widget build(BuildContext c) {
    final p = nav.p;
    return BottomSheetShell(p: p, onClose: () => nav.close('editform'), child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('O’zgartirish so’rovi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.ink)),
        const SizedBox(height: 6),
        Text('O’zgarish faqat ikkinchi tomon tasdiqlagandan keyin kuchga kiradi. Asl yozuv o’chirilmaydi.',
            style: TextStyle(fontSize: 12.5, color: p.t3, height: 1.5)),
        const SizedBox(height: 20),
        MicroLabel('ESKI SUMMA', p),
        const SizedBox(height: 8),
        Text(money(500000), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.t3, decoration: TextDecoration.lineThrough)),
        const SizedBox(height: 18),
        MicroLabel('YANGI SUMMA', p),
        const SizedBox(height: 10),
        Container(height: 52, decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.centerLeft,
            child: Text('480 000', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.t5))),
        const SizedBox(height: 18),
        MicroLabel('YANGI IZOH', p),
        const SizedBox(height: 10),
        Container(height: 44, decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.centerLeft,
            child: Text('Izoh (ixtiyoriy)', style: TextStyle(fontSize: 14, color: p.t5))),
        const SizedBox(height: 22),
        InkButton('So’rov yuborish', () { nav.close('editform'); nav.open('review'); }, p),
      ]),
    );
  }
}

class ReviewScreen extends StatelessWidget {
  final Nav nav;
  const ReviewScreen(this.nav);
  @override
  Widget build(BuildContext c) {
    final p = nav.p;
    return Container(color: p.bg, child: Column(children: [
      OverlayHeader(p: p, title: 'O’zgartirish so’rovi', onBack: () => nav.close('review')),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
        child: Column(children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
              alignment: Alignment.center, child: Text('SA', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.ink))),
          const SizedBox(height: 14),
          Text('Sardor Aliyev yozuvni o’zgartirishni so’ramoqda', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.ink, height: 1.5)),
          const SizedBox(height: 6),
          Text('Mol savdosi · 12-iyul', style: TextStyle(fontSize: 12.5, color: p.t3)),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(border: Border.all(color: p.bd2), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('ESKI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: p.t2)),
                    Text(money(780000), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.t3, decoration: TextDecoration.lineThrough)),
                  ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('YANGI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: p.t2)),
                    Text(money(760000), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink)),
                  ])),
            ]),
          ),
          const SizedBox(height: 14),
          Text('Tasdiqlasangiz yozuv yangilanadi, eski qiymat tarixda saqlanadi. Rad etsangiz asl yozuv o’zgarishsiz qoladi.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: p.t4, height: 1.6)),
          const SizedBox(height: 22),
          InkButton('Tasdiqlash', () => nav.close('review'), p),
          const SizedBox(height: 10),
          GestureDetector(onTap: () => nav.close('review'), child: Container(height: 50,
              decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center, child: Text('Rad etish', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.ink)))),
        ]),
      )),
    ]));
  }
}

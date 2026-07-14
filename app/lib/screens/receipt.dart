import 'package:flutter/material.dart';
import '../nav.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ReceiptScreen extends StatelessWidget {
  final Nav nav;
  const ReceiptScreen(this.nav);
  @override
  Widget build(BuildContext c) {
    final p = nav.p;
    return Container(color: p.bg, child: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
        child: Row(children: [
          GestureDetector(onTap: nav.closeReceipt,
              child: SizedBox(width: 34, height: 34, child: Icon(Icons.arrow_back_ios_new, size: 18, color: p.ink))),
          Text('Dalil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.ink)),
          const Spacer(),
          Text('#TR-000482', style: TextStyle(fontSize: 12, color: p.t3)),
        ]),
      ),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(28, 28, 28, 24), children: [
        Column(children: [
          Icon(Icons.lock_outline, size: 26, color: p.ink),
          const SizedBox(height: 12),
          Text('QULFLANGAN YOZUV', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.8, color: p.t2)),
          const SizedBox(height: 14),
          Text('+${money(500000)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 6),
          Text('Daromad', style: TextStyle(fontSize: 14, color: p.t1)),
        ]),
        const SizedBox(height: 24),
        _row('Kimdan', 'Akmal Karimov', p),
        _row('Kimga', 'Jasur Toshmatov', p),
        _row('Sana', '14-iyul 2026, 14:20', p),
        _row('Tasdiqlash kodi', '4 8 2 9 1', p),
        _row('Holat', 'Ikki tomonlama tasdiqlangan', p, last: true),
        const SizedBox(height: 16),
        Text('Ushbu yozuv o’chirib bo’lmaydi. O’zgartirish faqat ikki tomon roziligi bilan amalga oshiriladi.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: p.t4, height: 1.6)),
        const SizedBox(height: 22),
        InkButton('Ulashish (PDF)', () {}, p, height: 48),
        const SizedBox(height: 10),
        Container(height: 48,
            decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text('O’zgartirish so’rovi', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: p.ink))),
      ])),
    ]));
  }

  Widget _row(String k, String v, P p, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.hair2))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(fontSize: 13, color: p.t2)),
          Flexible(child: Text(v, textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.ink))),
        ]),
      );
}

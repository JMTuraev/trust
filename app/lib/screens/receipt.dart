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
      OverlayHeader(p: p, title: 'Dalil', onBack: () => nav.close('receipt'), trailing: '#TR-000482'),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(28, 28, 28, 24), children: [
        Column(children: [
          Icon(Icons.lock_outline, size: 26, color: p.ink),
          const SizedBox(height: 12),
          Text('QULFLANGAN YOZUV', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.8, color: p.t2)),
          const SizedBox(height: 14),
          Text('+${money(500000)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 6),
          Text('Qarz berdim', style: TextStyle(fontSize: 14, color: p.t1)),
        ]),
        const SizedBox(height: 24),
        _row('Kimdan', 'Jasur Toshmatov', p),
        _row('Kimga', 'Akmal Karimov', p),
        _row('Sana', '14-iyul 2026, 14:20', p),
        _row('Tasdiqlash kodi', '4 8 2 9 1', p),
        _row('Holat', 'Ikki tomonlama tasdiqlangan', p, last: true),
        const SizedBox(height: 16),
        Text('Ushbu yozuv o’chirib bo’lmaydi. O’zgartirish faqat ikki tomon roziligi bilan amalga oshiriladi.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: p.t4, height: 1.6)),
        const SizedBox(height: 22),
        InkButton('Ulashish (PDF)', () => nav.open('pdf'), p, height: 48),
        const SizedBox(height: 10),
        _outline('O’zgartirish so’rovi', () => nav.open('editform'), p),
        const SizedBox(height: 4),
        GestureDetector(onTap: () => nav.close('receipt'), child: Container(height: 44, alignment: Alignment.center,
            child: Text('Arxivlash', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: p.t2)))),
      ])),
    ]));
  }

  Widget _row(String k, String v, P p, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.hair2))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(fontSize: 13, color: p.t2)),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.ink))),
        ]),
      );

  Widget _outline(String label, VoidCallback onTap, P p) => GestureDetector(onTap: onTap,
      child: Container(height: 48, decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center, child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: p.ink))));
}

import 'package:flutter/material.dart';
import '../nav.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class XarajatScreen extends StatefulWidget {
  final Nav nav;
  const XarajatScreen(this.nav);
  @override
  State<XarajatScreen> createState() => _XarajatScreenState();
}

class _XarajatScreenState extends State<XarajatScreen> {
  bool chat = true;
  int period = 1; // 0 hafta, 1 oy, 2 yil

  @override
  Widget build(BuildContext c) {
    final p = widget.nav.p;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Xarajat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.ink, letterSpacing: -0.3)),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(3),
            child: Row(children: [
              _seg('Chat', chat, () => setState(() => chat = true), p),
              _seg('Hisobot', !chat, () => setState(() => chat = false), p),
            ]),
          ),
        ]),
      ),
      Expanded(child: chat ? _chat(p) : _hisobot(p)),
    ]);
  }

  Widget _seg(String label, bool on, VoidCallback tap, P p) => Expanded(child: GestureDetector(
        onTap: tap,
        child: Container(height: 32,
            decoration: BoxDecoration(color: on ? p.ink : Colors.transparent, borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? p.bg : p.t2))),
      ));

  // ---- CHAT ----
  Widget _chat(P p) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('OYLIK LIMIT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: p.t2)),
              Text('${money(1550000)} / ${money(3000000)}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.green)),
            ]),
            const SizedBox(height: 7),
            ClipRRect(borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: 0.52, minHeight: 4, backgroundColor: p.hair2, color: p.ink)),
          ]),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10), children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: SizedBox(width: 250,
              child: Text('O’zingiz bilan chat — xarajat yoki daromadni yozing yoki ayting, AI avtomatik toifalaydi',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: p.t4, height: 1.5))))),
          for (final x in xChat) x.sep ? _daySep(x, p) : _bubble(x, p),
        ])),
        _inputBar(p),
      ]);

  Widget _daySep(XItem x, P p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(x.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.t3)),
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Daromad ', style: TextStyle(fontSize: 10, color: p.t4)),
              Text('+${money(x.dayIn)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: p.green)),
              Text('  ·  ', style: TextStyle(fontSize: 10, color: p.t5)),
              Text('Xarajat ', style: TextStyle(fontSize: 10, color: p.t4)),
              Text('−${money(x.dayOut)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: p.red)),
            ]),
          ]),
        )),
      );

  Widget _bubble(XItem x, P p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 7),
            decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd)),
                    alignment: Alignment.center, child: Text(x.cat.substring(0, 1), style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: p.ink))),
                const SizedBox(width: 7),
                Text(x.cat, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: p.t2, letterSpacing: 0.5)),
              ]),
              const SizedBox(height: 7),
              Text('${x.income ? '+' : '−'}${money(x.amount)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: x.income ? p.green : p.red)),
              if (x.note.isNotEmpty) ...[const SizedBox(height: 3), Text(x.note, style: TextStyle(fontSize: 13, color: p.t1))],
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: Text(x.time, style: TextStyle(fontSize: 10, color: p.t4))),
            ]),
          ),
        ]),
      );

  Widget _inputBar(P p) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair))),
        child: Row(children: [
          Expanded(child: Container(height: 42, padding: const EdgeInsets.only(left: 15, right: 6),
              decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(21)),
              alignment: Alignment.centerLeft, child: Text('Masalan: «taksiga 25 ming»', style: TextStyle(fontSize: 13.5, color: p.t5)))),
          const SizedBox(width: 10),
          Container(width: 46, height: 46, decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
              child: Icon(Icons.mic_none, color: p.bg, size: 20)),
        ]),
      );

  // ---- HISOBOT ----
  Widget _hisobot(P p) {
    final periods = ['Hafta', 'Oy', 'Yil'];
    final trend = [0.5, 0.75, 0.6, 0.9, 0.7, 1.0];
    final tLabels = ['Fev', 'Mar', 'Apr', 'May', 'Iyn', 'Iyl'];
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      Padding(padding: const EdgeInsets.fromLTRB(24, 14, 24, 0), child: Row(children: [
        for (int i = 0; i < periods.length; i++) Expanded(child: Padding(
          padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
          child: GestureDetector(onTap: () => setState(() => period = i),
            child: Container(height: 32,
                decoration: BoxDecoration(color: period == i ? p.ink : Colors.transparent,
                    border: Border.all(color: period == i ? p.ink : p.bd), borderRadius: BorderRadius.circular(16)),
                alignment: Alignment.center,
                child: Text(periods[i], style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: period == i ? p.bg : p.ink))),
          ),
        )),
      ])),
      Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
        child: Column(children: [
          Text('BU OY · SOF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.6, color: p.t2)),
          const SizedBox(height: 8),
          Text('+${money(4350000)}', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Xarajat ', style: TextStyle(fontSize: 11.5, color: p.t3)),
            Text('−${money(2450000)}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.red)),
            const SizedBox(width: 12),
            Text('Daromad ', style: TextStyle(fontSize: 11.5, color: p.t3)),
            Text('+${money(6800000)}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.green)),
          ]),
        ]),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(24, 22, 24, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          MicroLabel('OYLIK LIMIT', p),
          Container(height: 28, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center, child: Text('Tahrirlash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.ink))),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${money(1550000)} / ${money(3000000)}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.ink)),
          Text('52%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.green)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: 0.52, minHeight: 6, backgroundColor: p.hair2, color: p.ink)),
        const SizedBox(height: 7),
        Text('${money(1450000)} qoldi', style: TextStyle(fontSize: 12, color: p.green)),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(24, 22, 24, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MicroLabel('TOIFALAR', p),
        const SizedBox(height: 8),
        for (final cat in xCats) _cat(cat, p),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(24, 26, 24, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MicroLabel('XARAJAT TRENDI · 6 OY', p),
        const SizedBox(height: 16),
        SizedBox(height: 110, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (int i = 0; i < trend.length; i++) Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text((trend[i] * 800).toStringAsFixed(0), style: TextStyle(fontSize: 10, color: p.t3)),
            const SizedBox(height: 6),
            Container(width: 30, height: 80 * trend[i], decoration: BoxDecoration(color: p.ink, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))),
            const SizedBox(height: 6),
            Text(tLabels[i], style: TextStyle(fontSize: 11, color: p.t3)),
          ])),
        ])),
        const SizedBox(height: 8),
        Text('ming so’m hisobida', style: TextStyle(fontSize: 11, color: p.t5)),
      ])),
    ]);
  }

  Widget _cat(Cat cat, P p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd)),
              alignment: Alignment.center, child: Text(cat.name.substring(0, 2).toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: p.ink))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(cat.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.ink)),
              Text(money(cat.amt), style: TextStyle(fontSize: 12.5, color: p.t2)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: cat.w, minHeight: 4, backgroundColor: p.hair2, color: p.ink)),
          ])),
        ]),
      );
}

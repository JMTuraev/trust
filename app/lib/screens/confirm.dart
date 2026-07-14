import 'package:flutter/material.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ConfirmScreen extends StatefulWidget {
  final Nav nav;
  const ConfirmScreen(this.nav);
  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  String code = '';
  @override
  Widget build(BuildContext c) {
    final p = widget.nav.p;
    return Container(color: p.bg, child: Column(children: [
      OverlayHeader(p: p, title: 'Tasdiq so’rovi', onBack: () => widget.nav.close('confirm')),
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
        child: Column(children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
              alignment: Alignment.center, child: Text('AK', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.ink))),
          const SizedBox(height: 14),
          Text('Akmal Karimov +500 000 so’m yozuvni tasdiqlashingizni so’ramoqda',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.ink, height: 1.5)),
          const SizedBox(height: 6),
          Text('Mol savdosi uchun · bugun 14:20', style: TextStyle(fontSize: 12.5, color: p.t3)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < 5; i++) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.5),
              child: Container(width: 48, height: 54,
                  decoration: BoxDecoration(border: Border.all(color: i < code.length ? p.ink : p.bd), borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(i < code.length ? code[i] : '', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.ink))),
            ),
          ]),
          const SizedBox(height: 20),
          InkButton('Tasdiqlash', () => widget.nav.close('confirm'), p),
        ]),
      ),
      const Spacer(),
      Padding(padding: const EdgeInsets.fromLTRB(30, 0, 30, 26), child: Keypad(p: p, onKey: (k) {
        setState(() {
          if (k == '⌫') { if (code.isNotEmpty) code = code.substring(0, code.length - 1); }
          else if (code.length < 5) code += k;
        });
      })),
    ]));
  }
}

import 'package:flutter/material.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';

class NewPartnerSheet extends StatefulWidget {
  final Nav nav;
  const NewPartnerSheet(this.nav);
  @override
  State<NewPartnerSheet> createState() => _NewPartnerSheetState();
}

class _NewPartnerSheetState extends State<NewPartnerSheet> {
  int status = 0; // 0 Trust'da bor, 1 Taklif
  @override
  Widget build(BuildContext c) {
    final p = widget.nav.p;
    return BottomSheetShell(p: p, onClose: () => widget.nav.close('newpartner'), child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Yangi hamkor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.ink)),
        const SizedBox(height: 20),
        MicroLabel('ISM', p),
        const SizedBox(height: 10),
        _field('Ism yozing', p),
        const SizedBox(height: 20),
        MicroLabel('TELEFON', p),
        const SizedBox(height: 10),
        Container(height: 46, decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              GestureDetector(onTap: () => widget.nav.open('country'), child: Row(children: [
                const Text('🇺🇿', style: TextStyle(fontSize: 17)),
                const SizedBox(width: 6),
                Text('+998', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: p.ink)),
                Icon(Icons.keyboard_arrow_down, size: 16, color: p.t3),
              ])),
              const SizedBox(width: 10),
              Container(width: 1, height: 20, color: p.bd),
              const SizedBox(width: 12),
              Text('90 123 45 67', style: TextStyle(fontSize: 14.5, color: p.t5)),
            ])),
        const SizedBox(height: 20),
        MicroLabel('HOLAT', p),
        const SizedBox(height: 10),
        Row(children: [
          _statusBtn('Trust’da bor', 0, p),
          const SizedBox(width: 8),
          _statusBtn('Taklif qilish', 1, p),
        ]),
        const SizedBox(height: 10),
        Text(status == 0 ? 'Yozuvlar ikki tomonlama tasdiqlanadi.' : 'SMS taklif yuboriladi. Ular qo’shilgach yozuvlar tasdiqli bo’ladi.',
            style: TextStyle(fontSize: 11, color: p.t3, height: 1.5)),
        const SizedBox(height: 24),
        InkButton('Qo’shish', () => widget.nav.close('newpartner'), p),
      ]),
    );
  }

  Widget _field(String hint, P p) => Container(height: 46,
      decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.centerLeft,
      child: Text(hint, style: TextStyle(fontSize: 14.5, color: p.t5)));

  Widget _statusBtn(String label, int i, P p) => Expanded(child: GestureDetector(
        onTap: () => setState(() => status = i),
        child: Container(height: 42,
            decoration: BoxDecoration(color: status == i ? p.ink : Colors.transparent,
                border: Border.all(color: status == i ? p.ink : p.bd), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: status == i ? p.bg : p.ink))),
      ));
}

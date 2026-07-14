import 'package:flutter/material.dart';
import '../nav.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class PdfScreen extends StatelessWidget {
  final Nav nav;
  const PdfScreen(this.nav);
  static const _ink = Color(0xFF111111);
  static const _mut = Color(0xFF9C9C98);
  static const _line = Color(0xFFF2F2F0);

  @override
  Widget build(BuildContext c) {
    final p = nav.p;
    return Container(color: p.field, child: Column(children: [
      Container(color: p.bg, child: OverlayHeader(p: p, title: 'PDF dalil', onBack: () => nav.close('pdf'), trailing: 'TR-000482')),
      Expanded(child: ListView(padding: const EdgeInsets.all(18), children: [
        Container(
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E2DE)),
              borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 1))]),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TRUST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2.2, color: _mut)),
            const SizedBox(height: 6),
            const Text('Hisob-kitob dalili', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.2)),
            const SizedBox(height: 4),
            const Text('Hujjat ID: TR-000482', style: TextStyle(fontSize: 11, color: _mut)),
            const Divider(height: 24, color: Color(0xFFECECEC)),
            _pair('Kimdan', 'Jasur Toshmatov', '+998 90 123 45 67'),
            _pair('Kimga', 'Akmal Karimov', '+998 90 123 45 67'),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Column(children: [
              Text('SUMMA', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.8, color: _mut)),
              SizedBox(height: 6),
              Text('+500 000', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _ink)),
              SizedBox(height: 4),
              Text('Qarz berdim', style: TextStyle(fontSize: 12, color: Color(0xFF7A7A76))),
            ])),
            const Divider(height: 1, color: _line),
            _simplePair('Sana va vaqt', '14-iyul 2026, 14:20'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFECECEC)), borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('TASDIQ · IKKI TOMON TASDIQLADI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.6, color: _mut)),
                SizedBox(height: 10),
                _MiniRow('1-tomon (yaratdi)', '14:20'),
                SizedBox(height: 7),
                _MiniRow('2-tomon (kod bilan tasdiqladi)', '14:25'),
                SizedBox(height: 7),
                _MiniRow('Tasdiqlash kodi', '4 8 2 9 1'),
              ]),
            ),
            const SizedBox(height: 16),
            const Text('Ushbu hujjat ikki tomonning kod orqali tasdig’i asosida yaratildi. O’chirib bo’lmaydi.',
                style: TextStyle(fontSize: 10.5, color: Color(0xFFB0B0AC), height: 1.6)),
          ]),
        ),
      ])),
      Container(
        color: p.bg,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair2))),
        child: Column(children: [
          InkButton('PDF yuklab olish', () {}, p),
          const SizedBox(height: 10),
          Container(height: 46, decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center, child: Text('Ulashish', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink))),
        ]),
      ),
    ]));
  }

  Widget _pair(String k, String name, String phone) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(fontSize: 11.5, color: _mut)),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink)),
            const SizedBox(height: 2),
            Text(phone, style: const TextStyle(fontSize: 11, color: _mut)),
          ]),
        ]),
      );

  Widget _simplePair(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(fontSize: 11.5, color: _mut)),
          Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink)),
        ]),
      );
}

class _MiniRow extends StatelessWidget {
  final String k, v;
  const _MiniRow(this.k, this.v);
  @override
  Widget build(BuildContext c) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: const TextStyle(fontSize: 12, color: Color(0xFF9C9C98))),
        Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
      ]);
}

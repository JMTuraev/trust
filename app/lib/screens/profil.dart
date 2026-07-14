import 'package:flutter/material.dart';
import '../nav.dart';
import '../theme.dart';

class ProfilScreen extends StatelessWidget {
  final Nav nav;
  const ProfilScreen(this.nav);

  @override
  Widget build(BuildContext c) {
    final p = nav.p;
    return ListView(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
        child: Column(children: [
          Container(width: 72, height: 72,
              decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('JT', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: p.ink))),
          const SizedBox(height: 14),
          Text('Jasur Toshmatov', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 4),
          Text('+998 90 123 45 67', style: TextStyle(fontSize: 13, color: p.t2)),
        ]),
      ),
      _switchRow('Tungi rejim', nav.isDark, nav.toggleDark, p),
      _plainRow('Til', 'O’zbekcha', p),
      _plainRow('PIN kodni o’zgartirish', '', p),
      _plainRow('Bildirishnomalar', '', p),
      _plainRow('Yordam', '', p),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        child: Text('Chiqish', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: p.ink)),
      ),
      Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text('Trust · v1.1 · Toshkent', style: TextStyle(fontSize: 11, color: p.t6))),
      ),
    ]);
  }

  Widget _switchRow(String label, bool on, VoidCallback toggle, P p) => GestureDetector(
        onTap: toggle,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, color: p.ink))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 26,
              decoration: BoxDecoration(color: on ? p.ink : p.bd, borderRadius: BorderRadius.circular(13)),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3), width: 20, height: 20,
                  decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _plainRow(String label, String value, P p) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, color: p.ink))),
          Text(value, style: TextStyle(fontSize: 13, color: p.t3)),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 18, color: p.t6),
        ]),
      );
}

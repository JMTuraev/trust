import 'package:flutter/material.dart';
import '../nav.dart';
import '../data.dart';
import '../theme.dart';

class NotifsScreen extends StatelessWidget {
  final Nav nav;
  const NotifsScreen(this.nav);
  @override
  Widget build(BuildContext c) {
    final p = nav.p;
    return Container(color: p.bg, child: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
        child: Row(children: [
          GestureDetector(onTap: nav.closeNotifs,
              child: SizedBox(width: 34, height: 34, child: Icon(Icons.arrow_back_ios_new, size: 18, color: p.ink))),
          Text('Bildirishnomalar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.ink)),
        ]),
      ),
      Expanded(child: ListView(children: [
        for (final n in notifs)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
            child: Row(children: [
              if (n.pending) Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle)),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink)),
                const SizedBox(height: 3),
                Text(n.sub, style: TextStyle(fontSize: 12.5, color: p.t2)),
                const SizedBox(height: 3),
                Text(n.time, style: TextStyle(fontSize: 11, color: p.t4)),
              ])),
            ]),
          ),
      ])),
    ]));
  }
}

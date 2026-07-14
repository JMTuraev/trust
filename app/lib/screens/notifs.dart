import 'package:flutter/material.dart';
import '../nav.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class NotifsScreen extends StatelessWidget {
  final Nav nav;
  const NotifsScreen(this.nav);

  IconData _icon(NType t) {
    switch (t) {
      case NType.req: return Icons.help_outline;
      case NType.ok: return Icons.check;
      case NType.rem: return Icons.notifications_none;
      case NType.edit: return Icons.swap_vert;
      case NType.rej: return Icons.close;
    }
  }

  void _tap(NType t) {
    switch (t) {
      case NType.req: nav.open('confirm'); break;
      case NType.edit: nav.open('review'); break;
      default: break;
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = nav.p;
    return Container(color: p.bg, child: Column(children: [
      OverlayHeader(p: p, title: 'Bildirishnomalar', onBack: () => nav.close('notifs')),
      Expanded(child: ListView(children: [
        for (final n in notifs) GestureDetector(
          onTap: () => _tap(n.type),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 15, 20, 15),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd2)),
                  child: Icon(_icon(n.type), size: 16, color: p.ink)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(n.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink))),
                  if (n.unread) Container(width: 6, height: 6, margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle)),
                ]),
                const SizedBox(height: 3),
                Text(n.detail, style: TextStyle(fontSize: 12.5, color: p.t3, height: 1.45)),
              ])),
              const SizedBox(width: 8),
              Text(n.time, style: TextStyle(fontSize: 11, color: p.t5)),
            ]),
          ),
        ),
        Padding(padding: const EdgeInsets.all(24), child: GestureDetector(
          onTap: () => nav.open('push'),
          child: Container(height: 40, decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(20)),
              alignment: Alignment.center, child: Text('Android push ko’rinishi (demo)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.ink))),
        )),
      ])),
    ]));
  }
}

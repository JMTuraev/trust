import 'package:flutter/material.dart';
import '../nav.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  final Nav nav;
  const HomeScreen(this.nav);

  @override
  Widget build(BuildContext c) {
    final p = nav.p;
    final owedToMe = partners.where((x) => x.balance > 0).fold<num>(0, (s, x) => s + x.balance);
    final owedByMe = partners.where((x) => x.balance < 0).fold<num>(0, (s, x) => s + x.balance.abs());
    final net = owedToMe - owedByMe;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Trust', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.ink, letterSpacing: -0.3)),
            Row(children: [
              Text('Ishonchli hisob-kitob', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: p.t4, letterSpacing: 0.4)),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: nav.openNotifs,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd2)),
                  child: Icon(Icons.notifications_none, size: 18, color: p.ink),
                ),
              ),
            ]),
          ]),
          const SizedBox(height: 22),
          MicroLabel('SOF BALANS', p),
          const SizedBox(height: 6),
          Text(sumTxt(net, sign: true),
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8,
                  color: net >= 0 ? p.green : p.red)),
          const SizedBox(height: 10),
          Row(children: [
            _leg('Sizga qarz', money(owedToMe), p),
            const SizedBox(width: 16),
            _leg('Qarzingiz', money(owedByMe), p),
          ]),
          const SizedBox(height: 20),
          Container(
            height: 40,
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Qidirish', style: TextStyle(fontSize: 14, color: p.t5)),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: partners.length,
          itemBuilder: (c, i) => _row(partners[i], p),
        ),
      ),
    ]);
  }

  Widget _leg(String k, String v, P p) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$k  ', style: TextStyle(fontSize: 12, color: p.t2)),
        Text(v, style: TextStyle(fontSize: 12, color: p.ink, fontWeight: FontWeight.w600)),
      ]);

  Widget _row(Partner r, P p) => GestureDetector(
        onTap: () => nav.openClient(r),
        child: Container(
          decoration: BoxDecoration(
            color: p.bg,
            border: Border(bottom: BorderSide(color: p.hair2)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(children: [
            SizedBox(
              width: 44, height: 44,
              child: Stack(clipBehavior: Clip.none, children: [
                InitialsAvatar(r.initials, p),
                Positioned(right: -2, bottom: -2, child: TrustBadge(r.onTrust, p)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: p.ink)),
                const SizedBox(height: 2),
                Text(r.sub, style: TextStyle(fontSize: 12, color: p.t3)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(sumTxt(r.balance, sign: true),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: r.balance >= 0 ? p.green : p.red)),
              const SizedBox(height: 2),
              Text(r.balance >= 0 ? 'sizga qarzdor' : 'qarzingiz',
                  style: TextStyle(fontSize: 11, color: p.t5)),
            ]),
          ]),
        ),
      );
}

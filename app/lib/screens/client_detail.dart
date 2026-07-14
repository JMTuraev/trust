import 'package:flutter/material.dart';
import '../nav.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ClientDetail extends StatefulWidget {
  final Nav nav;
  const ClientDetail(this.nav);
  @override
  State<ClientDetail> createState() => _ClientDetailState();
}

class _ClientDetailState extends State<ClientDetail> {
  bool chat = true;

  @override
  Widget build(BuildContext c) {
    final p = widget.nav.p;
    final r = widget.nav.client!;
    return Container(
      color: p.bg,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
          child: Row(children: [
            GestureDetector(
              onTap: widget.nav.back,
              child: SizedBox(width: 34, height: 34, child: Icon(Icons.arrow_back_ios_new, size: 18, color: p.ink)),
            ),
            SizedBox(width: 38, height: 38, child: Stack(clipBehavior: Clip.none, children: [
              InitialsAvatar(r.initials, p, size: 38),
              Positioned(right: -2, bottom: -2, child: TrustBadge(r.onTrust, p, size: 15)),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: p.ink)),
              const SizedBox(height: 1),
              Text(sumTxt(r.balance, sign: true),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: r.balance >= 0 ? p.green : p.red)),
            ])),
            Container(width: 34, height: 34,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd2)),
                child: Icon(Icons.add, size: 18, color: p.ink)),
          ]),
        ),
        // Tabs
        Row(children: [
          _tab('Chat', chat, () => setState(() => chat = true), p),
          _tab('Operatsiyalar', !chat, () => setState(() => chat = false), p),
        ]),
        if (!r.onTrust)
          Container(
            color: p.card2,
            padding: const EdgeInsets.fromLTRB(20, 9, 16, 9),
            child: Row(children: [
              Expanded(child: Text('Trust’da yo’q — yozuvlar tasdiqsiz, dalil kuchiga ega emas',
                  style: TextStyle(fontSize: 11.5, color: p.t1, height: 1.4))),
              Container(
                height: 30, padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(15)),
                alignment: Alignment.center,
                child: Text('Trust’ga taklif', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.bg)),
              ),
            ]),
          ),
        Expanded(child: chat ? _chatView(p) : _opsView(p, r)),
      ]),
    );
  }

  Widget _tab(String label, bool on, VoidCallback tap, P p) => Expanded(
        child: GestureDetector(
          onTap: tap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? p.ink : p.hair, width: on ? 2 : 1))),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? p.ink : p.t3)),
          ),
        ),
      );

  Widget _chatView(P p) {
    final msgs = [
      [true, 'Assalomu alaykum, hisobni ochamiz', '14:20'],
      [false, '+500 000 so’m — mol savdosi uchun', '14:22'],
      [true, 'Tasdiqladim, rahmat', '14:25'],
    ];
    return ListView(padding: const EdgeInsets.symmetric(vertical: 14), children: [
      for (final m in msgs) _msg(m[0] as bool, m[1] as String, m[2] as String, p),
    ]);
  }

  Widget _msg(bool mine, String text, String time, P p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Row(mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: mine ? p.ink : p.card2, borderRadius: BorderRadius.circular(16)),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$text  ', style: TextStyle(fontSize: 14, height: 1.45, color: mine ? p.bg : p.ink)),
              TextSpan(text: time, style: TextStyle(fontSize: 10, color: mine ? p.bg.withOpacity(0.6) : p.t4)),
            ])),
          ),
        ]),
      );

  Widget _opsView(P p, Partner r) {
    return ListView(children: [
      _op(true, 500000, 'Mol savdosi uchun', 'Bugun 14:20', 'Tasdiqlangan', p),
      _op(false, 120000, 'Yetkazib berish', 'Kecha 11:05', 'Tasdiqlangan', p),
      _op(true, 300000, 'Qarz qaytarish', '12-iyul', 'Tasdiq kutilmoqda', p),
    ]);
  }

  Widget _op(bool income, num amt, String note, String date, String status, P p) => GestureDetector(
        onTap: widget.nav.openReceipt,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(note, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: p.ink)),
              const SizedBox(height: 3),
              Text('$date · $status', style: TextStyle(fontSize: 12, color: p.t3)),
            ])),
            Text('${income ? '+' : '−'}${money(amt)}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: income ? p.green : p.red)),
          ]),
        ),
      );
}

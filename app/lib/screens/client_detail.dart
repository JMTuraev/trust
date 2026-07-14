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
  bool menu = false;
  bool profileModal = false;
  bool codeRevealed = false;

  @override
  Widget build(BuildContext c) {
    final p = widget.nav.p;
    final r = widget.nav.client!;
    final flipped = widget.nav.flipped;
    return Container(color: p.bg, child: Stack(children: [
      Column(children: [
        _header(p, r),
        _tabs(p),
        if (flipped) _flipBanner(p, r),
        if (!r.onTrust) _oneSidedBanner(p),
        Expanded(child: chat ? _chatView(p, r) : _opsView(p)),
        if (chat) _inputBar(p),
      ]),
      if (menu) _menu(p),
      if (profileModal) _profileModal(p, r),
    ]));
  }

  Widget _header(P p, Partner r) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
        child: Row(children: [
          GestureDetector(onTap: widget.nav.back,
              child: SizedBox(width: 30, height: 34, child: Icon(Icons.arrow_back_ios_new, size: 18, color: p.ink))),
          SizedBox(width: 38, height: 38, child: Stack(clipBehavior: Clip.none, children: [
            InitialsAvatar(r.initials, p, size: 38),
            Positioned(right: -2, bottom: -2, child: TrustBadge(r.onTrust, p, size: 15)),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => setState(() => menu = !menu),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: p.ink))),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down, size: 16, color: p.t3),
              ]),
            ),
            const SizedBox(height: 1),
            Text(signed(r.balance) + ' so’m',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: r.balance >= 0 ? p.green : p.red)),
            Text('2 ta tasdiq kutilmoqda', style: TextStyle(fontSize: 10.5, color: p.t3)),
          ])),
          GestureDetector(
            onTap: widget.nav.toggleFlip,
            child: Container(width: 34, height: 34, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: widget.nav.flipped ? p.ink : Colors.transparent,
                    border: Border.all(color: widget.nav.flipped ? p.ink : p.bd)),
                child: Icon(Icons.swap_horiz, size: 17, color: widget.nav.flipped ? p.bg : p.ink)),
          ),
          GestureDetector(
            onTap: () => widget.nav.open('newop'),
            child: Container(width: 34, height: 34,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd2)),
                child: Icon(Icons.add, size: 18, color: p.ink)),
          ),
        ]),
      );

  Widget _menu(P p) => Positioned.fill(child: GestureDetector(
        onTap: () => setState(() => menu = false),
        child: Container(color: Colors.transparent, child: Stack(children: [
          Positioned(top: 56, left: 62, child: Material(
            color: Colors.transparent,
            child: Container(
              width: 186,
              decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.bd2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 28, offset: const Offset(0, 10))]),
              child: Column(children: [
                _menuItem('Nomni tahrirlash', p, false),
                _menuItem('Arxivlash', p, true),
                _menuItem('Profil', p, true, onTap: () => setState(() { menu = false; profileModal = true; })),
              ]),
            ),
          )),
        ])),
      ));

  Widget _menuItem(String label, P p, bool border, {VoidCallback? onTap}) => GestureDetector(
        onTap: onTap ?? () => setState(() => menu = false),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: border ? Border(top: BorderSide(color: p.hair2)) : null),
          child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: p.ink)),
        ),
      );

  Widget _tabs(P p) => Row(children: [
        _tab('Chat', chat, () => setState(() => chat = true), p),
        _tab('Operatsiyalar', !chat, () => setState(() => chat = false), p),
      ]);

  Widget _tab(String label, bool on, VoidCallback tap, P p) => Expanded(child: GestureDetector(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? p.ink : p.hair, width: on ? 2 : 1))),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? p.ink : p.t3)),
        ),
      ));

  Widget _flipBanner(P p, Partner r) => GestureDetector(
        onTap: widget.nav.toggleFlip,
        child: Container(
          color: p.card2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle)),
            Flexible(child: Text('Ikkinchi tomon ko’rinishi — ${r.name} ekrani · yopish uchun bosing',
                style: TextStyle(fontSize: 11.5, color: p.t1))),
          ]),
        ),
      );

  Widget _oneSidedBanner(P p) => Container(
        color: p.card2,
        padding: const EdgeInsets.fromLTRB(20, 9, 16, 9),
        child: Row(children: [
          Expanded(child: Text('Trust’da yo’q — yozuvlar tasdiqsiz, dalil kuchiga ega emas',
              style: TextStyle(fontSize: 11.5, color: p.t1, height: 1.4))),
          Container(height: 30, padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(15)),
              alignment: Alignment.center,
              child: Text('Trust’ga taklif', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.bg))),
        ]),
      );

  Widget _chatView(P p, Partner r) => ListView(padding: const EdgeInsets.symmetric(vertical: 14), children: [
        for (final m in clientChat) _chatItem(m, p),
      ]);

  Widget _chatItem(CItem m, P p) {
    switch (m.kind) {
      case CKind.sys:
        return Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: p.hair), borderRadius: BorderRadius.circular(20)),
              child: Text(m.text, style: TextStyle(fontSize: 11, color: p.t2)))));
      case CKind.text:
        return _textMsg(m, p);
      case CKind.voice:
        return _voiceMsg(m, p);
      case CKind.code:
        return _codeMsg(m, p);
      case CKind.tx:
        return _txCard(m, p);
    }
  }

  Widget _textMsg(CItem m, P p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Row(mainAxisAlignment: m.mine ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: m.mine ? p.ink : p.card2, borderRadius: BorderRadius.circular(16)),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${m.text}  ', style: TextStyle(fontSize: 14, height: 1.45, color: m.mine ? p.bg : p.ink)),
              TextSpan(text: m.time, style: TextStyle(fontSize: 10, color: m.mine ? p.bg.withOpacity(0.6) : p.t4)),
            ])),
          ),
        ]),
      );

  Widget _voiceMsg(CItem m, P p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Row(mainAxisAlignment: m.mine ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: m.mine ? p.ink : p.card2, borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 34, height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: m.mine ? p.bg : p.ink),
                  child: Icon(Icons.play_arrow, size: 18, color: m.mine ? p.ink : p.bg)),
              const SizedBox(width: 10),
              Row(children: [ for (int i = 0; i < 16; i++)
                Container(width: 2.5, height: (i % 4 + 1) * 4.0, margin: const EdgeInsets.symmetric(horizontal: 1),
                    color: (m.mine ? p.bg : p.ink).withOpacity(0.7)) ]),
              const SizedBox(width: 10),
              Text(m.text, style: TextStyle(fontSize: 10, color: m.mine ? p.bg.withOpacity(0.7) : p.t4)),
            ]),
          ),
        ]),
      );

  Widget _codeMsg(CItem m, P p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Row(mainAxisAlignment: m.mine ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => setState(() => codeRevealed = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: m.mine ? p.ink : p.card2, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TASDIQ KODI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: m.mine ? p.bg.withOpacity(0.7) : p.t2)),
                const SizedBox(height: 4),
                Text(codeRevealed ? m.text : '•••••', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 6, color: m.mine ? p.bg : p.ink)),
                const SizedBox(height: 4),
                Text(codeRevealed ? 'Ikkinchi tomon kiritadi' : 'Kodni ko’rish uchun bosing',
                    style: TextStyle(fontSize: 11, color: m.mine ? p.bg.withOpacity(0.7) : p.t2)),
              ]),
            ),
          ),
        ]),
      );

  Widget _txCard(CItem m, P p) {
    final pending = m.status == 'pending';
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(color: p.bg, border: Border.all(color: p.bd2), borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(
                color: pending ? p.amber : p.green, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text('OPERATSIYA · ${pending ? 'KUTILMOQDA' : 'TASDIQLANGAN'}',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: p.t2)),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(m.txType, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.ink)),
            Text(signed(m.income ? m.amount : -m.amount),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: m.income ? p.green : p.red)),
          ]),
          const SizedBox(height: 3),
          Text(m.time, style: TextStyle(fontSize: 11.5, color: p.t4)),
          Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.only(top: 11),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair2))),
              child: pending
                  ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Kod bilan tasdiqlanmagan', style: TextStyle(fontSize: 12, color: p.t3)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(border: Border.all(color: p.bd2), borderRadius: BorderRadius.circular(20)),
                          child: Text('tasdiqsiz', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: p.t2))),
                    ])
                  : GestureDetector(
                      onTap: () => widget.nav.open('receipt'),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Dalilni ochish', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.ink)),
                        Icon(Icons.chevron_right, size: 18, color: p.ink),
                      ]),
                    )),
        ]),
      ),
    );
  }

  Widget _opsView(P p) => ListView(children: [
        for (final o in clientOps) GestureDetector(
          onTap: o.status == 'Tasdiqlangan' ? () => widget.nav.open('receipt') : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.type, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: p.ink)),
                const SizedBox(height: 2),
                Text(o.date, style: TextStyle(fontSize: 12, color: p.t3)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(signed(o.income ? o.amount : -o.amount),
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: o.income ? p.green : p.red)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(width: 5, height: 5, decoration: BoxDecoration(
                      color: o.status == 'Tasdiqlangan' ? p.green : p.amber, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(o.status, style: TextStyle(fontSize: 11, color: p.t2)),
                ]),
              ]),
            ]),
          ),
        ),
      ]);

  Widget _inputBar(P p) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair))),
        child: Row(children: [
          Icon(Icons.add, size: 22, color: p.t1),
          const SizedBox(width: 6),
          Expanded(child: Container(
            height: 40, padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(border: Border.all(color: p.bd2), borderRadius: BorderRadius.circular(20)),
            alignment: Alignment.centerLeft,
            child: Text('Xabar...', style: TextStyle(fontSize: 14, color: p.t5)),
          )),
          const SizedBox(width: 6),
          Icon(Icons.photo_camera_outlined, size: 22, color: p.t1),
          const SizedBox(width: 8),
          Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd)),
              child: Icon(Icons.mic_none, size: 20, color: p.ink)),
        ]),
      );

  Widget _profileModal(P p, Partner r) => Positioned.fill(child: GestureDetector(
        onTap: () => setState(() => profileModal = false),
        child: Container(
          color: Colors.black.withOpacity(0.4),
          padding: const EdgeInsets.all(34),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 60, height: 60, child: Stack(clipBehavior: Clip.none, children: [
                  InitialsAvatar(r.initials, p, size: 60),
                  Positioned(right: 0, bottom: 0, child: TrustBadge(r.onTrust, p, size: 18)),
                ])),
                const SizedBox(height: 12),
                Text(r.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 3),
                Text(r.phone, style: TextStyle(fontSize: 13, color: p.t2)),
                const SizedBox(height: 5),
                Text(r.onTrust ? 'Trust’da · ikki tomonlama tasdiq' : 'Trust’da yo’q', style: TextStyle(fontSize: 11.5, color: p.t3)),
                const SizedBox(height: 16),
                _modalRow('Operatsiyalar', '${r.ops}', p, true),
                _modalRow('Balans', signed(r.balance), p, false, color: r.balance >= 0 ? p.green : p.red),
                const SizedBox(height: 12),
                Container(width: double.infinity, height: 44,
                    decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text('Yopish', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.ink))),
              ]),
            ),
          ),
        ),
      ));

  Widget _modalRow(String k, String v, P p, bool border, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: border ? Border(bottom: BorderSide(color: p.hair2)) : Border(top: BorderSide(color: p.hair2))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(fontSize: 13, color: p.t2)),
          Text(v, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color ?? p.ink)),
        ]),
      );
}

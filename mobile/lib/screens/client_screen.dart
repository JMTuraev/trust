// Hamkor sahifasi — prototip (template.html 722–1046) bilan 1:1
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final ScrollController _chat = ScrollController();
  int _lastCount = -1;

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }

  // CSS-triangle (0x0 box + rangli borderlar)
  Widget _tri({double t = 0, double b = 0, double l = 0, double r = 0, required Color c, required String side}) {
    return Container(
      width: 0,
      height: 0,
      decoration: BoxDecoration(
        border: Border(
          top: t > 0 ? BorderSide(width: t, color: side == 'top' ? c : Colors.transparent) : BorderSide.none,
          bottom: b > 0 ? BorderSide(width: b, color: side == 'bottom' ? c : Colors.transparent) : BorderSide.none,
          left: l > 0 ? BorderSide(width: l, color: side == 'left' ? c : Colors.transparent) : BorderSide.none,
          right: r > 0 ? BorderSide(width: r, color: side == 'right' ? c : Colors.transparent) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _plus(double s, Color c) {
    return SizedBox(
      width: s,
      height: s,
      child: Stack(children: [
        Positioned(left: (s - 2) / 2, top: 0, child: Container(width: 2, height: s, color: c)),
        Positioned(top: (s - 2) / 2, left: 0, child: Container(width: s, height: 2, color: c)),
      ]),
    );
  }

  Widget _chatItem(BuildContext context, Map<String, dynamic> m, Map<String, dynamic> v, Pal p) {
    final end = m['align'] == 'end';
    final maxW = MediaQuery.of(context).size.width * 0.76;

    if (m['isText'] == true) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 16),
        child: Row(
          mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: maxW),
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
              decoration: BoxDecoration(color: m['bg'] as Color, borderRadius: BorderRadius.circular(16)),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: m['text'] as String,
                    style: GoogleFonts.inter(fontSize: 14, color: m['fg'] as Color, height: 20.3 / 14),
                  ),
                  TextSpan(
                    text: ' ${m['time']}${m['checks']}',
                    style: GoogleFonts.inter(fontSize: 10, color: m['tc'] as Color),
                  ),
                ]),
                textScaler: TextScaler.noScaling,
              ),
            ),
          ],
        ),
      );
    }

    if (m['isVoice'] == true) {
      final bars = (m['bars'] as List).cast<Map<String, dynamic>>();
      final barKids = <Widget>[];
      for (var i = 0; i < bars.length; i++) {
        if (i > 0) barKids.add(const SizedBox(width: 1.5));
        barKids.add(Container(
          width: 2.5,
          height: bars[i]['h'] as double,
          decoration: BoxDecoration(color: bars[i]['c'] as Color, borderRadius: BorderRadius.circular(1)),
        ));
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 16),
        child: Row(
          mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Tap(
              onTap: m['toggle'] as VoidCallback,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(color: m['bg'] as Color, borderRadius: BorderRadius.circular(16)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: m['pbg'] as Color, shape: BoxShape.circle),
                    child: Center(
                      child: m['notPlaying'] == true
                          ? Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: _tri(t: 5, b: 5, l: 8, c: m['pfg'] as Color, side: 'left'),
                            )
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 2.5, height: 10, color: m['pfg'] as Color),
                              const SizedBox(width: 2.5),
                              Container(width: 2.5, height: 10, color: m['pfg'] as Color),
                            ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      height: 18,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: barKids),
                    ),
                    const SizedBox(height: 3),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Tx(m['durText'] as String, size: 10, color: m['tc'] as Color, tab: true),
                      const SizedBox(width: 6),
                      Tx('${m['time']}${m['checks']}', size: 10, color: m['tc'] as Color),
                    ]),
                  ]),
                ]),
              ),
            ),
          ],
        ),
      );
    }

    if (m['isVnote'] == true) {
      final prog = m['prog'] as double;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              Tap(
                onTap: m['toggle'] as VoidCallback,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(width: 3, color: (prog > 0 ? m['ringOn'] : m['ringOff']) as Color),
                  ),
                  child: ClipOval(
                    child: Container(
                      color: m['vbg'] as Color,
                      child: Stack(alignment: Alignment.center, children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: m['pbg2'] as Color, shape: BoxShape.circle),
                          child: Center(
                            child: m['notPlaying'] == true
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 3),
                                    child: _tri(t: 7, b: 7, l: 11, c: m['pfg2'] as Color, side: 'left'),
                                  )
                                : Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(width: 3, height: 13, color: m['pfg2'] as Color),
                                    const SizedBox(width: 3),
                                    Container(width: 3, height: 13, color: m['pfg2'] as Color),
                                  ]),
                          ),
                        ),
                        Positioned(bottom: 14, child: Tx('VIDEO', size: 8.5, color: m['tcv'] as Color, ls: 1.5)),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Tx('${m['durText']} · ${m['time']}${m['checks']}', size: 10, color: p.t3),
            ]),
          ],
        ),
      );
    }

    if (m['isCode'] == true) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 16),
        child: Row(
          mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Tap(
              onTap: m['revealTap'] as VoidCallback,
              child: Container(
                constraints: BoxConstraints(maxWidth: maxW),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(color: m['bg'] as Color, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Tx('TASDIQ KODI', size: 10.5, w: FontWeight.w600, color: m['cap'] as Color, ls: 1.2),
                  if (m['hidden'] == true) ...[
                    const SizedBox(height: 4),
                    Tx('•••••', size: 22, w: FontWeight.w700, color: m['fg'] as Color, ls: 6),
                    const SizedBox(height: 4),
                    Tx("Kodni ko'rish uchun bosing", size: 11, color: m['cap'] as Color),
                  ],
                  if (m['revealed'] == true) ...[
                    const SizedBox(height: 4),
                    Tx(m['codeText'] as String, size: 22, w: FontWeight.w700, color: m['fg'] as Color, ls: 6, tab: true),
                    const SizedBox(height: 4),
                    Tx(m['capText'] as String, size: 11, color: m['cap'] as Color),
                  ],
                  const SizedBox(height: 5),
                  Tx(m['time'] as String, size: 10, color: m['cap'] as Color),
                ]),
              ),
            ),
          ],
        ),
      );
    }

    if (m['isSys'] == true) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: p.hair), borderRadius: BorderRadius.circular(20)),
            child: Tx(m['text'] as String, size: 11, color: p.t2, align: TextAlign.center),
          ),
        ),
      );
    }

    // isTx
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: p.bg,
          border: Border.all(color: p.bd2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: m['dot'] as Color, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Expanded(
              child: Tx('OPERATSIYA · ${(m['stLabel'] as String).toUpperCase()}',
                  size: 10.5, w: FontWeight.w600, color: p.t2, ls: 1.2, maxLines: 1),
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Tx(m['type'] as String, size: 14, w: FontWeight.w500, color: p.ink),
              Tx(m['amount'] as String, size: 17, w: FontWeight.w700, color: m['acolor'] as Color, tab: true),
            ],
          ),
          const SizedBox(height: 3),
          Tx(m['date'] as String, size: 11.5, color: p.t4),
          if (m['unconf'] == true)
            Container(
              margin: const EdgeInsets.only(top: 13),
              padding: const EdgeInsets.only(top: 11),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair2))),
              child: Row(children: [
                Expanded(child: Tx('Bir tomonlama yozuv — dalil emas', size: 12, color: p.t3)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                  decoration: BoxDecoration(border: Border.all(color: p.bd2), borderRadius: BorderRadius.circular(20)),
                  child: Tx('tasdiqsiz', size: 10, w: FontWeight.w600, color: p.t2, ls: 0.6),
                ),
              ]),
            ),
          if (m['showInput'] == true)
            Container(
              margin: const EdgeInsets.only(top: 13),
              padding: const EdgeInsets.only(top: 13),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Tap(
                  onTap: m['fillCode'] as VoidCallback,
                  child: Tx(m['fillText'] as String, size: 12, color: p.t1, lh: 18),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  CodeBoxes(
                    boxes: (v['codeBoxes'] as List).cast<Map<String, dynamic>>(),
                    w: 31, h: 40, fs: 16, gap: 6, r: 9,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: InkBtn(label: 'Tasdiqlash', onTap: m['confirm'] as VoidCallback, h: 42, fs: 13),
                    ),
                  ),
                ]),
                if (v['codeError'] == true) ...[
                  const SizedBox(height: 8),
                  Tx("Kod noto'g'ri. Qayta urinib ko'ring.", size: 12, color: p.t1),
                ],
              ]),
            ),
          if (m['showMyCode'] == true)
            Container(
              margin: const EdgeInsets.only(top: 13),
              padding: const EdgeInsets.only(top: 13),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Tx('Tasdiqlash kodi — ikkinchi tomon kiritadi', size: 12, color: p.t1),
                const SizedBox(height: 6),
                Tx(m['code'] as String, size: 24, w: FontWeight.w700, color: p.ink, ls: 8, tab: true),
              ]),
            ),
          if (m['done'] == true)
            Tap(
              onTap: m['openReceipt'] as VoidCallback,
              child: Container(
                margin: const EdgeInsets.only(top: 13),
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair2))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Tx('Dalilni ochish', size: 13, w: FontWeight.w600, color: p.ink),
                  ChevRight(color: p.ink),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _menuItem(Pal p, String label, VoidCallback onTap, {bool top = false}) {
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: top ? BoxDecoration(border: Border(top: BorderSide(color: p.hair2))) : null,
        child: Tx(label, size: 13.5, w: FontWeight.w500, color: p.ink),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();

    final chatItems = (v['chatItems'] as List).cast<Map<String, dynamic>>();
    if (v['isChatTab'] == true && chatItems.length != _lastCount) {
      _lastCount = chatItems.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chat.hasClients) _chat.jumpTo(_chat.position.maxScrollExtent);
      });
    }

    // Flip icon (14x13)
    Widget flipIcon() {
      final fg = v['flipFg'] as Color;
      return SizedBox(
        width: 14,
        height: 13,
        child: Stack(children: [
          Positioned(top: 2.6, left: 0,
              child: Container(width: 9, height: 1.6, decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(1)))),
          Positioned(top: 0, right: 0, child: _tri(t: 3.4, b: 3.4, l: 5, c: fg, side: 'left')),
          Positioned(bottom: 2.6, right: 0,
              child: Container(width: 9, height: 1.6, decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(1)))),
          Positioned(bottom: 0, left: 0, child: _tri(t: 3.4, b: 3.4, r: 5, c: fg, side: 'right')),
        ]),
      );
    }

    final header = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
      child: Row(children: [
        BackBtn(onTap: () => v['back']()),
        const SizedBox(width: 12),
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
            child: Center(child: Tx(v['cInitials'] as String, size: 13, w: FontWeight.w600, color: p.ink)),
          ),
          if (v['cOnTrust'] == true) const TrustBadge(size: 15),
          if (v['oneSided'] == true) const OneSidedBadge(size: 15),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (v['renaming'] == true)
              Row(children: [
                Expanded(
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(8)),
                    child: StoreField(
                      value: v['renVal'] as String,
                      onChanged: (t) => v['onRen'](t),
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.ink),
                      onSubmit: () => v['renSave'](),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tap(
                  onTap: () => v['renSave'](),
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(15)),
                    child: Tx('OK', size: 11.5, w: FontWeight.w600, color: p.bg),
                  ),
                ),
              ]),
            if (v['notRenaming'] == true)
              Tap(
                onTap: () => v['menuTap'](),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Tx(v['cName'] as String, size: 15.5, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true)),
                  if (v['showChev'] == true) ...[
                    const SizedBox(width: 6),
                    Transform.translate(
                      offset: const Offset(0, -4),
                      child: Transform.rotate(
                        angle: 0.785398,
                        child: Container(
                          width: 6.5,
                          height: 6.5,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: p.t3, width: 1.7),
                              bottom: BorderSide(color: p.t3, width: 1.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            const SizedBox(height: 1),
            Tx(v['cBal'] as String, size: 12, w: FontWeight.w500, color: v['cBalColor'] as Color, tab: true, maxLines: 1),
            if (v['hasPend'] == true) ...[
              const SizedBox(height: 1),
              Tx(v['pendText'] as String, size: 10.5, color: p.t3, tab: true, maxLines: 1),
            ],
          ]),
        ),
        if (v['canFlip'] == true) ...[
          const SizedBox(width: 12),
          Tap(
            onTap: () => v['flipTap'](),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: v['flipBg'] as Color,
                border: Border.all(color: v['flipBd'] as Color),
              ),
              child: Center(child: flipIcon()),
            ),
          ),
        ],
        const SizedBox(width: 12),
        Tap(
          onTap: () => v['openSheetClient'](),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd2)),
            child: Center(child: _plus(12, p.ink)),
          ),
        ),
      ]),
    );

    final tabs = Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair))),
      child: Row(children: [
        Expanded(
          child: Tap(
            onTap: () => v['toChat'](),
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 11),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 2, color: v['chatTabLine'] as Color))),
              child: Center(child: Tx('Chat', size: 13.5, w: FontWeight.w600, color: v['chatTabColor'] as Color)),
            ),
          ),
        ),
        Expanded(
          child: Tap(
            onTap: () => v['toOps'](),
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 11),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 2, color: v['opsTabLine'] as Color))),
              child: Center(child: Tx('Operatsiyalar', size: 13.5, w: FontWeight.w600, color: v['opsTabColor'] as Color)),
            ),
          ),
        ),
      ]),
    );

    final flippedBanner = v['flipped'] == true
        ? Tap(
            onTap: () => v['flipTap'](),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
              decoration: BoxDecoration(color: p.card2, border: Border(bottom: BorderSide(color: p.hair2))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _Pulse(
                  duration: const Duration(milliseconds: 1800),
                  child: Container(width: 6, height: 6, decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: "Ikkinchi tomon ko'rinishi — ", style: GoogleFonts.inter(fontSize: 11.5, color: p.t1)),
                        TextSpan(text: v['flipWho'] as String, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.ink)),
                        TextSpan(text: ' ekrani · yopish uchun bosing', style: GoogleFonts.inter(fontSize: 11.5, color: p.t1)),
                      ]),
                      maxLines: 1,
                      textScaler: TextScaler.noScaling,
                    ),
                  ),
                ),
              ]),
            ),
          )
        : const SizedBox.shrink();

    final oneSidedBanner = v['oneSided'] == true
        ? Container(
            padding: const EdgeInsets.fromLTRB(20, 9, 16, 9),
            decoration: BoxDecoration(color: p.card2, border: Border(bottom: BorderSide(color: p.hair2))),
            child: Row(children: [
              Expanded(
                child: Tx("Trust'da yo'q — yozuvlar tasdiqsiz, dalil kuchiga ega emas", size: 11.5, color: p.t1, lh: 16.1),
              ),
              const SizedBox(width: 10),
              Tap(
                onTap: () => v['inviteTap'](),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(15)),
                  child: Tx("Trust'ga taklif qilish", size: 11.5, w: FontWeight.w600, color: p.bg),
                ),
              ),
            ]),
          )
        : const SizedBox.shrink();

    // Chat input bar
    Widget inputBar() {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.hair))),
        child: Row(children: [
          if (v['recOn'] == true)
            Expanded(
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(children: [
                    _Pulse(
                      duration: const Duration(milliseconds: 1000),
                      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle)),
                    ),
                    const SizedBox(width: 10),
                    Tx('yozilmoqda…', size: 14, color: p.t1),
                    const Spacer(),
                    Tx('0:02', size: 12, color: p.t3, tab: true),
                  ]),
                ),
              ),
            ),
          if (v['recOff'] == true)
            Expanded(
              child: Row(children: [
                Tap(
                  onTap: () => v['attachTap'](),
                  child: SizedBox(width: 38, height: 38, child: Center(child: _plus(16, p.t1))),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(border: Border.all(color: p.bd2), borderRadius: BorderRadius.circular(20)),
                    child: StoreField(
                      value: v['chatInput'] as String,
                      onChanged: (t) => v['onChatInput'](t),
                      hint: 'Xabar...',
                      style: GoogleFonts.inter(fontSize: 14, color: p.ink),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tap(
                  onTap: () => v['camTap'](),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Center(
                      child: SizedBox(
                        width: 17,
                        height: 13,
                        child: Stack(clipBehavior: Clip.none, children: [
                          Container(
                            width: 17,
                            height: 13,
                            decoration: BoxDecoration(
                              border: Border.all(color: p.t1, width: 1.6),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Positioned(right: -6, top: 2.5, child: _tri(t: 3.5, b: 3.5, l: 4.5, c: p.t1, side: 'left')),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (v['hasText'] == true)
                  Tap(
                    onTap: () => v['sendChat'](),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: _tri(t: 6, b: 6, l: 11, c: p.bg, side: 'left'),
                        ),
                      ),
                    ),
                  ),
                if (v['noText'] == true)
                  Tap(
                    onTap: () => v['micTap'](),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(0, 2.5),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 9,
                              height: 14,
                              decoration: BoxDecoration(
                                border: Border.all(color: p.ink, width: 1.6),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -5),
                              child: Container(
                                width: 15,
                                height: 7,
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: p.ink, width: 1.6),
                                    right: BorderSide(color: p.ink, width: 1.6),
                                    bottom: BorderSide(color: p.ink, width: 1.6),
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -5),
                              child: Container(width: 1.6, height: 3, color: p.ink),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
        ]),
      );
    }

    // Ops tab
    Widget skelRow(Map<String, dynamic> s, {EdgeInsets pad = const EdgeInsets.symmetric(vertical: 16, horizontal: 24), bool border = true}) {
      return Container(
        padding: pad,
        decoration: border ? BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))) : null,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skel(wf: (s['w1'] as num).toDouble(), h: 12),
              const SizedBox(height: 8),
              Skel(wf: (s['w2'] as num).toDouble(), h: 9, r: 5),
            ]),
          ),
          const SizedBox(width: 12),
          const Skel(w: 76, h: 12),
        ]),
      );
    }

    Widget opsList() {
      final rows = <Widget>[];
      if (v['skelOps'] == true) {
        final sk = (v['skelRows'] as List).cast<Map<String, dynamic>>();
        for (final s in sk.take(4)) {
          rows.add(skelRow(s));
        }
      }
      if (v['notSkelOps'] == true) {
        for (final o in (v['opsRows'] as List).cast<Map<String, dynamic>>()) {
          rows.add(Tap(
            onTap: o['open'] as VoidCallback,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Tx(o['type'] as String, size: 14.5, w: FontWeight.w600, color: p.ink, maxLines: 1),
                    const SizedBox(height: 2),
                    Tx(o['date'] as String, size: 12, color: p.t3),
                  ]),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Tx(o['amount'] as String, size: 14.5, w: FontWeight.w600, color: o['color'] as Color, tab: true),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 5, height: 5, decoration: BoxDecoration(color: o['dot'] as Color, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Tx(o['st'] as String, size: 11, color: p.t2, maxLines: 1),
                  ]),
                ]),
              ]),
            ),
          ));
        }
        if (v['opsLoadingMore'] == true) {
          rows.add(skelRow(const {'w1': 0.44, 'w2': 0.28}, border: false));
        }
      }
      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120) v['opsMore']();
          return false;
        },
        child: ListView(children: rows),
      );
    }

    return Stack(children: [
      Column(children: [
        header,
        tabs,
        flippedBanner,
        oneSidedBanner,
        if (v['isChatTab'] == true) ...[
          Expanded(
            child: ListView.builder(
              controller: _chat,
              padding: const EdgeInsets.symmetric(vertical: 14),
              itemCount: chatItems.length,
              itemBuilder: (ctx, i) => _chatItem(ctx, chatItems[i], v, p),
            ),
          ),
          inputBar(),
        ],
        if (v['isOpsTab'] == true) Expanded(child: opsList()),
      ]),
      if (v['menuOpen'] == true) ...[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => v['menuClose'](),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: 56,
          left: 62,
          child: Container(
            constraints: const BoxConstraints(minWidth: 186),
            decoration: BoxDecoration(
              color: p.bg,
              border: Border.all(color: p.bd2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(offset: Offset(0, 10), blurRadius: 28, color: Color(0x29000000))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                _menuItem(p, 'Nomni tahrirlash', () => v['menuRename']()),
                _menuItem(p, 'Arxivlash', () => v['menuArchive'](), top: true),
                _menuItem(p, 'Profil', () => v['menuProfile'](), top: true),
              ]),
            ),
          ),
        ),
      ],
      if (v['pProfOpen'] == true)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => v['pProfClose'](),
            child: Container(
              color: const Color(0x66000000),
              padding: const EdgeInsets.all(34),
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(18)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Stack(clipBehavior: Clip.none, children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
                          child: Center(child: Tx(v['cInitials'] as String, size: 18, w: FontWeight.w600, color: p.ink)),
                        ),
                        if (v['cOnTrust'] == true) const TrustBadge(size: 18),
                      ]),
                      const SizedBox(height: 12),
                      Tx(v['cName'] as String, size: 17, w: FontWeight.w700, color: p.ink),
                      const SizedBox(height: 3),
                      Tx(v['pPhone'] as String, size: 13, color: p.t2, tab: true),
                      const SizedBox(height: 5),
                      Tx(v['pStatus'] as String, size: 11.5, color: p.t3),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair2))),
                        child: Column(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Tx('Operatsiyalar', size: 13, color: p.t2),
                              Tx(v['pOps'] as String, size: 13.5, w: FontWeight.w600, color: p.ink, tab: true),
                            ]),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Tx('Balans', size: 13, color: p.t2),
                              Tx(v['pBal'] as String, size: 13.5, w: FontWeight.w600, color: v['cBalColor'] as Color, tab: true),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: GhostBtn(label: 'Yopish', onTap: () => v['pProfClose'](), h: 44, fs: 13.5),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Pulsatsiya (CSS trPulse) — opacity 1 → 0.35 sikl
class _Pulse extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const _Pulse({required this.child, required this.duration});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

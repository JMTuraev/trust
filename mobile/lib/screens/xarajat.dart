// Xarajat ekrani — prototype/template.html 467–651 bilan 1:1
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class XarajatScreen extends StatefulWidget {
  const XarajatScreen({super.key});

  @override
  State<XarajatScreen> createState() => _XarajatScreenState();
}

class _XarajatScreenState extends State<XarajatScreen> with TickerProviderStateMixin {
  late final AnimationController _ring =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  late final AnimationController _tick =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  final DateTime _t0 = DateTime.now();
  final ScrollController _chatCtl = ScrollController();
  int _lastChatLen = -1;

  @override
  void dispose() {
    _ring.dispose();
    _tick.dispose();
    _chatCtl.dispose();
    super.dispose();
  }

  double _ms() => DateTime.now().difference(_t0).inMilliseconds.toDouble();

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();

    return Stack(
      children: [
        Column(
          children: [
            // Header + segmented
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx('Xarajat', size: 22, w: FontWeight.w700, color: p.ink, ls: -0.3),
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      border: Border.all(color: p.bd),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        for (final ms in (v['xarTabs'] as List).cast<Map<String, dynamic>>())
                          Expanded(
                            child: Tap(
                              onTap: ms['pick'],
                              child: Container(
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: ms['bg'],
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Tx(ms['label'], size: 13, w: FontWeight.w600, color: ms['fg']),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (v['xtHisobot'] == true) Expanded(child: _hisobot(v, p)),
            if (v['xtChat'] == true) ..._chat(v, p, context),
          ],
        ),
        if (v['vOpen'] == true) Positioned.fill(child: _voice(v, p)),
      ],
    );
  }

  // ---------------- HISOBOT ----------------
  Widget _hisobot(Map<String, dynamic> v, Pal p) {
    final periods = (v['xarPeriods'] as List).cast<Map<String, dynamic>>();
    final cats = (v['xarCats'] as List).cast<Map<String, dynamic>>();
    final trend = (v['xTrend'] as List).cast<Map<String, dynamic>>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Period chips
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: Row(
            children: [
              for (var i = 0; i < periods.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Tap(
                    onTap: periods[i]['pick'],
                    child: Container(
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: periods[i]['bg'],
                        border: Border.all(color: periods[i]['bd']),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Tx(periods[i]['label'], size: 12.5, w: FontWeight.w600, color: periods[i]['fg']),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Net block
        Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Cap(v['xarNetCap'], ls: 1.6),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Tx(v['xarNet'], size: 30, w: FontWeight.w700, color: p.ink, tab: true, ls: -0.5),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Tx('Xarajat', size: 11.5, color: p.t3),
                        const SizedBox(width: 6),
                        Tx(v['xarOutTxt'], size: 13.5, w: FontWeight.w600, color: v['redC'], tab: true),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Tx('Daromad', size: 11.5, color: p.t3),
                        const SizedBox(width: 6),
                        Tx(v['xarInTxt'], size: 13.5, w: FontWeight.w600, color: v['greenC'], tab: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // LIMIT
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Cap('OYLIK LIMIT', ls: 1.6),
                  Tap(
                    onTap: v['limEditToggle'],
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: p.bd),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Tx(v['limBtnTxt'], size: 12, w: FontWeight.w600, color: p.ink),
                    ),
                  ),
                ],
              ),
              if (v['limEditOpen'] == true)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            border: Border.all(color: p.bd),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: StoreField(
                            value: v['limEditVal'].toString(),
                            onChanged: (t) => v['limEditSet'](t),
                            hint: 'Masalan: 3000000',
                            style: GoogleFonts.inter(fontSize: 14, color: p.ink),
                            keyboardType: TextInputType.number,
                            onSubmit: v['limSave'],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tap(
                        onTap: v['limSave'],
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.ink,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Tx('Saqlash', size: 13, w: FontWeight.w600, color: p.bg),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Tx(v['limSpentTxt'], size: 13.5, w: FontWeight.w600, color: p.ink, tab: true),
                        Tx(' / ${v['limTotTxt']}', size: 13.5, color: p.t3, tab: true),
                      ],
                    ),
                    Tx(v['limPctTxt'], size: 12, w: FontWeight.w600, color: v['limRemainC'], tab: true),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                height: 6,
                margin: const EdgeInsets.only(top: 8),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: p.hair2,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  widthFactor: (v['limPct'] as num) / 100,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: v['limBar'],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Tx(v['limNoteTxt'], size: 12, color: v['limRemainC'], tab: true),
              ),
            ],
          ),
        ),
        // TOIFALAR
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Cap('TOIFALAR', ls: 1.6),
              if (v['xarCatsEmpty'] == true)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Tx("Bu davrda xarajat yo'q", size: 13, color: p.t4),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  children: [
                    for (final xc in cats)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: p.bd),
                              ),
                              child: Tx(xc['abbr'], size: 10.5, w: FontWeight.w700, color: p.ink),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Tx(xc['name'], size: 13, w: FontWeight.w600, color: p.ink),
                                      Tx(xc['amt'], size: 12.5, color: p.t2, tab: true),
                                    ],
                                  ),
                                  Container(
                                    width: double.infinity,
                                    height: 4,
                                    margin: const EdgeInsets.only(top: 6),
                                    clipBehavior: Clip.hardEdge,
                                    decoration: BoxDecoration(
                                      color: p.hair2,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: FractionallySizedBox(
                                      widthFactor: (xc['w'] as num) / 100,
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: p.ink,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // TREND
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Cap('XARAJAT TRENDI · 6 OY', ls: 1.6),
              Container(
                height: 110,
                margin: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < trend.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Tx(trend[i]['val'], size: 10, color: p.t3, tab: true),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxWidth: 30),
                              height: trend[i]['h'],
                              decoration: BoxDecoration(
                                color: trend[i]['bg'],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Tx(trend[i]['label'], size: 11, color: p.t3),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Tx("ming so'm hisobida", size: 11, color: p.t5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- CHAT ----------------
  List<Widget> _chat(Map<String, dynamic> v, Pal p, BuildContext context) {
    final xChat = (v['xChat'] as List).cast<Map<String, dynamic>>();
    if (xChat.length != _lastChatLen) {
      final wasInit = _lastChatLen == -1;
      _lastChatLen = xChat.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_chatCtl.hasClients) return;
        if (wasInit) {
          _chatCtl.jumpTo(_chatCtl.position.maxScrollExtent);
        } else {
          _chatCtl.animateTo(
            _chatCtl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
    final items = xChat.reversed.toList();
    final maxW = MediaQuery.of(context).size.width * 0.76;

    return [
      // Limit strip
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Tx('OYLIK LIMIT', size: 10.5, w: FontWeight.w600, color: p.t2, ls: 1.2),
                const SizedBox(width: 10),
                Flexible(
                  child: Tx(v['limRemainTxt'], size: 11.5, w: FontWeight.w600, color: v['limRemainC'], tab: true, maxLines: 1, ellipsis: true),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              height: 4,
              margin: const EdgeInsets.only(top: 7),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: p.hair2,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                widthFactor: (v['limPct'] as num) / 100,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: v['limBar'],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          controller: _chatCtl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 250),
                  child: Tx(
                    "O'zingiz bilan chat — xarajat yoki daromadni yozing yoki ayting, AI avtomatik toifalaydi",
                    size: 11.5,
                    color: p.t4,
                    lh: 17.25,
                    align: TextAlign.center,
                  ),
                ),
              ),
            ),
            for (final cb in items)
              if (cb['sep'] == true)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 14),
                      decoration: BoxDecoration(
                        color: p.card2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Tx(cb['label'], size: 11, w: FontWeight.w600, color: p.t3),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Tx('Daromad', size: 10, color: p.t4),
                              const SizedBox(width: 4),
                              Tx(cb['dTxt'], size: 10, w: FontWeight.w600, color: cb['dColor'], tab: true),
                              const SizedBox(width: 4),
                              Tx('·', size: 10, color: p.t5),
                              const SizedBox(width: 4),
                              Tx('Xarajat', size: 10, color: p.t4),
                              const SizedBox(width: 4),
                              Tx(cb['xTxt'], size: 10, w: FontWeight.w600, color: cb['xColor'], tab: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: cb['just'] == 'start' ? MainAxisAlignment.start : MainAxisAlignment.end,
                    children: [
                      Container(
                        constraints: BoxConstraints(maxWidth: maxW),
                        padding: const EdgeInsets.fromLTRB(13, 10, 13, 7),
                        decoration: BoxDecoration(
                          color: p.card2,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular((cb['rad'] as List)[0]),
                            topRight: Radius.circular((cb['rad'] as List)[1]),
                            bottomRight: Radius.circular((cb['rad'] as List)[2]),
                            bottomLeft: Radius.circular((cb['rad'] as List)[3]),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: p.bd),
                                  ),
                                  child: Tx(cb['abbr'], size: 8.5, w: FontWeight.w700, color: p.ink),
                                ),
                                const SizedBox(width: 7),
                                Tx(cb['cat'], size: 10.5, w: FontWeight.w600, color: p.t2, ls: 0.5),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Tx(cb['amt'], size: 16, w: FontWeight.w700, color: cb['color'], tab: true),
                            ),
                            if (cb['hasNote'] == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Tx(cb['note'], size: 13, color: p.t1),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Tx(cb['time'], size: 10, color: p.t4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
      // Input bar
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair))),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                padding: const EdgeInsets.only(left: 15, right: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: p.bd),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: StoreField(
                        value: v['xarTextVal'],
                        onChanged: (t) => v['xarTextSet'](t),
                        hint: 'Masalan: «taksiga 25 ming»',
                        style: GoogleFonts.inter(fontSize: 13.5, color: p.ink),
                        onSubmit: v['xarTextGo'],
                      ),
                    ),
                    if (v['xHasText'] == true)
                      Tap(
                        onTap: v['xarTextGo'],
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                          child: Tx('↑', size: 14, color: p.bg),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tap(
              onTap: v['xarMicTap'],
              child: SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _ring,
                        builder: (_, __) {
                          final t = _ring.value;
                          return Opacity(
                            opacity: (1 - t) * 0.45,
                            child: Transform.scale(
                              scale: 1 + 0.6 * t,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: p.ink),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 9,
                              height: 13,
                              decoration: BoxDecoration(
                                color: p.bg,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -4),
                              child: Container(
                                width: 15,
                                height: 7,
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: p.bg, width: 2),
                                    right: BorderSide(color: p.bg, width: 2),
                                    bottom: BorderSide(color: p.bg, width: 2),
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -4),
                              child: Container(width: 2, height: 2, color: p.bg),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ---------------- VOICE OVERLAY ----------------
  Widget _voice(Map<String, dynamic> v, Pal p) {
    final wave = (v['vWave'] as List).cast<Map<String, dynamic>>();
    final samples = (v['vSamples'] as List).cast<Map<String, dynamic>>();
    return Container(
      color: p.bg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Tap(
                  onTap: v['vClose'],
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: p.bd),
                    ),
                    child: Tx('✕', size: 13, color: p.t2),
                  ),
                ),
              ],
            ),
          ),
          if (v['vListen'] == true)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Tap(
                      onTap: () => v['vStop'](),
                      child: SizedBox(
                        height: 60,
                        child: AnimatedBuilder(
                          animation: _tick,
                          builder: (_, __) {
                            final ms = _ms();
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                for (var i = 0; i < wave.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 3),
                                  _waveBar(wave[i], ms, p),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Tx('Tinglayapman…', size: 20, w: FontWeight.w700, color: p.ink),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Tx((v['vHint'] ?? '') as String, size: 12.5, color: p.t3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        for (var i = 0; i < samples.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          Tap(
                            onTap: samples[i]['pick'],
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: p.bd),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Tx('«${samples[i]['text']}»', size: 14, color: p.ink),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (v['vParsing'] == true)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 0, 30, 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Tx('«${v['vText']}»', size: 19, w: FontWeight.w600, color: p.ink, lh: 26.6, align: TextAlign.center),
                    const SizedBox(height: 22),
                    AnimatedBuilder(
                      animation: _tick,
                      builder: (_, __) {
                        final ms = _ms();
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0) const SizedBox(width: 9),
                              Opacity(
                                opacity: 0.3 + 0.7 * (0.5 + 0.5 * math.sin(2 * math.pi * (ms - i * 200) / 1000)),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                                ),
                              ),
                            ],
                            const SizedBox(width: 9),
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Tx('AI tahlil qilmoqda…', size: 12.5, color: p.t3),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _waveBar(Map<String, dynamic> w, double ms, Pal p) {
    final dur = (w['dur'] as num).toDouble();
    final delay = (w['delay'] as num).toDouble();
    // alternate (reverse) animatsiya: davri 2*dur, uchburchak to'lqin 0.15..1
    final t = ((ms - delay) / dur);
    final ph = t - t.floorToDouble(); // 0..1
    final cycle = (t.floor() % 2 == 0) ? ph : 1 - ph;
    final scale = 0.15 + 0.85 * cycle.clamp(0.0, 1.0);
    return Transform.scale(
      scaleY: scale,
      child: Container(
        width: 3.5,
        height: (w['h'] as num).toDouble(),
        decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

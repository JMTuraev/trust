// Xarajatlar — papka (folder) UI, dizayn "Xarajatlar Trust.html" bilan 1:1.
// TO'LIQ EKRAN: bottom navsiz, header'da orqaga. Matn-birinchi: input -> AI -> papka.
// Dinamika (dizayn kabi): input ichida rangli belgilash (summa yashil/qizil, toifa/buyruq/sana
// fonli), yozuv papkaga "uchadi" (fly chip + papka pulsi), sparkline jonli (oxirgi 8 yozuv,
// yangisida siljiydi), yangi papka "pop", tray "shake", toastlar "Bekor qilish" bilan.
import 'dart:ui' show lerpDouble;
import 'package:flutter/foundation.dart' show listEquals;
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
  // Papka kartalari pozitsiyasi (fly nishoni) va pulslash hisoblagichi
  final Map<String, GlobalKey> _fk = {};
  final GlobalKey _inputKey = GlobalKey();
  final Map<String, int> _pulse = {};

  GlobalKey _keyFor(String name) => _fk.putIfAbsent(name, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();

    // Fly hodisalarini iste'mol qilamiz — kadr chizilgach uchiramiz (pozitsiyalar tayyor)
    final flyEvents = (v['xfFlyEvents'] as List).cast<Map<String, dynamic>>();
    if (flyEvents.isNotEmpty) {
      final events = List<Map<String, dynamic>>.from(flyEvents);
      (v['xfFlyDone'] as Function)();
      WidgetsBinding.instance.addPostFrameCallback((_) => _launchFly(events));
    }

    return Stack(
      children: [
        // ------- Asosiy sahifa -------
        Column(
          children: [
            _header(v, p),
            _balance(v, p),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 210),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (v['xfEmptyAll'] == true) _emptyAll(p),
                    if ((v['xfInFolders'] as List).isNotEmpty) ...[
                      _cap('KIRIM', p),
                      const SizedBox(height: 10),
                      _grid((v['xfInFolders'] as List).cast<Map<String, dynamic>>(), p),
                      const SizedBox(height: 18),
                    ],
                    if ((v['xfOutFolders'] as List).isNotEmpty) ...[
                      _cap('CHIQIM', p),
                      const SizedBox(height: 10),
                      _grid((v['xfOutFolders'] as List).cast<Map<String, dynamic>>(), p),
                      const SizedBox(height: 18),
                    ],
                    if (v['xfShowTray'] == true) _tray(v, p),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ------- Papka tafsiloti (to'liq ekran) -------
        if (v['xfDetailOpen'] == true) Positioned.fill(child: _detail(v, p)),

        // ------- Oxirgi o'zgarishlar (jurnal) -------
        if (v['xfLogOpen'] == true) Positioned.fill(child: _logPanel(v, p)),

        // ------- Pastki qatlam -------
        Positioned(left: 0, right: 0, bottom: 0, child: _bottomOverlay(v, p)),
      ],
    );
  }

  // ================= FLY ANIMATSIYASI (dizayn: flyToFolder) =================
  void _launchFly(List<Map<String, dynamic>> events) {
    for (var i = 0; i < events.length; i++) {
      Future.delayed(Duration(milliseconds: i * 120), () {
        if (mounted) _flyOne(events[i], i);
      });
    }
  }

  void _flyOne(Map<String, dynamic> e, int i) {
    final p = curPal();
    final overlay = Overlay.of(context);
    final inputBox = _inputKey.currentContext?.findRenderObject() as RenderBox?;
    final folderBox = _fk[e['cat']]?.currentContext?.findRenderObject() as RenderBox?;
    if (inputBox == null) return;
    final start = inputBox.localToGlobal(Offset(14 + i * 8.0, -58));
    // Nishon: papka kartasi markazi; karta hali ko'rinmasa — biroz yuqoriga uchib so'nadi
    final end = folderBox != null
        ? folderBox.localToGlobal(Offset.zero) +
            Offset(folderBox.size.width / 2 - 62, folderBox.size.height / 2 - 18)
        : start - const Offset(0, 220);

    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 720));
    final curve = CurvedAnimation(parent: ctrl, curve: const Cubic(.22, .9, .26, 1));
    final inc = e['inc'] == true;
    final glow = inc ? p.green : p.red;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: curve,
        builder: (_, __) {
          final t = curve.value;
          final pos = Offset.lerp(start, end, t)!;
          final op = t < .08 ? t / .08 : (t > .82 ? (1 - t) / .18 : 1.0);
          final sc = 1.0 - t * .16;
          return Positioned(
            left: pos.dx,
            top: pos.dy,
            child: IgnorePointer(
              child: Opacity(
                opacity: op.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: sc,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: p.card2,
                      border: Border.all(color: p.bd2),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 32, offset: const Offset(0, 14)),
                        BoxShadow(color: glow.withValues(alpha: inc ? .40 : .22), blurRadius: 22),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tx('${e['emoji']} ${e['cat']}', size: 13, w: FontWeight.w500, color: p.ink),
                        const SizedBox(width: 8),
                        Tx('${e['amtTxt']}', size: 13, w: FontWeight.w600, color: inc ? p.green : p.red),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    overlay.insert(entry);
    ctrl.forward().whenComplete(() {
      entry.remove();
      ctrl.dispose();
      // Qo'ngan papka pulslaydi
      if (mounted) setState(() => _pulse[e['cat'] as String] = (_pulse[e['cat'] as String] ?? 0) + 1);
    });
  }

  // ================= SARLAVHA (dizayn: back + title + jurnal) =================
  Widget _header(Map<String, dynamic> v, Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
      child: Row(
        children: [
          Tap(
            onTap: v['xfBack'],
            child: SizedBox(width: 34, height: 34, child: Center(child: BackChevron(color: p.ink))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx('Xarajatlar', size: 17, w: FontWeight.w700, color: p.ink, ls: -0.2),
                const SizedBox(height: 1),
                Tx('${v['xfMonth']}', size: 11.5, color: p.t3),
              ],
            ),
          ),
          // Jurnal tugmasi (soat + yangilik nuqtasi)
          Tap(
            onTap: v['xfLogToggle'],
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd)),
              child: Stack(
                children: [
                  Center(child: Icon(Icons.history, size: 18, color: p.ink)),
                  if (v['xfLogDot'] == true)
                    Positioned(
                      top: 4, right: 4,
                      child: Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: p.green,
                          border: Border.all(color: p.bg, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= OY BALANSI =================
  Widget _balance(Map<String, dynamic> v, Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tx('${v['xfBalCap']}', size: 11, w: FontWeight.w600, color: p.t2, ls: 1.6),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Tx('${v['xfBalTxt']}', size: 30, w: FontWeight.w700,
                  color: v['xfBalPos'] == true ? p.green : p.red, ls: -0.6),
              const SizedBox(width: 7),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Tx("so'm", size: 13, color: p.t3),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Tx('Kirim ', size: 12, color: p.t2),
              Tx('${v['xfInTxt']}', size: 12, w: FontWeight.w600, color: p.green),
              const SizedBox(width: 18),
              Tx('Chiqim ', size: 12, color: p.t2),
              Tx('${v['xfOutTxt']}', size: 12, w: FontWeight.w600, color: p.red),
            ],
          ),
        ],
      ),
    );
  }

  // ================= PAPKALAR =================
  Widget _cap(String t, Pal p) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Tx(t, size: 11, w: FontWeight.w600, color: p.t2, ls: 1.6),
      );

  Widget _grid(List<Map<String, dynamic>> fs, Pal p) {
    final rows = <Widget>[];
    for (var i = 0; i < fs.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _folderCard(fs[i], p)),
          const SizedBox(width: 10),
          Expanded(child: i + 1 < fs.length ? _folderCard(fs[i + 1], p) : const SizedBox()),
        ],
      ));
      if (i + 2 < fs.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _folderCard(Map<String, dynamic> f, Pal p) {
    final inc = f['inc'] == true;
    final accent = inc ? p.green : p.red;
    final name = '${f['name']}';

    Widget card = Tap(
      onTap: f['open'],
      child: Container(
        key: _keyFor(name),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: inc ? Color.alphaBlend(p.green.withValues(alpha: .05), p.hov2) : p.hov2,
          border: Border.all(color: p.hair2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0, top: 10, bottom: 10,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(3), bottomRight: Radius.circular(3)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Tx('${f['emoji']}', size: 20, color: p.ink),
                      if (f['isNew'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: p.card2,
                            border: Border.all(color: p.bd2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Tx('Yangi ✨', size: 10, w: FontWeight.w600, color: p.t1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Tx(name, size: 12.5, w: FontWeight.w500, color: p.t2, maxLines: 1),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Flexible(
                        child: Tx('${f['totalTxt']}', size: 15, w: FontWeight.w600,
                            color: inc ? p.green : p.red, maxLines: 1),
                      ),
                      if (inc) ...[
                        const SizedBox(width: 5),
                        Container(
                          width: 14, height: 14, alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.green.withValues(alpha: .18),
                          ),
                          child: Tx('↑', size: 9, color: p.green),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity, height: 18,
                    child: _AnimSpark(
                      pts: (f['spark'] as List).cast<double>(),
                      color: inc ? p.green.withValues(alpha: .65) : p.t5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Yangi papka "pop" (dizayn: xkPop scale-bounce)
    if (f['isNew'] == true) {
      card = TweenAnimationBuilder<double>(
        key: ValueKey('pop-$name'),
        tween: Tween(begin: 0.82, end: 1.0),
        duration: const Duration(milliseconds: 550),
        curve: Curves.elasticOut,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: card,
      );
    }

    // Fly qo'nganda puls (scale 1.06 -> 1)
    final pc = _pulse[name] ?? 0;
    if (pc > 0) {
      card = TweenAnimationBuilder<double>(
        key: ValueKey('pulse-$name-$pc'),
        tween: Tween(begin: 1.06, end: 1.0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: card,
      );
    }
    return card;
  }

  Widget _emptyAll(Pal p) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 30),
      decoration: BoxDecoration(
        color: p.hov2,
        border: Border.all(color: p.hair2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Tx('Hozircha yozuvlar yo\'q', size: 14, w: FontWeight.w600, color: p.t1,
              align: TextAlign.center),
          const SizedBox(height: 6),
          Tx('Pastdagi maydonga yozing — AI o\'zi papkalarga saralaydi', size: 12,
              color: p.t4, align: TextAlign.center),
        ],
      ),
    );
  }

  // ================= ANIQLANMAGAN (tray) =================
  Widget _tray(Map<String, dynamic> v, Pal p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Tx('ANIQLANMAGAN', size: 11, w: FontWeight.w600, color: p.t2, ls: 1.6),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: p.red.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Tx('${v['xfTrayCount']}', size: 10, w: FontWeight.w600, color: p.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final t in (v['xfTrayRows'] as List).cast<Map<String, dynamic>>()) ...[
          _Shake(
            key: ValueKey('shake-${t['id']}'),
            child: Tap(
              onTap: t['toggle'],
              child: _Dashed(
                color: p.red.withValues(alpha: .45),
                radius: 14,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Tx('${t['text']}', size: 13, color: p.t1, maxLines: 1),
                          ),
                          const SizedBox(width: 8),
                          Tx('papka tanlang ↓', size: 11, color: p.t4),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Tx('${t['amtTxt']} so\'m', size: 13, w: FontWeight.w600, color: p.red),
                      if (t['open'] == true) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: [
                            for (final c in (t['chips'] as List).cast<Map<String, dynamic>>())
                              Tap(
                                onTap: c['pick'],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: p.card2,
                                    border: Border.all(color: p.bd),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Tx('${c['label']}', size: 12, w: FontWeight.w500, color: p.ink),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ================= PAPKA TAFSILOTI =================
  Widget _detail(Map<String, dynamic> v, Pal p) {
    return Container(
      color: p.bg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 20, 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
            child: Row(
              children: [
                Tap(
                  onTap: v['xfDetailClose'],
                  child: SizedBox(width: 34, height: 34, child: Center(child: BackChevron(color: p.ink))),
                ),
                Container(
                  width: 36, height: 36, alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(12)),
                  child: Tx('${v['xfDEmoji']}', size: 18, color: p.ink),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tx('${v['xfDName']}', size: 16, w: FontWeight.w700, color: p.ink, maxLines: 1),
                      const SizedBox(height: 1),
                      Tx('${v['xfDCount']}', size: 11.5, color: p.t3),
                    ],
                  ),
                ),
                SizedBox(
                  width: 60, height: 20,
                  child: _AnimSpark(
                    pts: (v['xfDSpark'] as List).cast<double>(),
                    color: v['xfDInc'] == true ? p.green.withValues(alpha: .65) : p.t5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Tx('${v['xfDTotalTxt']}', size: 28, w: FontWeight.w700,
                        color: v['xfDInc'] == true ? p.green : p.ink, ls: -0.5),
                    const SizedBox(width: 7),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Tx("so'm", size: 13, color: p.t3),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Tx('✎ tahrirlash · ✕ o\'chirish', size: 11, color: p.t4),
              ],
            ),
          ),
          Expanded(
            child: v['xfDEmpty'] == true
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                    child: Column(
                      children: [
                        Tx('Hozircha yozuvlar yo\'q', size: 14, w: FontWeight.w600, color: p.t1,
                            align: TextAlign.center),
                        const SizedBox(height: 6),
                        Tx('Pastdagi maydonga yozing — AI shu papkaga o\'zi qo\'shadi', size: 12,
                            color: p.t4, align: TextAlign.center),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 210),
                    children: [
                      for (final g in (v['xfDGroups'] as List).cast<Map<String, dynamic>>()) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                          child: Tx('${g['label']}'.toUpperCase(), size: 11, w: FontWeight.w600,
                              color: p.t2, ls: 1.6),
                        ),
                        for (final r in (g['rows'] as List).cast<Map<String, dynamic>>())
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _entryRow(r, p),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _entryRow(Map<String, dynamic> r, Pal p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.hov2,
        border: Border.all(color: p.hair2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx('${r['desc']}', size: 13.5, w: FontWeight.w500, color: p.ink, maxLines: 1),
                const SizedBox(height: 2),
                Tx('${r['time']}', size: 11, color: p.t4),
              ],
            ),
          ),
          Tx('${r['amtTxt']}', size: 13.5, w: FontWeight.w600,
              color: r['inc'] == true ? p.green : p.ink),
          const SizedBox(width: 8),
          _roundBtn('✎', r['edit'], p),
          const SizedBox(width: 6),
          _roundBtn('✕', r['del'], p),
        ],
      ),
    );
  }

  Widget _roundBtn(String glyph, dynamic onTap, Pal p) {
    return Tap(
      onTap: onTap,
      child: Container(
        width: 28, height: 28, alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd)),
        child: Tx(glyph, size: 11, color: p.t2),
      ),
    );
  }

  // ================= JURNAL =================
  Widget _logPanel(Map<String, dynamic> v, Pal p) {
    return Container(
      color: p.bg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 16, 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tx('Oxirgi o\'zgarishlar', size: 16, w: FontWeight.w700, color: p.ink),
                      const SizedBox(height: 1),
                      Tx('Yangi yozuvlar, tahrir va o\'chirishlar', size: 11.5, color: p.t3),
                    ],
                  ),
                ),
                _roundBtn('✕', v['xfLogToggle'], p),
              ],
            ),
          ),
          Expanded(
            child: v['xfLogEmpty'] == true
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                    child: Column(
                      children: [
                        Tx('Hozircha o\'zgarishlar yo\'q', size: 14, w: FontWeight.w600, color: p.t1,
                            align: TextAlign.center),
                        const SizedBox(height: 6),
                        Tx('Yozuv qo\'shsangiz, tahrirlasangiz yoki o\'chirsangiz shu yerda ko\'rinadi',
                            size: 12, color: p.t4, align: TextAlign.center),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 210),
                    children: [
                      for (final o in (v['xfLogRows'] as List).cast<Map<String, dynamic>>())
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _logRow(o, p),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _logRow(Map<String, dynamic> o, Pal p) {
    final isDel = o['isDel'] == true;
    final type = '${o['type']}';
    final badgeColor = type == 'add' ? p.green : type == 'del' ? p.red : p.t1;
    final badgeBg = type == 'add'
        ? p.green.withValues(alpha: .14)
        : type == 'del' ? p.red.withValues(alpha: .14) : p.card2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.hov2,
        border: Border.all(color: p.hair2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Tx('${o['emoji']}', size: 16, color: p.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${o['desc']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.5, fontWeight: FontWeight.w500,
                          color: isDel ? p.t3 : p.ink,
                          decoration: isDel ? TextDecoration.lineThrough : TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg, borderRadius: BorderRadius.circular(999)),
                      child: Tx('${o['badge']}', size: 9.5, w: FontWeight.w600, color: badgeColor),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Tx('${o['sub']}', size: 11, color: p.t4, maxLines: 1),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${o['amtTxt']}',
            style: GoogleFonts.inter(
              fontSize: 13.5, fontWeight: FontWeight.w600,
              color: isDel ? p.t3 : (o['inc'] == true ? p.green : p.ink),
              decoration: isDel ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
          if (o['canAct'] == true) ...[
            const SizedBox(width: 8),
            _roundBtn('✎', o['edit'], p),
            const SizedBox(width: 6),
            _roundBtn('✕', o['delTap'], p),
          ],
        ],
      ),
    );
  }

  // ================= PASTKI QATLAM =================
  Widget _bottomOverlay(Map<String, dynamic> v, Pal p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 60, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [p.bg.withValues(alpha: 0), p.bg.withValues(alpha: .88), p.bg],
          stops: const [0, .46, .82],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (v['xfEditingOpen'] == true) ...[
            _SlideIn(
              key: const ValueKey('editchip'),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 5, 6, 5),
                decoration: BoxDecoration(
                  color: p.card2,
                  border: Border.all(color: p.bd2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tx('Tahrirlanmoqda: ', size: 12, color: p.t2),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Tx('${v['xfEditLabel']}', size: 12, w: FontWeight.w600,
                          color: p.ink, maxLines: 1),
                    ),
                    const SizedBox(width: 8),
                    Tap(
                      onTap: v['xfEditCancel'],
                      child: Container(
                        width: 22, height: 22, alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: p.hair2),
                        child: Tx('✕', size: 10, color: p.t1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (v['xfToastOpen'] == true) ...[
            _SlideIn(
              key: ValueKey('toast-${v['xfToastText']}'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: p.card2,
                  border: Border.all(color: p.bd2),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .45), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: Row(
                  children: [
                    Expanded(child: Tx('${v['xfToastText']}', size: 13, color: p.ink)),
                    Tap(
                      onTap: v['xfUndo'],
                      child: Text(
                        'Bekor qilish',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600, color: p.ink,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (v['xfCfOpen'] == true) ...[
            _SlideIn(key: const ValueKey('confirm'), child: _confirmCard(v, p)),
            const SizedBox(height: 10),
          ],

          // Matn input (rangli highlight bilan) + yuborish
          Container(
            key: _inputKey,
            height: 46,
            decoration: BoxDecoration(
              color: p.field.withValues(alpha: .95),
              border: Border.all(color: p.bd),
              borderRadius: BorderRadius.circular(23),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 28, offset: const Offset(0, 10))],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  left: 16, right: 52,
                  child: Center(
                    child: _HlField(
                      value: '${v['xarTextVal'] ?? ''}',
                      onChanged: (t) => v['xarTextSet'](t),
                      hint: 'Oziq-ovqatga 120 000 sarfladim...',
                      onSubmit: v['xfSend'],
                    ),
                  ),
                ),
                Positioned(
                  right: 6, top: 6,
                  child: Tap(
                    onTap: v['xfSend'],
                    child: Opacity(
                      opacity: '${v['xarTextVal'] ?? ''}'.trim().isEmpty && v['xfBusy'] != true ? .4 : 1,
                      child: Container(
                        width: 34, height: 34, alignment: Alignment.center,
                        decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                        child: v['xfBusy'] == true
                            ? _PulseDots(color: p.bg)
                            : Tx('↑', size: 16, w: FontWeight.w700, color: p.bg),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Tx('Yozing — AI o\'zi papkalarga saralaydi', size: 11, color: p.t4),
          ),
        ],
      ),
    );
  }

  Widget _confirmCard(Map<String, dynamic> v, Pal p) {
    final isMerge = v['xfCfMerge'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.field,
        border: Border.all(color: p.bd2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 40, offset: const Offset(0, 16))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tx(isMerge ? 'BIRLASHTIRISHNI TASDIQLANG' : 'O\'CHIRISHNI TASDIQLANG',
              size: 11, w: FontWeight.w600, color: p.t2, ls: 1.6),
          const SizedBox(height: 12),
          if (isMerge)
            Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: .55,
                    child: _Dashed(
                      color: p.t5, radius: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tx('${v['xfCfFromTxt']}', size: 13, w: FontWeight.w500, color: p.ink, maxLines: 1),
                            const SizedBox(height: 4),
                            Tx('${v['xfCfFromSum']}', size: 12.5, color: p.t2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Tx('→', size: 16, color: p.t3),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: p.ink, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tx('${v['xfCfToTxt']}', size: 13, w: FontWeight.w500, color: p.ink, maxLines: 1),
                        const SizedBox(height: 4),
                        Tx('${v['xfCfToSum']}', size: 12.5, color: p.t2),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Opacity(
              opacity: .8,
              child: _Dashed(
                color: p.red.withValues(alpha: .55), radius: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Tx('${v['xfCfFromTxt']}', size: 13, w: FontWeight.w500, color: p.ink),
                      Tx('o\'chiriladi', size: 11, color: p.red),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Tap(
                  onTap: v['xfCfOk'],
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isMerge ? p.ink : p.red,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Tx('Tasdiqlash', size: 13, w: FontWeight.w700,
                        color: isMerge ? p.bg : const Color(0xFF140807)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tap(
                  onTap: v['xfCfNo'],
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: p.bd),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Tx('Bekor', size: 13, w: FontWeight.w600, color: p.t1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================= RANGLI INPUT (dizayn: highlight) =================
// Summa — yashil/qizil (+13% fon), toifa so'zi — card2 fon, buyruq/sana — hair2 fon.
class _HlController extends TextEditingController {
  static final _amtRe = RegExp(
      r"(\d{1,3}(?:[  .]\d{3})+|\d+)(\s*(?:ming|mln|million))?(\s*so['’ʻ`]?m)?",
      caseSensitive: false);
  static final _catRe = RegExp(
      r"oziq-ovqat|oziq|tushlik|nonushta|ovqat|bozor|market|taksi|avtobus|metro|benzin|transport|kofe|qahva|kommunal|svet|gaz|internet|telefon|kiyim|xarid\w*|do['’ʻ`]?kon|dori\w*|shifokor|apteka|kino|konsert|sport|zal|fitnes|kitob\w*|papka\w*|oylik|maosh|avans|mijoz\w*|sotuv\w*|biznes|daromad|bonus",
      caseSensitive: false);
  static final _cmdRe = RegExp(r"birlashtir\w*|o['’ʻ`]?chir\w*|keldi|tushdi|qaytdi",
      caseSensitive: false);
  static final _dateRe = RegExp(r"bugun|kechqurun|kecha|ertalab|ertaga", caseSensitive: false);
  static final _incRe = RegExp(
      r"\b(oylik|maosh|avans|daromad|bonus|kirim)\b|mijoz\w*|sotuv\w*|\bsotdim\b|keldi|tushdi|qaytdi|qaytardi",
      caseSensitive: false);
  static final _cutRe = RegExp(r",|\bva\b", caseSensitive: false);

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final p = curPal();
    final t = text;
    if (t.isEmpty) return TextSpan(style: style);

    // Segment yo'nalishi: vergul/"va" bo'laklari ichida INC so'zi bormi
    final cuts = <int>[0];
    for (final m in _cutRe.allMatches(t)) {
      cuts.add(m.start);
    }
    cuts.add(t.length);
    bool segIn(int pos) {
      for (var i = 0; i < cuts.length - 1; i++) {
        if (pos >= cuts[i] && pos < cuts[i + 1]) return _incRe.hasMatch(t.substring(cuts[i], cuts[i + 1]));
      }
      return false;
    }

    final ranges = <List<dynamic>>[]; // [s, e, type]
    void push(RegExp re, String type) {
      for (final m in re.allMatches(t)) {
        if (m.end > m.start) ranges.add([m.start, m.end, type]);
      }
    }

    push(_amtRe, 'amt');
    push(_catRe, 'cat');
    push(_cmdRe, 'cmd');
    push(_dateRe, 'date');
    ranges.sort((a, b) => (a[0] as int) != (b[0] as int)
        ? (a[0] as int) - (b[0] as int)
        : ((b[1] as int) - (b[0] as int)) - ((a[1] as int) - (a[0] as int)));
    final kept = <List<dynamic>>[];
    var last = 0;
    for (final r in ranges) {
      if ((r[0] as int) >= last) {
        kept.add(r);
        last = r[1] as int;
      }
    }

    final spans = <TextSpan>[];
    var pos = 0;
    for (final r in kept) {
      final s = r[0] as int, e = r[1] as int, type = r[2] as String;
      if (s > pos) spans.add(TextSpan(text: t.substring(pos, s)));
      Color c;
      Color bg;
      if (type == 'amt') {
        final cc = segIn(s) ? p.green : p.red;
        c = cc;
        bg = cc.withValues(alpha: .13);
      } else if (type == 'cat') {
        c = p.ink;
        bg = p.card2;
      } else if (type == 'cmd') {
        c = p.t1;
        bg = p.hair2;
      } else {
        c = p.t2;
        bg = p.hair2;
      }
      spans.add(TextSpan(
        text: t.substring(s, e),
        style: TextStyle(color: c, background: Paint()..color = bg),
      ));
      pos = e;
    }
    if (pos < t.length) spans.add(TextSpan(text: t.substring(pos)));
    return TextSpan(style: style, children: spans);
  }
}

/// Store bilan sinxron RANGLI TextField (StoreField + _HlController)
class _HlField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final VoidCallback? onSubmit;
  const _HlField({required this.value, required this.onChanged, this.hint, this.onSubmit});

  @override
  State<_HlField> createState() => _HlFieldState();
}

class _HlFieldState extends State<_HlField> {
  late final _HlController _c = _HlController()..text = widget.value;

  @override
  void didUpdateWidget(covariant _HlField old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) {
      _c.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final st = GoogleFonts.inter(fontSize: 14, color: p.ink);
    return TextField(
      controller: _c,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmit != null ? (_) => widget.onSubmit!() : null,
      style: st,
      cursorColor: p.ink,
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        border: InputBorder.none,
        hintText: widget.hint,
        hintStyle: st.copyWith(color: p.t5),
      ),
    );
  }
}

// ================= YORDAMCHI ANIMATSIYALAR =================

/// Jonli sparkline — nuqtalar o'zgarганда eski holatdan yangисига silliq o'tadi
class _AnimSpark extends StatefulWidget {
  final List<double> pts;
  final Color color;
  const _AnimSpark({required this.pts, required this.color});

  @override
  State<_AnimSpark> createState() => _AnimSparkState();
}

class _AnimSparkState extends State<_AnimSpark> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 550), value: 1);
  late List<double> _from = widget.pts;
  late List<double> _to = widget.pts;

  List<double> _now() {
    final t = Curves.easeOutCubic.transform(_c.value);
    return [
      for (var i = 0; i < _to.length; i++)
        lerpDouble(i < _from.length ? _from[i] : 0, _to[i], t) ?? _to[i],
    ];
  }

  @override
  void didUpdateWidget(covariant _AnimSpark old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.pts, widget.pts)) {
      _from = _now();
      _to = widget.pts;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(painter: _Spark(_now(), widget.color)),
    );
  }
}

/// Sparkline chizuvchi (dizayn: polyline, stroke 2, round)
class _Spark extends CustomPainter {
  final List<double> pts;
  final Color color;
  _Spark(this.pts, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = pts.length == 1 ? 0.0 : i / (pts.length - 1) * size.width;
      final y = size.height - (pts[i].clamp(0.0, 1.0) * size.height * 0.8) - size.height * 0.1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_Spark old) => old.pts != pts || old.color != color;
}

/// Shtrixli (dashed) ramka — dizayndagi 1.5px dashed
class _Dashed extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  const _Dashed({required this.child, required this.color, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashPainter(color, radius),
      child: child,
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashPainter(this.color, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, (d + dash).clamp(0, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color || old.radius != radius;
}

/// Paydo bo'lishda pastdan siljib kirish (dizayn: xkSlidein)
class _SlideIn extends StatelessWidget {
  final Widget child;
  const _SlideIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: c),
      ),
      child: child,
    );
  }
}

/// Paydo bo'lishda chayqalish (dizayn: xkShake — tray e'tibor tortadi)
class _Shake extends StatelessWidget {
  final Widget child;
  const _Shake({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (_, t, c) {
        final amp = (1 - t) * 5;
        final dx = amp * ((t * 25).floor() % 2 == 0 ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: c);
      },
      child: child,
    );
  }
}

/// Band holat: nuqtalar pulslashi (yuborish tugmasida)
class _PulseDots extends StatefulWidget {
  final Color color;
  const _PulseDots({required this.color});

  @override
  State<_PulseDots> createState() => _PulseDotsState();
}

class _PulseDotsState extends State<_PulseDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Opacity(
                opacity: (0.35 + 0.65 * ((t * 3 - i).clamp(0.0, 1.0) - ((t * 3 - i - 1).clamp(0.0, 1.0)))).clamp(0.2, 1.0),
                child: Container(
                  width: 3.5, height: 3.5,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

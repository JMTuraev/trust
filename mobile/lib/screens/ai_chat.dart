// Trust AI — moliyaviy hamroh chati (docs/ai-character.md).
// Circles tabi o'rniga keladi (flags.dart: kCirclesEnabled=false, kAiEnabled=true).
//
// Dizayn: ilovaning mavjud tili — 46px pill input (xarajat.dart bilan bir xil),
// r14 pufaklar, r16 blok kartalari, brend qizil/yashil (theme.dart).
//
// FAQAT MATN — mikrofon/ovoz UI yo'q (mahsulot qarori 2026-07-17, §11).
//
// Har AI javobi ostida "noto'g'ri javob" flag tugmasi — Google Play 2026 talabi.
import 'dart:async';

import 'package:flutter/material.dart';

import '../ai_blocks.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final ScrollController _sc = ScrollController();

  /// Allaqachon "qo'ngan" javoblar — ekran qayta qurilganda animatsiya takrorlanmasin.
  final Set<String> _landed = <String>{};
  int _lastCount = 0;
  bool _lastSending = false;

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sc.hasClients) return;
      _sc.animateTo(
        _sc.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _send([String? preset]) {
    if (preset != null) FocusManager.instance.primaryFocus?.unfocus(); // chip: klaviatura kerak emas
    store.aiSend_(preset);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final L0 = store.L();
    final msgs = (store.S['aiMsgs'] as List).cast<Map<String, dynamic>>();
    final sending = store.S['aiSending'] == true;
    final expired = store.S['subStatus'] == 'expired';

    // Yangi xabar / "yozmoqda" holati o'zgardi -> pastga suramiz
    if (msgs.length != _lastCount || sending != _lastSending) {
      _lastCount = msgs.length;
      _lastSending = sending;
      _scrollToEnd();
    }

    return Column(
      children: [
        _header(p, L0),
        Expanded(child: _body(p, L0, msgs, sending)),
        _bottom(p, L0, expired, sending),
      ],
    );
  }

  // ================= SARLAVHA =================
  Widget _header(Pal p, Map<String, dynamic> L0) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(L0['aiTitle'] as String, size: 22, w: FontWeight.w700, color: p.ink, ls: -0.3),
                const SizedBox(height: 3),
                Tx(L0['aiSubtitle'] as String, size: 12.5, color: p.t2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= TANA =================
  Widget _body(Pal p, Map<String, dynamic> L0, List<Map<String, dynamic>> msgs, bool sending) {
    final loading = store.S['aiLoading'] == true;
    final err = store.S['aiError'] as String?;

    if (msgs.isEmpty) {
      if (loading) return _skeleton(p);
      // Tarmoq xatosi: bo'sh-holat EMAS — aniq sabab + qayta urinish
      if (err != null && store.S['aiLoaded'] != true) return _loadError(p, L0, err);
      return _empty(p, L0);
    }

    final items = <Widget>[
      // AI disclosure (Play 2026) — suhbat boshida, ohista
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Center(child: Tx(L0['aiDisclosure'] as String, size: 11, color: p.t4, align: TextAlign.center, lh: 15)),
      ),
    ];
    for (final m in msgs) {
      final id = '${m['id']}';
      final isUser = m['role'] == 'user';
      final animate = !isUser && m['fresh'] == true && !_landed.contains(id);
      if (animate) _landed.add(id);
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: isUser
            ? _userBubble('${m['text']}', p)
            : _AiAnswer(
                key: ValueKey('ai-$id'),
                msg: m,
                animate: animate,
                onChip: (t) => _send(t),
                onGrow: _scrollToEnd,
              ),
      ));
    }
    if (sending) {
      items.add(Padding(padding: const EdgeInsets.only(bottom: 14), child: _typing(p, L0)));
    } else if (store.S['aiLimited'] == true) {
      items.add(Padding(padding: const EdgeInsets.only(bottom: 14), child: _limitCard(p, L0)));
    } else if (store.S['aiSendErr'] != null) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _errStrip('${store.S['aiSendErr']}', p, L0),
      ));
    }

    return ListView(
      controller: _sc,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      children: items,
    );
  }

  // ================= BO'SH HOLAT (xush kelibsiz + boshlang'ich chiplar) =================
  Widget _empty(Pal p, Map<String, dynamic> L0) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tx(L0['aiWelcomeTitle'] as String, size: 18, w: FontWeight.w700, color: p.ink, ls: -0.2),
          const SizedBox(height: 7),
          Tx(L0['aiWelcomeBody'] as String, size: 13.5, color: p.t1, lh: 20),
          const SizedBox(height: 18),
          Tx(L0['aiStartCap'] as String, size: 11, w: FontWeight.w600, color: p.t2, ls: 1.4),
          const SizedBox(height: 10),
          AiChips(
            items: [
              L0['aiStart1'] as String,
              L0['aiStart2'] as String,
              L0['aiStart3'] as String,
            ],
            onTap: (t) => _send(t),
          ),
          const SizedBox(height: 20),
          Tx(L0['aiDisclosure'] as String, size: 11, color: p.t4, lh: 15),
        ],
      ),
    );
  }

  Widget _skeleton(Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Skel(wf: .58, h: 15),
          SizedBox(height: 10),
          Skel(wf: .84, h: 15),
          SizedBox(height: 10),
          Skel(wf: .42, h: 15),
        ],
      ),
    );
  }

  Widget _loadError(Pal p, Map<String, dynamic> L0, String err) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tx(L0['aiLoadErr'] as String, size: 14, w: FontWeight.w600, color: p.ink),
          const SizedBox(height: 5),
          Tx(err, size: 12.5, color: p.t2, lh: 18),
          const SizedBox(height: 14),
          GhostBtn(
            label: L0['aiRetry'] as String,
            h: 44,
            onTap: () => store.loadAiMsgs(force: true),
          ),
        ],
      ),
    );
  }

  // ================= PUFAKLAR =================
  Widget _userBubble(String text, Pal p) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
            decoration: BoxDecoration(
              color: p.ink,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Tx(text, size: 14, color: p.bg, lh: 20),
          ),
        ),
      ],
    );
  }

  Widget _typing(Pal p, Map<String, dynamic> L0) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
          decoration: BoxDecoration(
            color: p.field,
            border: Border.all(color: p.hair),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomRight: Radius.circular(14),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TypingDots(color: p.t3),
              const SizedBox(width: 9),
              Tx(L0['aiTyping'] as String, size: 12.5, color: p.t2),
            ],
          ),
        ),
      ],
    );
  }

  /// 429 — savol chegarasi. Bu xato emas: do'stona, ayblovsiz (§3).
  /// Sabab store'da aniqlanadi (aiLimitKind): kunlik/oylik chegara — kutish kerak;
  /// 'slow' (daqiqalik tezlik) — o'tkinchi, shuning uchun qayta urinish tugmasi bilan
  /// (foydalanuvchi savolini qayta yozmasin — aiSend_ inputni tozalab yuborgan).
  Widget _limitCard(Pal p, Map<String, dynamic> L0) {
    final kind = '${store.S['aiLimitKind'] ?? 'day'}';
    final slow = kind == 'slow';
    final key = slow ? 'aiLimitSlow' : (kind == 'month' ? 'aiLimitMonth' : 'aiLimitHit');
    return Container(
      padding: EdgeInsets.fromLTRB(13, slow ? 6 : 12, slow ? 6 : 13, slow ? 6 : 12),
      decoration: BoxDecoration(
        color: p.field,
        border: Border.all(color: p.bd2),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: slow ? 6 : 0),
            child: Icon(Icons.schedule, size: 16, color: p.t2),
          ),
          const SizedBox(width: 9),
          Expanded(child: Tx(L0[key] as String, size: 12.5, color: p.ink, lh: 18)),
          if (slow)
            Tap(
              onTap: () => store.aiRetry_(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                child: Tx(L0['aiRetry'] as String, size: 12.5, w: FontWeight.w700, color: p.ink),
              ),
            ),
        ],
      ),
    );
  }

  Widget _errStrip(String text, Pal p, Map<String, dynamic> L0) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 6, 6, 6),
      decoration: BoxDecoration(
        color: p.red.withValues(alpha: .08),
        border: Border.all(color: p.red.withValues(alpha: .28)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Tx(text, size: 12.5, color: p.ink, lh: 17),
            ),
          ),
          Tap(
            onTap: () => store.aiRetry_(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              child: Tx(L0['aiRetry'] as String, size: 12.5, w: FontWeight.w700, color: p.red),
            ),
          ),
        ],
      ),
    );
  }

  // ================= PASTKI QATLAM (input yoki read-only) =================
  Widget _bottom(Pal p, Map<String, dynamic> L0, bool expired, bool sending) {
    // 402 — obuna tugagan: tarix ko'rinadi, yangi savol yozilmaydi (read-only)
    if (expired) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Tap(
          onTap: () => store.set({'screen': 'profil', 'clientId': null, 'receiptId': null, 'inLinkId': null}),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: p.field,
              border: Border.all(color: p.bd2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 17, color: p.t2),
                const SizedBox(width: 10),
                Expanded(child: Tx(L0['aiReadOnly'] as String, size: 12.5, color: p.ink, lh: 17)),
                const SizedBox(width: 6),
                ChevRight(color: p.t3),
              ],
            ),
          ),
        ),
      );
    }

    final val = '${store.S['aiInput'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: p.field.withValues(alpha: .95),
          border: Border.all(color: p.bd),
          borderRadius: BorderRadius.circular(23),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              left: 16,
              right: 52,
              child: Center(
                child: StoreField(
                  value: val,
                  onChanged: (t) => store.set({'aiInput': t}),
                  hint: L0['aiInputPh'] as String,
                  onSubmit: () => _send(),
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Tap(
                onTap: () => _send(),
                child: Opacity(
                  opacity: val.trim().isEmpty && !sending ? .4 : 1,
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                    child: sending
                        ? _TypingDots(color: p.bg)
                        : Tx('↑', size: 16, w: FontWeight.w700, color: p.bg),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI JAVOBI — bloklar ketma-ket "qo'nadi" + flag tugmasi
// ---------------------------------------------------------------------------
class _AiAnswer extends StatefulWidget {
  final Map<String, dynamic> msg;
  final bool animate;
  final ValueChanged<String> onChip;
  final VoidCallback onGrow;
  const _AiAnswer({
    super.key,
    required this.msg,
    required this.animate,
    required this.onChip,
    required this.onGrow,
  });

  @override
  State<_AiAnswer> createState() => _AiAnswerState();
}

class _AiAnswerState extends State<_AiAnswer> {
  late List<Map<String, dynamic>> _blocks = _read();
  int _shown = 0;
  Timer? _t;

  List<Map<String, dynamic>> _read() {
    final b = widget.msg['blocks'];
    final list = b is List ? b.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    if (list.isNotEmpty) return list;
    // Bloksiz javob (zaxira): oddiy matn pufagi
    final t = '${widget.msg['text'] ?? ''}'.trim();
    return t.isEmpty ? <Map<String, dynamic>>[] : [
      {'type': 'text', 'text': t}
    ];
  }

  @override
  void initState() {
    super.initState();
    if (!widget.animate) {
      _shown = _blocks.length; // tarix — darhol to'liq
      return;
    }
    _shown = _blocks.isEmpty ? 0 : 1;
    _tick();
  }

  // Bloklar birma-bir qo'nadi (ilovadagi xoreografiya uslubi)
  void _tick() {
    if (_shown >= _blocks.length) return;
    _t = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() => _shown++);
      widget.onGrow();
      _tick();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final L0 = store.L();
    final flagged = widget.msg['flagged'] == true;
    final done = _shown >= _blocks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _shown && i < _blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == _blocks.length - 1 ? 0 : 9),
            child: _Land(child: AiBlockView(block: _blocks[i], onChip: widget.onChip)),
          ),
        // "Noto'g'ri javob" — HAR AI javobi ostida (Google Play 2026 talabi)
        if (done && _blocks.isNotEmpty)
          Tap(
            onTap: flagged ? null : () => store.aiFlag_('${widget.msg['id']}'),
            child: Padding(
              padding: const EdgeInsets.only(top: 9, left: 2, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(flagged ? Icons.flag : Icons.outlined_flag,
                      size: 13, color: flagged ? p.red : p.t4),
                  const SizedBox(width: 5),
                  Tx(
                    (flagged ? L0['aiFlagged'] : L0['aiFlag']) as String,
                    size: 11,
                    w: FontWeight.w500,
                    color: flagged ? p.red : p.t4,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Blok "qo'nishi" — xiralikdan chiqib, pastdan siljib keladi.
class _Land extends StatelessWidget {
  final Widget child;
  const _Land({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (_, t, ch) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: ch),
      ),
      child: child,
    );
  }
}

/// "yozmoqda…" nuqtalari (xarajat.dart _PulseDots bilan bir xil ritm).
class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
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
              if (i > 0) const SizedBox(width: 3),
              Opacity(
                opacity: (0.35 + 0.65 * ((t * 3 - i).clamp(0.0, 1.0) - ((t * 3 - i - 1).clamp(0.0, 1.0))))
                    .clamp(0.2, 1.0),
                child: Container(
                  width: 4,
                  height: 4,
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

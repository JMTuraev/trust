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
import 'package:google_fonts/google_fonts.dart';

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

  /// Birinchi ochilishda suhbat pastidan (eng so'nggi xabardan) boshlanganmi.
  bool _openedAtEnd = false;

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

  /// Birinchi ochilishdagi "pastdan boshla" — animateTo EMAS: birinchi frame'da
  /// maxScrollExtent hali taxminiy (ListView lazy, bloklar/chartlar keyin
  /// joylashadi), animatsiya o'rtada to'xtab qolardi. Shuning uchun post-frame
  /// jumpTo (bu yangi elementlarni qurdirib extentni aniqlashtiradi) + layout
  /// tinchlangach yana bir jumpTo.
  void _jumpToEnd() {
    void jump() {
      if (!mounted || !_sc.hasClients) return;
      _sc.jumpTo(_sc.position.maxScrollExtent);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jump();
      Future.delayed(const Duration(milliseconds: 120), jump);
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

    // Yangi xabar / "yozmoqda" holati o'zgardi -> pastga suramiz.
    // Birinchi to'ldirilish (ochilish yoki tarix endi yuklandi) — sakrash bilan:
    // ekran darhol eng so'nggi xabardan boshlanadi; keyingilari — silliq animatsiya.
    if (msgs.length != _lastCount || sending != _lastSending) {
      final firstFill = !_openedAtEnd && msgs.isNotEmpty;
      _lastCount = msgs.length;
      _lastSending = sending;
      if (firstFill) {
        _openedAtEnd = true;
        _jumpToEnd();
      } else {
        _scrollToEnd();
      }
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
      padding: const EdgeInsets.fromLTRB(10, 16, 20, 10),
      child: Row(
        children: [
          // Orqaga — kelib chiqqan tabga qaytadi (bottom nav AI'da yashirin, shuning
          // uchun bu yagona chiqish yo'li). store.goAi() saqlagan 'aiFrom'ga boradi.
          Tap(
            onTap: () => store.vals()['goAiBack'](),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
              child: Icon(Icons.arrow_back_ios_new, size: 20, color: p.ink),
            ),
          ),
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
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: isUser
            ? _userBubble('${m['text']}', p)
            : _AiAnswer(
                key: ValueKey('ai-$id'),
                msg: m,
                // _landed bu yerda TEKSHIRILMAYDI — belgilash initState'da
                // (Set.add) bo'ladi: ListView elementni uzoq scrolldan keyin
                // qayta yaratsa animatsiya (va onGrow scroll) TAKRORLANMAYDI.
                animate: !isUser && m['fresh'] == true,
                landed: _landed,
                onChip: (t) => _send(t),
                onGrow: _scrollToEnd,
              ),
      ));
    }
    if (sending) {
      items.add(Padding(padding: const EdgeInsets.only(bottom: 14), child: _typing(p)));
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

  Widget _typing(Pal p) {
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
          // "yozmoqda" MATNI o'rniga brend loader: Trust logotipi ohista puls bilan
          // (mahsulot qarori 2026-07-17). Spinner emas; l10n['aiTyping'] kaliti saqlanadi.
          child: const _BrandLoader(size: 20),
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
        // 46px pill'ning o'suvchan varianti (PO 2026-07-17): 1 qator = 46
        // (20px satr + 12+12 padding + 1+1 border), matn ko'paygach 3 qatorgacha
        // kengayadi, undan keyin TextField o'z ichida scroll (maxLines:3).
        constraints: const BoxConstraints(minHeight: 46),
        decoration: BoxDecoration(
          color: p.field.withValues(alpha: .95),
          border: Border.all(color: p.bd),
          borderRadius: BorderRadius.circular(23),
        ),
        child: Row(
          // Yuborish tugmasi pastki-o'ngda qoladi (ko'p qatorda ham)
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: StoreField(
                  value: val,
                  onChanged: (t) => store.set({'aiInput': t}),
                  hint: L0['aiInputPh'] as String,
                  onSubmit: () => _send(),
                  minLines: 1,
                  maxLines: 3,
                  // Satr balandligi qat'iy 20px — konteyner o'sishi bashoratli
                  style: GoogleFonts.inter(fontSize: 14, color: p.ink, height: 20 / 14),
                ),
              ),
            ),
            const SizedBox(width: 6), // matn bilan tugma orasi avvalgidek 12px
            Padding(
              padding: const EdgeInsets.all(6),
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
  final Set<String> landed;
  final ValueChanged<String> onChip;
  final VoidCallback onGrow;
  const _AiAnswer({
    super.key,
    required this.msg,
    required this.animate,
    required this.landed,
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

  /// initState paytidagi animate — keyingi rebuild'larda widget.animate=false
  /// bo'lib keladi (_landed), lekin qo'nish davom etayotgan javob o'z
  /// "yangi"ligini eslab qolishi kerak.
  bool _fresh = false;

  /// So'z-reveal allaqachon BOSHLANGAN text bloklari (indeks) — ListView
  /// elementni qayta yaratsa (uzoq scroll) animatsiya takrorlanmasin.
  final Set<int> _revealed = <int>{};

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
    // Set.add — atomar "birinchi marta"mi tekshiruvi: yangi id'da true, ilgari
    // qo'ngan (yoki ListView qayta yaratgan) javobda false. Shu bilan uzoq
    // scrolldan keyingi re-mount animatsiyani va onGrow scrollни TAKRORLAMAYDI.
    _fresh = widget.animate && widget.landed.add('${widget.msg['id']}');
    if (!_fresh) {
      _shown = _blocks.length; // tarix yoki re-mount — darhol to'liq
      return;
    }
    _shown = _blocks.isEmpty ? 0 : 1;
    _tick();
  }

  // Bloklar birma-bir qo'nadi (ilovadagi xoreografiya uslubi).
  // Endigina qo'ngan blok TEXT bo'lsa, uning so'z-reveal'i ("marjon") tugashini
  // kutamiz: kechikish matn uzunligiga qarab cho'ziladi (aiTextRevealMs bilan
  // bir xil formula) + ohang uchun kichik pauza; boshqa bloklar — 420ms.
  void _tick() {
    if (_shown >= _blocks.length) return;
    final last = _blocks[_shown - 1];
    var ms = 420;
    if ('${last['type']}' == 'text') {
      final reveal = aiTextRevealMs('${last['text']}');
      if (reveal + 260 > ms) ms = reveal + 260;
    }
    _t = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() => _shown++);
      widget.onGrow();
      _tick();
    });
  }

  /// Text bloki uchun so'z-reveal bayrog'i — faqat BIRINCHI qurilishda true
  /// (Set.add: yangi indeksda true, takrorida false).
  /// Eslatma: bu build ichidagi ongli mutatsiya. Bir frame'da ikkinchi rebuild
  /// bo'lsa blok animate=false oladi — xavfsiz degradatsiya (matn darhol
  /// to'liq ko'rinadi, hech qachon "ko'rinmas matn" emas). AiTextBubble o'z
  /// animatsiyasini initState'da bir marta boshlaydi, keyingi false'lar uni
  /// to'xtatmaydi.
  bool _textAnim(int i) {
    if (!_fresh || '${_blocks[i]['type']}' != 'text') return false;
    return _revealed.add(i);
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
            child: _Land(
              child: AiBlockView(
                block: _blocks[i],
                onChip: widget.onChip,
                animate: _textAnim(i),
              ),
            ),
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

/// Brend "yozmoqda" indikatori — Trust logotipi (TrustMark) ohista nafas oladi
/// (opaklik + engil masshtab pulsi). Spinner emas: brend uslubi. Doimiy takrorlanadi,
/// shuning uchun javob necha soniya kutilsa ham "ishlayapman" hissi yo'qolmaydi.
class _BrandLoader extends StatefulWidget {
  final double size;
  const _BrandLoader({required this.size});

  @override
  State<_BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<_BrandLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Opacity(
          opacity: 0.45 + 0.55 * t,
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
        );
      },
      child: TrustMark(size: widget.size),
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

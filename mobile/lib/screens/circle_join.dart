// Circle'ga qo'shilish (taklif) — prototip frame 9 bilan 1:1.
// Taklif namunasi: Family Fund (bildirishnomadan ochiladi).
// + Kod bilan qo'shilish (join by code) sheet'i: kod -> preview -> qo'shilish.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';
import '../circles_data.dart';
import '../circle_ui.dart';
import '../circles_l10n.dart';

/// "Taklif kodini kiriting" oqimi (Circles ro'yxati / bo'sh holatdan ochiladi).
/// Do'stidan kod olgan foydalanuvchi: kodni joylaydi -> doira PREVIEW ko'radi
/// (nomi, a'zolar, badal) -> tasdiqlab qo'shiladi. Prototip sheet uslubida.
Future<void> showJoinByCode(BuildContext context) {
  final p = curPal();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: p.dim,
    builder: (_) => const CircleJoinByCodeSheet(),
  );
}

class CircleJoinByCodeSheet extends StatefulWidget {
  const CircleJoinByCodeSheet({super.key});

  @override
  State<CircleJoinByCodeSheet> createState() => _CircleJoinByCodeSheetState();
}

class _CircleJoinByCodeSheetState extends State<CircleJoinByCodeSheet> {
  String _code = '';
  bool _busy = false; // so'rov ketmoqda (preview yoki join) — ikki bosishdan himoya
  String? _error; // inline xato (sheet toast'ni yopib turadi, shu sabab inline)
  Map<String, dynamic>? _preview; // GET /join/:token natijasi

  String get _token => extractInviteCode(_code);

  // 1-bosqich: kodni tekshirish (preview olish)
  Future<void> _check() async {
    final t = _token;
    if (_busy || t.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await circlesRepo.joinPreview(t);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok && r.data is Map) {
        _preview = Map<String, dynamic>.from(r.data as Map);
      } else {
        _error = r.status == 404 ? cf('codeInvalid') : r.error;
      }
    });
  }

  // 2-bosqich: qo'shilish
  Future<void> _join() async {
    final t = _token;
    if (_busy || t.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await circlesRepo.joinByToken(t);
    if (!mounted) return;
    if (r.ok && r.data is Map) {
      final id = '${(r.data as Map)['id']}';
      final v = store.vals();
      Navigator.pop(context);
      v['openCircle'](id); // set() — ro'yxat ham yangilanadi
      store.toast_(cf('toastJoined'));
      return;
    }
    setState(() {
      _busy = false;
      _error = r.status == 404
          ? cf('codeInvalid')
          : r.status == 402
              ? cf('subExpiredErr')
              : r.error; // 400 (poyga: to'lib/yopilib qolgan) — server matni
    });
  }

  // Allaqachon a'zo bo'lgan doirani ochish
  void _openExisting() {
    final id = '${_preview?['id'] ?? ''}';
    if (id.isEmpty) return;
    final v = store.vals();
    Navigator.pop(context);
    v['openCircle'](id);
  }

  // Boshqa kod kiritish — 1-bosqichga qaytish
  void _reset() => setState(() {
        _preview = null;
        _error = null;
        _code = '';
      });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Padding(
      // Klaviatura ochilganda panel ko'tariladi (kod maydoni yopilib qolmasin)
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
        ),
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(color: p.bd, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: _preview == null ? _codeEntry(p) : _previewBody(p),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 1-bosqich: kod kiritish ----
  List<Widget> _codeEntry(Pal p) {
    final ready = !_busy && _token.length >= 12;
    return [
      Tx(cf('enterCodeTitle'), size: 16.5, w: FontWeight.w600, color: p.ink),
      const SizedBox(height: 6),
      Tx(cf('enterCodeHelp'), size: 12.5, color: p.t2, lh: 17.5),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)),
        child: StoreField(
          value: _code,
          onChanged: (t) => setState(() => _code = t),
          hint: cf('enterCodeHint'),
          autofocus: true,
          keyboardType: TextInputType.visiblePassword, // hex kod — avtokorreksiyasiz
          onSubmit: _check,
          style: GoogleFonts.inter(fontSize: 14, color: p.ink, letterSpacing: 1.2),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Tx(_error!, size: 12, color: p.red, lh: 16.8),
      ],
      const SizedBox(height: 14),
      Opacity(
        opacity: ready ? 1 : 0.5,
        child: CircleBtn(
          label: _busy ? '…' : cf('continueBtn'),
          onTap: () {
            if (ready) _check();
          },
        ),
      ),
      CircleLink(label: cf('cancel'), onTap: () => Navigator.pop(context)),
    ];
  }

  // ---- 2-bosqich: doira preview + qo'shilish ----
  List<Widget> _previewBody(Pal p) {
    final j = _preview!;
    final name = (j['name'] as String?) ?? '';
    final owner = (j['owner_name'] as String?) ?? '';
    final cur = curSymbol((j['currency'] as String?) ?? 'UZS');
    final amount = (j['amount'] as num?)?.toInt() ?? 0;
    final membersCount = (j['members_count'] as num?)?.toInt() ?? 0;
    final roundsTotal = (j['rounds_total'] as num?)?.toInt() ?? 0;
    final nextPos = (j['next_position'] as num?)?.toInt() ?? (roundsTotal + 1);
    final already = j['already_member'] == true;
    final invited = j['invited'] == true;
    final active = j['status'] == 'active';
    final full = membersCount >= 24 && !already && !invited;
    final joinable = active && !already && !full;
    // Yangi qo'shiluvchi oxiriga qo'shiladi: jami roundlar = nextPos bo'ladi
    final showTurn = joinable && !invited;

    return [
      Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.field, shape: BoxShape.circle),
            child: CircleGlyph(size: 24, color: p.ink),
          ),
          const SizedBox(height: 12),
          Tx(name, size: 19, w: FontWeight.w700, color: p.ink, ls: -0.3, align: TextAlign.center),
          const SizedBox(height: 3),
          Tx(cf('invitedBy', {'name': owner}), size: 12.5, color: p.t2),
        ],
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: CircleStatCell(k: cf('membersK'), val: cf('people', {'n': '$membersCount'}))),
        const SizedBox(width: 10),
        Expanded(child: CircleStatCell(k: cf('contribution'), val: cf('contributionMo', {'amt': money(amount, cur)}))),
      ]),
      if (showTurn) ...[
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: CircleStatCell(k: cf('duration'), val: cf('roundsN', {'n': '$nextPos'}))),
          const SizedBox(width: 10),
          Expanded(child: CircleStatCell(k: cf('yourTurn'), val: cf('roundN', {'n': '$nextPos'}))),
        ]),
      ],
      const SizedBox(height: 16),
      if (!active)
        Tx(cf('circleEndedErr'), size: 12.5, color: p.red, align: TextAlign.center, lh: 17.5)
      else if (full)
        Tx(cf('circleFullErr'), size: 12.5, color: p.red, align: TextAlign.center, lh: 17.5)
      else if (already)
        Tx(cf('alreadyMemberErr'), size: 12.5, color: p.t1, align: TextAlign.center, lh: 17.5),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Tx(_error!, size: 12, color: p.red, align: TextAlign.center, lh: 16.8),
      ],
      const SizedBox(height: 12),
      if (joinable)
        Opacity(
          opacity: _busy ? 0.55 : 1,
          child: CircleBtn(label: _busy ? '…' : cf('joinBtn'), onTap: _join),
        )
      else if (already)
        CircleBtn(label: cf('openCircleBtn'), onTap: _openExisting),
      CircleLink(label: cf('anotherCode'), onTap: _busy ? () {} : _reset),
    ];
  }
}

class CircleJoinScreen extends StatefulWidget {
  const CircleJoinScreen({super.key});

  @override
  State<CircleJoinScreen> createState() => _CircleJoinScreenState();
}

class _CircleJoinScreenState extends State<CircleJoinScreen> {
  bool _busy = false; // qo'shilish/rad — ikki marta bosishdan himoya

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final c = circlesRepo.byId(v['circleId'] as String?);
    if (c == null) return const SizedBox.shrink();

    final name = c.name;
    final len = c.members.length;
    final amount = c.amount;
    final total = c.roundsTotal;
    final pool = c.pool;
    final cur = c.currency;
    final yourTurn = c.you?.payoutPosition ?? 1;
    final admins = c.members.where((m) => m.isAdmin).toList();
    final inviter = admins.isNotEmpty ? admins.first.name : (c.members.isNotEmpty ? c.members.first.name : '');

    Widget dotLine(String text, {bool first = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: p.hair2))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 3), child: TlDot(color: p.green)),
              const SizedBox(width: 12),
              Expanded(child: Tx(text, size: 12.5, color: p.t1, lh: 17.5)),
            ],
          ),
        );

    return Column(
      children: [
        CircleHeader(
          leading: Tap(
            onTap: () => v['closeCircleJoin'](),
            child: SizedBox(width: 34, height: 34, child: Center(child: CloseGlyph(color: p.t2))),
          ),
          title: cf('joinTitle'),
          trailing: const SizedBox(width: 16),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.field, shape: BoxShape.circle),
                      child: CircleGlyph(size: 24, color: p.ink),
                    ),
                    const SizedBox(height: 12),
                    Tx(name, size: 19, w: FontWeight.w700, color: p.ink, ls: -0.3),
                    const SizedBox(height: 3),
                    Tx(cf('invitedBy', {'name': inviter}), size: 12.5, color: p.t2),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(child: CircleStatCell(k: cf('membersK'), val: cf('people', {'n': '$len'}))),
                      const SizedBox(width: 10),
                      Expanded(child: CircleStatCell(k: cf('contribution'), val: cf('contributionMo', {'amt': money(amount, cur)}))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: CircleStatCell(k: cf('duration'), val: cf('roundsN', {'n': '$total'}))),
                      const SizedBox(width: 10),
                      Expanded(child: CircleStatCell(k: cf('yourTurn'), val: cf('roundN', {'n': '$yourTurn'}))),
                    ]),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    dotLine(cf('joinStep1', {'amt': money(amount, cur)}), first: true),
                    dotLine(cf('joinStep2', {'pool': money(pool, cur)})),
                    dotLine(cf('joinStep3', {'r': '$yourTurn'})),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair))),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: Column(
            children: [
              Opacity(
                opacity: _busy ? 0.55 : 1,
                child: CircleBtn(
                  label: _busy ? '…' : cf('joinBtn'),
                  onTap: () {
                    if (_busy) return;
                    setState(() => _busy = true);
                    v['circleJoinAccept']();
                  },
                ),
              ),
              CircleLink(
                label: cf('decline'),
                onTap: () {
                  if (_busy) return;
                  setState(() => _busy = true);
                  v['circleDecline']();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

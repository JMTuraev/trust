// Yangi Circle yaratish — real a'zolar (ism + telefon), backendga yuboriladi.
//  • valyuta dropdown  • Monthly / Custom (kalendarda raqamlangan sanalar)
//  • a'zolarni qo'lda qo'shish (mock YO'Q)  • jonli payout order (In turn / Random / I pick)
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';
import '../circles_data.dart';
import '../circle_ui.dart';
import '../circles_l10n.dart';

const List<(String, String)> _kCurrencies = [
  ('\$', 'USD'), ("so'm", 'UZS'), ('€', 'EUR'), ('₽', 'RUB'), ('£', 'GBP'), ('₸', 'KZT'),
];
const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _fmtDate(DateTime d) => '${_mon[d.month - 1]} ${d.day}';
const _tints = [Tint.warm, Tint.green, Tint.blue];
Tint _tintAt(int i, bool isYou) => isYou ? Tint.me : _tints[i % _tints.length];
String _ini(String n) {
  final w = n.split(' ').where((x) => x.isNotEmpty).toList();
  if (w.isEmpty) return '?';
  if (w.first.toLowerCase() == 'you') return 'You';
  return w.map((x) => x[0]).take(2).join().toUpperCase();
}

// Formadagi a'zo (o'zgaruvchan ism/telefon)
class _NM {
  final int id;
  String name;
  String phone = '';
  final bool isYou;
  _NM({required this.id, this.name = '', this.isYou = false});
}

class CircleCreateScreen extends StatefulWidget {
  const CircleCreateScreen({super.key});

  @override
  State<CircleCreateScreen> createState() => _CircleCreateScreenState();
}

class _CircleCreateScreenState extends State<CircleCreateScreen> with SingleTickerProviderStateMixin {
  final _rng = Random();
  String _name = '';
  String _amount = '50';
  String _cur = '\$';
  String _freq = 'monthly';
  String _order = 'inTurn';
  int _nextId = 1;
  late final List<_NM> _people = [_NM(id: 0, name: 'You', isYou: true), _NM(id: _nextId++)];
  final List<DateTime> _dates = [];
  late DateTime _calMonth;
  Map<int, int> _pos = {};
  final List<int> _pickOrder = [];
  bool _busy = false;
  late final AnimationController _shuffleCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _shuffleCtrl.dispose();
    super.dispose();
  }

  int get _count => _people.length;
  int get _amt => int.tryParse(_amount.replaceAll(RegExp(r'\D'), '')) ?? 0;
  String _money(int n) => money(n, _cur);

  // ---- a'zolar ----
  void _addMember() {
    if (_people.length >= 12) return;
    setState(() => _people.add(_NM(id: _nextId++)));
    if (_order == 'random') _shuffle();
  }

  void _removeMember(int id) {
    setState(() {
      _people.removeWhere((m) => m.id == id && !m.isYou);
      _pickOrder.remove(id);
      if (_dates.length > _people.length) _dates.removeRange(_people.length, _dates.length);
    });
    if (_order == 'random') _shuffle();
  }

  // ---- payout ----
  int? _posOf(_NM m, int idx) {
    switch (_order) {
      case 'random':
        return _pos[m.id];
      case 'iPick':
        final i = _pickOrder.indexOf(m.id);
        return i >= 0 ? i + 1 : null;
      default:
        return idx + 1;
    }
  }

  void _setOrder(String o) {
    setState(() => _order = o);
    if (o == 'random') _shuffle();
    if (o == 'iPick') setState(() => _pickOrder.clear());
  }

  void _shuffle() {
    final ids = _people.map((m) => m.id).toList();
    final nums = List.generate(ids.length, (i) => i + 1)..shuffle(_rng);
    setState(() => _pos = {for (var i = 0; i < ids.length; i++) ids[i]: nums[i]});
    _shuffleCtrl.forward(from: 0);
  }

  void _pick(_NM m) {
    setState(() => _pickOrder.contains(m.id) ? _pickOrder.remove(m.id) : _pickOrder.add(m.id));
  }

  List<_NM> _sequence() {
    switch (_order) {
      case 'random':
        return [..._people]..sort((a, b) => (_pos[a.id] ?? 0).compareTo(_pos[b.id] ?? 0));
      case 'iPick':
        final picked = _pickOrder.map((id) => _people.firstWhere((m) => m.id == id)).toList();
        final rest = _people.where((m) => !_pickOrder.contains(m.id)).toList();
        return [...picked, ...rest];
      default:
        return _people;
    }
  }

  // ---- calendar ----
  void _toggleDate(DateTime d) {
    setState(() {
      final i = _dates.indexWhere((x) => x.year == d.year && x.month == d.month && x.day == d.day);
      if (i >= 0) {
        _dates.removeAt(i);
      } else if (_dates.length < _count) {
        _dates.add(d);
      }
    });
  }

  void _autoDates() {
    setState(() {
      _dates.clear();
      final y = _calMonth.year, m = _calMonth.month;
      final daysIn = DateTime(y, m + 1, 0).day;
      final step = (daysIn - 2) / _count;
      for (var i = 0; i < _count; i++) {
        final day = (2 + step * i).round().clamp(1, daysIn);
        final d = DateTime(y, m, day);
        if (!_dates.any((x) => x.day == d.day)) _dates.add(d);
      }
    });
  }

  Future<void> _create() async {
    if (_busy) return;
    if (_amt <= 0) {
      store.toast_(cf('needAmount'));
      return;
    }
    if (_people.length < 2) {
      store.toast_(cf('needMembers'));
      return;
    }
    // Dublikat telefonlar — server ham rad etadi, lekin oldindan aniq xabar beramiz
    final phones = _people.map((m) => m.phone.replaceAll(RegExp(r'\D'), '')).where((s) => s.isNotEmpty).toList();
    if (phones.toSet().length != phones.length) {
      store.toast_(cf('dupPhone'));
      return;
    }
    final seq = _sequence();
    final rank = {for (var i = 0; i < seq.length; i++) seq[i].id: i + 1};
    final members = [
      for (final m in _people)
        {
          'name': m.isYou ? 'You' : (m.name.trim().isEmpty ? 'Member ${rank[m.id]}' : m.name.trim()),
          if (!m.isYou && m.phone.trim().isNotEmpty) 'phone': m.phone.trim(),
          'payout_position': rank[m.id],
          'is_you': m.isYou,
        },
    ];
    List<String> due;
    if (_freq == 'custom' && _dates.isNotEmpty) {
      due = _dates.map(_fmtDate).toList();
    } else {
      final now = DateTime.now();
      due = [for (var i = 0; i < _people.length; i++) _fmtDate(DateTime(now.year, now.month + 1 + i, 20))];
    }
    final body = <String, dynamic>{
      'name': _name.trim().isEmpty ? 'New Circle' : _name.trim(),
      'amount': _amt,
      'currency': curCode(_cur),
      'frequency': _freq == 'custom' ? 'custom' : 'monthly',
      'payout_order': _order,
      'members': members,
      'due_dates': due,
    };
    setState(() => _busy = true);
    // Repo bevosita: xatoda forma OCHIQ qoladi (kiritilgan ma'lumot yo'qolmaydi),
    // muvaffaqiyatda yangi doira darhol ochiladi.
    final c = await circlesRepo.createCircle(body);
    if (!mounted) return;
    setState(() => _busy = false);
    if (c != null) {
      store.set({'circleCreateOpen': false, 'circleOpen': true, 'circleId': c.id});
      store.toast_(cf('toastCreated'));
    } else {
      // 402 — obuna tugagan: lokalizatsiyalangan xabar (server matni o'zbekcha)
      store.toast_(circlesRepo.errorStatus == 402 ? cf('subExpiredErr') : (circlesRepo.error ?? cf('toastError')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();

    Widget sec(String cap, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Cap(cap, ls: 1.5), const SizedBox(height: 8), child],
          ),
        );

    // Siz nechanchi round'da olasiz (summary uchun)
    final youIdx = _people.indexWhere((m) => m.isYou);
    final youPos = _posOf(_people[youIdx], youIdx) ?? 1;

    return Column(
      children: [
        CircleHeader(
          leading: Tap(
            onTap: () => v['closeCircleCreate'](),
            child: SizedBox(width: 34, height: 34, child: Center(child: CloseGlyph(color: p.t2))),
          ),
          title: cf('newCircle'),
          trailing: Tap(onTap: _create, child: Tx(cf('create'), size: 13.5, w: FontWeight.w600, color: p.t3)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              sec(
                cf('name'),
                _fieldBox(p, StoreField(
                  value: _name,
                  onChanged: (t) => setState(() => _name = t),
                  hint: 'Family Fund',
                  style: GoogleFonts.inter(fontSize: 14, color: p.ink),
                )),
              ),
              sec(cf('contribution'), _amountField(p)),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: CircleSeg(
                  options: [('monthly', cf('monthly')), ('custom', cf('custom'))],
                  value: _freq,
                  onChanged: (f) => setState(() => _freq = f),
                ),
              ),
              if (_freq == 'custom') Padding(padding: const EdgeInsets.only(top: 12), child: _calendar(p)),
              sec(cf('membersLabel'), _membersList(p)),
              sec(cf('payoutOrder'), _payout(p)),
              Container(
                margin: const EdgeInsets.only(top: 18),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tx(cf('summaryLine', {'amt': _money(_amt), 'n': '$_count', 'pool': _money(_amt * _count)}),
                        size: 13.5, w: FontWeight.w600, color: p.ink),
                    const SizedBox(height: 3),
                    Tx(cf('summarySub', {'n': '$_count', 'r': '$youPos'}), size: 11.5, color: p.t2, lh: 16.1),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair))),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: CircleBtn(label: _busy ? '…' : cf('createBtn'), onTap: _create),
        ),
      ],
    );
  }

  Widget _fieldBox(Pal p, Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.hair2)),
        child: child,
      );

  Widget _amountField(Pal p) {
    return _fieldBox(
      p,
      Row(
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _cur,
              isDense: true,
              dropdownColor: p.bg,
              borderRadius: BorderRadius.circular(12),
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: p.t3),
              items: [
                for (final c in _kCurrencies)
                  DropdownMenuItem(value: c.$1, child: Tx('${c.$1}  ${c.$2}', size: 14, w: FontWeight.w600, color: p.ink)),
              ],
              selectedItemBuilder: (_) => [
                for (final c in _kCurrencies)
                  Align(alignment: Alignment.centerLeft, child: Tx(c.$1, size: 15, w: FontWeight.w700, color: p.ink)),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _cur = val);
              },
            ),
          ),
          Container(width: 1, height: 22, color: p.bd, margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(
            child: StoreField(
              value: _amount,
              onChanged: (t) {
                var d = t.replaceAll(RegExp(r'\D'), '');
                if (d.length > 9) d = d.substring(0, 9);
                setState(() => _amount = d);
              },
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: p.ink),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- a'zolar ro'yxati (real, tahrirlanadigan) ----------
  Widget _membersList(Pal p) {
    return Column(
      children: [
        for (var i = 0; i < _people.length; i++) _memberEdit(p, _people[i], i),
        if (_people.length < 12)
          Tap(
            onTap: _addMember,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const DashAvatar(size: 30),
                  const SizedBox(width: 10),
                  Tx(cf('inviteMember'), size: 13.5, w: FontWeight.w600, color: p.t2),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _memberEdit(Pal p, _NM m, int i) {
    if (m.isYou) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const CAvatar(initials: 'You', size: 30, tint: Tint.me),
          const SizedBox(width: 10),
          Tx('You', size: 13.5, w: FontWeight.w600, color: p.ink),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CAvatar(initials: _ini(m.name), size: 30, tint: _tintAt(i, false)),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: StoreField(
              value: m.name,
              onChanged: (t) => setState(() => m.name = t),
              hint: cf('name'),
              style: GoogleFonts.inter(fontSize: 13.5, color: p.ink),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: StoreField(
              value: m.phone,
              onChanged: (t) => setState(() => m.phone = t),
              hint: '+998…',
              keyboardType: TextInputType.phone,
              style: GoogleFonts.inter(fontSize: 12.5, color: p.t1),
            ),
          ),
          Tap(
            onTap: () => _removeMember(m.id),
            child: SizedBox(width: 30, height: 30, child: Icon(Icons.close_rounded, size: 16, color: p.t4)),
          ),
        ],
      ),
    );
  }

  // ---------- kalendar ----------
  Widget _calendar(Pal p) {
    final y = _calMonth.year, m = _calMonth.month;
    final daysIn = DateTime(y, m + 1, 0).day;
    final lead = DateTime(y, m, 1).weekday - 1;
    final slots = ((lead + daysIn) / 7).ceil() * 7;

    Widget cell(int slot) {
      final dayNum = slot - lead + 1;
      if (dayNum < 1 || dayNum > daysIn) return const Expanded(child: SizedBox(height: 42));
      final idx = _dates.indexWhere((x) => x.year == y && x.month == m && x.day == dayNum);
      final sel = idx >= 0;
      return Expanded(
        child: Tap(
          onTap: () => _toggleDate(DateTime(y, m, dayNum)),
          child: SizedBox(
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: sel ? BoxDecoration(shape: BoxShape.circle, color: p.ink) : null,
                  child: Tx('$dayNum', size: 13, w: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? p.bg : p.t1),
                ),
                if (sel)
                  Positioned(
                    top: 2,
                    right: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: p.green, border: Border.all(color: p.bg, width: 1.5)),
                      child: Tx('${idx + 1}', size: 9, w: FontWeight.w700, color: p.bg),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.hair2)),
      child: Column(
        children: [
          Row(
            children: [
              Tap(
                onTap: () => setState(() => _calMonth = DateTime(y, m - 1)),
                child: SizedBox(width: 34, height: 34, child: Icon(Icons.chevron_left_rounded, size: 22, color: p.t2)),
              ),
              Expanded(child: Tx('${_mon[m - 1]} $y', size: 13.5, w: FontWeight.w600, color: p.ink, align: TextAlign.center)),
              Tap(
                onTap: () => setState(() => _calMonth = DateTime(y, m + 1)),
                child: SizedBox(width: 34, height: 34, child: Icon(Icons.chevron_right_rounded, size: 22, color: p.t2)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                for (final w in const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
                  Expanded(child: Tx(w, size: 10.5, w: FontWeight.w600, color: p.t4, align: TextAlign.center)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                for (var wk = 0; wk < slots ~/ 7; wk++) Row(children: [for (var d = 0; d < 7; d++) cell(wk * 7 + d)]),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Expanded(child: Tx('${cf('pickDates', {'n': '$_count'})} · ${_dates.length}/$_count', size: 11.5, color: p.t2)),
                Tap(
                  onTap: _autoDates,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(16)),
                    child: Tx(cf('autoFill'), size: 11.5, w: FontWeight.w600, color: p.ink),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- payout order (jonli) ----------
  Widget _payout(Pal p) {
    final hint = _order == 'random' ? cf('orderRandom') : (_order == 'iPick' ? cf('orderPick') : cf('orderInTurn'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleSeg(
          options: [('inTurn', cf('inTurn')), ('random', cf('random')), ('iPick', cf('iPick'))],
          value: _order,
          onChanged: _setOrder,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Tx(hint, size: 11.5, color: p.t2, lh: 16.1)),
            if (_order == 'random')
              Tap(
                onTap: _shuffle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotationTransition(turns: _shuffleCtrl, child: Icon(Icons.casino_rounded, size: 15, color: p.ink)),
                      const SizedBox(width: 6),
                      Tx(cf('shuffle'), size: 11.5, w: FontWeight.w600, color: p.ink),
                    ],
                  ),
                ),
              )
            else if (_order == 'iPick' && _pickOrder.isNotEmpty)
              Tap(
                onTap: () => setState(() => _pickOrder.clear()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(16)),
                  child: Tx(cf('reset'), size: 11.5, w: FontWeight.w600, color: p.ink),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < _people.length; i++) _payoutRow(p, _people[i], i),
      ],
    );
  }

  Widget _payoutRow(Pal p, _NM m, int idx) {
    final n = _posOf(m, idx);
    final tappable = _order == 'iPick';
    final label = m.isYou ? 'You' : (m.name.trim().isEmpty ? 'Member ${idx + 1}' : m.name.trim());
    return Tap(
      onTap: tappable ? () => _pick(m) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            _numBadge(p, n),
            const SizedBox(width: 12),
            CAvatar(initials: m.isYou ? 'You' : _ini(m.name), size: 30, tint: _tintAt(idx, m.isYou)),
            const SizedBox(width: 10),
            Expanded(child: Tx(label, size: 13.5, color: p.ink, maxLines: 1, ellipsis: true)),
            if (tappable && n == null) Tx(cf('add'), size: 11.5, w: FontWeight.w600, color: p.t3),
          ],
        ),
      ),
    );
  }

  Widget _numBadge(Pal p, int? n) {
    final assigned = n != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Container(
        key: ValueKey(n ?? -1),
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: assigned ? p.ink : p.field, border: assigned ? null : Border.all(color: p.bd)),
        child: Tx(assigned ? '$n' : '·', size: assigned ? 12.5 : 15, w: FontWeight.w700, color: assigned ? p.bg : p.t3),
      ),
    );
  }
}

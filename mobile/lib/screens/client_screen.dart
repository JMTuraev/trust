// Hamkor sahifasi — QARZ DAFTARI (ledger). Erkin matnli chat YO'Q (spec 4.1).
// Tuzilma: header (balans) → tasdiqlash cardlari → eski yozuvlar (join review)
// → lenta (qarz kartochkalari) → 3 aqlli tugma / input panel → dialoglar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter, TextEditingValue, TextSelection;
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

// "Kutilmoqda"/tasdiq urg'usi uchun issiq rang (amber-700)
const _amber = Color(0xFFB45309);

// Summani jonli "x xxx xxx" ko'rinishida guruhlovchi formatter (xarajat bilan bir xil mantiq).
class _GroupFmt extends TextInputFormatter {
  static final _d = RegExp(r'\d');

  String _group(String digits) {
    final b = StringBuffer();
    for (var k = 0; k < digits.length; k++) {
      if (k > 0 && (digits.length - k) % 3 == 0) b.write(' ');
      b.write(digits[k]);
    }
    return b.toString();
  }

  bool _isGroupSpace(String s, int i) =>
      s[i] == ' ' && i > 0 && i + 1 < s.length && _d.hasMatch(s[i - 1]) && _d.hasMatch(s[i + 1]);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    final t = newV.text;
    if (t.isEmpty || !_d.hasMatch(t)) return newV;
    var meaningfulBefore = 0;
    final selEnd = newV.selection.end.clamp(0, t.length);
    for (var i = 0; i < selEnd; i++) {
      if (!_isGroupSpace(t, i)) meaningfulBefore++;
    }
    final out = StringBuffer();
    var i = 0;
    while (i < t.length) {
      if (_d.hasMatch(t[i])) {
        final run = StringBuffer();
        var j = i;
        while (j < t.length) {
          if (_d.hasMatch(t[j])) {
            run.write(t[j]);
            j++;
          } else if (t[j] == ' ' && j + 1 < t.length && _d.hasMatch(t[j + 1])) {
            j++;
          } else {
            break;
          }
        }
        out.write(_group(run.toString()));
        i = j;
      } else {
        out.write(t[i]);
        i++;
      }
    }
    final res = out.toString();
    var pos = 0, seen = 0;
    while (pos < res.length && seen < meaningfulBefore) {
      if (!_isGroupSpace(res, pos)) seen++;
      pos++;
    }
    return TextEditingValue(text: res, selection: TextSelection.collapsed(offset: pos));
  }
}

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  Widget _plus(double s, Color c) => SizedBox(
        width: s,
        height: s,
        child: Stack(children: [
          Positioned(left: (s - 2) / 2, top: 0, child: Container(width: 2, height: s, color: c)),
          Positioned(top: (s - 2) / 2, left: 0, child: Container(width: s, height: 2, color: c)),
        ]),
      );

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

  // Kichik teg-chip (tasdiqsiz / nizoli / tahrirlangan)
  Widget _chip(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Tx(text, size: 10, w: FontWeight.w600, color: fg, ls: .3),
      );

  // ---------------- Tasdiqlash kartochkasi (sticky, ekran tepasida) ----------------
  Widget _confirmCard(Map<String, dynamic> m, Pal p) {
    final isEdit = m['isEdit'] == true;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.card2,
        border: Border.all(color: _amber.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: _amber, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Tx(m['cap'] as String, size: 10.5, w: FontWeight.w700, color: _amber, ls: 1.1),
        ]),
        const SizedBox(height: 10),
        if (isEdit) ...[
          Tx(m['title'] as String, size: 14, w: FontWeight.w600, color: p.ink),
          const SizedBox(height: 8),
          for (final d in (m['diffs'] as List).cast<Map<String, dynamic>>())
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                SizedBox(width: 58, child: Tx(d['label'] as String, size: 12, color: p.t3)),
                Expanded(
                  child: Row(children: [
                    Flexible(child: Tx(d['old'] as String, size: 12.5, color: p.t4, maxLines: 1, ellipsis: true)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: ChevRight(color: p.t4)),
                    Flexible(child: Tx(d['new'] as String, size: 12.5, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true)),
                  ]),
                ),
              ]),
            ),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Tx(m['title'] as String, size: 14.5, w: FontWeight.w600, color: p.ink)),
              const SizedBox(width: 10),
              Tx(m['amount'] as String, size: 17, w: FontWeight.w700, color: p.ink, tab: true),
            ],
          ),
          const SizedBox(height: 3),
          Tx(m['sub'] as String, size: 11.5, color: p.t3),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GhostBtn(label: store.L()['btnReject'] as String, onTap: m['reject'] as VoidCallback, h: 40, fs: 13)),
          const SizedBox(width: 10),
          Expanded(child: InkBtn(label: store.L()['btnConfirm'] as String, onTap: m['confirm'] as VoidCallback, h: 40, fs: 13)),
        ]),
      ]),
    );
  }

  // ---------------- Eski yozuv (join review) kartochkasi ----------------
  Widget _reviewCard(Map<String, dynamic> m, Pal p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.bg,
        border: Border.all(color: p.bd2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Tx(m['title'] as String, size: 14.5, w: FontWeight.w600, color: p.ink)),
            const SizedBox(width: 10),
            Tx(m['amount'] as String, size: 16, w: FontWeight.w700, color: p.ink, tab: true),
          ],
        ),
        const SizedBox(height: 3),
        Tx(m['sub'] as String, size: 11.5, color: p.t3),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GhostBtn(label: store.L()['btnRejectShort'] as String, onTap: m['reject'] as VoidCallback, h: 38, fs: 12.5)),
          const SizedBox(width: 10),
          Expanded(child: InkBtn(label: store.L()['btnConfirm'] as String, onTap: m['confirm'] as VoidCallback, h: 38, fs: 12.5)),
        ]),
      ]),
    );
  }

  // ---------------- Lenta: qarz kartochkasi ----------------
  Widget _feedCard(Map<String, dynamic> m, Pal p) {
    final dead = m['isDead'] == true;
    final progW = (m['progW'] as int).toDouble();
    final tags = <Widget>[];
    if (m['oneSided'] == true) tags.add(_chip(store.L()['tagUnconfirmed'] as String, _amber, _amber.withValues(alpha: .12)));
    if (m['reviewing'] == true) tags.add(_chip(store.L()['tagReviewing'] as String, p.t2, p.field));
    if (m['disputed'] == true) tags.add(_chip(store.L()['tagDisputed'] as String, p.red, p.red.withValues(alpha: .12)));
    if (m['edited'] == true) tags.add(_chip(store.L()['tagEdited'] as String, p.t3, p.field));

    return Opacity(
      opacity: dead ? 0.5 : 1,
      child: Tap(
        onTap: m['open'] as VoidCallback,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border.all(color: p.hair2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: m['stColor'] as Color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Flexible(child: Tx(m['title'] as String, size: 14.5, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true)),
                    const SizedBox(width: 8),
                    Tx(m['stLabel'] as String, size: 10.5, w: FontWeight.w600, color: m['stColor'] as Color, ls: .2),
                  ]),
                ),
                const SizedBox(width: 8),
                Tx(m['amount'] as String, size: 16, w: FontWeight.w700, color: m['amountColor'] as Color, tab: true,
                    align: TextAlign.right),
              ],
            ),
            const SizedBox(height: 4),
            Row(children: [
              Tx(m['date'] as String, size: 11.5, color: p.t4),
              if ((m['due'] as String).isNotEmpty) ...[
                Tx('  ·  ', size: 11.5, color: p.t5),
                Tx(m['due'] as String, size: 11.5, color: p.t4, tab: true),
              ],
            ]),
            if ((m['note'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Tx(m['note'] as String, size: 12.5, color: p.t2),
            ],
            // Progress (faol/yopilgan qarz)
            if ((m['progText'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(children: [
                  Container(height: 5, color: p.field),
                  FractionallySizedBox(
                    widthFactor: (progW / 100).clamp(0.0, 1.0),
                    child: Container(height: 5, color: m['isClosed'] == true ? p.green : p.ink),
                  ),
                ]),
              ),
              const SizedBox(height: 5),
              Tx(m['progText'] as String, size: 11, color: p.t3, tab: true),
            ],
            if ((m['forgivenText'] as String).isNotEmpty) ...[
              const SizedBox(height: 3),
              Tx(m['forgivenText'] as String, size: 11, color: p.t3, tab: true),
            ],
            if ((m['overdue'] as String).isNotEmpty) ...[
              const SizedBox(height: 6),
              Tx(m['overdue'] as String, size: 11, w: FontWeight.w600, color: p.red, tab: true),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 9),
              Wrap(spacing: 6, runSpacing: 6, children: tags),
            ],
            if (m['canCancel'] == true) ...[
              const SizedBox(height: 10),
              Tap(
                onTap: m['cancel'] as VoidCallback,
                child: Tx(store.L()['btnCancelFull'] as String, size: 12.5, w: FontWeight.w600, color: p.red),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ---------------- Bo'sh holat ----------------
  // Skroll-xavfsiz: input panel + klaviatura maydonni siqqanda ham overflow bermaydi.
  Widget _empty(Pal p) => LayoutBuilder(
        builder: (ctx, c) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: _emptyBody(p),
          ),
        ),
      );

  Widget _emptyBody(Pal p) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd2, width: 2)),
            child: Center(child: Tx('₮', size: 34, w: FontWeight.w700, color: p.t4)),
          ),
          const SizedBox(height: 16),
          Tx(store.L()['noDebtTitle'] as String, size: 14, w: FontWeight.w600, color: p.t1, align: TextAlign.center),
          const SizedBox(height: 6),
          Tx(store.L()['noDebtSub'] as String,
              size: 12, color: p.t4, align: TextAlign.center, lh: 17),
        ]),
      );

  // ---------------- Panel maydonlari ----------------
  Widget _panelField(Pal p, String label, String value, ValueChanged<String> onCh,
      {String? hint, bool number = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Tx(label, size: 11, w: FontWeight.w600, color: p.t3, ls: .3),
      const SizedBox(height: 5),
      Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(10)),
        child: StoreField(
          value: value,
          onChanged: onCh,
          hint: hint,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: false) : null,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: number ? FontWeight.w700 : FontWeight.w500, color: p.ink),
        ),
      ),
    ]);
  }

  // Oy qisqartmalari (muddat sanasini ixcham ko'rsatish uchun)
  static const _mon = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];
  String _dueLabel(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return store.L()['lblDue'] as String;
    return '${d.day}-${_mon[d.month - 1]}';
  }

  // ---------------- Input panel (lend/borrow/close) ----------------
  // Dizayn: 1-qator — summa+valyuta (bitta maydon) + muddat (kalendar); sana YO'Q.
  //         2-qator — Telegram/Instagram uslubidagi izoh input + dumaloq send.
  Widget _inputPanel(BuildContext context, Map<String, dynamic> v, Pal p) {
    final L0 = v['L'] as Map<String, dynamic>;
    final isClose = v['chIsClose'] == true;
    final curs = (v['chCurs'] as List).cast<String>();
    final title = v['chIsLend'] == true
        ? L0['lendDebt'] as String
        : v['chIsBorrow'] == true
            ? L0['borrowDebt'] as String
            : L0['closeDebt'] as String;

    final children = <Widget>[
      Row(children: [
        Tx(title, size: 12.5, w: FontWeight.w600, color: p.t3, ls: .3),
        const Spacer(),
        Tap(
          onTap: v['chClosePanel'] as VoidCallback,
          child: Icon(Icons.close_rounded, size: 19, color: p.t3),
        ),
      ]),
      const SizedBox(height: 10),
    ];

    if (isClose) {
      // Qaysi qarzni yopish — chip tanlash
      final chips = (v['chCloseChips'] as List).cast<Map<String, dynamic>>();
      if (chips.isEmpty) {
        children.add(Tx(L0['noClosable'] as String, size: 12.5, color: p.t3));
      } else {
        children.add(SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in chips) ...[
                Tap(
                  onTap: c['pick'] as VoidCallback,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: c['sel'] == true ? p.ink : p.field,
                      borderRadius: BorderRadius.circular(10),
                      border: c['locked'] == true ? Border.all(color: p.bd2) : null,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 5, height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c['sel'] == true ? p.bg : (c['dir'] == 'in' ? p.green : p.red),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Tx(c['label'] as String, size: 12.5, w: FontWeight.w600,
                          color: c['sel'] == true ? p.bg : p.ink, tab: true),
                      if (c['locked'] == true) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_outline, size: 12, color: c['sel'] == true ? p.bg : p.t4),
                      ],
                    ]),
                  ),
                ),
              ],
            ],
          ),
        ));
        children.add(const SizedBox(height: 12));
        // Kechirish varianti — faqat u menga qarzdor bo'lsa (toMe)
        if (v['chCloseIsMine'] != true) {
          children.add(Row(children: [
            Expanded(child: _segBtn(p, L0['gotMoney'] as String, v['chReason'] == 'returned', () => v['chSetReason']('returned'))),
            const SizedBox(width: 8),
            Expanded(child: _segBtn(p, L0['forgave'] as String, v['chReason'] == 'forgiven', () => v['chSetReason']('forgiven'))),
          ]));
          children.add(const SizedBox(height: 12));
        }
      }
    }

    // 1-QATOR: summa+valyuta birlashtirilgan maydon (+ lend/borrow'da muddat kalendar).
    children.add(Row(children: [
      Expanded(child: _amtCurField(v, p, isClose: isClose, curs: curs)),
      if (!isClose) ...[
        const SizedBox(width: 10),
        _dueField(context, v, p),
      ],
    ]));

    // 2-QATOR: Telegram/Instagram uslubidagi izoh input + dumaloq send.
    children.add(const SizedBox(height: 12));
    children.add(_telegramRow(v, p));

    // Klaviatura ochilganda panel overflow bermasligi uchun — skroll + balandlik cheklovi.
    final maxH = MediaQuery.of(context).size.height * 0.62;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.hair)),
        boxShadow: const [BoxShadow(offset: Offset(0, -3), blurRadius: 14, color: Color(0x14000000))],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ),
    );
  }

  // Summa (jonli "x xxx xxx") + valyuta dropdown — FONSIZ (bg yo'q), pastki chiziqli.
  Widget _amtCurField(Map<String, dynamic> v, Pal p, {required bool isClose, required List<String> curs}) {
    return Container(
      height: 46,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2, width: 1.5))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: StoreField(
            value: v['chA'] as String,
            onChanged: (t) => v['chSetA'](t),
            hint: '0',
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [_GroupFmt()],
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: p.ink),
          ),
        ),
        // Valyuta dropdown — yopishda qarz valyutasi qat'iy (o'zgarmaydi)
        if (isClose)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Tx(v['chCur'] as String, size: 13.5, w: FontWeight.w600, color: p.t3),
          )
        else
          PopupMenuButton<String>(
            onSelected: (c) => v['chSetCur'](c),
            color: p.bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              for (final c in curs)
                PopupMenuItem<String>(
                  value: c,
                  height: 42,
                  child: Tx(c, size: 14, w: v['chCur'] == c ? FontWeight.w700 : FontWeight.w500, color: p.ink),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Tx(v['chCur'] as String, size: 14, w: FontWeight.w600, color: p.t2),
                Icon(Icons.arrow_drop_down_rounded, size: 20, color: p.t3),
              ]),
            ),
          ),
      ]),
    );
  }

  // Muddat — kalendar orqali tanlanadi (matn kiritish YO'Q).
  Widget _dueField(BuildContext context, Map<String, dynamic> v, Pal p) {
    final L0 = v['L'] as Map<String, dynamic>;
    final iso = v['chDue'] as String;
    final set = v['chSetDue'] as ValueChanged<String>;
    return Tap(
      onTap: () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final init = DateTime.tryParse(iso) ?? today;
        final picked = await showDatePicker(
          context: context,
          initialDate: init.isBefore(today) ? today : init,
          firstDate: today,
          lastDate: DateTime(now.year + 5),
          helpText: L0['dueHelp'] as String,
        );
        if (picked != null) {
          set('${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: iso.isEmpty ? p.bd2 : p.ink, width: iso.isEmpty ? 1 : 1.4),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_outlined, size: 16, color: iso.isEmpty ? p.t4 : p.ink),
          const SizedBox(width: 6),
          Tx(iso.isEmpty ? L0['lblDue'] as String : _dueLabel(iso), size: 13,
              w: iso.isEmpty ? FontWeight.w500 : FontWeight.w600, color: iso.isEmpty ? p.t3 : p.ink, tab: true),
          if (iso.isNotEmpty) ...[
            const SizedBox(width: 5),
            Tap(
              onTap: () => set(''),
              child: Icon(Icons.close_rounded, size: 14, color: p.t4),
            ),
          ],
        ]),
      ),
    );
  }

  // Telegram/Instagram uslubidagi izoh input + dumaloq send tugma.
  // Bir qatorli matn markazda turadi (balanslangan padding), ko'p qatorda yuqoriga o'sadi.
  Widget _telegramRow(Map<String, dynamic> v, Pal p) {
    final L0 = v['L'] as Map<String, dynamic>;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(23)),
          child: StoreField(
            value: v['chNote'] as String,
            onChanged: (t) => v['chSetNote'](t),
            hint: L0['noteHintDots'] as String,
            maxLines: 4,
            minLines: 1,
            style: GoogleFonts.inter(fontSize: 15, color: p.ink, height: 1.25),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Tap(
        onTap: v['chSubmit'] as VoidCallback,
        child: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(Icons.send_rounded, size: 20, color: p.bg),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _segBtn(Pal p, String label, bool on, VoidCallback onTap) => Tap(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? p.ink : p.field,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Tx(label, size: 12.5, w: FontWeight.w600, color: on ? p.bg : p.t2),
        ),
      );

  // ---------------- 3 aqlli tugma ----------------
  Widget _smartButtons(Map<String, dynamic> v, Pal p) {
    final btns = (v['ledBtns'] as List).cast<Map<String, dynamic>>();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.hair))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          for (var i = 0; i < btns.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Tap(
                onTap: () => v['ledBtnTap'](btns[i]['key'], btns[i]['on'] == true, btns[i]['off']),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: btns[i]['on'] == true ? p.ink : p.field,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Tx(
                    btns[i]['label'] as String,
                    size: 13,
                    w: FontWeight.w600,
                    color: btns[i]['on'] == true ? p.bg : p.t4,
                    align: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ---------------- Yozuv tarixi / tahrir dialogi ----------------
  Widget _historyDialog(Map<String, dynamic> v, Pal p) {
    final L0 = v['L'] as Map<String, dynamic>;
    final d = v['histData'] as Map<String, dynamic>?;
    if (d == null) return const SizedBox.shrink();
    final editing = v['histEditing'] == true;
    final versions = (d['versions'] as List).cast<Map<String, dynamic>>();
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => v['histClose'](),
        child: Container(
          color: const Color(0x66000000),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 560),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(18)),
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Tx(d['title'] as String, size: 16, w: FontWeight.w700, color: p.ink)),
                      Tap(
                        onTap: () => v['histClose'](),
                        child: Icon(Icons.close_rounded, size: 20, color: p.t3),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Tx(d['stLabel'] as String, size: 11.5, w: FontWeight.w600, color: p.t2),
                    const SizedBox(height: 14),
                    if (!editing) ...[
                      _kv(p, L0['lblAmount'] as String, d['amount'] as String),
                      _kv(p, L0['date'] as String, d['date'] as String),
                      if ((d['due'] as String).isNotEmpty) _kv(p, L0['lblDue'] as String, d['due'] as String),
                      if ((d['note'] as String).isNotEmpty) _kv(p, L0['lblNote'] as String, d['note'] as String),
                      if (versions.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Tx(L0['capHistory'] as String, size: 10.5, w: FontWeight.w700, color: p.t3, ls: 1),
                        const SizedBox(height: 8),
                        for (final ver in versions)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              Expanded(
                                child: Tx(
                                  [ver['amount'], if ((ver['due'] as String).isNotEmpty) ver['due'], if ((ver['note'] as String).isNotEmpty) ver['note']].join(' · '),
                                  size: 12, color: p.t2, tab: true, maxLines: 1, ellipsis: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tx(ver['time'] as String, size: 10.5, color: p.t4, tab: true),
                            ]),
                          ),
                      ],
                      if (d['canEdit'] == true) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: GhostBtn(label: L0['btnEdit'] as String, onTap: () => v['histEditStart'](), h: 44, fs: 13.5),
                        ),
                      ],
                    ] else ...[
                      _panelField(p, L0['lblAmount'] as String, v['eA'] as String, (t) => v['eSetA'](t), hint: '0', number: true),
                      const SizedBox(height: 12),
                      _panelField(p, L0['dueOptional'] as String, v['eDue'] as String, (t) => v['eSetDue'](t), hint: L0['dueDateHint'] as String),
                      const SizedBox(height: 12),
                      _panelField(p, L0['lblNote'] as String, v['eNote'] as String, (t) => v['eSetNote'](t), hint: L0['noteWhy'] as String),
                      const SizedBox(height: 8),
                      Tx(L0['editActiveNote'] as String,
                          size: 11.5, color: p.t3, lh: 16),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: InkBtn(label: L0['sendChange'] as String, onTap: () => v['histEditSave'](), h: 48),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(Pal p, String k, String val) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 70, child: Tx(k, size: 12.5, color: p.t3)),
          Expanded(child: Tx(val, size: 13.5, w: FontWeight.w600, color: p.ink, tab: true)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final L0 = v['L'] as Map<String, dynamic>;

    // Yuklanish/xato holati — HECH QACHON o'lik ekran bo'lmasin: orqaga tugma doim bo'lsin.
    if (v['hasLedger'] != true) {
      return Container(
        color: p.bg,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Align(alignment: Alignment.centerLeft, child: BackBtn(onTap: () => v['back']())),
            ),
            const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          ]),
        ),
      );
    }

    final balLines = (v['balLines'] as List).cast<Map<String, dynamic>>();
    final cards = (v['ledCards'] as List).cast<Map<String, dynamic>>();
    final review = (v['ledReview'] as List).cast<Map<String, dynamic>>();
    final feed = (v['ledFeed'] as List).cast<Map<String, dynamic>>();
    final panelOpen = v['chAct'] != null;

    // -------- Header --------
    final header = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
      child: Row(children: [
        BackBtn(onTap: () => v['back']()),
        const SizedBox(width: 12),
        TrustAvatar(initials: v['cInitials'] as String, size: 40, onTrust: v['cInTrust'] == true),
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
                    child: Tx(L0['btnOk'] as String, size: 11.5, w: FontWeight.w600, color: p.bg),
                  ),
                ),
              ]),
            if (v['notRenaming'] == true)
              Tap(
                onTap: () => v['menuTap'](),
                child: Tx(v['cName'] as String, size: 15.5, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
              ),
            const SizedBox(height: 2),
            for (final b in balLines)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Tx(b['text'] as String, size: 11.5, w: FontWeight.w500, color: b['color'] as Color, tab: true, maxLines: 1, ellipsis: true),
              ),
          ]),
        ),
        const SizedBox(width: 10),
        Tap(
          onTap: () => v['menuTap'](),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd2)),
            child: Center(child: _plus(12, p.ink)),
          ),
        ),
      ]),
    );

    // -------- Off-Trust / kutilayotgan bog'lanish banneri --------
    // offTrust: hamkor Trust'da YO'Q (ro'yxatdan o'tmagan). pendingLink: Trust'da BOR,
    // lekin bog'lanish hali qabul qilinmagan — bularni ARALASHTIRMA (badge bilan ziddiyat).
    final _bannerText = v['pendingLink'] == true
        ? store.Lf('pendingLinkBanner', {'name': v['pendingLinkName'] as String? ?? ''})
        : (v['offTrust'] == true ? L0['offTrustBanner'] as String : null);
    final offTrustBanner = _bannerText != null
        ? Container(
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
            decoration: BoxDecoration(color: _amber.withValues(alpha: .1), border: Border(bottom: BorderSide(color: p.hair2))),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 15, color: _amber),
              const SizedBox(width: 8),
              Expanded(child: Tx(_bannerText, size: 11.5, color: p.t1, lh: 16)),
            ]),
          )
        : const SizedBox.shrink();

    // -------- Body list --------
    final bodyChildren = <Widget>[];
    // Tasdiqlash kartochkalari (tepada)
    for (final c in cards) {
      bodyChildren.add(_confirmCard(c, p));
    }
    // Eski yozuvlar (join review)
    if (review.isNotEmpty) {
      bodyChildren.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(children: [
          Expanded(child: Tx(store.Lf('oldRecordsCap', {'n': '${v['ledReviewCount']}'}), size: 10.5, w: FontWeight.w700, color: p.t3, ls: 1)),
          if (review.length > 1)
            Tap(
              onTap: () => v['revAllAsk'](),
              child: Tx(L0['confirmAll'] as String, size: 12, w: FontWeight.w600, color: p.ink),
            ),
        ]),
      ));
      for (final r in review) {
        bodyChildren.add(_reviewCard(r, p));
      }
    }
    // Lenta
    if (feed.isNotEmpty && cards.isNotEmpty) {
      bodyChildren.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Tx(L0['capRecords'] as String, size: 10.5, w: FontWeight.w700, color: p.t3, ls: 1),
      ));
    }
    for (final f in feed) {
      bodyChildren.add(_feedCard(f, p));
    }
    bodyChildren.add(const SizedBox(height: 16));

    final body = v['ledgerLoading'] == true
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
        : (feed.isEmpty && cards.isEmpty && review.isEmpty)
            ? _empty(p)
            : ListView(children: bodyChildren);

    return Stack(children: [
      Column(children: [
        header,
        offTrustBanner,
        Expanded(child: body),
        // Pastki qism: input panel (ochiq bo'lsa) yoki 3 tugma — pastga YOPISHADI (Telegram kabi).
        // Panel ichida SingleChildScrollView + maxHeight bor: klaviatura siqsa ichki skroll bo'ladi,
        // body (Expanded) esa 0 gacha kichrayadi — shu bois tashqi overflow bo'lmaydi.
        if (panelOpen) _inputPanel(context, v, p) else _smartButtons(v, p),
      ]),

      // Menyu (rename/archive/disconnect/profile)
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
            // IntrinsicWidth — Positioned+minWidth cheksiz kenglik beradi; stretch Column
            // uchun chegaralangan kenglik kerak (aks holda RenderBox was not laid out).
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: IntrinsicWidth(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  _menuItem(p, L0['menuRename'] as String, () => v['menuRename']()),
                  if (v['incoming'] == true)
                    _menuItem(p, L0['menuDisconnect'] as String, () => v['menuDisconnect'](), top: true)
                  else
                    _menuItem(p, L0['menuArchive'] as String, () => v['menuArchive'](), top: true),
                  _menuItem(p, L0['menuProfile'] as String, () => v['menuProfile'](), top: true),
                ]),
              ),
            ),
          ),
        ),
      ],

      // Hamkor profili popup
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
                      TrustAvatar(initials: v['cInitials'] as String, size: 60, onTrust: v['cInTrust'] == true),
                      const SizedBox(height: 12),
                      Tx(v['cName'] as String, size: 17, w: FontWeight.w700, color: p.ink),
                      const SizedBox(height: 3),
                      Tx(v['pPhone'] as String, size: 13, color: p.t2, tab: true),
                      const SizedBox(height: 5),
                      Tx(v['pStatus'] as String, size: 11.5, color: p.t3),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: GhostBtn(label: L0['btnClose'] as String, onTap: () => v['pProfClose'](), h: 44, fs: 13.5),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),

      // "Barchasini tasdiqlash" tasdiq oynasi
      if (v['revAllOpen'] == true)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => v['revAllNo'](),
            child: Container(
              color: const Color(0x66000000),
              padding: const EdgeInsets.all(28),
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(18)),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Tx(L0['confirmAllTitle'] as String, size: 16, w: FontWeight.w700, color: p.ink),
                      const SizedBox(height: 8),
                      Tx(v['revAllText'] as String, size: 13, color: p.t2, lh: 18),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(child: GhostBtn(label: L0['btnCancelShort'] as String, onTap: () => v['revAllNo'](), h: 44, fs: 13.5)),
                        const SizedBox(width: 10),
                        Expanded(child: InkBtn(label: L0['btnConfirm'] as String, onTap: () => v['revAllOk'](), h: 44, fs: 13.5)),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),

      // Yozuv tarixi / tahrir dialogi
      if (v['histOpen'] == true) _historyDialog(v, p),
    ]);
  }
}

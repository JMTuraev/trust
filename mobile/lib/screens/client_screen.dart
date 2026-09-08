// Hamkor sahifasi — QARZ DAFTARI (ledger). Erkin matnli chat YO'Q (spec 4.1).
// Dizayn: prototype/redesign/DESIGN_SPEC.md §5.8 (Hamkor chati) + §5.9 (Yangi yozuv sheet).
// Tuzilma: header (BackBtn · RingAvatar · ism · ⋯) → banner (Trust'da emas / kutilmoqda)
// → lenta (teskari: balans kartasi · eski yozuvlar · pufaklar · tasdiq kartalari pastda)
// → BottomPanel (Qarz berish · Qarzni yopish · eslatma) → sheet'lar (yozuv formasi,
// menyu, profil, tarix/tahrir, barchasini tasdiqlash).
// Barcha store.vals() kalitlari va callback'lar avvalgi bilan bir xil.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter, TextEditingValue, TextSelection;
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

/// Dizayn matni uchun L() kaliti yo'q bo'lsa — uz-fallback (xarajat.dart _t naqshi).
String _t(String key, String fb) => (store.L()[key] as String?) ?? fb;

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

/// Chat-style alignment wrapper for ledger feed cards (public for widget tests).
///
/// Side comes from the store feed map ('right' = value outflow from the viewer,
/// 'left' = inflow; see `sideFor` in debt_ledger.dart). Unknown/empty side
/// falls back to a full-width glass card so the feed never breaks.
/// Visuals (DESIGN_SPEC §5.8):
/// - right ("men berdim"): mint 10% fon + mint 25% chegara, pastki-o'ng r8;
/// - left ("u berdi"): coral 8% fon + coral 20% chegara, pastki-chap r8;
/// - [tone] 'glass' (qaytarish / hisob-kitob): glass2 fon + glassBd chegara.
class LedgerFeedBubble extends StatelessWidget {
  final String side; // 'right' | 'left' | '' (unknown -> full-width)
  final Pal pal;
  final VoidCallback? onTap;
  final Widget child;

  /// 'mint' | 'coral' | 'glass'. null → tomondan kelib chiqadi (right→mint, left→coral).
  final String? tone;

  /// Bubble width as a fraction of the feed width (spec: 270/358 ≈ 0.76–0.80;
  /// interactive cards may pass up to ~0.92 for usability).
  final double widthFactor;

  const LedgerFeedBubble({
    super.key,
    required this.side,
    required this.pal,
    required this.child,
    this.onTap,
    this.tone,
    this.widthFactor = 0.80,
  });

  @override
  Widget build(BuildContext context) {
    final isRight = side == 'right';
    final isLeft = side == 'left';
    final aligned = isRight || isLeft;
    final tn = tone ?? (isRight ? 'mint' : isLeft ? 'coral' : 'glass');
    final Color fill, bd;
    switch (tn) {
      case 'mint':
        fill = pal.mint.withValues(alpha: .10);
        bd = pal.mint.withValues(alpha: .25);
        break;
      case 'coral':
        fill = pal.coral.withValues(alpha: .08);
        bd = pal.coral.withValues(alpha: .20);
        break;
      default:
        fill = pal.glass2;
        bd = pal.glassBd;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: isRight
            ? Alignment.centerRight
            : isLeft
                ? Alignment.centerLeft
                : Alignment.center,
        child: FractionallySizedBox(
          widthFactor: aligned ? widthFactor : 1.0,
          child: Tap(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: fill,
                border: Border.all(color: bd),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(Tb.rRow),
                  topRight: const Radius.circular(Tb.rRow),
                  bottomLeft: Radius.circular(isLeft ? 8 : Tb.rRow),
                  bottomRight: Radius.circular(isRight ? 8 : Tb.rRow),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  // Oy qisqartmalari (muddat sanasini ixcham ko'rsatish uchun)
  static const _mon = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];
  String _dueLabel(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return store.L()['lblDue'] as String;
    return '${d.day}-${_mon[d.month - 1]}';
  }

  // ---------------- Balans kartasi (lenta markazida) ----------------
  // balLines: "U sizga: 1 500 000 so'm · shundan … · muddati o'tdi" — birinchi ':'
  // dan keyingi qismning boshi summa (30/600), qolgan " · …" qo'shimchalar 12 t3.
  Widget _balanceCard(Map<String, dynamic> v, Pal p, List<Map<String, dynamic>> balLines) {
    final L0 = v['L'] as Map<String, dynamic>;
    final rows = <Widget>[];
    if (balLines.isEmpty) {
      rows.add(Tx(L0['subZero'] as String, size: 13, color: p.t2, align: TextAlign.center));
      rows.add(const SizedBox(height: 2));
      rows.add(Tx(L0['zero'] as String, size: 30, w: FontWeight.w600, color: p.t1, tab: true, align: TextAlign.center));
    }
    for (var i = 0; i < balLines.length; i++) {
      final b = balLines[i];
      final text = b['text'] as String;
      final color = b['color'] as Color;
      final m = RegExp(r'[:：]\s*').firstMatch(text);
      if (i > 0) rows.add(const SizedBox(height: 8));
      if (m == null) {
        rows.add(Tx(text, size: i == 0 ? 20 : 14, w: FontWeight.w600, color: color, tab: true, align: TextAlign.center));
        continue;
      }
      final label = text.substring(0, m.start);
      final rest = text.substring(m.end);
      final parts = rest.split(' · ');
      final amount = parts.first;
      final sfx = parts.length > 1 ? parts.sublist(1).join(' · ') : '';
      rows.add(Tx(label, size: 13, color: p.t2, align: TextAlign.center));
      rows.add(const SizedBox(height: 2));
      rows.add(FittedBox(
        fit: BoxFit.scaleDown,
        child: Tx(amount, size: i == 0 ? 30 : 20, w: FontWeight.w600, color: color, tab: true, ls: -0.5),
      ));
      if (sfx.isNotEmpty) {
        rows.add(const SizedBox(height: 2));
        rows.add(Tx(sfx, size: 12, color: p.t3, align: TextAlign.center, maxLines: 3));
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Center(
        child: GlassCard(
          r: Tb.rRow,
          pad: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: rows),
        ),
      ),
    );
  }

  // ---------------- Tasdiqlash kartasi (lentaning eng pastida, amber) ----------------
  Widget _confirmCard(Map<String, dynamic> m, Pal p) {
    final isEdit = m['isEdit'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.9,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: p.amber.withValues(alpha: .10),
              border: Border.all(color: p.amber.withValues(alpha: .30)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(Tb.rRow),
                topRight: Radius.circular(Tb.rRow),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(Tb.rRow),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: p.amber, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Expanded(child: Tx(m['cap'] as String, size: 12, w: FontWeight.w700, color: p.amber, ls: 1, font: TbFont.body)),
              ]),
              const SizedBox(height: 10),
              if (isEdit) ...[
                Tx(m['title'] as String, size: 15, w: FontWeight.w600, color: p.ink),
                const SizedBox(height: 8),
                for (final d in (m['diffs'] as List).cast<Map<String, dynamic>>())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      SizedBox(width: 62, child: Tx(d['label'] as String, size: 13, color: p.t3)),
                      Expanded(
                        // Eski→yangi qiymatlar (summa/muddat/izoh) — moliyaviy diff
                        // "..." bilan kesilmaydi, sig'masa qatorga o'raladi.
                        child: Row(children: [
                          Flexible(child: Tx(d['old'] as String, size: 13, color: p.t4, tab: true)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.arrow_forward_rounded, size: 14, color: p.t4),
                          ),
                          Flexible(child: Tx(d['new'] as String, size: 13, w: FontWeight.w600, color: p.ink, tab: true)),
                        ]),
                      ),
                    ]),
                  ),
              ] else ...[
                Tx(m['title'] as String, size: 15, w: FontWeight.w500, color: p.ink),
                const SizedBox(height: 4),
                Tx(m['amount'] as String, size: 24, w: FontWeight.w600, color: p.ink, tab: true),
                const SizedBox(height: 4),
                Tx(m['sub'] as String, size: 13, color: p.t2),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: GlassBtn(label: store.L()['btnReject'] as String, onTap: m['reject'] as VoidCallback, h: 44, fs: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: GradientBtn(
                    label: store.L()['btnConfirm'] as String,
                    onTap: m['confirm'] as VoidCallback,
                    icon: Icons.check_rounded,
                    h: 44,
                    fs: 14,
                    glow: false,
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------------- Eski yozuv (join review) kartochkasi ----------------
  Widget _reviewCard(Map<String, dynamic> m, Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassCard(
        r: Tb.rRow,
        pad: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Tx(m['title'] as String, size: 15, w: FontWeight.w600, color: p.ink)),
              const SizedBox(width: 10),
              Tx(m['amount'] as String, size: 18, w: FontWeight.w600, color: p.ink, tab: true),
            ],
          ),
          const SizedBox(height: 4),
          Tx(m['sub'] as String, size: 13, color: p.t2),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: GlassBtn(label: store.L()['btnRejectShort'] as String, onTap: m['reject'] as VoidCallback, h: 40, fs: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: GradientBtn(
                label: store.L()['btnConfirm'] as String,
                onTap: m['confirm'] as VoidCallback,
                icon: Icons.check_rounded,
                h: 40,
                fs: 13,
                glow: false,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // Holat pill'i: muddati o'tdi coral · faol mint · yopildi muted · kutilmoqda amber ·
  // rad/bekor/nizoli coral · tasdiqlangan amal muted.
  Widget _statusPill(Map<String, dynamic> m, Pal p) {
    final L0 = store.L();
    if ((m['overdue'] as String).isNotEmpty) return PillBadge.coral(m['overdue'] as String);
    if (m['isActive'] == true) return PillBadge.mint(m['stLabel'] as String);
    if (m['isClosed'] == true) return PillBadge.muted(m['stLabel'] as String);
    if (m['isDead'] == true || m['disputed'] == true) return PillBadge.coral(m['stLabel'] as String);
    if (m['stLabel'] == L0['stPending']) return PillBadge.amber(m['stLabel'] as String);
    return PillBadge.muted(m['stLabel'] as String);
  }

  // ---------------- Lenta: qarz kartochkasi (chat-style bubble) ----------------
  Widget _feedCard(Map<String, dynamic> m, Pal p) {
    final dead = m['isDead'] == true;
    final closed = m['isClosed'] == true;
    final side = m['side'] as String? ?? '';
    final amount = m['amount'] as String;
    // Qarz yozuvi summasi belgi (+/−) bilan keladi; qaytarish/hisob-kitob — belgisiz.
    final isDebt = amount.startsWith('+') || amount.startsWith('−');
    final tone = !isDebt ? 'glass' : (side == 'right' ? 'mint' : side == 'left' ? 'coral' : 'glass');
    final Color iconBg, iconFg;
    final IconData icon;
    if (!isDebt) {
      iconBg = p.ink.withValues(alpha: .10);
      iconFg = p.ink;
      icon = Icons.refresh_rounded;
    } else if (side == 'left') {
      iconBg = p.coral.withValues(alpha: .15);
      iconFg = p.coral;
      icon = Icons.south_west_rounded;
    } else {
      iconBg = p.mint.withValues(alpha: .15);
      iconFg = p.mint;
      icon = Icons.north_east_rounded;
    }
    final amountColor = (dead || closed) ? p.t3 : (m['amountColor'] as Color);
    final progW = (m['progW'] as int).toDouble();
    final showProg = (m['progText'] as String).isNotEmpty;

    final tags = <Widget>[];
    if (m['oneSided'] == true) tags.add(PillBadge.amber(store.L()['tagUnconfirmed'] as String, h: 20));
    if (m['reviewing'] == true) tags.add(PillBadge.muted(store.L()['tagReviewing'] as String, h: 20));
    if (m['disputed'] == true) tags.add(PillBadge.coral(store.L()['tagDisputed'] as String, h: 20));
    if (m['edited'] == true) tags.add(PillBadge.muted(store.L()['tagEdited'] as String, h: 20));

    return Opacity(
      opacity: dead ? 0.55 : 1,
      child: LedgerFeedBubble(
        side: side,
        pal: p,
        tone: tone,
        onTap: m['open'] as VoidCallback,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 14, color: iconFg),
            ),
            const SizedBox(width: 8),
            // Yozuv sarlavhasi — "..." bilan kesilmaydi, 2 qatorga o'raladi
            Expanded(child: Tx(m['title'] as String, size: 13, color: p.t2, maxLines: 2)),
          ]),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Tx(amount, size: 24, w: FontWeight.w600, color: amountColor, tab: true),
          ),
          if ((m['note'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Tx(m['note'] as String, size: 14, color: p.t1),
          ],
          // Progress (faol/yopilgan qarz)
          if (showProg) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Tx(m['progText'] as String, size: 12, color: p.t2, tab: true)),
              const SizedBox(width: 8),
              Tx('${closed ? 100 : progW.round()}%', size: 12, w: FontWeight.w600, color: p.t2, tab: true),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(children: [
                Container(height: 6, color: p.ink.withValues(alpha: .10)),
                FractionallySizedBox(
                  widthFactor: closed ? 1.0 : (progW / 100).clamp(0.0, 1.0),
                  child: Container(height: 6, decoration: const BoxDecoration(gradient: Tb.mintCyan)),
                ),
              ]),
            ),
          ],
          if ((m['forgivenText'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Tx(m['forgivenText'] as String, size: 12, color: p.t2, tab: true),
          ],
          const SizedBox(height: 8),
          // Meta qator: sana · muddat + holat pill
          Row(children: [
            Expanded(
              child: Tx(
                [m['date'] as String, if ((m['due'] as String).isNotEmpty) m['due'] as String].join(' · '),
                size: 12, color: p.t4, tab: true, maxLines: 2,
              ),
            ),
            const SizedBox(width: 8),
            _statusPill(m, p),
          ]),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: tags),
          ],
          if (m['canCancel'] == true) ...[
            const SizedBox(height: 10),
            Tap(
              onTap: m['cancel'] as VoidCallback,
              child: Tx(store.L()['btnCancelFull'] as String, size: 13, w: FontWeight.w600, color: p.coral),
            ),
          ],
        ]),
      ),
    );
  }

  // ---------------- Bo'sh holat ----------------
  // Skroll-xavfsiz: pastki panel + klaviatura maydonni siqqanda ham overflow bermaydi.
  Widget _empty(Pal p) => LayoutBuilder(
        builder: (ctx, c) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: _emptyBody(p),
          ),
        ),
      );

  Widget _emptyBody(Pal p) => Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 100),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.glass,
                border: Border.all(color: p.glassBd),
              ),
              child: Icon(Icons.description_outlined, size: 32, color: p.t3),
            ),
            const SizedBox(height: 16),
            Tx(store.L()['noDebtTitle'] as String, size: 15, w: FontWeight.w600, color: p.t1, align: TextAlign.center),
            const SizedBox(height: 6),
            Tx(store.L()['noDebtSub'] as String, size: 13, color: p.t4, align: TextAlign.center, lh: 18),
          ]),
        ),
      );

  // ---------------- Yangi yozuv sheet'i (lend/borrow/close) — §5.9 ----------------
  // Ilgari inline pastki panel edi; endi SheetShell ichidagi forma. Callback'lar
  // (chSetA/chSetCur/chSetDue/chSetNote/chSetReason/chSubmit/chClosePanel) o'zgarmagan.
  Widget _txSheet(BuildContext context, Map<String, dynamic> v, Pal p) {
    final L0 = v['L'] as Map<String, dynamic>;
    final isClose = v['chIsClose'] == true;
    final isLend = v['chIsLend'] == true;
    final isBorrow = v['chIsBorrow'] == true;
    final curs = (v['chCurs'] as List).cast<String>();
    final title = isLend
        ? L0['lendDebt'] as String
        : isBorrow
            ? L0['borrowDebt'] as String
            : L0['closeDebt'] as String;
    final amtStr = v['chA'] as String;
    final amt = int.tryParse(amtStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final amtColor = isLend ? p.mint : (isBorrow ? p.coral : p.ink);
    final due = v['chDue'] as String;

    final children = <Widget>[
      // Sarlavha 20/600 + o'ngda 44px ✕
      Row(children: [
        Expanded(child: Tx(title, size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head)),
        GlassIconBtn(icon: Icons.close_rounded, onTap: v['chClosePanel'] as VoidCallback),
      ]),
      const SizedBox(height: 6),
      // Hamkor: **Ism** 14 t2
      Row(children: [
        RingAvatar(initials: v['cInitials'] as String, size: 24, seed: v['cName'] as String, ring: 1.5),
        const SizedBox(width: 8),
        Flexible(child: Tx(v['cName'] as String, size: 14, w: FontWeight.w600, color: p.t2, maxLines: 1, ellipsis: true)),
      ]),
      const SizedBox(height: 18),
    ];

    if (isClose) {
      // Qaysi qarzni yopish — chip tanlash
      final chips = (v['chCloseChips'] as List).cast<Map<String, dynamic>>();
      if (chips.isEmpty) {
        children.add(Tx(L0['noClosable'] as String, size: 14, color: p.t3));
        children.add(const SizedBox(height: 14));
      } else {
        children.add(SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                PillChip(
                  label: chips[i]['label'] as String,
                  selected: chips[i]['sel'] == true,
                  onTap: chips[i]['pick'] as VoidCallback,
                  leading: chips[i]['locked'] == true
                      ? Icon(Icons.lock_outline_rounded, size: 14, color: chips[i]['sel'] == true ? p.bg : p.t4)
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: chips[i]['sel'] == true ? p.bg : (chips[i]['dir'] == 'in' ? p.mint : p.coral),
                          ),
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
            Expanded(
              child: PillChip(
                label: L0['gotMoney'] as String,
                selected: v['chReason'] == 'returned',
                onTap: () => v['chSetReason']('returned'),
                h: 44,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PillChip(
                label: L0['forgave'] as String,
                selected: v['chReason'] == 'forgiven',
                onTap: () => v['chSetReason']('forgiven'),
                h: 44,
              ),
            ),
          ]));
          children.add(const SizedBox(height: 14));
        }
      }
    }

    // Summa 46/600 tab + valyuta segmenti (h40 shisha pill; yopishda valyuta qat'iy)
    final amountField = StoreField(
      value: amtStr,
      onChanged: (t) => v['chSetA'](t),
      hint: '0',
      hintColor: p.t6,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [_GroupFmt()],
      style: tbStyle(size: 46, w: FontWeight.w600, color: amtColor, tab: true, ls: -1),
    );
    final curSeg = isClose
        ? Tx(v['chCur'] as String, size: 16, w: FontWeight.w600, color: p.t2, tab: true)
        : _curSegment(p, curs, v['chCur'] as String, (c) => v['chSetCur'](c));
    if (curs.length <= 2 || isClose) {
      children.add(Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: amountField),
        const SizedBox(width: 12),
        curSeg,
      ]));
    } else {
      children.add(amountField);
      children.add(const SizedBox(height: 10));
      children.add(Align(alignment: Alignment.centerLeft, child: curSeg));
    }
    children.add(const SizedBox(height: 14));

    // Chiplar qatori: [cal] sana (bugun) · [clock amber] muddat (kalendar)
    if (!isClose) {
      final dateIso = v['chDate'] as String;
      children.add(SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            PillChip(
              label: dateIso.isEmpty ? _dueLabel(DateTime.now().toIso8601String()) : _dueLabel(dateIso),
              selected: false,
              onTap: null,
              leading: Icon(Icons.calendar_today_rounded, size: 16, color: p.t2),
            ),
            const SizedBox(width: 8),
            PillChip(
              label: due.isEmpty ? L0['lblDue'] as String : _dueLabel(due),
              selected: due.isNotEmpty,
              onTap: () => _pickDue(context, v),
              leading: Icon(Icons.schedule_rounded, size: 16, color: due.isNotEmpty ? p.bg : p.amber),
            ),
            if (due.isNotEmpty) ...[
              const SizedBox(width: 8),
              GlassIconBtn(icon: Icons.close_rounded, onTap: () => v['chSetDue'](''), size: 40, iconSize: 18),
            ],
          ],
        ),
      ));
      children.add(const SizedBox(height: 14));
    }

    // Izoh — h48 shisha pill
    children.add(GlassField(
      h: 48,
      child: StoreField(
        value: v['chNote'] as String,
        onChanged: (t) => v['chSetNote'](t),
        hint: L0['noteHintDots'] as String,
        style: tbStyle(size: 15, color: p.ink),
      ),
    ));
    children.add(const SizedBox(height: 18));
    children.add(GradientBtn(
      label: _t('sendEntry', 'Yozuvni yuborish'), // TODO l10n
      icon: Icons.send_rounded,
      onTap: v['chSubmit'] as VoidCallback,
      enabled: amt > 0,
    ));
    children.add(const SizedBox(height: 10));
    children.add(Center(
      child: Tx(
        v['accepted'] == true
            ? _t('entryPendingHint', "Hamkor tasdiqlagach yozuv faol bo'ladi") // TODO l10n
            : L0['hintBook'] as String,
        size: 13, color: p.t4, align: TextAlign.center,
      ),
    ));

    return SheetShell(
      onClose: v['chClosePanel'] as VoidCallback,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  // UZS|USD segmenti — h40 shisha pill, tanlangan oq fon + bg matn
  Widget _curSegment(Pal p, List<String> curs, String cur, ValueChanged<String> onPick) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.glass,
        border: Border.all(color: p.glassBd),
        borderRadius: BorderRadius.circular(Tb.rPill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final c in curs)
          Tap(
            onTap: () => onPick(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cur == c ? p.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(Tb.rPill),
              ),
              child: Tx(c, size: 13, w: FontWeight.w700, color: cur == c ? p.bg : p.t2, font: TbFont.num),
            ),
          ),
      ]),
    );
  }

  // Muddat — kalendar orqali tanlanadi (matn kiritish YO'Q).
  Future<void> _pickDue(BuildContext context, Map<String, dynamic> v) async {
    final L0 = v['L'] as Map<String, dynamic>;
    final iso = v['chDue'] as String;
    final set = v['chSetDue'] as ValueChanged<String>;
    final p = curPal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final init = DateTime.tryParse(iso) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: init.isBefore(today) ? today : init,
      firstDate: today,
      lastDate: DateTime(now.year + 5),
      helpText: L0['dueHelp'] as String,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: (p.isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
            primary: p.violet,
            onPrimary: Colors.white,
            surface: p.surface,
            onSurface: p.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      set('${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  // ---------------- Pastki panel: Qarz berish · Qarzni yopish · eslatma ----------------
  Widget _bottomPanel(Map<String, dynamic> v, Pal p) {
    final btns = (v['ledBtns'] as List).cast<Map<String, dynamic>>();
    // Eslatma — Moliya/profil "reminders" ro'yxatidagi shu hamkor yozuvi
    // (faqat menga qarzi bor, Trust'dagi hamkor uchun mavjud).
    final cid = store.S['clientId'];
    Map<String, dynamic>? rem;
    for (final r in ((v['reminders'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
      if (r['key'] == cid) {
        rem = r;
        break;
      }
    }
    final remOn = rem != null && rem['canRemind'] == true;
    final remCool = rem != null && rem['cooling'] == true;
    final remCoolText = rem != null ? (rem['coolText'] as String? ?? '') : '';
    final remTap = rem != null ? rem['remind'] : null;
    return BottomPanel(
      h: 72,
      child: Row(children: [
        for (var i = 0; i < btns.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: i == 0
                ? (btns[i]['on'] == true
                    ? SolidBtn.mint(
                        btns[i]['label'] as String,
                        () => v['ledBtnTap'](btns[i]['key'], true, btns[i]['off']),
                        icon: Icons.north_east_rounded,
                        h: 52,
                        fs: 14,
                      )
                    : GlassBtn(
                        label: btns[i]['label'] as String,
                        onTap: () => v['ledBtnTap'](btns[i]['key'], false, btns[i]['off']),
                        icon: Icons.north_east_rounded,
                        fg: p.t5,
                        h: 52,
                        fs: 14,
                      ))
                : GlassBtn(
                    label: btns[i]['label'] as String,
                    onTap: () => v['ledBtnTap'](btns[i]['key'], btns[i]['on'] == true, btns[i]['off']),
                    icon: Icons.refresh_rounded,
                    fg: btns[i]['on'] == true ? p.ink : p.t5,
                    h: 52,
                    fs: 14,
                  ),
          ),
        ],
        const SizedBox(width: 8),
        // Eslatma — 52px gradient doira (bell)
        GlassIconBtn(
          icon: Icons.notifications_none_rounded,
          gradient: remOn,
          size: 52,
          color: p.t5,
          onTap: () {
            if (remOn) {
              remTap();
            } else if (remCool) {
              store.toast_(remCoolText);
            } else {
              store.toast_(_t('ledgerNoActive', "Faol qarz yo'q"));
            }
          },
        ),
      ]),
    );
  }

  // ---------------- Menyu sheet (rename/archive|disconnect/profile) ----------------
  Widget _menuSheet(Map<String, dynamic> v, Pal p) {
    final L0 = v['L'] as Map<String, dynamic>;
    return SheetShell(
      onClose: () => v['menuClose'](),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Tx(v['cName'] as String, size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head, maxLines: 2),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListRow(icon: Icons.edit_outlined, iconColor: p.cyan, title: L0['menuRename'] as String, onTap: () => v['menuRename']()),
            if (v['incoming'] == true)
              ListRow(icon: Icons.close_rounded, iconColor: p.coral, title: L0['menuDisconnect'] as String, onTap: () => v['menuDisconnect']())
            else
              ListRow(icon: Icons.archive_outlined, iconColor: p.t1, title: L0['menuArchive'] as String, onTap: () => v['menuArchive']()),
            ListRow(icon: Icons.person_outline_rounded, iconColor: p.t1, title: L0['menuProfile'] as String, onTap: () => v['menuProfile'](), last: true),
          ]),
        ),
      ]),
    );
  }

  // ---------------- Hamkor profili sheet ----------------
  Widget _profileSheet(Map<String, dynamic> v, Pal p) {
    final L0 = v['L'] as Map<String, dynamic>;
    return SheetShell(
      onClose: () => v['pProfClose'](),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
        Center(
          child: RingAvatar(
            initials: v['cInitials'] as String,
            size: 72,
            ring: 3,
            seed: v['cName'] as String,
            dot: v['cInTrust'] == true ? p.cyan : null,
          ),
        ),
        const SizedBox(height: 12),
        Tx(v['cName'] as String, size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head, align: TextAlign.center),
        const SizedBox(height: 4),
        Tx(v['pPhone'] as String, size: 15, color: p.t2, tab: true, align: TextAlign.center),
        const SizedBox(height: 6),
        Tx(v['pStatus'] as String, size: 13, color: v['cInTrust'] == true ? p.mint : p.t3, align: TextAlign.center),
        const SizedBox(height: 20),
        GlassBtn(label: L0['btnClose'] as String, onTap: () => v['pProfClose'](), h: 48),
      ]),
    );
  }

  // ---------------- "Barchasini tasdiqlash" sheet ----------------
  Widget _revAllSheet(Map<String, dynamic> v, Pal p) {
    final L0 = v['L'] as Map<String, dynamic>;
    return SheetShell(
      onClose: () => v['revAllNo'](),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Tx(L0['confirmAllTitle'] as String, size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head),
        const SizedBox(height: 8),
        Tx(v['revAllText'] as String, size: 14, color: p.t2, lh: 20),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: GlassBtn(label: L0['btnCancelShort'] as String, onTap: () => v['revAllNo'](), h: 48)),
          const SizedBox(width: 8),
          Expanded(child: GradientBtn(label: L0['btnConfirm'] as String, onTap: () => v['revAllOk'](), icon: Icons.check_rounded, h: 48, fs: 15)),
        ]),
      ]),
    );
  }

  // ---------------- Yozuv tarixi / tahrir sheet'i ----------------
  Widget _historySheet(Map<String, dynamic> v, Pal p) {
    final L0 = v['L'] as Map<String, dynamic>;
    final d = v['histData'] as Map<String, dynamic>?;
    if (d == null) return const SizedBox.shrink();
    final editing = v['histEditing'] == true;
    final versions = (d['versions'] as List).cast<Map<String, dynamic>>();
    return SheetShell(
      onClose: () => v['histClose'](),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Tx(d['title'] as String, size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head),
              const SizedBox(height: 2),
              Tx(d['stLabel'] as String, size: 13, w: FontWeight.w600, color: p.t2),
            ]),
          ),
          GlassIconBtn(icon: Icons.close_rounded, onTap: () => v['histClose']()),
        ]),
        const SizedBox(height: 16),
        if (!editing) ...[
          GlassCard(
            r: Tb.rRow,
            pad: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              _kv(p, L0['lblAmount'] as String, d['amount'] as String),
              _kv(p, L0['date'] as String, d['date'] as String),
              if ((d['due'] as String).isNotEmpty) _kv(p, L0['lblDue'] as String, d['due'] as String),
              if ((d['note'] as String).isNotEmpty) _kv(p, L0['lblNote'] as String, d['note'] as String),
            ]),
          ),
          if (versions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Cap(L0['capHistory'] as String),
            const SizedBox(height: 8),
            for (final ver in versions)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: p.glass,
                  border: Border.all(color: p.glassBd),
                  borderRadius: BorderRadius.circular(Tb.rIcon),
                ),
                child: Row(children: [
                  Expanded(
                    // Versiya qatori (summa · muddat · izoh) — moliyaviy
                    // qiymat "..." bilan kesilmaydi, o'raladi.
                    child: Tx(
                      [ver['amount'], if ((ver['due'] as String).isNotEmpty) ver['due'], if ((ver['note'] as String).isNotEmpty) ver['note']].join(' · '),
                      size: 13, color: p.t1, tab: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tx(ver['time'] as String, size: 11, color: p.t4, tab: true),
                ]),
              ),
          ],
          if (d['canEdit'] == true) ...[
            const SizedBox(height: 16),
            GlassBtn(label: L0['btnEdit'] as String, onTap: () => v['histEditStart'](), icon: Icons.edit_outlined, h: 48),
          ],
        ] else ...[
          _sheetField(p, L0['lblAmount'] as String, v['eA'] as String, (t) => v['eSetA'](t), hint: '0', number: true),
          const SizedBox(height: 12),
          _sheetField(p, L0['dueOptional'] as String, v['eDue'] as String, (t) => v['eSetDue'](t), hint: L0['dueDateHint'] as String),
          const SizedBox(height: 12),
          _sheetField(p, L0['lblNote'] as String, v['eNote'] as String, (t) => v['eSetNote'](t), hint: L0['noteWhy'] as String),
          const SizedBox(height: 10),
          Tx(L0['editActiveNote'] as String, size: 13, color: p.t4, lh: 18),
          const SizedBox(height: 16),
          GradientBtn(label: L0['sendChange'] as String, onTap: () => v['histEditSave'](), icon: Icons.send_rounded),
        ],
      ]),
    );
  }

  Widget _kv(Pal p, String k, String val) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 78, child: Tx(k, size: 13, color: p.t3)),
          Expanded(child: Tx(val, size: 14, w: FontWeight.w600, color: p.ink, tab: true)),
        ]),
      );

  // Sheet maydoni: Cap + GlassField(h48)
  Widget _sheetField(Pal p, String label, String value, ValueChanged<String> onCh, {String? hint, bool number = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Cap(label),
      const SizedBox(height: 8),
      GlassField(
        h: 48,
        child: StoreField(
          value: value,
          onChanged: onCh,
          hint: hint,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: false) : null,
          style: tbStyle(size: 15, w: number ? FontWeight.w600 : FontWeight.w400, color: p.ink, tab: number),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final L0 = v['L'] as Map<String, dynamic>;

    // Yuklanish/xato holati — HECH QACHON o'lik ekran bo'lmasin: orqaga tugma doim bo'lsin.
    if (v['hasLedger'] != true) {
      return SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 12),
            child: Align(alignment: Alignment.centerLeft, child: BackBtn(onTap: () => v['back']())),
          ),
          Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: p.cyan))),
        ]),
      );
    }

    final balLines = (v['balLines'] as List).cast<Map<String, dynamic>>();
    final cards = (v['ledCards'] as List).cast<Map<String, dynamic>>();
    final review = (v['ledReview'] as List).cast<Map<String, dynamic>>();
    final feed = (v['ledFeed'] as List).cast<Map<String, dynamic>>();
    final panelOpen = v['chAct'] != null;
    final inTrust = v['cInTrust'] == true;

    // -------- Header: BackBtn · RingAvatar(40) · ism 17/600 + holat · ⋯ --------
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 8),
      child: Row(children: [
        BackBtn(onTap: () => v['back']()),
        const SizedBox(width: 12),
        RingAvatar(initials: v['cInitials'] as String, size: 40, seed: v['cName'] as String, dot: inTrust ? p.cyan : null),
        const SizedBox(width: 12),
        Expanded(
          child: v['renaming'] == true
              ? Row(children: [
                  Expanded(
                    child: GlassField(
                      h: 40,
                      focused: true,
                      child: StoreField(
                        value: v['renVal'] as String,
                        onChanged: (t) => v['onRen'](t),
                        style: tbStyle(size: 15, w: FontWeight.w600, color: p.ink),
                        onSubmit: () => v['renSave'](),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: GradientBtn(label: L0['btnOk'] as String, onTap: () => v['renSave'](), h: 40, fs: 13, glow: false),
                  ),
                ])
              : Tap(
                  onTap: () => v['menuTap'](),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    // Hamkor nomi — "..." bilan kesilmaydi (moliyaviy ilova qoidasi)
                    Tx(v['cName'] as String, size: 17, w: FontWeight.w600, color: p.ink, font: TbFont.head, maxLines: 2),
                    const SizedBox(height: 1),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: Tx(
                          inTrust
                              ? _t('inTrustBadge', "Trustbook'da") // TODO l10n
                              : _t('viaSms', 'SMS orqali'), // TODO l10n
                          size: 13, color: inTrust ? p.cyan : p.t3, maxLines: 1, ellipsis: true,
                        ),
                      ),
                      if (inTrust) ...[
                        const SizedBox(width: 3),
                        Icon(Icons.check_rounded, size: 14, color: p.cyan),
                      ],
                    ]),
                  ]),
                ),
        ),
        const SizedBox(width: 8),
        // "Ko'proq" — kontekst menyu (rename/archive/profil); nom bosilganda ham shu menyu.
        GlassIconBtn(icon: Icons.more_horiz_rounded, onTap: () => v['menuTap']()),
      ]),
    );

    // -------- Off-Trust / kutilayotgan bog'lanish banneri --------
    // offTrust: hamkor Trust'da YO'Q (ro'yxatdan o'tmagan). pendingLink: Trust'da BOR,
    // lekin bog'lanish hali qabul qilinmagan — bularni ARALASHTIRMA (badge bilan ziddiyat).
    final bannerText = v['pendingLink'] == true
        ? store.Lf('pendingLinkBanner', {'name': v['pendingLinkName'] as String? ?? ''})
        : (v['offTrust'] == true ? L0['offTrustBanner'] as String : null);
    final offTrustBanner = bannerText != null
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: p.amber.withValues(alpha: .10),
                border: Border.all(color: p.amber.withValues(alpha: .30)),
                borderRadius: BorderRadius.circular(Tb.rIcon),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 16, color: p.amber),
                const SizedBox(width: 8),
                Expanded(child: Tx(bannerText, size: 13, color: p.t1, lh: 18)),
              ]),
            ),
          )
        : const SizedBox.shrink();

    // -------- Lenta (teskari ListView: [0] — eng pastda) --------
    // Yuqoridan pastga: balans kartasi → eski yozuvlar → pufaklar (eski → yangi)
    // → tasdiq kartalari (eng pastda). reverse:true uchun tartib teskari tuziladi.
    final top = <Widget>[];
    top.add(_balanceCard(v, p, balLines));
    if (review.isNotEmpty) {
      top.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(children: [
          Expanded(child: Cap(store.Lf('oldRecordsCap', {'n': '${v['ledReviewCount']}'}), ls: 1.2)),
          if (review.length > 1)
            Tap(
              onTap: () => v['revAllAsk'](),
              child: Tx(L0['confirmAll'] as String, size: 13, w: FontWeight.w600, color: p.cyan),
            ),
        ]),
      ));
      for (final r in review) {
        top.add(_reviewCard(r, p));
      }
    }
    if (feed.isNotEmpty && cards.isNotEmpty) {
      top.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Cap(L0['capRecords'] as String, ls: 1.2),
      ));
    }
    // feed newest-first → lentada eski yuqorida, yangi pastda
    for (final f in feed.reversed) {
      top.add(_feedCard(f, p));
    }
    for (final c in cards) {
      top.add(_confirmCard(c, p));
    }
    final bodyChildren = <Widget>[
      const SizedBox(height: 124), // pastki panel uchun bo'shliq
      ...top.reversed,
      const SizedBox(height: 8),
    ];

    final body = v['ledgerLoading'] == true
        ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: p.cyan))
        : (feed.isEmpty && cards.isEmpty && review.isEmpty)
            ? _empty(p)
            : ListView(reverse: true, children: bodyChildren);

    return Stack(children: [
      Column(children: [
        header,
        offTrustBanner,
        Expanded(child: body),
      ]),
      // Pastki suzuvchi panel (Telegram kabi pastga yopishadi)
      Positioned(left: 16, right: 16, bottom: 16, child: _bottomPanel(v, p)),

      // Yangi yozuv sheet'i (lend/borrow/close) — SheetShell, klaviatura bilan skroll
      if (panelOpen) _txSheet(context, v, p),

      // Menyu (rename/archive/disconnect/profile)
      if (v['menuOpen'] == true) _menuSheet(v, p),

      // Hamkor profili
      if (v['pProfOpen'] == true) _profileSheet(v, p),

      // "Barchasini tasdiqlash" tasdiq oynasi
      if (v['revAllOpen'] == true) _revAllSheet(v, p),

      // Yozuv tarixi / tahrir
      if (v['histOpen'] == true) _historySheet(v, p),
    ]);
  }
}

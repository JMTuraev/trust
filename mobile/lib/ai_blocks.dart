// Trust AI — interaktiv bloklar (docs/ai-character.md §11).
//
// Server javobi quruq matn emas, BLOKLAR ro'yxati bo'lib keladi; bu fayl ularni
// ilovaning mavjud dizayn tilida (karta r16, count-up raqam, confirm oqimi)
// native widgetga aylantiradi.
//
// 🔒 Oltin qoida: AI hech qachon pul amalini O'ZI bajarmaydi. Har amal bloki
// (debt_card / budget_set / category_move) foydalanuvchi TASDIQ dialogida "ha"
// deganidan keyingina mavjud endpointni chaqiradi:
//   remind        -> POST  /api/partners/:id/remind
//   budget_set    -> PUT   /api/limits
//   category_move -> PATCH /api/expenses/:id
//
// Ranglar FAQAT brend palitrasidan (theme.dart p.red / p.green) — Colors.red YO'Q.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'api.dart';
import 'store.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------------------
// MODEL — JSON -> tozalangan bloklar
// ---------------------------------------------------------------------------

/// Qo'llab-quvvatlanadigan blok turlari (§11 jadvali). Bu ro'yxatda yo'q tur
/// (yoki nuqsonli blok) JIMGINA tashlab ketiladi — chat hech qachon yiqilmasin.
const Set<String> kAiBlockTypes = {
  'text', 'stat', 'chart', 'chips', 'debt_card', 'budget_set', 'category_move', 'progress',
};

/// Server `blocks` maydonini xavfsiz ro'yxatga aylantiradi (store.dart shuni chaqiradi).
List<Map<String, dynamic>> parseAiBlocks(dynamic raw) {
  final out = <Map<String, dynamic>>[];
  if (raw is! List) return out;
  for (final b in raw) {
    if (b is! Map) continue;
    final type = '${b['type'] ?? ''}';
    if (!kAiBlockTypes.contains(type)) continue;
    final m = <String, dynamic>{};
    b.forEach((k, v) => m['$k'] = v);
    if (!_aiBlockValid(type, m)) continue;
    out.add(m);
  }
  return out;
}

/// Blokda ishlash uchun MINIMAL ma'lumot bormi (yarim-yo'q blok chizilmasin).
bool _aiBlockValid(String type, Map<String, dynamic> b) {
  switch (type) {
    case 'text':
      return '${b['text'] ?? ''}'.trim().isNotEmpty;
    case 'stat':
      return '${b['value'] ?? ''}'.trim().isNotEmpty;
    case 'chart':
      return aiChartRows(b['data']).isNotEmpty;
    case 'chips':
      return aiStrList(b['items']).isNotEmpty;
    case 'debt_card':
      return '${b['partner_id'] ?? ''}'.trim().isNotEmpty && aiNum(b['amount']) != null;
    case 'budget_set':
      return aiNum(b['amount']) != null;
    case 'category_move':
      return '${b['expense_id'] ?? ''}'.trim().isNotEmpty && '${b['category'] ?? ''}'.trim().isNotEmpty;
    case 'progress':
      return aiNum(b['value'] ?? b['percent']) != null;
  }
  return false;
}

/// Raqam: 12, "12", "1 200,5" -> num; aks holda null.
num? aiNum(dynamic v) {
  if (v is num) return v;
  if (v is String) {
    final s = v.replaceAll(' ', '').replaceAll(' ', '').replaceAll(',', '.');
    return num.tryParse(s);
  }
  return null;
}

/// Matnlar ro'yxati (chips items) — bo'shlar tashlanadi.
List<String> aiStrList(dynamic v) {
  if (v is! List) return const <String>[];
  final out = <String>[];
  for (final e in v) {
    final s = '$e'.trim();
    if (s.isNotEmpty) out.add(s);
  }
  return out;
}

/// chart.data: [["Oziq-ovqat", 2100000], ...] yoki [{label, value}] — ikkalasi ham.
/// Qaytadi: [[String label, num value], ...]
List<List<dynamic>> aiChartRows(dynamic v) {
  final out = <List<dynamic>>[];
  if (v is! List) return out;
  for (final r in v) {
    if (r is List && r.length >= 2) {
      final n = aiNum(r[1]);
      final l = '${r[0]}'.trim();
      if (n != null && l.isNotEmpty) out.add([l, n]);
    } else if (r is Map) {
      final n = aiNum(r['value'] ?? r['amount'] ?? r['total']);
      final l = '${r['label'] ?? r['name'] ?? r['category'] ?? ''}'.trim();
      if (n != null && l.isNotEmpty) out.add([l, n]);
    }
  }
  return out;
}

/// "2 400 000" — guruhlangan absolyut son (xarajat.dart _AnimNum bilan bir xil).
String aiGroup(num v) {
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

String _aiTrim(double x) {
  final s = x.toStringAsFixed(x >= 10 ? 0 : 1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// O'qishli raqam (§6: "2 400 000" emas -> "2.4 mln"). 480000 -> "480k".
String aiShort(num v) {
  final a = v.abs();
  if (a >= 1000000) return '${_aiTrim(a / 1000000)} ${store.L()['aiUnitMln']}';
  if (a >= 10000) return '${_aiTrim(a / 1000)}${store.L()['aiUnitK']}';
  return aiGroup(a);
}

/// Blok toni -> BREND rangi. null = neytral (rang majburlanmaydi).
Color? aiTone(dynamic tone, Pal p) {
  switch ('${tone ?? ''}'.toLowerCase()) {
    case 'good':
    case 'ok':
    case 'up':
    case 'positive':
    case 'success':
      return p.green;
    case 'warn':
    case 'bad':
    case 'down':
    case 'negative':
    case 'danger':
      return p.red;
  }
  return null;
}

/// "1.2 mln" -> {n: 1.2, suffix: "mln", dec: 1, plus: false}; parse bo'lmasa null.
Map<String, dynamic>? aiSplitValue(dynamic v) {
  if (v is num) return {'n': v, 'suffix': '', 'dec': 0, 'plus': false};
  final s = '$v'.trim();
  if (s.isEmpty) return null;
  final m = RegExp(r'^([+\-−]?)\s*([0-9][0-9  .,]*)(.*)$').firstMatch(s);
  if (m == null) return null;
  final sign = m.group(1) ?? '';
  var digits = (m.group(2) ?? '').replaceAll(' ', '').replaceAll(' ', '');
  // Oxiridagi ajratgich ("1.2 mln" -> "1.2", "2 400 000." -> "2400000")
  while (digits.isNotEmpty && (digits.endsWith('.') || digits.endsWith(','))) {
    digits = digits.substring(0, digits.length - 1);
  }
  if (digits.contains(',') && digits.contains('.')) {
    digits = digits.replaceAll(',', ''); // vergul — guruh ajratgichi
  } else if (digits.contains(',')) {
    final parts = digits.split(',');
    // "2,4" -> kasr; "2,400,000" -> guruh
    digits = (parts.length == 2 && parts[1].length <= 2) ? '${parts[0]}.${parts[1]}' : digits.replaceAll(',', '');
  }
  final n = num.tryParse(digits);
  if (n == null) return null;
  final dot = digits.indexOf('.');
  final dec = dot < 0 ? 0 : (digits.length - dot - 1).clamp(0, 2);
  return {
    'n': (sign == '-' || sign == '−') ? -n : n,
    'suffix': (m.group(3) ?? '').trim(),
    'dec': dec,
    'plus': sign == '+',
  };
}

String _aiInitials(String n) {
  final parts = n.split(' ').where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.map((w) => w[0]).take(2).join().toUpperCase();
}

// ---------------------------------------------------------------------------
// "MARJON" MATN — yangi javob matni so'zma-so'z ochiladi (PO so'rovi 2026-07-17)
// ---------------------------------------------------------------------------

/// Matn so'z bo'laklari — har bo'lak "so'z + ortidagi bo'shliq" (yangi qatorlar
/// ham bo'shliqqa kiradi), shunda bo'laklar qo'shilsa ASL matn aynan tiklanadi
/// va TextSpan layouti to'liq matn bilan 1:1 bo'ladi.
List<String> aiRevealChunks(String text) {
  final out = <String>[];
  for (final m in RegExp(r'\S+\s*').allMatches(text)) {
    out.add(m[0]!);
  }
  if (out.isEmpty) return text.isEmpty ? const <String>[] : <String>[text];
  // Boshidagi bo'shliq (kamdan-kam) — birinchi bo'lakka qo'shib yuboriladi
  final matched = out.fold<int>(0, (s, c) => s + c.length);
  if (matched < text.length) out[0] = text.substring(0, text.length - matched) + out[0];
  return out;
}

/// So'z-reveal umumiy davomiyligi (ms): ~55ms/so'z, uzun matnda 2.5s bilan
/// cheklanadi (so'zlar avtomatik tezroq/guruh bo'lib ochiladi). Bir so'z — 0:
/// blokning o'z "qo'nish" fade'i yetarli. DIQQAT: ai_chat.dart dagi
/// _AiAnswer._tick ham SHU formuladan foydalanadi — matn ochilib BO'LGACH
/// keyingi blok qo'nishi uchun ikkalasi sinxron turishi shart.
int aiTextRevealMs(String text) {
  final n = aiRevealChunks(text).length;
  if (n <= 1) return 0;
  final ms = n * 55;
  return ms > 2500 ? 2500 : ms;
}

// ---------------------------------------------------------------------------
// UMUMIY QISMLAR
// ---------------------------------------------------------------------------

/// Blok kartasi — ilovadagi karta uslubi (xarajat.dart bilan bir xil r16/field/bd2),
/// lekin ro'yxat ichida turgani uchun og'ir soyasiz.
BoxDecoration aiCardDeco(Pal p) => BoxDecoration(
      color: p.field,
      border: Border.all(color: p.bd2),
      borderRadius: BorderRadius.circular(16),
    );

/// Tasdiq dialogi (§11: har amal `confirm: true`). link_decision_sheet.dart uslubi.
Future<bool> aiConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String okLabel,
}) async {
  final p = curPal();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: p.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Tx(title, size: 16, w: FontWeight.w700, color: p.ink),
      content: Tx(body, size: 13.5, color: p.t1, lh: 19),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Tx(store.L()['btnCancelShort'] as String, size: 14, w: FontWeight.w600, color: p.t2),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Tx(okLabel, size: 14, w: FontWeight.w700, color: p.ink),
        ),
      ],
    ),
  );
  return ok == true;
}

/// 0 dan sanab chiqadigan raqam — xarajat.dart _AnimNum bilan bir xil his
/// (900ms, easeInCubic: sekin boshlanib tezlashadi, tabular figures).
class AiCountUp extends StatefulWidget {
  final num value;
  final String prefix;
  final String suffix;
  final int decimals;
  final double size;
  final FontWeight weight;
  final Color color;
  final double ls;
  const AiCountUp({
    super.key,
    required this.value,
    required this.size,
    required this.color,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.weight = FontWeight.w700,
    this.ls = 0,
  });

  @override
  State<AiCountUp> createState() => _AiCountUpState();
}

class _AiCountUpState extends State<AiCountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900), value: 1);
  double _from = 0;
  late double _to = widget.value.toDouble();

  @override
  void initState() {
    super.initState();
    if (_to != 0) _c.forward(from: 0); // AI raqami har doim 0 dan sanaydi
  }

  double _now() {
    final t = Curves.easeInCubic.transform(_c.value);
    return _from + (_to - _from) * t;
  }

  @override
  void didUpdateWidget(covariant AiCountUp old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = _now();
      _to = widget.value.toDouble();
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    final a = v.abs();
    final body = widget.decimals > 0 ? a.toStringAsFixed(widget.decimals) : aiGroup(a);
    return (v < -0.000001 ? '−' : '') + body;
  }

  @override
  Widget build(BuildContext context) {
    final suf = widget.suffix.trim();
    final tail = suf.isEmpty ? '' : (suf.length <= 1 ? suf : ' $suf'); // "480k" / "2.1 mln"
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Text(
        '${widget.prefix}${_fmt(_now())}$tail',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textScaler: TextScaler.noScaling,
        style: GoogleFonts.inter(
          fontSize: widget.size,
          fontWeight: widget.weight,
          color: widget.color,
          letterSpacing: widget.ls,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BLOK -> WIDGET
// ---------------------------------------------------------------------------

/// Bitta blokni chizadi. Notanish tur parseAiBlocks'da filtrlanadi — bu yerda
/// zaxira sifatida bo'sh widget qaytadi (hech qachon crash emas).
class AiBlockView extends StatelessWidget {
  final Map<String, dynamic> block;
  final ValueChanged<String> onChip;

  /// FAQAT text bloki uchun: yangi javobda so'z-reveal ("marjon"). Boshqa blok
  /// turlariga ta'sir qilmaydi.
  final bool animate;

  const AiBlockView({
    super.key,
    required this.block,
    required this.onChip,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    switch ('${block['type'] ?? ''}') {
      case 'text':
        return AiTextBubble(text: '${block['text']}', animate: animate);
      case 'stat':
        return _StatBlock(b: block);
      case 'chart':
        return _ChartBlock(b: block);
      case 'chips':
        return AiChips(items: aiStrList(block['items']), onTap: onChip);
      case 'debt_card':
        return _DebtCardBlock(b: block);
      case 'budget_set':
        return _BudgetSetBlock(b: block);
      case 'category_move':
        return _CategoryMoveBlock(b: block);
      case 'progress':
        return _ProgressBlock(b: block);
    }
    return const SizedBox.shrink();
  }
}

/// AI matn pufagi (chapda, iliq).
///
/// `animate: true` (faqat YANGI javob) — matn so'zma-so'z "marjondek" ochiladi:
/// butun matn joyini BOSHIDAN egallaydi (ko'rinmagan so'zlar shaffof, layout
/// sakramaydi — pufak balandligi o'zgarmaydi), so'zlar alpha bilan ohista
/// paydo bo'ladi. Tarixdan kelgan xabar (`animate: false`) darhol to'liq.
class AiTextBubble extends StatefulWidget {
  final String text;
  final bool animate;
  const AiTextBubble({super.key, required this.text, this.animate = false});

  @override
  State<AiTextBubble> createState() => _AiTextBubbleState();
}

class _AiTextBubbleState extends State<AiTextBubble> with SingleTickerProviderStateMixin {
  /// Fade oynasi (so'z-slotlarda): har so'z ~1.5 slot davomida 0->1 ochiladi —
  /// qattiq "yonish" emas, marjon donasidek ohista.
  static const double _fadeW = 1.5;

  late final List<String> _chunks = aiRevealChunks(widget.text);
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    // Animatsiya FAQAT birinchi qurilishda boshlanadi — tepadagi setState
    // widgetni qayta qursa ham takrorlanmaydi (_landed mexanizmiga mos:
    // keyingi rebuild'larda widget.animate=false keladi, biz e'tibor bermaymiz).
    // Scroll signali YO'Q: reveal davomida pufak balandligi o'zgarmaydi
    // (shaffof so'zlar joyni boshidan egallagan), scroll shart emas —
    // blok qo'nishlarida _AiAnswer._tick o'zi onGrow chaqiradi.
    final ms = aiTextRevealMs(widget.text);
    if (widget.animate && ms > 0) {
      _c = AnimationController(vsync: this, duration: Duration(milliseconds: ms))
        ..forward();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Widget _text(Pal p) {
    final c = _c;
    // Tarix yoki bir so'zli matn: darhol to'liq (mavjud Tx uslubi).
    if (c == null) return Tx(widget.text, size: 14, color: p.ink, lh: 20);
    // Tx bilan AYNAN bir xil uslub (Inter 14/20) — reveal tugagach ham shu
    // Text.rich qoladi, almashtirish/sakrash yo'q.
    final style = GoogleFonts.inter(fontSize: 14, color: p.ink, height: 20 / 14);
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final pw = c.value * (_chunks.length + _fadeW); // progress so'z-slotlarda
        return Text.rich(
          TextSpan(
            style: style,
            children: [
              for (var i = 0; i < _chunks.length; i++)
                TextSpan(
                  text: _chunks[i],
                  style: TextStyle(
                    color: p.ink.withValues(alpha: ((pw - i) / _fadeW).clamp(0.0, 1.0)),
                  ),
                ),
            ],
          ),
          textScaler: TextScaler.noScaling,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Container(
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
      child: _text(p),
    );
  }
}

/// Tez javob tugmalari — bosilsa matn keyingi savol bo'lib yuboriladi.
class AiChips extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onTap;
  const AiChips({super.key, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in items)
          Tap(
            onTap: () => onTap(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: p.bg,
                border: Border.all(color: p.bd),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Tx(s, size: 12.5, w: FontWeight.w500, color: p.ink),
            ),
          ),
      ],
    );
  }
}

/// Katta raqam + o'zgarish pilyulyasi (+25%). Rang: brend qizil/yashil.
class _StatBlock extends StatelessWidget {
  final Map<String, dynamic> b;
  const _StatBlock({required this.b});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final tone = aiTone(b['tone'], p);
    final label = '${b['label'] ?? ''}'.trim();
    final delta = '${b['delta'] ?? ''}'.trim();
    final parts = aiSplitValue(b['value']);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: aiCardDeco(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Tx(label.toUpperCase(), size: 11, w: FontWeight.w600, color: p.t2, ls: 1.4, maxLines: 1, ellipsis: true),
            const SizedBox(height: 7),
          ],
          Row(
            children: [
              Flexible(
                child: parts == null
                    // Raqam emas (masalan "yaqin") — shunchaki matn, animatsiyasiz
                    ? Tx('${b['value']}', size: 24, w: FontWeight.w700, color: tone ?? p.ink,
                        ls: -0.5, maxLines: 1, ellipsis: true)
                    : AiCountUp(
                        value: parts['n'] as num,
                        prefix: parts['plus'] == true ? '+' : '',
                        suffix: parts['suffix'] as String,
                        decimals: parts['dec'] as int,
                        size: 24,
                        weight: FontWeight.w700,
                        color: tone ?? p.ink,
                        ls: -0.5,
                      ),
              ),
              if (delta.isNotEmpty) ...[
                const SizedBox(width: 9),
                _DeltaPill(text: delta, tone: tone ?? p.t1),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final String text;
  final Color tone;
  const _DeltaPill({required this.text, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Tx(text, size: 11.5, w: FontWeight.w700, color: tone),
    );
  }
}

/// Mini bar chart — toifa | bar | qiymat. Paketsiz, native (pubspec'da chart yo'q).
class _ChartBlock extends StatelessWidget {
  final Map<String, dynamic> b;
  const _ChartBlock({required this.b});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final rows = aiChartRows(b['data']);
    final color = aiTone(b['tone'], p) ?? p.ink; // neytral: brend siyoh rangi
    final title = '${b['title'] ?? ''}'.trim();
    var maxV = 0.0;
    for (final r in rows) {
      final x = (r[1] as num).abs().toDouble();
      if (x > maxV) maxV = x;
    }
    if (maxV <= 0) maxV = 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: aiCardDeco(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Tx(title.toUpperCase(), size: 11, w: FontWeight.w600, color: p.t2, ls: 1.4, maxLines: 1, ellipsis: true),
            const SizedBox(height: 11),
          ],
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Tx('${r[0]}', size: 12, color: p.t1, maxLines: 1, ellipsis: true),
                  ),
                  Expanded(
                    child: _ChartBar(
                      frac: ((r[1] as num).abs().toDouble() / maxV).clamp(0.04, 1.0),
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Tx(aiShort(r[1] as num), size: 12, w: FontWeight.w600, color: p.ink, tab: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  final double frac;
  final Color color;
  const _ChartBar({required this.frac, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: frac),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) => Container(
        height: 8,
        decoration: BoxDecoration(color: p.barbg, borderRadius: BorderRadius.circular(4)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: t.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    );
  }
}

/// Qarz kartasi — muzlab qolgan pul + "Eslatma yuborish" (tasdiq bilan).
/// Endpoint: POST /api/partners/:id/remind (mavjud).
class _DebtCardBlock extends StatefulWidget {
  final Map<String, dynamic> b;
  const _DebtCardBlock({required this.b});

  @override
  State<_DebtCardBlock> createState() => _DebtCardBlockState();
}

class _DebtCardBlockState extends State<_DebtCardBlock> {
  bool _busy = false;
  bool _done = false;

  String get _name {
    final n = '${widget.b['name'] ?? ''}'.trim();
    return n.isEmpty ? '—' : n;
  }

  String _label() {
    final acts = widget.b['actions'];
    if (acts is List) {
      for (final a in acts) {
        if (a is Map && '${a['action'] ?? ''}' == 'remind') {
          final l = '${a['label'] ?? ''}'.trim();
          if (l.isNotEmpty) return l;
        }
      }
    }
    return store.L()['aiRemind'] as String;
  }

  Future<void> _remind() async {
    if (_busy || _done) return;
    final id = '${widget.b['partner_id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    // AI taklif qildi — YUBORISHNI foydalanuvchi tasdiqlaydi
    final ok = await aiConfirm(
      context,
      title: store.L()['aiRemindTitle'] as String,
      body: store.Lf('aiRemindBody', {'name': _name}),
      okLabel: store.L()['aiRemind'] as String,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await Api.remind(id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = r.ok;
    });
    store.toast_(r.ok ? (store.L()['aiRemindDone'] as String) : r.error);
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final amount = aiNum(widget.b['amount']) ?? 0;
    final days = aiNum(widget.b['days'])?.round() ?? 0;
    // Yo'nalish: default — MENGA qarzdor (§4.5 muzlagan pul), ya'ni brend yashil.
    final iOwe = '${widget.b['direction'] ?? ''}' == 'i_owe';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: aiCardDeco(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TrustAvatar(initials: _aiInitials(_name), size: 40),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tx(_name, size: 14.5, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                    if (days > 0) ...[
                      const SizedBox(height: 2),
                      Tx(store.Lf('aiDaysFrozen', {'n': '$days'}), size: 11.5, color: p.t2),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AiCountUp(
                value: amount,
                suffix: '${store.L()['som']}',
                size: 15,
                weight: FontWeight.w700,
                color: iOwe ? p.red : p.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_done)
            _AiDoneStrip(text: store.L()['aiRemindDone'] as String)
          else
            InkBtn(label: _label(), h: 42, fs: 13.5, loading: _busy, onTap: _remind),
        ],
      ),
    );
  }
}

/// Chegara qo'yish — inline slider + tasdiq. Endpoint: PUT /api/limits (mavjud).
/// DIQQAT: /api/limits — OYLIK UMUMIY chegara (toifa bo'yicha emas); blokdagi
/// `category` faqat kontekst sifatida ko'rsatiladi.
class _BudgetSetBlock extends StatefulWidget {
  final Map<String, dynamic> b;
  const _BudgetSetBlock({required this.b});

  @override
  State<_BudgetSetBlock> createState() => _BudgetSetBlockState();
}

class _BudgetSetBlockState extends State<_BudgetSetBlock> {
  late double _min;
  late double _max;
  late double _v;
  bool _busy = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final amount = (aiNum(widget.b['amount']) ?? 0).toDouble().abs();
    _min = (aiNum(widget.b['min']) ?? 0).toDouble().abs();
    final maxRaw = (aiNum(widget.b['max']) ?? (amount > 0 ? amount * 2 : 1000000)).toDouble().abs();
    _max = maxRaw > _min ? maxRaw : _min + 1;
    _v = amount.clamp(_min, _max);
  }

  Future<void> _save() async {
    if (_busy || _done) return;
    final val = _v.round();
    final ok = await aiConfirm(
      context,
      title: store.L()['aiBudgetTitle'] as String,
      body: store.Lf('aiBudgetBody', {'amount': '${aiShort(val)} ${store.L()['som']}'}),
      okLabel: store.L()['aiBudgetSet'] as String,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await Api.setLimit(val);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = r.ok;
    });
    if (r.ok) {
      store.toast_(store.L()['aiBudgetDone'] as String);
      store.hydrate(full: false); // Xarajat ekranidagi limit darhol yangilansin
    } else {
      store.toast_(r.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final cat = '${widget.b['category'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: aiCardDeco(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tx(store.L()['aiBudgetCap'] as String, size: 11, w: FontWeight.w600, color: p.t2, ls: 1.6),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                aiGroup(_v),
                textScaler: TextScaler.noScaling,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                  letterSpacing: -0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Tx('${store.L()['som']}', size: 12.5, color: p.t3),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: p.ink,
              inactiveTrackColor: p.barbg,
              thumbColor: p.ink,
              overlayColor: p.ink.withValues(alpha: .10),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: _v.clamp(_min, _max),
              min: _min,
              max: _max,
              divisions: 20,
              onChanged: _done || _busy ? null : (x) => setState(() => _v = x),
            ),
          ),
          Tx(cat.isEmpty
                  ? (store.L()['aiBudgetHint'] as String)
                  : store.Lf('aiBudgetHintCat', {'cat': cat}),
              size: 11.5, color: p.t3, lh: 16),
          const SizedBox(height: 11),
          if (_done)
            _AiDoneStrip(text: store.L()['aiBudgetDone'] as String)
          else
            InkBtn(label: store.L()['aiBudgetSet'] as String, h: 42, fs: 13.5, loading: _busy, onTap: _save),
        ],
      ),
    );
  }
}

/// "Bu yozuvni {toifa}ga ko'chiraymi?" — tasdiq bilan.
/// Endpoint: PATCH /api/expenses/:id (mavjud).
class _CategoryMoveBlock extends StatefulWidget {
  final Map<String, dynamic> b;
  const _CategoryMoveBlock({required this.b});

  @override
  State<_CategoryMoveBlock> createState() => _CategoryMoveBlockState();
}

class _CategoryMoveBlockState extends State<_CategoryMoveBlock> {
  bool _busy = false;
  bool _done = false;

  Future<void> _move() async {
    if (_busy || _done) return;
    final id = '${widget.b['expense_id'] ?? ''}'.trim();
    final cat = '${widget.b['category'] ?? ''}'.trim();
    if (id.isEmpty || cat.isEmpty) return;
    final ok = await aiConfirm(
      context,
      title: store.L()['aiMoveTitle'] as String,
      body: store.Lf('aiMoveTo', {'cat': cat}),
      okLabel: store.L()['btnConfirm'] as String,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await Api.patchExpense(id, category: cat);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = r.ok;
    });
    if (r.ok) {
      store.toast_(store.Lf('tMovedTo', {'cat': cat}));
      store.hydrate(full: false); // papkalar/summalar yangilansin
    } else {
      store.toast_(r.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final cat = '${widget.b['category'] ?? ''}'.trim();
    final from = '${widget.b['from'] ?? ''}'.trim();
    final note = '${widget.b['label'] ?? widget.b['note'] ?? ''}'.trim();
    final amount = aiNum(widget.b['amount']);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: aiCardDeco(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tx(store.L()['aiMoveCap'] as String, size: 11, w: FontWeight.w600, color: p.t2, ls: 1.6),
          const SizedBox(height: 10),
          if (note.isNotEmpty || amount != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Tx(note.isEmpty ? '—' : note, size: 13, w: FontWeight.w500, color: p.ink,
                        maxLines: 1, ellipsis: true),
                  ),
                  if (amount != null) ...[
                    const SizedBox(width: 8),
                    Tx('${aiShort(amount)} ${store.L()['som']}', size: 13, w: FontWeight.w600, color: p.t1, tab: true),
                  ],
                ],
              ),
            ),
          Row(
            children: [
              if (from.isNotEmpty) ...[
                Flexible(child: Tx(from, size: 13, color: p.t3, maxLines: 1, ellipsis: true)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Tx('→', size: 14, color: p.t3),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: p.ink, width: 1.5),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Tx(cat, size: 13, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_done)
            _AiDoneStrip(text: store.Lf('tMovedTo', {'cat': cat}))
          else
            InkBtn(label: store.L()['btnConfirm'] as String, h: 42, fs: 13.5, loading: _busy, onTap: _move),
        ],
      ),
    );
  }
}

/// Streak / maqsad halqasi (§9 "g'alabani ko'r").
class _ProgressBlock extends StatelessWidget {
  final Map<String, dynamic> b;
  const _ProgressBlock({required this.b});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final raw = aiNum(b['value'] ?? b['percent']) ?? 0;
    final maxV = (aiNum(b['max']) ?? (raw > 1 ? 100 : 1)).toDouble();
    final frac = maxV > 0 ? (raw / maxV).clamp(0.0, 1.0).toDouble() : 0.0;
    final tone = aiTone(b['tone'], p) ?? p.green; // odatda g'alaba — brend yashil
    final label = '${b['label'] ?? ''}'.trim();
    final caption = '${b['caption'] ?? b['text'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: aiCardDeco(p),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: frac),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, t, __) => CustomPaint(
                painter: _AiRing(t, tone, p.barbg),
                child: Center(
                  child: Tx('${(t * 100).round()}%', size: 11, w: FontWeight.w700, color: p.ink, tab: true),
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label.isNotEmpty)
                  Tx(label, size: 14, w: FontWeight.w600, color: p.ink, maxLines: 2, ellipsis: true),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Tx(caption, size: 12, color: p.t2, lh: 16, maxLines: 3, ellipsis: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiRing extends CustomPainter {
  final double frac;
  final Color color;
  final Color track;
  _AiRing(this.frac, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    const sw = 4.0;
    final rect = Rect.fromLTWH(sw / 2, sw / 2, size.width - sw, size.height - sw);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..color = track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, bg);
    if (frac > 0) {
      final fg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * frac.clamp(0.0, 1.0), false, fg);
    }
  }

  @override
  bool shouldRepaint(_AiRing o) => o.frac != frac || o.color != color || o.track != track;
}

/// Amal bajarilgandan keyingi holat — takror bosib bo'lmaydi.
class _AiDoneStrip extends StatelessWidget {
  final String text;
  const _AiDoneStrip({required this.text});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.green.withValues(alpha: .10),
        border: Border.all(color: p.green.withValues(alpha: .30)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_rounded, size: 16, color: p.green),
          const SizedBox(width: 7),
          Flexible(child: Tx(text, size: 13, w: FontWeight.w600, color: p.green, maxLines: 1, ellipsis: true)),
        ],
      ),
    );
  }
}

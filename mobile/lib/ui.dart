// Trust — umumiy UI primitivlari (prototip elementlari bilan 1:1)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'store.dart';
import 'theme.dart';

Pal curPal() => pal(store.S['dark'] == true);

/// Inter shrift bilan matn. lh — px'dagi line-height (template'dagi ratio*fontSize).
class Tx extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight w;
  final Color color;
  final double? ls;
  final double? lh;
  final bool tab;
  final TextAlign? align;
  final int? maxLines;
  final bool ellipsis;
  const Tx(
    this.text, {
    super.key,
    required this.size,
    this.w = FontWeight.w400,
    required this.color,
    this.ls,
    this.lh,
    this.tab = false,
    this.align,
    this.maxLines,
    this.ellipsis = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      maxLines: maxLines,
      overflow: ellipsis ? TextOverflow.ellipsis : null,
      textScaler: TextScaler.noScaling,
      style: GoogleFonts.inter(
        fontSize: size,
        fontWeight: w,
        color: color,
        letterSpacing: ls,
        height: lh != null ? lh! / size : null,
        fontFeatures: tab ? const [FontFeature.tabularFigures()] : null,
      ),
    );
  }
}

/// Bosiladigan element
class Tap extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const Tap({super.key, this.onTap, required this.child});

  @override
  Widget build(BuildContext context) =>
      GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
}

/// Orqaga strelka (burchak-chiziq)
class BackChevron extends StatelessWidget {
  final Color color;
  final double size;
  final double thickness;
  const BackChevron({super.key, required this.color, this.size = 10, this.thickness = 2});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: color, width: thickness),
            bottom: BorderSide(color: color, width: thickness),
          ),
        ),
      ),
    );
  }
}

class BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Color? color;
  const BackBtn({super.key, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(child: BackChevron(color: color ?? curPal().ink)),
      ),
    );
  }
}

/// O'ngga chevron
class ChevRight extends StatelessWidget {
  final Color color;
  final double size;
  final double thickness;
  const ChevRight({super.key, required this.color, this.size = 7, this.thickness = 1.5});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: color, width: thickness),
            right: BorderSide(color: color, width: thickness),
          ),
        ),
      ),
    );
  }
}

/// Avatar ustidagi "Trust'da" belgisi. Stack(clipBehavior: Clip.none) ichida ishlatiladi.
class TrustBadge extends StatelessWidget {
  final double size;
  const TrustBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final k = size / 16;
    return Positioned(
      right: -2,
      bottom: -2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: p.ink,
          shape: BoxShape.circle,
          border: Border.all(color: p.bg, width: 2),
        ),
        child: Center(
          child: Transform.translate(
            offset: Offset(0, -1.5 * k),
            child: Transform.rotate(
              angle: -0.785398,
              child: Container(
                width: 6 * k,
                height: 3 * k,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: p.bg, width: 1.4),
                    bottom: BorderSide(color: p.bg, width: 1.4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Trust'da yo'q" belgisi
class OneSidedBadge extends StatelessWidget {
  final double size;
  const OneSidedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final k = size / 16;
    return Positioned(
      right: -2,
      bottom: -2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: p.bg,
          shape: BoxShape.circle,
          border: Border.all(color: p.t4, width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 4 * k,
              height: 4 * k,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.t2, width: 1.2)),
            ),
            Container(
              width: 8 * k,
              height: 3.5 * k,
              margin: const EdgeInsets.only(top: 0.5),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: p.t2, width: 1.2),
                  top: BorderSide(color: p.t2, width: 1.2),
                  right: BorderSide(color: p.t2, width: 1.2),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4 * k),
                  topRight: Radius.circular(4 * k),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Raqamli klaviatura (3x4). keys: [{label, tap}]
class KeyPad extends StatelessWidget {
  final List<Map<String, dynamic>> keys;
  const KeyPad({super.key, required this.keys});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (row) {
          return Row(
            children: List.generate(3, (col) {
              final k = keys[row * 3 + col];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Tap(
                    onTap: k['tap'],
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                      child: Tx(k['label'], size: 20, w: FontWeight.w600, color: p.ink),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}

/// Kod kataklari. boxes: [{key, d, bd}]
class CodeBoxes extends StatelessWidget {
  final List<Map<String, dynamic>> boxes;
  final double w, h, fs, gap, r;
  const CodeBoxes({
    super.key,
    required this.boxes,
    this.w = 50,
    this.h = 58,
    this.fs = 24,
    this.gap = 9,
    this.r = 12,
  });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final children = <Widget>[];
    for (var i = 0; i < boxes.length; i++) {
      if (i > 0) children.add(SizedBox(width: gap));
      final b = boxes[i];
      children.add(Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: b['bd'] as Color),
          borderRadius: BorderRadius.circular(r),
        ),
        child: Tx(b['d'], size: fs, w: FontWeight.w700, color: p.ink, tab: true),
      ));
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// Pastdan chiqadigan sheet (dim + panel). Stack ichida Positioned.fill sifatida ishlatiladi.
class SheetShell extends StatelessWidget {
  final VoidCallback onClose;
  final Widget child;
  final bool scroll;
  final double? heightPct; // masalan 0.62
  const SheetShell({super.key, required this.onClose, required this.child, this.scroll = true, this.heightPct});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final handle = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: Container(width: 38, height: 4, decoration: BoxDecoration(color: p.bd, borderRadius: BorderRadius.circular(2))),
      ),
    );
    final panelChild = scroll
        ? SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [child]),
          )
        : child;
    return Positioned.fill(
      // LayoutBuilder: klaviatura ochilganda body qisqaradi — sheet balandligi
      // 0.88*ekran emas, mavjud joydan ham oshmasligi kerak (aks holda overflow).
      child: LayoutBuilder(builder: (context, cons) {
        final maxH = (MediaQuery.of(context).size.height * 0.88).clamp(0.0, cons.maxHeight);
        return Column(
          children: [
            Expanded(child: GestureDetector(onTap: onClose, child: Container(color: p.dim))),
            Container(
              width: double.infinity,
              height: heightPct != null
                  ? (MediaQuery.of(context).size.height * heightPct!).clamp(0.0, cons.maxHeight)
                  : null,
              constraints: BoxConstraints(maxHeight: maxH),
              decoration: BoxDecoration(
                color: p.bg,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
              ),
              padding: const EdgeInsets.only(top: 10),
              child: heightPct != null
                  ? Column(children: [handle, Expanded(child: panelChild)])
                  : Column(mainAxisSize: MainAxisSize.min, children: [handle, Flexible(child: panelChild)]),
            ),
          ],
        );
      }),
    );
  }
}

/// Kichik sarlavha (SUMMA, TURI ...)
class Cap extends StatelessWidget {
  final String text;
  final double ls;
  const Cap(this.text, {super.key, this.ls = 1.4});

  @override
  Widget build(BuildContext context) =>
      Tx(text, size: 11, w: FontWeight.w600, color: curPal().t2, ls: ls);
}

/// Asosiy qora tugma
class InkBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double h;
  final double fs;
  const InkBtn({super.key, required this.label, required this.onTap, this.h = 50, this.fs = 15});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Tap(
      onTap: onTap,
      child: Container(
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(12)),
        child: Tx(label, size: fs, w: FontWeight.w600, color: p.bg),
      ),
    );
  }
}

/// Konturli tugma
class GhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double h;
  final double fs;
  final double r;
  const GhostBtn({super.key, required this.label, required this.onTap, this.h = 50, this.fs = 15, this.r = 12});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Tap(
      onTap: onTap,
      child: Container(
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(r)),
        child: Tx(label, size: fs, w: FontWeight.w600, color: p.ink),
      ),
    );
  }
}

/// Toast (pastda markazda)
class ToastView extends StatelessWidget {
  final bool open;
  final String text;
  const ToastView({super.key, required this.open, required this.text});

  @override
  Widget build(BuildContext context) {
    if (!open) return const SizedBox.shrink();
    final p = curPal();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 104,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 18),
            decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(20)),
            child: Tx(text, size: 12.5, w: FontWeight.w500, color: p.bg),
          ),
        ),
      ),
    );
  }
}

/// Skeleton blok. wf — kenglik ulushi (0..1), w — px.
class Skel extends StatelessWidget {
  final double? w;
  final double? wf;
  final double h;
  final double r;
  const Skel({super.key, this.w, this.wf, required this.h, this.r = 6});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: curPal().card2, borderRadius: BorderRadius.circular(r)),
    );
    if (wf != null) return FractionallySizedBox(widthFactor: wf, alignment: Alignment.centerLeft, child: box);
    return box;
  }
}

/// Store bilan sinxron TextField (tashqi o'zgarishda kursorni saqlab yangilaydi).
class StoreField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final TextStyle? style;
  final Color? hintColor;
  final TextInputType? keyboardType;
  final VoidCallback? onSubmit;
  final TextAlign textAlign;
  final bool autofocus;
  const StoreField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.style,
    this.hintColor,
    this.keyboardType,
    this.onSubmit,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
  });

  @override
  State<StoreField> createState() => _StoreFieldState();
}

class _StoreFieldState extends State<StoreField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant StoreField old) {
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
    final st = widget.style ?? GoogleFonts.inter(fontSize: 14, color: p.ink);
    return TextField(
      controller: _c,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmit != null ? (_) => widget.onSubmit!() : null,
      keyboardType: widget.keyboardType,
      textAlign: widget.textAlign,
      autofocus: widget.autofocus,
      style: st,
      cursorColor: p.ink,
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        border: InputBorder.none,
        hintText: widget.hint,
        hintStyle: st.copyWith(color: widget.hintColor ?? p.t5),
      ),
    );
  }
}

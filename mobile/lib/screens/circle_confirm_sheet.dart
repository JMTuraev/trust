// Qabulni tasdiqlash sheet — prototip frame 7 bilan 1:1.
// Ikki marta bosishdan himoya (_busy); to'liq yig'ilmagan bo'lsa ogohlantirish qatori.
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../circles_data.dart';
import '../circle_ui.dart';
import '../circles_l10n.dart';

class CircleConfirmSheet extends StatefulWidget {
  const CircleConfirmSheet({super.key});

  @override
  State<CircleConfirmSheet> createState() => _CircleConfirmSheetState();
}

class _CircleConfirmSheetState extends State<CircleConfirmSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final c = circlesRepo.byId(v['circleId'] as String?);
    if (c == null) return const SizedBox.shrink();
    // Oluvchi to'lamaydi: to'liq yig'ilgan holat = a'zolar soni - 1
    final payers = c.members.length - 1;
    final partial = c.paidCount < payers;

    return SheetShell(
      onClose: () => v['closeCircleConfirm'](),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Tx(cf('confirmTitle'), size: 16.5, w: FontWeight.w600, color: p.ink),
          const SizedBox(height: 4),
          Tx(cf('paySub', {'name': c.name, 'a': '${c.currentRound.index}', 'b': '${c.roundsTotal}'}),
              size: 12.5, color: p.t2),
          const SizedBox(height: 18),
          Tx(money(c.pool, c.currency), size: 34, w: FontWeight.w700, color: p.green, ls: -0.8, align: TextAlign.center),
          const SizedBox(height: 4),
          Tx(cf('fromAll', {'n': '${c.members.length}'}), size: 12, color: p.t2, align: TextAlign.center),
          if (partial) ...[
            const SizedBox(height: 4),
            // Hali hamma to'lamagan — tasdiqlash faqat to'laganlarni dalil qiladi
            Tx(cf('confirmPaidSoFar', {'n': '${c.paidCount}', 'm': '${c.members.length}'}),
                size: 11.5, w: FontWeight.w600, color: p.red, align: TextAlign.center),
          ],
          const SizedBox(height: 16),
          ProofBanner(cf('confirmBanner'), margin: EdgeInsets.zero),
          const SizedBox(height: 14),
          Opacity(
            opacity: _busy ? 0.55 : 1,
            child: CircleBtn(
              label: _busy ? '…' : cf('confirmReceiptOf', {'amt': money(c.pool, c.currency)}),
              onTap: () {
                if (_busy) return;
                setState(() => _busy = true);
                v['circleConfirmReceipt']();
              },
            ),
          ),
          CircleLink(label: cf('notYet'), onTap: () => v['closeCircleConfirm']()),
        ],
      ),
    );
  }
}

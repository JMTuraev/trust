// To'lov sheet — prototip frame 6 bilan 1:1. Ikki marta bosishdan himoya (_busy).
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../circles_data.dart';
import '../circle_ui.dart';
import '../circles_l10n.dart';

class CirclePaySheet extends StatefulWidget {
  const CirclePaySheet({super.key});

  @override
  State<CirclePaySheet> createState() => _CirclePaySheetState();
}

class _CirclePaySheetState extends State<CirclePaySheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final c = circlesRepo.byId(v['circleId'] as String?);
    if (c == null) return const SizedBox.shrink();
    final rec = c.currentRecipient;

    return SheetShell(
      onClose: () => v['closeCirclePay'](),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Tx(cf('payTitle'), size: 16.5, w: FontWeight.w600, color: p.ink),
          const SizedBox(height: 4),
          Tx(cf('paySub', {'name': c.name, 'a': '${c.currentRound.index}', 'b': '${c.roundsTotal}'}),
              size: 12.5, color: p.t2),
          const SizedBox(height: 18),
          Tx(money(c.amount, c.currency), size: 34, w: FontWeight.w700, color: p.ink, ls: -0.8, align: TextAlign.center),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CAvatar(initials: rec?.initials ?? '', size: 22, tint: rec?.tint ?? Tint.warm),
              const SizedBox(width: 8),
              Flexible(child: Tx(cf('toRecipient', {'name': rec?.name ?? ''}), size: 12.5, color: p.t1, maxLines: 1, ellipsis: true)),
            ],
          ),
          const SizedBox(height: 16),
          ProofBanner(cf('payBanner', {'name': firstName(rec?.name ?? '')}), margin: EdgeInsets.zero),
          const SizedBox(height: 14),
          Opacity(
            opacity: _busy ? 0.55 : 1,
            child: CircleBtn(
              label: _busy ? '…' : cf('confirmPayment', {'amt': money(c.amount, c.currency)}),
              onTap: () {
                if (_busy) return;
                setState(() => _busy = true);
                v['circleMarkPaid']();
              },
            ),
          ),
          CircleLink(label: cf('cancel'), onTap: () => v['closeCirclePay']()),
        ],
      ),
    );
  }
}

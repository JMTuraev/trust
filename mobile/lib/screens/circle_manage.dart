// Circle boshqaruvi — real (egasi nomni tahrirlaydi, doirani yopadi).
// Yopish — tasdiq dialogi bilan (dalilli doira soft-close bo'ladi, server hal qiladi).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';
import '../circles_data.dart';
import '../circle_ui.dart';
import '../circles_l10n.dart';

class CircleManageScreen extends StatelessWidget {
  const CircleManageScreen({super.key});

  void _rename(BuildContext context, String current, Map<String, dynamic> v) {
    final p = curPal();
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Tx(cf('name'), size: 16, w: FontWeight.w600, color: p.ink),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          cursorColor: p.ink,
          style: GoogleFonts.inter(fontSize: 15, color: p.ink),
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Tx(cf('cancel'), size: 14, color: p.t2)),
          TextButton(
            onPressed: () {
              final nm = ctrl.text.trim();
              Navigator.pop(ctx);
              if (nm.isNotEmpty) v['circleManageRename'](nm);
            },
            child: Tx(cf('save'), size: 14, w: FontWeight.w600, color: p.ink),
          ),
        ],
      ),
    );
  }

  // Yopish — halokatli amal: avval tasdiq so'raladi
  void _confirmClose(BuildContext context, Map<String, dynamic> v) {
    final p = curPal();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Tx(cf('closeConfirmTitle'), size: 16, w: FontWeight.w600, color: p.ink),
        content: Tx(cf('closeConfirmBody'), size: 13.5, color: p.t1, lh: 19),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Tx(cf('cancel'), size: 14, color: p.t2)),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              v['circleCloseAction']();
            },
            child: Tx(cf('closeConfirmBtn'), size: 14, w: FontWeight.w600, color: p.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final c = circlesRepo.byId(v['circleId'] as String?);
    if (c == null) return const SizedBox.shrink();

    final orderLabel = switch (c.payoutOrder) {
      PayoutOrder.random => cf('random'),
      PayoutOrder.iPick => cf('iPick'),
      PayoutOrder.inTurn => cf('inTurn'),
    };

    return Column(
      children: [
        CircleHeader(
          leading: BackBtn(onTap: () => v['closeCircleManage']()),
          title: cf('manage'),
          trailing: Tx(c.name, size: 11.5, color: p.t3),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 4),
            children: [
              CircleSettingRow(
                label: cf('name'),
                value: c.name,
                onTap: c.isOwner ? () => _rename(context, c.name, v) : null,
              ),
              CircleSettingRow(label: cf('contribution'), value: cf('contributionMonth', {'amt': money(c.amount, c.currency)})),
              CircleSettingRow(label: cf('payoutOrder'), value: orderLabel),
              CircleSettingRow(label: cf('membersLabel'), value: cf('people', {'n': '${c.members.length}'})),
              CircleSettingRow(label: cf('reminders'), value: cf('remindersVal')),
              ProofBanner(cf('manageNote'), margin: const EdgeInsets.fromLTRB(20, 10, 20, 10)),
            ],
          ),
        ),
        if (c.isOwner && c.status == CircleStatus.active)
          CircleSettingRow(
            label: cf('closeCircle'),
            danger: true,
            hairBorder: true,
            onTap: () => _confirmClose(context, v),
          ),
      ],
    );
  }
}

// Dalil (receipt) ekrani — DESIGN_SPEC §5.10 ("dark glass + gradient").
// ScreenHeader("Dalil") · GlassCard r24 (gradient blur dog' bilan): QULFLANGAN YOZUV ·
// yozuv kodi 22/600 · summa 36/600 mint · 2 ustunli grid · izoh ·
// GradientBtn(ios_share) "Ulashish (PDF)" · GlassBtn "O'zgartirish so'rovi" · "Arxivlash".
// Callback'lar: receipt['close'/'share'/'change'/'archive'] — o'zgarmagan.
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final p = curPal();
    final receipt = (v['receipt'] as Map).cast<String, dynamic>();

    Widget cell(String label, String value, {Color? valueColor, IconData? icon}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Tx(label, size: 13, color: p.t3),
          const SizedBox(height: 3),
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 15, color: valueColor ?? p.ink), const SizedBox(width: 4)],
            // Ism/sana — sig'masa 2 qatorga o'raladi ("..." bilan kesilmaydi)
            Expanded(child: Tx(value, size: 14, w: FontWeight.w600, color: valueColor ?? p.ink, maxLines: 2)),
          ]),
        ],
      );
    }

    final divider = Container(height: 1, color: p.hairline, margin: const EdgeInsets.symmetric(vertical: 16));

    return Column(
      children: [
        ScreenHeader(
          title: L0['receiptTitle'] as String,
          onBack: () => receipt['close'](),
          trailing: [Tx(receipt['id'] as String, size: 12, color: p.t3, tab: true)],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 20, Tb.padX, 32),
            children: [
              GlassCard(
                r: Tb.rCard,
                child: Stack(
                  children: [
                    // O'ng-yuqorida 160px gradient blur dog' (25%)
                    Positioned(
                      top: -50,
                      right: -50,
                      child: IgnorePointer(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                          child: Opacity(
                            opacity: .25,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: const BoxDecoration(gradient: Tb.brandDiag, shape: BoxShape.circle),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.lock_outline_rounded, size: 16, color: p.cyan),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Tx(L0['lockedCap'] as String, size: 13, w: FontWeight.w700, color: p.cyan, ls: 1, font: TbFont.body, maxLines: 1, ellipsis: true),
                            ),
                            if (receipt['corrected'] == true) ...[
                              const SizedBox(width: 8),
                              PillBadge.amber(L0['correctedBadge'] as String, h: 20),
                            ],
                          ]),
                          const SizedBox(height: 14),
                          Tx(receipt['id'] as String, size: 22, w: FontWeight.w600, color: p.ink, tab: true, ls: 1),
                          const SizedBox(height: 10),
                          // Summa hech qachon kesilmaydi — sig'masa kichrayadi
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Tx(receipt['amount'] as String, size: 36, w: FontWeight.w600, color: p.mint, ls: -0.5, tab: true),
                          ),
                          const SizedBox(height: 4),
                          Tx(receipt['type'] as String, size: 14, color: p.t1),
                          if (receipt['editPending'] == true) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: p.amber.withValues(alpha: .10),
                                border: Border.all(color: p.amber.withValues(alpha: .30)),
                                borderRadius: BorderRadius.circular(Tb.rIcon),
                              ),
                              child: Tx(store.Lf('editPending', {'info': '${receipt['editLine']}'}), size: 13, color: p.t1),
                            ),
                          ],
                          divider,
                          // 2 ustunli grid: Kimdan / Kimga · Sana / Holat
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: cell(L0['from'] as String, receipt['from'] as String)),
                            const SizedBox(width: 12),
                            Expanded(child: cell(L0['to'] as String, receipt['to'] as String)),
                          ]),
                          const SizedBox(height: 14),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: cell(L0['date'] as String, receipt['date'] as String)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: cell(L0['lblStatus'] as String, L0['ledgerEntryKept'] as String,
                                  valueColor: p.mint, icon: Icons.verified_user_outlined),
                            ),
                          ]),
                          if (receipt['corrected'] == true) ...[
                            divider,
                            Cap(L0['capHistory'] as String),
                            for (final h in (receipt['histRows'] as List).cast<Map<String, dynamic>>())
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Tx(h['txt'] as String, size: 13, color: p.t1),
                              ),
                          ],
                          divider,
                          Tx(L0['receiptNote'] as String, size: 13, color: p.t3, lh: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GradientBtn(label: L0['share'] as String, icon: Icons.ios_share_rounded, onTap: () => receipt['share']()),
              const SizedBox(height: 10),
              GlassBtn(label: L0['changeReq'] as String, icon: Icons.edit_outlined, onTap: () => receipt['change'](), h: 52),
              const SizedBox(height: 6),
              TextBtn(label: L0['archive'] as String, onTap: () => receipt['archive'](), color: p.t2),
            ],
          ),
        ),
      ],
    );
  }
}

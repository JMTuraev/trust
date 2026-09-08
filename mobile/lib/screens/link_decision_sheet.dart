// Bog'lanish qarori — "X sizni kontragent qilib qo'shgan".
// Qaror qilishdan oldin faqat minimal ma'lumot: kim, nechta yozuv, umumiy summa.
// Rad etish oldidan oddiy tasdiq dialogi (xato bosishdan himoya).
// Dizayn: DESIGN_SPEC "dark glass + gradient" (SheetShell · RingAvatar · GlassCard · GradientBtn/GlassBtn).
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class LinkDecisionSheet extends StatelessWidget {
  const LinkDecisionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final p = curPal();
    final ld = (v['ld'] as Map).cast<String, dynamic>();
    if (ld.isEmpty) return const SizedBox.shrink();

    return SheetShell(
      onClose: () => v['closeLinkDecision'](),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: RingAvatar(initials: ld['initials'], size: 72, ring: 3, seed: '${ld['name']}')),
          const SizedBox(height: 14),
          Tx(store.Lf('addedYouAsParty', {'name': '${ld['sellerLabel']}'}),
              size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head, align: TextAlign.center),
          const SizedBox(height: 8),
          Tx(L0['linkAcceptSub'] as String, size: 14, color: p.t2, lh: 20, align: TextAlign.center),
          const SizedBox(height: 18),
          GlassCard(
            r: Tb.rRow,
            pad: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Cap(L0['capRecords'] as String),
                      const SizedBox(height: 4),
                      Tx(ld['opsCount'], size: 16, w: FontWeight.w600, color: p.ink, tab: true, align: TextAlign.center),
                    ],
                  ),
                ),
                Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 16), color: p.hairline),
                Expanded(
                  child: Column(
                    children: [
                      Cap(L0['capTotal'] as String),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Tx(ld['total'], size: 16, w: FontWeight.w600, color: ld['totalColor'], tab: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GradientBtn(
            label: L0['accept'] as String,
            icon: Icons.check_rounded,
            onTap: () => ld['accept'](),
            loading: v['busy'] == 'link:accept',
          ),
          const SizedBox(height: 10),
          GlassBtn(
            label: L0['btnReject'] as String,
            h: 48,
            loading: v['busy'] == 'link:reject',
            onTap: () async {
              // Xato bosishdan himoya: bitta oddiy tasdiq (parol emas)
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: p.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tb.rCard)),
                  title: Tx(L0['rejectConfirmTitle'] as String, size: 18, w: FontWeight.w600, color: p.ink),
                  content: Tx(L0['rejectConfirmBody'] as String, size: 14, color: p.t2, lh: 20),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Tx(L0['btnCancelShort'] as String, size: 14, w: FontWeight.w600, color: p.t2)),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Tx(L0['btnReject'] as String, size: 14, w: FontWeight.w600, color: p.coral)),
                  ],
                ),
              );
              if (ok == true) ld['reject']();
            },
          ),
        ],
      ),
    );
  }
}

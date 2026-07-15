// Bog'lanish qarori — "X sizni kontragent qilib qo'shgan".
// Qaror qilishdan oldin faqat minimal ma'lumot: kim, nechta yozuv, umumiy summa.
// Rad etish oldidan oddiy tasdiq dialogi (xato bosishdan himoya).
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';

class LinkDecisionSheet extends StatelessWidget {
  const LinkDecisionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final ld = (v['ld'] as Map).cast<String, dynamic>();
    if (ld.isEmpty) return const SizedBox.shrink();

    return SheetShell(
      onClose: () => v['closeLinkDecision'](),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
            child: Tx(ld['initials'], size: 20, w: FontWeight.w600, color: p.ink),
          ),
          const SizedBox(height: 14),
          Tx("${ld['sellerLabel']} sizni kontragent qilib qo'shgan",
              size: 16, w: FontWeight.w700, color: p.ink, align: TextAlign.center),
          const SizedBox(height: 8),
          Tx("Qabul qilsangiz — uning yozuvlari va balans ochiladi. Rad etsangiz — hech narsa ko'rinmaydi.",
              size: 12.5, color: p.t2, lh: 19, align: TextAlign.center),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: BoxDecoration(
              border: Border.all(color: p.bd),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    const Cap('YOZUVLAR'),
                    const SizedBox(height: 4),
                    Tx(ld['opsCount'], size: 15, w: FontWeight.w700, color: p.ink),
                  ],
                ),
                Container(width: 1, height: 34, margin: const EdgeInsets.symmetric(horizontal: 22), color: p.bd),
                Column(
                  children: [
                    const Cap('UMUMIY'),
                    const SizedBox(height: 4),
                    Tx(ld['total'], size: 15, w: FontWeight.w700, color: ld['totalColor']),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          InkBtn(label: 'Qabul qilish', h: 50, onTap: () => ld['accept']()),
          const SizedBox(height: 10),
          GhostBtn(
            label: 'Rad etish',
            h: 46,
            onTap: () async {
              // Xato bosishdan himoya: bitta oddiy tasdiq (parol emas)
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: p.bg,
                  title: Tx('Rostdan ham rad etasizmi?', size: 16, w: FontWeight.w700, color: p.ink),
                  content: Tx(
                      "Yozuvlar ko'rinmaydi va balansga kirmaydi. Keyinroq «Rad etilganlar»dan tiklashingiz mumkin.",
                      size: 13, color: p.t2, lh: 19),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Tx('Bekor', size: 14, w: FontWeight.w600, color: p.t2)),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Tx('Rad etish', size: 14, w: FontWeight.w600, color: p.red)),
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

// Rad etilgan bog'lanishlar — mijoz istalgan payt "Tiklash" bosadi:
// status accepted'ga qaytadi, yozuvlar va balans ochiladi (ma'lumot hech qachon o'chmaydi).
// Dizayn: DESIGN_SPEC "dark glass + gradient" (ScreenHeader · surface qatorlar · RingAvatar · PillChip).
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class RejectedLinksScreen extends StatelessWidget {
  const RejectedLinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final p = curPal();
    final rows = (v['rejRows'] as List).cast<Map<String, dynamic>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(
          title: L0['rejLinksTitle'] as String,
          subtitle: L0['rejLinksSub'] as String,
          onBack: () => v['closeRejected'](),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Tx(L0['rejLinksEmpty'] as String, size: 15, color: p.t3))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 120),
                  children: [
                    for (final r in rows)
                      Container(
                        constraints: const BoxConstraints(minHeight: 76),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(Tb.rRow),
                          border: Border.all(color: p.glassBd),
                        ),
                        child: Row(
                          children: [
                            RingAvatar(initials: r['initials'], size: 48, seed: '${r['name']}', dot: p.coral),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tx(r['name'], size: 16, w: FontWeight.w600, color: p.ink, maxLines: 2),
                                  const SizedBox(height: 3),
                                  // Balans/holat matni to'liq ko'rinsin — 2 qatorgacha o'raladi
                                  Tx(r['sub'], size: 13, color: p.t3, maxLines: 2),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Ichki padding'li shisha pill (PillChip) — qatorda ixcham tugma
                            PillChip(
                              label: L0['btnRestore'] as String,
                              selected: false,
                              onTap: r['restore'],
                              h: 36,
                              leading: Icon(Icons.refresh_rounded, size: 16, color: p.t1),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

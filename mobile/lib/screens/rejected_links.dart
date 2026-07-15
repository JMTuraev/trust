// Rad etilgan bog'lanishlar — mijoz istalgan payt "Tiklash" bosadi:
// status accepted'ga qaytadi, yozuvlar va balans ochiladi (ma'lumot hech qachon o'chmaydi).
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';

class RejectedLinksScreen extends StatelessWidget {
  const RejectedLinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final rows = (v['rejRows'] as List).cast<Map<String, dynamic>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: BackBtn(onTap: () => v['closeRejected']()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
          child: Tx("Rad etilgan bog'lanishlar", size: 22, w: FontWeight.w700, color: p.ink, ls: -0.3),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Tx("Tiklasangiz — yozuvlar va balans qayta ochiladi", size: 12.5, color: p.t3),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Tx("Rad etilgan bog'lanish yo'q", size: 13.5, color: p.t3))
              : ListView(
                  padding: const EdgeInsets.only(top: 6, bottom: 24),
                  children: [
                    for (final r in rows)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
                              child: Tx(r['initials'], size: 14, w: FontWeight.w600, color: p.ink),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Tx(r['name'], size: 14.5, w: FontWeight.w600, color: p.ink),
                                  const SizedBox(height: 3),
                                  Tx(r['sub'], size: 12, color: p.t3, maxLines: 1, ellipsis: true),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Tap(
                              onTap: r['restore'],
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: p.ink,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Tx('Tiklash', size: 12.5, w: FontWeight.w600, color: p.bg),
                              ),
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

// O'zgartirishni tasdiqlash (ikkinchi tomon) — prototip 1501–1534 qatorlar bilan 1:1
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final rv = (v['rv'] as Map?) ?? {};
    return Column(
      children: [
        // Sarlavha
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
          child: Row(
            children: [
              BackBtn(onTap: () => v['closeReview']()),
              const SizedBox(width: 10),
              Tx("O'zgartirish so'rovi", size: 16, w: FontWeight.w700, color: p.ink),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
            child: Column(
              children: [
                Container(
                  width: 56, height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
                  child: Tx((rv['initials'] ?? '') as String, size: 17, w: FontWeight.w600, color: p.ink),
                ),
                const SizedBox(height: 14),
                Tx((rv['title'] ?? '') as String, size: 16, w: FontWeight.w600, color: p.ink, lh: 24, align: TextAlign.center),
                const SizedBox(height: 6),
                Tx((rv['sub'] ?? '') as String, size: 12.5, color: p.t3, align: TextAlign.center),
                const SizedBox(height: 24),
                // ESKI / YANGI kartasi
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: p.bd2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Cap('ESKI'),
                              Text(
                                (rv['oldAmt'] ?? '') as String,
                                maxLines: 1,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: p.t3,
                                  decoration: TextDecoration.lineThrough,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Cap('YANGI'),
                              Tx((rv['newAmt'] ?? '') as String, size: 17, w: FontWeight.w700, color: p.ink, tab: true, maxLines: 1),
                            ],
                          ),
                        ),
                        if (rv['hasNote'] == true)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 13),
                            child: Tx('Izoh: ${rv['newNote']}', size: 12.5, color: p.t3),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Tx(
                  "Tasdiqlasangiz yozuv yangilanadi, eski qiymat tarixda saqlanadi. Rad etsangiz asl yozuv o'zgarishsiz qoladi.",
                  size: 11.5, color: p.t4, lh: 18.4, align: TextAlign.center,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      InkBtn(label: 'Tasdiqlash', onTap: () => v['approveEdit']()),
                      const SizedBox(height: 10),
                      GhostBtn(label: 'Rad etish', onTap: () => v['rejectEdit']()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

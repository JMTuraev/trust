// PDF dalil (hujjat) — prototip 1402–1480 qatorlar bilan 1:1.
// Hujjat ranglari qat'iy (temaga bog'liq emas) — qog'oz doim oq.
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';

// Qat'iy hujjat ranglari
const _paper = Color(0xFFFFFFFF);
const _cardBd = Color(0xFFE2E2DE);
const _gray = Color(0xFF9C9C98);
const _dark = Color(0xFF111111);
const _mid = Color(0xFF7A7A76);
const _lightC = Color(0xFFB0B0AC);
const _hairF = Color(0xFFECECEC);
const _hair2F = Color(0xFFF2F2F0);
const _stamp = Color(0xFF8A8A86);
const _stampRing = Color(0xFFC9C9C5);

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({super.key});

  Widget _party(String label, String name, String phone) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _hair2F))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Tx(label, size: 11.5, color: _gray),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Tx(name, size: 12.5, w: FontWeight.w600, color: _dark, maxLines: 1),
              const SizedBox(height: 2),
              Tx(phone, size: 11, color: _gray, tab: true, maxLines: 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _confRow(String label, Widget value, double mt) {
    return Padding(
      padding: EdgeInsets.only(top: mt),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Tx(label, size: 12, color: _gray), value],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final p = curPal();
    final pdf = (v['pdf'] as Map?) ?? {};
    return Column(
      children: [
        // Sarlavha
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border(bottom: BorderSide(color: p.hair2)),
          ),
          child: Row(
            children: [
              BackBtn(onTap: () => v['closePdf']()),
              const SizedBox(width: 10),
              Tx(L0['pdfProofTitle'] as String, size: 16, w: FontWeight.w700, color: p.ink),
              const Spacer(),
              Tx((pdf['docId'] ?? '') as String, size: 11, color: p.t3, tab: true, maxLines: 1),
            ],
          ),
        ),
        // Hujjat
        Expanded(
          child: Container(
            color: p.field,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                  decoration: BoxDecoration(
                    color: _paper,
                    border: Border.all(color: _cardBd),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(color: Color(0x14000000), offset: Offset(0, 1), blurRadius: 6),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Shtamp
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Transform.rotate(
                          angle: 0.14,
                          child: Container(
                            width: 58, height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _stampRing, width: 1.5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // mini qulf
                                Container(
                                  width: 9, height: 7,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: _stamp, width: 1.5),
                                      top: BorderSide(color: _stamp, width: 1.5),
                                      right: BorderSide(color: _stamp, width: 1.5),
                                    ),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(5), topRight: Radius.circular(5),
                                    ),
                                  ),
                                ),
                                Transform.translate(
                                  offset: const Offset(0, -1),
                                  child: Container(
                                    width: 13, height: 9,
                                    decoration: BoxDecoration(
                                      color: _stamp,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Tx(L0['proofStamp'] as String, size: 6.5, w: FontWeight.w700, color: _stamp, ls: 1.4),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Kontent
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Tx('TRUST', size: 10, w: FontWeight.w600, color: _gray, ls: 2.2),
                          const SizedBox(height: 6),
                          Tx(L0['settlementProof'] as String, size: 17, w: FontWeight.w700, color: _dark, ls: -0.2),
                          const SizedBox(height: 4),
                          Tx(store.Lf('docIdLabel', {'id': '${pdf['docId'] ?? ''}'}), size: 11, color: _gray, tab: true, maxLines: 1),
                          Container(height: 1, color: _hairF, margin: const EdgeInsets.only(top: 16)),
                          _party(L0['from'] as String, (pdf['fromName'] ?? '') as String, (pdf['fromPhone'] ?? '') as String),
                          _party(L0['to'] as String, (pdf['toName'] ?? '') as String, (pdf['toPhone'] ?? '') as String),
                          // SUMMA
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(top: 18, bottom: 14),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _hair2F))),
                            child: Column(
                              children: [
                                Tx(L0['capAmount'] as String, size: 10.5, w: FontWeight.w600, color: _gray, ls: 1.8),
                                const SizedBox(height: 6),
                                Tx((pdf['amount'] ?? '') as String, size: 28, w: FontWeight.w700, color: _dark, tab: true, maxLines: 1),
                                const SizedBox(height: 4),
                                Tx((pdf['type'] ?? '') as String, size: 12, color: _mid),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Tx(L0['dateTimeLabel'] as String, size: 11.5, color: _gray),
                                Tx((pdf['dateTime'] ?? '') as String, size: 12.5, w: FontWeight.w600, color: _dark, maxLines: 1),
                              ],
                            ),
                          ),
                          // Tasdiq bloki
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: _hairF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tx(L0['entryInfoCap'] as String, size: 10.5, w: FontWeight.w600, color: _gray, ls: 1.6),
                                _confRow(L0['createdAt'] as String, Tx((pdf['madeAt'] ?? '') as String, size: 12, w: FontWeight.w600, color: _dark, maxLines: 1), 10),
                              ],
                            ),
                          ),
                          if (pdf['corrected'] == true)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE0E0DC)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Tx(L0['capHistory'] as String, size: 10.5, w: FontWeight.w600, color: _gray, ls: 1.6),
                                  ...((pdf['histRows'] as List?) ?? []).map(
                                    (h) => Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Tx((h['txt'] ?? '') as String, size: 11.5, color: _mid, maxLines: 1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          Tx(
                            L0['pdfFooter'] as String,
                            size: 10.5, color: _lightC, lh: 16.8,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Pastki tugmalar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border(top: BorderSide(color: p.hair2)),
          ),
          child: Column(
            children: [
              InkBtn(label: L0['pdfDownloadBtn'] as String, onTap: () => v['pdfDownload']()),
              const SizedBox(height: 10),
              GhostBtn(label: L0['share'] as String, onTap: () => v['pdfShare'](), h: 46, fs: 14),
            ],
          ),
        ),
      ],
    );
  }
}

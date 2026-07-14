// Android push (lock screen) demo — prototype/template.html 1536–1561 bilan 1:1
// Ranglar tema o'zgarmaydi — qulf ekrani doim qorong'i.
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';

class PushDemo extends StatelessWidget {
  const PushDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    const bgC = Color(0xFF0A0A0C);
    const fgC = Color(0xFFF5F5F5);

    return Container(
      color: bgC,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: v['closePush'],
            ),
          ),
          Column(
            children: [
              // Soat
              const IgnorePointer(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Tx('9:41', size: 56, w: FontWeight.w300, color: fgC, ls: -1),
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Tx('Yakshanba, 12-iyul', size: 13, color: Color(0x99F5F5F5)),
                      ),
                    ],
                  ),
                ),
              ),
              // Push kartochka
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 36, 14, 0),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: fgC,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Tx('T', size: 10, w: FontWeight.w700, color: bgC),
                        ),
                        const SizedBox(width: 8),
                        const Tx('Trust · hozir', size: 11.5, color: Color(0x99F5F5F5)),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Tx("Akmal Karimov sizdan tasdiq so'rayapti", size: 14, w: FontWeight.w600, color: fgC),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Tx("500 000 so'm · Kod: 48215", size: 13, color: Color(0xBFF5F5F5)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Tap(
                              onTap: v['pushView'],
                              child: Container(
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0x40F5F5F5)),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Tx("Ko'rish", size: 12.5, w: FontWeight.w600, color: fgC),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Tap(
                              onTap: v['pushConfirmBtn'],
                              child: Container(
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: fgC,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Tx('Tasdiqlash', size: 12.5, w: FontWeight.w600, color: bgC),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Tx('Yopish uchun istalgan joyga bosing', size: 11, color: Color(0x73F5F5F5)),
                      const SizedBox(height: 10),
                      Container(
                        width: 120,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0x80F5F5F5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

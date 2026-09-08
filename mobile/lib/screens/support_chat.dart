// Yordam chati — foydalanuvchi <-> Trustbook jamoasi (server -> Telegram ko'prigi).
// Xabarlar 4s polling bilan yangilanadi (chat naqshi). Yozish har doim bepul.
// Dizayn: prototype/redesign/DESIGN_SPEC.md §5.18 (AI chati bilan bir xil pufaklar;
// header: 44px gradient doira headset + nom + sub 13 t2; pastki BottomPanel h56).
//
// Store shartnomasi o'zgarmadi: closeSupport, supportItems (mine/body/time),
// supportInput, supportSetInput, supportSend.
import 'package:flutter/material.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';

class SupportChatScreen extends StatelessWidget {
  const SupportChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final items = (v['supportItems'] as List).cast<Map<String, dynamic>>();
    // 2026-08-02 audit: bu ekran yagona TO'LIQ o'zbekcha (tarjimasiz) ekran edi —
    // ruscha/inglizcha interfeysdagi foydalanuvchi aynan muammo haqida yozmoqchi
    // bo'lganda o'zi tushunmaydigan tilga duch kelardi.
    final L0 = store.L();
    return Column(
      children: [
        ScreenHeader(
          title: '${L0['supportTitle'] ?? "Yordam chati"}',
          // TODO l10n: "Trustbook jamoasi · odatda 1 soatda javob beradi"
          subtitle: 'Trustbook jamoasi · odatda 1 soatda javob beradi',
          onBack: () => v['closeSupport'](),
          leading: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Tb.brandDiag, boxShadow: Tb.glow),
            child: const Icon(Icons.headset_mic_rounded, size: 22, color: Colors.white),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Tx(
                      '${L0['supportEmpty'] ?? "Savol, muammo yoki taklifingizni yozing."}',
                      size: 15, color: p.t2, lh: 22, align: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 12),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final m = items[items.length - 1 - i];
                    final mine = m['mine'] == true;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.fromLTRB(16, 11, 16, 10),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          gradient: mine ? Tb.userBubble : null,
                          color: mine ? null : p.glass,
                          border: mine ? null : Border.all(color: p.glassBd),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(mine ? 20 : 8),
                            bottomRight: Radius.circular(mine ? 8 : 20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tx('${m['body']}', size: 15, color: mine ? Colors.white : p.ink, lh: 21),
                            const SizedBox(height: 4),
                            Tx('${m['time']}', size: 11,
                                color: mine ? Colors.white.withValues(alpha: .7) : p.t5, tab: true),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          child: BottomPanel(
            h: 56,
            padding: const EdgeInsets.only(left: 18, right: 6),
            child: Row(
              children: [
                Expanded(
                  child: StoreField(
                    value: '${v['supportInput']}',
                    onChanged: (t) => v['supportSetInput'](t),
                    hint: '${L0['supportHint'] ?? "Xabar yozing..."}',
                    onSubmit: () => v['supportSend'](),
                  ),
                ),
                const SizedBox(width: 8),
                GlassIconBtn(
                  icon: Icons.send_rounded,
                  gradient: true,
                  iconSize: 20,
                  onTap: () => v['supportSend'](),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Yordam chati — foydalanuvchi <-> Trustbook jamoasi (server -> Telegram ko'prigi).
// Xabarlar 4s polling bilan yangilanadi (chat naqshi). Yozish har doim bepul.
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              BackBtn(onTap: () => v['closeSupport']()),
              const SizedBox(width: 10),
              Tx('${L0['supportTitle'] ?? "Yordam chati"}', size: 18, w: FontWeight.w700, color: p.ink),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Tx(
                      '${L0['supportEmpty'] ?? "Savol, muammo yoki taklifingizni yozing."}',
                      size: 13.5, color: p.t3, lh: 20, align: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final m = items[items.length - 1 - i];
                    final mine = m['mine'] == true;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: mine ? p.ink : p.field,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tx('${m['body']}', size: 13.5, color: mine ? p.bg : p.ink),
                            const SizedBox(height: 3),
                            Tx('${m['time']}', size: 10,
                                color: mine ? p.bg.withValues(alpha: .6) : p.t4, tab: true),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair))),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: StoreField(
                    value: '${v['supportInput']}',
                    onChanged: (t) => v['supportSetInput'](t),
                    hint: '${L0['supportHint'] ?? "Xabar yozing..."}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tap(
                onTap: () => v['supportSend'](),
                child: Container(
                  width: 44, height: 44, alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_upward, size: 20, color: p.bg),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

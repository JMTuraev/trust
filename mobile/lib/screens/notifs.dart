// Bildirishnomalar ekrani — dizayn: prototype/redesign/DESIGN_SPEC.md §5.15
// (ScreenHeader + "O'qilgan" cyan TextBtn; GlassCard ro'yxat; qator: 44px
// ikonka-avatar · sarlavha 15/600 + sub 14 t2 · vaqt 12 t4 + o'qilmagan gradient nuqta).
//
// Store shartnomasi o'zgarmadi: closeNotifs, notifUnread, notifReadAll,
// notifEmpty, notifRows (title/detail/time/unread/isReq/isMsg/isOk/isRem/isEdit/isRej/tap).
import 'package:flutter/material.dart';
import '../flags.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class NotifsScreen extends StatelessWidget {
  const NotifsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final p = curPal();
    final rows = (v['notifRows'] as List).cast<Map<String, dynamic>>();

    return Column(
      children: [
        ScreenHeader(
          title: (v['L'] as Map)['profNotif'] as String,
          onBack: v['closeNotifs'],
          trailing: [
            // Barchasini o'qilgan qilish — faqat o'qilmagan bo'lsa
            if ((v['notifUnread'] as int? ?? 0) > 0)
              TextBtn(label: L0['markAllRead'] as String, fs: 14, h: 44, color: p.cyan, onTap: v['notifReadAll']),
          ],
        ),
        // Bo'sh holat
        if (v['notifEmpty'] == true)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassCard(
                      r: 28,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(Icons.notifications_none_rounded, size: 24, color: p.t2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Tx(L0['notifEmptyTitle'] as String, size: 15, w: FontWeight.w600, color: p.t1,
                        align: TextAlign.center),
                    const SizedBox(height: 6),
                    Tx(L0['notifEmptySub'] as String, size: 13, color: p.t4, align: TextAlign.center, lh: 18),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 32),
              children: [
                GlassCard(
                  r: 24,
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) _row(rows[i], p, last: i == rows.length - 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> n, Pal p, {required bool last}) {
    final unread = n['unread'] == true;
    return Tap(
      onTap: n['tap'],
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.hairline))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(n, p),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sarlavha to'liq ko'rinsin — 2 qatorgacha o'raladi
                  Tx('${n['title'] ?? ''}', size: 15, w: FontWeight.w600, color: p.ink, maxLines: 2),
                  const SizedBox(height: 3),
                  Tx('${n['detail'] ?? ''}', size: 14, color: p.t2, lh: 19),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Tx('${n['time'] ?? ''}', size: 12, color: p.t4, maxLines: 1, tab: true),
                ),
                if (unread)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Tb.brandDiag),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 44px dumaloq shisha ikonka-avatar (turi bo'yicha ikonka + urg'u rangi).
  Widget _avatar(Map<String, dynamic> n, Pal p) {
    IconData icon;
    Color color;
    if (n['isMsg'] == true) {
      // Xabar (chat) bildirishnomasi: chat UI yashirin bo'lsa neytral "info" —
      // bosilganda faqat o'qilgan deb belgilanadi (store.dart), hech qayerga olib bormaydi.
      // Chat qaytarilganda (kChatEnabled=true) yana so'rov belgisi ko'rinadi.
      icon = kChatEnabled ? Icons.help_outline_rounded : Icons.info_outline_rounded;
      color = p.t1;
    } else if (n['isReq'] == true) {
      icon = Icons.person_outline_rounded;
      color = p.cyan;
    } else if (n['isOk'] == true) {
      icon = Icons.check_rounded;
      color = p.mint;
    } else if (n['isRem'] == true) {
      icon = Icons.schedule_rounded;
      color = p.amber;
    } else if (n['isEdit'] == true) {
      icon = Icons.edit_outlined;
      color = p.violet;
    } else if (n['isRej'] == true) {
      icon = Icons.close_rounded;
      color = p.coral;
    } else {
      icon = Icons.notifications_none_rounded;
      color = p.t2;
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .15),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

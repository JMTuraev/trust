// Roundlar tarixi — prototip frame 10 bilan 1:1 (vertikal timeline).
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';
import '../circles_data.dart';
import '../circle_ui.dart';
import '../circles_l10n.dart';

class CircleHistoryScreen extends StatelessWidget {
  const CircleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final c = circlesRepo.byId(v['circleId'] as String?);
    if (c == null) return const SizedBox.shrink();
    final len = c.members.length;

    return Column(
      children: [
        CircleHeader(
          leading: BackBtn(onTap: () => v['closeCircleHistory']()),
          title: c.name,
          trailing: Tx(cf('history'), size: 11.5, color: p.t3),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              for (var i = 0; i < c.rounds.length; i++) _tli(c, c.rounds[i], i == 0, len, p),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tli(Circle c, CircleRound r, bool first, int len, Pal p) {
    final rec = c.memberById(r.recipientId);
    final upcoming = r.status == RoundStatus.upcoming;
    final dotColor = r.status == RoundStatus.done
        ? p.green
        : (r.status == RoundStatus.current ? p.ink : p.bd);

    Widget detail;
    if (r.status == RoundStatus.done) {
      // Sana bo'sh bo'lsa " · " dumi qolmasin
      final line = r.dueDate.isEmpty
          ? cf('receivedLine', {'amt': money(c.pool, c.currency), 'date': ''}).replaceAll(RegExp(r'\s*·\s*$'), '')
          : cf('receivedLine', {'amt': money(c.pool, c.currency), 'date': r.dueDate});
      detail = Row(
        children: [
          Flexible(child: Tx('$line · ', size: 11.5, color: p.t3, maxLines: 1, ellipsis: true)),
          Tx('✓ ${cf('confirmedTag')}', size: 11.5, color: p.green),
        ],
      );
    } else if (r.status == RoundStatus.current) {
      detail = Tx(cf('inProgress', {'n': '${c.paidCount}', 'm': '$len'}), size: 11.5, color: p.t3);
    } else {
      detail = Tx(
        r.dueDate.isEmpty ? cf('upcomingNoDate') : cf('upcoming', {'date': r.dueDate}),
        size: 11.5,
        color: p.t3,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: p.hair2))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 3), child: TlDot(color: dotColor)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(cf('roundName', {'n': '${r.index}', 'name': rec?.name ?? ''}),
                    size: 13.5, w: FontWeight.w600, color: upcoming ? p.t2 : p.ink, maxLines: 1, ellipsis: true),
                const SizedBox(height: 2),
                detail,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// LedgerFeedBubble widget testlari — chat-style lenta bubble'lari:
// right = "sent" (card2 tint, pastki-o'ng burchak kichik), left = "received"
// (bg + hairline border, pastki-chap burchak kichik), noma'lum side = full-width.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/screens/client_screen.dart';
import 'package:trust_mobile/theme.dart';

const _feedW = 400.0;

Widget _host(Widget bubble) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: _feedW, child: bubble)),
    );

// Bubble ichidagi dekoratsiyali Container (LedgerFeedBubble descendanti)
Container _bubbleBox(WidgetTester t) => t.widget<Container>(
      find.descendant(of: find.byType(LedgerFeedBubble), matching: find.byType(Container)).first,
    );

void main() {
  final p = pal(false);
  const inner = SizedBox(height: 24, width: double.infinity);

  testWidgets('right side: card2 tint, no border, small bottom-right corner', (t) async {
    await t.pumpWidget(_host(LedgerFeedBubble(side: 'right', pal: p, child: inner)));
    final deco = _bubbleBox(t).decoration as BoxDecoration;
    expect(deco.color, p.card2);
    expect(deco.border, isNull);
    final r = deco.borderRadius as BorderRadius;
    expect(r.bottomRight, const Radius.circular(5));
    expect(r.bottomLeft, const Radius.circular(14));
    expect(r.topLeft, const Radius.circular(14));
  });

  testWidgets('left side: bg + hairline border, small bottom-left corner', (t) async {
    await t.pumpWidget(_host(LedgerFeedBubble(side: 'left', pal: p, child: inner)));
    final deco = _bubbleBox(t).decoration as BoxDecoration;
    expect(deco.color, p.bg);
    expect(deco.border, isNotNull);
    expect((deco.border as Border).top.color, p.hair2);
    final r = deco.borderRadius as BorderRadius;
    expect(r.bottomLeft, const Radius.circular(5));
    expect(r.bottomRight, const Radius.circular(14));
  });

  testWidgets('right side hugs the right edge at 80% of feed width', (t) async {
    await t.pumpWidget(_host(LedgerFeedBubble(side: 'right', pal: p, child: inner)));
    final host = t.getRect(find.byType(SizedBox).first);
    final box = t.getRect(
      find.descendant(of: find.byType(LedgerFeedBubble), matching: find.byType(Container)).first,
    );
    const avail = _feedW - 28; // 14px chetki padding har tomonda
    expect(box.width, moreOrLessEquals(avail * 0.80, epsilon: 0.6));
    expect(host.right - box.right, moreOrLessEquals(14, epsilon: 0.6)); // o'ngga yopishgan
    expect(box.left - host.left, greaterThan(60)); // chapda ochiq joy
  });

  testWidgets('left side hugs the left edge at 80% of feed width', (t) async {
    await t.pumpWidget(_host(LedgerFeedBubble(side: 'left', pal: p, child: inner)));
    final host = t.getRect(find.byType(SizedBox).first);
    final box = t.getRect(
      find.descendant(of: find.byType(LedgerFeedBubble), matching: find.byType(Container)).first,
    );
    const avail = _feedW - 28;
    expect(box.width, moreOrLessEquals(avail * 0.80, epsilon: 0.6));
    expect(box.left - host.left, moreOrLessEquals(14, epsilon: 0.6));
  });

  testWidgets('interactive width override (up to ~92%) is respected', (t) async {
    await t.pumpWidget(
        _host(LedgerFeedBubble(side: 'right', pal: p, widthFactor: 0.92, child: inner)));
    final box = t.getRect(
      find.descendant(of: find.byType(LedgerFeedBubble), matching: find.byType(Container)).first,
    );
    expect(box.width, moreOrLessEquals((_feedW - 28) * 0.92, epsilon: 0.6));
  });

  testWidgets('unknown side: legacy full-width received look (safe fallback)', (t) async {
    await t.pumpWidget(_host(LedgerFeedBubble(side: '', pal: p, child: inner)));
    final box = t.getRect(
      find.descendant(of: find.byType(LedgerFeedBubble), matching: find.byType(Container)).first,
    );
    expect(box.width, moreOrLessEquals(_feedW - 28, epsilon: 0.6));
    final deco = _bubbleBox(t).decoration as BoxDecoration;
    expect(deco.color, p.bg);
    expect(deco.border, isNotNull);
    final r = deco.borderRadius as BorderRadius;
    expect(r.bottomLeft, const Radius.circular(14)); // burchaklar simmetrik
    expect(r.bottomRight, const Radius.circular(14));
  });

  testWidgets('tap fires onTap', (t) async {
    var tapped = 0;
    await t.pumpWidget(_host(
        LedgerFeedBubble(side: 'right', pal: p, onTap: () => tapped++, child: inner)));
    await t.tap(find.byType(LedgerFeedBubble));
    await t.pumpAndSettle();
    expect(tapped, 1);
  });
}

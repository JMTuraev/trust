// LedgerFeedBubble widget testlari — chat-style lenta bubble'lari
// (DESIGN_SPEC §5.8, "dark glass + gradient"):
// right = "men berdim" (mint 10% fon + mint 25% chegara, pastki-o'ng burchak 8),
// left = "u berdi" (coral 8% + coral 20%, pastki-chap burchak 8),
// tone 'glass' (qaytarish) = glass2 + glassBd, noma'lum side = full-width glass.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/screens/client_screen.dart';
import 'package:trust_mobile/theme.dart';

const _feedW = 400.0;
// Chetki padding har tomonda 16 (dizayn: lenta px16)
const _pad = 16.0;

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

  testWidgets('right side: mint tint + mint border, small bottom-right corner', (t) async {
    await t.pumpWidget(_host(LedgerFeedBubble(side: 'right', pal: p, child: inner)));
    final deco = _bubbleBox(t).decoration as BoxDecoration;
    expect(deco.color, p.mint.withValues(alpha: .10));
    expect(deco.border, isNotNull);
    expect((deco.border as Border).top.color, p.mint.withValues(alpha: .25));
    final r = deco.borderRadius as BorderRadius;
    expect(r.bottomRight, const Radius.circular(8));
    expect(r.bottomLeft, const Radius.circular(Tb.rRow));
    expect(r.topLeft, const Radius.circular(Tb.rRow));
  });

  testWidgets('left side: coral tint + coral border, small bottom-left corner', (t) async {
    await t.pumpWidget(_host(LedgerFeedBubble(side: 'left', pal: p, child: inner)));
    final deco = _bubbleBox(t).decoration as BoxDecoration;
    expect(deco.color, p.coral.withValues(alpha: .08));
    expect(deco.border, isNotNull);
    expect((deco.border as Border).top.color, p.coral.withValues(alpha: .20));
    final r = deco.borderRadius as BorderRadius;
    expect(r.bottomLeft, const Radius.circular(8));
    expect(r.bottomRight, const Radius.circular(Tb.rRow));
  });

  testWidgets('glass tone (qaytarish) on the right: glass2 fill + glassBd border', (t) async {
    await t.pumpWidget(_host(LedgerFeedBubble(side: 'right', pal: p, tone: 'glass', child: inner)));
    final deco = _bubbleBox(t).decoration as BoxDecoration;
    expect(deco.color, p.glass2);
    expect((deco.border as Border).top.color, p.glassBd);
    final r = deco.borderRadius as BorderRadius;
    expect(r.bottomRight, const Radius.circular(8)); // tomon saqlanadi
  });

  testWidgets('right side hugs the right edge at 80% of feed width', (t) async {
    await t.pumpWidget(_host(LedgerFeedBubble(side: 'right', pal: p, child: inner)));
    final host = t.getRect(find.byType(SizedBox).first);
    final box = t.getRect(
      find.descendant(of: find.byType(LedgerFeedBubble), matching: find.byType(Container)).first,
    );
    const avail = _feedW - 2 * _pad;
    expect(box.width, moreOrLessEquals(avail * 0.80, epsilon: 0.6));
    expect(host.right - box.right, moreOrLessEquals(_pad, epsilon: 0.6)); // o'ngga yopishgan
    expect(box.left - host.left, greaterThan(60)); // chapda ochiq joy
  });

  testWidgets('left side hugs the left edge at 80% of feed width', (t) async {
    await t.pumpWidget(_host(LedgerFeedBubble(side: 'left', pal: p, child: inner)));
    final host = t.getRect(find.byType(SizedBox).first);
    final box = t.getRect(
      find.descendant(of: find.byType(LedgerFeedBubble), matching: find.byType(Container)).first,
    );
    const avail = _feedW - 2 * _pad;
    expect(box.width, moreOrLessEquals(avail * 0.80, epsilon: 0.6));
    expect(box.left - host.left, moreOrLessEquals(_pad, epsilon: 0.6));
  });

  testWidgets('interactive width override (up to ~92%) is respected', (t) async {
    await t.pumpWidget(
        _host(LedgerFeedBubble(side: 'right', pal: p, widthFactor: 0.92, child: inner)));
    final box = t.getRect(
      find.descendant(of: find.byType(LedgerFeedBubble), matching: find.byType(Container)).first,
    );
    expect(box.width, moreOrLessEquals((_feedW - 2 * _pad) * 0.92, epsilon: 0.6));
  });

  testWidgets('unknown side: full-width glass look (safe fallback)', (t) async {
    await t.pumpWidget(_host(LedgerFeedBubble(side: '', pal: p, child: inner)));
    final box = t.getRect(
      find.descendant(of: find.byType(LedgerFeedBubble), matching: find.byType(Container)).first,
    );
    expect(box.width, moreOrLessEquals(_feedW - 2 * _pad, epsilon: 0.6));
    final deco = _bubbleBox(t).decoration as BoxDecoration;
    expect(deco.color, p.glass2);
    expect(deco.border, isNotNull);
    final r = deco.borderRadius as BorderRadius;
    expect(r.bottomLeft, const Radius.circular(Tb.rRow)); // burchaklar simmetrik
    expect(r.bottomRight, const Radius.circular(Tb.rRow));
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

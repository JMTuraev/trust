// Partner-card notification badges — pure logic (store.dart top-level fns):
//   partnerInTrust   — «in Trust» badge derivation incl. counterparty_deleted
//   notifBadgeText   — count caption with the «9+» cap
//   mapNotifCounts   — GET /api/notifications/counts payload -> internal shape
//   bumpNotifCounts  — optimistic +1 on a foreground FCM push (no mutation)
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/store.dart';

void main() {
  group('partnerInTrust («in Trust» badge derivation)', () {
    test('registered counterparty -> badge on', () {
      expect(partnerInTrust({'counterparty_id': 'u1'}), isTrue);
      expect(partnerInTrust({'counterparty_id': 'u1', 'counterparty_deleted': false}), isTrue);
      // old backend rows without the field keep the badge (null != true)
      expect(partnerInTrust({'counterparty_id': 'u1', 'counterparty_deleted': null}), isTrue);
    });

    test('counterparty deleted the account -> badge drops', () {
      expect(partnerInTrust({'counterparty_id': 'u1', 'counterparty_deleted': true}), isFalse);
    });

    test('not registered -> badge off', () {
      expect(partnerInTrust({'counterparty_id': null}), isFalse);
      expect(partnerInTrust({}), isFalse);
      // deleted flag alone never turns the badge ON
      expect(partnerInTrust({'counterparty_deleted': false}), isFalse);
    });
  });

  group('notifBadgeText (display cap)', () {
    test('1..9 as-is, above 9 -> «9+»', () {
      expect(notifBadgeText(0), '0');
      expect(notifBadgeText(1), '1');
      expect(notifBadgeText(9), '9');
      expect(notifBadgeText(10), '9+');
      expect(notifBadgeText(137), '9+');
    });
  });

  group('mapNotifCounts (server payload -> internal shape)', () {
    test('maps count/total_amount/last_amounts, coerces strings', () {
      final m = mapNotifCounts({
        'p1': {'count': 2, 'total_amount': 75000, 'last_amounts': [50000, 25000]},
        'p2': {'count': '3', 'total_amount': '900', 'last_amounts': ['500', 400]},
      });
      expect(m['p1'], {'count': 2, 'total': 75000, 'last': [50000, 25000]});
      expect(m['p2'], {'count': 3, 'total': 900, 'last': [500, 400]});
    });

    test('zero/negative counts and junk rows are dropped', () {
      final m = mapNotifCounts({
        'p1': {'count': 0, 'total_amount': 0, 'last_amounts': []},
        'p2': 'junk',
        'p3': {'count': 1},
      });
      expect(m.containsKey('p1'), isFalse);
      expect(m.containsKey('p2'), isFalse);
      expect(m['p3'], {'count': 1, 'total': 0, 'last': []});
    });

    // 2026-08-04 contract: rich `last: [{amount, currency}]` preferred over
    // legacy last_amounts; currency resolution server > prev-same-amount > UZS.
    test('rich last rows: server currency wins (even over a prev FCM cur)', () {
      final m = mapNotifCounts({
        'p1': {
          'count': 2, 'total_amount': 300,
          'last': [{'amount': 200, 'currency': 'EUR'}, {'amount': 100, 'currency': 'UZS'}],
          'last_amounts': [999], // legacy field ignored when `last` present
        },
      }, prev: {
        'p1': {'count': 1, 'total': 200, 'last': [200], 'cur': 'USD'},
      });
      expect(m['p1'], {'count': 2, 'total': 300, 'last': [200, 100], 'cur': 'EUR'});
    });

    test('null server currency + no prev -> no cur key (chip falls back to UZS)', () {
      final m = mapNotifCounts({
        'p1': {'count': 1, 'total_amount': 500, 'last': [{'amount': 500, 'currency': null}]},
      });
      expect(m['p1'], {'count': 1, 'total': 500, 'last': [500]});
      expect((m['p1'] as Map).containsKey('cur'), isFalse);
    });

    test('null server currency keeps prev cur for the same partner+newest amount', () {
      final m = mapNotifCounts({
        'p1': {'count': 1, 'total_amount': 500, 'last': [{'amount': 500, 'currency': null}]},
      }, prev: {
        'p1': {'count': 1, 'total': 500, 'last': [500], 'cur': 'USD'}, // FCM bump carried it
      });
      expect(m['p1'], {'count': 1, 'total': 500, 'last': [500], 'cur': 'USD'});
    });

    test('null server currency + different newest amount -> prev cur dropped', () {
      final m = mapNotifCounts({
        'p1': {'count': 2, 'total_amount': 800, 'last': [{'amount': 300}, {'amount': 500}]},
      }, prev: {
        'p1': {'count': 1, 'total': 500, 'last': [500], 'cur': 'USD'},
      });
      expect(m['p1'], {'count': 2, 'total': 800, 'last': [300, 500]});
      expect((m['p1'] as Map).containsKey('cur'), isFalse);
    });

    test('legacy response without `last` still works (numbers-only last_amounts)', () {
      final m = mapNotifCounts({
        'p1': {'count': 2, 'total_amount': 75000, 'last_amounts': [50000, 25000]},
      }, prev: {
        'p1': {'count': 1, 'total': 50000, 'last': [50000], 'cur': 'USD'},
      });
      // newest amount unchanged -> bump currency survives the legacy shape too
      expect(m['p1'], {'count': 2, 'total': 75000, 'last': [50000, 25000], 'cur': 'USD'});
    });
  });

  group('bumpNotifCounts (foreground push, optimistic)', () {
    test('first event for a partner: count 1, amount remembered newest-first', () {
      final out = bumpNotifCounts({}, 'p1', amount: 50000, currency: 'UZS');
      expect(out['p1'], {'count': 1, 'total': 50000, 'last': [50000], 'cur': 'UZS'});
    });

    test('existing counters bump; last stays newest-first and capped at 3', () {
      final before = {
        'p1': {'count': 3, 'total': 6000, 'last': [3000, 2000, 1000], 'cur': 'UZS'},
      };
      final out = bumpNotifCounts(before, 'p1', amount: 4000);
      expect(out['p1'], {
        'count': 4, 'total': 10000,
        'last': [4000, 3000, 2000], // 1000 pushed out by the cap
        'cur': 'UZS', // currency survives an amount-only push
      });
    });

    test('amount-less push bumps the count but not total/last', () {
      final out = bumpNotifCounts({
        'p1': {'count': 1, 'total': 500, 'last': [500]},
      }, 'p1');
      expect(out['p1'], {'count': 2, 'total': 500, 'last': [500]});
    });

    test('input map is not mutated (reset stays a pure remove)', () {
      final before = {
        'p1': {'count': 1, 'total': 100, 'last': [100]},
      };
      final out = bumpNotifCounts(before, 'p2', amount: 42);
      expect(before.keys.toList(), ['p1']);
      expect(before['p1'], {'count': 1, 'total': 100, 'last': [100]});
      expect(out.keys.toSet(), {'p1', 'p2'});
      // reset = removing the partner key from a copy — the original is intact
      final reset = Map<String, Map<String, dynamic>>.from(out)..remove('p2');
      expect(reset.containsKey('p2'), isFalse);
      expect(out.containsKey('p2'), isTrue);
    });

    test('other partners are untouched by a bump', () {
      final out = bumpNotifCounts({
        'p1': {'count': 2, 'total': 0, 'last': []},
      }, 'p2', amount: 7);
      expect(out['p1'], {'count': 2, 'total': 0, 'last': []});
      expect(out['p2'], {'count': 1, 'total': 7, 'last': [7]});
    });
  });
}

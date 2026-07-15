// VAQTINCHA PREVIEW — UI smoke-test uchun soxta ma'lumotli kirish nuqtasi.
// Ishlatish: flutter run -t lib/main_preview.dart  (git'ga qo'shilmaydi, keyin o'chiriladi)
import 'package:flutter/material.dart';
import 'main.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now().millisecondsSinceEpoch;
  store.S.addAll({
    'stage': 'app',
    'meId': 'me1', 'meName': 'Jafar Turaev', 'mePhone': '998901234567',
    'clients': [
      {'id': 'c1', 'name': 'Aziz Karimov', 'phone': '+998 90 111 22 33', 'linkStatus': 'accepted', 'onTrust': true, 'archived': false},
      {'id': 'c2', 'name': 'Malika Yusupova', 'phone': '+998 91 222 33 44', 'linkStatus': 'pending', 'onTrust': false, 'archived': false},
      {'id': 'c3', 'name': 'Bobur Saidov', 'phone': '+998 93 333 44 55', 'linkStatus': 'accepted', 'onTrust': true, 'archived': false},
      {'id': 'c4', 'name': 'Dilnoza Rahimova', 'phone': '+998 94 444 55 66', 'linkStatus': 'accepted', 'onTrust': true, 'archived': true},
    ],
    'txs': [
      {'id': 't1', 'c': 'c1', 'type': 'Qarz berdim', 'a': 2500000, 'cur': 'UZS', 'st': 'ok', 'date': '12-iyl', 'by': 'me', 'note': '', 'ts': now - 3 * 86400000},
      {'id': 't2', 'c': 'c1', 'type': "To'lov oldim", 'a': 1000000, 'cur': 'UZS', 'st': 'ok', 'date': '14-iyl', 'by': 'them', 'note': '', 'ts': now - 86400000},
      {'id': 't3', 'c': 'c2', 'type': 'Qarz oldim', 'a': 500000, 'cur': 'UZS', 'st': 'ok', 'date': '10-iyl', 'by': 'me', 'note': '', 'ts': now - 5 * 86400000},
    ],
    'msgs': {
      'c1': [
        {'k': 'sys', 'text': '12-iyl, 2026'},
        {'k': 'tx', 'tx': 't1'},
        {'k': 'text', 'mine': false, 'text': "Assalomu alaykum! To'lovning yarmini ertaga o'tkazaman", 'time': '14:02', 'read': true},
        {'k': 'text', 'mine': true, 'text': 'Yaxshi, kelishdik 👍', 'time': '14:05', 'read': true},
        {'k': 'tx', 'tx': 't2'},
      ],
    },
  });
  runApp(const TrustApp());
}

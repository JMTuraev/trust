import 'package:intl/intl.dart';

final _nf = NumberFormat('#,##0', 'ru');
String money(num v) => _nf.format(v.abs()).replaceAll(' ', ' ').replaceAll(',', ' ');
String sumTxt(num v, {bool sign = false}) {
  final s = money(v);
  if (!sign) return '$s so’m';
  if (v > 0) return '+$s';
  if (v < 0) return '−$s';
  return s;
}

class Partner {
  final String id, name, initials, sub;
  final num balance; // + sizga qarzdor, - qarzingiz
  final bool onTrust;
  final String phone;
  final int ops;
  const Partner(this.id, this.name, this.initials, this.sub, this.balance,
      this.onTrust, this.phone, this.ops);
}

const partners = <Partner>[
  Partner('1', 'Akmal Karimov', 'AK', 'Oxirgi: bugun 14:20', 1250000, true, '+998 90 123 45 67', 24),
  Partner('2', 'Dilnoza Yusupova', 'DY', 'Oxirgi: kecha', -430000, true, '+998 93 555 22 11', 12),
  Partner('3', 'Sardor Aliyev', 'SA', 'Oxirgi: 12-iyul', 780000, true, '+998 91 700 10 20', 31),
  Partner('4', 'Malika Rashidova', 'MR', 'Tasdiqsiz yozuvlar', 200000, false, '+998 94 321 00 55', 5),
  Partner('5', 'Jamshid Toshpo’lat', 'JT', 'Oxirgi: 8-iyul', -1500000, true, '+998 97 003 44 44', 18),
];

class ChatMsg {
  final bool income;
  final num amount;
  final String cat, note, time;
  const ChatMsg(this.income, this.amount, this.cat, this.note, this.time);
}

const chatDemo = <ChatMsg>[
  ChatMsg(true, 500000, 'SAVDO', 'Mol savdosi uchun', '14:20'),
  ChatMsg(false, 120000, 'TRANSPORT', 'Yetkazib berish', '11:05'),
  ChatMsg(true, 300000, 'QARZ QAYTARISH', '', 'Kecha 18:30'),
  ChatMsg(false, 75000, 'BOSHQA', 'Qadoqlash', 'Kecha 09:10'),
];

class NotifItem {
  final String title, sub, time;
  final bool pending;
  const NotifItem(this.title, this.sub, this.time, this.pending);
}

const notifs = <NotifItem>[
  NotifItem('Akmal Karimov tasdiq so’radi', '+500 000 so’m · Mol savdosi', '5 daqiqa oldin', true),
  NotifItem('Dilnoza Yusupova yozuvni tasdiqladi', '−120 000 so’m', '1 soat oldin', false),
  NotifItem('Sardor Aliyev o’zgartirish so’radi', '780 000 → 760 000', 'Kecha', true),
];

import 'package:intl/intl.dart';

final _nf = NumberFormat('#,##0', 'en');
String money(num v) => _nf.format(v.abs()).replaceAll(',', ' ');
String signed(num v) {
  final s = money(v);
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
  String get balSub => balance >= 0 ? 'sizga qarzdor' : 'qarzingiz';
}

const partners = <Partner>[
  Partner('1', 'Akmal Karimov', 'AK', 'Oxirgi: bugun 14:20', 1250000, true, '+998 90 123 45 67', 24),
  Partner('2', 'Dilnoza Yusupova', 'DY', 'Oxirgi: kecha', -430000, true, '+998 93 555 22 11', 12),
  Partner('3', 'Sardor Aliyev', 'SA', 'Oxirgi: 12-iyul', 780000, true, '+998 91 700 10 20', 31),
  Partner('4', 'Malika Rashidova', 'MR', 'Tasdiqsiz yozuvlar', 200000, false, '+998 94 321 00 55', 5),
  Partner('5', 'Jamshid Toshpo’lat', 'JT', 'Oxirgi: 8-iyul', -1500000, true, '+998 97 003 44 44', 18),
];

const archived = <Partner>[
  Partner('a1', 'Botir Ergashev', 'BE', 'Arxivda', 0, true, '+998 90 000 00 00', 8),
];

/// Client chat elementlari
enum CKind { text, tx, code, sys, voice }
class CItem {
  final CKind kind;
  final bool mine;
  final String text, time;
  // tx
  final bool income;
  final num amount;
  final String txType, status; // status: 'done','pending','mine'
  const CItem(this.kind, {this.mine = true, this.text = '', this.time = '',
      this.income = true, this.amount = 0, this.txType = '', this.status = ''});
}

const clientChat = <CItem>[
  CItem(CKind.sys, text: 'Trust orqali bog’landingiz'),
  CItem(CKind.text, mine: false, text: 'Assalomu alaykum, hisobni ochamiz', time: '14:10'),
  CItem(CKind.tx, income: true, amount: 500000, txType: 'Qarz berdim', status: 'done', time: '14:20'),
  CItem(CKind.text, mine: true, text: 'Tasdiqladingizmi?', time: '14:23'),
  CItem(CKind.tx, income: false, amount: 120000, txType: 'Qaytardim', status: 'pending', time: '11:05'),
  CItem(CKind.code, mine: false, text: '48291', time: 'Kecha 18:30'),
  CItem(CKind.voice, mine: true, text: '0:07', time: 'Kecha 09:10'),
];

class Op {
  final bool income;
  final num amount;
  final String type, date, status; // status: 'Tasdiqlangan','Kutilmoqda'
  const Op(this.income, this.amount, this.type, this.date, this.status);
}
const clientOps = <Op>[
  Op(true, 500000, 'Qarz berdim', 'Bugun 14:20', 'Tasdiqlangan'),
  Op(false, 120000, 'Qaytardim', 'Kecha 11:05', 'Tasdiqlangan'),
  Op(true, 300000, 'Qarz berdim', '12-iyul', 'Kutilmoqda'),
  Op(false, 75000, 'Qaytardim', '8-iyul', 'Tasdiqlangan'),
];

/// Xarajat chat (o'zi bilan)
class XItem {
  final bool sep;
  final String label; // separator kun nomi
  final num dayIn, dayOut;
  final bool income;
  final num amount;
  final String cat, note, time;
  const XItem.separator(this.label, this.dayIn, this.dayOut)
      : sep = true, income = true, amount = 0, cat = '', note = '', time = '';
  const XItem.bubble(this.income, this.amount, this.cat, this.note, this.time)
      : sep = false, label = '', dayIn = 0, dayOut = 0;
}
const xChat = <XItem>[
  XItem.separator('Bugun', 800000, 195000),
  XItem.bubble(true, 500000, 'SAVDO', 'Mol savdosi uchun', '14:20'),
  XItem.bubble(false, 120000, 'TRANSPORT', 'Yetkazib berish', '11:05'),
  XItem.separator('Kecha', 300000, 75000),
  XItem.bubble(true, 300000, 'QARZ', '', '18:30'),
  XItem.bubble(false, 75000, 'QADOQLASH', 'Qadoqlash', '09:10'),
];

class Cat {
  final String name; final num amt; final double w;
  const Cat(this.name, this.amt, this.w);
}
const xCats = <Cat>[
  Cat('Transport', 620000, 1.0),
  Cat('Savdo', 480000, 0.77),
  Cat('Qadoqlash', 210000, 0.34),
  Cat('Boshqa', 90000, 0.15),
];

enum NType { req, ok, rem, edit, rej }
class Notif {
  final NType type;
  final String title, detail, time;
  final bool unread;
  const Notif(this.type, this.title, this.detail, this.time, this.unread);
}
const notifs = <Notif>[
  Notif(NType.req, 'Akmal Karimov tasdiq so’radi', '+500 000 so’m · Mol savdosi uchun', '5 daq', true),
  Notif(NType.ok, 'Dilnoza Yusupova tasdiqladi', '−120 000 so’m yozuvi dalil bo’ldi', '1 soat', true),
  Notif(NType.edit, 'Sardor Aliyev o’zgartirish so’radi', '780 000 → 760 000 so’m', 'Kecha', false),
  Notif(NType.rem, 'Eslatma', 'Jamshid bilan hisob-kitob muddati bugun', 'Kecha', false),
  Notif(NType.rej, 'O’zgartirish rad etildi', 'Malika so’rovingizni rad etdi', '2 kun', false),
];

class Country {
  final String flag, name, dial;
  const Country(this.flag, this.name, this.dial);
}
const countries = <Country>[
  Country('🇺🇿', 'O’zbekiston', '+998'),
  Country('🇷🇺', 'Rossiya', '+7'),
  Country('🇰🇿', 'Qozog’iston', '+7'),
  Country('🇰🇬', 'Qirg’iziston', '+996'),
  Country('🇹🇯', 'Tojikiston', '+992'),
  Country('🇹🇷', 'Turkiya', '+90'),
  Country('🇺🇸', 'AQSH', '+1'),
  Country('🇦🇪', 'BAA', '+971'),
];

// Trust — prototip logikasining (prototype/logic.js) Flutter/Dart porti.
// Barcha state, hodisalar va hosilaviy qiymatlar (vals) prototip bilan 1:1.
// vals() Map qaytaradi — kalitlar prototip template placeholderlari bilan bir xil.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';
import 'theme.dart';
import 'api.dart';
import 'flags.dart';
import 'secure.dart';
import 'push.dart';
import 'iap.dart';
import 'l10n.dart';
import 'ledger/debt_ledger.dart';
import 'circles_data.dart';
import 'circles_l10n.dart';
import 'ai_blocks.dart' show parseAiBlocks;

// 2026-07-17: ovoz/STT butunlay olib tashlandi — ilova FAQAT MATN (docs/ai-character.md §11).


const List<Map<String, dynamic>> ccList = [
  {'f': '🇺🇿', 'n': "O'zbekiston", 'd': '+998', 'len': 9, 'ph': '90 123 45 67'},
  {'f': '🇷🇺', 'n': 'Rossiya', 'd': '+7', 'len': 10, 'ph': '912 345 67 89'},
  {'f': '🇹🇷', 'n': 'Turkiya', 'd': '+90', 'len': 10, 'ph': '501 234 56 78'},
  {'f': '🇺🇸', 'n': 'AQSH', 'd': '+1', 'len': 10, 'ph': '212 555 0123'},
  {'f': '🇬🇧', 'n': 'Buyuk Britaniya', 'd': '+44', 'len': 10, 'ph': '7911 123 456'},
  {'f': '🇦🇪', 'n': 'BAA', 'd': '+971', 'len': 9, 'ph': '50 123 45 67'},
  {'f': '🇪🇸', 'n': 'Ispaniya', 'd': '+34', 'len': 9, 'ph': '612 345 678'},
  {'f': '🇮🇳', 'n': 'Hindiston', 'd': '+91', 'len': 10, 'ph': '98765 43210'},
  {'f': '🇨🇳', 'n': 'Xitoy', 'd': '+86', 'len': 11, 'ph': '138 0013 8000'},
  {'f': '🇩🇪', 'n': 'Germaniya', 'd': '+49', 'len': 10, 'ph': '1512 345 6789'},
];

// ---------------- Home qidiruv/filtr sof funksiyalari (unit-test: test/home_*) ----------------

/// Qidiruv normalizatsiyasi: kichik harf, apostrof variantlari (’ ʻ ʼ ‘ ` ´ -> ')
/// birxillashadi, o'zbek kirillcha matn lotinga o'giriladi — so'rov qaysi
/// yozuvda bo'lsa ham ism topiladi ("Азиз" ↔ "Aziz", "Ғани" ↔ "G'ani").
String searchNorm(String s) {
  var t = s.toLowerCase();
  t = t.replaceAll(RegExp('[‘’ʻʼ`´]'), "'");
  if (!RegExp(r'[Ѐ-ӿ]').hasMatch(t)) return t;
  const cyr = {
    // Digraflar / o'zbekcha maxsus harflar
    'ш': 'sh', 'ч': 'ch', 'ё': 'yo', 'ю': 'yu', 'я': 'ya', 'ц': 'ts', 'щ': 'sh',
    'ў': "o'", 'ғ': "g'", 'қ': 'q', 'ҳ': 'h',
    // Yakka harflar
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ж': 'j',
    'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n',
    'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f',
    'х': 'x', 'ъ': "'", 'ь': '', 'э': 'e',
  };
  final b = StringBuffer();
  for (final ch in t.split('')) {
    b.write(cyr[ch] ?? ch);
  }
  return b.toString();
}

/// Faqat raqamlar ('+998 90 703-44-44' -> '998907034444')
String digitsOf(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

/// Hamkor qatori qidiruvga mos keladimi:
/// - ism: searchNorm bilan (apostrof + kirill/lotin bardoshli), qism-satr;
/// - telefon: ikkala tomondan raqam ajratiladi, so'rovda >=3 raqam bo'lsa qism-satr;
/// - summa: so'rov faqat raqam (bo'shliq/nuqta/vergul ajratkichlariga ruxsat)
///   bo'lsa balans raqamlariga qism-satr ("500" -> 1 500 000 mos).
bool partnerMatch(String query,
    {required String name, String phone = '', Iterable<int> amounts = const []}) {
  final q = query.trim();
  if (q.isEmpty) return true;
  if (searchNorm(name).contains(searchNorm(q))) return true;
  final qd = digitsOf(q);
  if (qd.length >= 3 && digitsOf(phone).contains(qd)) return true;
  final numericOnly =
      qd.isNotEmpty && q.replaceAll(RegExp('[\\s.,  ]'), '') == qd;
  if (numericOnly) {
    for (final a in amounts) {
      if ('${a.abs()}'.contains(qd)) return true;
    }
  }
  return false;
}

/// Davr chegaralari — QURILMA-LOKAL vaqtda, [fromMs, toMs): from INKLYUZIV,
/// to EKSKLYUZIV (keyingi kun 00:00 — server .lt(to) ishlatadi, shu sabab
/// kunning oxirgi millisekundi ham qamrab olinadi).
/// Loyihaviy saboq: kun chegarasi hech qachon serverda hisoblanmaydi (±1 kun
/// timezone xatosi). Hafta dushanbadan boshlanadi. 'all' -> [0, 0] (filtr yo'q).
List<int> homePeriodRange(String filter, DateTime now,
    {int customFrom = 0, int customTo = 0}) {
  int startOf(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
  // Exclusive end: next-day 00:00 exactly (no -1ms) — matches the documented
  // [from, to) convention and the server-side `.lt(to)` comparison.
  int endOf(DateTime d) => DateTime(d.year, d.month, d.day + 1).millisecondsSinceEpoch;
  switch (filter) {
    case 'today':
      return [startOf(now), endOf(now)];
    case 'yesterday':
      final y = DateTime(now.year, now.month, now.day - 1);
      return [startOf(y), endOf(y)];
    case 'week':
      final mon = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      return [startOf(mon), endOf(now)];
    case 'month':
      return [DateTime(now.year, now.month, 1).millisecondsSinceEpoch, endOf(now)];
    case 'custom':
      var f = DateTime.fromMillisecondsSinceEpoch(customFrom);
      var t = DateTime.fromMillisecondsSinceEpoch(customTo);
      if (customFrom > customTo) {
        final tmp = f;
        f = t;
        t = tmp;
      }
      return [startOf(f), endOf(t)];
    default:
      return [0, 0];
  }
}

// ------------- Partner-card notification badges (pure, unit-tested) -------------

/// «in Trust» badge: the counterparty is registered (counterparty_id present)
/// AND has not deleted their account. When the counterparty deletes the
/// account the badge drops in near-realtime (falls back to the one-sided look).
bool partnerInTrust(Map<String, dynamic> p) =>
    p['counterparty_id'] != null && p['counterparty_deleted'] != true;

/// Badge caption: 1..9 as-is, anything above shown as «9+».
String notifBadgeText(int count) => count > 9 ? '9+' : '$count';

/// Maps GET /api/notifications/counts payload (body['counts']) to the internal
/// shape: partnerId -> {count, total, last:[newest-first ints], cur?}.
/// `cur` is the currency of the NEWEST amount (the only one the chip renders).
/// Resolution order:
///   1. server `last: [{amount, currency}]` currency wins when non-null;
///   2. null/absent server currency keeps `prev`'s cur when it refers to the
///      same partner + same newest amount (e.g. an FCM bump carried currency);
///   3. otherwise no `cur` key — the chip falls back to UZS at render time.
/// Legacy responses without `last` (numbers-only `last_amounts`) keep working.
/// Zero/negative counts are dropped so the UI never renders an empty badge.
Map<String, Map<String, dynamic>> mapNotifCounts(Map raw, {Map prev = const {}}) {
  int toInt(dynamic v) => v == null ? 0 : (v is num ? v : (num.tryParse('$v') ?? 0)).round();
  final out = <String, Map<String, dynamic>>{};
  raw.forEach((k, v) {
    if (v is! Map) return;
    final count = toInt(v['count']);
    if (count <= 0) return;
    // Rich rows (server, 2026-08-04 contract): last: [{amount, currency}].
    final richRows =
        v['last'] is List ? (v['last'] as List).whereType<Map>().toList() : const <Map>[];
    final List<int> last;
    String? cur;
    if (richRows.isNotEmpty) {
      last = richRows.map((m) => toInt(m['amount'])).toList();
      cur = richRows.first['currency'] as String?;
    } else {
      last = ((v['last_amounts'] as List?) ?? const []).map(toInt).toList();
    }
    if (cur == null) {
      final p = prev['$k'];
      final pl = p is Map ? ((p['last'] as List?) ?? const []) : const [];
      if (p is Map && pl.isNotEmpty && last.isNotEmpty && toInt(pl.first) == last.first) {
        cur = p['cur'] as String?;
      }
    }
    out['$k'] = {
      'count': count,
      'total': toInt(v['total_amount']),
      'last': last,
      if (cur != null) 'cur': cur,
    };
  });
  return out;
}

/// Optimistic +1 for a foreground push (server reconciles on the next poll).
/// The input map is NOT mutated — a fresh copy is returned. `amount` (when the
/// push carries it) is prepended to the newest-first `last` list (capped at 3);
/// `currency` is remembered for formatting the amount chip.
Map<String, Map<String, dynamic>> bumpNotifCounts(Map counts, String partnerId,
    {num? amount, String? currency}) {
  int toInt(dynamic v) => v == null ? 0 : (v is num ? v : (num.tryParse('$v') ?? 0)).round();
  final out = <String, Map<String, dynamic>>{
    for (final e in counts.entries)
      if (e.value is Map) '${e.key}': Map<String, dynamic>.from(e.value as Map),
  };
  final prev = out[partnerId];
  final cur = currency?.isNotEmpty == true ? currency : prev?['cur'] as String?;
  out[partnerId] = {
    'count': toInt(prev?['count']) + 1,
    'total': toInt(prev?['total']) + (amount?.round() ?? 0),
    'last': [
      if (amount != null) amount.round(),
      ...((prev?['last'] as List?) ?? const []).map(toInt),
    ].take(3).toList(),
    if (cur != null) 'cur': cur,
  };
  return out;
}

// ------------- Modul obunalari (per-module subs, pure + unit-tested) -------------

/// Modul standartlari — server javobi YO'Q bo'lsa (eski backend, 404, tarmoq) yoki
/// modul ro'yxatda kelmasa shu qiymatlar ishlaydi. price — USD/oy;
/// soon — hali sotuvda emas (hisoblagich yo'q, faqat "tez orada").
/// Manba: backend kontrakti 2026-08-04 (migration 020).
///
/// PO 2026-08-04: 'ijarachi' va 'toyxona' QURILDI (backend + mobil ekranlar) —
/// ikkalasi ham `soon: false`, ya'ni hub'da oddiy menyu bo'lib ochiladi va
/// paywall'da haqiqiy CTA turadi. Backend katalogi (src/lib/subscription.js:
/// MODULES) ham `soon` bayrog'ini tashladi — shu ikki manba SINXRON qoladi.
/// Obyekt chegaralari: ijarachi — 5 uy, toyxona — 1 to'yxona (paywall'da
/// aytiladi: screens/paywall_sheet.dart, kModCapUnits).
const Map<String, Map<String, dynamic>> kSubModuleDefaults = {
  'xarajat': {'price': 5, 'soon': false},
  'qarz': {'price': 8, 'soon': false},
  'ijarachi': {'price': 13, 'soon': false},
  'toyxona': {'price': 24, 'soon': false},
};

/// Kartalar tartibi — server qanday tartibda yuborsa ham UI barqaror qoladi.
const List<String> kSubModuleOrder = ['xarajat', 'qarz', 'ijarachi', 'toyxona'];

/// Hisoblagichni KO'RSATISH shifti (faqat UI uchun — ma'lumot KLAMP QILINMAYDI).
///
/// NEGA: `mapSubsModules` server `free_limit`ini AYNAN qanday kelsa shunday
/// uzatadi (fabrikatsiya/klamp yo'q — hisoblagich serverning haqiqiy qaroriga
/// mos bo'lishi shart). Ammo PRODUCTION'da render.yaml FREE_DEBT_ENTRIES /
/// FREE_EXPENSE_ENTRIES = "300" (ataylab: Play Billing ulangunicha paywall
/// yo'q), ya'ni chip "7/300" bo'lib ichki test qiymatini oshkor qilardi.
/// KELISHUV: `limit > kSubLimitDisplayMax` bo'lsa UI hisoblagich chipini
/// UMUMAN chizmaydi (qulf mantiqi o'zgarmaydi — u used>=limit bo'yicha).
/// Haqiqiy tarif limitlari bir xonali (bugun 5) — 20 xavfsiz chegara.
///
/// YAGONA MANBA: screens/home_hub.dart'dagi `kModChipMaxLimit` shu qiymatga
/// teng bo'lishi SHART (test/subs_status_test.dart buni tekshiradi) — ikkita
/// mustaqil "shift" bo'lsa chip bir ekranda ko'rinib, boshqasida yo'qoladi.
const int kSubLimitDisplayMax = 20;

/// Modul nomining l10n kaliti (xarid tasdig'i toasti uchun).
///
/// NEGA NUSXA: screens/paywall_sheet.dart'da AYNI shunday `kModNameKey` bor, lekin
/// u EKRAN qatlami va o'zi store.dart'ni import qiladi (kSubModuleDefaults uchun) —
/// store'dan ekranni import qilish bog'liqlik yo'nalishini teskari qilardi va
/// `kModNameKey` nomi ikki kutubxonada to'qnashardi. Shu sabab bu yerda ALOHIDA
/// nom bilan kichik nusxa turadi; yangi modul qo'shilsa IKKALASI ham yangilanadi.
const Map<String, String> kSubModuleNameKey = {
  'xarajat': 'modXarajat',
  'qarz': 'modQarz',
  'ijarachi': 'modIjarachi',
  'toyxona': 'modToyxona',
};

int _subInt(dynamic v) => v is num ? v.toInt() : (num.tryParse('$v')?.toInt() ?? 0);

/// GET /api/subs/status javob TANASINI UI qatorlariga o'giradi (sof funksiya).
/// Qator: {module, active, soon, used, limit, price, product}.
///
/// GRACEFUL: har bir maydon yo'q bo'lishi mumkin. Javob boshqa shaklda bo'lsa
/// (404 HTML, eski backend, 'modules' yo'q) — BO'SH ro'yxat qaytadi va hub
/// hisoblagichsiz/qulfsiz, ya'ni bugungidek ko'rinadi.
/// "Tez orada" modullarda hisoblagich YO'Q — server 0/0 yuboradi, biz ham 0/0.
List<Map<String, dynamic>> mapSubsModules(dynamic raw) {
  if (raw is! Map) return const [];
  final list = raw['modules'];
  if (list is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final m in list) {
    if (m is! Map) continue;
    final name = '${m['module'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    final def = kSubModuleDefaults[name];
    // soon: server aytmasa lokal standartga tayanamiz (2026-08-04'dan barcha
    // modullar ochiq — hech biri "tez orada" emas; mantiq esa joyida qoladi,
    // kelgusi modul qo'shilsa yana kerak bo'ladi)
    final soon = m['soon'] == true || (m['soon'] == null && def?['soon'] == true);
    final pid = '${m['product_id'] ?? ''}'.trim();
    out.add({
      'module': name,
      'active': m['active'] == true,
      'soon': soon,
      'used': soon ? 0 : _subInt(m['used']),
      'limit': soon ? 0 : _subInt(m['free_limit']),
      'price': m['price_usd'] != null ? _subInt(m['price_usd']) : _subInt(def?['price']),
      'product': pid.isNotEmpty ? pid : 'trust_${name}_monthly',
      'until': m['active_until'] is String ? m['active_until'] : null,
    });
  }
  // Ma'lum modullar kelishilgan tartibda, notanishlari oxirida (server yangi
  // modul qo'shsa ham UI yiqilmasin).
  out.sort((a, b) {
    final ia = kSubModuleOrder.indexOf(a['module'] as String);
    final ib = kSubModuleOrder.indexOf(b['module'] as String);
    return (ia < 0 ? kSubModuleOrder.length : ia).compareTo(ib < 0 ? kSubModuleOrder.length : ib);
  });
  return out;
}

// ────────── Modul yakunlari (bosh ekran kartasidagi RAQAM) ──────────
// Ijara va To'yxona kartalari Xarajat/Qarz kabi JONLI summa ko'rsatadi. Raqam
// modul repolarida emas, serverdan keladi: GET /api/<modul>/summary (joriy oy,
// Toshkent vaqti — oraliq YUBORILMAYDI, izoh api.dart'da).
//
// GRACEFUL: bu endpointlar bugungi production'da YO'Q (404). Mapper har qanday
// shaklda (null, HTML, kalitlar yetishmasa) NOLLI xaritani qaytaradi — karta
// tinch nol holatida chiziladi, xato ham, spinner ham YO'Q.

/// Yakun xaritasining nol qiymati — «ma'lumot yo'q» ham shu (count == 0).
const Map<String, int> kHubModZero = {'left': 0, 'count': 0, 'pending': 0};

/// GET /api/ijara/summary -> {left, count, pending} (sof funksiya).
/// left    — oyda YIG'ILISHI KERAK bo'lgan pul (charged − paid); manfiy = avans.
/// count   — bekor qilinmagan hisob-kitoblar (pul yig'indisi AYNAN shularniki).
/// pending — hali to'lanmagan hisob-kitoblar (byStatus.kutilmoqda).
Map<String, int> mapIjaraHubSum(dynamic raw) {
  if (raw is! Map) return kHubModZero;
  final by = raw['byStatus'];
  return {
    'left': _subInt(raw['left']),
    // countActive yo'q bo'lsa count'ga tushamiz (eski/qisqartirilgan javob)
    'count': _subInt(raw['countActive'] ?? raw['count']),
    'pending': by is Map ? _subInt(by['kutilmoqda']) : 0,
  };
}

/// GET /api/toyxona/summary -> {left, count, pending} (sof funksiya).
/// left    — oyda to'lanmagan qoldiq (total − paid).
/// count   — bekor qilinmagan bandlar soni.
/// pending — hali to'liq to'lanmagan bandlar (band + tasdiq); kartada
///           ko'rsatilmaydi, lekin shakl ijara bilan bir xil qolsin.
Map<String, int> mapToyHubSum(dynamic raw) {
  if (raw is! Map) return kHubModZero;
  final by = raw['byStatus'];
  return {
    'left': _subInt(raw['left']),
    'count': _subInt(raw['countActive'] ?? raw['count']),
    'pending': by is Map ? _subInt(by['band']) + _subInt(by['tasdiq']) : 0,
  };
}

/// Eski (butun ilova) premium obunasi faolmi — legacy_premium.active.
bool subsLegacyActive(dynamic raw) =>
    raw is Map && raw['legacy_premium'] is Map && (raw['legacy_premium'] as Map)['active'] == true;

/// Modul xaridi tasdig'i: «Xarajatlar obunasi yoqildi — rahmat!» (sof funksiya).
/// `l` — joriy til xaritasi (store.L()). HIMOYALI: notanish modulda modul kodi
/// ishlatiladi, kalit yo'q bo'lsa Lf singari kalit nomi qaytadi — crash yo'q.
String subModuleThanksText(Map<String, dynamic> l, String module) {
  final k = kSubModuleNameKey[module];
  final v = k == null ? null : l[k];
  final name = v is String && v.isNotEmpty ? v : module;
  return (l['subModuleThanks'] ?? 'subModuleThanks').toString().replaceAll('{module}', name);
}

/// Paywall holati bitta modul uchun: {module, price, soon, used, limit, product}.
/// Modul server ro'yxatida bo'lmasa (masalan "tez orada" modul yoki endpoint yo'q) —
/// lokal standartlardan YASALADI, shunda paywall baribir to'g'ri narx ko'rsatadi.
Map<String, dynamic> subsPaywallEntry(String module, List<Map<String, dynamic>> mods) {
  for (final m in mods) {
    if (m['module'] == module) {
      return {
        'module': module,
        'price': _subInt(m['price']),
        'soon': m['soon'] == true,
        'used': _subInt(m['used']),
        'limit': _subInt(m['limit']),
        'product': '${m['product'] ?? 'trust_${module}_monthly'}',
      };
    }
  }
  final def = kSubModuleDefaults[module];
  return {
    'module': module,
    'price': _subInt(def?['price']),
    'soon': def?['soon'] == true,
    'used': 0,
    'limit': 0,
    'product': 'trust_${module}_monthly',
  };
}

class TrustStore extends ChangeNotifier {
  final Map<String, dynamic> S = {
    // 'boot' — sessiya tekshirilgunicha splash (welcome "miltillab" o'tib ketmasin)
    'stage': 'boot', 'lang': 'uz', 'dark': false, 'phone': '', 'otpVal': '', 'pinVal': '',
    'pinFirst': '', // PIN o'rnatishda birinchi kiritilgan qiymat (re-enter tasdiqlash)
    'pinRet': null, // 'profil' — PIN o'zgartirish profil ichidan boshlangan
    'pinMode': 'set', // 'set' = onboardingda o'rnatish, 'check' = qayta kirishda tekshirish
    'pinErr': false, // noto'g'ri PIN — nuqtalar qizil chaqnaydi
    'xarTab': 'chat', 'xarPeriod': 'oy', 'voiceStage': null, 'vText': '', 'xarText': '',
    'xcCats': <String>[],
    // Xarajatlar v2 — papka (folder) UI holati (dizayn: Xarajatlar Trust.html)
    'xfDetail': null, // ochiq papka nomi
    'xfIncBusy': false, // #15: kirim qo'shilmoqda (spinner)
    'xfIncSub': null, // #15v2: ochiq sub-daromad papkasi ('@dokon'); null = Daromad asosiy
    'xfIncSubsMade': <String>[], // #15v2: yaratilgan sub-papkalar (bo'sh bo'lsa ham ko'rinadi) — SharedPreferences
    'xfDeleting': <String>[], // #35: o'chirilayotgan yozuv idlari (kartada spinner)
    'xfLogOpen': false, 'xfLogDot': false,
    'xfLog': <Map<String, dynamic>>[], // sessiya jurnali: add/edit/del/merge (max 12)
    'xfTray': <Map<String, dynamic>>[], // ANIQLANMAGAN — papka tanlanishi kutilayotgan yozuvlar
    'xfTrayNaming': null, // qo'lda nom yozilayotgan tray qatori id'si
    'xfTrayName': '', // qo'lda nom buferi (TextField onChanged shu yerga yozadi)
    'xfEditing': null, // {id, label} — input orqali tahrirlash rejimi
    'xfConfirm': null, // {kind:'merge'|'delf', from, to} — tasdiqlash kartasi
    'xfToast': null, // {text, kind:'add'|'del', ids|entry} — "Bekor qilish" bilan lokal toast
    'xfNewCats': <String>[], // shu sessiyada yangi ochilgan papkalar ("Yangi ✨")
    // Uchish nishoni: yangi toifa GHOST-kartasi (cat -> kirimmi). Chip uchishidan
    // OLDIN xira karta paydo bo'ladi, qo'nganda haqiqiy yozuv bilan to'ladi.
    'xfGhostCats': <String, bool>{},
    'xfFly': <Map<String, dynamic>>[], // papkaga "uchish" animatsiya hodisalari (UI iste'mol qiladi)
    'xfReorderFrom': null, // qayta-tartib siljishi uchun ESKI tartib (bir martalik, UI iste'mol qiladi)
    'xfPeriod': <String, dynamic>{'kind': 'month'}, // davr filtri: today/yesterday/week/month/all/custom(from,to)
    // Chatdagi yozuvni inline tahrirlash (bubble bosilganda)
    'xEditId': null, 'xEditVals': null,
    'xarLimit': 0, 'limEdit': null,
    'xarEntries': <Map<String, dynamic>>[],
    // 'hub' — ildiz ekran (screens/home_hub.dart). Bo'limlar: home (Hamkorlar),
    // xarajat, ai, profil — hub'dan ochiladi, orqaga hub'ga qaytaradi.
    'screen': 'hub', 'clientId': null, 'tab': 'chat',
    'sheetOpen': false, 'sheetMode': 'client', 'sheetClient': null,
    'receiptId': null, 'search': '', 'chatInput': '', 'toast': '',
    'notifOpen': false, 'archOpen': false, 'langOpen': false,
    'editFormOpen': false, 'editA': '', 'editNote': '', 'pdfOpen': false,
    'playing': null, 'remTimes': <String, int>{},
    'pinOn': true, 'notifOn': true,
    'cMenuOpen': false, 'cRen': null, 'pProfOpen': false,
    'skelHome': false, 'skelOps': false, 'homeVis': 6, 'opsVis': 8,
    'swipeId': null, 'swipeDx': 0.0, 'swipeSnap': null,
    'npOpen': false, 'npName': '', 'npPhone': '',
    'homeLoadingMore': false, 'opsLoadingMore': false,
    // Home davr filtri (header dropdown): 'all'|'today'|'yesterday'|'week'|'month'|'custom'
    'homeFilter': 'all', 'homeFilterFrom': 0, 'homeFilterTo': 0,
    'homeFilterOpen': false,
    // Davr summalari (server): partnerId -> {to_me, by_me, repaid_to_me, repaid_by_me, count}
    'homePeriod': <String, Map<String, int>>{},
    // Server javobida 'period' bor-yo'qligi — eski backend'da false: filtr o'chadi
    // (ro'yxat to'liq, umumiy summalar) — graceful degradation, hech qachon yiqilmaydi.
    'homePeriodOk': false,
    'homePeriodLoading': false,
    'onbCc': '+998', 'npCc': '+998', 'ccOpen': null, 'ccSearch': '',
    'form': <String, dynamic>{'type': 'Qarz berdim', 'amount': '', 'currency': 'UZS', 'note': '', 'name': ''},
    // Real ma'lumotlar serverdan hydrate() orqali yuklanadi
    'clients': <Map<String, dynamic>>[],
    'txs': <Map<String, dynamic>>[],
    'msgs': <String, List<Map<String, dynamic>>>{},
    'localMsgs': <String, List<Map<String, dynamic>>>{},
    // REAL chat (server): xabarlar hamkor bo'yicha + o'qilmagan hisoblagichlar (badge)
    'srvMsgs': <String, List<Map<String, dynamic>>>{},
    'msgUnread': <String, int>{},
    // Partner-card badges: partnerId -> {count, total, last:[newest-first], cur?}
    // (unread debt-event notifications; server counts + FCM optimistic bumps)
    'notifCounts': <String, Map<String, dynamic>>{},
    // Qarz daftari (ledger) — ochiq hamkor yozuvlari (server'dan, DebtEntry ro'yxati)
    'ledgerRows': <Map<String, dynamic>>[],
    'ledgerLoading': false,
    'ledgerError': null, // server xatosi JIM yutilmasin (bo'sh ekran o'rniga xabar)
    // Yordam chati (support -> Telegram ko'prigi)
    'supportOpen': false, 'supportMsgs': <Map<String, dynamic>>[], 'supportInput': '',
    // Input panel: chAct = null|'lend'|'borrow'|'close'; forma maydonlari
    'chAct': null, 'chA': '', 'chCur': 'UZS', 'chDue': '', 'chDate': '', 'chNote': '',
    'chDebt': null, 'chReason': 'returned', // yopish oqimida tanlangan qarz + sabab
    'histId': null, 'histEdit': false, 'eA': '', 'eDue': '', 'eNote': '', // yozuv dialogi/tahrir
    'revAllOpen': false, // "Hammasini tasdiqlash" ogohlantirishi
    // Profil qo'shimchalari
    'meAvatar': null, // lokal rasm yo'li (galereyadan)
    'cur': 'UZS', // asosiy valyuta (yangi yozuv formasi uchun default)
    // Obuna holati (backend /profile/me): 'free' | 'premium'. Server 'trial' qaytarmaydi.
    'subStatus': 'free', 'trialEnd': null, 'premUntil': null,
    'debtsUsed': null, 'expensesUsed': null,
    'freeDebtEntries': null, 'freeExpenseEntries': null,
    // Modul obunalari (GET /api/subs/status). BO'SH = server qo'llamaydi/xato —
    // hub bugungidek (hisoblagichsiz, qulfsiz) ko'rinadi.
    'modSubs': <Map<String, dynamic>>[],
    'modSubsLegacy': false, // eski butun-ilova premiumi faolmi
    // Ijara/To'yxona kartalaridagi summa (GET /api/<modul>/summary). null =
    // hali so'ralmagan yoki server javob bermadi (404) — karta tinch nol
    // holatida: «0 so'm» + modul tavsifi. Shakl: {left, count, pending}.
    'hubIjaraSum': null,
    'hubToySum': null,
    'paywall': null, // {module, price, soon, used, limit, product} yoki null
    'iapBusy': false, // Apple IAP xaridi ketmoqda — paywall CTA spinner/disabled
    'delArmAt': 0, // (eski) profil o'chirish ikki bosqichli tasdiq vaqti — endi ishlatilmaydi
    'delOtpOpen': false, 'delOtpBusy': false, 'delOtpPhone': '', // #34: OTP bilan o'chirish modali
    'notifs': <Map<String, dynamic>>[],
    // Trust AI (moliyaviy hamroh chati — docs/ai-character.md)
    // aiMsgs qatori: {id, role:'user'|'ai', text, blocks:[...], ts, flagged, fresh}
    'aiMsgs': <Map<String, dynamic>>[],
    'aiInput': '', // input maydoni matni
    'aiLoading': false, 'aiLoaded': false, 'aiError': null, // tarix yuklash
    'aiSending': false, // javob kutilmoqda ("yozmoqda…")
    'aiSendErr': null, // oxirgi yuborish xatosi (retry uchun)
    'aiLastText': null, // retry uchun oxirgi savol
    'aiLimited': false, // 429 — savol chegarasi (sabab: aiLimitKind)
    'aiLimitKind': null, // 'day' | 'month' | 'slow' — 429 sababi (xabar shu bo'yicha)
    // Bog'lanishlar (meni kontragent qilib qo'shganlar) — link modeli
    'links': <Map<String, dynamic>>[],
    'linkDecisionId': null, // qaror sheet'i ochiq bog'lanish
    'rejOpen': false, // "Rad etilganlar" ro'yxati
    'inLinkId': null, // ochiq kiruvchi daftar (qabul qilingan bog'lanish)
    'inLinkOps': <Map<String, dynamic>>[], // uning operatsiyalari
    // Auth / sessiya
    'meId': null, 'mePhone': null, 'meName': null, 'meNameEdit': null,
    'meNo': null, // 8 xonali foydalanuvchi ID (profiles.user_no, 016 migratsiya)
    'pMeta': <String, String>{}, // hamkor o'zgarish-imzolari (poll uchun)
    'busy': null, // server javobini kutayotgan tugma kaliti (loading spinner)
  };

  Timer? _tt, _pi, _lp, _poll;
  /// Xarajat "land" zaxira taymeri — logout'da bekor qilinadi (2026-08-02 audit).
  Timer? _landFallback;
  Map<String, dynamic>? _sw;
  bool _swClick = false;
  bool _busy = false;
  bool _hydrating = false;
  final Map<String, bool> _opsSeen = {};

  void set(Map<String, dynamic> patch) {
    S.addAll(patch);
    notifyListeners();
  }

  Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final d = sp.getBool('trust_dark') ?? false;
      final l = sp.getString('trust_lang') ?? 'uz';
      S['dark'] = d;
      S['lang'] = l;
      notifyListeners();
    } catch (_) {}
    // Token muddati o'tsa (401) — istalgan ekrandan markazlashgan logout
    Api.onUnauthorized = _forceLogout;
    // Tarmoq xatolari foydalanuvchi tilida ko'rsatilsin (ilgari har doim o'zbekcha edi,
    // ruscha/inglizcha interfeysda ham — 2026-08-02 audit).
    _syncApiErrStrings();
    // Server yozishni 402 bilan bloklagan = obuna tugagan. Lokal holat darhol
    // 'expired'ga o'tadi — global banner va profil kartasi to'g'ri ko'rinadi
    // (aks holda ilova qayta ochilgunicha eski "trial" holati ko'rsatilardi).
    // MUHIM (2026-08-02 audit): 402 faqat O'ZIMIZNING kvota tugaganda holatni
    // o'zgartiradi. Ilgari qarshi tomon (daftar egasi) kvotasi tugagani uchun kelgan
    // 402 ham "mening obunam tugadi" deb qabul qilinardi va butun ilovada qizil
    // banner yonardi. Server endi kodni ajratadi: SUB_EXPIRED / OWNER_SUB_EXPIRED.
    // 2026-08-04: server 402 bilan birga `module` ham yuboradi (qaysi modul
    // kvotasi tugagan). Bunday holatda GLOBAL "obuna tugadi" bannerini
    // YOQMAYMIZ — bu butun ilova emas, bitta modul to'sig'i: shu modulning
    // paywall'i ochiladi. Modulsiz 402 (eski backend) — avvalgidek.
    Api.onPaymentRequired = (String code, String module) {
      if (code == 'OWNER_SUB_EXPIRED') return; // bu — daftar egasining muammosi
      if (module.isNotEmpty && kModuleSubsUi) {
        openPaywall_(module);
        unawaited(refreshSubs_(force: true)); // used/limit darhol aniqlashsin
        return;
      }
      if (S['subStatus'] != 'expired') set({'subStatus': 'expired'});
      unawaited(refreshMe()); // serverdan aniqlashtirib olamiz (yopishib qolmasin)
    };
    await Api.loadToken();
    _wireIap(); // Apple IAP (iOS) — StoreKit tayyorlash + xarid oqimini kuzatish
    S['pinOn'] = await SecureStore.hasPin(); // toggle holatini secure storage'dan tiklaymiz
    // Valyuta va avatar (lokal saqlanadi)
    try {
      final sp = await SharedPreferences.getInstance();
      S['cur'] = sp.getString('trust_cur') ?? 'UZS';
      S['meAvatar'] = sp.getString('trust_avatar');
      // #15v2: yaratilgan sub-daromad papkalari (bo'sh bo'lsa ham ko'rinadi)
      S['xfIncSubsMade'] = sp.getStringList('trust_inc_subs') ?? <String>[];
    } catch (_) {}
    if (Api.token != null) {
      _tryResume(); // splash ko'rinib turadi — natijaga qarab app/pin/welcome
    } else {
      set({'stage': 'welcome'}); // sessiya yo'q — endi welcome ko'rsatamiz
    }
  }

  // Saqlangan token bilan sessiyani tiklash.
  // MUHIM: 401 (token yaroqsiz) va tarmoq/server xatosi (status 0/5xx) ni AJRATAMIZ —
  // aks holda vaqtinchalik uzilishда yaroqli sessiya "chiqib ketgan" ko'rinardi.
  Future<void> _tryResume() async {
    // PIN o'rnatilgan bo'lsa — ma'lumot fonda yuklanaturib, oldin PIN so'raladi (himoya darvozasi).
    final needPin = await SecureStore.hasPin();
    final prof = await Api.me();
    if (prof.ok && prof.data != null) {
      final p = prof.data as Map<String, dynamic>;
      set({
        'meId': p['id'], 'mePhone': p['phone'], 'meName': p['full_name'],
        'meNo': p['user_no'],
        'notifOn': p['notif_enabled'] != false,
        // Obuna holati: server 'premium' yoki 'free' qaytaradi (trial modeli olib tashlangan)
        'subStatus': p['status'] ?? 'free',
        // Bepul kvota hisobi — serverdan (UI hech narsa hardcode qilmaydi)
        'debtsUsed': ((p['usage'] as Map?)?['debts_used'] as num?)?.toInt(),
        'expensesUsed': ((p['usage'] as Map?)?['expenses_used'] as num?)?.toInt(),
        'freeDebtEntries': ((p['price'] as Map?)?['free_debt_entries'] as num?)?.toInt(),
        'freeExpenseEntries': ((p['price'] as Map?)?['free_expense_entries'] as num?)?.toInt(),
        'trialEnd': p['trial_ends_at'],
        'premUntil': p['premium_until'],
        'stage': needPin ? 'pin' : 'app', 'pinMode': 'check', 'skelHome': true,
      });
      await SecureStore.writeMe(p['id'] as String?, p['phone'] as String?);
      await hydrate();
      set({'skelHome': false});
      _startPolling();
    } else if (prof.status == 401) {
      await Api.saveToken(null); // muddati o'tgan token
      await SecureStore.writeMe(null, null);
      set({'stage': 'welcome'}); // boot splashdan welcome'ga
    } else {
      // Tarmoq/server xatosi (status 0 yoki 5xx): token yaroqli — ilovaga kiritamiz,
      // hydrate keyin qayta urinadi. Foydalanuvchi onboarding'ga tushmaydi.
      // MUHIM (2026-08-02 audit): bu yo'lda ilgari meId UMUMAN o'rnatilmasdi. Natijada
      // '${S['meId']}' -> "null" bo'lib, HAR BIR qarzning yo'nalishi TESKARI ko'rsatilardi
      // ("Aziz menga qarzdor" -> "Men Azizga qarzdorman"). Endi oxirgi kirishda
      // saqlangan qiymat tiklanadi va profil fonda qayta so'raladi.
      final savedId = await SecureStore.readMeId();
      final savedPhone = await SecureStore.readMePhone();
      set({
        if (savedId != null) 'meId': savedId,
        if (savedPhone != null) 'mePhone': savedPhone,
        'stage': needPin ? 'pin' : 'app', 'pinMode': 'check', 'skelHome': true,
      });
      await hydrate();
      set({'skelHome': false});
      _startPolling();
      // Profilni fonda qayta olishga urinamiz (meId hali noma'lum bo'lsa — muhim).
      unawaited(_retryMe());
    }
  }

  /// Profilni fonda qayta olish (tarmoq tiklangach). meId noma'lum bo'lsa —
  /// qarz yo'nalishlari noto'g'ri ko'rinadi, shuning uchun bir necha marta urinamiz.
  Future<void> _retryMe() async {
    for (final delay in [3, 8, 20, 45]) {
      await Future.delayed(Duration(seconds: delay));
      if (S['stage'] != 'app' && S['stage'] != 'pin') return;
      final r = await Api.me();
      if (!r.ok || r.data is! Map) continue;
      final p = r.data as Map<String, dynamic>;
      set({
        'meId': p['id'], 'mePhone': p['phone'], 'meName': p['full_name'],
        'meNo': p['user_no'],
        'notifOn': p['notif_enabled'] != false,
        'subStatus': p['status'] ?? 'free',
        // Bepul kvota hisobi — serverdan (UI hech narsa hardcode qilmaydi)
        'debtsUsed': ((p['usage'] as Map?)?['debts_used'] as num?)?.toInt(),
        'expensesUsed': ((p['usage'] as Map?)?['expenses_used'] as num?)?.toInt(),
        'freeDebtEntries': ((p['price'] as Map?)?['free_debt_entries'] as num?)?.toInt(),
        'freeExpenseEntries': ((p['price'] as Map?)?['free_expense_entries'] as num?)?.toInt(),
        'trialEnd': p['trial_ends_at'],
        'premUntil': p['premium_until'],
      });
      await SecureStore.writeMe(p['id'] as String?, p['phone'] as String?);
      await hydrate();
      return;
    }
  }

  // Markazlashgan logout — 401 (sessiya tugagan) yoki qo'lda chiqishда
  void _forceLogout() {
    // MUHIM (2026-08-02 audit): ilgari faqat stage=='app' da ishlardi. Token kechasi
    // muddati tugab, foydalanuvchi PIN ekranida turgan bo'lsa, 401'lar e'tiborsiz
    // qolardi — u PIN kiritib, BO'M-BO'SH ilovaga tushardi va nima bo'lganini bilmasdi.
    if (S['stage'] != 'app' && S['stage'] != 'pin') return;
    logout_();
    toast_(L()['tSessionEnd']);
  }

  // ---------------- SERVER <-> UI mapping ----------------
  static const _monU = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];
  static const _typeUz = {
    'qarz_berdim': 'Qarz berdim', 'qarz_oldim': 'Qarz oldim',
    'menga_qaytarildi': "To'lov oldim", 'qaytardim': "To'lov berdim",
  };
  static const _typeSrv = {
    'Qarz berdim': 'qarz_berdim', 'Qarz oldim': 'qarz_oldim',
    "To'lov oldim": 'menga_qaytarildi', "To'lov berdim": 'qaytardim',
  };
  // Mijoz nuqtai nazarida tur teskarisi (sotuvchi "Qarz berdim" = mijoz "Qarz oldim")
  static const _typeFlip = {
    'Qarz berdim': 'Qarz oldim', 'Qarz oldim': 'Qarz berdim',
    "To'lov oldim": "To'lov berdim", "To'lov berdim": "To'lov oldim",
  };
  static const _stUz = {'active': 'ok', 'archived': 'arch'};
  static const _notifKind = {
    'rem': 'reminder',
    'link_new': 'linknew', 'link_acc': 'linkacc', 'link_rej': 'linkrej', 'op_new': 'opnew',
    // qarz daftari va chat — bosilganda hamkor daftariga olib boradi (openFromNotif)
    'debt_new': 'debt', 'debt_confirm': 'debt', 'debt_reject': 'debt',
    'repay_new': 'debt', 'settle_new': 'debt', 'edit_req': 'debt', 'review_req': 'debt',
    'msg': 'msg',
    // eski (v2) turlari — tarixiy qatorlar uchun
    'req': 'confirmed', 'ok': 'confirmed', 'edit': 'confirmed', 'rej': 'rejected',
    // circle hodisalari (mavjud ikonkalar bilan xavfsiz render)
    'circle_invite': 'confirmed', 'circle_turn': 'confirmed', 'circle_paid': 'confirmed',
    'circle_confirm': 'confirmed', 'circle_due': 'reminder', 'circle_joined': 'confirmed',
    'circle_closed': 'confirmed',
  };
  // Optimistic-bump filter (pushArrived_) — MUST mirror the server's
  // PARTNER_BADGE_TYPES (src/routes/notifications.js): /api/notifications/counts
  // counts exactly these types, so bumping anything else would flash a badge
  // the next poll removes. Wider than _notifKind's 'debt' bucket: rem/op_new
  // are badge events too (2026-08-04 lead polish round).
  static const Set<String> _badgeTypes = {
    'debt_new', 'debt_confirm', 'debt_reject', 'repay_new', 'settle_new',
    'edit_req', 'review_req', 'rem', 'op_new',
  };

  int _numToInt(dynamic v) => v == null ? 0 : (v is num ? v : (num.tryParse('$v') ?? 0)).round();

  DateTime? _dt(dynamic iso) => iso is String ? DateTime.tryParse(iso)?.toLocal() : null;

  String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// ISO sana -> 'Bugun' | 'Kecha' | '12-iyl'
  String _fmtDateIso(dynamic iso) {
    final d = _dt(iso);
    if (d == null) return '';
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return L()['tToday'] as String;
    if (diff == 1) return L()['tYesterday'] as String;
    return '${d.day}-${_monU[d.month - 1]}';
  }

  /// Bildirishnoma vaqti: 'Hozir' | '15 daqiqa oldin' | 'HH:mm' | 'Kecha' | '12-iyl'
  String _relTime(dynamic iso) {
    final d = _dt(iso);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return L()['tNow'] as String;
    if (diff.inMinutes < 60) return Lf('tMinAgo', {'n': '${diff.inMinutes}'});
    final today = DateTime.now();
    if (d.year == today.year && d.month == today.month && d.day == today.day) return _hhmm(d);
    return _fmtDateIso(iso);
  }

  int _daysAgo(dynamic iso) {
    final d = _dt(iso);
    if (d == null) return 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  }

  /// '998997034444' -> '+998 99 703 44 44'
  String _fmtSrvPhone(String digits) {
    if (digits.isEmpty) return '';
    if (digits.startsWith('998') && digits.length == 12) {
      final d = digits.substring(3);
      return '+998 ${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5, 7)} ${d.substring(7)}';
    }
    return '+$digits';
  }

  Map<String, dynamic> _mapPartner(Map<String, dynamic> p) => {
        'id': p['id'], 'name': p['name'] ?? '',
        'phone': _fmtSrvPhone((p['counterparty_phone'] ?? '') as String),
        // linkStatus: pending | accepted | rejected (rad — signal ketgach ko'rinadi)
        'linkStatus': p['link_status'] ?? 'pending',
        'onTrust': p['link_status'] == 'accepted',
        // «in Trust» badge: registered (counterparty_id present, does not wait
        // for accepted) AND the counterparty has not deleted their account —
        // partnerInTrust (pure, tested). Home rows and the 1:1 header (cInTrust)
        // both derive from this single field.
        'inTrust': partnerInTrust(p),
        'archived': p['archived'] == true,
        'srvBal': (p['balances'] is Map)
            ? (p['balances'] as Map).map((k, v) => MapEntry('$k', _numToInt(v)))
            : <String, int>{},
      };

  /// Menga kelgan bog'lanish (GET /api/links qatori)
  Map<String, dynamic> _mapLink(Map<String, dynamic> l) {
    final alias = (l['my_alias'] as String?)?.trim();
    final sellerName = (l['seller_name'] as String?)?.trim();
    final phone = _fmtSrvPhone((l['seller_phone'] ?? '') as String);
    return {
      'id': l['id'],
      'status': l['status'] ?? 'pending',
      'name': (alias?.isNotEmpty == true ? alias : null) ?? (sellerName?.isNotEmpty == true ? sellerName : null) ?? phone,
      'sellerLabel': l['seller_label'] ?? phone,
      'phone': phone,
      'opsCount': _numToInt(l['ops_count']),
      'total': _numToInt(l['total']), // mijoz nuqtai nazarida: + = sotuvchi menga qarzdor
      'ts': _dt(l['status_changed_at'] ?? l['created_at'])?.millisecondsSinceEpoch ?? 0,
    };
  }

  Map<String, dynamic> _mapOp(Map<String, dynamic> o, {bool flip = false}) {
    final type = _typeUz[o['type']] ?? o['type'];
    return {
      'id': o['id'], 'c': o['partner_id'],
      'type': flip ? (_typeFlip[type] ?? type) : type,
      'a': _numToInt(o['amount']),
      'cur': o['currency'] ?? 'UZS',
      'date': _fmtDateIso(o['created_at']),
      'st': _stUz[o['status']] ?? 'ok',
      'by': o['created_by'] == S['meId'] ? 'me' : 'them',
      'note': o['note'] ?? '',
      'ts': _dt(o['created_at'])?.millisecondsSinceEpoch ?? 0,
    };
  }

  Map<String, dynamic> _mapExpense(Map<String, dynamic> e) => {
        'id': e['id'],
        'kind': e['income'] == true ? 'd' : 'x',
        'cat': (e['category'] as String?) ?? (e['income'] == true ? 'Daromad' : 'Boshqa'),
        'note': e['note'] ?? '',
        'a': _numToInt(e['amount']),
        'days': _daysAgo(e['occurred_at']),
        't': _dt(e['occurred_at']) != null ? _hhmm(_dt(e['occurred_at'])!) : '',
        // Hub «SO'NGGI» tasmasi uchun: xarajat va operatsiyalar bitta vaqt
        // o'qi bo'yicha aralashtiriladi (operatsiyalarda 'ts' allaqachon bor)
        'ts': _dt(e['occurred_at'])?.millisecondsSinceEpoch ?? 0,
        // Papka UI uchun: oy kaliti va oy kuni (sparkline savatlari)
        'ym': _dt(e['occurred_at']) != null
            ? '${_dt(e['occurred_at'])!.year}-${_dt(e['occurred_at'])!.month}'
            : '',
        'dom': _dt(e['occurred_at'])?.day ?? 1,
      };

  Map<String, dynamic> _mapNotif(Map<String, dynamic> n) => {
        'id': n['id'],
        'kind': _notifKind[n['type']] ?? 'confirmed',
        'unread': n['read'] != true,
        'title': n['title'] ?? '',
        'detail': n['detail'] ?? '',
        'time': _relTime(n['created_at']),
        'tx': n['operation_id'],
        'link': n['link_id'],
        'circle': n['circle_id'],
      };

  /// Foydalanuvchi ko'rsatiladigan nomi
  String meLabel() {
    final n = S['meName'];
    if (n is String && n.trim().isNotEmpty) return n.trim();
    return _fmtSrvPhone((S['mePhone'] as String?) ?? '');
  }

  // ---------------- Serverdan yuklash (hydrate) + polling ----------------
  Future<void> hydrate({bool full = true}) async {
    if (_hydrating) return;
    _hydrating = true;
    try {
      // Xarajatlar tanlangan davr bo'yicha tortiladi (polling ham shu davrni
      // saqlaydi — aks holda filtrlangan ro'yxat standart javob bilan yuvilardi)
      final rs = await Future.wait([
        Api.partners(), Api.notifications(), _xfFetchExpenses(), Api.getLimit(), Api.links(),
        Api.notifCounts(),
        // Chat unread counts only while the chat UI exists (kChatEnabled) —
        // with the flag off this request was dead weight on every 15s poll.
        if (kChatEnabled) Api.unreadCounts(),
      ]);
      final pr = rs[0], nr = rs[1], er = rs[2], lr = rs[3], kr = rs[4], cr = rs[5];
      var plist = <Map<String, dynamic>>[];
      final patch = <String, dynamic>{};
      if (pr.ok && pr.data is List) {
        plist = (pr.data as List).cast<Map<String, dynamic>>();
        patch['clients'] = plist.map(_mapPartner).toList();
      }
      // Partner-card notification badges (unread debt events). The partner whose
      // 1:1 ledger is currently open is dropped: openLedger_ marked it read
      // optimistically and the POST may not have landed yet — the badge must
      // not flash back. A failed request keeps the last known counts. `prev`
      // lets the reconcile keep an FCM-bump currency when the server row has
      // none for the same newest amount (see mapNotifCounts).
      if (cr.ok && cr.body['counts'] is Map) {
        patch['notifCounts'] =
            mapNotifCounts(cr.body['counts'] as Map, prev: S['notifCounts'] as Map)
              ..remove(S['clientId'])
              ..remove(S['inLinkId']);
      }
      if (kChatEnabled) {
        // O'qilmagan xabarlar (badge) — hamkor qatorlarida ko'rinadi
        final ur = rs[6];
        if (ur.ok && ur.data is Map) {
          patch['msgUnread'] = (ur.data as Map).map((k, v) => MapEntry('$k', _numToInt(v)));
        }
      }
      if (nr.ok && nr.data is List) {
        patch['notifs'] = (nr.data as List).cast<Map<String, dynamic>>().map(_mapNotif).toList();
      }
      if (er.ok && er.data is List) {
        patch['xarEntries'] = (er.data as List).cast<Map<String, dynamic>>().map(_mapExpense).toList();
      }
      if (lr.ok && lr.data is Map) {
        patch['xarLimit'] = _numToInt((lr.data as Map)['monthly_limit']);
      }
      if (kr.ok && kr.data is List) {
        patch['links'] = (kr.data as List).cast<Map<String, dynamic>>().map(_mapLink).toList();
      }
      if (patch.isNotEmpty) set(patch);

      // Modul obunalari (hisoblagich + qulf) — hub ma'lumoti bilan bir oqimda,
      // lekin ALOHIDA va throttle bilan: bu so'rov yiqilsa hydrate buzilmaydi.
      unawaited(refreshSubs_(force: full));
      // Ijara/To'yxona kartalaridagi summa — AYNAN shu nuqtada va shu qoidalar
      // bilan (60s throttle, jim yiqiladi). Alohida chaqiruv: bu ikki so'rov
      // 404 qaytarsa ham hydrate ham, obuna hisoblagichi ham buzilmaydi.
      unawaited(refreshHubMods_(force: full));

      // Davr filtri faol bo'lsa — summalari ham polling bilan birga yangilanadi
      // (kun almashsa chegaralar qurilma-lokal qayta hisoblanadi)
      if (S['homeFilter'] != 'all') unawaited(loadHomePeriod_());

      // Ochiq kiruvchi daftar bo'lsa — operatsiyalarini yangilab turamiz
      if (S['inLinkId'] != null) _loadLinkOps(S['inLinkId'] as String, silent: true);

      // Operatsiyalar: faqat imzosi o'zgargan hamkorlar uchun qayta yuklanadi
      final meta = Map<String, String>.from(S['pMeta'] as Map);
      final toFetch = <Map<String, dynamic>>[];
      for (final p in plist) {
        final sig = '${p['balance']}|${p['link_status']}|${p['updated_at']}';
        if (full || meta[p['id']] != sig) toFetch.add(p);
        meta[p['id'] as String] = sig;
      }
      if (toFetch.isNotEmpty) {
        final details = await Future.wait(toFetch.map((p) => Api.partnerDetail(p['id'] as String)));
        // MUHIM (2026-08-02 audit): ilgari fetchedIds BARCHA so'ralgan hamkorlarni
        // o'z ichiga olardi, shu sabab so'rovi MUVAFFAQIYATSIZ bo'lgan hamkorning
        // tranzaksiyalari ham `kept` dan chiqarib tashlanardi — ammo msgs[pid] eski
        // id'larga ishora qilib qolardi. Keyingi qayta chizishda `_tx(...)!` null'ga
        // tushib, butun ilova qizil xato ekraniga o'tardi (orqaga qaytib ham bo'lmasdi).
        // Endi faqat MUVAFFAQIYATLI olinganlar almashtiriladi.
        final okIds = <dynamic>{};
        for (var i = 0; i < details.length; i++) {
          if (details[i].ok && details[i].data is Map) okIds.add(toFetch[i]['id']);
        }
        final kept = _txs().where((t) => !okIds.contains(t['c'])).toList();
        final added = <Map<String, dynamic>>[];
        final msgs = Map<String, List<Map<String, dynamic>>>.from(S['msgs']);
        for (var i = 0; i < details.length; i++) {
          if (!details[i].ok || details[i].data is! Map) continue;
          final ops = (((details[i].data as Map)['operations'] as List?) ?? [])
              .cast<Map<String, dynamic>>()
              .where((o) => o['status'] != 'cancelled' && o['status'] != 'disputed')
              .map(_mapOp)
              .toList()
            ..sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));
          added.addAll(ops);
          msgs[toFetch[i]['id'] as String] = ops.map((t) => {'k': 'tx', 'tx': t['id']}).toList();
        }
        final all = [...kept, ...added]..sort((a, b) => ((a['ts'] as int?) ?? 0).compareTo((b['ts'] as int?) ?? 0));
        set({'txs': all, 'msgs': msgs, 'pMeta': meta});
      } else {
        S['pMeta'] = meta;
      }
    } finally {
      _hydrating = false;
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (S['stage'] == 'app') hydrate(full: false);
    });
  }

  // ---------------- Home davr filtri (period) ----------------
  // Yangi so'rov eski javobni bekor qiladi (poyga bardoshi)
  int _periodSeq = 0;

  /// GET /api/partners?period_from=..&period_to=.. — davr summalari bilan.
  /// api.dart (umumiy fayl) tegilmasin deb shu yerda — circles_data._circlesReq
  /// naqshi (auth header, 401 -> markazlashgan logout). Xato jim qaytadi:
  /// loadHomePeriod_ degradatsiyani o'zi boshqaradi.
  Future<ApiRes> _partnersPeriodReq(int from, int to) async {
    try {
      final uri = Uri.parse('$apiUrl/api/partners?period_from=$from&period_to=$to');
      final headers = {
        'Content-Type': 'application/json',
        if (Api.token != null) 'Authorization': 'Bearer ${Api.token}',
      };
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
      Map<String, dynamic> map;
      try {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      } catch (_) {
        map = <String, dynamic>{};
      }
      if (res.statusCode >= 400 || map['success'] == false) {
        if (res.statusCode == 401 && Api.token != null) Api.onUnauthorized?.call();
        return ApiRes(false, null, (map['error'] as String?) ?? 'Server xatosi (${res.statusCode})', res.statusCode);
      }
      return ApiRes(true, map['data'], '', res.statusCode);
    } catch (_) {
      return ApiRes(false, null, '', 0);
    }
  }

  /// Faol filtr uchun davr summalarini yuklaydi. Chegaralar FAQAT qurilma-lokal
  /// hisoblanadi (homePeriodRange). Muvaffaqiyatsiz so'rov yoki 'period'siz javob
  /// (eski backend) -> homePeriodOk=false: ro'yxat TO'LIQ, umumiy summalar qoladi.
  Future<void> loadHomePeriod_() async {
    if (S['homeFilter'] == 'all') return;
    final r = homePeriodRange(S['homeFilter'] as String, DateTime.now(),
        customFrom: S['homeFilterFrom'] as int, customTo: S['homeFilterTo'] as int);
    final seq = ++_periodSeq;
    set({'homePeriodLoading': true});
    final res = await _partnersPeriodReq(r[0], r[1]);
    if (seq != _periodSeq || S['homeFilter'] == 'all') return; // eskirgan javob
    if (!res.ok || res.data is! List) {
      // Transient failure (e.g. network blip during the 15s silent refresh):
      // keep the LAST successful period sums — otherwise the filtered list
      // would jump to the full list mid-scroll. Sums are only cleared when the
      // filter itself changes (setHomeFilter_). First load (homePeriodOk still
      // false) degrades gracefully to the unfiltered list as before.
      set({'homePeriodLoading': false});
      return;
    }
    final rows = (res.data as List).whereType<Map>().toList();
    final per = <String, Map<String, int>>{};
    var has = false;
    for (final p in rows) {
      final pd = p['period'];
      if (pd is Map) {
        has = true;
        per['${p['id']}'] = pd.map((k, v) => MapEntry('$k', _numToInt(v)));
      }
    }
    // Bo'sh ro'yxat -> filtr baribir bo'sh; qatorlar bor-u 'period' yo'q -> eski backend
    set({'homePeriodLoading': false, 'homePeriodOk': rows.isEmpty || has, 'homePeriod': per});
  }

  /// Davr filtri tanlovi ('custom' uchun from/to — epoch ms, qurilma-lokal kunlar)
  void setHomeFilter_(String f, {int from = 0, int to = 0}) {
    _periodSeq++; // uchayotgan eski javob endi qo'llanilmaydi
    set({
      'homeFilter': f, 'homeFilterFrom': from, 'homeFilterTo': to,
      'homeFilterOpen': false,
      'homeVis': 6, // sahifalash boshidan (onSearch bilan bir xil)
      'homePeriod': <String, Map<String, int>>{},
      'homePeriodOk': false,
      'homePeriodLoading': f != 'all',
    });
    if (f != 'all') loadHomePeriod_();
  }

  /// Faol filtr chip yorlig'i ('Shu hafta' / '12.07 – 03.08' ...)
  String fltLabel_(Map<String, dynamic> L0) {
    String dm(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
    }

    return switch (S['homeFilter']) {
      'today' => L0['fltToday'] as String,
      'yesterday' => L0['fltYesterday'] as String,
      'week' => L0['fltWeek'] as String,
      'month' => L0['fltMonth'] as String,
      'custom' => '${dm(S['homeFilterFrom'] as int)} – ${dm(S['homeFilterTo'] as int)}',
      _ => L0['fltAll'] as String,
    };
  }

  /// Home ro'yxati filtri — kuchli qidiruv + faol davr (period.count > 0).
  /// vals() va homeMore sahifalashi BIR XIL manbadan foydalanadi.
  List<Map<String, dynamic>> _homeClients() {
    final q = (S['search'] as String).trim();
    final fActive = S['homeFilter'] != 'all' && S['homePeriodOk'] == true;
    final per = S['homePeriod'] as Map;
    return _clients().where((c) {
      if (c['archived'] == true) return false;
      if (!partnerMatch(q,
          name: (c['name'] ?? '') as String,
          phone: (c['phone'] ?? '') as String,
          amounts: ((c['srvBal'] as Map?)?.values ?? const <dynamic>[]).map(_numToInt))) {
        return false;
      }
      if (fActive) {
        final pd = per[c['id']];
        if (pd is! Map || _numToInt(pd['count']) <= 0) return false;
      }
      return true;
    }).toList();
  }

  /// Ilova fonga o'tganda BARCHA pollinglar to'xtaydi, qaytganda tiklanadi.
  ///
  /// MUHIM (2026-08-02 audit): ilgari ilova fonda ham har 15 soniyada hydrate,
  /// har 3–4 soniyada chat/ledger/support so'rovlarini yuborib turardi. 12 hamkorli
  /// foydalanuvchida bu daqiqasiga ~87 so'rov — serverning /api limiti esa 120/min
  /// (IP bo'yicha). Bir uy/operator NAT ortidagi ikki foydalanuvchi 429 ola boshlardi,
  /// ustiga batareya va mobil trafik behuda sarflanardi.
  void appPaused_() {
    _poll?.cancel();
    _ledgerPoll?.cancel();
    _chatPoll?.cancel();
    _supPoll?.cancel();
  }

  void appResumed_() {
    if (S['stage'] != 'app') return;
    _startPolling();
    hydrate(full: false);
    if (S['supportOpen'] == true) {
      _supPoll?.cancel();
      _supPoll = Timer.periodic(const Duration(seconds: 4), (_) => _supTick());
    }
    final pid = _ledPid();
    if (pid != null) {
      _ledgerPoll?.cancel();
      _ledgerPoll = Timer.periodic(const Duration(seconds: 4), (_) {
        if (S['clientId'] == pid || S['inLinkId'] == pid) {
          _refetchLedger(pid);
        } else {
          _ledgerPoll?.cancel();
        }
      });
    }
  }

  /// verify-otp muvaffaqiyati: token + profil + ma'lumotlar
  Future<void> _loginSuccess(Map<String, dynamic> data) async {
    await Api.saveToken(data['access_token'] as String?);
    final user = (data['user'] as Map?) ?? {};
    S['meId'] = user['id'];
    S['mePhone'] = user['phone'];
    final prof = await Api.me();
    if (prof.ok && prof.data is Map) {
      final p = prof.data as Map;
      S['meName'] = p['full_name'];
      S['meNo'] = p['user_no'];
      S['notifOn'] = p['notif_enabled'] != false;
      // Obuna holati birinchi kirishda ham to'ldirilsin — aks holda profil qatori
      // ilova qayta ochilgunicha "Sinov tugagan" deb NOTO'G'RI ko'rsatadi
      S['subStatus'] = p['status'] ?? 'trial';
      S['trialEnd'] = p['trial_ends_at'];
      S['premUntil'] = p['premium_until'];
    }
    hydrate(); // fonda yuklanadi — foydalanuvchi PIN kiritayotgan payt
    _startPolling();
  }

  /// 8 xonali user ID'ni o'qish oson shaklda: 12345678 -> "1234 5678"
  String _fmtUserNo(String n) => n.length == 8 ? '${n.substring(0, 4)} ${n.substring(4)}' : n;

  /// ISO satrdan mahalliy HH:mm (yordam chati vaqt yorlig'i).
  /// DIQQAT: _hhmm(DateTime) allaqachon mavjud — bu ISO-satr varianti, nomi boshqa.
  String _hhmmIso(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> L() => kLangs[S['lang']] ?? lUz;

  /// Tarjima + {token} almashtirish (interpolatsiyali xabarlar uchun).
  String Lf(String key, Map<String, String> vars) {
    var s = (L()[key] ?? key).toString();
    vars.forEach((k, val) => s = s.replaceAll('{$k}', val));
    return s;
  }

  // Server javobini kutayotgan tugma kaliti (null = hech biri). UI spinner ko'rsatadi.
  void _setBusy(String? key) => set({'busy': key});

  void toast_(String msg) {
    _tt?.cancel();
    set({'toast': msg});
    _tt = Timer(const Duration(milliseconds: 2200), () => set({'toast': ''}));
  }

  void setDark(bool d) {
    SharedPreferences.getInstance().then((sp) => sp.setBool('trust_dark', d));
    set({'dark': d});
  }

  void setLang(String l) {
    SharedPreferences.getInstance().then((sp) => sp.setString('trust_lang', l));
    set({'lang': l});
    _syncApiErrStrings();
  }

  /// Api qatlamidagi tarmoq xatolari matnini joriy tilga moslaydi.
  void _syncApiErrStrings() {
    final l = L();
    Api.errNetwork = l['errNetwork'] as String?;
    Api.errWaking = l['errWaking'] as String?;
  }

  // ================= Obuna xaridi (Apple IAP — iap.dart) =================
  // iOS'da StoreKit orqali $9/oy premium. Android'da IapService "off" (kvota modeli,
  // Play Billing keyin ulanadi). Paywall (profil kartasi) shu metodlarni chaqiradi.
  bool _iapWired = false;
  void _wireIap() {
    if (_iapWired) return;
    _iapWired = true;
    IapService.onBusy = (b) => set({'iapBusy': b});
    IapService.onError = (m) => toast_(m);
    IapService.onPremiumGranted = () async {
      await refreshMe(); // banner/karta darhol "Premium"ga o'tsin
      set({'iapBusy': false});
      toast_(L()['subThanks'] as String? ?? 'Premium yoqildi — rahmat!');
    };
    // Modul obunasi yoqildi — paywall yopiladi, hisoblagichlar serverdan yangilanadi.
    // Xabar MODULGA xos ('subModuleThanks'); eski umumiy premium 'subThanks'da qoladi.
    IapService.onModuleGranted = (String module) async {
      set({'iapBusy': false, 'paywall': null});
      await refreshSubs_(force: true);
      toast_(subModuleThanks_(module));
    };
    IapService.init(); // fire-and-forget (Android'da darhol qaytadi)
  }

  /// Paywall "Obunani yangilash / sotib olish" (iOS) — StoreKit to'lov oynasini ochadi.
  void buyPremium() => IapService.buy();

  /// "Xaridni tiklash" (iOS) — qurilma almashsa oldingi obunani qaytaradi (Apple talabi).
  void restorePremium() => IapService.restore();

  /// Serverdan profil/obuna holatini qayta o'qib lokal holatni yangilaydi
  /// (xariddan keyin banner va profil kartasi darhol yangilansin).
  Future<void> refreshMe() async {
    final prof = await Api.me();
    if (prof.ok && prof.data is Map) {
      final p = prof.data as Map;
      set({
        'subStatus': p['status'] ?? S['subStatus'],
        'trialEnd': p['trial_ends_at'],
        'premUntil': p['premium_until'],
      });
    }
  }

  // ================= Modul obunalari (GET /api/subs/status) =================
  // Butun oqim HIMOYALANGAN: endpoint yo'q (404), xato yoki maydonlar yetishmasa
  // 'modSubs' bo'sh qoladi va ilova bugungidek ishlaydi (hisoblagich ham, qulf ham
  // yo'q). Hech qachon toast ko'rsatilmaydi — bu fon so'rovi.
  int _subsAtMs = 0; // oxirgi muvaffaqiyatli so'rov vaqti (throttle uchun)
  bool _subsBusy = false;
  // Band paytda kelgan majburiy so'rov — tugagach bir marta qayta uriladi
  bool _subsAgain = false;

  /// Modul holatini serverdan olish. force=false — 60s throttle: hydrate polling
  /// har 15 soniyada chaqiradi, ammo hisoblagich faqat foydalanuvchining O'Z
  /// yozuvidan o'zgaradi (u yerda force:true bilan darhol yangilanadi).
  Future<void> refreshSubs_({bool force = false}) async {
    if (!kModuleSubsUi) return; // avariya tugmasi (flags.dart)
    if (_subsBusy) {
      // Boshqa so'rov ketyapti. Agar u BOSHQA akkauntniki bo'lsa (logout->login
      // poygasi), uning javobi identity guard bilan tashlanadi va yangi akkaunt
      // hisoblagichsiz qolardi — shuning uchun bayroq qo'yamiz, `finally` qayta uradi.
      if (force) _subsAgain = true;
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _subsAtMs < 60000) return;
    _subsBusy = true;
    // Kimning hisoblagichini so'rayapmiz — javob kelguncha logout/boshqa akkaunt
    // bo'lishi mumkin (_subsBusy faqat qayta kirishdan saqlaydi, EGALIKDAN emas).
    // _periodSeq singari: eskirgan javob YANGI sessiyaga yozilmasin.
    final uid = S['meId'];
    try {
      final r = await Api.subsStatus();
      // 404/5xx/tarmoq — JIM: eski holat saqlanadi (bo'sh bo'lsa bo'sh qoladi).
      if (!r.ok || r.body['modules'] is! List) return;
      if (S['meId'] != uid) return; // boshqa akkaunt — bu javob endi begona
      _subsAtMs = now;
      final mods = mapSubsModules(r.body);
      final patch = <String, dynamic>{'modSubs': mods, 'modSubsLegacy': subsLegacyActive(r.body)};
      // Ochiq paywall — subsPaywallEntry SNAPSHOT: yangi used/limit o'ziga
      // kelmaydi. 402 javobida `openPaywall_ + refreshSubs_(force:true)` ataylab
      // "used/limit darhol aniqlashsin" deb chaqiriladi — shu qayta hisoblashsiz
      // sheet butun umri davomida eski (ko'pincha 0/0) raqamni ko'rsatardi.
      final pw = S['paywall'];
      if (pw is Map) {
        final pm = '${pw['module'] ?? ''}';
        if (pm.isNotEmpty) patch['paywall'] = subsPaywallEntry(pm, mods);
      }
      set(patch);
    } finally {
      _subsBusy = false;
      if (_subsAgain) {
        _subsAgain = false;
        // Kutib turgan so'rov — endi joriy akkaunt uchun bajariladi (await EMAS:
        // finally bloki cho'zilmasin).
        refreshSubs_(force: true);
      }
    }
  }

  // ========= Modul yakunlari (GET /api/ijara|toyxona/summary) =========
  // refreshSubs_ bilan BIR XIL shartnoma: fon so'rovi, jim yiqiladi, toast yo'q.
  // Endpointlar bugungi production'da YO'Q (404) — o'shanda xarita null qoladi
  // va hub kartalari TINCH nol holatida chiziladi (0 so'm + modul tavsifi).
  int _hubModsAtMs = 0; // oxirgi urinish vaqti (throttle uchun)
  bool _hubModsBusy = false;
  bool _hubModsAgain = false; // band paytda kelgan majburiy so'rov

  /// Ijara/To'yxona kartasidagi summani serverdan olish.
  ///
  /// Throttle 60s — refreshSubs_ bilan bir xil (hydrate polling har 15 soniyada
  /// chaqiradi). DIQQAT: `_hubModsAtMs` javob KELGACH har doim yangilanadi, xato
  /// bo'lsa ham — aks holda endpoint yo'q serverga (404) har 15 soniyada ikkita
  /// befoyda so'rov ketardi.
  Future<void> refreshHubMods_({bool force = false}) async {
    if (_hubModsBusy) {
      // Boshqa so'rov ketyapti. Agar u BOSHQA akkauntniki bo'lsa (logout->login
      // poygasi), javobi identity guard bilan tashlanadi va yangi akkaunt
      // raqamsiz qolardi — bayroq qo'yamiz, `finally` qayta uradi.
      if (force) _hubModsAgain = true;
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _hubModsAtMs < 60000) return;
    _hubModsBusy = true;
    // Kimning raqamini so'rayapmiz — javob kelguncha logout/boshqa akkaunt
    // bo'lishi mumkin (_hubModsBusy faqat qayta kirishdan saqlaydi, EGALIKDAN
    // emas). Bu qo'riq refreshSubs_'dan ko'chirilgan: kechikkan javob ilgari
    // OLDINGI akkauntning raqamlarini yangi sessiyaga yozib qo'yardi.
    final uid = S['meId'];
    try {
      final rs = await Future.wait([Api.ijaraSummary(), Api.toyxonaSummary()]);
      if (S['meId'] != uid) return; // boshqa akkaunt — bu javob endi begona
      _hubModsAtMs = now;
      final patch = <String, dynamic>{};
      if (rs[0].ok && rs[0].data is Map) patch['hubIjaraSum'] = mapIjaraHubSum(rs[0].data);
      if (rs[1].ok && rs[1].data is Map) patch['hubToySum'] = mapToyHubSum(rs[1].data);
      // 404/5xx/tarmoq — JIM: eski holat saqlanadi (bo'sh bo'lsa bo'sh qoladi).
      if (patch.isNotEmpty) set(patch);
    } finally {
      _hubModsBusy = false;
      if (_hubModsAgain) {
        _hubModsAgain = false;
        // Kutib turgan so'rov — endi joriy akkaunt uchun (await EMAS: `finally`
        // bloki cho'zilmasin).
        refreshHubMods_(force: true);
      }
    }
  }

  List<Map<String, dynamic>> _modSubs() =>
      (S['modSubs'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];

  /// Modul paywall'ini ochish (hub kartasi qulfi yoki 402 javobi).
  void openPaywall_(String module) {
    if (module.isEmpty) return;
    set({'paywall': subsPaywallEntry(module, _modSubs())});
  }

  void paywallClose_() => set({'paywall': null});

  /// «Xarajatlar obunasi yoqildi — rahmat!» — modul nomi joriy tilda
  /// (matnni sof funksiya yasaydi — test/subs_status_test.dart).
  String subModuleThanks_(String module) => subModuleThanksText(L(), module);

  /// Paywall CTA — modul obunasini sotib olish.
  /// BUGUNGI HOLAT: mahsulotlar App Store Connect/Play Console'da hali yo'q, shu
  /// sabab buyModule() `false` qaytaradi va foydalanuvchi narxsiz, har modulga
  /// to'g'ri keladigan "to'lov hali ulanmagan" xabarini ko'radi.
  Future<void> paywallBuy_() async {
    final pw = S['paywall'];
    if (pw is! Map) return;
    final module = '${pw['module'] ?? ''}';
    if (module.isEmpty) return;
    final started = await IapService.buyModule(module);
    if (!started) {
      toast_(L()['pwPayComingSoon'] as String? ?? "To'lov hali ulanmagan — obuna tez orada ishlaydi");
    }
  }

  String typeLabel(String t) => kTypeLabels[S['lang']]?[t] ?? t;

  /// Foydalanuvchi yozgan chat xabari (lokal — serverda chat yo'q)
  void addLocalMsg(String cid, Map<String, dynamic> m) {
    final l = Map<String, List<Map<String, dynamic>>>.from(S['localMsgs'] as Map);
    l[cid] = [...(l[cid] ?? []), m];
    set({'localMsgs': l});
  }

  void tapKey(String field, String label) {
    String v = S[field] as String;
    if (label == 'del') {
      if (v.isNotEmpty) v = v.substring(0, v.length - 1);
    } else if (v.length < (field == 'pinVal' ? 4 : 5)) {
      v += label;
    }
    set({field: v, if (field == 'pinVal') 'pinErr': false});
    if (field == 'pinVal' && v.length == 4) {
      switch (S['pinMode'] as String? ?? 'set') {
        case 'check':
          _pinCheck(v);
        case 'old':
          _pinOld(v);
        case 'confirm':
          _pinConfirm(v);
        default:
          _pinSet(v);
      }
    }
  }

  // PIN o'rnatish 1-bosqich: birinchi kiritish — endi QAYTA KIRITIB tasdiqlash so'raladi.
  Future<void> _pinSet(String pin) async {
    Timer(const Duration(milliseconds: 220), () {
      set({'pinMode': 'confirm', 'pinFirst': pin, 'pinVal': ''});
    });
  }

  // PIN o'rnatish 2-bosqich: qayta kiritish mos bo'lsa saqlanadi, aks holda boshidan.
  Future<void> _pinConfirm(String pin) async {
    if (pin == (S['pinFirst'] as String? ?? '')) {
      await SecureStore.setPin(pin);
      final fromProfil = S['pinRet'] == 'profil';
      Timer(const Duration(milliseconds: 220), () {
        set({
          'stage': 'app', 'pinVal': '', 'pinFirst': '', 'pinRet': null, 'pinOn': true,
          if (!fromProfil) 'skelHome': true, if (!fromProfil) 'homeVis': 6,
        });
        if (!fromProfil) {
          Timer(const Duration(milliseconds: 950), () => set({'skelHome': false}));
          toast_(L()['tWelcome']);
        } else {
          toast_(L()['tPinSet']);
        }
      });
    } else {
      // Mos kelmadi — qizil signal, boshidan
      set({'pinErr': true});
      Timer(const Duration(milliseconds: 450), () {
        set({'pinMode': 'set', 'pinFirst': '', 'pinVal': '', 'pinErr': false});
        toast_(L()['tPinMismatch']);
      });
    }
  }

  // PIN o'zgartirish: avval JORIY PIN tekshiriladi, keyin yangi o'rnatish oqimi.
  Future<void> _pinOld(String pin) async {
    final ok = await SecureStore.checkPin(pin);
    if (ok) {
      set({'pinMode': 'set', 'pinVal': '', 'pinErr': false});
    } else {
      set({'pinErr': true});
      Timer(const Duration(milliseconds: 400), () => set({'pinVal': '', 'pinErr': false}));
    }
  }

  // PIN o'zgartirishni profil ichidan boshlash
  Future<void> pinChangeStart_() async {
    final has = await SecureStore.hasPin();
    set({
      'stage': 'pin',
      'pinMode': has ? 'old' : 'set',
      'pinVal': '', 'pinFirst': '', 'pinRet': 'profil',
    });
  }

  // Qayta kirishda PIN tekshirish — to'g'ri bo'lsa app, xato bo'lsa nuqtalar qizarib tozalanadi.
  Future<void> _pinCheck(String pin) async {
    final ok = await SecureStore.checkPin(pin);
    if (ok) {
      set({'stage': 'app', 'pinVal': '', 'pinErr': false, 'skelHome': true, 'homeVis': 6});
      Timer(const Duration(milliseconds: 950), () => set({'skelHome': false}));
    } else {
      set({'pinErr': true});
      Timer(const Duration(milliseconds: 400), () => set({'pinVal': '', 'pinErr': false}));
    }
  }

  // Profil sozlamasidagi PIN kaliti — o'chirsa PIN olib tashlanadi, yoqsa o'rnatish ekraniga.
  Future<void> _togglePin() async {
    final on = S['pinOn'] != true; // yangi holat
    set({'pinOn': on});
    if (!on) {
      await SecureStore.clearPin();
      toast_(L()['tPinRemoved']);
    } else if (!await SecureStore.hasPin()) {
      set({'stage': 'pin', 'pinMode': 'set', 'pinVal': '', 'pinRet': 'profil'});
    }
  }

  Map<String, dynamic> ccEntry(String dial) =>
      ccList.firstWhere((c) => c['d'] == dial, orElse: () => ccList[0]);

  List<Map<String, dynamic>> _clients() => List<Map<String, dynamic>>.from(S['clients']);
  List<Map<String, dynamic>> _txs() => List<Map<String, dynamic>>.from(S['txs']);
  List<Map<String, dynamic>> _notifs() => List<Map<String, dynamic>>.from(S['notifs']);
  List<Map<String, dynamic>> _xar() => List<Map<String, dynamic>>.from(S['xarEntries']);
  /// Chat oqimi: serverdan hosil qilingan (tx) + REAL server xabarlari + lokal (eski) xabarlar
  Map<String, List<Map<String, dynamic>>> _msgs() {
    final d = Map<String, List<Map<String, dynamic>>>.from(S['msgs']);
    final srv = Map<String, List<Map<String, dynamic>>>.from(S['srvMsgs'] as Map);
    for (final e in srv.entries) {
      d[e.key] = [...(d[e.key] ?? []), ...e.value];
    }
    final l = Map<String, List<Map<String, dynamic>>>.from(S['localMsgs'] as Map);
    for (final e in l.entries) {
      d[e.key] = [...(d[e.key] ?? []), ...e.value];
    }
    return d;
  }

  Map<String, dynamic>? _tx(String? id) {
    for (final t in _txs()) {
      if (t['id'] == id) return t;
    }
    return null;
  }

  Map<String, dynamic>? _client(String? id) {
    for (final c in _clients()) {
      if (c['id'] == id) return c;
    }
    return null;
  }

  void archive_(String id) => _setArchived(id, true, L()['tArch']);

  void restore_(String id) => _setArchived(id, false, L()['tRestoredArch'] as String);

  Future<void> _setArchived(String id, bool v, String msg) async {
    final before = _clients();
    set({
      'clients': before.map((x) => x['id'] == id ? {...x, 'archived': v} : x).toList(),
      'swipeSnap': null, 'swipeId': null, 'swipeDx': 0.0,
    });
    final r = await Api.patchPartner(id, archived: v);
    if (!r.ok) {
      set({'clients': before}); // orqaga qaytarish
      toast_(r.error);
      return;
    }
    toast_(msg);
  }

  // Swipe (GestureDetector bilan ishlatiladi)
  void swBegin(String id) {
    _sw = {'id': id, 'dx0': S['swipeSnap'] == id ? -96.0 : 0.0, 'moved': false};
    _lp?.cancel();
    _lp = Timer(const Duration(milliseconds: 480), () {
      if (_sw != null && _sw!['id'] == id && _sw!['moved'] != true) {
        _sw = null;
        set({'swipeSnap': id, 'swipeId': null, 'swipeDx': 0.0});
      }
    });
  }

  void swMove(String id, double dx) {
    if (_sw == null || _sw!['id'] != id) return;
    final raw = (_sw!['dx0'] as double) + dx;
    if (dx.abs() > 6) {
      _sw!['moved'] = true;
      _lp?.cancel();
    }
    if (_sw!['moved'] != true) return;
    set({'swipeId': id, 'swipeDx': raw.clamp(-140.0, 0.0)});
  }

  void swEnd(String id, VoidCallback act) {
    _lp?.cancel();
    if (_sw == null || _sw!['id'] != id) return;
    final moved = _sw!['moved'] == true;
    _sw = null;
    if (moved) _swClick = true;
    final double dx = S['swipeId'] == id
        ? (S['swipeDx'] as double)
        : (S['swipeSnap'] == id ? -96.0 : 0.0);
    if (moved && dx < -120) {
      set({'swipeId': null, 'swipeDx': 0.0, 'swipeSnap': null});
      act();
    } else if (moved && dx < -48) {
      set({'swipeSnap': id, 'swipeId': null, 'swipeDx': 0.0});
    } else if (moved) {
      set({'swipeSnap': S['swipeSnap'] == id ? null : S['swipeSnap'], 'swipeId': null, 'swipeDx': 0.0});
    } else {
      set({'swipeId': null, 'swipeDx': 0.0});
    }
  }

  Future<void> renSave_() async {
    if (S['cRen'] == null) return;
    final v = (S['cRen'] as String).trim();
    final id = S['clientId'] as String?;
    if (v.isEmpty || id == null) {
      set({'cRen': null});
      return;
    }
    final r = await Api.patchPartner(id, name: v);
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    set({
      'clients': _clients().map((x) => x['id'] == id ? {...x, 'name': v} : x).toList(),
      'cRen': null,
    });
    toast_(L()['tNameUpdated']);
  }

  List<Map<String, dynamic>> makeKeys(String field) {
    return ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del']
        .map((l) => {
              'label': l == 'del' ? '⌫' : l,
              'tap': l == '' ? () {} : () => tapKey(field, l),
            })
        .toList();
  }

  // ---------------- Bog'lanish (link) amallari — mijoz tomoni ----------------

  /// Qabul qilingan bog'lanish operatsiyalarini yuklash
  Future<void> _loadLinkOps(String linkId, {bool silent = false}) async {
    final r = await Api.linkOperations(linkId);
    if (!r.ok) {
      if (!silent) toast_(r.error);
      return;
    }
    final ops = (((r.data as Map)['operations'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .map((o) => _mapOp(o, flip: true)) // mijoz nuqtai nazari
        .toList()
      ..sort((a, b) => (b['ts'] as int).compareTo(a['ts'] as int));
    set({'inLinkOps': ops});
  }

  /// Kiruvchi (meni qo'shgan sotuvchi) daftarini ochish
  Future<void> openIncoming(String linkId) async {
    set({
      'inLinkId': linkId, 'inLinkOps': <Map<String, dynamic>>[],
      'clientId': null, 'tab': 'ops', 'cMenuOpen': false, 'cRen': null,
      'pProfOpen': false, 'opsVis': 8, 'notifOpen': false, 'linkDecisionId': null,
    });
    openLedger_(linkId); // kiruvchi daftar ham LEDGER (qarz daftari) bilan ishlaydi
    await _loadLinkOps(linkId);
  }

  Map<String, dynamic>? _link(String? id) {
    for (final l in List<Map<String, dynamic>>.from(S['links'] as List)) {
      if (l['id'] == id) return l;
    }
    return null;
  }

  /// accept | reject | restore | disconnect | block | unblock
  Future<void> linkAct(String id, String action, {String? okMsg}) async {
    if (_busy) return;
    _busy = true;
    _setBusy('link:$action');
    final r = await Api.linkAction(id, action);
    _busy = false;
    _setBusy(null);
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    if (okMsg != null) toast_(okMsg);
    // Rad/uzish ochiq daftarni yopadi
    if ((action == 'reject' || action == 'disconnect' || action == 'block') && S['inLinkId'] == id) {
      set({'inLinkId': null, 'inLinkOps': <Map<String, dynamic>>[]});
    }
    set({'linkDecisionId': null});
    final kr = await Api.links();
    if (kr.ok && kr.data is List) {
      set({'links': (kr.data as List).cast<Map<String, dynamic>>().map(_mapLink).toList()});
    }
  }

  void togglePlay(String key, int dur) {
    final p = S['playing'] as Map<String, dynamic>?;
    if (p != null && p['key'] == key && p['paused'] != true) {
      _pi?.cancel();
      set({'playing': {...p, 'paused': true}});
      return;
    }
    _pi?.cancel();
    final double start = (p != null && p['key'] == key) ? (p['prog'] as double) : 0.0;
    set({'playing': {'key': key, 'prog': start, 'paused': false, 'dur': dur}});
    _pi = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final pp = S['playing'] as Map<String, dynamic>?;
      if (pp == null || pp['paused'] == true) {
        _pi?.cancel();
        return;
      }
      final np = (pp['prog'] as double) + 0.1 / dur;
      if (np >= 1) {
        _pi?.cancel();
        set({'playing': null});
      } else {
        set({'playing': {...pp, 'prog': np}});
      }
    });
  }

  // ================= REAL CHAT (server): matn + OVOZLI xabarlar =================
  Timer? _chatPoll;
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _posSub, _doneSub;
  String? _playKey;

  /// Server xabari -> chat bubble shakli (mavjud render bilan mos)
  Map<String, dynamic> _mapMsg(Map<String, dynamic> m) => {
        'id': m['id'],
        'k': m['kind'] == 'audio' ? 'voice' : 'text',
        'mine': m['sender_id'] == S['meId'],
        'text': m['body'] ?? '',
        'dur': _numToInt(m['duration_sec'] ?? 1).clamp(1, 600),
        'audioUrl': m['audio_url'],
        'time': _dt(m['created_at']) != null ? _hhmm(_dt(m['created_at'])!.toLocal()) : '',
        'read': m['read_at'] != null,
        'at': m['created_at'] ?? '',
      };

  List<Map<String, dynamic>> _srv(String pid) =>
      List<Map<String, dynamic>>.from((S['srvMsgs'] as Map)[pid] as List? ?? []);

  /// Chat ochilganda: to'liq tarix + o'qildi + tez polling (realtime his)
  Future<void> openChat_(String partnerId) async {
    final r = await Api.messages(partnerId);
    if (r.ok && r.data is List) {
      final list = (r.data as List).cast<Map<String, dynamic>>().map(_mapMsg).toList();
      final srv = Map<String, List<Map<String, dynamic>>>.from(S['srvMsgs'] as Map);
      srv[partnerId] = list;
      final un = Map<String, int>.from(S['msgUnread'] as Map)..remove(partnerId);
      set({'srvMsgs': srv, 'msgUnread': un});
      Api.readMsgs(partnerId); // kutmaymiz
    }
    _chatPoll?.cancel();
    // Realtime: chat ochiq ekan har 3 soniyada faqat YANGI xabarlar (after=oxirgi)
    _chatPoll = Timer.periodic(const Duration(seconds: 3), (_) => _chatTick(partnerId));
  }

  Future<void> _chatTick(String partnerId) async {
    if (S['clientId'] != partnerId) {
      _chatPoll?.cancel();
      return;
    }
    final cur = _srv(partnerId);
    final after = cur.isNotEmpty ? cur.last['at'] as String? : null;
    final r = await Api.messages(partnerId, after: after);
    if (!r.ok || r.data is! List) return;
    final fresh = (r.data as List).cast<Map<String, dynamic>>().map(_mapMsg).toList();
    if (fresh.isEmpty) return;
    final ids = cur.map((m) => m['id']).toSet();
    final add = fresh.where((m) => !ids.contains(m['id'])).toList();
    if (add.isEmpty) return;
    final srv = Map<String, List<Map<String, dynamic>>>.from(S['srvMsgs'] as Map);
    srv[partnerId] = [...cur, ...add];
    set({'srvMsgs': srv});
    // Qarshi tomondan kelganlar — darhol o'qildi
    if (add.any((m) => m['mine'] != true)) Api.readMsgs(partnerId);
  }

  void stopChatPoll_() {
    _chatPoll?.cancel();
    _player.stop();
    _playKey = null;
    set({'playing': null});
  }

  /// Matn xabar — SERVERGA yoziladi (real chat), javob darhol oqimga qo'shiladi
  Future<void> sendChatServer_(String partnerId, String text) async {
    final r = await Api.sendMsg(partnerId, text);
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    final m = _mapMsg(r.data as Map<String, dynamic>);
    final srv = Map<String, List<Map<String, dynamic>>>.from(S['srvMsgs'] as Map);
    srv[partnerId] = [..._srv(partnerId), m];
    set({'srvMsgs': srv});
  }

  // 2026-07-17: chat ovozli xabar yuborish OLIB TASHLANDI (FAQAT MATN — docs/ai-character.md §11).
  // ChatRec (stt.dart) va Api.sendAudio o'chirildi; server /api/messages/:id/audio ham yo'q.

  /// REAL audio ijro (audioplayers): play/pause, progress S['playing'] orqali UI'ga
  Future<void> togglePlayReal(String key, int dur, String? url) async {
    if (url == null) return togglePlay(key, dur); // eski (lokal demo) xabarlar
    if (_playKey == key) {
      final st = _player.state;
      if (st == PlayerState.playing) {
        await _player.pause();
        final p = S['playing'] as Map<String, dynamic>?;
        set({'playing': {...?p, 'paused': true}});
      } else {
        await _player.resume();
        final p = S['playing'] as Map<String, dynamic>?;
        set({'playing': {...?p, 'paused': false}});
      }
      return;
    }
    await _player.stop();
    _playKey = key;
    set({'playing': {'key': key, 'prog': 0.0, 'paused': false}});
    _posSub?.cancel();
    _doneSub?.cancel();
    _posSub = _player.onPositionChanged.listen((pos) {
      final total = dur > 0 ? dur * 1000 : 1;
      final prog = (pos.inMilliseconds / total).clamp(0.0, 1.0);
      if (_playKey == key) set({'playing': {'key': key, 'prog': prog, 'paused': false}});
    });
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (_playKey == key) {
        _playKey = null;
        set({'playing': null});
      }
    });
    try {
      await _player.play(UrlSource(url));
    } catch (_) {
      _playKey = null;
      set({'playing': null});
      toast_(L()['tAudioFail']);
    }
  }

  // ================= PROFIL: foto / valyuta / obuna / o'chirish =================
  Future<void> pickAvatar_() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
      if (x == null) return;
      final dir = await SharedPreferences.getInstance();
      // Rasmni doimiy joyga ko'chirmaymiz — picker cache yo'lini saqlaymiz (lokal ko'rinish).
      await dir.setString('trust_avatar', x.path);
      set({'meAvatar': x.path});
      toast_(L()['tPhotoUpdated']);
    } catch (e) {
      toast_(L()['tPhotoFail']);
    }
  }

  static const _curList = ['UZS', 'USD', 'EUR', 'RUB'];
  void cycleCur_() {
    final i = _curList.indexOf(S['cur'] as String? ?? 'UZS');
    final next = _curList[(i + 1) % _curList.length];
    SharedPreferences.getInstance().then((sp) => sp.setString('trust_cur', next));
    set({'cur': next});
  }

  /// #34: Profil o'chirish — SMS KOD bilan tasdiqlash (ikki bosqichli bosish o'rniga).
  /// 1-qadam profileDeleteAsk_: bazadagi raqamga OTP yuboriladi, modal ochiladi.
  /// 2-qadam profileDeleteConfirm_: kod to'g'ri -> soft delete + logout.
  /// SOFT delete: qarshi tomonda daftar QOLADI (link modeli), qayta kirish = tiklash.
  Future<void> profileDeleteAsk_() async {
    if (S['delOtpBusy'] == true) return;
    set({'delOtpBusy': true});
    final r = await Api.sendDeleteOtp();
    set({'delOtpBusy': false});
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    final masked = ((r.data as Map?)?['phone_masked'] as String?) ?? '';
    set({'delOtpOpen': true, 'delOtpPhone': masked});
    toast_(L()['tDelOtpSent'] as String? ?? 'Tasdiqlash kodi SMS bilan yuborildi');
  }

  Future<bool> profileDeleteConfirm_(String code) async {
    final c = code.trim();
    if (c.length < 4) {
      toast_(L()['tCodeShort'] as String? ?? "Kodni to'liq kiriting");
      return false;
    }
    if (S['delOtpBusy'] == true) return false;
    set({'delOtpBusy': true});
    final r = await Api.deleteProfile(c);
    set({'delOtpBusy': false});
    if (!r.ok) {
      toast_(r.error);
      return false;
    }
    set({'delOtpOpen': false});
    toast_(L()['tProfileDeleted']);
    logout_();
    return true;
  }

  void profileDeleteCancel_() => set({'delOtpOpen': false});

  // ================= QARZ DAFTARI (ledger) =================
  Timer? _ledgerPoll;

  /// Ochiq hamkorning DebtLedger obyektini quramiz (viewer = meId perspektivasi).
  DebtLedger _ledgerFor(String partnerId) {
    final c = _client(partnerId);
    final accepted = c?['onTrust'] != false; // off-Trust bo'lsa oneSided oqim
    final rows = (S['ledgerRows'] as List).cast<Map<String, dynamic>>();
    final entries = rows.map((j) => DebtEntry.fromServer(j, '${S['meId']}')).toList();
    return DebtLedger(meId: '${S['meId']}', partnerAccepted: accepted, entries: entries);
  }

  /// Hamkor daftarini serverdan yuklash + realtime polling (chat o'rniga).
  Future<void> openLedger_(String partnerId) async {
    // Opening the 1:1 ledger marks this partner's debt-event notifications as
    // read: local count zeroed optimistically (card badge disappears at once),
    // POST fired without await — idempotent, and a silent failure is fine
    // because the next hydrate poll restores the true server count.
    if ((S['notifCounts'] as Map).containsKey(partnerId)) {
      set({
        'notifCounts': Map<String, Map<String, dynamic>>.from(
            S['notifCounts'] as Map)
          ..remove(partnerId),
      });
    }
    unawaited(Api.readPartnerNotifs(partnerId));
    // Daftar almashganda oldingi hamkor qatorlari ko'rinib turmasin
    if (S['ledgerPid'] != partnerId) {
      set({'ledgerPid': partnerId, 'ledgerRows': <Map<String, dynamic>>[], 'ledgerLoading': true});
    } else {
      set({'ledgerLoading': (S['ledgerRows'] as List).isEmpty});
    }
    final r = await Api.debts(partnerId);
    if (r.ok && r.data is List) {
      set({'ledgerRows': (r.data as List).cast<Map<String, dynamic>>(), 'ledgerLoading': false, 'ledgerError': null});
    } else {
      // MUHIM (2026-07-28 audit): xato JIM yutilardi — kontragent "bo'sh daftar"
      // ko'rib, yozuvlar yo'qolgan deb o'ylardi. Endi xabar ko'rsatamiz.
      set({'ledgerLoading': false, 'ledgerError': r.error});
      toast_(r.error);
    }
    _ledgerPoll?.cancel();
    _ledgerPoll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (S['clientId'] == partnerId || S['inLinkId'] == partnerId) {
        _refetchLedger(partnerId);
      } else {
        _ledgerPoll?.cancel();
      }
    });
  }

  Future<void> _refetchLedger(String partnerId) async {
    final r = await Api.debts(partnerId);
    if (r.ok && r.data is List) {
      set({'ledgerRows': (r.data as List).cast<Map<String, dynamic>>()});
    }
  }

  void stopLedgerPoll_() {
    _ledgerPoll?.cancel();
    set({'chAct': null, 'chA': '', 'chDebt': null, 'histId': null, 'histEdit': false, 'revAllOpen': false});
  }

  // Server call -> re-fetch (server = haqiqat manbai; ikki tomonlama tasdiq shundan)
  Future<void> _ledgerAct(String partnerId, Future<ApiRes> Function() call, {String? okMsg}) async {
    if (_busy) return;
    _busy = true;
    final r = await call();
    _busy = false;
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    await _refetchLedger(partnerId);
    // Yangi qarz yozuvi kvotani yedi — hisoblagich darhol yangilansin
    unawaited(refreshSubs_(force: true));
    if (okMsg != null) toast_(okMsg);
  }

  // ---- Input panel: 3 tugma ----
  void chOpen_(String key) {
    if (S['chAct'] == key) {
      set({'chAct': null});
      return;
    }
    final today = _isoDate(DateTime.now());
    // Yopish oqimi: erkin qarz bo'lsa avtomatik tanlanadi
    if (key == 'close') {
      final led = _ledgerFor(_ledPid()!);
      final closable = led.closableDebts().where((d) => led.remainingEff(d) > 0).toList();
      set({
        'chAct': 'close', 'chDebt': closable.length == 1 ? closable.first.id : null,
        'chA': closable.length == 1 ? _fmt(led.remainingEff(closable.first)) : '',
        'chReason': 'returned',
      });
      return;
    }
    set({'chAct': key, 'chA': '', 'chCur': (S['cur'] ?? 'UZS'), 'chDue': '', 'chDate': today, 'chNote': '', 'chDebt': null});
  }

  void chClose_() => set({'chAct': null, 'chA': '', 'chDue': '', 'chDate': '', 'chNote': '', 'chDebt': null});

  void chSet_(Map<String, dynamic> patch) => set(patch);

  /// Yuborish: lend/borrow -> yangi qarz; close -> repay yoki settle (tanlangan qarzga qarab).
  Future<void> chSubmit_() async {
    final pid = _ledPid();
    if (pid == null) return;
    final act = S['chAct'] as String?;
    final amt = int.tryParse('${S['chA']}'.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    if (amt <= 0) {
      toast_(L()['tSum']);
      return;
    }
    // MUHIM (2026-08-02 audit): quyidagi qiymatlar chClose_() dan OLDIN o'zgaruvchiga
    // olinadi. Ilgari closure ichida S['chDue'] / S['chNote'] / S['chDate'] o'qilardi,
    // ammo chClose_() ulardan avval ishga tushib formani TOZALAB yuborardi — natijada
    // MUDDAT, IZOH va SANA serverга hech qachon bormasdi. Ya'ni foydalanuvchi kalendardan
    // muddat tanlaydi, ilova esa uni jimgina tashlab yuborardi va avto-eslatma
    // (mahsulotning asosiy va'dasi) hech qachon ishlamasdi.
    final curV = '${S['chCur'] ?? 'UZS'}';
    final dueV = '${S['chDue']}';
    final noteV = '${S['chNote']}';
    final dateV = '${S['chDate']}'.isEmpty ? _isoDate(DateTime.now()) : '${S['chDate']}';
    final reasonV = S['chReason'] == 'forgiven' ? 'forgiven' : 'returned';

    if (act == 'lend' || act == 'borrow') {
      final dir = act == 'lend' ? 'toMe' : 'fromMe'; // viewer perspektivasi
      chClose_();
      await _ledgerAct(pid, () => Api.openDebt(pid,
          direction: dir, amount: amt, currency: curV,
          actedAt: dateV,
          due: dueV, note: noteV),
          okMsg: _ledgerFor(pid).partnerAccepted ? (L()['okPendingConfirm'] as String) : (L()['okWroteUnconf'] as String));
    } else if (act == 'close') {
      final debtId = S['chDebt'] as String?;
      if (debtId == null) {
        toast_(L()['tPickDebt']);
        return;
      }
      final led = _ledgerFor(pid);
      DebtEntry? d;
      for (final e in led.entries) {
        if (e.id == debtId) d = e;
      }
      if (d == null) return;
      chClose_();
      if (d.direction == DebtDir.fromMe) {
        // Men qaytaraman
        await _ledgerAct(pid, () => Api.repay(pid, debtId, amt, note: noteV), okMsg: L()['okRepaySent'] as String);
      } else {
        // U menga qarzdor — pulni oldim / kechdim
        await _ledgerAct(pid, () => Api.settle(pid, debtId, amt, reasonV, note: noteV), okMsg: L()['okSent'] as String);
      }
    }
  }

  // ---- Yozuv amallari ----
  // Ochiq daftar id'si: o'z hamkorim (clientId) YOKI kiruvchi bog'lanish (inLinkId)
  String? _ledPid() => (S['clientId'] ?? S['inLinkId']) as String?;
  void ledgerConfirm_(String id) => _ledgerAct(_ledPid()!, () => Api.debtConfirm(id), okMsg: L()['okConfirmed'] as String);
  void ledgerReject_(String id) => _ledgerAct(_ledPid()!, () => Api.debtReject(id), okMsg: L()['okRejected'] as String);
  void ledgerConfirmOp_(String id) => _ledgerAct(_ledPid()!, () => Api.debtConfirmOp(id), okMsg: L()['okConfirmed'] as String);
  void ledgerRejectOp_(String id) => _ledgerAct(_ledPid()!, () => Api.debtRejectOp(id), okMsg: L()['okRejected'] as String);
  void ledgerCancel_(String id) => _ledgerAct(_ledPid()!, () => Api.debtCancel(id), okMsg: L()['tCancelled'] as String);
  void ledgerEditConfirm_(String id) => _ledgerAct(_ledPid()!, () => Api.debtEditConfirm(id), okMsg: L()['okEditConfirmed'] as String);
  void ledgerEditReject_(String id) => _ledgerAct(_ledPid()!, () => Api.debtEditReject(id), okMsg: L()['okRejected'] as String);
  void ledgerReviewReject_(String id) => _ledgerAct(_ledPid()!, () => Api.reviewReject(id));
  void ledgerReviewConfirm_(String debtId) =>
      _ledgerAct(_ledPid()!, () => Api.reviewConfirm(_ledPid()!, debtId), okMsg: L()['okConfirmedTwoSided'] as String);

  Future<void> ledgerReviewAll_() async {
    set({'revAllOpen': false});
    final pid = _ledPid()!;
    final led = _ledgerFor(pid);
    // Har bir natija tekshiriladi — ilgari 409 ("holat o'zgargan") kelsa ham
    // "hammasi tasdiqlandi" deb aytilardi (2026-08-02 audit).
    var ok = 0, total = 0;
    for (final d in led.reviewDebts()) {
      total++;
      final r = await Api.reviewConfirm(pid, d.id);
      if (r.ok) ok++;
    }
    await _refetchLedger(pid);
    toast_(ok == total ? L()['tAllConfirmed'] as String : '$ok/$total — qisman tasdiqlandi');
  }

  // ---- Yozuv tahriri (dialog) ----
  void histOpen_(String id) => set({'histId': id, 'histEdit': false});
  void histClose_() => set({'histId': null, 'histEdit': false});
  void histEditStart_() {
    final led = _ledgerFor(_ledPid()!);
    DebtEntry? d;
    for (final e in led.entries) {
      if (e.id == S['histId']) d = e;
    }
    if (d == null) return;
    set({'histEdit': true, 'eA': '${d.amount}', 'eDue': _isoDate(d.due), 'eNote': d.note});
  }

  Future<void> histEditSave_() async {
    final id = S['histId'] as String?;
    if (id == null) return;
    final amt = int.tryParse('${S['eA']}'.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    if (amt <= 0) {
      toast_(L()['tSum']);
      return;
    }
    set({'histEdit': false, 'histId': null});
    await _ledgerAct(_ledPid()!,
        () => Api.debtEdit(id, amount: amt, due: '${S['eDue']}', note: '${S['eNote']}'),
        okMsg: L()['okEditSent'] as String);
  }

  String _isoDate(DateTime? d) => d == null ? '' : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Qarz yozuvi sarlavhasi — tur+yo'nalish (spec 4.6/4.7 kartochka matnlari)
  String _debtTitle(DebtEntry e, DebtLedger led) {
    if (e.kind == EntryKind.repay) return L()['debtRepay'] as String;
    if (e.kind == EntryKind.settle) {
      return e.reason == CloseReason.forgiven ? (L()['debtForgive'] as String) : (L()['debtSettle'] as String);
    }
    // debt: yo'nalish "menga" / "men unga" — meId nuqtai nazaridan
    return e.direction == DebtDir.toMe ? (L()['debtOwesYouT'] as String) : (L()['debtYouBorrowedT'] as String);
  }

  // Holat yorlig'i (spec 4.10 badge matnlari)
  String _stLabel(EntryStatus s) {
    switch (s) {
      case EntryStatus.pending:
        return L()['stPending'] as String;
      case EntryStatus.active:
        return L()['stActiveL'] as String;
      case EntryStatus.closed:
        return L()['stClosedL'] as String;
      case EntryStatus.rejected:
        return L()['okRejected'] as String;
      case EntryStatus.cancelled:
        return L()['tCancelled'] as String;
      case EntryStatus.ok:
        return L()['okConfirmed'] as String;
      case EntryStatus.disputed:
        return L()['stDisputedL'] as String;
    }
  }

  Color _stColor(EntryStatus s, Color ink, Color red, Color mut) {
    switch (s) {
      case EntryStatus.active:
      case EntryStatus.pending:
        return ink;
      case EntryStatus.rejected:
      case EntryStatus.disputed:
        return red;
      case EntryStatus.closed:
      case EntryStatus.cancelled:
      case EntryStatus.ok:
        return mut;
    }
  }

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');

  String fmtA(int a, String cur) => _fmt(a) + (cur == 'USD' ? ' \$' : " so'm");

  /// Yozuv muallifi o'z yozuvini to'g'ridan-to'g'ri tuzatadi (audit op_history'da)
  Future<void> submitEdit() async {
    final t = _tx(S['receiptId']);
    if (t == null) return;
    final newA = int.tryParse(S['editA'] as String) ?? (t['a'] as int);
    final newNote = (S['editNote'] as String).trim();
    if (newA == t['a'] && newNote == (t['note'] ?? '')) {
      toast_(L()['tNoChange']);
      return;
    }
    if (_busy) return;
    _busy = true;
    _setBusy('submitEdit');
    final r = await Api.patchOp(t['id'] as String, amount: newA, note: newNote);
    _busy = false;
    _setBusy(null);
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    final line = '${fmtA(t['a'] as int, t['cur'] as String)} → ${fmtA(newA, t['cur'] as String)} · ${_fmtDateIso(DateTime.now().toIso8601String())}';
    set({
      'txs': _txs().map((x) {
        if (x['id'] != t['id']) return x;
        return {
          ...x,
          'a': newA,
          'note': newNote.isNotEmpty ? newNote : x['note'],
          'hist': [...((x['hist'] as List?) ?? []), {'txt': line}],
        };
      }).toList(),
      'editFormOpen': false, 'editA': '', 'editNote': '',
    });
    toast_(L()['tEntryFixed']);
    hydrate(full: false);
  }

  Future<void> createTx() async {
    final f = Map<String, dynamic>.from(S['form']);
    final a = int.tryParse(f['amount'] as String) ?? 0;
    if (a == 0) {
      toast_(L()['tSum']);
      return;
    }
    final cl0 = _client(S['sheetClient']);
    if (cl0 == null) {
      toast_(L()['tPickPartner']);
      return;
    }
    if (_busy) return;
    _busy = true;
    _setBusy('createTx');
    final r = await Api.createOp(
      cl0['id'] as String,
      _typeSrv[f['type']] ?? 'qarz_berdim',
      a,
      f['currency'] as String,
      (f['note'] as String).trim(),
    );
    _busy = false;
    _setBusy(null);
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    final tx = _mapOp(r.data as Map<String, dynamic>);
    final cid = cl0['id'] as String;
    final msgs = Map<String, List<Map<String, dynamic>>>.from(S['msgs']);
    msgs[cid] = [...(msgs[cid] ?? []), {'k': 'tx', 'tx': tx['id']}];
    set({
      'txs': [..._txs(), tx], 'msgs': msgs, 'sheetOpen': false,
      'clientId': cid, 'tab': 'chat',
      'form': {'type': 'Qarz berdim', 'amount': '', 'currency': S['cur'] ?? 'UZS', 'note': '', 'name': ''},
    });
    openLedger_(cid); // qarz daftarini yuklash + polling
    toast_(L()['tSaved']);
    unawaited(refreshSubs_(force: true)); // kvota hisoblagichi yangilansin
    hydrate(full: false);
  }

  Map<String, dynamic> xarParse_(String txt) {
    final t = txt.toLowerCase();
    final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(t);
    double a = m != null ? (double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0) : 0;
    if (RegExp(r'mln|million|milion').hasMatch(t)) {
      a *= 1000000;
    } else if (RegExp(r'ming').hasMatch(t)) {
      a *= 1000;
    }
    final ai = a.round();
    // #15: asosiy input FAQAT xarajat — daromad endi "Daromad" papkasi ichidan kiritiladi.
    const bool inc = false;
    String cat = 'Boshqa';
    if (!inc) {
      final map = [
        ['Oziq-ovqat', r"oziq|ovqat|bozor|non|go'sht|gosht|market|restoran|kafe|choyxona"],
        ['Transport', r"taksi|benzin|yo'l|yol|metro|avtobus|mashina"],
        ['Kommunal', r'kommunal|svet|elektr|gaz|suv|internet|telefon'],
        ["Ko'ngilochar", r"kino|konsert|o'yin|oyin|sayohat|dam olish"],
        ['Kiyim', r"kiyim|ko'ylak|koylak|poyabzal|shim|kurtka"],
        ['Salomatlik', r'dori|apteka|shifokor|klinika|tish|salomatlik'],
      ];
      for (final e in map) {
        if (RegExp(e[1]).hasMatch(t)) {
          cat = e[0];
          break;
        }
      }
    }
    final trimmed = txt.trim();
    final note = trimmed.isEmpty ? '' : trimmed[0].toUpperCase() + trimmed.substring(1);
    // #15: asosiy input faqat xarajat (inc doim false) — CI analyze dead_code tozalandi
    return {'kind': 'x', 'amount': ai != 0 ? ai.toString() : '', 'cat': cat, 'note': note};
  }

  // 2026-07-17: ovozli kiritish (STT hold-to-talk) OLIB TASHLANDI — FAQAT MATN.
  // DIQQAT: 'voiceStage'/'vText' QOLADI — ular endi MATN parsing holati ('parsing' bosqichi,
  // xarajat.dart ishlatadi). Faqat 'rec' qiymati o'ldi.

  // Server parse -> AVTOMATIK saqlash (tasdiqlash kartasi yo'q). Qarz -> Hamkorlar oqimiga.
  // Toifa/summa xato bo'lsa — chatdagi bubble'ni bosib inline tuzatiladi.
  Future<void> xarPick_(String txt, {String source = 'text'}) async {
    set({'voiceStage': 'parsing', 'vText': txt});
    final r = await Api.parseExpense(txt);
    if (!r.ok) {
      if (r.status == 0 || r.status >= 500) return _xarOffline(txt);
      set({'voiceStage': null, 'vText': ''});
      toast_(r.error);
      return;
    }
    final d = r.data as Map<String, dynamic>;
    final actions = ((d['actions'] as List?) ?? []).cast<Map<String, dynamic>>();
    if (actions.isEmpty) {
      set({'voiceStage': null, 'vText': ''});
      toast_(L()['tAmountUnclear']);
      return;
    }
    // #15: asosiy input FAQAT xarajat. Parser "daromad" desa ham xarajatga o'giramiz
    // (daromad faqat "Daromad" papkasi ichidan kiritiladi). Qarz yo'nalishi o'zgarmaydi.
    for (final a in actions) {
      if (a['direction'] == 'daromad') {
        a['direction'] = 'xarajat';
        final c = ((a['category'] as String?) ?? '').trim().toLowerCase();
        if (c.isEmpty || c == 'daromad') a['category'] = 'Boshqa';
      }
    }
    // Ajratamiz: toifasi aniq -> darhol papkaga; noaniq ('Boshqa'/bo'sh xarajat) -> ANIQLANMAGAN tray
    final sure = <Map<String, dynamic>>[];
    final unsure = <Map<String, dynamic>>[];
    for (final a in actions) {
      final cat = ((a['category'] as String?) ?? '').trim();
      // DIQQAT: server maydoni 'direction' ('type' emas) — eski nom tray'ni o'lik qilib qo'ygandi
      if (a['direction'] == 'xarajat' && (cat.isEmpty || cat.toLowerCase() == 'boshqa')) {
        unsure.add(a);
      } else {
        sure.add(a);
      }
    }
    if (unsure.isNotEmpty) {
      final tray = List<Map<String, dynamic>>.from(S['xfTray'] as List);
      for (var i = 0; i < unsure.length; i++) {
        final a = unsure[i];
        final note = ((a['note'] as String?) ?? '').trim();
        tray.add({
          'id': 't${DateTime.now().microsecondsSinceEpoch}_$i',
          'text': note.isNotEmpty ? note : txt,
          'open': false, 'action': a, 'src': txt,
        });
      }
      set({'xfTray': tray});
    }
    if (sure.isNotEmpty) {
      // parsed = barcha amallar (xato tuzatishni o'rganish uchun)
      final ok = await _xcConfirm(txt, source, sure, actions);
      if (!ok) set({'voiceStage': null, 'vText': ''}); // xato — matn inputda qoladi
    } else {
      set({'voiceStage': null, 'vText': '', if (unsure.isNotEmpty) 'xarText': _xarTextIfSame(txt)});
      if (unsure.isNotEmpty) toast_(L()['tPickFolder']);
    }
  }

  // Inputni faqat yuborilgan matn O'ZGARMAGAN bo'lsa tozalaymiz — foydalanuvchi
  // parse davomida yangi jumla yoza boshlagan bo'lsa, yozayotgani o'chib ketmasin
  dynamic _xarTextIfSame(String sent) {
    final cur = ((S['xarText'] as String?) ?? '')
        .trim()
        .replaceAllMapped(RegExp(r'(\d) (?=\d)'), (m) => m[1]!);
    return cur == sent ? '' : S['xarText'];
  }

  // Yakuniy saqlash: daromad/xarajat -> expenses; qarz -> Hamkorlar oqimiga yo'naltiriladi
  Future<bool> _xcConfirm(String txt, String source,
      List<Map<String, dynamic>> finals, List<Map<String, dynamic>>? parsed) async {
    final r = await Api.confirmExpense(txt, source, finals, parsed: parsed);
    if (!r.ok) {
      toast_(r.error);
      return false;
    }
    final d = r.data as Map<String, dynamic>;
    // Yangi yozuv saqlandi — xarajat kvotasi hisoblagichi yangilansin
    unawaited(refreshSubs_(force: true));
    final saved = ((d['saved'] as List?) ?? []).cast<Map<String, dynamic>>();
    final routed = ((d['routed'] as List?) ?? []).cast<Map<String, dynamic>>();
    if (saved.isNotEmpty) {
      final es = saved.map(_mapExpense).toList();
      // Yangi papka belgisi ("Yangi ✨"): saqlashdan OLDIN mavjud bo'lmagan toifalar
      final existing = _xfFolders().map((f) => f['name']).toSet();
      final newCats = List<String>.from(S['xfNewCats'] as List);
      for (final e in es) {
        final c = e['cat'] as String;
        if (!existing.contains(c) && !newCats.contains(c)) newCats.add(c);
      }
      // Fly-animatsiya hodisalari: har yozuv o'z papkasiga "uchadi" (dizayn: flyToFolder).
      // MUHIM: yozuvlar xarEntries'ga DARHOL qo'shilmaydi — har biri chip QO'NGANDA
      // (xfLandOne_) alohida qo'shiladi; shunda papka raqami aynan qo'nish paytida sanaydi.
      final fly = List<Map<String, dynamic>>.from(S['xfFly'] as List);
      for (final e in es) {
        fly.add({
          'cat': e['cat'], 'emoji': xfEmoji(e['cat'] as String),
          'amtTxt': (e['kind'] == 'd' ? '+' : '−') + _fx(e['a'] as int),
          'inc': e['kind'] == 'd',
          'entry': e, // qo'nishda commit qilinadigan to'liq yozuv
        });
      }
      // Ghost-papka: yangi toifa kartasi chip uchishidan OLDIN nishon sifatida
      // paydo bo'ladi — chip "hech narsaga" uchib, papka keyin paydo bo'lishi tuzatildi
      final ghosts = Map<String, bool>.from((S['xfGhostCats'] as Map).cast<String, bool>());
      for (final e in es) {
        final c = e['cat'] as String;
        if (!existing.contains(c)) ghosts[c] = e['kind'] == 'd';
      }
      // Tartib MUZLATILADI (hali hech narsa qo'nmagan — joriy tartib olinadi):
      // chip o'z papkasining HOZIRGI o'rniga qo'nsin, grid sakramasin.
      // ??= — oldingi partiya hali muzlatgan bo'lsa, o'sha asl tartib qoladi.
      // Oldingi partiyaning kutayotgan taymeri bekor — yangi chiplar uchayotganda
      // otilib, grid ularning tagida siljib ketmasin; yangi qo'nishlar (yoki 8s
      // _landFallback) taymerni qaytadan boshlaydi.
      _xfReorderT?.cancel();
      _xfReorderT = null;
      _xfFrozenOrder ??= [for (final f in _xfFolders()) f['name'] as String];
      set({'xfNewCats': newCats, 'xfFly': fly, 'xfGhostCats': ghosts});
      // Zaxira: biror sabab bilan land bo'lmasa (ekran yopildi) — 8s dan keyin to'g'ridan-to'g'ri.
      // MUHIM (2026-08-02 audit): taymer maydonda saqlanadi va logout'da bekor qilinadi —
      // aks holda chiqishdan keyin ishga tushib, OLDINGI akkaunt xarajatlarini
      // yangi foydalanuvchi ekraniga qaytarib qo'yardi.
      _landFallback?.cancel();
      _landFallback = Timer(const Duration(seconds: 8), () {
        if (S['stage'] != 'app') return;
        for (final e in es) {
          xfLandOne_(e);
        }
      });
      for (final e in es) {
        _xfLogAdd('add',
            cat: e['cat'] as String,
            desc: (e['note'] as String?)?.isNotEmpty == true ? e['note'] as String : e['cat'] as String,
            amount: e['a'] as int, income: e['kind'] == 'd', id: e['id'] as String?);
      }
      // Dizayn toasti: "N ta yozuv saqlandi · X so'm" + Bekor qilish (saqlanganlarni o'chiradi)
      final total = es.fold<int>(0, (s, e) => s + (e['a'] as int));
      final ids = es.map((e) => e['id'] as String).toList();
      _xfToastShow({
        'text': Lf('xUndoSaved', {'n': '${es.length}', 'sum': '${_fx(total)}'}),
        'kind': 'add', 'ids': ids,
      });
    }
    // Matn AYNAN chip uchadigan framda tozalanadi — yozuv "inputdan uchib ketadi"
    set({'voiceStage': null, 'vText': '', 'xarText': _xarTextIfSame(txt)});
    if (routed.isNotEmpty) {
      // Xarajat menyusi qarzga ARALASHMAYDI (PO 2026-08-03): yo'naltirish ham,
      // "O'tish" tugmasi ham yo'q — faqat tugmasiz ogohlantirish toasti.
      // Qarz amallari xarajat bo'lib saqlanmaydi (server /confirm `routed` qaytaradi).
      _xfToastShow({'text': L()['tDebtUsePartners'], 'kind': 'warn'});
    }
    return true;
  }

  // Chip qo'nganda BITTA yozuvni kiritish — papka/balans raqamlari shu paytda sanaydi.
  // Idempotent: qayta chaqirilsa yoki undo qilingan bo'lsa hech narsa qilmaydi.
  final Set<String> _xfCancelledLand = {};
  void xfLandOne_(Map<String, dynamic> e) {
    // Har qo'nish (urinishi) qayta-tartib taymerini QAYTA boshlaydi — tartib
    // faqat oxirgi chip qo'nib, summa sanab bo'lgach (1000ms > _AnimNum 900ms)
    // bo'shatiladi. Ko'p chipli yuborishda ham BIR marta siljiydi.
    if (_xfFrozenOrder != null) {
      _xfReorderT?.cancel();
      _xfReorderT = Timer(const Duration(milliseconds: 1000), _xfUnfreeze);
    }
    final id = e['id'] as String?;
    if (id != null && _xfCancelledLand.contains(id)) return;
    if (id != null && _xar().any((x) => x['id'] == id)) return;
    // Ghost-karta haqiqiyga aylanadi — yozuv kiritildi
    final ghosts = Map<String, bool>.from((S['xfGhostCats'] as Map).cast<String, bool>());
    ghosts.remove(e['cat']);
    set({'xarEntries': [e, ..._xar()], 'xfGhostCats': ghosts});
  }

  // Muzlatishni bo'shatish: grid yangi (summa bo'yicha) tartibga BIR marta o'tadi.
  // Undo'da darhol chaqiriladi — yozuvlar o'chgach eski tartib o'z-o'zidan to'g'ri.
  void _xfUnfreeze() {
    _xfReorderT?.cancel();
    _xfReorderT = null;
    if (_xfFrozenOrder == null) return;
    // ESKI (ko'rinib turgan) tartib UI'ga BIR MARTALIK uzatiladi (flyEvents kabi):
    // ekran har karta eski o'rnidan yangi o'rniga SILJIB borishini ko'rsatadi —
    // joy almashuvi sezilarli bo'ladi, sakrash emas.
    final from = [for (final f in _xfFolders()) f['name'] as String];
    _xfFrozenOrder = null;
    set({'xfReorderFrom': from}); // Root rebuild — yangi tartib + siljish manbai
  }

  // Lokal (dizayn uslubidagi) toast — o'zi yopiladi (default 5s)
  void _xfToastShow(Map<String, dynamic> t, {int seconds = 5}) {
    set({'xfToast': t});
    _xfToastT?.cancel();
    _xfToastT = Timer(Duration(seconds: seconds), () => set({'xfToast': null}));
  }

  // Ko'chirish toasti (ekran _moveTo dan chaqiriladi) — Bekor qilish yozuvni
  // ESKI papkaga PATCH bilan qaytaradi; server o'rganish signalini ham teskari oladi.
  void xfMovedToast_({required String id, required String oldCat, required String newCat,
      required String desc, required int amount}) {
    _xfToastShow({
      'text': Lf('tMovedTo', {'cat': newCat}),
      'kind': 'moved', 'eid': id, 'old': oldCat, 'desc': desc, 'a': amount,
    });
  }

  // Zaxira: server parse yiqilganda lokal qoida-parser bilan eski oqim
  Future<void> _xarOffline(String txt) async {
    final f = xarParse_(txt);
    final a = int.tryParse(f['amount'] as String) ?? 0;
    if (a == 0) {
      set({'voiceStage': null, 'vText': ''});
      toast_(L()['tAmountUnclear']);
      return;
    }
    final r = await Api.addExpense(a, f['kind'] == 'd', f['cat'] as String, f['note'] as String);
    if (!r.ok) {
      set({'voiceStage': null, 'vText': ''});
      toast_(r.error);
      return;
    }
    final e = _mapExpense(r.data as Map<String, dynamic>);
    set({'xarEntries': [e, ..._xar()], 'voiceStage': null, 'vText': '', 'xarText': _xarTextIfSame(txt)});
    toast_(Lf('tAiCategorized', {'cat': '${f['cat']}'}));
  }

  // ---------- Chatdagi yozuvni inline tahrirlash (bubble bosilganda) ----------
  Future<void> _ensureXcCats() async {
    if ((S['xcCats'] as List).isNotEmpty) return;
    final c = await Api.categories();
    if (c.ok) set({'xcCats': (c.data as List).map((x) => (x as Map)['name'] as String).toList()});
  }

  void xEditOpen_(String id) {
    final e = _xar().firstWhere((x) => x['id'] == id, orElse: () => <String, dynamic>{});
    if (e.isEmpty) return;
    set({
      'xEditId': id,
      'xEditVals': {'kind': e['kind'], 'amount': '${e['a']}', 'cat': e['cat'], 'note': e['note'] ?? ''},
    });
    _ensureXcCats();
  }

  void xEditSet_(Map<String, dynamic> patch) {
    final v = Map<String, dynamic>.from((S['xEditVals'] as Map?) ?? {});
    set({'xEditVals': {...v, ...patch}});
  }

  void xEditClose_() => set({'xEditId': null, 'xEditVals': null});

  Future<void> xEditSave_() async {
    final id = S['xEditId'] as String?;
    final v = S['xEditVals'] as Map<String, dynamic>?;
    if (id == null || v == null) return;
    final amt = int.tryParse('${v['amount']}'.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    if (amt <= 0) {
      toast_(L()['tSum']);
      return;
    }
    if (_busy) return;
    _busy = true;
    final income = v['kind'] == 'd';
    final r = await Api.patchExpense(id,
        amount: amt, income: income, category: income ? 'Daromad' : (v['cat'] as String? ?? 'Boshqa'));
    _busy = false;
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    final e = _mapExpense(r.data as Map<String, dynamic>);
    set({
      'xarEntries': _xar().map((x) => x['id'] == id ? e : x).toList(),
      'xEditId': null, 'xEditVals': null,
    });
    toast_(L()['tUpdated']);
  }

  Future<void> xEditDelete_() async {
    final id = S['xEditId'] as String?;
    if (id == null) return;
    if (_busy) return;
    _busy = true;
    final r = await Api.deleteExpense(id);
    _busy = false;
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    set({'xarEntries': _xar().where((x) => x['id'] != id).toList(), 'xEditId': null, 'xEditVals': null});
    toast_(L()['tDeletedOk']);
  }

  // ================= Xarajatlar v2 — papka (folder) UI =================
  Timer? _xfToastT;

  // Papka tartibini MUZLATISH — xoreografiya: chip QO'NADI -> summa SANAYDI ->
  // KEYIN grid siljiydi. Fly-chiplar uchayotganda tartib eskicha qoladi; har
  // qo'nish taymerni qayta boshlaydi, shunda ko'p chipli yuborishda tartib faqat
  // OXIRGI chip qo'nib, count-up (_AnimNum 900ms) tugagach BIR marta yangilanadi.
  List<String>? _xfFrozenOrder; // muzlatilgan papka nomlari tartibi (null = erkin)
  Timer? _xfReorderT;

  static const _monFull = ['Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
    'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'];

  // Hafta kunlari — hub sarlavhasidagi «Iyul 2026 · payshanba» uchun.
  // DateTime.weekday: 1 = dushanba ... 7 = yakshanba.
  // _monFull kabi ATAYLAB faqat o'zbekcha (ilovada oy nomlari ham shunday).
  static const _wdFull = ['dushanba', 'seshanba', 'chorshanba', 'payshanba',
    'juma', 'shanba', 'yakshanba'];

  // Toifa -> emoji (dizayn KW ro'yxati + backend seed toifalari)
  static const _xfEmojiMap = {
    'oylik': '💼', 'biznes': '📈', 'boshqa kirim': '💰', 'daromad': '💰',
    'transport': '🚌', 'taksi': '🚕', 'kofe': '☕️', 'oziq-ovqat': '🍜',
    'kommunal': '💡', 'xaridlar': '🛍️', 'kiyim': '🛍️', 'salomatlik': '💊',
    "ko'ngilochar": '🎬', 'sport': '🏋️', 'kitoblar': '📚', 'uy': '🏠',
    'aloqa': '📱', "ta'lim": '🎓', 'talim': '🎓', 'boshqa': '📦',
    // 2026-08-04: real toifalar to'plami (CatIcon.glyphFor bilan sinxron)
    "sovg'a": '🎁', "to'y": '💍', 'marosim': '💍', 'dehqonchilik': '🌱',
    'remont': '🔧', 'avto': '🚗', "go'zallik": '✂️', 'hayvonot': '🐾',
    'bolalar': '👶', 'soliq': '🧾', 'ijara': '🔑', 'safar': '✈️',
    'sayohat': '✈️', 'kitob': '📚', 'telefon': '📱', 'internet': '📱',
    'choyxona': '🍵', 'qahva': '☕️',
  };

  // KALIT SO'Z zaxirasi — CatIcon._kw bilan SEMANTIK sinxron (papka glifi va
  // emoji bir ma'noda chiqsin); birinchi moslik g'olib.
  static const List<List<String>> _xfEmojiKw = [
    ["ta'lim", '🎓'], ['talim', '🎓'], ['kurs', '🎓'], ['maktab', '🎓'],
    ['sovg', '🎁'],
    ["to'y", '💍'], ['marosim', '💍'], ['nikoh', '💍'],
    ['sport', '🏋️'], ['fitnes', '🏋️'], ['zal', '🏋️'],
    ['dehqon', '🌱'], ["bog'", '🌱'], ['ekin', '🌱'],
    ['remont', '🔧'], ['usta', '🔧'], ["ta'mir", '🔧'],
    ['avto', '🚗'], ['mashina', '🚗'], ['benzin', '🚗'],
    ["go'zallik", '✂️'], ['gozallik', '✂️'], ['salon', '✂️'], ['soch', '✂️'],
    ['hayvon', '🐾'], ['mushuk', '🐾'],
    ['bola', '👶'], ['farzand', '👶'],
    ['soliq', '🧾'], ['jarima', '🧾'],
    ['ijara', '🔑'], ['arenda', '🔑'], ['kvartira', '🔑'],
    ['safar', '✈️'], ['sayohat', '✈️'],
    ['kitob', '📚'],
    ['telefon', '📱'], ['internet', '📱'], ['aloqa', '📱'],
    ['choy', '🍵'], ['kofe', '☕️'], ['qahva', '☕️'], ['kafe', '☕️'],
    ['taksi', '🚕'], ['transport', '🚌'],
    ['ovqat', '🍜'], ['oziq', '🍜'], ['bozor', '🍜'], ['market', '🍜'],
    ['kommunal', '💡'], ['svet', '💡'], ['gaz', '💡'],
    ['kiyim', '🛍️'], ['xarid', '🛍️'], ["do'kon", '🛍️'], ['dokon', '🛍️'],
    ['dori', '💊'], ['shifokor', '💊'], ['apteka', '💊'], ['salomatlik', '💊'],
    ['uy', '🏠'],
  ];

  String xfEmoji(String cat) {
    final n = _xfNorm(cat);
    final hit = _xfEmojiMap[n];
    if (hit != null) return hit;
    for (final e in _xfEmojiKw) {
      if (n.contains(e[0])) return e[1];
    }
    return '📁';
  }

  String _xfNorm(String s) => s.toLowerCase()
      .replaceAll('’', "'").replaceAll('ʻ', "'").replaceAll('`', "'").replaceAll('ʼ', "'");

  // 1234567 -> "1 234 567" (dizayndagi format; valyuta belgisi alohida ko'rsatiladi)
  String _fx(num v) {
    final s = v.abs().round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  // ---- DAVR FILTRI (2026-08-04): butun Xarajatlar ekrani tanlangan davr
  // bo'yicha ishlaydi (ilgari qat'iy joriy oy edi). [from, to) — lokal kun
  // boshlari; ikkalasi null = Jami (chegarasiz).
  List<DateTime?> _xfRange() {
    final p = (S['xfPeriod'] as Map?)?.cast<String, dynamic>() ?? const {'kind': 'month'};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch ('${p['kind']}') {
      case 'today':
        return [today, today.add(const Duration(days: 1))];
      case 'yesterday':
        return [today.subtract(const Duration(days: 1)), today];
      case 'week':
        final start = today.subtract(Duration(days: today.weekday - 1)); // dushanbadan
        return [start, start.add(const Duration(days: 7))];
      case 'all':
        return [null, null];
      case 'custom':
        final f = DateTime.tryParse('${p['from'] ?? ''}');
        final t = DateTime.tryParse('${p['to'] ?? ''}');
        if (f == null || t == null) return [null, null];
        return [
          DateTime(f.year, f.month, f.day),
          DateTime(t.year, t.month, t.day).add(const Duration(days: 1)),
        ];
      default: // month (standart)
        return [DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 1)];
    }
  }

  // Tanlangan davr yozuvlari (papka UI, balans, sub-daromadlar — hammasi shu manbadan)
  List<Map<String, dynamic>> _xfPeriodEntries() {
    final r = _xfRange();
    final from = r[0], to = r[1];
    if (from == null && to == null) return _xar();
    return _xar().where((e) {
      final ts = (e['ts'] as int?) ?? 0;
      if (ts == 0) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      if (from != null && d.isBefore(from)) return false;
      if (to != null && !d.isBefore(to)) return false;
      return true;
    }).toList();
  }

  // Davrga mos server so'rovi. from — davr boshidan 1 KUN OLDIN (superset):
  // sana-only satrni server UTC yarim tun deb o'qiydi, UZ(+5)da lokal kun boshi
  // UTC'da oldingi kunga tushadi — 1 kunlik zaxira bo'lmasa "Bugun"ning
  // 00:00-05:00 yozuvlari javobga kirmay qolardi (reviewer, 2026-08-04).
  // Aniq kesim baribir _xfPeriodEntries'da lokal qilinadi. limit 1000 — server
  // maksimumi; unga urilish xfSetPeriod_'da halol toast bilan bildiriladi.
  Future<ApiRes> _xfFetchExpenses() {
    final from = _xfRange()[0];
    if (from == null) return Api.expenses(limit: 1000);
    final f = from.subtract(const Duration(days: 1));
    return Api.expenses(from: f.toIso8601String().substring(0, 10), limit: 1000);
  }

  // Davrni almashtirish: darhol lokal qayta chizish (data swap — reorder
  // animatsiyasisiz), keyin server'dan to'liq davr yozuvlari tortiladi.
  Future<void> xfSetPeriod_(Map<String, dynamic> p) async {
    set({'xfPeriod': p});
    final r = await _xfFetchExpenses();
    if (!identical(S['xfPeriod'], p)) return; // davr yana almashgan — eskirgan javob
    if (!r.ok || r.data is! List) {
      if (!r.ok) toast_(r.error);
      return;
    }
    final list = (r.data as List).cast<Map<String, dynamic>>().map(_mapExpense).toList();
    set({'xarEntries': list});
    // 1000 ta server-cheklovga urilish — HAR davr uchun halol ogohlantirish
    // (katta oy/uzun custom ham jim kesilmasin; reviewer, 2026-08-04)
    if (list.length >= 1000) {
      toast_(Lf('fltTruncated', {'n': '1000'}));
    }
  }

  // Papkalar: joriy oy yozuvlaridan toifa bo'yicha.
  // #15 (Option C): DAROMAD — bitta QATTIQ papka. Barcha kirim yozuvlari shu papkada
  // yig'iladi (ichida @manba sub-guruhlar detail'da ko'rinadi). Har doim mavjud (bo'sh
  // bo'lsa ham) va ro'yxat BOSHIDA turadi. Chiqim papkalari — toifa bo'yicha, avvalgidek.
  List<Map<String, dynamic>> _xfFolders() {
    final map = <String, Map<String, dynamic>>{};
    // Qattiq Daromad papkasi — doim bor
    map['Daromad'] = {
      'name': 'Daromad', 'income': true, 'total': 0,
      'entries': <Map<String, dynamic>>[], 'hard': true,
    };
    for (final e in _xfPeriodEntries()) {
      final isInc = e['kind'] == 'd';
      // Kirim -> hammasi 'Daromad' papkasiga (sub-manba entry'ning o'z 'cat'ida saqlanadi);
      // chiqim -> o'z toifasiga.
      final key = isInc ? 'Daromad' : ((e['cat'] as String?) ?? 'Boshqa');
      final f = map.putIfAbsent(key,
          () => {'name': key, 'income': isInc, 'total': 0, 'entries': <Map<String, dynamic>>[]});
      f['total'] = (f['total'] as int) + (e['a'] as int);
      (f['entries'] as List).add(e);
    }
    // Ghost-papkalar: fly-chip uchayotganda nishon karta bo'lishi uchun — endi FAQAT chiqim
    // (kirim asosiy inputdan kelmaydi, shuning uchun ghost kirim papka kerak emas).
    for (final g in (S['xfGhostCats'] as Map).cast<String, bool>().entries) {
      if (g.value == true) continue; // kirim ghost — o'tkazib yuboramiz
      map.putIfAbsent(g.key, () =>
          {'name': g.key, 'income': false, 'total': 0, 'entries': <Map<String, dynamic>>[], 'ghost': true});
    }
    final list = map.values.toList();
    // Daromad BIRINCHI; qolganlari total bo'yicha kamayish tartibida.
    // MUZLATILGAN payt (chip uchmoqda / summa sanalmoqda): eski tartib saqlanadi,
    // muzlatishdan keyin tug'ilgan (ghost) papkalar oxiriga qo'shiladi — chip
    // nishoni bo'lib ko'rinadi, grid esa qimirlamaydi.
    final frozen = _xfFrozenOrder;
    list.sort((a, b) {
      if (a['name'] == 'Daromad') return -1;
      if (b['name'] == 'Daromad') return 1;
      if (frozen != null) {
        final ia = frozen.indexOf(a['name'] as String);
        final ib = frozen.indexOf(b['name'] as String);
        final ka = ia < 0 ? frozen.length : ia;
        final kb = ib < 0 ? frozen.length : ib;
        if (ka != kb) return ka - kb;
      }
      return (b['total'] as int).compareTo(a['total'] as int);
    });
    return list;
  }

  // #15v2: yozuv izohidan birinchi @teg ('@dokon') — kichik harflarda. Yo'q bo'lsa null.
  String? _incTag(String? note) {
    if (note == null || note.isEmpty) return null;
    final m = RegExp(r'@[^\s@]{1,20}').firstMatch(note);
    return m?.group(0)?.toLowerCase();
  }

  /// #15v2: sub-daromad papkalari (joriy oy): kirim (in), @chiqim (out), qoldiq (left).
  /// Manba: kirim yozuvlari cat='@nomi' + foydalanuvchi yaratgan bo'sh papkalar
  /// (xfIncSubsMade). Chiqim: izohida '@nomi' tegi bo'lgan xarajatlar.
  List<Map<String, dynamic>> _xfIncSubs() {
    final map = <String, Map<String, dynamic>>{}; // key: lowercase nom
    void ensure(String name) => map.putIfAbsent(
        name.toLowerCase(), () => {'name': name, 'in': 0, 'out': 0, 'n': 0});
    for (final s in (S['xfIncSubsMade'] as List).cast<String>()) {
      ensure(s);
    }
    for (final e in _xfPeriodEntries()) {
      if (e['kind'] == 'd') {
        final c = (e['cat'] as String?) ?? 'Daromad';
        if (!c.startsWith('@')) continue; // 'Daromad' umumiy — sub emas
        ensure(c);
        final f = map[c.toLowerCase()]!;
        f['in'] = (f['in'] as int) + (e['a'] as int);
        f['n'] = (f['n'] as int) + 1;
      } else {
        final tag = _incTag(e['note'] as String?);
        if (tag == null || !map.containsKey(tag)) continue;
        final f = map[tag]!;
        f['out'] = (f['out'] as int) + (e['a'] as int);
      }
    }
    final list = map.values.toList();
    for (final f in list) {
      f['left'] = (f['in'] as int) - (f['out'] as int);
    }
    list.sort((a, b) => (b['left'] as int).compareTo(a['left'] as int));
    return list;
  }

  // Dinamik sparkline (dizayn kabi): papkaning OXIRGI 8 yozuvi summalari — yangi yozuv
  // qo'shilganda chiziq siljiydi (rolling oyna). Kam yozuvda chapdan past qiymat bilan to'ldiriladi.
  List<double> _xfSpark(List entries) {
    final es = entries.cast<Map<String, dynamic>>().toList()
      ..sort((a, b) {
        // eski -> yangi: avval kun, bir kun ichida vaqt (HH:mm) bo'yicha
        final d = (b['days'] as int).compareTo(a['days'] as int);
        if (d != 0) return d;
        return ('${a['t']}').compareTo('${b['t']}');
      });
    final amts = es.map((e) => (e['a'] as int).toDouble()).toList();
    final last = amts.length > 8 ? amts.sublist(amts.length - 8) : amts;
    // DIQQAT: List.filled fixed-length qaytaradi — addAll qulatadi; spread bilan yig'amiz
    final vals = [...List<double>.filled(8 - last.length, 0.0), ...last];
    final m = vals.reduce(math.max);
    if (m <= 0) return List<double>.filled(8, 0.08);
    return vals.map((v) => v <= 0 ? 0.08 : (0.15 + (v / m) * 0.85)).toList();
  }

  // Sessiya jurnali (Oxirgi o'zgarishlar) — max 12
  void _xfLogAdd(String type,
      {required String cat, required String desc, required int amount, required bool income, String? id}) {
    final log = List<Map<String, dynamic>>.from(S['xfLog'] as List);
    log.insert(0, {
      'id': 'l${DateTime.now().microsecondsSinceEpoch}', 'type': type,
      'cat': cat, 'desc': desc, 'a': amount, 'income': income, 'eid': id,
      't': _hhmm(DateTime.now()),
    });
    set({'xfLog': log.take(12).toList(), if (S['xfLogOpen'] != true) 'xfLogDot': true});
  }

  // #15v2: OCHIQ sub-papka ichiga kirim qo'shish (summa + izoh). Kirimlar FAQAT
  // sub-papka ichidan kiritiladi (asosiy input xarajat-only). true = maydonni tozala.
  Future<bool> xfAddIncome_(String amountText, String noteText) async {
    final sub = S['xfIncSub'] as String?;
    if (sub == null) return false;
    final amt = int.tryParse(amountText.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    if (amt <= 0) { toast_(L()['tSum'] as String? ?? "Summa noto'g'ri"); return false; }
    if (_busy) return false;
    _busy = true;
    set({'xfIncBusy': true});
    final r = await Api.addExpense(amt, true, sub, noteText.trim());
    _busy = false;
    set({'xfIncBusy': false});
    if (!r.ok) { toast_(r.error); return false; }
    final e = _mapExpense(r.data as Map<String, dynamic>);
    set({'xarEntries': [e, ..._xar()]});
    _xfLogAdd('add', cat: sub, desc: noteText.trim().isNotEmpty ? noteText.trim() : sub,
        amount: amt, income: true, id: e['id'] as String?);
    toast_(L()['tSavedIncome'] as String? ?? 'Kirim saqlandi');
    return true;
  }

  /// #15v2: yangi sub-daromad papkasi. '@' avtomatik qo'shiladi, bo'sh joylar olib
  /// tashlanadi; mavjud bo'lsa (katta-kichik farqsiz) — o'shanisi ochiladi.
  Future<bool> xfIncSubCreate_(String raw) async {
    var n = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (n.isNotEmpty && !n.startsWith('@')) n = '@$n';
    if (n.length < 2 || n.length > 21) {
      toast_(L()['xfIncNameLen'] as String? ?? "Nom 1–20 belgi bo'lsin");
      return false;
    }
    // Mavjudmi? (yaratilganlar + kirimlardan hosil bo'lganlar)
    final existing = _xfIncSubs().where((f) => '${f['name']}'.toLowerCase() == n.toLowerCase()).toList();
    if (existing.isNotEmpty) {
      set({'xfIncSub': existing.first['name']});
      return true;
    }
    final made = List<String>.from(S['xfIncSubsMade'] as List);
    made.add(n);
    S['xfIncSubsMade'] = made;
    SharedPreferences.getInstance()
        .then((sp) => sp.setStringList('trust_inc_subs', made))
        .catchError((_) => false);
    set({'xfIncSub': n});
    return true;
  }

  /// #15v2: kirim yozuvini tahrirlash (summa + izoh). true = modal yopilsin.
  Future<bool> xfIncEditSave_(String id, String amountText, String noteText) async {
    final amt = int.tryParse(amountText.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    if (amt <= 0) { toast_(L()['tSum'] as String? ?? "Summa noto'g'ri"); return false; }
    if (_busy) return false;
    _busy = true;
    final r = await Api.patchExpense(id, amount: amt, note: noteText.trim());
    _busy = false;
    if (!r.ok) { toast_(r.error); return false; }
    final e = _mapExpense(r.data as Map<String, dynamic>);
    set({'xarEntries': _xar().map((x) => x['id'] == id ? e : x).toList()});
    toast_(L()['tUpdated'] as String? ?? 'Yangilandi');
    return true;
  }

  // Yuborish: tahrir rejimi / birlashtirish / papka o'chirish / oddiy parse
  Future<void> xfSend_() async {
    if (S['voiceStage'] == 'parsing') return; // parse ketmoqda — ikkilangan send yo'q
    // Ko'rinishdagi "400 000" formati parser uchun "400000" ga tozalanadi
    final raw = ((S['xarText'] as String?) ?? '').trim();
    final t = raw.replaceAllMapped(RegExp(r'(\d) (?=\d)'), (m) => m[1]!);
    if (t.isEmpty) {
      toast_(L()['tWriteSentence']);
      return;
    }
    final ed = S['xfEditing'] as Map<String, dynamic>?;
    if (ed != null) {
      set({'xarText': ''});
      return _xfEditSave(ed['id'] as String, t);
    }
    final low = _xfNorm(t);
    if (low.contains('birlashtir')) {
      set({'xarText': ''});
      return _xfMergeAsk(low);
    }
    if (low.contains('papka') && low.contains("o'chir")) {
      set({'xarText': ''});
      return _xfDelFolderAsk(low);
    }
    // Klaviatura DARHOL yopiladi — ekran kengayib, parvoz to'liq kuzatiladi.
    // Matn inputda rangli holicha KUTIB TURADI — chip uchgan framda tozalanadi
    // (_xcConfirm), shunda "yozuv inputdan uchib ketdi" hissi beriladi.
    FocusManager.instance.primaryFocus?.unfocus();
    await xarPick_(t, source: 'text');
  }

  // "Taksi xarajatlarini Transportga birlashtir" — matnda 2 papka nomini topamiz
  void _xfMergeAsk(String low) {
    final hits = <Map<String, dynamic>>[];
    for (final f in _xfFolders()) {
      final i = low.indexOf(_xfNorm(f['name'] as String));
      if (i >= 0) hits.add({'f': f, 'i': i});
    }
    hits.sort((a, b) => (a['i'] as int).compareTo(b['i'] as int));
    if (hits.length < 2) {
      toast_(L()['tSayTwoFolders']);
      return;
    }
    final fromF = hits[0]['f'] as Map<String, dynamic>;
    final toF = hits[1]['f'] as Map<String, dynamic>;
    if (fromF['income'] != toF['income']) {
      toast_("Kirim va chiqim papkalari birlashtirilmaydi");
      return;
    }
    set({'xfConfirm': {'kind': 'merge', 'from': fromF, 'to': toF}});
  }

  // "Taksi papkasini o'chir" — bitta papka nomi
  void _xfDelFolderAsk(String low) {
    for (final f in _xfFolders()) {
      if (low.contains(_xfNorm(f['name'] as String))) {
        set({'xfConfirm': {'kind': 'delf', 'from': f}});
        return;
      }
    }
    toast_(L()['tFolderNotFound']);
  }

  // Tasdiqlash kartasi: OK — birlashtirish yoki papka o'chirish
  Future<void> xfCfOk_() async {
    final c = S['xfConfirm'] as Map<String, dynamic>?;
    if (c == null) return;
    set({'xfConfirm': null});
    final from = c['from'] as Map<String, dynamic>;
    final ids = (from['entries'] as List).cast<Map<String, dynamic>>().map((e) => e['id'] as String).toList();
    // MUHIM (2026-08-02 audit): ilgari har bir so'rov natijasi E'TIBORSIZ qolardi va
    // UI shartsiz "bajarildi" deb ko'rsatardi. Zaif tarmoqda 11 tadan 4 tasi o'chib,
    // 7 tasi qolardi — foydalanuvchi "papka o'chdi" degan xabarni ko'rar, 15 soniyadan
    // keyin esa hydrate o'sha 7 ta yozuvni qaytarib, balansni ham ko'tarib qo'yardi.
    // Endi FAQAT muvaffaqiyatli id'lar lokal holatga qo'llanadi va toast rost gapiradi.
    final okIds = <String>[];
    if (c['kind'] == 'merge') {
      final to = c['to'] as Map<String, dynamic>;
      for (final id in ids) {
        final r = await Api.patchExpense(id, category: to['name'] as String);
        if (r.ok) okIds.add(id);
      }
      set({'xarEntries': _xar().map((x) => okIds.contains(x['id']) ? {...x, 'cat': to['name']} : x).toList()});
      _xfLogAdd('merge', cat: to['name'] as String, desc: "${from['name']} → ${to['name']}",
          amount: from['total'] as int, income: from['income'] == true);
      toast_(okIds.length == ids.length
          ? Lf('tMerged', {'from': '${from['name']}', 'to': '${to['name']}'})
          : '${okIds.length}/${ids.length} — qisman bajarildi');
    } else {
      for (final id in ids) {
        final r = await Api.deleteExpense(id);
        if (r.ok) okIds.add(id);
      }
      set({
        'xarEntries': _xar().where((x) => !okIds.contains(x['id'])).toList(),
        if (okIds.length == ids.length) 'xfDetail': null,
      });
      _xfLogAdd('del', cat: from['name'] as String, desc: "${from['name']} papkasi",
          amount: from['total'] as int, income: from['income'] == true);
      toast_(okIds.length == ids.length
          ? Lf('tDeletedName', {'name': '${from['name']}'})
          : '${okIds.length}/${ids.length} — qisman o\'chirildi');
    }
    if (okIds.length != ids.length) unawaited(hydrate(full: true));
  }

  void xfCfNo_() => set({'xfConfirm': null});

  // Yozuvni tahrirlash: input'ga joriy qiymat tushadi, yuborish -> PATCH
  void xfEditStart_(String id) {
    final e = _xar().firstWhere((x) => x['id'] == id, orElse: () => <String, dynamic>{});
    if (e.isEmpty) return;
    final label = (e['note'] as String?)?.isNotEmpty == true ? e['note'] : e['cat'];
    set({
      'xfEditing': {'id': id, 'label': label},
      'xarText': '${e['note'] ?? ''} ${e['a']}'.trim(),
      'xfLogOpen': false,
    });
  }

  void xfEditCancel_() => set({'xfEditing': null, 'xarText': ''});

  Future<void> _xfEditSave(String id, String t) async {
    set({'xfEditing': null});
    final f = xarParse_(t);
    final amt = int.tryParse(f['amount'] as String) ?? 0;
    if (amt <= 0) {
      toast_(L()['tSum']);
      return;
    }
    final r = await Api.patchExpense(id, amount: amt, note: f['note'] as String?);
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    final e = _mapExpense(r.data as Map<String, dynamic>);
    set({'xarEntries': _xar().map((x) => x['id'] == id ? e : x).toList()});
    _xfLogAdd('edit', cat: e['cat'] as String,
        desc: (e['note'] as String?)?.isNotEmpty == true ? e['note'] as String : e['cat'] as String,
        amount: e['a'] as int, income: e['kind'] == 'd', id: id);
    toast_(L()['tUpdated']);
  }

  // Yozuvni o'chirish — "Bekor qilish" (undo) bilan lokal toast
  Future<void> xfDelEntry_(String id) async {
    final e = _xar().firstWhere((x) => x['id'] == id, orElse: () => <String, dynamic>{});
    if (e.isEmpty) return;
    // #35: karta "o'chirilmoqda" holati — server javobi kelguncha spinner ko'rinadi
    final dl = List<String>.from(S['xfDeleting'] as List);
    if (dl.contains(id)) return; // ikkilangan bosish
    dl.add(id);
    set({'xfDeleting': dl});
    final r = await Api.deleteExpense(id);
    final dl2 = List<String>.from(S['xfDeleting'] as List)..remove(id);
    if (!r.ok) {
      set({'xfDeleting': dl2});
      toast_(r.error);
      return;
    }
    set({'xarEntries': _xar().where((x) => x['id'] != id).toList(), 'xfDeleting': dl2});
    _xfLogAdd('del', cat: e['cat'] as String,
        desc: (e['note'] as String?)?.isNotEmpty == true ? e['note'] as String : e['cat'] as String,
        amount: e['a'] as int, income: e['kind'] == 'd');
    _xfToastShow({'text': L()['tDeletedOk'], 'kind': 'del', 'entry': e});
  }

  // Toast tugmasi: del -> yozuv qayta qo'shiladi; add -> saqlanganlar o'chiriladi;
  // moved -> yozuv eski papkaga qaytariladi (warn turida tugma yo'q — o'zi yopiladi)
  Future<void> xfUndo_() async {
    final t = S['xfToast'] as Map<String, dynamic>?;
    _xfToastT?.cancel();
    set({'xfToast': null});
    if (t == null) return;
    if (t['kind'] == 'moved') {
      final r = await Api.patchExpense('${t['eid']}', category: '${t['old']}');
      if (!r.ok) {
        toast_(r.error);
        return;
      }
      // Server kanonik toifani qaytaradi (odatda eski nomning o'zi)
      final srvCat = ((r.data as Map?)?['category'] as String?) ?? '${t['old']}';
      set({
        'xarEntries': _xar()
            .map((e) => e['id'] == t['eid'] ? {...e, 'cat': srvCat} : e)
            .toList(),
      });
      _xfLogAdd('edit', cat: srvCat, desc: '${t['desc']}',
          amount: (t['a'] as int?) ?? 0, income: false, id: '${t['eid']}');
      toast_(Lf('tMovedTo', {'cat': srvCat}));
      return;
    }
    if (t['kind'] == 'del') {
      final e = t['entry'] as Map<String, dynamic>?;
      if (e == null) return;
      final r = await Api.addExpense(e['a'] as int, e['kind'] == 'd', e['cat'] as String, (e['note'] as String?) ?? '');
      if (!r.ok) {
        toast_(r.error);
        return;
      }
      final ne = _mapExpense(r.data as Map<String, dynamic>);
      set({'xarEntries': [ne, ..._xar()]});
      toast_(L()['tRestored']);
    } else if (t['kind'] == 'add') {
      final ids = (t['ids'] as List?)?.cast<String>() ?? [];
      _xfCancelledLand.addAll(ids); // hali qo'nmagan chip'lar keyin kirib qolmasin
      for (final id in ids) {
        await Api.deleteExpense(id);
      }
      // Bekor qilingan partiyaning kutayotgan ghost-kartalari ham tozalanadi
      set({'xarEntries': _xar().where((x) => !ids.contains(x['id'])).toList(), 'xfGhostCats': <String, bool>{}});
      _xfUnfreeze(); // yozuvlar o'chdi — eski (muzlatilgan) tartib o'z-o'zidan to'g'ri
      toast_(L()['tCancelled']);
    }
  }

  // ANIQLANMAGAN tray
  void xfTrayToggle_(String id) {
    set({
      'xfTray': (S['xfTray'] as List).cast<Map<String, dynamic>>()
          .map((t) => t['id'] == id ? {...t, 'open': t['open'] != true} : t).toList(),
    });
  }

  // createNew: AI taklifi yoki qo'lda yozilgan nom — serverda yangi papka yaratiladi
  // (/confirm accept_new_category), keyin ghost -> fly oqimi odatdagidek ishlaydi.
  Future<void> xfTrayPick_(String id, String cat, {bool createNew = false}) async {
    final tray = (S['xfTray'] as List).cast<Map<String, dynamic>>();
    final t = tray.firstWhere((x) => x['id'] == id, orElse: () => <String, dynamic>{});
    if (t.isEmpty) return;
    final a = Map<String, dynamic>.from(t['action'] as Map);
    a['category'] = cat;
    // 2026-08-03: har doim true — foydalanuvchi papkani O'ZI tanladi (bu "jimgina
    // yaratish" emas). Ilgari faqat createNew'da yuborilardi; tanlangan papka
    // categories jadvalida bo'lmasa (eski yozuvlardan qurilgan papka) server yozuvni
    // indamay 'Boshqa'ga tushirardi — foydalanuvchi tanlagan toifa "yo'qolardi".
    a['accept_new_category'] = true;
    set({'xfTray': tray.where((x) => x['id'] != id).toList()});
    // confirm orqali saqlaymiz — parsed bilan birga (lug'at o'rganadi: keyingi safar AI o'zi topadi)
    await _xcConfirm(t['src'] as String, 'text', [a], [Map<String, dynamic>.from(t['action'] as Map)]);
  }

  Future<void> limSave_() async {
    final v = int.tryParse((S['limEdit'] ?? '') as String) ?? 0;
    if (v == 0) {
      toast_(L()['tSum']);
      return;
    }
    final r = await Api.setLimit(v);
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    set({'xarLimit': v, 'limEdit': null});
    toast_(L()['tLimitUpdated']);
  }

  // ---------------- Onboarding — real OTP (SMS) ----------------
  Future<void> phoneNext_() async {
    final ccOnb = ccEntry(S['onbCc']);
    if ((S['phone'] as String).length != ccOnb['len']) {
      toast_(L()['tNum']);
      return;
    }
    if (_busy) return;
    _busy = true;
    _setBusy('phone');
    toast_(L()['tSendingCode']);
    final r = await Api.sendOtp('${S['onbCc']}${S['phone']}');
    _busy = false;
    _setBusy(null);
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    set({'stage': 'otp', 'otpVal': ''});
    toast_(L()['tSmsSent']);
  }

  Future<void> otpConfirm_() async {
    if ((S['otpVal'] as String).length != 5) {
      toast_(L()['tEnterCode']);
      return;
    }
    if (_busy) return;
    _busy = true;
    _setBusy('otp');
    toast_(L()['tChecking']);
    final r = await Api.verifyOtp('${S['onbCc']}${S['phone']}', S['otpVal'] as String);
    if (!r.ok) {
      _busy = false;
      _setBusy(null);
      set({'otpVal': ''});
      toast_(r.error);
      return;
    }
    await _loginSuccess(r.data as Map<String, dynamic>);
    PushService.sync(); // FCM tokenni yangi akkauntga bog'laymiz (fire-and-forget)
    _busy = false;
    _setBusy(null);
    set({'stage': 'pin', 'pinVal': '', 'pinMode': 'set'}); // yangi kirish — PIN o'rnatiladi
  }

  void logout_() {
    _poll?.cancel();
    _supPoll?.cancel();
    // MUHIM: Api.saveToken(null) dan OLDIN — push token serverdan uziladi
    // (shu qurilmada boshqa akkaunt kirsa, bu akkauntning push'i kelmasin)
    PushService.unregister();
    Api.saveToken(null);
    SecureStore.writeMe(null, null); // shaxsiyat keshini ham tozalaymiz
    SecureStore.clearPin(); // keyingi kirishda PIN qaytadan o'rnatiladi
    _subsAtMs = 0; // yangi akkaunt kirsa modul holati DARHOL qayta so'ralsin
    _hubModsAtMs = 0; // ... modul kartalaridagi summa ham
    _landFallback?.cancel(); // chiqishdan keyin eski akkaunt yozuvlarini qaytarmasin
    _xfReorderT?.cancel(); // muzlatilgan papka tartibi ham eski akkauntdan qolmasin
    _xfFrozenOrder = null;
    set({
      'stage': 'welcome', 'phone': '', 'otpVal': '', 'pinVal': '',
      'screen': 'hub', 'clientId': null, 'receiptId': null, 'sheetOpen': false,
      'notifOpen': false, 'linkDecisionId': null, 'rejOpen': false,
      'archOpen': false, 'langOpen': false,
      'inLinkId': null, 'inLinkOps': <Map<String, dynamic>>[],
      'links': <Map<String, dynamic>>[],
      'clients': <Map<String, dynamic>>[], 'txs': <Map<String, dynamic>>[],
      'msgs': <String, List<Map<String, dynamic>>>{}, 'localMsgs': <String, List<Map<String, dynamic>>>{},
      'notifs': <Map<String, dynamic>>[], 'xarEntries': <Map<String, dynamic>>[],
      'xarLimit': 0, 'pMeta': <String, String>{},
      'supportOpen': false, 'supportMsgs': <Map<String, dynamic>>[], 'supportInput': '',
      'meId': null, 'mePhone': null, 'meName': null, 'meNameEdit': null, 'meNo': null,
      'subStatus': 'free', 'trialEnd': null, 'premUntil': null,
      'debtsUsed': null, 'expensesUsed': null,
      // Modul obunalari boshqa akkauntdan qolib ketmasin
      'modSubs': <Map<String, dynamic>>[], 'modSubsLegacy': false, 'paywall': null,
      // Modul summalari ham ketadi — chiqqandan keyin eski akkauntning puli
      // bir lahzaga bo'lsa ham yangi bosh ekranda turmasin.
      'hubIjaraSum': null, 'hubToySum': null,
      'meAvatar': null, // shu qurilmada boshqa user kirsa avvalgi rasm ko'rinmasin
      // Trust AI suhbati — shaxsiy ma'lumot: qurilmada boshqa user kirsa ko'rinmasin
      'aiMsgs': <Map<String, dynamic>>[], 'aiInput': '', 'aiLoaded': false,
      'aiLoading': false, 'aiError': null, 'aiSending': false, 'aiSendErr': null,
      'aiLastText': null, 'aiLimited': false, 'aiLimitKind': null,
    });
    SharedPreferences.getInstance().then((sp) => sp.remove('trust_avatar'));
  }

  // ================= YORDAM CHATI (support -> Telegram) =================
  Timer? _supPoll;
  List<Map<String, dynamic>> _supMsgs() => (S['supportMsgs'] as List).cast<Map<String, dynamic>>();

  Future<void> openSupport_() async {
    set({'supportOpen': true});
    final r = await Api.supportMessages();
    if (r.ok && r.data is List) {
      set({'supportMsgs': (r.data as List).cast<Map<String, dynamic>>()});
    } else if (!r.ok) {
      toast_(r.error);
    }
    _supPoll?.cancel();
    // Chat ochiq ekan — 4s realtime polling (partner chati naqshi bilan bir xil)
    _supPoll = Timer.periodic(const Duration(seconds: 4), (_) => _supTick());
  }

  void closeSupport_() {
    _supPoll?.cancel();
    set({'supportOpen': false});
  }

  Future<void> _supTick() async {
    if (S['supportOpen'] != true) {
      _supPoll?.cancel();
      return;
    }
    final before = _supMsgs();
    final after = before.isEmpty ? null : before.last['created_at'] as String?;
    final r = await Api.supportMessages(after: after);
    if (!(r.ok && r.data is List && (r.data as List).isNotEmpty)) return;
    // MUHIM (2026-08-02 audit): ro'yxat AWAIT'dan KEYIN qayta o'qiladi va id bo'yicha
    // dublikat filtrlanadi. Ilgari `before` (eski surat) ustiga qo'shilardi, shu bois
    // polling oynasida yuborilgan xabar chatda IKKI MARTA ko'rinardi.
    final cur = _supMsgs();
    final seen = cur.map((m) => '${m['id']}').toSet();
    final fresh = (r.data as List)
        .cast<Map<String, dynamic>>()
        .where((m) => !seen.contains('${m['id']}'))
        .toList();
    if (fresh.isEmpty) return;
    set({'supportMsgs': [...cur, ...fresh]});
  }

  Future<void> sendSupport_() async {
    final t = (S['supportInput'] as String).trim();
    if (t.isEmpty) return;
    set({'supportInput': ''});
    final r = await Api.sendSupport(t);
    if (r.ok && r.data is Map) {
      final row = (r.data as Map).cast<String, dynamic>();
      final cur = _supMsgs();
      if (cur.any((m) => '${m['id']}' == '${row['id']}')) return; // polling ulgurgan
      set({'supportMsgs': [...cur, row]});
    } else {
      set({'supportInput': t}); // yuborilmadi — matn yo'qolmasin
      toast_(r.error);
    }
  }

  /// FOREGROUND FCM data payload (push arrived while the app is open, NOT
  /// tapped): the partner-card badge must appear within a second — optimistic
  /// bump from `data` (partner_id / amount / currency), then a silent
  /// hydrate(full:false) reconciles with the server counts.
  void pushArrived_(Map<String, dynamic> d) {
    final pid = '${d['partner_id'] ?? ''}';
    final type = '${d['type'] ?? ''}';
    // Bump only for types the /counts endpoint actually counts (else the next
    // poll would remove the badge). Typeless data pushes still bump — hydrate
    // reconciles within a second either way.
    final isBadgeEvent = type.isEmpty || _badgeTypes.contains(type);
    if (pid.isNotEmpty && isBadgeEvent) {
      if (S['clientId'] == pid || S['inLinkId'] == pid) {
        // That 1:1 ledger is open — the user sees the event live (4s ledger
        // poll). Keep it read server-side instead of flashing a badge later.
        unawaited(Api.readPartnerNotifs(pid));
      } else {
        set({
          'notifCounts': bumpNotifCounts(S['notifCounts'] as Map, pid,
              amount: num.tryParse('${d['amount'] ?? ''}'),
              currency: d['currency'] as String?),
        });
      }
    }
    if (S['stage'] == 'app') unawaited(hydrate(full: false));
  }

  /// Bildirishnoma bosilganda marshrutlash (link modeli)
  /// Push BOSILGANDA: FCM `data` ni ichki bildirishnoma shakliga o'giradi va ochadi.
  /// (2026-08-02 audit: ilgari bosish umuman qayta ishlanmasdi.)
  Future<void> openFromPush(Map<String, dynamic> d) async {
    // Ilova hali tayyor bo'lmasa — tayyor bo'lguncha kutamiz (maks. ~10s)
    for (var i = 0; i < 20 && S['stage'] != 'app'; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (S['stage'] != 'app') return;
    final type = '${d['type'] ?? ''}';
    if (type == 'support') { unawaited(openSupport_()); return; }
    await openFromNotif({
      'id': null,
      'kind': _notifKind[type] ?? 'confirmed',
      'link': d['link_id'],
      'circle': d['circle_id'],
      'tx': d['operation_id'],
    });
  }

  Future<void> openFromNotif(Map<String, dynamic> n) async {
    final nid = n['id'] as String?;
    if (nid != null) Api.readNotif(nid); // fire-and-forget (push'dan kelganda id yo'q)
    set({'notifs': _notifs().map((x) => x['id'] == n['id'] ? {...x, 'unread': false} : x).toList()});
    final kind = n['kind'] as String?;
    final linkId = n['link'] as String?;
    final opId = n['tx'] as String?;

    // Circle hodisasi -> yuklab, taklif bo'lsa Join, aks holda detal
    final circleId = n['circle'] as String?;
    if (circleId != null) {
      await loadCircles(force: true);
      final c = circlesRepo.byId(circleId);
      if (c == null) { set({'notifOpen': false}); return; }
      set({'notifOpen': false, 'circleId': circleId,
           if (c.myStatus == 'invited') 'circleJoinOpen': true else 'circleOpen': true});
      return;
    }

    // Yangi bog'lanish so'rovi -> qaror sheet'i (minimal preview)
    if (kind == 'linknew' && linkId != null) {
      final kr = await Api.links();
      if (kr.ok && kr.data is List) {
        set({'links': (kr.data as List).cast<Map<String, dynamic>>().map(_mapLink).toList()});
      }
      final l = _link(linkId);
      if (l == null) {
        toast_(L()['tLinkNotFound']);
        return;
      }
      if (l['status'] == 'pending') {
        set({'linkDecisionId': linkId});
      } else if (l['status'] == 'accepted') {
        openIncoming(linkId);
      } else {
        toast_(L()['tLinkRejectedRestore']);
      }
      return;
    }

    // Yangi/tuzatilgan yozuv (qabul qilingan bog'lanishda) -> sotuvchi daftari
    if (kind == 'opnew' && linkId != null) {
      final l = _link(linkId);
      if (l != null && l['status'] == 'accepted') {
        openIncoming(linkId);
      } else if (opId != null && _tx(opId) != null) {
        set({'receiptId': opId});
      }
      return;
    }

    // Mijoz qabul qildi / rad etdi (sotuvchiga) -> hamkor sahifasi
    if ((kind == 'linkacc' || kind == 'linkrej') && linkId != null) {
      hydrate(full: false);
      if (_client(linkId) != null) {
        set({'notifOpen': false, 'clientId': linkId, 'tab': 'chat', 'cMenuOpen': false, 'cRen': null, 'pProfOpen': false, 'opsVis': 8});
        openLedger_(linkId); // qarz daftari
      } else {
        set({'notifOpen': false});
      }
      return;
    }

    // Xabar (chat) bildirishnomasi — chat UI vaqtincha yashirin (flags.dart kChatEnabled=false):
    // yuqorida o'qilgan deb belgilandi; HECH QAYERGA olib bormaymiz (panel ochiq qoladi).
    if (kind == 'msg') return;

    // Qarz daftari bildirishnomasi -> tegishli hamkor daftari
    if (kind == 'debt' && linkId != null) {
      if (_client(linkId) != null) {
        set({'notifOpen': false, 'clientId': linkId, 'inLinkId': null, 'tab': 'chat',
             'cMenuOpen': false, 'cRen': null, 'pProfOpen': false, 'opsVis': 8});
        openLedger_(linkId);
      } else if (_link(linkId)?['status'] == 'accepted') {
        openIncoming(linkId);
      } else {
        set({'notifOpen': false});
      }
      return;
    }

    // Eslatma yoki eski turdagi yozuvlar
    if (opId != null && _tx(opId) != null) {
      set({'receiptId': opId});
      return;
    }
    set({'notifOpen': false});
  }

  // ================= BOSH HUB (ildiz ekran) =================
  // Dizayn: prototype/bosh-ekran.dc.html «4-tur» (Asosiy Light/Dark, Bo'sh holat).
  // Barcha qiymat REAL ma'lumotdan hosil qilinadi: xarEntries (xarajat kartasi),
  // clients + txs + links (oldi-berdi kartasi), aiMsgs (Trust AI kartasi).
  // Mock raqam YO'Q — bo'sh/yuklanish holatlari ham real holatdan kelib chiqadi.

  /// Hub'ga qaytish — bo'lim ichidagi holatlar ham tozalanadi.
  void goHub_() {
    // Modul ekranidan qaytyapmizmi — hub kartasidagi summa ESKIRGAN bo'lishi
    // mumkin (foydalanuvchi endigina hisob-kitob/bron qo'shdi yoki to'lov
    // yozdi). Fon polling'i 60s throttle bilan ishlaydi, ya'ni raqam bir
    // daqiqagacha eski qolardi — «kirdim, qo'shdim, chiqdim, o'zgarmadi».
    // Shuning uchun AYNAN shu o'tishda majburiy yangilaymiz. Modul ekranlari
    // boshqa sessiya egaligida, shu bois hook o'sha fayllarga emas, shu yerga
    // qo'yilgan. So'rov fon rejimida: yiqilsa hech narsa ko'rinmaydi.
    final fromModule = S['screen'] == 'ijara' || S['screen'] == 'toyxona';
    set({
      'screen': 'hub', 'clientId': null, 'receiptId': null, 'inLinkId': null,
      'xfDetail': null, 'xfLogOpen': false,
    });
    if (fromModule) unawaited(refreshHubMods_(force: true));
  }

  /// Android apparat "orqaga": bo'lim ekranidan hub'ga qaytish mumkinmi?
  /// FAQAT toza holatda ushlaymiz — ustida overlay/sheet/daftar ochiq bo'lsa,
  /// tugma tizim ixtiyorida qoladi (avvalgi xatti-harakat o'zgarmaydi).
  /// Hub ustida biror overlay/sheet/daftar ochiqmi (apparat "orqaga" ular
  /// ixtiyorida qoladi — ochiq qatlam avval yopiladi).
  bool _anyLayerOpen() =>
      S['ccOpen'] != null ||
      S['langOpen'] == true ||
      S['paywall'] != null ||
      S['linkDecisionId'] != null ||
      S['clientId'] != null ||
      S['inLinkId'] != null ||
      S['receiptId'] != null ||
      S['notifOpen'] == true ||
      S['archOpen'] == true ||
      S['rejOpen'] == true ||
      S['pdfOpen'] == true ||
      S['sheetOpen'] == true ||
      S['npOpen'] == true ||
      S['editFormOpen'] == true ||
      S['xfDetail'] != null ||
      S['xEditId'] != null ||
      S['circleOpen'] == true ||
      S['circleCreateOpen'] == true ||
      S['circleHistoryOpen'] == true ||
      S['circleManageOpen'] == true ||
      S['circleJoinOpen'] == true ||
      S['circlePayOpen'] == true ||
      S['circleConfirmOpen'] == true ||
      S['circleInviteOpen'] == true;

  bool hubBackable() {
    if (S['stage'] != 'app') return false;
    if (S['screen'] == 'hub') return false;
    return !_anyLayerOpen();
  }

  /// Ochiq eng YUQORI qatlamni yopadi. true = biror narsa yopildi.
  ///
  /// MUHIM (2026-08-02 audit): Android'ning apparat "orqaga" tugmasi ilgari
  /// overlay ochiq bo'lganda TIZIM ixtiyoriga qolardi. Ilovada bitta route
  /// bo'lgani uchun tizim buni "ilovadan chiqish" deb tushunardi: foydalanuvchi
  /// hamkor daftarini ochib, orqaga bosardi va ILOVA YOPILARDI (chekni ko'rish,
  /// bildirishnomalar paneli, PDF ko'rinishi va h.k. — hammasida shunday edi).
  bool closeTopLayer_() {
    // Tartib: eng ustki (sheet/dialog) -> pastki (ekran qatlami)
    // Modul paywall'i — main.dart'da z:64, ya'ni cc (z:60) va til (z:62) sheetlaridan
    // USTIDA chiziladi, shuning uchun birinchi bo'lib SHU yopiladi (review 2026-08-04 #4:
    // ilgari cc/til birinchi turardi — 402 til varag'i ochiq turib kelsa, "orqaga"
    // ko'rinmayotgan varaqni yopar va foydalanuvchiga HECH NARSA o'zgarmagandek tuyulardi).
    // Ilgari paywall bu ro'yxatda UMUMAN yo'q edi: hub ildizida u ochiq bo'lsa "orqaga"
    // "yana bosing — chiqadi"ga tushardi va ikkinchi bosishda ILOVA YOPILARDI.
    if (S['paywall'] != null) { set({'paywall': null}); return true; }
    if (S['ccOpen'] != null) { set({'ccOpen': null}); return true; }
    if (S['langOpen'] == true) { set({'langOpen': false}); return true; }
    if (S['circleInviteOpen'] == true) { set({'circleInviteOpen': false}); return true; }
    if (S['circleConfirmOpen'] == true) { set({'circleConfirmOpen': false}); return true; }
    if (S['circlePayOpen'] == true) { set({'circlePayOpen': false}); return true; }
    if (S['circleJoinOpen'] == true) { set({'circleJoinOpen': false}); return true; }
    if (S['circleManageOpen'] == true) { set({'circleManageOpen': false}); return true; }
    if (S['circleHistoryOpen'] == true) { set({'circleHistoryOpen': false}); return true; }
    if (S['circleCreateOpen'] == true) { set({'circleCreateOpen': false}); return true; }
    if (S['circleOpen'] == true) { set({'circleOpen': false}); return true; }
    if (S['editFormOpen'] == true) { set({'editFormOpen': false}); return true; }
    if (S['xEditId'] != null) { set({'xEditId': null}); return true; }
    if (S['sheetOpen'] == true) { set({'sheetOpen': false}); return true; }
    if (S['npOpen'] == true) { set({'npOpen': false}); return true; }
    if (S['linkDecisionId'] != null) { set({'linkDecisionId': null}); return true; }
    if (S['pdfOpen'] == true) { set({'pdfOpen': false}); return true; }
    if (S['receiptId'] != null) { set({'receiptId': null}); return true; }
    if (S['xfDetail'] != null) { set({'xfDetail': null}); return true; }
    if (S['notifOpen'] == true) { set({'notifOpen': false}); return true; }
    if (S['archOpen'] == true) { set({'archOpen': false}); return true; }
    if (S['rejOpen'] == true) { set({'rejOpen': false}); return true; }
    if (S['supportOpen'] == true) { closeSupport_(); return true; }
    if (S['clientId'] != null || S['inLinkId'] != null) {
      stopLedgerPoll_();
      set({'clientId': null, 'inLinkId': null, 'cMenuOpen': false, 'cRen': null, 'pProfOpen': false});
      return true;
    }
    return false;
  }

  /// Apparat "orqaga" biror qatlamni yopishi kerakmi?
  bool layerOpen() => S['stage'] == 'app' && _anyLayerOpen();

  // ---------------- Modul ekranlarining O'Z qatlamlari ----------------
  // Ijaradagi uylar / To'yxona kabi modullar butun holatini O'Z State'ida
  // saqlaydi (uy tafsiloti, forma modallari, oy menyusi) — store ularni
  // KO'RMAYDI, ya'ni _anyLayerOpen() ham, closeTopLayer_() ham ular haqida
  // hech narsa bilmaydi. Natijasi (review 2026-08-04, FINDING 2 — MEDIUM):
  // "Yangi to'lov" formasi ochiq, summa yozilgan holatda apparat "orqaga"
  // BUTUN modulni yopib, kiritilgan ma'lumotni yo'qotardi; uy tafsilotidan
  // bosilganda esa ro'yxatga emas, hub'ga chiqib ketardi.
  //
  // Yechim — modul o'zining "eng ustki qatlamni yop" funksiyasini SHU YERGA
  // yozadi, Root PopScope (main.dart) esa hub'ga qaytishdan OLDIN uni chaqiradi.
  // handleSystemBack: true QILINMAYDI — ikkinchi PopScope bir bosishda ikki
  // qavat orqaga ketardi (main.dart izohi).
  //
  // MODUL SHARTNOMASI (To'yxona ham AYNAN shu ikki qatorni qo'shadi):
  //   initState: store.setModuleBack_(_closeTop);
  //   dispose  : store.clearModuleBack_(_closeTop);
  // `_closeTop()` -> true = qatlam yopildi (modul ichida qolamiz),
  //                  false = yopiladigan narsa yo'q (hub'ga qaytiladi).
  bool Function()? moduleBack;

  /// Modul ekrani o'z qatlam-yopgichini ro'yxatdan o'tkazadi (initState).
  void setModuleBack_(bool Function() fn) => moduleBack = fn;

  /// dispose: FAQAT o'zinikini tozalaydi. Bir moduldan boshqasiga o'tishda
  /// yangi ekranning initState'i eskisining dispose'idan OLDIN ishlashi mumkin —
  /// shartsiz null qilinsa yangi ro'yxatdan o'tish o'chib ketardi.
  void clearModuleBack_(bool Function() fn) {
    if (moduleBack == fn) moduleBack = null;
  }

  /// Apparat "orqaga": modulning ochiq qatlamini yopishga urinish.
  /// true = yopildi, hub'ga qaytilmaydi.
  bool tryModuleBack_() => moduleBack?.call() ?? false;

  /// Hub ildizida (bo'lim/overlay/sheet yo'q) — apparat "orqaga" bu holatda
  /// darhol chiqarmaydi: 2 soniya ichida yana bosilsagina ilova yopiladi.
  bool atHubRoot() =>
      S['stage'] == 'app' && S['screen'] == 'hub' && !_anyLayerOpen();

  // Ranglarni ekranning o'zi theme.dart'dan (curPal) oladi — bu yerda faqat
  // matn/raqam/holat. Asosiy raqamlar UZS'da; oldi-berdi kartasi qo'shimcha
  // ravishda chet valyuta netlarini alohida qatorlarda ko'rsatadi (hubDebtFx,
  // PO 2026-07-17) — to'liq ko'p-valyutali ko'rinish Hamkorlar bo'limida qoladi.
  Map<String, dynamic> _hubVals(
    String Function(String) initials, {
    required List<Map<String, dynamic>> linksAll,
    required Map<String, int> Function(String) bal,
  }) {
    final L0 = L();
    final now = DateTime.now();
    final entries = _xar();
    final txs = _txs(); // ts bo'yicha o'sish tartibida (hydrate shunday saralaydi)
    final partners = _clients().where((c) => c['archived'] != true).toList();
    final accepted = linksAll.where((l) => l['status'] == 'accepted').toList();
    // Menga kelgan, hali qabul qilinmagan bog'lanish so'rovlari (ikki-tomonlama qabul).
    final pendingIn = linksAll.where((l) => l['status'] == 'pending').toList();

    // ---- Salomlashuv + sana («Xayrli tong, Aziz» / «Iyul 2026 · payshanba») ----
    // Salomlashuv ismi FAQAT haqiqiy ismdan olinadi — ismsiz foydalanuvchida
    // telefon raqami ism o'rniga chiqmasligi uchun (meLabel() fallback beradi).
    final full = meLabel().trim();
    final nameOnly = (S['meName'] as String?)?.trim() ?? '';
    final first = nameOnly.isEmpty ? '' : nameOnly.split(RegExp(r'\s+')).first;
    final greetKey = now.hour < 12
        ? 'hubGreetMorning'
        : now.hour < 18
            ? 'hubGreetDay'
            : now.hour < 22
                ? 'hubGreetEve'
                : 'hubGreetNight';

    // ---- Obuna mikro-nishoni (Sinov · N kun / Premium) ----
    final subSt = S['subStatus'] as String? ?? 'trial';
    final subEndRaw = subSt == 'premium' ? S['premUntil'] : S['trialEnd'];
    final subEnd = subEndRaw is String ? DateTime.tryParse(subEndRaw)?.toLocal() : null;
    var trialDays = -1;
    if (subEnd != null) {
      trialDays = subEnd.difference(now).inDays + 1; // SubInfo/profRows bilan bir xil hisob
      if (trialDays < 0) trialDays = 0;
      if (subSt == 'trial' && trialDays > 7) trialDays = 7;
    }

    // ---- XARAJAT kartasi: joriy oy ----
    final ym = '${now.year}-${now.month}';
    final pm = DateTime(now.year, now.month - 1, 1); // o'tgan oy (yil chegarasini o'zi hal qiladi)
    final pym = '${pm.year}-${pm.month}';
    final monthEx = entries.where((e) => e['ym'] == ym && e['kind'] == 'x').toList();
    final prevEx = entries.where((e) => e['ym'] == pym && e['kind'] == 'x').toList();
    final monthOut = monthEx.fold<int>(0, (s, e) => s + (e['a'] as int));

    // Sparkline: joriy oyning har kuni bo'yicha xarajat (1-kundan bugungacha).
    // Nol kunlar ham qoladi — chiziq oyning haqiqiy shakli bo'lsin.
    final daily = List<double>.filled(now.day, 0.0);
    for (final e in monthEx) {
      final d = (e['dom'] as int?) ?? 1;
      if (d >= 1 && d <= now.day) daily[d - 1] += (e['a'] as int).toDouble();
    }

    // Trend qatori («Transport +25%»): joriy oyda eng ko'p ketgan toifa,
    // o'tgan oyning SHU toifasi bilan solishtiriladi. O'tgan oyda bo'lmasa — yashiriladi.
    final catNow = <String, int>{};
    for (final e in monthEx) {
      final c = (e['cat'] as String?) ?? 'Boshqa';
      catNow[c] = (catNow[c] ?? 0) + (e['a'] as int);
    }
    String topCat = '';
    var topVal = 0;
    catNow.forEach((c, v) {
      if (v > topVal) {
        topVal = v;
        topCat = c;
      }
    });
    var trendTxt = '';
    var trendUp = true;
    if (topCat.isNotEmpty) {
      final prevVal = prevEx
          .where((e) => ((e['cat'] as String?) ?? 'Boshqa') == topCat)
          .fold<int>(0, (s, e) => s + (e['a'] as int));
      if (prevVal > 0) {
        final pct = ((topVal - prevVal) / prevVal * 100).round();
        trendUp = pct >= 0;
        trendTxt = '$topCat ${pct >= 0 ? '+' : '−'}${pct.abs()}%';
      }
    }

    // «Qoldi: +N» — oylik chegara qoldig'i (chegara qo'yilmagan bo'lsa qator yashirinadi)
    final lim = S['xarLimit'] as int;
    final limLeft = lim - monthOut;

    // Bugungi xarajat («Bugun: −12 000»)
    final todayOut = entries
        .where((e) => e['kind'] == 'x' && (e['days'] as int) == 0)
        .fold<int>(0, (s, e) => s + (e['a'] as int));

    // ---- OLDI-BERDI kartasi ----
    // Har valyuta bo'yicha net (PO 2026-07-17): asosiy raqam UZS bo'lib qoladi,
    // nol bo'lmagan chet valyutalar (masalan USD) kartada alohida qator bo'ladi.
    // «Faol qarz» endi valyutadan qat'i nazar sanaladi — faqat-USD qarz ham faol.
    var toMe = 0, activeDebts = 0;
    final fxNet = <String, int>{}; // UZS'dan boshqa valyutalar: kod -> net summa
    for (final c in partners) {
      var any = false;
      bal(c['id'] as String).forEach((cur, amt) {
        if (amt == 0) return;
        any = true;
        if (cur == 'UZS') {
          if (amt > 0) toMe += amt;
        } else {
          fxNet[cur] = (fxNet[cur] ?? 0) + amt;
        }
      });
      if (any) activeDebts++;
    }
    for (final l in accepted) {
      // Kiruvchi link totali serverdan valyutasiz (UZS) keladi — vals()dagi
      // net/toMeUZS hisobi bilan bir xil qamrov.
      final t = l['total'] as int;
      if (t != 0) activeDebts++;
      if (t > 0) toMe += t;
    }
    // Qarama-qarshi qarzlar bir-birini yopishi mumkin (+2000 va −2000) — 0 qator chiqmasin
    fxNet.removeWhere((_, v) => v == 0);
    final fxCurs = fxNet.keys.toList()..sort();
    final partnersCount = partners.length + accepted.length;

    // «Bekzod · 47 kun javobsiz» — menga qarzi bor hamkorlar ichidan oxirgi
    // harakati eng eski bo'lgani (yozuv ham, tasdiq ham kelmagan kunlar soni).
    String frozenName = '';
    var frozenDays = 0;
    for (final c in partners) {
      if ((bal(c['id'] as String)['UZS'] ?? 0) <= 0) continue;
      var lastTs = 0;
      for (final t in txs) {
        if (t['c'] == c['id'] && (t['ts'] as int) > lastTs) lastTs = t['ts'] as int;
      }
      if (lastTs == 0) continue;
      final d = now.difference(DateTime.fromMillisecondsSinceEpoch(lastTs)).inDays;
      if (d > frozenDays) {
        frozenDays = d;
        frozenName = c['name'] as String;
      }
    }

    // Yashil sparkline: daftar balansining o'sish chizig'i — operatsiyalar
    // xronologik yig'indisi (oxirgi 12 nuqta). Sarlavha raqami server balansidan
    // olinadi, chiziq esa TREND ko'rsatadi (aniq mos kelishi shart emas).
    final run = <double>[];
    var acc = 0.0;
    for (final t in txs) {
      if (t['cur'] != 'UZS' || t['st'] == 'pending') continue;
      final et = t['type'] as String;
      final sg = (et == 'Qarz berdim' || et == "To'lov berdim") ? 1 : -1;
      acc += sg * (t['a'] as int).toDouble();
      run.add(acc);
    }
    var debtSpark = run.length > 12 ? run.sublist(run.length - 12) : run;
    // Ko'rinadigan oynada real variatsiya bo'lmasa (<2 nuqta yoki hammasi teng),
    // sparkline «yolg'iz nuqta» bo'lib chiziladi — bo'sh ro'yxat qaytaramiz,
    // UI blokni butunlay yashiradi (PO 2026-07-17).
    if (debtSpark.length < 2 || debtSpark.every((x) => x == debtSpark.first)) {
      debtSpark = const <double>[];
    }

    // ---- «SO'NGGI» tasmasi: xarajat + operatsiyalar bitta vaqt o'qida ----
    final feed = <Map<String, dynamic>>[];
    for (final e in entries) {
      final inc = e['kind'] == 'd';
      final label = ((e['note'] as String?) ?? '').trim().isNotEmpty
          ? (e['note'] as String).trim()
          : ((e['cat'] as String?) ?? '');
      feed.add({
        'key': 'x${e['id']}',
        'ts': (e['ts'] as int?) ?? 0,
        'ini': _hubIni(label),
        'name': label,
        'sub': '${_fmtDay(e['days'] as int)}, ${e['t']} · ${e['cat']}',
        'amt': (inc ? '+' : '−') + _fmt(e['a'] as int),
        'inc': inc,
        'tap': () => goXarajat_(),
      });
    }
    for (final t in txs) {
      final c = _client(t['c']);
      if (c == null) continue;
      final et = t['type'] as String;
      final pos = et == 'Qarz berdim' || et == "To'lov berdim";
      final cid = t['c'] as String;
      feed.add({
        'key': 'o${t['id']}',
        'ts': (t['ts'] as int?) ?? 0,
        'ini': initials(c['name'] as String),
        'name': c['name'],
        'sub': '${t['date']} · ${typeLabel(et)}',
        'amt': (pos ? '+' : '−') + _fmt(t['a'] as int),
        'inc': pos,
        'tap': () {
          set({'screen': 'home', 'clientId': cid, 'inLinkId': null, 'tab': 'chat'});
          openLedger_(cid);
        },
      });
    }
    feed.sort((a, b) => (b['ts'] as int).compareTo(a['ts'] as int));
    final recent = feed.take(4).toList();

    final hasAny = entries.isNotEmpty || partners.isNotEmpty || accepted.isNotEmpty;

    // Ijara/To'yxona kartalaridagi summa (refreshHubMods_ yozadi). null =
    // hali kelmagan yoki server javob bermadi (endpoint 404) — HAMMASI NOL
    // bo'ladi va karta tinch nol holatida chiziladi. Bu ATAYLAB shunday: bosh
    // ekranda "xato" yoki aylanuvchi spinner ko'rinishi kerak emas.
    final ijSum = (S['hubIjaraSum'] as Map?) ?? kHubModZero;
    final toySum = (S['hubToySum'] as Map?) ?? kHubModZero;
    final ijLeft = (ijSum['left'] as int?) ?? 0;
    final ijCount = (ijSum['count'] as int?) ?? 0;
    final ijPend = (ijSum['pending'] as int?) ?? 0;
    final toyLeft = (toySum['left'] as int?) ?? 0;
    final toyCount = (toySum['count'] as int?) ?? 0;

    return {
      // 'isHub' vals() ichida hisoblanadi (isHome/isXarajat bilan bir xil `noClient` sharti)
      'goHub': () => goHub_(),
      'hubBackable': hubBackable(),
      'hubAtRoot': atHubRoot(),
      'layerOpen': layerOpen(),
      'closeTopLayer': closeTopLayer_,
      // Modul ichidagi qatlam yopgichi. Tear-off BARQAROR: qiymat emas,
      // chaqirilgan PAYTDAGI `moduleBack` o'qiladi — modul ekrani vals()
      // hisoblangandan KEYIN mount bo'lsa ham to'g'ri ishlaydi.
      'moduleBack': tryModuleBack_,
      'hubBack': () => goHub_(),
      // Menga kelgan pending bog'lanish so'rovlari (hub bannerida ko'rsatiladi — item 7)
      'hubPendingReq': pendingIn.length,
      'hubPendingReqTxt': Lf('hubPendingReq', {'n': '${pendingIn.length}'}),
      'hubOpenReq': () {
        // Pending so'rov -> QAROR sheet'i (Accept/Reject), openIncoming EMAS
        // (openIncoming faqat ACCEPTED daftar uchun — pending'da "avval qabul
        // qiling" gating chiqib, qabul tugmasi ko'rinmasdi). openFromNotif:2016
        // bilan bir xil naqsh.
        if (pendingIn.length == 1) {
          set({'linkDecisionId': pendingIn.first['id'] as String});
        } else {
          goHome_();
        }
      },
      // Skelet: boot/hydrate paytida (mavjud skelHome bayrog'i bilan bir xil manba)
      'hubSkel': S['skelHome'] == true,
      // Bo'sh holat: hech qanday yozuv/hamkor yo'q («birinchi kirish»)
      'hubEmpty': !hasAny,

      // Sarlavha
      'hubGreet': _greet(greetKey, first),
      'hubGreetEmpty': _greet('hubWelcome', first),
      'hubDate': '${_monFull[now.month - 1]} ${now.year} · ${_wdFull[now.weekday - 1]}',
      'hubIni': initials(full),
      'hubAvatar': S['meAvatar'],
      'hubTrial': subSt == 'trial' && trialDays >= 0,
      'hubTrialTxt': Lf('hubTrialChip', {'n': '$trialDays'}),
      'hubPrem': subSt == 'premium',
      'hubPremTxt': L0['hubPremium'] as String,
      'hubBellDot': _notifs().any((n) => n['unread'] == true),
      'hubOpenNotifs': () => set({'notifOpen': true}),
      'hubOpenProfil': () => set(
          {'screen': 'profil', 'clientId': null, 'receiptId': null, 'inLinkId': null}),

      // Xarajat kartasi
      'hubXarSec': L0['hubXarSec'] as String, // bo'lim nomi caption (PO 2026-07-17)
      'hubXarCap': Lf('hubSpentIn', {'month': _monFull[now.month - 1]}),
      'hubXarTxt': '−${_fmt(monthOut)}',
      'hubXarUnit': L0['som'] as String,
      'hubXarSpark': daily,
      'hubHasLimit': lim > 0,
      'hubLeftCap': L0['hubLeft'] as String,
      'hubLeftTxt': (limLeft >= 0 ? '+' : '−') + _fmt(limLeft.abs()),
      'hubLeftPos': limLeft >= 0,
      'hubTrendTxt': trendTxt,
      'hubTrendUp': trendUp,
      'hubOpenXar': () => goXarajat_(),

      // Oldi-berdi kartasi
      'hubDebtSec': L0['hubDebtSec'] as String, // bo'lim nomi caption (PO 2026-07-17)
      'hubDebtCap': L0['hubToMe'] as String,
      'hubDebtTxt': '+${_fmt(toMe)}',
      // Birlik — Xarajat kartasi bilan bir xil manba: kartalar bitta qobiqdan
      // chiqadi (_hubShell), summa va birligi ham bir xil ko'rinishda.
      'hubDebtUnit': L0['som'] as String,
      'hubDebtSub': Lf('hubDebtsPartners', {'d': '$activeDebts', 'p': '$partnersCount'}),
      // Chet valyuta netlari — kod bo'yicha saralangan; pos: musbat = sizga qarz
      'hubDebtFx': [
        for (final cur in fxCurs)
          {
            'cur': cur,
            'txt': (fxNet[cur]! > 0 ? '+' : '−') + _fmt(fxNet[cur]!.abs()),
            'pos': fxNet[cur]! > 0,
          },
      ],
      'hubDebtSpark': debtSpark,
      'hubFrozen': frozenName.isNotEmpty && frozenDays > 0,
      'hubFrozenTxt': Lf('hubNoAnswer', {'name': frozenName, 'n': '$frozenDays'}),
      'hubOpenDebt': () => goHome_(),

      // ── Modul kartalari (Ijaradagi uylar / To'yxona) ──
      // Xarajat/Qarz bilan BIR XIL anatomiya: sarlavha + summa + sub-qator.
      // RANG — YASHIL, o'ylab topilgan yangi tus emas: bu ilovada qizil = pul
      // chiqmoqda, yashil = pul kirmoqda. Ikkala modulning bosh raqami ham EGAGA
      // KELISHI KERAK bo'lgan pul (yig'ilmagan ijara / to'lanmagan bron qoldig'i)
      // — ya'ni kirim, demak Qarz daftar bilan bir xil yashil.
      // Ishora hubLeftTxt bilan bir xil: manfiy (avans) qizilga o'tadi.
      'hubIjaraCap': L0['hubIjaraCap'] as String,
      'hubIjaraTxt': (ijLeft >= 0 ? '+' : '−') + _fmt(ijLeft.abs()),
      'hubIjaraPos': ijLeft >= 0,
      'hubIjaraUnit': L0['som'] as String,
      // Ma'lumot bo'lsa — faktlar; bo'lmasa (404/bo'sh) modul tavsifi. Karta
      // shu bilan nol holatida ham TO'LIQ o'qiladi, "buzilgan" emas.
      'hubIjaraSub': ijCount > 0
          ? Lf('hubIjaraSub', {'n': '$ijCount', 'w': '$ijPend'})
          : L0['modIjarachiDesc'] as String,
      'hubToyCap': L0['hubToyCap'] as String,
      'hubToyTxt': (toyLeft >= 0 ? '+' : '−') + _fmt(toyLeft.abs()),
      'hubToyPos': toyLeft >= 0,
      'hubToyUnit': L0['som'] as String,
      'hubToySub': toyCount > 0
          ? Lf('hubToySub', {'n': '$toyCount'})
          : L0['modToyxonaDesc'] as String,
      // Qulflangan bo'lsa karta paywall'ni ochadi — bu qaror ekran qatlamida
      // (_modLocked + openPaywall), bu yerda faqat toza navigatsiya.
      'hubOpenIjara': () => goIjara_(),
      'hubOpenToy': () => goToyxona_(),
      'hubAddDebt': () => set({
            'screen': 'home', 'clientId': null, 'receiptId': null, 'inLinkId': null,
            'npOpen': true, 'npName': '', 'npPhone': '',
          }),

      // Tugmalar
      'hubBtnXar': L0['hubAddExpense'] as String,
      'hubBtnDebt': L0['hubAddDebt'] as String,

      // «SO'NGGI»
      'hubRecentCap': L0['hubRecent'] as String,
      'hubTodayCap': L0['hubToday'] as String,
      'hubTodayTxt': '−${_fmt(todayOut)}',
      'hubRecentRows': recent,

      // ---- Modul obunalari (per-module subs) ----
      // modSubs BO'SH bo'lsa (endpoint yo'q / xato / kModuleSubsUi=false) hub
      // kartalari hisoblagichsiz va qulfsiz — aynan bugungidek ko'rinadi.
      // Qator: {module, active, soon, used, limit, price} (+product, +until).
      'modSubs': _modSubs(),
      'modSubsLegacy': S['modSubsLegacy'] == true,
      // Paywall: {module, price, soon, used, limit} yoki null
      'paywall': S['paywall'],
      'openPaywall': (String module) => openPaywall_(module),
      'paywallClose': () => paywallClose_(),
      'paywallBuy': () => unawaited(paywallBuy_()),

      // Bo'sh holat matnlari
      'hubEmptyXarCap': L0['hubEmptyExpCap'] as String,
      'hubEmptyXarTitle': L0['hubEmptyExpTitle'] as String,
      'hubEmptyXarHint': L0['hubEmptyExpHint'] as String,
      'hubEmptyDebtTitle': L0['hubEmptyDebtTitle'] as String,
      'hubEmptyDebtHint': L0['hubEmptyDebtHint'] as String,
      'hubEmptyDebtBtn': L0['hubEmptyDebtBtn'] as String,
      'hubEmptyRecent': L0['hubEmptyRecent'] as String,
    };
  }

  // Salomlashuv: ism bo'lsa «Xayrli tong, Aziz»; ismsizda oxirgi vergul/probel
  // olib tashlanadi («Xayrli tong») — telefon raqami ism o'rniga chiqmaydi.
  String _greet(String key, String name) => name.isNotEmpty
      ? Lf(key, {'name': name})
      : Lf(key, {'name': ''}).replaceFirst(RegExp(r'\s*[,，]\s*$'), '').trim();

  // «Taksi» -> «TX»: SO'NGGI qatoridagi dumaloq nishon (prototipdagi kabi 2 harf)
  String _hubIni(String s) {
    final t = s.trim();
    if (t.isEmpty) return '—';
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) return (words[0][0] + words[1][0]).toUpperCase();
    return (t.length >= 2 ? t.substring(0, 2) : t).toUpperCase();
  }

  // «Bugun» / «Kecha» / «17-iyul» (xarajat yozuvining kun yorlig'i)
  String _fmtDay(int d) {
    if (d == 0) return L()['tToday'] as String;
    if (d == 1) return L()['tYesterday'] as String;
    final dt = DateTime.now().subtract(Duration(days: d));
    const mon = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];
    return '${dt.day}-${mon[dt.month - 1]}';
  }

  // Hub kartalaridan bo'limga o'tish (vals() ichidagi goHome/goXarajat bilan bir xil patch)
  void goHome_() =>
      // #31: npOpen:false — eski/ochiq qolgan "yangi hamkor" oynasi bo'limga kirganda
      // avtomatik ochilib qolmasin. Header dropdowni ham yopiq holda ochiladi.
      set({'screen': 'home', 'clientId': null, 'receiptId': null, 'inLinkId': null, 'npOpen': false,
           'homeFilterOpen': false});
  void goXarajat_() =>
      set({'screen': 'xarajat', 'clientId': null, 'receiptId': null, 'inLinkId': null});

  // Modul bo'limlari — hub kartasidan TO'LIQ EKRAN bo'lib ochiladi (goXarajat_
  // bilan aynan bir naqsh). Orqaga: ekranning O'Z header tugmasi (onBack ->
  // goHub_) yoki apparat "orqaga" — u hubBackable() orqali hub'ga qaytaradi,
  // chunki 'screen' endi 'hub' emas. Ekranlar `handleSystemBack: false` bilan
  // quriladi: PopScope FAQAT Root'da (main.dart) bo'lishi kerak.
  void goToyxona_() =>
      set({'screen': 'toyxona', 'clientId': null, 'receiptId': null, 'inLinkId': null});
  void goIjara_() =>
      set({'screen': 'ijara', 'clientId': null, 'receiptId': null, 'inLinkId': null});

  Map<String, dynamic> _xarVals(Pal P, String Function(int, String) money) {
    final ink = P.ink, bg = P.bg, bd = P.bd, mut = P.t3, red = P.red, green = P.green;
    final dk = S['dark'] == true;
    String abbr(String c) => {
          'Oziq-ovqat': 'Oz', 'Transport': 'Tr', 'Kommunal': 'Km', "Ko'ngilochar": 'Ko',
          'Kiyim': 'Ki', 'Salomatlik': 'Sa', 'Boshqa': 'B', 'Daromad': 'Da',
        }[c] ?? 'B';
    const mon = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];
    String fmtDay(int d) {
      if (d == 0) return L()['tToday'] as String;
      if (d == 1) return L()['tYesterday'] as String;
      final dt = DateTime.now().subtract(Duration(days: d));
      return '${dt.day}-${mon[dt.month - 1]}';
    }

    final perDays = S['xarPeriod'] == 'hafta' ? 7 : S['xarPeriod'] == 'oy' ? 30 : 365;
    final entries = _xar();
    final inP = entries.where((e) => (e['days'] as int) < perDays).toList();
    final out = inP.where((e) => e['kind'] == 'x').fold<int>(0, (s, e) => s + (e['a'] as int));
    final inc = inP.where((e) => e['kind'] == 'd').fold<int>(0, (s, e) => s + (e['a'] as int));
    final net = inc - out;
    const xcats = ['Oziq-ovqat', 'Transport', 'Kommunal', "Ko'ngilochar", 'Kiyim', 'Salomatlik', 'Boshqa'];
    final perCat = xcats
        .map((c) => {'c': c, 'v': inP.where((e) => e['kind'] == 'x' && e['cat'] == c).fold<int>(0, (s, e) => s + (e['a'] as int))})
        .where((x) => (x['v'] as int) > 0)
        .toList()
      ..sort((a, b) => (b['v'] as int).compareTo(a['v'] as int));
    final maxCat = perCat.isNotEmpty ? perCat[0]['v'] as int : 1;
    final monthOut = entries.where((e) => e['kind'] == 'x' && (e['days'] as int) < 30).fold<int>(0, (s, e) => s + (e['a'] as int));
    final lim = S['xarLimit'] as int;
    final ratio = lim > 0 ? monthOut / lim : 0.0;
    final limOver = ratio > 1;
    final limNear = !limOver && ratio >= 0.8;
    final limHot = limOver || limNear;
    final limRem = (lim - monthOut).abs();

    // Chat items
    final chron = entries.reversed.toList()
      ..sort((a, b) => (b['days'] as int).compareTo(a['days'] as int));
    final visual = <Map<String, dynamic>>[];
    int? lastDay;
    for (final e in chron) {
      if (e['days'] != lastDay) {
        final dayD = entries.where((x) => x['days'] == e['days'] && x['kind'] == 'd').fold<int>(0, (s, x) => s + (x['a'] as int));
        final dayX = entries.where((x) => x['days'] == e['days'] && x['kind'] == 'x').fold<int>(0, (s, x) => s + (x['a'] as int));
        visual.add({
          'key': 'sep${e['days']}',
          'sep': true, 'bub': false, 'label': fmtDay(e['days'] as int),
          'dTxt': '+${money(dayD, 'UZS')}', 'dColor': dayD > 0 ? green : mut,
          'xTxt': '−${money(dayX, 'UZS')}', 'xColor': dayX > 0 ? red : mut,
        });
        lastDay = e['days'] as int;
      }
      final isD = e['kind'] == 'd';
      final eid = e['id'] as String;
      visual.add({
        'key': eid, 'id': eid,
        'sep': false, 'bub': true,
        'just': isD ? 'start' : 'end',
        'rad': isD ? [4.0, 16.0, 16.0, 16.0] : [16.0, 4.0, 16.0, 16.0],
        'abbr': abbr(e['cat'] as String), 'cat': (e['cat'] as String).toUpperCase(),
        'amt': (isD ? '+' : '−') + money(e['a'] as int, 'UZS'),
        'color': isD ? green : red,
        'note': e['note'],
        'hasNote': (e['note'] as String? ?? '').isNotEmpty && (e['note'] as String).toLowerCase() != (e['cat'] as String).toLowerCase(),
        'time': e['t'] ?? '',
        // Bubble bosilsa inline tahrirlash ochiladi (o'sha joyda — alohida oyna emas)
        'editing': S['xEditId'] == eid,
        'tap': () => xEditOpen_(eid),
      });
    }
    final xChat = visual.reversed.toList();

    final sums = [0, 1, 2, 3, 4, 5]
        .map((i) => entries.where((e) => e['kind'] == 'x' && (e['days'] as int) >= i * 30 && (e['days'] as int) < (i + 1) * 30).fold<int>(0, (s, e) => s + (e['a'] as int)))
        .toList();
    final maxTr = math.max(sums.reduce(math.max), 1);
    final nowM = DateTime.now().month - 1;

    return {
      'limPct': math.min(100, (ratio * 100).round()),
      'limPctTxt': '${(ratio * 100).round()}%',
      'limBar': limHot ? red : ink,
      'limRemainC': limHot ? red : mut,
      'limSpentTxt': money(monthOut, 'UZS'),
      'limTotTxt': money(lim, 'UZS'),
      'limRemainTxt': lim == 0
          ? (L()['limitNone'] as String)
          : (limOver ? (L()['limitOver'] as String) : Lf('limitLeftPfx', {'a': '${money(limRem, 'UZS')}'})),
      'limNoteTxt': lim == 0
          ? (L()['limitNoteNone'] as String)
          : limOver
              ? Lf('limitOverBy', {'n': '${money(limRem, 'UZS')}'})
              : limNear
                  ? Lf('limitNearLeft', {'a': '${money(limRem, 'UZS')}'})
                  : Lf('limitLeftPfx', {'a': '${money(limRem, 'UZS')}'}),
      'limBtnTxt': S['limEdit'] != null ? (L()['btnCancelShort'] as String) : (L()['btnChange'] as String),
      'limEditOpen': S['limEdit'] != null,
      'limEditVal': S['limEdit'] ?? '',
      'limEditSet': (String t) => set({'limEdit': t.replaceAll(RegExp(r'[^\d]'), '')}),
      'limSave': () => limSave_(),
      'limEditToggle': () => set({'limEdit': S['limEdit'] == null ? (S['xarLimit']).toString() : null}),
      'xtChat': S['xarTab'] == 'chat', 'xtHisobot': S['xarTab'] == 'hisobot',
      'xarTabs': [['chat', L()['tabChat'] as String], ['hisobot', L()['segReports'] as String]]
          .map((kv) => {
                'label': kv[1], 'pick': () => set({'xarTab': kv[0]}),
                'bg': S['xarTab'] == kv[0] ? ink : Colors.transparent,
                'fg': S['xarTab'] == kv[0] ? bg : mut,
              })
          .toList(),
      'xChat': xChat,
      'xTrend': [5, 4, 3, 2, 1, 0].map((i) {
        final label = mon[(nowM - i + 12) % 12];
        return {
          'label': label[0].toUpperCase() + label.substring(1),
          'val': (sums[i] / 1000).round().toString(),
          'h': math.max(4.0, (sums[i] / maxTr * 72).roundToDouble()),
          'bg': i == 0 ? ink : (dk ? const Color(0xFF2E2E2F) : const Color(0xFFE6E6E2)),
        };
      }).toList(),
      'xarPeriods': [['hafta', L()['perWeek'] as String], ['oy', L()['perMonth'] as String], ['yil', L()['perYear'] as String]]
          .map((kv) => {
                'label': kv[1], 'pick': () => set({'xarPeriod': kv[0]}),
                'bg': S['xarPeriod'] == kv[0] ? ink : Colors.transparent,
                'fg': S['xarPeriod'] == kv[0] ? bg : mut,
                'bd': S['xarPeriod'] == kv[0] ? ink : bd,
              })
          .toList(),
      'xarNetCap': Lf('netResultCap', {'p': '${S['xarPeriod'] == 'hafta' ? 'HAFTA' : S['xarPeriod'] == 'oy' ? 'OY' : 'YIL'}'}),
      'xarNet': (net >= 0 ? '+' : '−') + money(net.abs(), 'UZS'),
      'xarOutTxt': '−${money(out, 'UZS')}',
      'xarInTxt': '+${money(inc, 'UZS')}',
      'redC': red, 'greenC': green,
      'xarCats': perCat
          .map((x) => {
                'abbr': abbr(x['c'] as String), 'name': x['c'], 'amt': money(x['v'] as int, 'UZS'),
                'w': math.max(4, ((x['v'] as int) / maxCat * 100).round()),
              })
          .toList(),
      'xarCatsEmpty': perCat.isEmpty,
      // ---- Matn input (yagona kirish usuli — ovoz yo'q, 2026-07-17) ----
      'xarTextVal': S['xarText'] ?? '',
      'xarTextSet': (String t) => set({'xarText': t}),
      'xarTextGo': () {
        if (S['voiceStage'] == 'parsing') return;
        final t = ((S['xarText'] as String?) ?? '').trim();
        if (t.isEmpty) { toast_(L()['tWriteSentence']); return; }
        // Klaviatura darhol yopiladi; matn chip uchgunicha inputda kutadi
        FocusManager.instance.primaryFocus?.unfocus();
        xarPick_(t, source: 'text');
      },
      // ---- Xarajatlar v2: papka (folder) UI (dizayn: Xarajatlar Trust.html) ----
      // DIQQAT: try/catch bilan himoyalangan — bu blok otilsa vals() butunlay yiqilib,
      // BARCHA ekranlar muzlab qolardi (back ham ishlamasdi). Xato bo'lsa xavfsiz
      // bo'sh qiymatlar qaytadi, ilova tirik qoladi.
      ...(() {
        try {
        final xfNow = DateTime.now();
        // ---- Davr filtri yorlig'i (sarlavha/balans/hisoblagichlar shu bilan) ----
        final xfPer = ((S['xfPeriod'] as Map?)?.cast<String, dynamic>()) ?? const {'kind': 'month'};
        final xfPerKind = '${xfPer['kind'] ?? 'month'}';
        String xfPerLabelOf() {
          switch (xfPerKind) {
            case 'today':
              return L()['fltToday'] as String;
            case 'yesterday':
              return L()['fltYesterday'] as String;
            case 'week':
              return L()['fltWeek'] as String;
            case 'all':
              return L()['fltAll'] as String;
            case 'custom':
              final f = DateTime.tryParse('${xfPer['from'] ?? ''}');
              final t = DateTime.tryParse('${xfPer['to'] ?? ''}');
              if (f == null || t == null) return L()['fltCustom'] as String;
              // "12–18 avg" (bir oy ichida) yoki "28 iyul – 3 avg" uslubi
              final mf = _monFull[f.month - 1].substring(0, 3).toLowerCase();
              final mt = _monFull[t.month - 1].substring(0, 3).toLowerCase();
              return (f.month == t.month && f.year == t.year)
                  ? '${f.day}–${t.day} $mf'
                  : '${f.day} $mf – ${t.day} $mt';
            default: // month
              return '${_monFull[xfNow.month - 1]} ${xfNow.year}';
          }
        }
        final xfPerLabel = xfPerLabelOf();
        final xfFs = _xfFolders();
        final xfNew = (S['xfNewCats'] as List).cast<String>();
        int xfTin = 0, xfTout = 0;
        for (final f in xfFs) {
          if (f['income'] == true) {
            xfTin += f['total'] as int;
          } else {
            xfTout += f['total'] as int;
          }
        }
        final xfBal = xfTin - xfTout;
        Map<String, dynamic> xfCard(Map<String, dynamic> f) => {
              'name': f['name'], 'emoji': xfEmoji(f['name'] as String),
              'inc': f['income'] == true,
              'totalTxt': (f['income'] == true ? '+' : '−') + _fx(f['total'] as int),
              'totalVal': f['total'] as int, // count-up animatsiya uchun xom qiymat
              'spark': _xfSpark(f['entries'] as List),
              'isNew': xfNew.contains(f['name']),
              'ghost': f['ghost'] == true,
              'open': () => set({'xfDetail': f['name']}),
            };
        // #15v2: sub-daromad papkalari (har doim hisoblanadi — @ tanlov popupi uchun ham)
        final incSubs = _xfIncSubs();
        final xfDel = (S['xfDeleting'] as List).cast<String>();
        // Ochiq papka (tafsilot)
        final xfDN = S['xfDetail'] as String?;
        final xfDFl = xfFs.where((f) => f['name'] == xfDN).toList();
        final xfDF = xfDFl.isEmpty ? null : xfDFl.first;
        final xfGroups = <Map<String, dynamic>>[];
        final xfDIsInc = xfDF?['income'] == true;
        // Ochiq sub-daromad (Daromad ichida)
        final incSubName = S['xfIncSub'] as String?;
        final incSubF = incSubName == null
            ? null
            : incSubs.where((f) => '${f['name']}'.toLowerCase() == incSubName.toLowerCase()).firstOrNull;
        final incMain = incSubF == null;
        // CI analyze gate (2026-08-03): `incSubF!` o'rniga oddiy promotion ishlaydigan
        // lokal nusxa — har qanday Dart versiyasida ogohlantirishsiz (unnecessary_non_null_assertion)
        final subF = incSubF;
        final incSubNameLow = subF == null ? null : '${subF['name']}'.toLowerCase();
        Map<String, dynamic> detRow(Map<String, dynamic> e) => {
              'id': e['id'], 'a': e['a'], 'note': e['note'] ?? '',
              'desc': (e['note'] as String?)?.isNotEmpty == true ? e['note'] : e['cat'],
              'time': e['t'],
              'amtTxt': (e['kind'] == 'd' ? '+' : '−') + _fx(e['a'] as int),
              'inc': e['kind'] == 'd',
              'deleting': xfDel.contains(e['id']),
              'edit': () => xfEditStart_(e['id'] as String),
              'del': () => xfDelEntry_(e['id'] as String),
            };
        if (xfDF != null && !xfDIsInc) {
          // Chiqim papkasi — kunlar bo'yicha guruhlash (avvalgidek)
          final ents = (xfDF['entries'] as List).cast<Map<String, dynamic>>().toList();
          ents.sort((a, b) => (a['days'] as int).compareTo(b['days'] as int));
          for (final e in ents) {
            final d = e['days'] as int;
            final label = d <= 0 ? (L()['tToday'] as String) : d == 1 ? (L()['tYesterday'] as String) : Lf('daysAgo', {'d': '$d'});
            if (xfGroups.isEmpty || xfGroups.last['label'] != label) {
              xfGroups.add({'label': label, 'rows': <Map<String, dynamic>>[]});
            }
            (xfGroups.last['rows'] as List).add(detRow(e));
          }
        }
        // #15v2: Daromad oqimi — kirim (hammasi/sub) + @tegli chiqimlar, yangi->eski
        final incFlow = <Map<String, dynamic>>[];
        if (xfDIsInc && xfDF != null) {
          for (final e in _xfPeriodEntries()) {
            final isInc = e['kind'] == 'd';
            if (isInc) {
              final c = (e['cat'] as String?) ?? 'Daromad';
              if (incSubNameLow != null && c.toLowerCase() != incSubNameLow) continue;
            } else {
              final tag = _incTag(e['note'] as String?);
              if (tag == null) continue;
              if (incSubNameLow != null && tag != incSubNameLow) continue;
            }
            incFlow.add(e);
          }
          incFlow.sort((a, b) => ((b['ts'] as int?) ?? 0).compareTo((a['ts'] as int?) ?? 0));
        }
        final incFlowRows = incFlow.map((e) {
          final isInc = e['kind'] == 'd';
          final note = (e['note'] as String?) ?? '';
          return <String, dynamic>{
            'id': e['id'], 'a': e['a'], 'note': note,
            'inc': isInc,
            'title': note.isNotEmpty
                ? note
                : (isInc
                    ? (('${e['cat'] ?? ''}').startsWith('@')
                        ? '${e['cat']}'
                        : (L()['xfIncGeneral'] as String? ?? 'Umumiy kirim'))
                    : '${e['cat'] ?? ''}'),
            // Oy YOZUVNING O'ZIDAN (ts): davr filtri bir necha oyni qamrashi mumkin
            'when':
                '${e['dom']}-${_monFull[(((e['ts'] as int?) ?? 0) != 0 ? DateTime.fromMillisecondsSinceEpoch(e['ts'] as int).month : xfNow.month) - 1].toLowerCase()} · ${e['t']}',
            'chip': isInc ? '' : '${e['cat'] ?? ''}', // chiqimda: qaysi xarajat papkasi
            'amtTxt': (isInc ? '+' : '−') + _fx(e['a'] as int),
            'deleting': xfDel.contains(e['id']),
            'del': () => xfDelEntry_(e['id'] as String),
          };
        }).toList();
        // Sarlavha qiymatlari: sub ochiq bo'lsa — nomi + QOLDIQ (kirim − @chiqim)
        String xfDNameV = xfDF == null ? '' : '${xfDF['name']}';
        int xfDTotalV = xfDF == null ? 0 : xfDF['total'] as int;
        String xfDPrefixV = xfDF?['income'] == true ? '+' : '−';
        String xfDCountV = xfDF == null
            ? ''
            : (xfPerKind == 'month'
                ? Lf('monthYearCount', {'month': '${_monFull[xfNow.month - 1]}', 'year': '${xfNow.year}', 'n': '${(xfDF['entries'] as List).length}'})
                : Lf('periodCount', {'p': xfPerLabel, 'n': '${(xfDF['entries'] as List).length}'}));
        if (xfDIsInc && subF != null) {
          final left = subF['left'] as int;
          xfDNameV = '${subF['name']}';
          xfDTotalV = left.abs();
          xfDPrefixV = left < 0 ? '−' : '+';
          xfDCountV = '${incFlowRows.length} ${(L()['xfActsLabel'] as String?) ?? 'ta harakat'}';
        }
        // Tasdiqlash kartasi (birlashtirish / papka o'chirish)
        final xfCf = S['xfConfirm'] as Map<String, dynamic>?;
        final xfCfF = xfCf?['from'] as Map<String, dynamic>?;
        final xfCfT = xfCf?['to'] as Map<String, dynamic>?;
        // Tray chiplari: mavjud chiqim papkalari (bo'sh bo'lsa standart to'plam)
        final xfChipCats = xfFs.where((f) => f['income'] != true).map((f) => f['name'] as String).toList();
        final chipSrc = xfChipCats.isEmpty
            ? ['Transport', 'Oziq-ovqat', 'Kommunal', 'Xaridlar', 'Salomatlik']
            : xfChipCats;
        return <String, dynamic>{
          // Sarlavha va balans yorlig'i — tanlangan davrga dinamik ergashadi
          'xfMonth': xfPerLabel,
          'xfBalCap': xfPerKind == 'month'
              ? Lf('balOfMonth', {'month': '${_monFull[xfNow.month - 1].toUpperCase()}'})
              : Lf('balOfPeriod', {'p': xfPerLabel.toUpperCase()}),
          // Davr filtri (header dropdown UI shulardan quradi)
          'xfPerKind': xfPerKind,
          'xfPerLabel': xfPerLabel,
          'xfPerOpts': [
            {'k': 'today', 'label': L()['fltToday']},
            {'k': 'yesterday', 'label': L()['fltYesterday']},
            {'k': 'week', 'label': L()['fltWeek']},
            {'k': 'month', 'label': L()['fltMonth']},
            {'k': 'all', 'label': L()['fltAll']},
            {'k': 'custom', 'label': L()['fltCustom']},
          ],
          'xfPerPick': (String k) => xfSetPeriod_({'kind': k}),
          'xfPerCustom': (DateTime f, DateTime t) => xfSetPeriod_({
                'kind': 'custom',
                'from': f.toIso8601String().substring(0, 10),
                'to': t.toIso8601String().substring(0, 10),
              }),
          'xfBalTxt': (xfBal >= 0 ? '+' : '−') + _fx(xfBal.abs()),
          // Count-up animatsiya uchun xom qiymatlar
          'xfBalVal': xfBal.abs(),
          'xfInVal': xfTin,
          'xfOutVal': xfTout,
          'xfBalPos': xfBal >= 0,
          'xfInTxt': '+${_fx(xfTin)}',
          'xfOutTxt': '−${_fx(xfTout)}',
          'xfInFolders': xfFs.where((f) => f['income'] == true).map(xfCard).toList(),
          'xfOutFolders': xfFs.where((f) => f['income'] != true).map(xfCard).toList(),
          'xfEmptyAll': xfFs.isEmpty,
          // Papka tafsiloti
          'xfDetailOpen': xfDF != null,
          'xfDEmoji': xfDF == null ? '' : xfEmoji(xfDF['name'] as String),
          'xfDName': xfDNameV,
          'xfDCount': xfDCountV,
          'xfDTotalTxt': xfDF == null ? '' : (xfDPrefixV + _fx(xfDTotalV)),
          'xfDTotalVal': xfDTotalV,
          'xfDPrefix': xfDPrefixV,
          'xfDInc': xfDF?['income'] == true,
          'xfDSpark': xfDF == null ? List<double>.filled(8, 0.06) : _xfSpark(xfDF['entries'] as List),
          'xfDGroups': xfGroups,
          'xfDEmpty': xfDF != null && (xfDF['entries'] as List).isEmpty,
          // Yopish: sub ochiq bo'lsa -> Daromad asosiyga qaytadi; aks holda detail yopiladi
          'xfDetailClose': () {
            if (xfDIsInc && !incMain) {
              set({'xfIncSub': null});
            } else {
              set({'xfDetail': null, 'xfIncSub': null});
            }
          },
          // ---- #15v2: Daromad bo'limi (sub-papkalar + oqim + kirim qo'shish) ----
          'xfDIsIncome': xfDIsInc,
          'xfIncMain': incMain, // true = Daromad asosiy ko'rinish (sub-papkalar ro'yxati)
          'xfIncBusy': S['xfIncBusy'] == true,
          'xfAddIncome': (String amt, String note) => xfAddIncome_(amt, note),
          'xfIncCreate': (String name) => xfIncSubCreate_(name),
          'xfIncEditSave': (String id, String amt, String note) => xfIncEditSave_(id, amt, note),
          'xfIncSubRows': incSubs.map((f) {
            final left = f['left'] as int;
            return <String, dynamic>{
              'name': f['name'],
              'leftTxt': (left < 0 ? '−' : '') + _fx(left.abs()),
              'neg': left < 0,
              'inTxt': '+${_fx(f['in'] as int)}',
              'n': f['n'],
              'open': () => set({'xfIncSub': f['name']}),
            };
          }).toList(),
          'xfIncFlow': incFlowRows,
          // @ tanlov popupi (asosiy inputda '@...' yozilganda): nom + qoldiq
          'xfAtSubs': incSubs.map((f) {
            final left = f['left'] as int;
            return <String, dynamic>{
              'name': f['name'],
              'leftTxt': (left < 0 ? '−' : '') + _fx(left.abs()),
              'neg': left < 0,
            };
          }).toList(),
          // Daromad sahifasida pastki xarajat inputi KO'RINMAYDI (PO 2026-07-29)
          'xfHideInput': xfDIsInc && xfDF != null,
          // Jurnal (Oxirgi o'zgarishlar)
          'xfLogOpen': S['xfLogOpen'] == true,
          'xfLogDot': S['xfLogDot'] == true,
          'xfLogToggle': () => set({'xfLogOpen': S['xfLogOpen'] != true, 'xfLogDot': false}),
          'xfLogEmpty': (S['xfLog'] as List).isEmpty,
          'xfLogRows': (S['xfLog'] as List).cast<Map<String, dynamic>>().map((o) => {
                'emoji': xfEmoji(o['cat'] as String),
                'desc': o['desc'],
                'isDel': o['type'] == 'del',
                'badge': o['type'] == 'add' ? (L()['logNew'] as String)
                    : o['type'] == 'del' ? (L()['logDeleted'] as String)
                    : o['type'] == 'edit' ? (L()['logEdited'] as String) : (L()['logMerged'] as String),
                'type': o['type'],
                'sub': '${o['cat']} · ${o['t']}',
                'amtTxt': (o['income'] == true ? '+' : '−') + _fx(o['a'] as int),
                'inc': o['income'] == true,
                'canAct': o['type'] != 'del' && o['eid'] != null,
                'edit': () { if (o['eid'] != null) xfEditStart_(o['eid'] as String); },
                'delTap': () { if (o['eid'] != null) xfDelEntry_(o['eid'] as String); },
              }).toList(),
          // ANIQLANMAGAN tray
          'xfShowTray': (S['xfTray'] as List).isNotEmpty,
          'xfTrayCount': '${(S['xfTray'] as List).length}',
          'xfTrayRows': (S['xfTray'] as List).cast<Map<String, dynamic>>().map((t) {
            // AI taklif qilgan YANGI papka nomi (parse new_category_suggestion) — birinchi chip
            final aiName = ((t['action'] as Map)['new_category_suggestion'] as String?)?.trim() ?? '';
            return <String, dynamic>{
              'id': t['id'],
              'text': t['text'],
              'amtTxt': '−${_fx(_numToInt((t['action'] as Map)['amount']))}',
              'open': t['open'] == true,
              'naming': S['xfTrayNaming'] == t['id'],
              'toggle': () => xfTrayToggle_(t['id'] as String),
              'chips': [
                if (aiName.isNotEmpty)
                  {
                    'label': '✨ $aiName — yangi',
                    'isNew': true,
                    'pick': () => xfTrayPick_(t['id'] as String, aiName, createNew: true),
                  },
                for (final c in chipSrc)
                  {'label': '${xfEmoji(c)} $c', 'pick': () => xfTrayPick_(t['id'] as String, c)},
                {'label': L()['otherName'] as String, 'pick': () => set({'xfTrayNaming': t['id'], 'xfTrayName': ''})},
              ],
              // Qo'lda nom buferi — rebuild kerak emas (TextField matnni o'zi ushlab turadi)
              'nameSet': (String v) => S['xfTrayName'] = v,
              'nameOk': () {
                final n = ('${S['xfTrayName'] ?? ''}').trim();
                if (n.length < 2) {
                  toast_(L()['tNameMin2']);
                  return;
                }
                set({'xfTrayNaming': null, 'xfTrayName': ''});
                xfTrayPick_(t['id'] as String, n, createNew: true);
              },
            };
          }).toList(),
          // Tahrir rejimi / tasdiqlash / undo-toast / yuborish
          'xfEditingOpen': S['xfEditing'] != null,
          'xfEditLabel': '${(S['xfEditing'] as Map?)?['label'] ?? ''}',
          'xfEditCancel': () => xfEditCancel_(),
          'xfCfOpen': xfCf != null,
          'xfCfMerge': xfCf?['kind'] == 'merge',
          'xfCfFromTxt': xfCfF == null ? '' : '${xfEmoji(xfCfF['name'] as String)} ${xfCfF['name']}',
          'xfCfFromSum': xfCfF == null ? '' : ((xfCfF['income'] == true ? '+' : '−') + _fx(xfCfF['total'] as int)),
          'xfCfToTxt': xfCfT == null ? '' : '${xfEmoji(xfCfT['name'] as String)} ${xfCfT['name']}',
          'xfCfToSum': xfCfT == null ? '' : ((xfCfT['income'] == true ? '+' : '−') + _fx(xfCfT['total'] as int)),
          'xfCfOk': () => xfCfOk_(),
          'xfCfNo': () => xfCfNo_(),
          'xfToastOpen': S['xfToast'] != null,
          'xfToastText': '${(S['xfToast'] as Map?)?['text'] ?? ''}',
          // warn — tugmasiz ogohlantirish (bo'sh label: UI hech narsa chizmaydi)
          'xfToastBtn': (S['xfToast'] as Map?)?['kind'] == 'warn'
              ? ''
              : (L()['btnCancelFull'] as String? ?? 'Bekor qilish'),
          'xfUndo': () => xfUndo_(),
          'xfBusy': S['voiceStage'] == 'parsing',
          'xfSend': () => xfSend_(),
          // To'liq ekran: header'dagi orqaga tugmasi — bosh hub'ga qaytaradi
          'xfBack': () => goHub_(),
          // Fly-animatsiya hodisalari: UI o'qib, ishga tushirib, xfFlyDone bilan tozalaydi
          'xfFlyEvents': (S['xfFly'] as List).cast<Map<String, dynamic>>().map((ev) => {
                ...ev,
                // Chip qo'nganda chaqiriladi: yozuv shu paytda kiritiladi -> raqamlar sanaydi
                'land': () {
                  final en = ev['entry'];
                  if (en is Map<String, dynamic>) xfLandOne_(en);
                },
              }).toList(),
          'xfFlyDone': () {
            if ((S['xfFly'] as List).isNotEmpty) S['xfFly'] = <Map<String, dynamic>>[];
          },
          // Qayta-tartib siljish animatsiyasi uchun ESKI tartib (bir martalik)
          'xfReorderFrom': S['xfReorderFrom'],
          'xfReorderTaken': () {
            S['xfReorderFrom'] = null; // notifysiz iste'mol belgisi (flyEvents kabi)
          },
        };
        } catch (err) {
          debugPrint('xf blok xatosi (himoyalangan): $err');
          // Xavfsiz bo'sh qiymatlar — Xarajat ekrani bo'sh ko'rinadi, qolgan ilova ishlaydi
          return <String, dynamic>{
            'xfMonth': '', 'xfBalCap': 'BALANS', 'xfBalTxt': '+0', 'xfBalPos': true,
            'xfBalVal': 0, 'xfInVal': 0, 'xfOutVal': 0,
            'xfInTxt': '+0', 'xfOutTxt': '−0',
            'xfInFolders': <Map<String, dynamic>>[], 'xfOutFolders': <Map<String, dynamic>>[],
            'xfEmptyAll': true, 'xfDetailOpen': false, 'xfDEmoji': '', 'xfDName': '',
            'xfDCount': '', 'xfDTotalTxt': '', 'xfDTotalVal': 0, 'xfDInc': false,
            'xfDSpark': List<double>.filled(8, 0.08), 'xfDGroups': <Map<String, dynamic>>[],
            'xfDEmpty': true, 'xfDetailClose': () {},
            'xfDIsIncome': false, 'xfIncBusy': false, 'xfIncMain': true,
            'xfAddIncome': (String amt, String note) async => false,
            'xfIncCreate': (String name) async => false,
            'xfIncEditSave': (String id, String amt, String note) async => false,
            'xfIncSubRows': <Map<String, dynamic>>[], 'xfIncFlow': <Map<String, dynamic>>[],
            'xfAtSubs': <Map<String, dynamic>>[], 'xfHideInput': false, 'xfDPrefix': '+',
            'xfLogOpen': false, 'xfLogDot': false, 'xfLogToggle': () {}, 'xfLogEmpty': true,
            'xfLogRows': <Map<String, dynamic>>[],
            'xfShowTray': false, 'xfTrayCount': '0', 'xfTrayRows': <Map<String, dynamic>>[],
            'xfEditingOpen': false, 'xfEditLabel': '', 'xfEditCancel': () {},
            'xfCfOpen': false, 'xfCfMerge': false, 'xfCfFromTxt': '', 'xfCfFromSum': '',
            'xfCfToTxt': '', 'xfCfToSum': '', 'xfCfOk': () {}, 'xfCfNo': () {},
            'xfToastOpen': false, 'xfToastText': '', 'xfToastBtn': '', 'xfUndo': () {},
            'xfBusy': false, 'xfSend': () {},
            'xfBack': () => goHub_(),
            'xfFlyEvents': <Map<String, dynamic>>[], 'xfFlyDone': () {},
            'xfReorderFrom': null, 'xfReorderTaken': () {},
            'xfPerKind': 'month', 'xfPerLabel': '', 'xfPerOpts': <Map<String, dynamic>>[],
            'xfPerPick': (String k) {}, 'xfPerCustom': (DateTime f, DateTime t) {},
          };
        }
      })(),
      // ---- Chatdagi yozuvni inline tahrirlash (bubble bosilganda) ----
      'xEditOpen': S['xEditId'] != null,
      'xEditId': S['xEditId'],
      'xEditClose': () => xEditClose_(),
      'xEditSave': () => xEditSave_(),
      'xEditDelete': () => xEditDelete_(),
      'xEditIsX': (S['xEditVals'] as Map?)?['kind'] == 'x',
      'xEditIsD': (S['xEditVals'] as Map?)?['kind'] == 'd',
      'xEditAmount': '${(S['xEditVals'] as Map?)?['amount'] ?? ''}',
      'xEditNote': '${(S['xEditVals'] as Map?)?['note'] ?? ''}',
      'xEditPickX': () => xEditSet_({'kind': 'x'}),
      'xEditPickD': () => xEditSet_({'kind': 'd', 'cat': 'Daromad'}),
      'xEditOnAmount': (String t) => xEditSet_({'amount': t.replaceAll(RegExp(r'[^\d]'), '')}),
      'xEditCats': (S['xEditVals'] as Map?)?['kind'] == 'd'
          ? <Map<String, dynamic>>[]
          : (S['xcCats'] as List).cast<String>().map((c) => {
                'name': c,
                'sel': (S['xEditVals'] as Map?)?['cat'] == c,
                'pick': () => xEditSet_({'cat': c}),
              }).toList(),
    };
  }

  Map<String, dynamic> vals() {
    final L0 = L();
    final dk = S['dark'] == true;
    final P = pal(dk);
    final ink = P.ink, bg = P.bg, bd = P.bd, mut = P.t3, green = P.green, red = P.red;

    String money(int a, String cur) => switch (cur) {
          'USD' => '${_fmt(a)} \$', 'EUR' => '${_fmt(a)} €', 'RUB' => '${_fmt(a)} ₽',
          _ => '${_fmt(a)} ${L0['som']}',
        };
    int sign(String t) => (t == 'Qarz berdim' || t == "To'lov berdim") ? 1 : -1;
    String initials(String n) =>
        n.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

    // MUHIM (2026-08-02 audit): ilgari bu funksiya FAQAT UZS va USD ni qaytarardi,
    // holbuki profil valyutasi EUR/RUB bo'lishi mumkin (Profil > Asosiy valyuta) va
    // server barcha valyutalarni qaytaradi. Natijada EUR/RUB qarz ro'yxatda "0 so'm"
    // bo'lib ko'rinardi. Lokal fallback esa `b[t['cur']]!` da null'ga tushib
    // ILOVANI YIQITARDI (har kadrda qizil ekran). Endi valyutalar dinamik.
    const curOrder = ['UZS', 'USD', 'EUR', 'RUB'];
    Map<String, int> bal(String cid) {
      // Server balansi (operations + qarz daftari) — haqiqat manbai; bo'sh bo'lsa lokal fallback
      final srv = (_client(cid)?['srvBal'] as Map?)?.cast<String, int>();
      if (srv != null && srv.isNotEmpty) return Map<String, int>.from(srv);
      final b = <String, int>{'UZS': 0, 'USD': 0};
      for (final t in _txs()) {
        if (t['c'] == cid && t['st'] != 'pending') {
          final cur = '${t['cur'] ?? 'UZS'}';
          b[cur] = (b[cur] ?? 0) + sign(t['type']) * (t['a'] as int);
        }
      }
      return b;
    }

    Map<String, dynamic> balMain(Map<String, int> b) {
      // Ko'rsatiladigan valyuta: nolga teng bo'lmagan birinchisi (odatdagi tartibda,
      // so'ng ro'yxatda bo'lmagan valyutalar).
      final keys = [
        ...curOrder.where(b.containsKey),
        ...b.keys.where((k) => !curOrder.contains(k)),
      ];
      String? pick;
      for (final k in keys) {
        if ((b[k] ?? 0) != 0) { pick = k; break; }
      }
      if (pick == null) {
        // «hisob teng» yozuvi olib tashlandi (PO sinov) — faqat «0 so'm» summa qoladi.
        return {'text': L0['zero'], 'color': mut, 'sub': ''};
      }
      final v = b[pick]!;
      final cur = pick;
      final pos = v > 0;
      return {
        'text': (pos ? '+' : '−') + money(v.abs(), cur),
        'color': pos ? green : red,
        'sub': pos ? L0['subPos'] : L0['subNeg'],
      };
    }

    // Home — kuchli qidiruv (ism-normalizatsiya/telefon/summa: partnerMatch)
    // + davr filtri (homeFilter). fActive faqat server 'period' bergandagina true.
    final q = (S['search'] as String).trim();
    final fActive = S['homeFilter'] != 'all' && S['homePeriodOk'] == true;
    // Filtr summalari yuklanayotganda skelet — filtrsiz ro'yxat "miltillamasin".
    // FAQAT BIRINCHI yuklashda (homePeriodOk hali true emas): setHomeFilter_
    // homePeriodOk:false qiladi, muvaffaqiyatli javob true qiladi va 15s jim
    // poll (loadHomePeriod_) uni true saqlaydi — shu sabab har poll'da ro'yxat
    // skeletga "miltillamaydi" (2026-08-04 wave-1 review topilmasi).
    final homeSkel = S['skelHome'] == true ||
        (S['homeFilter'] != 'all' &&
            S['homePeriodLoading'] == true &&
            S['homePeriodOk'] != true);
    final homeFiltered = _homeClients();
    final visible = homeSkel
        ? <Map<String, dynamic>>[]
        : homeFiltered.take(S['homeVis'] as int).toList();
    final clientRows = visible.map((c) {
      final b = balMain(bal(c['id']));
      Map<String, dynamic>? last;
      for (final t in _txs().reversed) {
        if (t['c'] == c['id']) {
          last = t;
          break;
        }
      }
      final cid = c['id'] as String;
      // Unread debt-event notifications (server counts + FCM optimistic bumps):
      // count bubble on the avatar + latest amount chip in the balSub area.
      final ncr = (S['notifCounts'] as Map)[cid];
      final nc = ncr is Map ? ncr : const <String, dynamic>{};
      final nCount = _numToInt(nc['count']);
      final nLast = (nc['last'] as List?) ?? const [];
      final nAmt = nCount > 0 && nLast.isNotEmpty
          ? money(_numToInt(nLast.first), '${nc['cur'] ?? 'UZS'}')
          : '';
      return {
        'id': cid,
        'actLabel': 'Arxiv',
        'tx': S['swipeId'] == cid ? S['swipeDx'] : (S['swipeSnap'] == cid ? -96.0 : 0.0),
        'anim': S['swipeId'] != cid,
        'archTap': () => archive_(cid),
        'archAct': () => archive_(cid),
        'name': c['name'], 'initials': initials(c['name']),
        'onTrust': c['onTrust'] != false, 'oneSided': c['onTrust'] == false,
        // Badge «in Trust» — ro'yxatdan o'tganlik (accepted'ni kutmaydi);
        // counterparty_deleted bo'lsa o'chadi (partnerInTrust, _mapPartner).
        'inTrust': c['inTrust'] == true,
        'sub': last != null ? '${L0['last']}${last['date']}' : L0['noOps'],
        'bal': b['text'], 'color': b['color'], 'balSub': b['sub'],
        // O'qilmagan xabarlar soni — qatorda badge (sms kelsa ko'rinadi)
        'unread': (S['msgUnread'] as Map)[cid] ?? 0,
        // Notification badge (count bubble, «9+» cap) + latest-amount chip;
        // notifAmtOff keeps the plain balSub line when there is nothing unread.
        'notifOn': nCount > 0,
        'notifCountTxt': notifBadgeText(nCount),
        'notifAmtOn': nAmt.isNotEmpty,
        'notifAmtOff': nAmt.isEmpty,
        'notifAmtTxt': nAmt,
        'open': () {
          if (_swClick) {
            _swClick = false;
            return;
          }
          if (S['swipeSnap'] == cid) {
            set({'swipeSnap': null});
            return;
          }
          set({'clientId': cid, 'inLinkId': null, 'tab': 'chat', 'cMenuOpen': false, 'cRen': null, 'pProfOpen': false, 'opsVis': 8});
          openLedger_(cid); // qarz daftarini yuklash + tez polling
        },
      };
    }).toList();

    // Meni kontragent qilib qo'shganlar (qabul qilinganlari) — teskari balans bilan ro'yxatga qo'shiladi.
    // Faol davr filtrida link qatorlari YASHIRILADI: /api/links davr summalarini
    // bermaydi, "davrda harakat bor" va'dasini buzmaslik uchun (chip reset bilan qaytadi).
    final linksAll = List<Map<String, dynamic>>.from(S['links'] as List);
    final inRows = homeSkel || fActive
        ? <Map<String, dynamic>>[]
        : linksAll
            .where((l) => l['status'] == 'accepted' && partnerMatch(q,
                name: (l['name'] ?? '') as String,
                phone: (l['phone'] ?? '') as String,
                amounts: [_numToInt(l['total'])]))
            .map((l) {
            final tot = l['total'] as int;
            final lid = l['id'] as String;
            // Same notification badge as clientRows — counts are keyed by the
            // shared partner/link id (openLedger_ uses the same id space).
            final ncr = (S['notifCounts'] as Map)[lid];
            final nc = ncr is Map ? ncr : const <String, dynamic>{};
            final nCount = _numToInt(nc['count']);
            final nLast = (nc['last'] as List?) ?? const [];
            final nAmt = nCount > 0 && nLast.isNotEmpty
                ? money(_numToInt(nLast.first), '${nc['cur'] ?? 'UZS'}')
                : '';
            return {
              'id': 'in$lid',
              'actLabel': '',
              'tx': 0.0, 'anim': true,
              'archTap': () {}, 'archAct': () {},
              'name': l['name'], 'initials': initials(l['name'] as String),
              'onTrust': true, 'oneSided': false,
              // Kiruvchi (qabul qilingan) bog'lanish — hamkor ro'yxatdan o'tgan
              'inTrust': true,
              'sub': L0['addedYou'],
              'bal': tot == 0 ? L0['zero'] : (tot > 0 ? '+' : '−') + money(tot.abs(), 'UZS'),
              'color': tot > 0 ? green : (tot < 0 ? red : mut),
              'balSub': tot > 0 ? L0['subPos'] : (tot < 0 ? L0['subNeg'] : ''),
              // O'qilmagan xabarlar badge'i (data-qatlam; ko'rsatish ekran qaroriga bog'liq)
              'unread': (S['msgUnread'] as Map)[lid] ?? 0,
              'notifOn': nCount > 0,
              'notifCountTxt': notifBadgeText(nCount),
              'notifAmtOn': nAmt.isNotEmpty,
              'notifAmtOff': nAmt.isEmpty,
              'notifAmtTxt': nAmt,
              'open': () => openIncoming(lid),
            };
          }).toList();
    final homeRows = [...clientRows, ...inRows];

    int toMeUZS = 0, toMeUSD = 0, byMe = 0;
    for (final c in _clients()) {
      final b = bal(c['id']);
      final uzs = b['UZS'] ?? 0, usd = b['USD'] ?? 0;
      if (uzs > 0) toMeUZS += uzs;
      if (uzs < 0) byMe += -uzs;
      if (usd > 0) toMeUSD += usd;
    }
    // Qabul qilingan kiruvchi bog'lanishlar balansga qo'shiladi
    for (final l in linksAll) {
      if (l['status'] != 'accepted') continue;
      final tot = l['total'] as int;
      if (tot > 0) toMeUZS += tot;
      if (tot < 0) byMe += -tot;
    }
    final net = toMeUZS - byMe;

    // Faol davr filtri: SOF BALANS bloki davr summalariga o'tadi.
    // pToMe/pByMe — davrda YARATILGAN qarzlar (berilgan/olingan) yig'indisi;
    // pNet — davrdagi sof o'zgarish (qaytarilganlar ayirilgan holda).
    int pToMe = 0, pByMe = 0, pNet = 0;
    if (fActive) {
      for (final c in _clients()) {
        if (c['archived'] == true) continue;
        final pd = (S['homePeriod'] as Map)[c['id']];
        if (pd is! Map) continue;
        final tm = _numToInt(pd['to_me']), bm = _numToInt(pd['by_me']);
        pToMe += tm;
        pByMe += bm;
        pNet += (tm - _numToInt(pd['repaid_to_me'])) - (bm - _numToInt(pd['repaid_by_me']));
      }
    }

    // Client detail: o'z hamkorim (sotuvchi ko'rinishi) YOKI meni qo'shgan sotuvchi (mijoz ko'rinishi)
    final client = _client(S['clientId']);
    final inLink = S['clientId'] == null ? _link(S['inLinkId'] as String?) : null;
    final incoming = inLink != null;
    String cName = '', cInitials = '';
    String cBal = '';
    Color cBalColor = ink;
    var chatItems = <Map<String, dynamic>>[];
    var opsRows = <Map<String, dynamic>>[];

    Map<String, dynamic> txRow(Map<String, dynamic> t) {
      final et = t['type'] as String;
      final mine = t['by'] == 'me';
      return {
        // Chat-align convention (template m.isTx block) — placeholder/vals
        // invariant: every placeholder the template references must be emitted,
        // even while the chat UI is behind kChatEnabled=false. Values follow
        // the documented convention comment in template.html ('me' = right).
        'align': mine ? 'flex-end' : 'flex-start',
        'txw': '80%',
        'txbg': mine ? 'var(--card2)' : 'var(--bg)',
        'txbd': mine ? 'none' : '1px solid var(--bd2)',
        'txrad': mine ? '14px 14px 5px 14px' : '14px 14px 14px 5px',
        'stLabel': t['st'] == 'arch' ? L0['stArch'] : L0['stOk'],
        'dot': ink,
        'type': typeLabel(et),
        'amount': (sign(et) > 0 ? '+' : '−') + money(t['a'], t['cur']),
        'acolor': sign(et) > 0 ? green : red,
        'date': t['date'],
        // Kim yozgani — mijozga "X yozgan" ko'rinadi
        'byText': incoming
            ? Lf('wroteBy', {'name': '${inLink['name']}'})
            : (t['by'] == 'me' ? '' : (L()['wroteByOther'] as String)),
        'done': true,
        'canEdit': !incoming && t['by'] == 'me',
        'openReceipt': incoming ? () {} : () => set({'receiptId': t['id']}),
      };
    }

    if (incoming) {
      // Mijoz ko'rinishi: sotuvchi daftari (faqat o'qish)
      cName = inLink['name'] as String;
      cInitials = initials(cName);
      final tot = inLink['total'] as int;
      cBal = '${L0['balPfx']}${tot == 0 ? L0['zero'] : (tot > 0 ? '+' : '−') + money(tot.abs(), 'UZS')}';
      cBalColor = tot > 0 ? green : (tot < 0 ? red : mut);
      final inOps = List<Map<String, dynamic>>.from(S['inLinkOps'] as List);
      opsRows = inOps.take(S['opsVis'] as int).map((t) {
        final r = txRow(t);
        return {
          'key': t['id'],
          'type': r['type'],
          'date': '${t['date']} · ${r['byText']}',
          'amount': r['amount'], 'color': r['acolor'], 'st': r['stLabel'], 'dot': r['dot'],
          'canOpen': false, 'open': () {},
        };
      }).toList();
      chatItems = inOps.reversed
          .map((t) => {
                'key': t['id'],
                'isTx': true, 'isText': false, 'isSys': false, 'isVoice': false, 'isVnote': false, 'isCode': false,
                ...txRow(t),
              })
          .toList();
    }

    if (client != null) {
      final b = balMain(bal(client['id']));
      cName = client['name'];
      cInitials = initials(client['name']);
      cBal = '${L0['balPfx']}${b['text']}';
      cBalColor = b['color'];

      final msgsList = _msgs()[client['id']] ?? [];
      chatItems = List.generate(msgsList.length, (mi) {
        final m = msgsList[mi];
        final mn = m['mine'] == true;
        if (m['k'] == 'voice' || m['k'] == 'vnote') {
          final key = '${client['id']}:$mi';
          final playing = S['playing'] as Map<String, dynamic>?;
          final p = (playing != null && playing['key'] == key) ? playing : null;
          final prog = p != null ? p['prog'] as double : 0.0;
          final isPlaying = p != null && p['paused'] != true;
          final checks = mn ? (m['read'] == true ? ' ✓✓' : ' ✓') : '';
          final dur = m['dur'] as int;
          if (m['k'] == 'voice') {
            const nBars = 24;
            final barsV = List.generate(nBars, (i) {
              final h = 4 + (math.sin(i * 2.7 + mi * 3.1).abs() * 12).round();
              final filled = (i + 1) / nBars <= prog;
              final c = mn
                  ? (filled ? bg : (dk ? const Color(0x590F0F10) : const Color(0x59FFFFFF)))
                  : (filled ? ink : P.skelDot);
              return {'h': h.toDouble(), 'c': c};
            });
            final cur = (prog * dur).round();
            return {
              'key': key, 'isVoice': true, 'isVnote': false, 'isText': false, 'isSys': false, 'isTx': false, 'isCode': false,
              'align': mn ? 'end' : 'start',
              'bg': mn ? ink : P.field,
              'pbg': mn ? bg : ink,
              'pfg': mn ? ink : bg,
              'tc': mn ? (dk ? const Color(0x800F0F10) : const Color(0x8CFFFFFF)) : (dk ? const Color(0xFF77777C) : const Color(0xFFA6A6A2)),
              'bars': barsV, 'isPlaying': isPlaying, 'notPlaying': !isPlaying,
              'durText': '0:${(p != null ? cur : dur).toString().padLeft(2, '0')}',
              'time': m['time'], 'checks': checks,
              'toggle': () => togglePlayReal(key, dur, m['audioUrl'] as String?),
            };
          }
          final rem = dur - (prog * dur).round();
          return {
            'key': key, 'isVnote': true, 'isVoice': false, 'isText': false, 'isSys': false, 'isTx': false, 'isCode': false,
            'align': mn ? 'end' : 'start',
            'prog': prog,
            'ringOn': ink, 'ringOff': dk ? const Color(0xFF2E2E2F) : const Color(0xFFE0E0DC),
            'vbg': P.field,
            'stripe': dk ? const Color(0x0DF5F5F5) : const Color(0x0D111111),
            'pbg2': dk ? const Color(0x2EF5F5F5) : const Color(0x8C111111),
            'pfg2': dk ? const Color(0xFFF5F5F5) : const Color(0xFFFFFFFF),
            'tcv': dk ? const Color(0x66F5F5F5) : const Color(0x59111111),
            'isPlaying': isPlaying, 'notPlaying': !isPlaying,
            'durText': '0:${(p != null ? rem : dur).toString().padLeft(2, '0')}',
            'time': m['time'], 'checks': checks,
            'toggle': () => togglePlayReal(key, dur, m['audioUrl'] as String?),
          };
        }
        if (m['k'] == 'text') {
          return {
            'key': '${client['id']}:$mi',
            'isText': true, 'isTx': false, 'isSys': false, 'isVoice': false, 'isVnote': false, 'isCode': false,
            'checks': mn ? (m['read'] == true ? ' ✓✓' : ' ✓') : '',
            'align': mn ? 'end' : 'start',
            'bg': mn ? ink : P.field,
            'fg': mn ? bg : ink,
            'tc': mn ? (dk ? const Color(0x730F0F10) : const Color(0x80FFFFFF)) : (dk ? const Color(0xFF77777C) : const Color(0xFFA6A6A2)),
            'text': m['text'], 'time': m['time'],
          };
        }
        if (m['k'] == 'sys') {
          return {
            'key': '${client['id']}:$mi',
            'isSys': true, 'isText': false, 'isTx': false, 'isVoice': false, 'isVnote': false, 'isCode': false,
            'text': m['text'],
          };
        }
        return {
          'key': '${client['id']}:$mi',
          'isTx': true, 'isText': false, 'isSys': false, 'isVoice': false, 'isVnote': false, 'isCode': false,
          ...txRow(_tx(m['tx'])!),
        };
      });

      final opsAll = _txs().where((t) => t['c'] == client['id']).toList().reversed.toList();
      opsRows = opsAll.take(S['opsVis'] as int).map((t) {
        final r = txRow(t);
        return {
          'key': t['id'],
          'type': typeLabel(t['type']),
          'date': t['date'],
          'amount': r['amount'], 'color': r['acolor'], 'st': r['stLabel'], 'dot': r['dot'],
          'canOpen': true,
          'open': () => set({'receiptId': t['id']}),
        };
      }).toList();
    }

    // Receipt
    final meStr = '${meLabel()} ${L0['you']}';
    String shortId(String id) => id.replaceAll('-', '').substring(0, math.min(6, id.replaceAll('-', '').length)).toUpperCase();
    String fullDate(int? ts) {
      if (ts == null || ts == 0) return '';
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      return '${d.day}-${_monU[d.month - 1]}, ${d.year}';
    }

    Map<String, dynamic> receipt = {'close': () {}, 'share': () {}, 'change': () {}, 'archive': () {}};
    final rt = _tx(S['receiptId']);
    if (rt != null) {
      final rc = _client(rt['c']);
      final rcName = rc != null ? rc['name'] as String : '';
      final meGives = rt['type'] == 'Qarz berdim' || rt['type'] == "To'lov berdim";
      receipt = {
        'id': 'TR-${shortId(rt['id'] as String)}',
        'type': typeLabel(rt['type']),
        'amount': money(rt['a'], rt['cur']),
        'from': meGives ? meStr : rcName,
        'to': meGives ? rcName : meStr,
        'date': fullDate(rt['ts'] as int?),
        'code': '', // link modelida operatsiya kodi yo'q
        'editPending': false,
        'editLine': '',
        'corrected': (rt['hist'] as List?)?.isNotEmpty == true,
        'histRows': (rt['hist'] as List?) ?? [],
        'close': () => set({'receiptId': null, 'pdfOpen': false}),
        'share': () => set({'pdfOpen': true}),
        'change': () {
          if (rt['by'] != 'me') {
            toast_(L()['tOnlyAuthor']);
          } else {
            set({'editFormOpen': true, 'editA': '', 'editNote': rt['note'] ?? ''});
          }
        },
        'archive': () async {
          final r = await Api.archiveOp(rt['id'] as String);
          if (!r.ok) {
            toast_(r.error);
            return;
          }
          set({
            'txs': _txs().map((x) => x['id'] == rt['id'] ? {...x, 'st': 'arch'} : x).toList(),
            'receiptId': null,
          });
          toast_(L0['tArch']);
        },
      };
    }

    // PDF preview
    Map<String, dynamic> pdf = {};
    if (rt != null) {
      final rc2 = _client(rt['c']);
      final rc2Name = rc2 != null ? rc2['name'] as String : '';
      final meGives2 = rt['type'] == 'Qarz berdim' || rt['type'] == "To'lov berdim";
      final myPhone = _fmtSrvPhone((S['mePhone'] as String?) ?? '');
      final okTs = rt['okTs'] as int?;
      String hhmmOf(int? ts) => ts == null || ts == 0 ? '—' : _hhmm(DateTime.fromMillisecondsSinceEpoch(ts));
      pdf = {
        'docId': 'TR-${DateTime.now().year}-${shortId(rt['id'] as String)}',
        'fromName': meGives2 ? meLabel() : rc2Name,
        'fromPhone': meGives2 ? myPhone : (rc2?['phone'] ?? ''),
        'toName': meGives2 ? rc2Name : meLabel(),
        'toPhone': meGives2 ? (rc2?['phone'] ?? '') : myPhone,
        'amount': money(rt['a'], rt['cur']),
        'type': typeLabel(rt['type']),
        'dateTime': '${fullDate(rt['ts'] as int?)} · ${hhmmOf(rt['ts'] as int?)}',
        'madeAt': hhmmOf(rt['ts'] as int?), 'okAt': hhmmOf(okTs),
        'code': '',
        'corrected': (rt['hist'] as List?)?.isNotEmpty == true,
        'histRows': (rt['hist'] as List?) ?? [],
      };
    }

    // Moliya
    final given = _txs().where((t) => t['st'] != 'pending' && t['type'] == 'Qarz berdim' && t['cur'] == 'UZS').fold<int>(0, (s, t) => s + (t['a'] as int));
    final taken = _txs().where((t) => t['st'] != 'pending' && t['type'] == 'Qarz oldim' && t['cur'] == 'UZS').fold<int>(0, (s, t) => s + (t['a'] as int));
    final repaid = _txs().where((t) => t['st'] != 'pending' && t['type'] == "To'lov oldim" && t['cur'] == 'UZS').fold<int>(0, (s, t) => s + (t['a'] as int));
    final molTotals = [
      {'label': L0['given'], 'value': money(given, 'UZS'), 'color': ink},
      {'label': L0['taken'], 'value': money(taken, 'UZS'), 'color': ink},
      {'label': L0['repaid'], 'value': money(repaid, 'UZS'), 'color': ink},
      {'label': L0['netLabel'], 'value': (net >= 0 ? '+' : '−') + money(net.abs(), 'UZS'), 'color': net > 0 ? green : (net < 0 ? red : ink)},
    ];
    // Oylik aylanma — real operatsiyalardan (oxirgi 6 oy, UZS)
    final nowD = DateTime.now();
    final barMonths = List.generate(6, (i) => DateTime(nowD.year, nowD.month - (5 - i), 1));
    final barSums = barMonths.map((m) {
      final next = DateTime(m.year, m.month + 1, 1);
      return _txs().where((t) {
        if (t['cur'] != 'UZS' || t['st'] == 'pending') return false;
        final ts = (t['ts'] as int?) ?? 0;
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        return !dt.isBefore(m) && dt.isBefore(next);
      }).fold<int>(0, (s, t) => s + (t['a'] as int));
    }).toList();
    final maxBar = math.max(barSums.fold<int>(0, math.max), 1);
    final bars = List.generate(6, (i) {
      final label = _monU[barMonths[i].month - 1];
      return {
        'label': label[0].toUpperCase() + label.substring(1),
        'val': (barSums[i] / 1000000).toStringAsFixed(1),
        'h': math.max(4.0, (barSums[i] / maxBar * 80).roundToDouble()),
        'bg': i == 5 ? ink : (dk ? const Color(0xFF2E2E2F) : const Color(0xFFE6E6E2)),
      };
    });
    Map<String, dynamic> mkRem(String key, String name, String sub) {
      final last = ((S['remTimes'] as Map)[key] as int?) ?? 0;
      final left = 10800000 - (DateTime.now().millisecondsSinceEpoch - last);
      final cool = last != 0 && left > 0;
      final hrs = left > 0 ? left ~/ 3600000 : 0;
      final mins = math.min(59, math.max(1, ((left % 3600000) / 60000).ceil()));
      return {
        'key': key, 'name': name, 'sub': sub,
        'canRemind': !cool, 'cooling': cool,
        'coolText': cool ? Lf('nextReminder', {'h': '${hrs}', 'm': '${mins}'}) : '',
        'remind': () async {
          final lt = ((S['remTimes'] as Map)[key] as int?) ?? 0;
          if (DateTime.now().millisecondsSinceEpoch - lt < 10800000) return;
          final r = await Api.remind(key);
          if (!r.ok) {
            if (r.status == 429) {
              // server cooldown — lokal hisoblagichni ham yoqamiz
              set({'remTimes': {...(S['remTimes'] as Map), key: DateTime.now().millisecondsSinceEpoch}});
            }
            toast_(r.error);
            return;
          }
          set({'remTimes': {...(S['remTimes'] as Map), key: DateTime.now().millisecondsSinceEpoch}});
          toast_(Lf('tReminderSent', {'name': name.split(' ')[0]}));
        },
      };
    }
    // Eslatmalar — menga qarzi bor, Trust'dagi hamkorlar
    final reminders = _clients().where((c) => c['archived'] != true && c['onTrust'] != false).map((c) {
      final b = bal(c['id'] as String);
      // Har qanday valyutadagi musbat qoldiq eslatmaga tushadi (ilgari faqat UZS/USD edi).
      String? cur;
      int v = 0;
      for (final k in [...curOrder.where(b.containsKey), ...b.keys.where((k) => !curOrder.contains(k))]) {
        if ((b[k] ?? 0) > 0) { cur = k; v = b[k]!; break; }
      }
      if (cur == null || v <= 0) return null;
      return mkRem(c['id'] as String, c['name'] as String, money(v, cur));
    }).whereType<Map<String, dynamic>>().toList();

    final xarV = _xarVals(P, money);
    // Bosh hub (ildiz ekran) — dizayn: prototype/bosh-ekran.dc.html «4-tur»
    final hubV = _hubVals(initials, linksAll: linksAll, bal: bal);

    // Profil
    Map<String, dynamic> mkSwitch(String label, bool on, VoidCallback tap) => {
          'label': label, 'isSwitch': true, 'isPlain': false, 'value': '',
          'trk': on ? ink : (dk ? const Color(0xFF3A3A3C) : const Color(0xFFD9D9D5)),
          'knob': dk ? const Color(0xFF0F0F10) : const Color(0xFFFFFFFF),
          'knobLeft': on ? 21.0 : 3.0,
          'tap': tap,
        };
    final rejCount = linksAll.where((l) => l['status'] == 'rejected').length;
    final profRows = [
      {'label': L0['profTil'], 'value': L0['profTilVal'], 'isPlain': true, 'isSwitch': false, 'tap': () => set({'langOpen': true})},
      // Asosiy valyuta — bosishda aylanadi (UZS -> USD -> EUR -> RUB), yangi yozuv defaulti
      {'label': L0['profCur'], 'value': '${S['cur'] ?? 'UZS'}', 'isPlain': true, 'isSwitch': false, 'tap': () => cycleCur_()},
      mkSwitch(L0['darkMode'], dk, () => setDark(!dk)),
      mkSwitch(L0['profPin'], S['pinOn'] == true, () => _togglePin()),
      // PIN kodni o'zgartirish — joriy PIN tasdig'i bilan (faqat PIN yoniq bo'lsa)
      if (S['pinOn'] == true)
        {
          'label': L0['profPinChange'] ?? "PIN kodni o'zgartirish",
          'value': '', 'isPlain': true, 'isSwitch': false,
          'tap': () => pinChangeStart_(),
        },
      // Bildirishnomalar — serverda saqlanadi (op_new/rem shu bilan boshqariladi)
      mkSwitch(L0['profNotif'], S['notifOn'] == true, () async {
        final v = S['notifOn'] != true;
        set({'notifOn': v});
        final r = await Api.updateProfile(notifEnabled: v);
        if (!r.ok) {
          set({'notifOn': !v});
          toast_(r.error);
        }
      }),
      // Yordam chati (PO #10) — xabarlar jamoa Telegramiga tushadi, javob shu yerga keladi
      {
        'label': L0['profSupport'] ?? 'Yordam chati',
        'value': '', 'isPlain': true, 'isSwitch': false,
        'tap': () => openSupport_(),
      },
      // Rad etilgan bog'lanishlar — istalgan payt tiklash mumkin
      {
        'label': L0['rejLinks'],
        'value': rejCount > 0 ? rejCount.toString() : '',
        'isPlain': true, 'isSwitch': false,
        'tap': () => set({'rejOpen': true}),
      },
      {
        'label': L0['profArch'],
        'value': () {
          final n = _txs().where((t) => t['st'] == 'arch').length;
          return n > 0 ? n.toString() : '';
        }(),
        'isPlain': true, 'isSwitch': false, 'tap': () {},
      },
      // Obuna: 7 kun bepul sinov, keyin $9/oy (to'lov integratsiyasi keyingi bosqichda)
      {
        'label': L0['profSub'] ?? 'Obuna',
        'value': () {
          final st = S['subStatus'] as String? ?? 'free';
          if (st == 'premium') {
            // "Premium · 12.08.2026" — konsumer bir qarashda qachongacha ekanini ko'radi
            final pu = _dt(S['premUntil'] as String?);
            final base = L()['subPremium'] as String;
            if (pu == null) return base;
            String d2(int x) => x.toString().padLeft(2, '0');
            return '$base · ${d2(pu.day)}.${d2(pu.month)}.${pu.year}';
          }
          final te = _dt(S['trialEnd'] as String?);
          if (st == 'trial' && te != null) {
            final left = te.difference(DateTime.now()).inDays + 1;
            return Lf('subTrialLeft', {'n': '${left.clamp(0, 7)}'});
          }
          // MUHIM (2026-08-02 audit): server 'free' qaytaradi (trial modeli olib
          // tashlangan), lekin klient uni bilmasdi va HAR BIR yangi foydalanuvchiga
          // birinchi kunidayoq "Sinov tugagan" deb ko'rsatardi. Endi bepul kvota
          // ko'rsatiladi (raqamlar serverdan — UI hech narsa hardcode qilmaydi).
          if (st != 'expired') {
            final used = S['debtsUsed'];
            final lim = S['freeDebtEntries'];
            if (used is int && lim is int && lim > 0) {
              return '${L()['subFree'] ?? 'Bepul'} · $used/$lim';
            }
            return (L()['subFree'] as String?) ?? 'Bepul';
          }
          // Yuqoridagi 'subFree' bilan bir xil himoyali o'qish: kalit yo'q
          // bo'lsa (yangi til qo'shilganda) profil qatori yiqilmasin.
          return (L()['subExpiredShort'] as String?) ?? 'Tugagan';
        }(),
        'isPlain': true, 'isSwitch': false,
        'tap': () => toast_(L()['subInfo']),
      },
      // Profilni o'chirish (App Store/Play siyosati) — SOFT: qarshi tomonda daftar qoladi.
      // #34: bosilganda SMS kod yuboriladi va tasdiqlash modali ochiladi.
      {
        'label': L0['profDelete'] ?? "Profilni o'chirish",
        'value': '', 'isPlain': true, 'isSwitch': false, 'danger': true,
        'tap': () => profileDeleteAsk_(),
      },
    ];

    // Sheet
    final f = Map<String, dynamic>.from(S['form']);
    final types = ['Qarz berdim', 'Qarz oldim', "To'lov oldim", "To'lov berdim"]
        .map((tp) => {
              'key': tp,
              'label': typeLabel(tp),
              'bg': f['type'] == tp ? ink : bg,
              'fg': f['type'] == tp ? bg : ink,
              'bd': f['type'] == tp ? ink : bd,
              'pick': () => set({'form': {...f, 'type': tp}}),
            })
        .toList();
    // MUHIM (2026-08-02 audit): ilgari bu ro'yxat ['UZS','USD'] edi, ammo forma
    // valyutasi profil valyutasidan olinadi (EUR/RUB bo'lishi mumkin). Natijada
    // HECH BIR chip tanlangan ko'rinmasdi va foydalanuvchi valyutani ko'ra ham,
    // to'g'rilay ham olmasdi — yozuv esa EUR bo'lib ketaverardi.
    final curs = _curList
        .map((cu) => {
              'key': cu, 'label': cu,
              'bg': f['currency'] == cu ? ink : bg,
              'fg': f['currency'] == cu ? bg : ink,
              'pick': () => set({'form': {...f, 'currency': cu}}),
            })
        .toList();
    final shCl = _client(S['sheetClient']);
    final sheetClients = _clients()
        .where((c) => c['archived'] != true)
        .map((c) => {
              'key': c['id'],
              'name': (c['name'] as String).split(' ')[0],
              'bg': S['sheetClient'] == c['id'] ? ink : bg,
              'fg': S['sheetClient'] == c['id'] ? bg : ink,
              'bd': S['sheetClient'] == c['id'] ? ink : bd,
              'pick': () => set({'sheetClient': c['id']}),
            })
        .toList();

    // Onboarding
    final stage = S['stage'] as String;
    final ccOnb = ccEntry(S['onbCc']);
    final ccNp = ccEntry(S['npCc']);
    String fmtPhone(String d) {
      var out = d.substring(0, math.min(2, d.length));
      if (d.length > 2) out += ' ${d.substring(2, math.min(5, d.length))}';
      if (d.length > 5) out += ' ${d.substring(5, math.min(7, d.length))}';
      if (d.length > 7) out += ' ${d.substring(7, math.min(9, d.length))}';
      return out;
    }

    String fmtIntl(String d, String dial) => dial == '+998'
        ? fmtPhone(d)
        : d.replaceAllMapped(RegExp(r'(\d{3})(?=\d)'), (m) => '${m.group(1)} ');
    final otpVal = S['otpVal'] as String;
    final otpBoxes = List.generate(5, (i) => {
          'key': 'ob$i',
          'd': i < otpVal.length ? otpVal[i] : '',
          'bd': (stage == 'otp' && i == math.min(otpVal.length, 4)) ? ink : bd,
        });
    final pinVal = S['pinVal'] as String;
    final pinDots = List.generate(4, (i) => {
          'key': 'pd$i',
          'bg': i < pinVal.length ? ink : Colors.transparent,
        });

    // Notifications
    final notifRows = _notifs().map((n) {
      final k = n['kind'] as String;
      return {
        'key': n['id'],
        'title': n['title'], 'detail': n['detail'], 'time': n['time'], 'unread': n['unread'] == true,
        'isReq': k == 'linknew',
        'isMsg': k == 'msg', // chat yashirin (flags.dart): notifs.dart neytral "i" ko'rsatadi
        'isOk': k == 'linkacc' || k == 'opnew' || k == 'confirmed',
        'isRem': k == 'reminder',
        'isEdit': k == 'debt',
        'isRej': k == 'linkrej' || k == 'rejected',
        'tap': () => openFromNotif(n),
      };
    }).toList();

    // Bog'lanish qarori sheet'i (minimal preview: kim, nechta yozuv, umumiy summa)
    final ldLink = _link(S['linkDecisionId'] as String?);
    final ld = ldLink == null
        ? <String, dynamic>{}
        : {
            'name': ldLink['name'],
            'sellerLabel': ldLink['sellerLabel'],
            'initials': initials(ldLink['name'] as String),
            'opsCount': Lf('nRecords', {'n': '${ldLink['opsCount']}'}),
            'total': (ldLink['total'] as int) == 0
                ? L0['zero']
                : ((ldLink['total'] as int) > 0 ? '+' : '−') + money((ldLink['total'] as int).abs(), 'UZS'),
            'totalColor': (ldLink['total'] as int) > 0 ? green : ((ldLink['total'] as int) < 0 ? red : mut),
            'accept': () => linkAct(ldLink['id'] as String, 'accept',
                okMsg: L()['okLinkAccepted'] as String),
            'reject': () => linkAct(ldLink['id'] as String, 'reject',
                okMsg: L()['okLinkRejected'] as String),
          };

    // Rad etilganlar ro'yxati (tiklash faqat mijoz qo'lida)
    final rejRows = linksAll.where((l) => l['status'] == 'rejected').map((l) {
      final lid = l['id'] as String;
      return {
        'key': lid,
        'name': l['name'], 'initials': initials(l['name'] as String),
        'sub': Lf('nRecordsBy', {'n': '${l['opsCount']}', 'seller': '${l['sellerLabel']}'}),
        'restore': () => linkAct(lid, 'restore', okMsg: L()['okLinkRestored'] as String),
      };
    }).toList();

    final active = ink, idle = P.idle;
    final noClient = S['clientId'] == null && !incoming;

    return {
      // Ildiz ekran — bosh hub (pastki nav olib tashlandi: flags.kBottomNavEnabled)
      'isHub': S['screen'] == 'hub' && noClient,
      'isHome': S['screen'] == 'home' && noClient,
      'isCircles': S['screen'] == 'circles' && noClient,
      'isAi': S['screen'] == 'ai' && noClient,
      'isXarajat': S['screen'] == 'xarajat' && noClient,
      // Modul bo'limlari — hub kartasidan ochiladigan to'liq ekranlar
      'isToyxona': S['screen'] == 'toyxona' && noClient,
      'isIjara': S['screen'] == 'ijara' && noClient,
      'isProfil': S['screen'] == 'profil' && noClient,
      'netText': fActive
          ? (pNet >= 0 ? '+' : '−') + money(pNet.abs(), 'UZS')
          : (net >= 0 ? '+' : '−') + money(net.abs(), 'UZS'),
      'netColor': (fActive ? pNet : net) > 0 ? green : ((fActive ? pNet : net) < 0 ? red : ink),
      'owedToMe': fActive
          ? money(pToMe, 'UZS')
          : money(toMeUZS, 'UZS') + (toMeUSD != 0 ? ' · ${money(toMeUSD, 'USD')}' : ''),
      'owedByMe': money(fActive ? pByMe : byMe, 'UZS'),
      'search': S['search'],
      'onSearch': (String t) => set({'search': t, 'homeVis': 6}),
      // Header: sarlavha (menyu nomi) + davr filtri dropdown
      'homeTitle': L0['homeTitle'] as String,
      'homeFilter': S['homeFilter'],
      'homeFilterActive': S['homeFilter'] != 'all',
      'homeFilterOpen': S['homeFilterOpen'] == true,
      'homeFilterTap': () => set({'homeFilterOpen': S['homeFilterOpen'] != true}),
      'homeFilterClose': () => set({'homeFilterOpen': false}),
      'homeFilterCap': L0['fltCap'] as String,
      'homeFilterLabel': fltLabel_(L0),
      'homeFilterReset': () => setHomeFilter_('all'),
      'homeFilterOpts': [
        for (final o in const [
          ['all', 'fltAll'], ['today', 'fltToday'], ['yesterday', 'fltYesterday'],
          ['week', 'fltWeek'], ['month', 'fltMonth'],
        ])
          {
            'id': o[0],
            'label': L0[o[1]] as String,
            'on': S['homeFilter'] == o[0],
            'pick': () => setHomeFilter_(o[0]),
          },
      ],
      'homeFilterCustomLabel': L0['fltCustom'] as String,
      'homeFilterCustomOn': S['homeFilter'] == 'custom',
      // Ekran (home.dart) custom bosilganda: avval shu yopadi, so'ng sana oralig'i
      // tanlagichi ochiladi va natija homeFilterCustom(from, to) ga keladi.
      'homeFilterCustomPick': () => set({'homeFilterOpen': false}),
      'homeFilterFrom': S['homeFilterFrom'],
      'homeFilterTo': S['homeFilterTo'],
      'homeFilterCustom': (int from, int to) => setHomeFilter_('custom', from: from, to: to),
      'clientRows': homeRows,
      'hasArch': S['skelHome'] != true && _clients().any((c) => c['archived'] == true),
      'archCount': _clients().where((c) => c['archived'] == true).length,
      'archRows': _clients().where((c) => c['archived'] == true).map((c) {
        final aid = 'a${c['id']}';
        final cid = c['id'] as String;
        return {
          'id': aid,
          'tx': S['swipeId'] == aid ? S['swipeDx'] : (S['swipeSnap'] == aid ? -96.0 : 0.0),
          'anim': S['swipeId'] != aid,
          'name': c['name'], 'initials': initials(c['name']),
          'restoreAct': () => restore_(cid),
          'rowTap': () {
            if (_swClick) {
              _swClick = false;
              return;
            }
            if (S['swipeSnap'] == aid) set({'swipeSnap': null});
          },
          'restore': () => restore_(cid),
        };
      }).toList(),
      'skelHome': homeSkel,
      'skelRows': const [
        {'key': 'sk1', 'w1': 0.46, 'w2': 0.30}, {'key': 'sk2', 'w1': 0.58, 'w2': 0.26},
        {'key': 'sk3', 'w1': 0.40, 'w2': 0.34}, {'key': 'sk4', 'w1': 0.52, 'w2': 0.24},
        {'key': 'sk5', 'w1': 0.44, 'w2': 0.30}, {'key': 'sk6', 'w1': 0.56, 'w2': 0.28},
      ],
      'homeLoadingMore': S['homeLoadingMore'],
      'homeMore': () {
        if (S['skelHome'] == true || S['homeLoadingMore'] == true) return;
        // vals() ro'yxati bilan BIR XIL filtr (qidiruv + davr) — _homeClients
        final flt = _homeClients();
        if (flt.length <= (S['homeVis'] as int)) return;
        set({'homeLoadingMore': true});
        Timer(const Duration(milliseconds: 550), () => set({'homeVis': (S['homeVis'] as int) + 10, 'homeLoadingMore': false}));
      },
      'openSheetHome': () => set({'npOpen': true, 'npName': '', 'npPhone': ''}),
      'npOpen': S['npOpen'],
      'npClose': () => set({'npOpen': false}),
      'npName': S['npName'],
      'onNpName': (String t) => set({'npName': t}),
      'npPhoneText': fmtIntl(S['npPhone'], S['npCc']),
      'onNpPhone': (String t) {
        var d = t.replaceAll(RegExp(r'\D'), '');
        if (d.length > (ccNp['len'] as int)) d = d.substring(0, ccNp['len'] as int);
        set({'npPhone': d});
      },
      'npCcFlag': ccNp['f'], 'npCcDial': ccNp['d'], 'npPh': ccNp['ph'],
      'npHint': L()['npHintFull'] as String,
      'npCreate': () async {
        final nm = (S['npName'] as String).trim();
        if (nm.isEmpty) {
          toast_(L()['enterName'] as String);
          return;
        }
        if ((S['npPhone'] as String).length != ccNp['len']) {
          toast_(L0['tNum']);
          return;
        }
        if (_busy) return;
        _busy = true;
        _setBusy('npCreate');
        final r = await Api.createPartner(nm, '${S['npCc']}${S['npPhone']}');
        _busy = false;
        _setBusy(null);
        if (!r.ok) {
          // RECIPROCAL: raqam egasi SIZNI allaqachon qo'shgan — dublikat yaratilmadi.
          // Mavjud kiruvchi so'rovga yo'naltiramiz: pending -> qaror sheet, accepted -> daftar.
          if (r.code == 'RECIPROCAL_LINK' && r.body['link_id'] != null) {
            final lid = '${r.body['link_id']}';
            final kr = await Api.links();
            if (kr.ok && kr.data is List) {
              set({'links': (kr.data as List).cast<Map<String, dynamic>>().map(_mapLink).toList()});
            }
            set({'npOpen': false});
            if (r.body['link_status'] == 'accepted') {
              openIncoming(lid);
            } else {
              set({'linkDecisionId': lid});
            }
            return;
          }
          toast_(r.error);
          return;
        }
        final cl = _mapPartner(r.data as Map<String, dynamic>);
        set({
          'clients': [cl, ..._clients()],
          'npOpen': false, 'clientId': cl['id'], 'tab': 'chat', 'cMenuOpen': false, 'cRen': null,
          'pProfOpen': false, 'opsVis': 8, 'inLinkId': null,
        });
        openLedger_(cl['id'] as String); // yangi (bo'sh) daftar + polling
        toast_(L()['tPartnerAdded']);
        hydrate(full: false);
      },
      'goHome': () => set({'screen': 'home', 'clientId': null, 'receiptId': null, 'inLinkId': null, 'npOpen': false,
          'homeFilterOpen': false}),
      'goCircles': () {
        set({'screen': 'circles', 'clientId': null, 'receiptId': null, 'inLinkId': null});
        loadCircles();
      },
      'goAi': () {
        // Back "qayerdan kelgan bo'lsa o'shanga qaytadi": AI'ga o'tishdan OLDIN joriy
        // asosiy tabni saqlaymiz (faqat home/xarajat/profil/circles — aks holda 'home').
        final from = S['screen'];
        final mainTab = from == 'hub' ||
            from == 'home' ||
            from == 'xarajat' ||
            from == 'profil' ||
            from == 'circles';
        set({
          'screen': 'ai',
          'aiFrom': mainTab ? from : 'hub',
          'clientId': null,
          'receiptId': null,
          'inLinkId': null,
        });
        loadAiMsgs(); // tarix bir marta yuklanadi (aiLoaded)
      },
      // AI header'idagi orqaga tugmasi — kelib chiqqan ekranga qaytadi (odatda hub).
      'goAiBack': () => set(
          {'screen': S['aiFrom'] ?? 'hub', 'clientId': null, 'receiptId': null, 'inLinkId': null}),
      'goProfil': () => set({'screen': 'profil', 'clientId': null, 'receiptId': null, 'inLinkId': null}),
      'goXarajat': () => set({'screen': 'xarajat', 'clientId': null, 'receiptId': null, 'inLinkId': null}),
      'cMij': S['screen'] == 'home' ? active : idle,
      'cCircle': S['screen'] == 'circles' ? active : idle,
      'cAi': S['screen'] == 'ai' ? active : idle,
      'cXar': S['screen'] == 'xarajat' ? active : idle,
      'cProf': S['screen'] == 'profil' ? active : idle,
      ...circleNav(),
      ...xarV,
      ...hubV,

      'clientOpen': client != null || incoming,
      'incoming': incoming,
      'cName': cName, 'cInitials': cInitials, 'cBal': cBal, 'cBalColor': cBalColor,
      'hasPend': false, 'pendText': '',
      'canFlip': false,
      'oneSided': client != null && client['onTrust'] == false,
      'cOnTrust': (client != null && client['onTrust'] != false) || incoming,
      // Badge «in Trust» — ro'yxatdan o'tganlik (accepted'ni kutmaydi). cOnTrust
      // (accepted) esa ledger/reminder mantig'i uchun o'zgarmasdan qoladi.
      'cInTrust': (client != null && client['inTrust'] == true) || incoming,
      // Bog'lanish holati banneri (sotuvchi ko'rinishida)
      'linkPending': client != null && client['linkStatus'] == 'pending',
      'linkRejected': client != null && client['linkStatus'] == 'rejected',
      'menuOpen': S['cMenuOpen'],
      'menuTap': () => set({'cMenuOpen': S['cMenuOpen'] != true}),
      'menuClose': () => set({'cMenuOpen': false}),
      'menuRename': () =>
          set({'cMenuOpen': false, 'cRen': client != null ? client['name'] : (incoming ? inLink['name'] : '')}),
      'menuArchive': () {
        if (client == null) return;
        set({'cMenuOpen': false, 'clientId': null});
        archive_(client['id'] as String);
      },
      'menuProfile': () => set({'cMenuOpen': false, 'pProfOpen': true}),
      // Mijoz tomonida: aloqani uzish (yozuvlar yashirinadi, istalgan payt tiklanadi)
      'menuDisconnect': () {
        if (!incoming) return;
        set({'cMenuOpen': false});
        linkAct(inLink['id'] as String, 'disconnect',
            okMsg: L()['okDisconnected'] as String);
      },
      'renaming': S['cRen'] != null,
      'notRenaming': S['cRen'] == null,
      'showChev': true,
      'renVal': S['cRen'] ?? '',
      'onRen': (String t) => set({'cRen': t}),
      'renSave': () async {
        // Kiruvchi bog'lanishda — mijozning o'z aliasi (serverda client_alias)
        if (incoming) {
          final v = ((S['cRen'] as String?) ?? '').trim();
          if (v.isEmpty) {
            set({'cRen': null});
            return;
          }
          final r = await Api.linkAlias(inLink['id'] as String, v);
          if (!r.ok) {
            toast_(r.error);
            return;
          }
          set({
            'links': linksAll.map((l) => l['id'] == inLink['id'] ? {...l, 'name': v} : l).toList(),
            'cRen': null,
          });
          toast_(L()['tNameUpdated']);
          return;
        }
        renSave_();
      },
      'pProfOpen': S['pProfOpen'],
      'pProfClose': () => set({'pProfOpen': false}),
      'pPhone': client != null ? client['phone'] : (incoming ? inLink['phone'] : ''),
      'pStatus': client != null
          ? (client['linkStatus'] == 'accepted'
              ? (L()['pStatusLinked'] as String)
              : (L()['pStatusPending'] as String))
          : (incoming ? (L()['pStatusIncoming'] as String) : ''),
      'pOps': client != null
          ? _txs().where((t) => t['c'] == client['id']).length.toString()
          : (incoming ? '${inLink['opsCount']}' : ''),
      'pBal': cBal.replaceFirst(L0['balPfx'] as String, ''),
      'inviteTap': () {
        if (client == null) return;
        toast_(L()['tInviteAuto']);
      },
      'back': () {
        stopLedgerPoll_(); // ledger polling to'xtaydi
        set({'clientId': null, 'inLinkId': null, 'cMenuOpen': false, 'cRen': null, 'pProfOpen': false});
      },
      'toChat': () => set({'tab': 'chat'}),
      'toOps': () {
        final cid = S['clientId'] as String?;
        if (cid != null && _opsSeen[cid] != true) {
          _opsSeen[cid] = true;
          set({'tab': 'ops', 'skelOps': true});
          Timer(const Duration(milliseconds: 650), () => set({'skelOps': false}));
        } else {
          set({'tab': 'ops'});
        }
      },
      'skelOps': S['skelOps'],
      'notSkelOps': S['skelOps'] != true,
      'opsLoadingMore': S['opsLoadingMore'],
      'opsMore': () {
        if (S['skelOps'] == true || S['opsLoadingMore'] == true || S['clientId'] == null) return;
        final cnt = _txs().where((t) => t['c'] == S['clientId']).length;
        if (cnt <= (S['opsVis'] as int)) return;
        set({'opsLoadingMore': true});
        Timer(const Duration(milliseconds: 550), () => set({'opsVis': (S['opsVis'] as int) + 10, 'opsLoadingMore': false}));
      },
      'isChatTab': S['tab'] == 'chat',
      'isOpsTab': S['tab'] == 'ops',
      'chatTabColor': S['tab'] == 'chat' ? ink : mut,
      'chatTabLine': S['tab'] == 'chat' ? ink : Colors.transparent,
      'opsTabColor': S['tab'] == 'ops' ? ink : mut,
      'opsTabLine': S['tab'] == 'ops' ? ink : Colors.transparent,
      'chatItems': chatItems, 'opsRows': opsRows,
      'chatInput': S['chatInput'],
      'onChatInput': (String t) => set({'chatInput': t}),
      'sendChat': () {
        final text = (S['chatInput'] as String).trim();
        if (text.isEmpty || client == null) return;
        set({'chatInput': ''});
        // REAL chat: serverga yoziladi — qarshi tomonga yetib boradi (badge/notification)
        sendChatServer_(client['id'] as String, text);
      },
      // Kiruvchi daftar faqat o'qish uchun — yangi yozuvni faqat sotuvchi kiritadi
      'canWrite': client != null,
      'openSheetClient': () {
        if (client == null) return;
        set({'sheetOpen': true, 'sheetMode': 'fixed', 'sheetClient': client['id']});
      },
      'hasText': (S['chatInput'] as String).trim().isNotEmpty,
      'noText': (S['chatInput'] as String).trim().isEmpty,

      // ================= QARZ DAFTARI (ledger) — client_screen UI =================
      ...(() {
        try {
          // Ledger ikki tomonli: o'z hamkorim (client) YOKI meni qo'shgan tomon (incoming inLink).
          if (client == null && inLink == null) return <String, dynamic>{'hasLedger': false};
          final pid = (client?['id'] ?? inLink?['id']) as String?;
          if (pid == null) return <String, dynamic>{'hasLedger': false};
          final pName = (client?['name'] ?? inLink?['name'] ?? '') as String;
          final firstName = pName.trim().split(' ').first;
          final led = _ledgerFor(pid);
          final accepted = inLink != null ? (inLink['status'] == 'accepted') : (client?['onTrust'] != false);

          String fmtAmt(int a, String cur) => money(a, cur);
          String fmtDate(DateTime d) => '${d.day}-${_monU[d.month - 1]}';
          String balParts(Map<String, int> m) =>
              m.entries.map((e) => fmtAmt(e.value.abs(), e.key)).join(' + ');

          // ---- Header balans (spec 4.9) ----
          final bals = led.balances();
          final unver = led.unverifiedBalances();
          final inCur = <String, int>{}, outCur = <String, int>{};
          bals.forEach((c, v) {
            if (v > 0) {
              inCur[c] = v;
            } else if (v < 0) outCur[c] = -v;
          });
          bool overIn = false, overOut = false;
          for (final d in led.entries) {
            if (led.isOverdue(d)) {
              if (d.direction == DebtDir.toMe) overIn = true;
              if (d.direction == DebtDir.fromMe) overOut = true;
            }
          }
          String unvSfx(bool isIn) {
            final u = unver.entries.where((e) => isIn ? e.value > 0 : e.value < 0);
            if (u.isEmpty) return '';
            final m = {for (final e in u) e.key: e.value.abs()};
            return Lf('unconfSuffix', {'a': '${balParts(m)}'});
          }
          final balLines = <Map<String, dynamic>>[];
          if (inCur.isNotEmpty) {
            balLines.add({'text': Lf('balOwesYou', {'a': '${balParts(inCur)}'}) + unvSfx(true) + (overIn ? (L()['balOverdueSfx'] as String) : ''), 'color': overIn ? red : green});
          }
          if (outCur.isNotEmpty) {
            balLines.add({'text': Lf('balYouOwe', {'a': '${balParts(outCur)}'}) + unvSfx(false) + (overOut ? (L()['balOverdueSfx'] as String) : ''), 'color': red});
          }
          // «hisob teng» qatori olib tashlandi (PO sinov) — bo'sh balLines muammosiz render bo'ladi.

          // ---- Tasdiqlash cardlari (qarshi tomon pending amallari) ----
          final cards = <Map<String, dynamic>>[];
          for (final e in led.entries) {
            final mine = e.createdBy == '${S['meId']}';
            if (mine) continue;
            if (e.pendingEdit != null) {
              final pe = e.pendingEdit!;
              final diffs = <Map<String, dynamic>>[];
              if (pe.amount != e.amount) diffs.add({'label': L()['lblAmount'] as String, 'old': fmtAmt(e.amount, e.currency), 'new': fmtAmt(pe.amount, e.currency)});
              if (_isoDate(pe.due) != _isoDate(e.due)) diffs.add({'label': L()['lblDue'] as String, 'old': _isoDate(e.due).isEmpty ? '—' : _isoDate(e.due), 'new': _isoDate(pe.due).isEmpty ? '—' : _isoDate(pe.due)});
              if (pe.note != e.note) diffs.add({'label': L()['lblNote'] as String, 'old': e.note.isEmpty ? '—' : e.note, 'new': pe.note.isEmpty ? '—' : pe.note});
              cards.add({
                'id': e.id, 'isEdit': true, 'cap': L()['capChangeReq'] as String,
                'title': _debtTitle(e, led), 'diffs': diffs,
                'confirm': () => ledgerEditConfirm_(e.id), 'reject': () => ledgerEditReject_(e.id),
              });
            } else if (e.status == EntryStatus.pending) {
              final refDebt = e.ref != null ? led.entries.where((x) => x.id == e.ref).firstOrNull : null;
              cards.add({
                'id': e.id, 'isEdit': false, 'cap': L()['capNeedConfirm'] as String,
                'title': _debtTitle(e, led),
                'amount': (e.kind == EntryKind.debt && e.direction == DebtDir.toMe ? '+' : e.kind == EntryKind.debt ? '−' : '') + fmtAmt(e.amount, e.currency),
                'sub': [
                  fmtDate(e.date),
                  if (e.due != null) Lf('duePfx', {'d': '${_isoDate(e.due)}'}),
                  if (e.note.isNotEmpty) e.note,
                  if (refDebt != null) Lf('remainPfx', {'a': '${fmtAmt(led.remainingEff(refDebt), refDebt.currency)}'}),
                ].join(' · '),
                'confirm': () => e.kind == EntryKind.debt ? ledgerConfirm_(e.id) : ledgerConfirmOp_(e.id),
                // MUHIM (2026-08-02 audit): 'reject' ham TURGA qarab tarmoqlanadi.
                // Ilgari har doim /reject chaqirilardi, u esa faqat 'debt' ni qabul
                // qiladi — ya'ni soxta "qaytardim" yozuvini rad etish tugmasi
                // DOIM xato berardi, qarz esa pending amal bilan qulflanib qolardi.
                'reject': () => e.kind == EntryKind.debt ? ledgerReject_(e.id) : ledgerRejectOp_(e.id),
              });
            }
          }

          // ---- Review bloki (join, spec 5.1) ----
          final review = led.reviewDebts();
          final reviewCards = review.map((d) {
            final ops = led.relatedOps(d.id);
            final repaid = ops.where((o) => o.status == EntryStatus.ok).fold<int>(0, (s, o) => s + o.amount);
            return {
              'id': d.id, 'title': _debtTitle(d, led),
              'amount': fmtAmt(d.amount, d.currency),
              'sub': [fmtDate(d.date), if (d.note.isNotEmpty) d.note, Lf('remainPfx', {'a': '${fmtAmt(d.remaining, d.currency)}'}), if (repaid > 0) '${L()['paidLabel'] as String} ${fmtAmt(repaid, d.currency)}'].join(' · '),
              'confirm': () => ledgerReviewConfirm_(d.id), 'reject': () => ledgerReviewReject_(d.id),
            };
          }).toList();

          // ---- Lenta kartochkalari (barcha yozuvlar, chronologik) ----
          final feed = led.entries.map((e) {
            final mine = e.createdBy == '${S['meId']}';
            final isDebtEntry = e.kind == EntryKind.debt;
            final signPos = isDebtEntry && e.direction == DebtDir.toMe;
            final over = led.isOverdue(e);
            final paidPct = e.amount > 0 ? (e.paid / e.amount * 100).clamp(0, 100).round() : 0;
            return {
              'id': e.id,
              'side': led.sideOf(e).name, // 'left' | 'right' — chat alignment (debt_ledger.dart)
              'title': _debtTitle(e, led),
              'amount': isDebtEntry ? ((signPos ? '+' : '−') + fmtAmt(e.amount, e.currency)) : fmtAmt(e.amount, e.currency),
              'amountColor': isDebtEntry ? (signPos ? green : red) : mut,
              'date': fmtDate(e.date),
              'due': e.due != null ? Lf('duePfx', {'d': '${_isoDate(e.due)}'}) : '',
              'note': e.note,
              'stLabel': _stLabel(e.status),
              'stColor': _stColor(e.status, ink, red, mut),
              'isActive': e.status == EntryStatus.active,
              'isClosed': e.status == EntryStatus.closed,
              'isDead': e.status == EntryStatus.rejected || e.status == EntryStatus.cancelled,
              'disputed': e.status == EntryStatus.disputed,
              'oneSided': e.isOneSided,
              'reviewing': e.underReview,
              'edited': e.versions.isNotEmpty,
              'progW': isDebtEntry && e.status == EntryStatus.active ? paidPct : 0,
              'progText': isDebtEntry && (e.status == EntryStatus.active || e.status == EntryStatus.closed) ? Lf('closedProgress', {'paid': '${fmtAmt(e.paid, e.currency)}', 'amount': '${fmtAmt(e.amount, e.currency)}'}) : '',
              'forgivenText': e.forgiven > 0 ? Lf('forgivenLine', {'r': '${fmtAmt(e.paid - e.forgiven, e.currency)}', 'f': '${fmtAmt(e.forgiven, e.currency)}'}) : '',
              'overdue': over ? Lf('overdueDays', {'n': '${DateTime.now().difference(e.due!).inDays}'}) : '',
              'canCancel': mine && (e.status == EntryStatus.pending || e.status == EntryStatus.disputed),
              'cancel': () => ledgerCancel_(e.id),
              'open': () => histOpen_(e.id),
            };
          }).toList().reversed.toList();

          // ---- 3 tugma (spec 4.4) ----
          // ---- Tugmalar (PO 2026-07-28): "Qarz olish" OLIB TASHLANDI — qarz olish
          // kontragentning "qarz berish"i bilan bir xil ma'no, chalkashlik tug'dirardi.
          // Ledger SEMANTIK KOD qaytaradi — matn shu yerda l10n orqali quriladi;
          // kalit tarjimada hali bo'lmasa uz-fallback (xarajat.dart _t naqshi).
          String lfb(String key, String fb, [Map<String, String> vars = const {}]) {
            var s = (L()[key] as String?) ?? fb;
            vars.forEach((k, val) => s = s.replaceAll('{$k}', val));
            return s;
          }
          final closeCode = led.closeDisabledCode();
          final btns = [
            {
              'key': 'lend', 'label': L()['lendDebt'] as String, 'on': led.canGive,
              'off': led.giveDisabledCode() == null
                  ? null
                  : lfb('ledgerCantGive',
                      "Siz «{name}»ga {sum} qarzdorsiz — yana qarz berish mantiqsiz, avval hisobni yoping",
                      {'name': firstName, 'sum': led.sumActive(DebtDir.fromMe)}),
            },
            {
              'key': 'close', 'label': L()['closeDebt'] as String, 'on': led.canClose,
              'off': closeCode == null
                  ? null
                  : (closeCode == 'pendingWait'
                      ? lfb('ledgerPendingWait', 'Amal tasdiqlanishi kutilmoqda')
                      : lfb('ledgerNoActive', 'Faol qarz yo\'q')),
            },
          ];

          // ---- Yopish oqimi: tanlanadigan qarz chiplari ----
          final closeChips = led.closableDebts().map((d) {
            final locked = led.isLockedByPending(d);
            return {
              'id': d.id, 'sel': S['chDebt'] == d.id, 'locked': locked,
              'label': '${fmtAmt(led.remainingEff(d), d.currency)} · ${fmtDate(d.date)}',
              'over': led.isOverdue(d),
              'dir': d.direction == DebtDir.fromMe ? 'out' : 'in',
              'pick': () {
                if (locked) return;
                set({'chDebt': d.id, 'chA': _fmt(led.remainingEff(d)), 'chCur': d.currency});
              },
            };
          }).toList();
          final selDebt = led.closableDebts().where((d) => d.id == S['chDebt']).firstOrNull;
          final closeIsMine = selDebt?.direction == DebtDir.fromMe;

          // ---- Yozuv dialogi (versiya tarixi + edit) ----
          final histEntry = led.entries.where((e) => e.id == S['histId']).firstOrNull;

          return <String, dynamic>{
            'hasLedger': true,
            'accepted': accepted,
            'ledgerLoading': S['ledgerLoading'] == true,
            'balLines': balLines,
            // Ro'yxatdan o'tgan (counterparty_id bor) lekin qabul qilinmagan hamkorga
            // "Trust'da emas" DEMA (ziddiyat: badge "in Trust" turadi). offTrust faqat
            // haqiqatan ro'yxatda YO'Q hamkor uchun; ro'yxatda BOR-u qabul qilinmagan
            // uchun alohida "qabul qilinmagan" banneri.
            'offTrust': !accepted && !(inLink != null || client?['inTrust'] == true),
            'pendingLink': !accepted && (inLink != null || client?['inTrust'] == true),
            'pendingLinkName': firstName,
            'ledCards': cards,
            'ledCardCount': '${cards.length}',
            'ledReview': reviewCards,
            'ledReviewCount': '${reviewCards.length}',
            'revAllOpen': S['revAllOpen'] == true,
            'revAllAsk': () => set({'revAllOpen': true}),
            'revAllOk': () => ledgerReviewAll_(),
            'revAllNo': () => set({'revAllOpen': false}),
            'revAllText': Lf('revAllText', {'n': '${review.length}', 'sum': '${balParts({for (final d in review) d.currency: (review.where((x) => x.currency == d.currency).fold<int>(0, (s, x) => s + x.remaining))})}'}),
            'ledFeed': feed,
            'ledEmpty': feed.isEmpty,
            'ledBtns': btns,
            'ledBtnTap': (String key, bool on, String? off) {
              if (!on) {
                if (off != null) toast_(off);
                return;
              }
              chOpen_(key);
            },
            'chAct': S['chAct'],
            'chIsLend': S['chAct'] == 'lend',
            'chIsBorrow': S['chAct'] == 'borrow',
            'chIsClose': S['chAct'] == 'close',
            'chA': '${S['chA']}',
            'chCur': '${S['chCur'] ?? 'UZS'}',
            'chCurs': (S['myCurs'] as List?)?.cast<String>() ?? ['UZS', 'USD', 'EUR', 'RUB'],
            'chDate': '${S['chDate']}',
            'chDue': '${S['chDue']}',
            'chNote': '${S['chNote']}',
            'chReason': '${S['chReason']}',
            'chSetA': (String t) => set({'chA': t}),
            'chSetCur': (String c) => set({'chCur': c}),
            'chSetDate': (String d) => set({'chDate': d}),
            'chSetDue': (String d) => set({'chDue': d}),
            'chSetNote': (String n) => set({'chNote': n}),
            'chSetReason': (String r) => set({'chReason': r}),
            'chCloseChips': closeChips,
            'chCloseIsMine': closeIsMine,
            'chClosePanel': () => chClose_(),
            'chSubmit': () => chSubmit_(),
            // Yozuv dialogi
            'histOpen': histEntry != null,
            'histEditing': S['histEdit'] == true,
            'histData': histEntry == null ? null : {
              'title': _debtTitle(histEntry, led),
              'amount': fmtAmt(histEntry.amount, histEntry.currency),
              'date': fmtDate(histEntry.date),
              'due': histEntry.due != null ? _isoDate(histEntry.due) : '',
              'note': histEntry.note,
              'stLabel': _stLabel(histEntry.status),
              'oneSided': histEntry.isOneSided,
              'canEdit': histEntry.createdBy == '${S['meId']}' && histEntry.isDebt &&
                  (histEntry.status == EntryStatus.pending || histEntry.status == EntryStatus.active),
              'versions': histEntry.versions.map((v) => {
                'amount': fmtAmt(v.amount, histEntry.currency),
                'due': _isoDate(v.due), 'note': v.note,
                'time': _isoDate(v.editedAt),
              }).toList(),
            },
            'histClose': () => histClose_(),
            'histEditStart': () => histEditStart_(),
            'eA': '${S['eA']}', 'eDue': '${S['eDue']}', 'eNote': '${S['eNote']}',
            'eSetA': (String t) => set({'eA': t}),
            'eSetDue': (String t) => set({'eDue': t}),
            'eSetNote': (String t) => set({'eNote': t}),
            'histEditSave': () => histEditSave_(),
          };
        } catch (err) {
          debugPrint('ledger vals xatosi: $err');
          return <String, dynamic>{'hasLedger': false};
        }
      })(),

      'receiptOpen': rt != null, 'receipt': receipt,
      'molTotals': molTotals, 'bars': bars, 'reminders': reminders, 'profRows': profRows,
      // #34: profil o'chirish OTP modali (profil.dart)
      'delOtpOpen': S['delOtpOpen'] == true,
      'delOtpBusy': S['delOtpBusy'] == true,
      'delOtpPhone': '${S['delOtpPhone'] ?? ''}',
      'delOtpConfirm': (String code) => profileDeleteConfirm_(code),
      'delOtpCancel': () => profileDeleteCancel_(),
      'meName': meLabel(),
      'meInitials': initials(meLabel()),
      'meAvatar': S['meAvatar'], // lokal foto yo'li (galereyadan)
      'pickAvatar': () => pickAvatar_(),
      'mePhoneFmt': _fmtSrvPhone((S['mePhone'] as String?) ?? ''),
      // 8 xonali foydalanuvchi ID (016 migratsiya) — profil ekranida ism ostida
      'meNoFmt': S['meNo'] == null ? '' : 'ID: ${_fmtUserNo('${S['meNo']}')}',
      // Profil ismini tahrirlash (mijozlarga shu ism ko'rinadi)
      'meEditing': S['meNameEdit'] != null,
      'meEditVal': S['meNameEdit'] ?? '',
      'onMeName': (String t) => set({'meNameEdit': t}),
      'meEditToggle': () => set({'meNameEdit': S['meNameEdit'] == null ? (S['meName'] ?? '') : null}),
      'meNameSave': () async {
        final v = ((S['meNameEdit'] as String?) ?? '').trim();
        if (v.isEmpty) {
          set({'meNameEdit': null});
          return;
        }
        final r = await Api.updateProfile(fullName: v);
        if (!r.ok) {
          toast_(r.error);
          return;
        }
        set({'meName': v, 'meNameEdit': null});
        toast_(L()['tNameSaved']);
      },

      'sheetOpen': S['sheetOpen'],
      'closeSheet': () => set({'sheetOpen': false}),
      'sheetTitle': L0['sheetNew'],
      'sheetClientMode': S['sheetMode'] != 'fixed',
      'shTwoSided': true,
      'sheetFixed': S['sheetMode'] == 'fixed' && shCl != null,
      'sheetFixedName': shCl != null ? shCl['name'] : '',
      'sheetFixedInitials': shCl != null ? initials(shCl['name']) : '',
      'sheetClients': sheetClients, 'types': types, 'curs': curs,
      'formAmountText': (f['amount'] as String).isNotEmpty ? _fmt(int.parse(f['amount'] as String)) : '',
      'onAmount': (String t) {
        var d = t.replaceAll(RegExp(r'\D'), '');
        if (d.length > 12) d = d.substring(0, 12);
        set({'form': {...f, 'amount': d}});
      },
      'formNote': f['note'],
      'onNote': (String t) => set({'form': {...f, 'note': t}}),
      'sheetBtnLabel': L()['btnSave'] as String,
      'sheetHint': L()['sheetHintUnconf'] as String,
      'createTx': () => createTx(),

      'isOnbWelcome': stage == 'welcome',
      'isOnbPhone': stage == 'phone',
      'isOnbOtp': stage == 'otp',
      'isOnbPin': stage == 'pin',
      'isBoot': stage == 'boot', // sessiya tekshirilmoqda — animatsiyali splash
      'isApp': stage == 'app',
      // PIN ekrani rejimlari: set (o'rnatish) / confirm (qayta kiritish) /
      // check (qayta kirish) / old (o'zgartirishda joriy PIN)
      'pinCheck': S['pinMode'] == 'check',
      'pinTitle': S['pinMode'] == 'check'
          ? L0['pinEnterTitle']
          : S['pinMode'] == 'confirm'
              ? (L0['pinReenterT'] ?? "PIN'ni qayta kiriting")
              : S['pinMode'] == 'old'
                  ? (L0['pinCurrentT'] ?? 'Joriy PIN kodni kiriting')
                  : L0['pinTitle'],
      'pinSub': S['pinMode'] == 'check'
          ? L0['pinEnterSub']
          : S['pinMode'] == 'confirm'
              ? (L0['pinConfirmSame'] ?? 'Tasdiqlash uchun xuddi shu kodni kiriting')
              : S['pinMode'] == 'old'
                  ? (L0['pinConfirmCurrent'] ?? "O'zgartirish uchun joriy kodni tasdiqlang")
                  : L0['pinSub'],
      'pinErr': S['pinErr'] == true,
      'startOnb': () => set({'stage': 'phone'}),
      'backToWelcome': () => set({'stage': 'welcome'}),
      'backToPhone': () => set({'stage': 'phone', 'otpVal': ''}),
      // Orqaga: profil ichidan kelingan bo'lsa — profilga; check'da — chiqish; aks holda OTP'ga
      'backToOtp': () => S['pinRet'] == 'profil'
          ? set({'stage': 'app', 'pinVal': '', 'pinFirst': '', 'pinRet': null, 'pinMode': 'set'})
          : S['pinMode'] == 'check'
              ? logout_()
              : set({'stage': 'otp', 'pinVal': ''}),
      'phoneText': fmtIntl(S['phone'], S['onbCc']),
      'onPhone': (String t) {
        var d = t.replaceAll(RegExp(r'\D'), '');
        if (d.length > (ccOnb['len'] as int)) d = d.substring(0, ccOnb['len'] as int);
        set({'phone': d});
      },
      'phoneNext': () => phoneNext_(),
      'otpPhone': '${S['onbCc']} ${fmtIntl(S['phone'], S['onbCc'])}',
      'onbFlag': ccOnb['f'], 'onbDial': ccOnb['d'], 'onbPh': ccOnb['ph'],
      'ccOpenOnb': () => set({'ccOpen': 'onb', 'ccSearch': ''}),
      'ccOpenNp': () => set({'ccOpen': 'np', 'ccSearch': ''}),
      'ccOpen': S['ccOpen'] != null,
      'ccClose': () => set({'ccOpen': null}),
      'ccSearch': S['ccSearch'],
      'onCcSearch': (String t) => set({'ccSearch': t}),
      'ccRows': ccList.where((c) {
        final cq = (S['ccSearch'] as String).trim().toLowerCase();
        return cq.isEmpty || (c['n'] as String).toLowerCase().contains(cq) || (c['d'] as String).contains(cq);
      }).map((c) {
        return {
          'key': c['d'],
          'flag': c['f'], 'name': c['n'], 'dial': c['d'],
          'sel': (S['ccOpen'] == 'np' ? S['npCc'] : S['onbCc']) == c['d'],
          'pick': () {
            if (S['ccOpen'] == 'np') {
              var p = S['npPhone'] as String;
              if (p.length > (c['len'] as int)) p = p.substring(0, c['len'] as int);
              set({'npCc': c['d'], 'npPhone': p, 'ccOpen': null});
            } else {
              var p = S['phone'] as String;
              if (p.length > (c['len'] as int)) p = p.substring(0, c['len'] as int);
              set({'onbCc': c['d'], 'phone': p, 'ccOpen': null});
            }
          },
        };
      }).toList(),
      'otpBoxes': otpBoxes,
      'otpKeys': makeKeys('otpVal'),
      'otpConfirm': () => otpConfirm_(),
      'pinDots': pinDots,
      'pinKeys': makeKeys('pinVal'),
      'logout': () => logout_(),
      'L': L0,
      'busy': S['busy'], // server javobini kutayotgan tugma kaliti (loading)

      // Yordam chati (support -> Telegram)
      'supportOpen': S['supportOpen'] == true,
      'closeSupport': () => closeSupport_(),
      'supportItems': _supMsgs().map((m) => {
            'key': m['id'],
            'mine': m['direction'] == 'in',
            'body': '${m['body']}',
            'time': _hhmmIso('${m['created_at']}'),
          }).toList(),
      'supportInput': '${S['supportInput']}',
      'supportSetInput': (String t) => S['supportInput'] = t, // har harfda rebuild shart emas
      'supportSend': () => sendSupport_(),

      'openNotifs': () => set({'notifOpen': true}),
      'closeNotifs': () => set({'notifOpen': false}),
      'notifOpen': S['notifOpen'],
      'notifRows': notifRows,
      'bellDot': _notifs().any((n) => n['unread'] == true),
      'notifEmpty': notifRows.isEmpty,
      'notifUnread': _notifs().where((n) => n['unread'] == true).length,
      // Hammasini o'qilgan qilish — serverda + lokal
      'notifReadAll': () async {
        final r = await Api.readAllNotifs();
        if (!r.ok) {
          toast_(r.error);
          return;
        }
        set({'notifs': _notifs().map((n) => {...n, 'unread': false}).toList()});
      },

      // Arxiv — headerdagi tugma orqali alohida ekran
      'archOpen': S['archOpen'] == true,
      'openArch': () => set({'archOpen': true}),
      'closeArch': () => set({'archOpen': false}),

      // Til tanlash sheet'i
      'langOpen': S['langOpen'] == true,
      'closeLang': () => set({'langOpen': false}),
      'langRows': kLangMeta.map((m) => {
        'key': m['code'],
        'flag': m['flag'], 'name': m['name'],
        'sel': S['lang'] == m['code'],
        'pick': () {
          setLang(m['code']!);
          set({'langOpen': false});
        },
      }).toList(),

      // Bog'lanish qarori (minimal preview) + rad etilganlar
      'linkDecisionOpen': ldLink != null,
      'ld': ld,
      'closeLinkDecision': () => set({'linkDecisionId': null}),
      'rejOpen': S['rejOpen'] == true,
      'rejRows': rejRows,
      'closeRejected': () => set({'rejOpen': false}),

      'editFormOpen': S['editFormOpen'],
      'closeEditForm': () => set({'editFormOpen': false}),
      'editOld': rt != null ? money(rt['a'], rt['cur']) : '',
      'editOldRaw': rt != null ? rt['a'].toString() : '',
      'editAText': (S['editA'] as String).isNotEmpty ? _fmt(int.parse(S['editA'] as String)) : '',
      'onEditA': (String t) {
        var d = t.replaceAll(RegExp(r'\D'), '');
        if (d.length > 12) d = d.substring(0, 12);
        set({'editA': d});
      },
      'editNote': S['editNote'],
      'onEditNote': (String t) => set({'editNote': t}),
      'submitEdit': () => submitEdit(),

      'pdfOpen': S['pdfOpen'] == true && rt != null,
      'pdf': pdf,
      'closePdf': () => set({'pdfOpen': false}),
      'pdfDownload': () => toast_(L()['tPdfSoon']),
      'pdfShare': () => toast_(L()['tShareSoon']),

      'toastOpen': (S['toast'] as String).isNotEmpty,
      'toast': S['toast'],
    };
  }

  // ============ TRUST AI (moliyaviy hamroh chati) ============
  // Server javobi bloklar bilan keladi (docs/ai-character.md §11). AI hech qachon
  // pul amalini o'zi bajarmaydi — bloklardagi tugmalar mavjud endpointlarni
  // foydalanuvchi TASDIQLAGANDAN keyin chaqiradi (ai_blocks.dart).

  /// Server xabarini (yoki tarix qatorini) ichki modelga keltiradi.
  /// Noto'g'ri/bo'sh qator -> null (chat hech qachon yiqilmasin).
  Map<String, dynamic>? _aiMsg(dynamic m, {bool fresh = false}) {
    if (m is! Map) return null;
    final role = (m['role'] ?? m['sender'] ?? 'ai').toString();
    final blocks = parseAiBlocks(m['blocks']);
    final text = (m['text'] ?? m['content'] ?? m['body'] ?? '').toString();
    if (blocks.isEmpty && text.trim().isEmpty) return null;
    return {
      'id': (m['id'] ?? 'ai${DateTime.now().microsecondsSinceEpoch}').toString(),
      'role': role == 'user' ? 'user' : 'ai',
      'text': text,
      'blocks': blocks,
      'ts': (m['created_at'] ?? m['ts'] ?? '').toString(),
      'flagged': m['flagged'] == true,
      'fresh': fresh, // true — bloklar ketma-ket "qo'nadi" (birinchi ko'rinish)
    };
  }

  /// Javob konverti: {..} yoki {message:{..}} / {reply:{..}} — ikkalasi ham qabul.
  Map<String, dynamic>? _aiMsgFrom(dynamic data) {
    var m = data;
    if (m is Map && m['message'] is Map) {
      m = m['message'];
    } else if (m is Map && m['reply'] is Map) {
      m = m['reply'];
    }
    return _aiMsg(m, fresh: true);
  }

  /// Suhbat tarixi (ekran ochilganda). force — "qayta urinish" tugmasi.
  Future<void> loadAiMsgs({bool force = false}) async {
    if (S['aiLoading'] == true) return;
    if (S['aiLoaded'] == true && !force) return;
    set({'aiLoading': true, 'aiError': null});
    final r = await Api.aiMessages();
    if (!r.ok) {
      set({'aiLoading': false, 'aiError': r.error});
      return;
    }
    dynamic list = r.data;
    if (list is Map) list = list['messages'] ?? list['items'] ?? list['data'];
    final out = <Map<String, dynamic>>[];
    if (list is List) {
      for (final m in list) {
        final x = _aiMsg(m);
        if (x != null) out.add(x);
      }
    }
    // Eskidan yangiga. Sana bo'lmasa — server tartibiga tegmaymiz.
    if (out.every((m) => (m['ts'] as String).isNotEmpty)) {
      out.sort((a, b) => (a['ts'] as String).compareTo(b['ts'] as String));
    }
    set({'aiMsgs': out, 'aiLoaded': true, 'aiLoading': false, 'aiError': null});
  }

  /// Savol yuborish (input yoki chip). Foydalanuvchi pufagi darhol chiqadi.
  Future<void> aiSend_([String? preset]) async {
    final text = (preset ?? S['aiInput'] as String? ?? '').trim();
    if (text.isEmpty || S['aiSending'] == true) return;
    if (S['subStatus'] == 'expired') {
      toast_(L()['aiReadOnly'] as String);
      return;
    }
    final msgs = List<Map<String, dynamic>>.from(S['aiMsgs'] as List);
    msgs.add({
      'id': 'u${DateTime.now().microsecondsSinceEpoch}',
      'role': 'user',
      'text': text,
      'blocks': <Map<String, dynamic>>[],
      'ts': DateTime.now().toIso8601String(),
      'flagged': false,
      'fresh': false,
    });
    set({'aiMsgs': msgs, 'aiInput': '', 'aiSendErr': null, 'aiLimited': false, 'aiLimitKind': null});
    await _aiAsk(text);
  }

  /// Xatodan keyin qayta urinish — foydalanuvchi pufagi qayta qo'shilmaydi.
  Future<void> aiRetry_() async {
    final t = S['aiLastText'] as String?;
    if (t == null || t.isEmpty || S['aiSending'] == true) return;
    await _aiAsk(t);
  }

  /// 429 sababi -> UI xabari uchun tur. Kodsiz 429 (umumiy IP rateLimit) —
  /// o'tkinchi "sekinroq" holati, kunlik chegara EMAS.
  String _aiLimitKind(String code) {
    if (code == 'AI_LIMIT_DAILY') return 'day';
    if (code == 'AI_LIMIT_MONTHLY') return 'month';
    return 'slow';
  }

  Future<void> _aiAsk(String text) async {
    set({'aiSending': true, 'aiSendErr': null, 'aiLimited': false, 'aiLimitKind': null, 'aiLastText': text});
    final r = await Api.aiChat(text);
    if (r.ok) {
      final m = _aiMsgFrom(r.data);
      final l = List<Map<String, dynamic>>.from(S['aiMsgs'] as List);
      if (m != null) l.add(m);
      set({
        'aiMsgs': l,
        'aiSending': false,
        'aiLastText': null,
        // Javob keldi-yu bo'sh bo'lsa — jim qolmaymiz, aniq xato ko'rsatamiz
        'aiSendErr': m == null ? L()['aiEmptyErr'] as String : null,
      });
      return;
    }
    // 402 (obuna) Api.onPaymentRequired orqali allaqachon 'expired' qildi —
    // input bloklanadi; 429 esa alohida, do'stona chegara xabari bilan.
    //
    // DIQQAT: backend 429ni UCH xil sababga qaytaradi (src/routes/ai.js):
    //   AI_LIMIT_DAILY   — bugungi chegara tugadi (ertaga yangilanadi)
    //   AI_LIMIT_MONTHLY — oylik chegara tugadi (keyingi oy yangilanadi)
    //   AI_RATE_MINUTE / kodsiz (IP rateLimit) — "sekinroq yoz", bir ozdan keyin o'tadi.
    // Hammasiga "ertaga yana suhbatlashamiz" deyish YOLG'ON bo'lardi — kodga qarab
    // to'g'ri xabarni tanlaymiz ('slow' holatida qayta urinish tugmasi ham chiqadi).
    set({
      'aiSending': false,
      'aiLimited': r.status == 429,
      'aiLimitKind': r.status == 429 ? _aiLimitKind(r.code) : null,
      'aiSendErr': r.error,
    });
  }

  /// "Noto'g'ri javob" — Google Play 2026 talabi. Optimistik: bosilishi bilan belgilanadi.
  Future<void> aiFlag_(String id) async {
    final l = List<Map<String, dynamic>>.from(S['aiMsgs'] as List);
    final i = l.indexWhere((m) => m['id'] == id);
    if (i < 0 || l[i]['flagged'] == true) return;
    l[i] = {...l[i], 'flagged': true};
    set({'aiMsgs': l});
    final r = await Api.aiFlag(id, '');
    if (r.ok) {
      toast_(L()['aiFlagToast'] as String);
      return;
    }
    final l2 = List<Map<String, dynamic>>.from(S['aiMsgs'] as List);
    final j = l2.indexWhere((m) => m['id'] == id);
    if (j >= 0) l2[j] = {...l2[j], 'flagged': false}; // qaytaramiz — server qabul qilmadi
    set({'aiMsgs': l2});
    toast_(r.error);
  }

  // ============ CIRCLES (guruhli navbatli jamg'arma) — navigatsiya + amallar ============
  // Domen ma'lumotini ekranlar circlesRepo dan bevosita o'qiydi; bu yerda faqat
  // overlay bayroqlari, ochish/yopish va mutatsiya callback'lari (repo + set + toast).
  Map<String, dynamic> circleNav() {
    final id = S['circleId'] as String?;
    return {
      'circleOpen': S['circleOpen'] == true,
      'circleId': id,
      'circleCreateOpen': S['circleCreateOpen'] == true,
      'circleHistoryOpen': S['circleHistoryOpen'] == true,
      'circleManageOpen': S['circleManageOpen'] == true,
      'circleJoinOpen': S['circleJoinOpen'] == true,
      'circlePayOpen': S['circlePayOpen'] == true,
      'circleConfirmOpen': S['circleConfirmOpen'] == true,
      'circleInviteOpen': S['circleInviteOpen'] == true,
      // yuklash holati (backend)
      'circlesLoading': circlesRepo.loading,
      'circlesLoaded': circlesRepo.loaded,
      'circlesError': circlesRepo.error,
      'reloadCircles': () => loadCircles(force: true),
      // ochish / yopish
      'openCircle': (String cid) {
        set({'circleOpen': true, 'circleId': cid});
        if (!circlesRepo.loaded) loadCircles();
      },
      'closeCircle': () => set({'circleOpen': false}),
      'openCircleCreate': () => set({'circleCreateOpen': true}),
      'closeCircleCreate': () => set({'circleCreateOpen': false}),
      'openCircleHistory': () => set({'circleHistoryOpen': true}),
      'closeCircleHistory': () => set({'circleHistoryOpen': false}),
      'openCircleManage': () => set({'circleManageOpen': true}),
      'closeCircleManage': () => set({'circleManageOpen': false}),
      'openCircleJoin': (String cid) => set({'circleJoinOpen': true, 'circleId': cid}),
      'closeCircleJoin': () => set({'circleJoinOpen': false}),
      'openCirclePay': () => set({'circlePayOpen': true}),
      'closeCirclePay': () => set({'circlePayOpen': false}),
      'openCircleConfirm': () => set({'circleConfirmOpen': true}),
      'closeCircleConfirm': () => set({'circleConfirmOpen': false}),
      'openCircleInvite': () => set({'circleInviteOpen': true}),
      'closeCircleInvite': () => set({'circleInviteOpen': false}),
      // amallar (backend + toast)
      'circleMarkPaid': () async {
        if (id == null) return;
        final ok = await circlesRepo.markPaid(id);
        set({'circlePayOpen': false});
        toast_(ok ? cf('toastPaid') : (circlesRepo.errorStatus == 402 ? cf('subExpiredErr') : (circlesRepo.error ?? cf('toastError'))));
      },
      'circleConfirmReceipt': () async {
        if (id == null) return;
        final ok = await circlesRepo.confirmReceipt(id);
        set({'circleConfirmOpen': false});
        toast_(ok ? cf('toastConfirmed') : (circlesRepo.error ?? cf('toastError')));
      },
      'circleJoinAccept': () async {
        if (id == null) return;
        final ok = await circlesRepo.join(id);
        set({'circleJoinOpen': false});
        toast_(ok ? cf('toastJoined') : (circlesRepo.error ?? cf('toastError')));
      },
      'circleDecline': () async {
        if (id != null) await circlesRepo.declineInvite(id);
        set({'circleJoinOpen': false});
        toast_(cf('toastDeclined'));
      },
      'circleCloseAction': () async {
        if (id == null) return;
        final ok = await circlesRepo.closeCircle(id);
        if (ok) {
          set({'circleManageOpen': false, 'circleOpen': false, 'circleId': null});
          toast_(cf('toastClosed'));
        } else {
          toast_(circlesRepo.error ?? cf('toastError'));
        }
      },
      'circleInviteAdd': (List<Map<String, dynamic>> members) async {
        if (id == null || members.isEmpty) return;
        final ok = await circlesRepo.invite(id, members);
        set({'circleInviteOpen': false});
        toast_(ok ? cf('toastInvited') : (circlesRepo.errorStatus == 402 ? cf('subExpiredErr') : (circlesRepo.error ?? cf('toastError'))));
      },
      'circleManageRename': (String name) async {
        if (id == null) return;
        final ok = await circlesRepo.rename(id, name);
        toast_(ok ? cf('toastRenamed') : (circlesRepo.error ?? cf('toastError')));
      },
    };
  }

  // Circle'larni serverdan yuklash (tab ochilganda / app boshlanishida).
  Future<void> loadCircles({bool force = false}) async {
    if (circlesRepo.loading) return;
    if (circlesRepo.loaded && !force) {
      circlesRepo.load().then((_) => set({})); // fon yangilash + UI rebuild
      return;
    }
    circlesRepo.loading = true;
    set({});
    await circlesRepo.load();
    circlesRepo.loading = false;
    set({});
  }

}

final TrustStore store = TrustStore();

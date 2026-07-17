// Trust — prototip logikasining (prototype/logic.js) Flutter/Dart porti.
// Barcha state, hodisalar va hosilaviy qiymatlar (vals) prototip bilan 1:1.
// vals() Map qaytaradi — kalitlar prototip template placeholderlari bilan bir xil.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';
import 'theme.dart';
import 'api.dart';
import 'secure.dart';
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

class TrustStore extends ChangeNotifier {
  final Map<String, dynamic> S = {
    // 'boot' — sessiya tekshirilgunicha splash (welcome "miltillab" o'tib ketmasin)
    'stage': 'boot', 'lang': 'uz', 'dark': false, 'phone': '', 'otpVal': '', 'pinVal': '',
    'pinFirst': '', // PIN o'rnatishda birinchi kiritilgan qiymat (re-enter tasdiqlash)
    'pinRet': null, // 'profil' — PIN o'zgartirish profil ichidan boshlangan
    'pinMode': 'set', // 'set' = onboardingda o'rnatish, 'check' = qayta kirishda tekshirish
    'pinErr': false, // noto'g'ri PIN — nuqtalar qizil chaqnaydi
    'xarTab': 'chat', 'xarPeriod': 'oy', 'voiceStage': null, 'vText': '', 'xarText': '',
    'xcCats': <String>[], 'qarzDraft': null,
    // Xarajatlar v2 — papka (folder) UI holati (dizayn: Xarajatlar Trust.html)
    'xfDetail': null, // ochiq papka nomi
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
    // Chatdagi yozuvni inline tahrirlash (bubble bosilganda)
    'xEditId': null, 'xEditVals': null,
    'xarLimit': 0, 'limEdit': null,
    'xarEntries': <Map<String, dynamic>>[],
    'screen': 'home', 'clientId': null, 'tab': 'chat',
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
    // Qarz daftari (ledger) — ochiq hamkor yozuvlari (server'dan, DebtEntry ro'yxati)
    'ledgerRows': <Map<String, dynamic>>[],
    'ledgerLoading': false,
    // Input panel: chAct = null|'lend'|'borrow'|'close'; forma maydonlari
    'chAct': null, 'chA': '', 'chCur': 'UZS', 'chDue': '', 'chDate': '', 'chNote': '',
    'chDebt': null, 'chReason': 'returned', // yopish oqimida tanlangan qarz + sabab
    'histId': null, 'histEdit': false, 'eA': '', 'eDue': '', 'eNote': '', // yozuv dialogi/tahrir
    'revAllOpen': false, // "Hammasini tasdiqlash" ogohlantirishi
    // Profil qo'shimchalari
    'meAvatar': null, // lokal rasm yo'li (galereyadan)
    'cur': 'UZS', // asosiy valyuta (yangi yozuv formasi uchun default)
    'subStatus': 'trial', 'trialEnd': null, 'premUntil': null, // obuna holati (backend /profile/me)
    'delArmAt': 0, // profil o'chirish ikki bosqichli tasdiq vaqti
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
    'pMeta': <String, String>{}, // hamkor o'zgarish-imzolari (poll uchun)
    'busy': null, // server javobini kutayotgan tugma kaliti (loading spinner)
  };

  Timer? _tt, _pi, _lp, _poll;
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
    // Server yozishni 402 bilan bloklagan = obuna tugagan. Lokal holat darhol
    // 'expired'ga o'tadi — global banner va profil kartasi to'g'ri ko'rinadi
    // (aks holda ilova qayta ochilgunicha eski "trial" holati ko'rsatilardi).
    Api.onPaymentRequired = () {
      if (S['subStatus'] != 'expired') set({'subStatus': 'expired'});
    };
    await Api.loadToken();
    S['pinOn'] = await SecureStore.hasPin(); // toggle holatini secure storage'dan tiklaymiz
    // Valyuta va avatar (lokal saqlanadi)
    try {
      final sp = await SharedPreferences.getInstance();
      S['cur'] = sp.getString('trust_cur') ?? 'UZS';
      S['meAvatar'] = sp.getString('trust_avatar');
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
        'notifOn': p['notif_enabled'] != false,
        // Obuna holati: trial (7 kun) / premium / expired — profil va paywall uchun
        'subStatus': p['status'] ?? 'trial',
        'trialEnd': p['trial_ends_at'],
        'premUntil': p['premium_until'],
        'stage': needPin ? 'pin' : 'app', 'pinMode': 'check', 'skelHome': true,
      });
      await hydrate();
      set({'skelHome': false});
      _startPolling();
    } else if (prof.status == 401) {
      await Api.saveToken(null); // muddati o'tgan token
      set({'stage': 'welcome'}); // boot splashdan welcome'ga
    } else {
      // Tarmoq/server xatosi (status 0 yoki 5xx): token yaroqli — ilovaga kiritamiz,
      // hydrate keyin qayta urinadi. Foydalanuvchi onboarding'ga tushmaydi.
      set({'stage': needPin ? 'pin' : 'app', 'pinMode': 'check', 'skelHome': true});
      await hydrate();
      set({'skelHome': false});
      _startPolling();
    }
  }

  // Markazlashgan logout — 401 (sessiya tugagan) yoki qo'lda chiqishда
  void _forceLogout() {
    if (S['stage'] != 'app') return;
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
      final rs = await Future.wait(
          [Api.partners(), Api.notifications(), Api.expenses(), Api.getLimit(), Api.links(), Api.unreadCounts()]);
      final pr = rs[0], nr = rs[1], er = rs[2], lr = rs[3], kr = rs[4], ur = rs[5];
      var plist = <Map<String, dynamic>>[];
      final patch = <String, dynamic>{};
      if (pr.ok && pr.data is List) {
        plist = (pr.data as List).cast<Map<String, dynamic>>();
        patch['clients'] = plist.map(_mapPartner).toList();
      }
      // O'qilmagan xabarlar (badge) — hamkor qatorlarida ko'rinadi
      if (ur.ok && ur.data is Map) {
        patch['msgUnread'] = (ur.data as Map).map((k, v) => MapEntry('$k', _numToInt(v)));
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
        final fetchedIds = toFetch.map((p) => p['id']).toSet();
        final kept = _txs().where((t) => !fetchedIds.contains(t['c'])).toList();
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

  /// Profil o'chirish — ikki bosqichli tasdiq (5s ichida ikkinchi bosish).
  /// SOFT delete: qarshi tomonda daftar QOLADI (link modeli), qayta kirish = tiklash.
  Future<void> profileDelete_() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final armed = (S['delArmAt'] as int? ?? 0);
    if (now - armed > 5000) {
      set({'delArmAt': now});
      toast_(L()['tDelConfirmAgain']);
      return;
    }
    final r = await Api.deleteProfile();
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    toast_(L()['tProfileDeleted']);
    logout_();
  }

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
    // Daftar almashganda oldingi hamkor qatorlari ko'rinib turmasin
    if (S['ledgerPid'] != partnerId) {
      set({'ledgerPid': partnerId, 'ledgerRows': <Map<String, dynamic>>[], 'ledgerLoading': true});
    } else {
      set({'ledgerLoading': (S['ledgerRows'] as List).isEmpty});
    }
    final r = await Api.debts(partnerId);
    if (r.ok && r.data is List) {
      set({'ledgerRows': (r.data as List).cast<Map<String, dynamic>>(), 'ledgerLoading': false});
    } else {
      set({'ledgerLoading': false});
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
    if (act == 'lend' || act == 'borrow') {
      final dir = act == 'lend' ? 'toMe' : 'fromMe'; // viewer perspektivasi
      chClose_();
      await _ledgerAct(pid, () => Api.openDebt(pid,
          direction: dir, amount: amt, currency: '${S['chCur'] ?? 'UZS'}',
          actedAt: '${S['chDate']}'.isEmpty ? _isoDate(DateTime.now()) : '${S['chDate']}',
          due: '${S['chDue']}', note: '${S['chNote']}'),
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
        await _ledgerAct(pid, () => Api.repay(pid, debtId, amt, note: '${S['chNote']}'), okMsg: L()['okRepaySent'] as String);
      } else {
        // U menga qarzdor — pulni oldim / kechdim
        final reason = S['chReason'] == 'forgiven' ? 'forgiven' : 'returned';
        await _ledgerAct(pid, () => Api.settle(pid, debtId, amt, reason, note: '${S['chNote']}'), okMsg: L()['okSent'] as String);
      }
    }
  }

  // ---- Yozuv amallari ----
  // Ochiq daftar id'si: o'z hamkorim (clientId) YOKI kiruvchi bog'lanish (inLinkId)
  String? _ledPid() => (S['clientId'] ?? S['inLinkId']) as String?;
  void ledgerConfirm_(String id) => _ledgerAct(_ledPid()!, () => Api.debtConfirm(id), okMsg: L()['okConfirmed'] as String);
  void ledgerReject_(String id) => _ledgerAct(_ledPid()!, () => Api.debtReject(id), okMsg: L()['okRejected'] as String);
  void ledgerConfirmOp_(String id) => _ledgerAct(_ledPid()!, () => Api.debtConfirmOp(id), okMsg: L()['okConfirmed'] as String);
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
    for (final d in led.reviewDebts()) {
      await Api.reviewConfirm(pid, d.id);
    }
    await _refetchLedger(pid);
    toast_(L()['tAllConfirmed']);
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
    final inc = RegExp(r'(oylik|maosh|daromad|tushdi|keldi|sotdim|foyda|bonus)').hasMatch(t);
    String cat = inc ? 'Daromad' : 'Boshqa';
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
    return {'kind': inc ? 'd' : 'x', 'amount': ai != 0 ? ai.toString() : '', 'cat': cat, 'note': note};
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
      set({'xfNewCats': newCats, 'xfFly': fly, 'xfGhostCats': ghosts});
      // Zaxira: biror sabab bilan land bo'lmasa (ekran yopildi) — 8s dan keyin to'g'ridan-to'g'ri
      Timer(const Duration(seconds: 8), () {
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
      // Sahifadan ULOQTIRMAYMIZ: fly/kapalak o'ynab bo'lsin, foydalanuvchi Xarajatda
      // qolsin. Qarz amali toast + "O'tish" tugmasi bilan taklif qilinadi — bosilsa
      // _routeQarz eski oqimni (hamkor oynasi to'ldirilgan holda) ochadi.
      final q = routed.first;
      final person = ((q['person'] as String?) ?? '').trim();
      _xfToastShow({
        'text': "Qarz amali${person.isEmpty ? '' : ' ($person)'} — Hamkorlar bo'limida davom eting",
        'kind': 'qarz', 'route': q,
      }, seconds: 10);
    }
    return true;
  }

  // Chip qo'nganda BITTA yozuvni kiritish — papka/balans raqamlari shu paytda sanaydi.
  // Idempotent: qayta chaqirilsa yoki undo qilingan bo'lsa hech narsa qilmaydi.
  final Set<String> _xfCancelledLand = {};
  void xfLandOne_(Map<String, dynamic> e) {
    final id = e['id'] as String?;
    if (id != null && _xfCancelledLand.contains(id)) return;
    if (id != null && _xar().any((x) => x['id'] == id)) return;
    // Ghost-karta haqiqiyga aylanadi — yozuv kiritildi
    final ghosts = Map<String, bool>.from((S['xfGhostCats'] as Map).cast<String, bool>());
    ghosts.remove(e['cat']);
    set({'xarEntries': [e, ..._xar()], 'xfGhostCats': ghosts});
  }

  // Lokal (dizayn uslubidagi) toast — o'zi yopiladi (default 5s; qarz taklifi uzunroq)
  void _xfToastShow(Map<String, dynamic> t, {int seconds = 5}) {
    set({'xfToast': t});
    _xfToastT?.cancel();
    _xfToastT = Timer(Duration(seconds: seconds), () => set({'xfToast': null}));
  }

  // Qarz amali — Xarajatga EMAS (XOTIRA §3: bitta mic — uch natija).
  // Hamkor topilsa: operatsiya oynasi to'ldirilgan holda ochiladi.
  // Topilmasa: yangi hamkor oynasi (ism bilan), qarz ma'lumotlari kutib turadi.
  void _routeQarz(Map<String, dynamic> a) {
    final type = _typeUz[a['direction']] ?? 'Qarz berdim';
    final person = ((a['person'] as String?) ?? '').trim();
    final amount = '${a['amount'] ?? ''}';
    final note = (a['note'] as String?) ?? '';
    final match = person.isEmpty
        ? null
        : _clients().where((c) =>
            c['archived'] != true &&
            (c['name'] as String).toLowerCase().contains(person.toLowerCase())).toList();
    if (match != null && match.isNotEmpty) {
      set({
        'screen': 'home', 'clientId': match.first['id'], 'tab': 'chat', 'inLinkId': null,
        'chAct': type == 'Qarz oldim' ? 'borrow' : 'lend',
        'chA': amount, 'chCur': S['cur'] ?? 'UZS', 'chDue': '',
        'chDate': _isoDate(DateTime.now()), 'chNote': note, 'chDebt': null,
      });
      openLedger_(match.first['id'] as String);
      toast_(L()['tDebtFilled']);
    } else {
      set({
        'screen': 'home', 'npOpen': true, 'npName': person, 'npPhone': '',
        'qarzDraft': {'type': type, 'amount': amount, 'note': note},
      });
      toast_(L()['tDebtAddPartner']);
    }
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

  static const _monFull = ['Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
    'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'];

  // Toifa -> emoji (dizayn KW ro'yxati + backend seed toifalari)
  static const _xfEmojiMap = {
    'oylik': '💼', 'biznes': '📈', 'boshqa kirim': '💰', 'daromad': '💰',
    'transport': '🚌', 'taksi': '🚕', 'kofe': '☕️', 'oziq-ovqat': '🍜',
    'kommunal': '💡', 'xaridlar': '🛍️', 'kiyim': '🛍️', 'salomatlik': '💊',
    "ko'ngilochar": '🎬', 'sport': '🏋️', 'kitoblar': '📚', 'uy': '🏠',
    'aloqa': '📱', "ta'lim": '🎓', 'boshqa': '📦',
  };
  String xfEmoji(String cat) => _xfEmojiMap[_xfNorm(cat)] ?? '📁';

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

  // Joriy oy yozuvlari (papka UI faqat shu oy bilan ishlaydi — "IYUL BALANSI")
  List<Map<String, dynamic>> _xfMonthEntries() {
    final now = DateTime.now();
    final ym = '${now.year}-${now.month}';
    return _xar().where((e) => e['ym'] == ym).toList();
  }

  // Papkalar: joriy oy yozuvlaridan toifa bo'yicha
  List<Map<String, dynamic>> _xfFolders() {
    final map = <String, Map<String, dynamic>>{};
    for (final e in _xfMonthEntries()) {
      final cat = (e['cat'] as String?) ?? 'Boshqa';
      final f = map.putIfAbsent(cat,
          () => {'name': cat, 'income': e['kind'] == 'd', 'total': 0, 'entries': <Map<String, dynamic>>[]});
      f['total'] = (f['total'] as int) + (e['a'] as int);
      (f['entries'] as List).add(e);
    }
    // Ghost-papkalar: fly-chip uchayotganda nishon karta mavjud bo'lishi uchun
    // (yozuv hali kiritilmagan — chip qo'nganda haqiqiyga aylanadi)
    for (final g in (S['xfGhostCats'] as Map).cast<String, bool>().entries) {
      map.putIfAbsent(g.key, () =>
          {'name': g.key, 'income': g.value, 'total': 0, 'entries': <Map<String, dynamic>>[], 'ghost': true});
    }
    return map.values.toList()
      ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
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
    if (c['kind'] == 'merge') {
      final to = c['to'] as Map<String, dynamic>;
      for (final id in ids) {
        await Api.patchExpense(id, category: to['name'] as String);
      }
      set({'xarEntries': _xar().map((x) => ids.contains(x['id']) ? {...x, 'cat': to['name']} : x).toList()});
      _xfLogAdd('merge', cat: to['name'] as String, desc: "${from['name']} → ${to['name']}",
          amount: from['total'] as int, income: from['income'] == true);
      toast_(Lf('tMerged', {'from': '${from['name']}', 'to': '${to['name']}'}));
    } else {
      for (final id in ids) {
        await Api.deleteExpense(id);
      }
      set({'xarEntries': _xar().where((x) => !ids.contains(x['id'])).toList(), 'xfDetail': null});
      _xfLogAdd('del', cat: from['name'] as String, desc: "${from['name']} papkasi",
          amount: from['total'] as int, income: from['income'] == true);
      toast_(Lf('tDeletedName', {'name': '${from['name']}'}));
    }
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
    final r = await Api.deleteExpense(id);
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    set({'xarEntries': _xar().where((x) => x['id'] != id).toList()});
    _xfLogAdd('del', cat: e['cat'] as String,
        desc: (e['note'] as String?)?.isNotEmpty == true ? e['note'] as String : e['cat'] as String,
        amount: e['a'] as int, income: e['kind'] == 'd');
    _xfToastShow({'text': "O'chirildi", 'kind': 'del', 'entry': e});
  }

  // Toast tugmasi: del -> yozuv qayta qo'shiladi; add -> saqlanganlar o'chiriladi;
  // qarz -> Hamkorlar oqimiga o'tish (faqat foydalanuvchi O'ZI bosganda)
  Future<void> xfUndo_() async {
    final t = S['xfToast'] as Map<String, dynamic>?;
    _xfToastT?.cancel();
    set({'xfToast': null});
    if (t == null) return;
    if (t['kind'] == 'qarz') {
      _routeQarz((t['route'] as Map).cast<String, dynamic>());
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
    if (createNew) a['accept_new_category'] = true;
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
    _busy = false;
    _setBusy(null);
    set({'stage': 'pin', 'pinVal': '', 'pinMode': 'set'}); // yangi kirish — PIN o'rnatiladi
  }

  void logout_() {
    _poll?.cancel();
    Api.saveToken(null);
    SecureStore.clearPin(); // keyingi kirishda PIN qaytadan o'rnatiladi
    set({
      'stage': 'welcome', 'phone': '', 'otpVal': '', 'pinVal': '',
      'screen': 'home', 'clientId': null, 'receiptId': null, 'sheetOpen': false,
      'notifOpen': false, 'linkDecisionId': null, 'rejOpen': false,
      'archOpen': false, 'langOpen': false,
      'inLinkId': null, 'inLinkOps': <Map<String, dynamic>>[],
      'links': <Map<String, dynamic>>[],
      'clients': <Map<String, dynamic>>[], 'txs': <Map<String, dynamic>>[],
      'msgs': <String, List<Map<String, dynamic>>>{}, 'localMsgs': <String, List<Map<String, dynamic>>>{},
      'notifs': <Map<String, dynamic>>[], 'xarEntries': <Map<String, dynamic>>[],
      'xarLimit': 0, 'pMeta': <String, String>{},
      'meId': null, 'mePhone': null, 'meName': null, 'meNameEdit': null,
      'subStatus': 'trial', 'trialEnd': null, 'premUntil': null,
      'meAvatar': null, // shu qurilmada boshqa user kirsa avvalgi rasm ko'rinmasin
      // Trust AI suhbati — shaxsiy ma'lumot: qurilmada boshqa user kirsa ko'rinmasin
      'aiMsgs': <Map<String, dynamic>>[], 'aiInput': '', 'aiLoaded': false,
      'aiLoading': false, 'aiError': null, 'aiSending': false, 'aiSendErr': null,
      'aiLastText': null, 'aiLimited': false, 'aiLimitKind': null,
    });
    SharedPreferences.getInstance().then((sp) => sp.remove('trust_avatar'));
  }

  /// Bildirishnoma bosilganda marshrutlash (link modeli)
  Future<void> openFromNotif(Map<String, dynamic> n) async {
    Api.readNotif(n['id'] as String); // fire-and-forget
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
        // Ochiq papka (tafsilot)
        final xfDN = S['xfDetail'] as String?;
        final xfDFl = xfFs.where((f) => f['name'] == xfDN).toList();
        final xfDF = xfDFl.isEmpty ? null : xfDFl.first;
        final xfGroups = <Map<String, dynamic>>[];
        if (xfDF != null) {
          final ents = (xfDF['entries'] as List).cast<Map<String, dynamic>>().toList()
            ..sort((a, b) => (a['days'] as int).compareTo(b['days'] as int));
          for (final e in ents) {
            final d = e['days'] as int;
            final label = d <= 0 ? (L()['tToday'] as String) : d == 1 ? (L()['tYesterday'] as String) : Lf('daysAgo', {'d': '$d'});
            if (xfGroups.isEmpty || xfGroups.last['label'] != label) {
              xfGroups.add({'label': label, 'rows': <Map<String, dynamic>>[]});
            }
            (xfGroups.last['rows'] as List).add({
              'id': e['id'], 'a': e['a'],
              'desc': (e['note'] as String?)?.isNotEmpty == true ? e['note'] : e['cat'],
              'time': e['t'],
              'amtTxt': (e['kind'] == 'd' ? '+' : '−') + _fx(e['a'] as int),
              'inc': e['kind'] == 'd',
              'edit': () => xfEditStart_(e['id'] as String),
              'del': () => xfDelEntry_(e['id'] as String),
            });
          }
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
          'xfMonth': '${_monFull[xfNow.month - 1]} ${xfNow.year}',
          'xfBalCap': Lf('balOfMonth', {'month': '${_monFull[xfNow.month - 1].toUpperCase()}'}),
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
          'xfDName': xfDF == null ? '' : xfDF['name'],
          'xfDCount': xfDF == null ? '' : Lf('monthYearCount', {'month': '${_monFull[xfNow.month - 1]}', 'year': '${xfNow.year}', 'n': '${(xfDF['entries'] as List).length}'}),
          'xfDTotalTxt': xfDF == null ? '' : ((xfDF['income'] == true ? '+' : '−') + _fx(xfDF['total'] as int)),
          'xfDTotalVal': xfDF == null ? 0 : xfDF['total'] as int,
          'xfDInc': xfDF?['income'] == true,
          'xfDSpark': xfDF == null ? List<double>.filled(8, 0.06) : _xfSpark(xfDF['entries'] as List),
          'xfDGroups': xfGroups,
          'xfDEmpty': xfDF != null && (xfDF['entries'] as List).isEmpty,
          'xfDetailClose': () => set({'xfDetail': null}),
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
          'xfToastBtn': (S['xfToast'] as Map?)?['kind'] == 'qarz' ? "O'tish" : 'Bekor qilish',
          'xfUndo': () => xfUndo_(),
          'xfBusy': S['voiceStage'] == 'parsing',
          'xfSend': () => xfSend_(),
          // To'liq ekran: header'dagi orqaga tugmasi (dizayn: bottom navsiz)
          'xfBack': () => set({'screen': 'home', 'xfDetail': null, 'xfLogOpen': false}),
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
            'xfLogOpen': false, 'xfLogDot': false, 'xfLogToggle': () {}, 'xfLogEmpty': true,
            'xfLogRows': <Map<String, dynamic>>[],
            'xfShowTray': false, 'xfTrayCount': '0', 'xfTrayRows': <Map<String, dynamic>>[],
            'xfEditingOpen': false, 'xfEditLabel': '', 'xfEditCancel': () {},
            'xfCfOpen': false, 'xfCfMerge': false, 'xfCfFromTxt': '', 'xfCfFromSum': '',
            'xfCfToTxt': '', 'xfCfToSum': '', 'xfCfOk': () {}, 'xfCfNo': () {},
            'xfToastOpen': false, 'xfToastText': '', 'xfToastBtn': '', 'xfUndo': () {},
            'xfBusy': false, 'xfSend': () {},
            'xfBack': () => set({'screen': 'home'}),
            'xfFlyEvents': <Map<String, dynamic>>[], 'xfFlyDone': () {},
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

    Map<String, int> bal(String cid) {
      // Server balansi (operations + qarz daftari) — haqiqat manbai; bo'sh bo'lsa lokal fallback
      final srv = (_client(cid)?['srvBal'] as Map?)?.cast<String, int>();
      if (srv != null && srv.isNotEmpty) return {'UZS': srv['UZS'] ?? 0, 'USD': srv['USD'] ?? 0};
      final b = {'UZS': 0, 'USD': 0};
      for (final t in _txs()) {
        if (t['c'] == cid && t['st'] != 'pending') {
          b[t['cur']] = b[t['cur']]! + sign(t['type']) * (t['a'] as int);
        }
      }
      return b;
    }

    Map<String, dynamic> balMain(Map<String, int> b) {
      if (b['UZS'] == 0 && b['USD'] == 0) {
        return {'text': L0['zero'], 'color': mut, 'sub': L0['subZero']};
      }
      final v = b['UZS'] != 0 ? b['UZS']! : b['USD']!;
      final cur = b['UZS'] != 0 ? 'UZS' : 'USD';
      final pos = v > 0;
      return {
        'text': (pos ? '+' : '−') + money(v.abs(), cur),
        'color': pos ? green : red,
        'sub': pos ? L0['subPos'] : L0['subNeg'],
      };
    }

    // Home
    final q = (S['search'] as String).trim().toLowerCase();
    final homeFiltered = _clients()
        .where((c) => c['archived'] != true && (c['name'] as String).toLowerCase().contains(q))
        .toList();
    final visible = S['skelHome'] == true
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
      return {
        'id': cid,
        'actLabel': 'Arxiv',
        'tx': S['swipeId'] == cid ? S['swipeDx'] : (S['swipeSnap'] == cid ? -96.0 : 0.0),
        'anim': S['swipeId'] != cid,
        'archTap': () => archive_(cid),
        'archAct': () => archive_(cid),
        'name': c['name'], 'initials': initials(c['name']),
        'onTrust': c['onTrust'] != false, 'oneSided': c['onTrust'] == false,
        'sub': last != null ? '${L0['last']}${last['date']}' : L0['noOps'],
        'bal': b['text'], 'color': b['color'], 'balSub': b['sub'],
        // O'qilmagan xabarlar soni — qatorda badge (sms kelsa ko'rinadi)
        'unread': (S['msgUnread'] as Map)[cid] ?? 0,
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

    // Meni kontragent qilib qo'shganlar (qabul qilinganlari) — teskari balans bilan ro'yxatga qo'shiladi
    final linksAll = List<Map<String, dynamic>>.from(S['links'] as List);
    final inRows = S['skelHome'] == true
        ? <Map<String, dynamic>>[]
        : linksAll
            .where((l) => l['status'] == 'accepted' && (l['name'] as String).toLowerCase().contains(q))
            .map((l) {
            final tot = l['total'] as int;
            final lid = l['id'] as String;
            return {
              'id': 'in$lid',
              'actLabel': '',
              'tx': 0.0, 'anim': true,
              'archTap': () {}, 'archAct': () {},
              'name': l['name'], 'initials': initials(l['name'] as String),
              'onTrust': true, 'oneSided': false,
              'sub': L0['addedYou'],
              'bal': tot == 0 ? L0['zero'] : (tot > 0 ? '+' : '−') + money(tot.abs(), 'UZS'),
              'color': tot > 0 ? green : (tot < 0 ? red : mut),
              'balSub': tot > 0 ? L0['subPos'] : (tot < 0 ? L0['subNeg'] : L0['subZero']),
              // O'qilmagan xabarlar badge'i (data-qatlam; ko'rsatish ekran qaroriga bog'liq)
              'unread': (S['msgUnread'] as Map)[lid] ?? 0,
              'open': () => openIncoming(lid),
            };
          }).toList();
    final homeRows = [...clientRows, ...inRows];

    int toMeUZS = 0, toMeUSD = 0, byMe = 0;
    for (final c in _clients()) {
      final b = bal(c['id']);
      if (b['UZS']! > 0) toMeUZS += b['UZS']!;
      if (b['UZS']! < 0) byMe += -b['UZS']!;
      if (b['USD']! > 0) toMeUSD += b['USD']!;
    }
    // Qabul qilingan kiruvchi bog'lanishlar balansga qo'shiladi
    for (final l in linksAll) {
      if (l['status'] != 'accepted') continue;
      final tot = l['total'] as int;
      if (tot > 0) toMeUZS += tot;
      if (tot < 0) byMe += -tot;
    }
    final net = toMeUZS - byMe;

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
      return {
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
      final v = b['UZS']! > 0 ? b['UZS']! : (b['USD']! > 0 ? b['USD']! : 0);
      if (v <= 0) return null;
      final cur = b['UZS']! > 0 ? 'UZS' : 'USD';
      return mkRem(c['id'] as String, c['name'] as String, money(v, cur));
    }).whereType<Map<String, dynamic>>().toList();

    final xarV = _xarVals(P, money);

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
          final st = S['subStatus'] as String? ?? 'trial';
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
          return L()['subExpired9'] as String;
        }(),
        'isPlain': true, 'isSwitch': false,
        'tap': () => toast_(L()['subInfo']),
      },
      // Profilni o'chirish (App Store/Play siyosati) — SOFT: qarshi tomonda daftar qoladi
      {
        'label': L0['profDelete'] ?? "Profilni o'chirish",
        'value': '', 'isPlain': true, 'isSwitch': false, 'danger': true,
        'tap': () => profileDelete_(),
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
    final curs = ['UZS', 'USD']
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
      'isHome': S['screen'] == 'home' && noClient,
      'isCircles': S['screen'] == 'circles' && noClient,
      'isAi': S['screen'] == 'ai' && noClient,
      'isXarajat': S['screen'] == 'xarajat' && noClient,
      'isProfil': S['screen'] == 'profil' && noClient,
      'netText': (net >= 0 ? '+' : '−') + money(net.abs(), 'UZS'),
      'netColor': net > 0 ? green : (net < 0 ? red : ink),
      'owedToMe': money(toMeUZS, 'UZS') + (toMeUSD != 0 ? ' · ${money(toMeUSD, 'USD')}' : ''),
      'owedByMe': money(byMe, 'UZS'),
      'search': S['search'],
      'onSearch': (String t) => set({'search': t, 'homeVis': 6}),
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
      'skelHome': S['skelHome'],
      'skelRows': const [
        {'key': 'sk1', 'w1': 0.46, 'w2': 0.30}, {'key': 'sk2', 'w1': 0.58, 'w2': 0.26},
        {'key': 'sk3', 'w1': 0.40, 'w2': 0.34}, {'key': 'sk4', 'w1': 0.52, 'w2': 0.24},
        {'key': 'sk5', 'w1': 0.44, 'w2': 0.30}, {'key': 'sk6', 'w1': 0.56, 'w2': 0.28},
      ],
      'homeLoadingMore': S['homeLoadingMore'],
      'homeMore': () {
        if (S['skelHome'] == true || S['homeLoadingMore'] == true) return;
        final cq2 = (S['search'] as String).trim().toLowerCase();
        final flt = _clients().where((c) => c['archived'] != true && (c['name'] as String).toLowerCase().contains(cq2)).toList();
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
          toast_(r.error);
          return;
        }
        final cl = _mapPartner(r.data as Map<String, dynamic>);
        final qd = S['qarzDraft'] as Map<String, dynamic>?;
        set({
          'clients': [cl, ..._clients()],
          'npOpen': false, 'clientId': cl['id'], 'tab': 'chat', 'cMenuOpen': false, 'cRen': null,
          'pProfOpen': false, 'opsVis': 8, 'inLinkId': null,
          // Ovozdan kelgan qarz kutib turgan bo'lsa — operatsiya oynasi to'ldirilgan holda ochiladi
          if (qd != null) ...{
            'qarzDraft': null,
            'chAct': qd['type'] == 'Qarz oldim' ? 'borrow' : 'lend',
            'chA': '${qd['amount']}', 'chCur': S['cur'] ?? 'UZS', 'chDue': '',
            'chDate': _isoDate(DateTime.now()), 'chNote': '${qd['note']}', 'chDebt': null,
          },
        });
        openLedger_(cl['id'] as String); // yangi (bo'sh) daftar + polling
        toast_(L()['tPartnerAdded']);
        hydrate(full: false);
      },
      'goHome': () => set({'screen': 'home', 'clientId': null, 'receiptId': null, 'inLinkId': null}),
      'goCircles': () {
        set({'screen': 'circles', 'clientId': null, 'receiptId': null, 'inLinkId': null});
        loadCircles();
      },
      'goAi': () {
        set({'screen': 'ai', 'clientId': null, 'receiptId': null, 'inLinkId': null});
        loadAiMsgs(); // tarix bir marta yuklanadi (aiLoaded)
      },
      'goProfil': () => set({'screen': 'profil', 'clientId': null, 'receiptId': null, 'inLinkId': null}),
      'goXarajat': () => set({'screen': 'xarajat', 'clientId': null, 'receiptId': null, 'inLinkId': null}),
      'cMij': S['screen'] == 'home' ? active : idle,
      'cCircle': S['screen'] == 'circles' ? active : idle,
      'cAi': S['screen'] == 'ai' ? active : idle,
      'cXar': S['screen'] == 'xarajat' ? active : idle,
      'cProf': S['screen'] == 'profil' ? active : idle,
      ...circleNav(),
      ...xarV,

      'clientOpen': client != null || incoming,
      'incoming': incoming,
      'cName': cName, 'cInitials': cInitials, 'cBal': cBal, 'cBalColor': cBalColor,
      'hasPend': false, 'pendText': '',
      'canFlip': false,
      'oneSided': client != null && client['onTrust'] == false,
      'cOnTrust': (client != null && client['onTrust'] != false) || incoming,
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
          if (balLines.isEmpty) balLines.add({'text': L()['balSettledLine'] as String, 'color': mut});

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
                'reject': () => ledgerReject_(e.id),
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
          final btns = [
            {'key': 'lend', 'label': L()['lendDebt'] as String, 'on': led.canGive, 'off': led.giveDisabledReason(firstName)},
            {'key': 'borrow', 'label': L()['borrowDebt'] as String, 'on': led.canTake, 'off': led.takeDisabledReason(firstName)},
            {'key': 'close', 'label': L()['closeDebt'] as String, 'on': led.canClose, 'off': led.closeDisabledReason()},
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
            'offTrust': !accepted,
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
      'meName': meLabel(),
      'meInitials': initials(meLabel()),
      'meAvatar': S['meAvatar'], // lokal foto yo'li (galereyadan)
      'pickAvatar': () => pickAvatar_(),
      'mePhoneFmt': _fmtSrvPhone((S['mePhone'] as String?) ?? ''),
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
              ? (L0['pinConfirmTitle'] ?? "PIN'ni qayta kiriting")
              : S['pinMode'] == 'old'
                  ? (L0['pinOldTitle'] ?? 'Joriy PIN kodni kiriting')
                  : L0['pinTitle'],
      'pinSub': S['pinMode'] == 'check'
          ? L0['pinEnterSub']
          : S['pinMode'] == 'confirm'
              ? (L0['pinConfirmSub'] ?? 'Tasdiqlash uchun xuddi shu kodni kiriting')
              : S['pinMode'] == 'old'
                  ? (L0['pinOldSub'] ?? "O'zgartirish uchun joriy kodni tasdiqlang")
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

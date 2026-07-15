// Trust — prototip logikasining (prototype/logic.js) Flutter/Dart porti.
// Barcha state, hodisalar va hosilaviy qiymatlar (vals) prototip bilan 1:1.
// vals() Map qaytaradi — kalitlar prototip template placeholderlari bilan bir xil.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'api.dart';
import 'stt.dart';
import 'secure.dart';
import 'l10n.dart';

// Ovozli kiritish (STT) vaqtincha o'chirilgan — matn-birinchi rejim.
// Qayta yoqish: true qiling (mic UI qaytadi, matn input yo'qoladi).
const bool kSttEnabled = false;


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
    'stage': 'welcome', 'lang': 'uz', 'dark': false, 'phone': '', 'otpVal': '', 'pinVal': '',
    'pinMode': 'set', // 'set' = onboardingda o'rnatish, 'check' = qayta kirishda tekshirish
    'pinErr': false, // noto'g'ri PIN — nuqtalar qizil chaqnaydi
    'xarTab': 'chat', 'xarPeriod': 'oy', 'voiceStage': null, 'vText': '', 'xarText': '',
    'xcCats': <String>[], 'qarzDraft': null,
    // Xarajatlar v2 — papka (folder) UI holati (dizayn: Xarajatlar Trust.html)
    'xfDetail': null, // ochiq papka nomi
    'xfLogOpen': false, 'xfLogDot': false,
    'xfLog': <Map<String, dynamic>>[], // sessiya jurnali: add/edit/del/merge (max 12)
    'xfTray': <Map<String, dynamic>>[], // ANIQLANMAGAN — papka tanlanishi kutilayotgan yozuvlar
    'xfEditing': null, // {id, label} — input orqali tahrirlash rejimi
    'xfConfirm': null, // {kind:'merge'|'delf', from, to} — tasdiqlash kartasi
    'xfToast': null, // {text, kind:'add'|'del', ids|entry} — "Bekor qilish" bilan lokal toast
    'xfNewCats': <String>[], // shu sessiyada yangi ochilgan papkalar ("Yangi ✨")
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
    'playing': null, 'recOn': false, 'remTimes': <String, int>{},
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
    'notifs': <Map<String, dynamic>>[],
    // Bog'lanishlar (meni kontragent qilib qo'shganlar) — link modeli
    'links': <Map<String, dynamic>>[],
    'linkDecisionId': null, // qaror sheet'i ochiq bog'lanish
    'rejOpen': false, // "Rad etilganlar" ro'yxati
    'inLinkId': null, // ochiq kiruvchi daftar (qabul qilingan bog'lanish)
    'inLinkOps': <Map<String, dynamic>>[], // uning operatsiyalari
    // Auth / sessiya
    'meId': null, 'mePhone': null, 'meName': null, 'meNameEdit': null,
    'pMeta': <String, String>{}, // hamkor o'zgarish-imzolari (poll uchun)
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
    await Api.loadToken();
    S['pinOn'] = await SecureStore.hasPin(); // toggle holatini secure storage'dan tiklaymiz
    if (Api.token != null) _tryResume(); // kutmaymiz — welcome darhol chiziladi
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
        'stage': needPin ? 'pin' : 'app', 'pinMode': 'check', 'skelHome': true,
      });
      await hydrate();
      set({'skelHome': false});
      _startPolling();
    } else if (prof.status == 401) {
      await Api.saveToken(null); // muddati o'tgan token — welcome'da qoladi
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
    toast_('Sessiya tugadi — qaytadan kiring');
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
    // eski (v2) turlari — tarixiy qatorlar uchun
    'req': 'confirmed', 'ok': 'confirmed', 'edit': 'confirmed', 'rej': 'rejected',
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
    if (diff == 0) return 'Bugun';
    if (diff == 1) return 'Kecha';
    return '${d.day}-${_monU[d.month - 1]}';
  }

  /// Bildirishnoma vaqti: 'Hozir' | '15 daqiqa oldin' | 'HH:mm' | 'Kecha' | '12-iyl'
  String _relTime(dynamic iso) {
    final d = _dt(iso);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Hozir';
    if (diff.inMinutes < 60) return '${diff.inMinutes} daqiqa oldin';
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
          [Api.partners(), Api.notifications(), Api.expenses(), Api.getLimit(), Api.links()]);
      final pr = rs[0], nr = rs[1], er = rs[2], lr = rs[3], kr = rs[4];
      var plist = <Map<String, dynamic>>[];
      final patch = <String, dynamic>{};
      if (pr.ok && pr.data is List) {
        plist = (pr.data as List).cast<Map<String, dynamic>>();
        patch['clients'] = plist.map(_mapPartner).toList();
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
    if (prof.ok && prof.data is Map) S['meName'] = (prof.data as Map)['full_name'];
    hydrate(); // fonda yuklanadi — foydalanuvchi PIN kiritayotgan payt
    _startPolling();
  }

  Map<String, dynamic> L() => kLangs[S['lang']] ?? lUz;

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
      if ((S['pinMode'] as String? ?? 'set') == 'check') {
        _pinCheck(v);
      } else {
        _pinSet(v);
      }
    }
  }

  // PIN o'rnatish (onboarding) — hashni secure storage'ga saqlab, ilovaga kiramiz.
  Future<void> _pinSet(String pin) async {
    await SecureStore.setPin(pin);
    Timer(const Duration(milliseconds: 280), () {
      set({'stage': 'app', 'pinVal': '', 'skelHome': true, 'homeVis': 6});
      Timer(const Duration(milliseconds: 950), () => set({'skelHome': false}));
      toast_(L()['tWelcome']);
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
      toast_('PIN o\'chirildi');
    } else if (!await SecureStore.hasPin()) {
      set({'stage': 'pin', 'pinMode': 'set', 'pinVal': ''});
    }
  }

  Map<String, dynamic> ccEntry(String dial) =>
      ccList.firstWhere((c) => c['d'] == dial, orElse: () => ccList[0]);

  List<Map<String, dynamic>> _clients() => List<Map<String, dynamic>>.from(S['clients']);
  List<Map<String, dynamic>> _txs() => List<Map<String, dynamic>>.from(S['txs']);
  List<Map<String, dynamic>> _notifs() => List<Map<String, dynamic>>.from(S['notifs']);
  List<Map<String, dynamic>> _xar() => List<Map<String, dynamic>>.from(S['xarEntries']);
  /// Chat oqimi: serverdan hosil qilingan (tx) + lokal yozilgan xabarlar
  Map<String, List<Map<String, dynamic>>> _msgs() {
    final d = Map<String, List<Map<String, dynamic>>>.from(S['msgs']);
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

  void restore_(String id) => _setArchived(id, false, 'Arxivdan qaytarildi');

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
    toast_('Nom yangilandi');
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
    final r = await Api.linkAction(id, action);
    _busy = false;
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

  // Chat ovozi — REAL hold-to-talk (Telegram uslubi): bosib turib gapiriladi,
  // qo'yib yuborilganda STT matnga aylantirib chat maydoniga qo'yadi.
  // Input bar almashtirilmaydi — klaviatura holatiga tegilmaydi.
  Future<void> chatMicStart() async {
    if (_recActive) return;
    _recActive = true;
    set({'recOn': true});
    await Stt.start(
      onStarted: () {},
      onDone: (text) {
        _recActive = false;
        set({'recOn': false});
        if (text != null && text.trim().isNotEmpty) {
          // Matn chat maydoniga tushadi — foydalanuvchi ko'rib, tahrirlashi va yuborishi mumkin
          set({'chatInput': '${(S['chatInput'] as String).trim().isEmpty ? '' : '${S['chatInput']} '}${text.trim()}'});
        } else {
          toast_(Stt.lastError ?? "Ovoz matnga aylanmadi — qayta urinib ko'ring");
        }
      },
    );
    if (Stt.lastError != null && S['recOn'] == true) {
      _recActive = false;
      set({'recOn': false});
      toast_(Stt.lastError!);
    }
  }

  void chatMicEnd() {
    if (!_recActive) return;
    Stt.finish(); // natija onDone orqali chatInput'ga tushadi
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
      toast_("O'zgarish kiritilmadi");
      return;
    }
    final r = await Api.patchOp(t['id'] as String, amount: newA, note: newNote);
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
    toast_('Yozuv tuzatildi — tarix saqlandi');
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
      toast_('Hamkorni tanlang');
      return;
    }
    if (_busy) return;
    _busy = true;
    final r = await Api.createOp(
      cl0['id'] as String,
      _typeSrv[f['type']] ?? 'qarz_berdim',
      a,
      f['currency'] as String,
      (f['note'] as String).trim(),
    );
    _busy = false;
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
      'form': {'type': 'Qarz berdim', 'amount': '', 'currency': 'UZS', 'note': '', 'name': ''},
    });
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

  // Real ovoz — Telegram/Instagram uslubi: mikrofonni BOSIB USHLAB turganda yozadi,
  // qo'yib yuborganda to'xtaydi va avtomatik chatga chiqadi (alohida ekran/tasdiq yo'q).
  bool _recActive = false;

  Future<void> voiceHoldStart() async {
    if (_recActive) return;
    _recActive = true;
    set({'voiceStage': 'rec', 'vText': ''});
    await Stt.start(
      onStarted: () {},
      onDone: (text) {
        _recActive = false;
        _voiceDone(text);
      },
    );
    if (Stt.lastError != null && S['voiceStage'] == 'rec') {
      _recActive = false;
      set({'voiceStage': null, 'vText': ''});
      toast_(Stt.lastError!);
    }
  }

  void voiceHoldEnd() {
    if (!_recActive) return;
    Stt.finish(); // STT natijani onDone orqali qaytaradi
  }

  void _voiceDone(String? text) {
    if (S['voiceStage'] != 'rec') return;
    if (text != null && text.trim().isNotEmpty) {
      xarPick_(text.trim(), source: 'voice');
    } else {
      set({'voiceStage': null, 'vText': ''});
      toast_(Stt.lastError ?? "Ovoz matnga aylanmadi — qayta urinib ko'ring");
    }
  }

  // Server parse -> AVTOMATIK saqlash (tasdiqlash kartasi yo'q). Qarz -> Hamkorlar oqimiga.
  // Toifa/summa xato bo'lsa — chatdagi bubble'ni bosib inline tuzatiladi.
  Future<void> xarPick_(String txt, {String source = 'text'}) async {
    Stt.cancel();
    set({'voiceStage': 'parsing', 'vText': txt});
    final r = await Api.parseExpense(txt, source);
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
      toast_('Summa aniqlanmadi — «taksiga 25 ming» deb ayting');
      return;
    }
    // Ajratamiz: toifasi aniq -> darhol papkaga; noaniq ('Boshqa'/bo'sh xarajat) -> ANIQLANMAGAN tray
    final sure = <Map<String, dynamic>>[];
    final unsure = <Map<String, dynamic>>[];
    for (final a in actions) {
      final cat = ((a['category'] as String?) ?? '').trim();
      if (a['type'] == 'xarajat' && (cat.isEmpty || cat.toLowerCase() == 'boshqa')) {
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
      if (!ok) set({'voiceStage': null, 'vText': ''});
    } else {
      set({'voiceStage': null, 'vText': ''});
      if (unsure.isNotEmpty) toast_('Papka tanlang — ANIQLANMAGAN bo\'limida kutmoqda');
    }
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
      set({'xfNewCats': newCats, 'xfFly': fly});
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
        'text': "${es.length} ta yozuv saqlandi · ${_fx(total)} so'm",
        'kind': 'add', 'ids': ids,
      });
    }
    set({'voiceStage': null, 'vText': ''});
    if (routed.isNotEmpty) _routeQarz(routed.first);
    return true;
  }

  // Chip qo'nganda BITTA yozuvni kiritish — papka/balans raqamlari shu paytda sanaydi.
  // Idempotent: qayta chaqirilsa yoki undo qilingan bo'lsa hech narsa qilmaydi.
  final Set<String> _xfCancelledLand = {};
  void xfLandOne_(Map<String, dynamic> e) {
    final id = e['id'] as String?;
    if (id != null && _xfCancelledLand.contains(id)) return;
    if (id != null && _xar().any((x) => x['id'] == id)) return;
    set({'xarEntries': [e, ..._xar()]});
  }

  // Lokal (dizayn uslubidagi) toast — 5 soniyada o'zi yopiladi
  void _xfToastShow(Map<String, dynamic> t) {
    set({'xfToast': t});
    _xfToastT?.cancel();
    _xfToastT = Timer(const Duration(seconds: 5), () => set({'xfToast': null}));
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
        'screen': 'home', 'clientId': match.first['id'], 'tab': 'chat',
        'sheetOpen': true, 'sheetClient': match.first['id'],
        'form': {'type': type, 'amount': amount, 'currency': 'UZS', 'note': note, 'name': ''},
      });
      toast_("Qarz amali — ma'lumotlar to'ldirildi, saqlang");
    } else {
      set({
        'screen': 'home', 'npOpen': true, 'npName': person, 'npPhone': '',
        'qarzDraft': {'type': type, 'amount': amount, 'note': note},
      });
      toast_("Qarz amali — hamkorni qo'shing, yozuv tayyor turadi");
    }
  }

  // Zaxira: server parse yiqilganda lokal qoida-parser bilan eski oqim
  Future<void> _xarOffline(String txt) async {
    final f = xarParse_(txt);
    final a = int.tryParse(f['amount'] as String) ?? 0;
    if (a == 0) {
      set({'voiceStage': null, 'vText': ''});
      toast_('Summa aniqlanmadi — «taksiga 25 ming» deb ayting');
      return;
    }
    final r = await Api.addExpense(a, f['kind'] == 'd', f['cat'] as String, f['note'] as String);
    if (!r.ok) {
      set({'voiceStage': null, 'vText': ''});
      toast_(r.error);
      return;
    }
    final e = _mapExpense(r.data as Map<String, dynamic>);
    set({'xarEntries': [e, ..._xar()], 'voiceStage': null, 'vText': ''});
    toast_('AI toifaladi: ${f['cat']} — chatga yozildi');
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
      toast_('Summani kiriting');
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
    toast_('Yangilandi');
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
    toast_("O'chirildi");
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
    return map.values.toList()
      ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
  }

  // Dinamik sparkline (dizayn kabi): papkaning OXIRGI 8 yozuvi summalari — yangi yozuv
  // qo'shilganda chiziq siljiydi (rolling oyna). Kam yozuvda chapdan past qiymat bilan to'ldiriladi.
  List<double> _xfSpark(List entries) {
    final es = entries.cast<Map<String, dynamic>>().toList()
      ..sort((a, b) => (b['days'] as int).compareTo(a['days'] as int)); // eski -> yangi
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
    // Ko'rinishdagi "400 000" formati parser uchun "400000" ga tozalanadi
    final raw = ((S['xarText'] as String?) ?? '').trim();
    final t = raw.replaceAllMapped(RegExp(r'(\d) (?=\d)'), (m) => m[1]!);
    if (t.isEmpty) {
      toast_('Jumla yozing');
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
    set({'xarText': ''});
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
      toast_('Ikkita papka nomini ayting: «Taksi xarajatlarini Transportga birlashtir»');
      return;
    }
    set({'xfConfirm': {'kind': 'merge', 'from': hits[0]['f'], 'to': hits[1]['f']}});
  }

  // "Taksi papkasini o'chir" — bitta papka nomi
  void _xfDelFolderAsk(String low) {
    for (final f in _xfFolders()) {
      if (low.contains(_xfNorm(f['name'] as String))) {
        set({'xfConfirm': {'kind': 'delf', 'from': f}});
        return;
      }
    }
    toast_('Papka topilmadi');
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
      toast_("Birlashtirildi: ${from['name']} → ${to['name']}");
    } else {
      for (final id in ids) {
        await Api.deleteExpense(id);
      }
      set({'xarEntries': _xar().where((x) => !ids.contains(x['id'])).toList(), 'xfDetail': null});
      _xfLogAdd('del', cat: from['name'] as String, desc: "${from['name']} papkasi",
          amount: from['total'] as int, income: from['income'] == true);
      toast_("O'chirildi: ${from['name']}");
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
      toast_('Summani kiriting');
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
    toast_('Yangilandi');
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

  // Bekor qilish (undo): del -> yozuv qayta qo'shiladi; add -> saqlanganlar o'chiriladi
  Future<void> xfUndo_() async {
    final t = S['xfToast'] as Map<String, dynamic>?;
    _xfToastT?.cancel();
    set({'xfToast': null});
    if (t == null) return;
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
      toast_('Qaytarildi');
    } else if (t['kind'] == 'add') {
      final ids = (t['ids'] as List?)?.cast<String>() ?? [];
      _xfCancelledLand.addAll(ids); // hali qo'nmagan chip'lar keyin kirib qolmasin
      for (final id in ids) {
        await Api.deleteExpense(id);
      }
      set({'xarEntries': _xar().where((x) => !ids.contains(x['id'])).toList()});
      toast_('Bekor qilindi');
    }
  }

  // ANIQLANMAGAN tray
  void xfTrayToggle_(String id) {
    set({
      'xfTray': (S['xfTray'] as List).cast<Map<String, dynamic>>()
          .map((t) => t['id'] == id ? {...t, 'open': t['open'] != true} : t).toList(),
    });
  }

  Future<void> xfTrayPick_(String id, String cat) async {
    final tray = (S['xfTray'] as List).cast<Map<String, dynamic>>();
    final t = tray.firstWhere((x) => x['id'] == id, orElse: () => <String, dynamic>{});
    if (t.isEmpty) return;
    final a = Map<String, dynamic>.from(t['action'] as Map);
    a['category'] = cat;
    set({'xfTray': tray.where((x) => x['id'] != id).toList()});
    // confirm orqali saqlaymiz — parsed bilan birga (lug'at o'rganadi: keyingi safar AI o'zi topadi)
    await _xcConfirm(t['src'] as String, 'text', [a], [Map<String, dynamic>.from(t['action'] as Map)]);
  }

  Future<void> limSave_() async {
    final v = int.tryParse((S['limEdit'] ?? '') as String) ?? 0;
    if (v == 0) {
      toast_('Summani kiriting');
      return;
    }
    final r = await Api.setLimit(v);
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    set({'xarLimit': v, 'limEdit': null});
    toast_('Oylik limit yangilandi');
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
    toast_('Kod yuborilmoqda…');
    final r = await Api.sendOtp('${S['onbCc']}${S['phone']}');
    _busy = false;
    if (!r.ok) {
      toast_(r.error);
      return;
    }
    set({'stage': 'otp', 'otpVal': ''});
    toast_('SMS kod yuborildi');
  }

  Future<void> otpConfirm_() async {
    if ((S['otpVal'] as String).length != 5) {
      toast_(L()['tEnterCode']);
      return;
    }
    if (_busy) return;
    _busy = true;
    toast_('Tekshirilmoqda…');
    final r = await Api.verifyOtp('${S['onbCc']}${S['phone']}', S['otpVal'] as String);
    if (!r.ok) {
      _busy = false;
      set({'otpVal': ''});
      toast_(r.error);
      return;
    }
    await _loginSuccess(r.data as Map<String, dynamic>);
    _busy = false;
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
    });
  }

  /// Bildirishnoma bosilganda marshrutlash (link modeli)
  Future<void> openFromNotif(Map<String, dynamic> n) async {
    Api.readNotif(n['id'] as String); // fire-and-forget
    set({'notifs': _notifs().map((x) => x['id'] == n['id'] ? {...x, 'unread': false} : x).toList()});
    final kind = n['kind'] as String?;
    final linkId = n['link'] as String?;
    final opId = n['tx'] as String?;

    // Yangi bog'lanish so'rovi -> qaror sheet'i (minimal preview)
    if (kind == 'linknew' && linkId != null) {
      final kr = await Api.links();
      if (kr.ok && kr.data is List) {
        set({'links': (kr.data as List).cast<Map<String, dynamic>>().map(_mapLink).toList()});
      }
      final l = _link(linkId);
      if (l == null) {
        toast_("Bog'lanish topilmadi");
        return;
      }
      if (l['status'] == 'pending') {
        set({'linkDecisionId': linkId});
      } else if (l['status'] == 'accepted') {
        openIncoming(linkId);
      } else {
        toast_("Bu bog'lanish rad etilgan — «Rad etilganlar»dan tiklashingiz mumkin");
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
      if (d == 0) return 'Bugun';
      if (d == 1) return 'Kecha';
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
          ? 'Limit belgilanmagan'
          : (limOver ? 'Limitdan oshdi' : 'Qoldi: ${money(limRem, 'UZS')}'),
      'limNoteTxt': lim == 0
          ? "Limit belgilanmagan — O'zgartirish orqali qo'ying"
          : limOver
              ? 'Limitdan oshdi · ${money(limRem, 'UZS')} ortiqcha'
              : limNear
                  ? 'Qoldi: ${money(limRem, 'UZS')} · limitga yaqin'
                  : 'Qoldi: ${money(limRem, 'UZS')}',
      'limBtnTxt': S['limEdit'] != null ? 'Bekor' : "O'zgartirish",
      'limEditOpen': S['limEdit'] != null,
      'limEditVal': S['limEdit'] ?? '',
      'limEditSet': (String t) => set({'limEdit': t.replaceAll(RegExp(r'[^\d]'), '')}),
      'limSave': () => limSave_(),
      'limEditToggle': () => set({'limEdit': S['limEdit'] == null ? (S['xarLimit']).toString() : null}),
      'xtChat': S['xarTab'] == 'chat', 'xtHisobot': S['xarTab'] == 'hisobot',
      'xarTabs': [['chat', 'Chat'], ['hisobot', 'Hisobotlar']]
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
      'xarPeriods': [['hafta', 'Hafta'], ['oy', 'Oy'], ['yil', 'Yil']]
          .map((kv) => {
                'label': kv[1], 'pick': () => set({'xarPeriod': kv[0]}),
                'bg': S['xarPeriod'] == kv[0] ? ink : Colors.transparent,
                'fg': S['xarPeriod'] == kv[0] ? bg : mut,
                'bd': S['xarPeriod'] == kv[0] ? ink : bd,
              })
          .toList(),
      'xarNetCap': '${S['xarPeriod'] == 'hafta' ? 'HAFTA' : S['xarPeriod'] == 'oy' ? 'OY' : 'YIL'} · SOF NATIJA',
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
      // ---- Mikrofon: bosib ushlab yozish (Telegram/Instagram) ----
      // STT o'chiq bo'lsa (kSttEnabled=false) mic o'rniga matn input ko'rsatiladi.
      'sttOn': kSttEnabled,
      'xarTextVal': S['xarText'] ?? '',
      'xarTextSet': (String t) => set({'xarText': t}),
      'xarTextGo': () {
        final t = ((S['xarText'] as String?) ?? '').trim();
        if (t.isEmpty) { toast_('Jumla yozing'); return; }
        set({'xarText': ''});
        xarPick_(t, source: 'text');
      },
      'micHoldStart': () => voiceHoldStart(),
      'micHoldEnd': () => voiceHoldEnd(),
      'micRec': S['voiceStage'] == 'rec',        // yozayapti (pulse)
      'micParsing': S['voiceStage'] == 'parsing', // tahlil qilinyapti
      'micHint': S['voiceStage'] == 'rec'
          ? "Tinglayapman… gapiring, qo'yib yuboring"
          : S['voiceStage'] == 'parsing'
              ? 'Tahlil qilinyapti…'
              : "Bosib ushlab gapiring — AI o'zi yozib toifalaydi",
      // ---- Xarajatlar v2: papka (folder) UI (dizayn: Xarajatlar Trust.html) ----
      ...(() {
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
            final label = d <= 0 ? 'Bugun' : d == 1 ? 'Kecha' : '$d kun avval';
            if (xfGroups.isEmpty || xfGroups.last['label'] != label) {
              xfGroups.add({'label': label, 'rows': <Map<String, dynamic>>[]});
            }
            (xfGroups.last['rows'] as List).add({
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
          'xfBalCap': '${_monFull[xfNow.month - 1].toUpperCase()} BALANSI',
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
          'xfDCount': xfDF == null ? '' : '${_monFull[xfNow.month - 1]} ${xfNow.year} · ${(xfDF['entries'] as List).length} ta yozuv',
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
                'badge': o['type'] == 'add' ? 'YANGI'
                    : o['type'] == 'del' ? "O'CHIRILDI"
                    : o['type'] == 'edit' ? 'TAHRIR' : 'BIRLASHDI',
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
          'xfTrayRows': (S['xfTray'] as List).cast<Map<String, dynamic>>().map((t) => {
                'id': t['id'],
                'text': t['text'],
                'amtTxt': '−${_fx(_numToInt((t['action'] as Map)['amount']))}',
                'open': t['open'] == true,
                'toggle': () => xfTrayToggle_(t['id'] as String),
                'chips': [
                  for (final c in chipSrc)
                    {'label': '${xfEmoji(c)} $c', 'pick': () => xfTrayPick_(t['id'] as String, c)},
                ],
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

    String money(int a, String cur) => cur == 'USD' ? '${_fmt(a)} \$' : '${_fmt(a)} ${L0['som']}';
    int sign(String t) => (t == 'Qarz berdim' || t == "To'lov berdim") ? 1 : -1;
    String initials(String n) =>
        n.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

    Map<String, int> bal(String cid) {
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
            ? '${inLink['name']} yozgan'
            : (t['by'] == 'me' ? '' : 'Qarshi tomon yozgan'),
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
              'toggle': () => togglePlay(key, dur),
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
            'toggle': () => togglePlay(key, dur),
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
            toast_('Faqat yozuv muallifi tuzatadi');
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
        'coolText': cool ? 'Keyingi eslatma: ${hrs}s ${mins}m' : '',
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
          toast_('Eslatma yuborildi — ${name.split(' ')[0]} push oladi');
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
      {'label': L0['profCur'], 'value': 'UZS', 'isPlain': true, 'isSwitch': false, 'tap': () {}},
      mkSwitch(L0['darkMode'], dk, () => setDark(!dk)),
      mkSwitch(L0['profPin'], S['pinOn'] == true, () => _togglePin()),
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
        'isOk': k == 'linkacc' || k == 'opnew' || k == 'confirmed',
        'isRem': k == 'reminder',
        'isEdit': false,
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
            'opsCount': "${ldLink['opsCount']} ta yozuv",
            'total': (ldLink['total'] as int) == 0
                ? L0['zero']
                : ((ldLink['total'] as int) > 0 ? '+' : '−') + money((ldLink['total'] as int).abs(), 'UZS'),
            'totalColor': (ldLink['total'] as int) > 0 ? green : ((ldLink['total'] as int) < 0 ? red : mut),
            'accept': () => linkAct(ldLink['id'] as String, 'accept',
                okMsg: "Qabul qilindi — yozuvlar va balans ochildi"),
            'reject': () => linkAct(ldLink['id'] as String, 'reject',
                okMsg: "Rad etildi — «Rad etilganlar»dan istalgan payt tiklaysiz"),
          };

    // Rad etilganlar ro'yxati (tiklash faqat mijoz qo'lida)
    final rejRows = linksAll.where((l) => l['status'] == 'rejected').map((l) {
      final lid = l['id'] as String;
      return {
        'key': lid,
        'name': l['name'], 'initials': initials(l['name'] as String),
        'sub': '${l['opsCount']} ta yozuv · ${l['sellerLabel']}',
        'restore': () => linkAct(lid, 'restore', okMsg: 'Tiklandi — yozuvlar va balans ochildi'),
      };
    }).toList();

    final active = ink, idle = P.idle;
    final noClient = S['clientId'] == null && !incoming;

    return {
      'isHome': S['screen'] == 'home' && noClient,
      'isMoliya': S['screen'] == 'moliya' && noClient,
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
      'npHint':
          "Raqam egasi Trust'ga kirganda bog'lanish so'rovi boradi — qabul qilsa, yozuvlar unga ham ko'rinadi. Sizning daftaringiz esa darhol ishlayveradi.",
      'npCreate': () async {
        final nm = (S['npName'] as String).trim();
        if (nm.isEmpty) {
          toast_('Ismni kiriting');
          return;
        }
        if ((S['npPhone'] as String).length != ccNp['len']) {
          toast_(L0['tNum']);
          return;
        }
        if (_busy) return;
        _busy = true;
        final r = await Api.createPartner(nm, '${S['npCc']}${S['npPhone']}');
        _busy = false;
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
            'qarzDraft': null, 'sheetOpen': true, 'sheetClient': cl['id'],
            'form': {'type': qd['type'], 'amount': qd['amount'], 'currency': 'UZS', 'note': qd['note'], 'name': ''},
          },
        });
        toast_("Kontragent qo'shildi");
        hydrate(full: false);
      },
      'goHome': () => set({'screen': 'home', 'clientId': null, 'receiptId': null, 'inLinkId': null}),
      'goMoliya': () => set({'screen': 'moliya', 'clientId': null, 'receiptId': null, 'inLinkId': null}),
      'goProfil': () => set({'screen': 'profil', 'clientId': null, 'receiptId': null, 'inLinkId': null}),
      'goXarajat': () => set({'screen': 'xarajat', 'clientId': null, 'receiptId': null, 'inLinkId': null}),
      'cMij': S['screen'] == 'home' ? active : idle,
      'cMol': S['screen'] == 'moliya' ? active : idle,
      'cXar': S['screen'] == 'xarajat' ? active : idle,
      'cProf': S['screen'] == 'profil' ? active : idle,
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
            okMsg: "Aloqa uzildi — «Rad etilganlar»dan tiklashingiz mumkin");
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
          toast_('Nom yangilandi');
          return;
        }
        renSave_();
      },
      'pProfOpen': S['pProfOpen'],
      'pProfClose': () => set({'pProfOpen': false}),
      'pPhone': client != null ? client['phone'] : (incoming ? inLink['phone'] : ''),
      'pStatus': client != null
          ? (client['linkStatus'] == 'accepted'
              ? "Bog'langan — yozuvlar ikki tomonda ko'rinadi"
              : "Kutilmoqda — raqam egasi hali qabul qilmagan")
          : (incoming ? "Sizni kontragent qilib qo'shgan — bog'lanish qabul qilingan" : ''),
      'pOps': client != null
          ? _txs().where((t) => t['c'] == client['id']).length.toString()
          : (incoming ? '${inLink['opsCount']}' : ''),
      'pBal': cBal.replaceFirst(L0['balPfx'] as String, ''),
      'inviteTap': () {
        if (client == null) return;
        toast_("Raqam egasi Trust'ga kirganda bog'lanish so'rovi avtomatik boradi");
      },
      'back': () => set({'clientId': null, 'inLinkId': null, 'cMenuOpen': false, 'cRen': null, 'pProfOpen': false}),
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
        if ((S['chatInput'] as String).trim().isEmpty || client == null) return;
        addLocalMsg(client['id'] as String,
            {'k': 'text', 'mine': true, 'text': (S['chatInput'] as String).trim(), 'time': _hhmm(DateTime.now()), 'read': false});
        set({'chatInput': ''});
      },
      // Kiruvchi daftar faqat o'qish uchun — yangi yozuvni faqat sotuvchi kiritadi
      'canWrite': client != null,
      'openSheetClient': () {
        if (client == null) return;
        set({'sheetOpen': true, 'sheetMode': 'fixed', 'sheetClient': client['id']});
      },
      'hasText': (S['chatInput'] as String).trim().isNotEmpty,
      'noText': (S['chatInput'] as String).trim().isEmpty,
      'recOn': S['recOn'],
      'recOff': S['recOn'] != true,
      // Chat ovozi: bosib turib gapirish (hold-to-talk) — matn chat maydoniga tushadi
      'chatMicStart': () => chatMicStart(),
      'chatMicEnd': () => chatMicEnd(),

      'receiptOpen': rt != null, 'receipt': receipt,
      'molTotals': molTotals, 'bars': bars, 'reminders': reminders, 'profRows': profRows,
      'meName': meLabel(),
      'meInitials': initials(meLabel()),
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
        toast_('Ism saqlandi — kontragentlarga shu ism ko\'rinadi');
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
      'sheetBtnLabel': 'Saqlash',
      'sheetHint': "Yozuv darhol saqlanadi — tasdiq talab qilinmaydi. Bog'langan kontragent buni o'z ilovasida ko'radi.",
      'createTx': () => createTx(),

      'isOnbWelcome': stage == 'welcome',
      'isOnbPhone': stage == 'phone',
      'isOnbOtp': stage == 'otp',
      'isOnbPin': stage == 'pin',
      'isApp': stage == 'app',
      // PIN ekrani ikki holatda: onboardingda o'rnatish / qayta kirishda tekshirish
      'pinCheck': S['pinMode'] == 'check',
      'pinTitle': S['pinMode'] == 'check' ? L0['pinEnterTitle'] : L0['pinTitle'],
      'pinSub': S['pinMode'] == 'check' ? L0['pinEnterSub'] : L0['pinSub'],
      'pinErr': S['pinErr'] == true,
      'startOnb': () => set({'stage': 'phone'}),
      'backToWelcome': () => set({'stage': 'welcome'}),
      'backToPhone': () => set({'stage': 'phone', 'otpVal': ''}),
      // Onboardingda orqaga OTP'ga; qayta kirish (check) holatida orqa = chiqish (welcome)
      'backToOtp': () => S['pinMode'] == 'check' ? logout_() : set({'stage': 'otp', 'pinVal': ''}),
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
      'pdfDownload': () => toast_('PDF hisobot — tez orada'),
      'pdfShare': () => toast_('Ulashish — tez orada'),

      'toastOpen': (S['toast'] as String).isNotEmpty,
      'toast': S['toast'],
    };
  }
}

final TrustStore store = TrustStore();

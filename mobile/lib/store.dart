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

const Map<String, dynamic> _uz = {
  'slogan': "«Hisobli do'st — ayrilmas»",
  'tagline': "Qarz va hisob-kitoblaringizni bitta joyda yuriting. Har bir yozuv saqlanadi — kontragent qabul qilsa, unga ham ko'rinadi.",
  'start': 'Boshlash', 'terms': 'Davom etish orqali foydalanish shartlariga rozilik bildirasiz',
  'phoneTitle': 'Telefon raqami', 'phoneSub': "Hisobingiz shu raqamga bog'lanadi", 'cont': 'Davom etish',
  'otpTitle': 'Tasdiqlash kodi', 'otpDemo': 'SMS orqali kelgan 5 xonali kodni kiriting', 'confirm': 'Tasdiqlash',
  'pinTitle': "PIN o'rnating", 'pinSub': 'Ilovaga kirish uchun 4 xonali kod',
  'appSub': 'Ishonchli hisob-kitob', 'netCap': 'SOF BALANS', 'owedTo': 'Sizga qarz', 'owedBy': 'Qarzingiz', 'searchPh': 'Qidirish',
  'navClients': 'Hamkorlar', 'navFin': 'Moliya', 'navProfile': 'Profil',
  'tabChat': 'Chat', 'tabOps': 'Operatsiyalar', 'opCap': 'Operatsiya',
  'codeWrong': "Kod noto'g'ri. Qayta urinib ko'ring.",
  'openDalil': 'Dalilni ochish', 'msgPh': 'Xabar yozing',
  'receiptTitle': 'Dalil', 'lockedCap': 'QULFLANGAN YOZUV', 'from': 'Kimdan', 'to': 'Kimga', 'date': 'Sana',
  'codeLabel': 'Tasdiqlash kodi', 'statusL': 'Holat', 'statusVal': 'Daftar yozuvi',
  'receiptNote': "Ushbu yozuv o'chirib bo'lmaydi. O'zgartirish faqat ikki tomon roziligi bilan amalga oshiriladi.",
  'share': 'Ulashish (PDF)', 'changeReq': "O'zgartirish so'rovi", 'archive': 'Arxivlash',
  'finTitle': 'Moliya', 'turnover': 'OYLIK AYLANMA', 'mlnHint': "mln so'm hisobida", 'remindersCap': 'ESLATMALAR', 'remind': 'Eslatish',
  'given': 'Berilgan qarzlar', 'taken': 'Olingan qarzlar', 'repaid': "Qaytarilgan to'lovlar", 'netLabel': 'Sof balans',
  'logout': 'Chiqish',
  'namePh': 'Ism yozing', 'notePh': 'Masalan: mol savdosi uchun',
  'sheetNew': 'Yangi operatsiya', 'sheetNewBook': 'Yangi tasdiqsiz yozuv', 'makeCode': 'Kod yaratish', 'saveUnconf': 'Saqlash (tasdiqsiz)',
  'hintClient': "Kod chatda ko'rinadi. Ikkinchi tomon kodni kiritgach, yozuv qulflanadi.",
  'hintBook': 'Bu yozuv faqat sizning daftaringizda saqlanadi — dalil emas.',
  'balPfx': 'Balans: ', 'stPending': 'Kutilmoqda', 'stOk': 'Yozuv', 'stArch': 'Arxivda', 'kod': 'kod',
  'me': 'Jasur Toshmatov (siz)', 'last': "So'nggi: ", 'noOps': "Amaliyot yo'q",
  'subPos': 'sizga qarz', 'subNeg': 'siz qarzsiz', 'subZero': 'hisob teng', 'zero': "0 so'm", 'som': "so'm", 'due': 'muddat',
  'tCode': 'Kod yaratildi — ', 'tSaved': 'Tasdiqsiz yozuv saqlandi', 'tDalil': 'Dalil yaratildi',
  'tArch': "Arxivga ko'chirildi", 'tWelcome': 'Xush kelibsiz!',
  'tSum': 'Summani kiriting', 'tNum': "Raqamni to'liq kiriting", 'tEnterCode': 'Kodni kiriting',
  'profTil': 'Til', 'profTilVal': "O'zbek (lotin)", 'profCur': 'Asosiy valyuta', 'profPin': 'PIN-kod',
  'profNotif': 'Bildirishnomalar', 'profArch': 'Arxivlangan yozuvlar', 'on': 'Yoqilgan',
};

const Map<String, dynamic> _ru = {
  'slogan': '«Счёт дружбы не портит»',
  'tagline': 'Ведите долги в одном месте. Каждая запись сохраняется — если контрагент примет связь, она видна и ему.',
  'start': 'Начать', 'terms': 'Продолжая, вы соглашаетесь с условиями использования',
  'phoneTitle': 'Номер телефона', 'phoneSub': 'Аккаунт будет привязан к этому номеру', 'cont': 'Продолжить',
  'otpTitle': 'Код подтверждения', 'otpDemo': 'Введите 5-значный код из SMS', 'confirm': 'Подтвердить',
  'pinTitle': 'Установите PIN', 'pinSub': 'Код из 4 цифр для входа в приложение',
  'appSub': 'учёт долгов', 'netCap': 'ЧИСТЫЙ БАЛАНС', 'owedTo': 'Вам должны', 'owedBy': 'Вы должны', 'searchPh': 'Поиск',
  'navClients': 'Клиенты', 'navFin': 'Финансы', 'navProfile': 'Профиль',
  'tabChat': 'Чат', 'tabOps': 'Операции', 'opCap': 'Операция',
  'codeWrong': 'Неверный код. Попробуйте ещё раз.',
  'openDalil': 'Открыть далил', 'msgPh': 'Напишите сообщение',
  'receiptTitle': 'Далил', 'lockedCap': 'ЗАЩИЩЁННАЯ ЗАПИСЬ', 'from': 'От кого', 'to': 'Кому', 'date': 'Дата',
  'codeLabel': 'Код подтверждения', 'statusL': 'Статус', 'statusVal': 'Запись в тетради',
  'receiptNote': 'Эту запись нельзя удалить. Изменения — только с согласия обеих сторон.',
  'share': 'Поделиться (PDF)', 'changeReq': 'Запрос на изменение', 'archive': 'В архив',
  'finTitle': 'Финансы', 'turnover': 'ОБОРОТ ПО МЕСЯЦАМ', 'mlnHint': 'в млн сумов', 'remindersCap': 'НАПОМИНАНИЯ', 'remind': 'Напомнить',
  'given': 'Выдано в долг', 'taken': 'Взято в долг', 'repaid': 'Возвращено', 'netLabel': 'Чистый баланс',
  'logout': 'Выйти',
  'namePh': 'Введите имя', 'notePh': 'Например: за товар',
  'sheetNew': 'Новая операция', 'sheetNewBook': 'Запись без подтверждения', 'makeCode': 'Создать код', 'saveUnconf': 'Сохранить (без подтв.)',
  'hintClient': 'Код появится в чате. Когда вторая сторона введёт код, запись будет заблокирована.',
  'hintBook': 'Эта запись хранится только в вашей тетради — это не далил.',
  'balPfx': 'Баланс: ', 'stPending': 'Ожидание', 'stOk': 'Запись', 'stArch': 'В архиве', 'kod': 'код',
  'me': 'Жасур Тошматов (вы)', 'last': 'Последняя: ', 'noOps': 'Нет операций',
  'subPos': 'вам должны', 'subNeg': 'вы должны', 'subZero': 'счёт равный', 'zero': '0 сум', 'som': 'сум', 'due': 'срок',
  'tCode': 'Код создан — ', 'tSaved': 'Запись сохранена (без подтв.)', 'tDalil': 'Далил создан',
  'tArch': 'Перенесено в архив', 'tWelcome': 'Добро пожаловать!',
  'tSum': 'Введите сумму', 'tNum': 'Введите номер полностью', 'tEnterCode': 'Введите код',
  'profTil': 'Язык', 'profTilVal': 'Русский', 'profCur': 'Основная валюта', 'profPin': 'PIN-код',
  'profNotif': 'Уведомления', 'profArch': 'Записи в архиве', 'on': 'Включено',
};

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
    'xarTab': 'chat', 'xarPeriod': 'oy', 'voiceStage': null, 'vText': '',
    'xcCats': <String>[], 'qarzDraft': null,
    // Chatdagi yozuvni inline tahrirlash (bubble bosilganda)
    'xEditId': null, 'xEditVals': null,
    'xarLimit': 0, 'limEdit': null,
    'xarEntries': <Map<String, dynamic>>[],
    'screen': 'home', 'clientId': null, 'tab': 'chat',
    'sheetOpen': false, 'sheetMode': 'client', 'sheetClient': null,
    'receiptId': null, 'search': '', 'chatInput': '', 'toast': '',
    'notifOpen': false,
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
    if (Api.token != null) _tryResume(); // kutmaymiz — welcome darhol chiziladi
  }

  // Saqlangan token bilan sessiyani tiklash.
  // MUHIM: 401 (token yaroqsiz) va tarmoq/server xatosi (status 0/5xx) ni AJRATAMIZ —
  // aks holda vaqtinchalik uzilishда yaroqli sessiya "chiqib ketgan" ko'rinardi.
  Future<void> _tryResume() async {
    final prof = await Api.me();
    if (prof.ok && prof.data != null) {
      final p = prof.data as Map<String, dynamic>;
      set({
        'meId': p['id'], 'mePhone': p['phone'], 'meName': p['full_name'],
        'notifOn': p['notif_enabled'] != false,
        'stage': 'app', 'skelHome': true,
      });
      await hydrate();
      set({'skelHome': false});
      _startPolling();
    } else if (prof.status == 401) {
      await Api.saveToken(null); // muddati o'tgan token — welcome'da qoladi
    } else {
      // Tarmoq/server xatosi (status 0 yoki 5xx): token yaroqli — ilovaga kiritamiz,
      // hydrate keyin qayta urinadi. Foydalanuvchi onboarding'ga tushmaydi.
      set({'stage': 'app', 'skelHome': true});
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

  Map<String, dynamic> L() => S['lang'] == 'ru' ? _ru : _uz;

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

  String typeLabel(String t) {
    if (S['lang'] != 'ru') return t;
    return {
      'Qarz berdim': 'Дал в долг', 'Qarz oldim': 'Взял в долг',
      "To'lov oldim": 'Получил оплату', "To'lov berdim": 'Отдал оплату',
    }[t] ?? t;
  }

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
    set({field: v});
    if (field == 'pinVal' && v.length == 4) {
      Timer(const Duration(milliseconds: 280), () {
        set({'stage': 'app', 'pinVal': '', 'skelHome': true, 'homeVis': 6});
        Timer(const Duration(milliseconds: 950), () => set({'skelHome': false}));
        toast_(L()['tWelcome']);
      });
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

  void startRec() {
    if (S['recOn'] == true) return;
    set({'recOn': true});
    Timer(const Duration(milliseconds: 1600), () {
      if (S['clientId'] == null) {
        set({'recOn': false});
        return;
      }
      addLocalMsg(S['clientId'] as String,
          {'k': 'voice', 'mine': true, 'dur': 7, 'time': 'Hozir', 'read': false});
      set({'recOn': false});
    });
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
    // Har doim avtomatik: parse natijasi to'g'ridan-to'g'ri chatga (parsed = xato tuzatishni o'rganish uchun)
    final ok = await _xcConfirm(txt, source, actions, actions);
    if (!ok) set({'voiceStage': null, 'vText': ''});
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
      set({'xarEntries': [...es.reversed, ..._xar()]});
    }
    set({'voiceStage': null, 'vText': ''});
    if (saved.isNotEmpty) {
      final cats = saved.map((e) => e['category'] ?? 'Boshqa').toSet().join(', ');
      toast_('AI toifaladi: $cats — chatga yozildi');
    }
    if (routed.isNotEmpty) _routeQarz(routed.first);
    return true;
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
    set({'stage': 'pin', 'pinVal': ''});
  }

  void logout_() {
    _poll?.cancel();
    Api.saveToken(null);
    set({
      'stage': 'welcome', 'phone': '', 'otpVal': '', 'pinVal': '',
      'screen': 'home', 'clientId': null, 'receiptId': null, 'sheetOpen': false,
      'notifOpen': false, 'linkDecisionId': null, 'rejOpen': false,
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
      'micHoldStart': () => voiceHoldStart(),
      'micHoldEnd': () => voiceHoldEnd(),
      'micRec': S['voiceStage'] == 'rec',        // yozayapti (pulse)
      'micParsing': S['voiceStage'] == 'parsing', // tahlil qilinyapti
      'micHint': S['voiceStage'] == 'rec'
          ? "Tinglayapman… gapiring, qo'yib yuboring"
          : S['voiceStage'] == 'parsing'
              ? 'Tahlil qilinyapti…'
              : "Bosib ushlab gapiring — AI o'zi yozib toifalaydi",
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
              'sub': "Sizni kontragent qilib qo'shgan",
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
    final meStr = '${meLabel()} ${S['lang'] == 'ru' ? '(вы)' : '(siz)'}';
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
      {'label': L0['profTil'], 'value': L0['profTilVal'], 'isPlain': true, 'isSwitch': false, 'tap': () => setLang(S['lang'] == 'uz' ? 'ru' : 'uz')},
      {'label': L0['profCur'], 'value': 'UZS', 'isPlain': true, 'isSwitch': false, 'tap': () {}},
      mkSwitch('Tungi rejim', dk, () => setDark(!dk)),
      mkSwitch(L0['profPin'], S['pinOn'] == true, () => set({'pinOn': S['pinOn'] != true})),
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
        'label': 'Rad etilgan bog\'lanishlar',
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
            {'k': 'text', 'mine': true, 'text': (S['chatInput'] as String).trim(), 'time': 'Hozir', 'read': false});
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
      'micTap': () => startRec(),
      'camTap': () => toast_('Kamera (demo)'),
      'attachTap': () => toast_('Fayl biriktirish (demo)'),

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
      'startOnb': () => set({'stage': 'phone'}),
      'backToWelcome': () => set({'stage': 'welcome'}),
      'backToPhone': () => set({'stage': 'phone', 'otpVal': ''}),
      'backToOtp': () => set({'stage': 'otp', 'pinVal': ''}),
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
      'pdfDownload': () => toast_('PDF yuklab olinmoqda…'),
      'pdfShare': () => toast_('Ulashish oynasi ochildi (demo)'),

      'toastOpen': (S['toast'] as String).isNotEmpty,
      'toast': S['toast'],
    };
  }
}

final TrustStore store = TrustStore();

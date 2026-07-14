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
  'tagline': "Qarz va hisob-kitoblaringizni ikki tomonlama tasdiq bilan yuriting. Har bir yozuv — o'chirilmas halol dalil.",
  'start': 'Boshlash', 'terms': 'Davom etish orqali foydalanish shartlariga rozilik bildirasiz',
  'phoneTitle': 'Telefon raqami', 'phoneSub': "Hisobingiz shu raqamga bog'lanadi", 'cont': 'Davom etish',
  'otpTitle': 'Tasdiqlash kodi', 'otpDemo': 'Demo: istalgan 5 raqam qabul qilinadi', 'confirm': 'Tasdiqlash',
  'pinTitle': "PIN o'rnating", 'pinSub': 'Ilovaga kirish uchun 4 xonali kod',
  'appSub': 'Ishonchli hisob-kitob', 'netCap': 'SOF BALANS', 'owedTo': 'Sizga qarz', 'owedBy': 'Qarzingiz', 'searchPh': 'Qidirish',
  'navClients': 'Hamkorlar', 'navFin': 'Moliya', 'navProfile': 'Profil',
  'tabChat': 'Chat', 'tabOps': 'Operatsiyalar', 'opCap': 'Operatsiya',
  'codeWrong': "Kod noto'g'ri. Qayta urinib ko'ring.",
  'openDalil': 'Dalilni ochish', 'msgPh': 'Xabar yozing',
  'receiptTitle': 'Dalil', 'lockedCap': 'QULFLANGAN YOZUV', 'from': 'Kimdan', 'to': 'Kimga', 'date': 'Sana',
  'codeLabel': 'Tasdiqlash kodi', 'statusL': 'Holat', 'statusVal': 'Ikki tomonlama tasdiqlangan',
  'receiptNote': "Ushbu yozuv o'chirib bo'lmaydi. O'zgartirish faqat ikki tomon roziligi bilan amalga oshiriladi.",
  'share': 'Ulashish (PDF)', 'changeReq': "O'zgartirish so'rovi", 'archive': 'Arxivlash',
  'finTitle': 'Moliya', 'turnover': 'OYLIK AYLANMA', 'mlnHint': "mln so'm hisobida", 'remindersCap': 'ESLATMALAR', 'remind': 'Eslatish',
  'given': 'Berilgan qarzlar', 'taken': 'Olingan qarzlar', 'repaid': "Qaytarilgan to'lovlar", 'netLabel': 'Sof balans',
  'logout': 'Chiqish',
  'namePh': 'Ism yozing', 'notePh': 'Masalan: mol savdosi uchun',
  'sheetNew': 'Yangi operatsiya', 'sheetNewBook': 'Yangi tasdiqsiz yozuv', 'makeCode': 'Kod yaratish', 'saveUnconf': 'Saqlash (tasdiqsiz)',
  'hintClient': "Kod chatda ko'rinadi. Ikkinchi tomon kodni kiritgach, yozuv qulflanadi.",
  'hintBook': 'Bu yozuv faqat sizning daftaringizda saqlanadi — dalil emas.',
  'balPfx': 'Balans: ', 'stPending': 'Kutilmoqda', 'stOk': 'Tasdiqlangan', 'stArch': 'Arxivda', 'kod': 'kod',
  'me': 'Jasur Toshmatov (siz)', 'last': "So'nggi: ", 'noOps': "Amaliyot yo'q",
  'subPos': 'sizga qarz', 'subNeg': 'siz qarzsiz', 'subZero': 'hisob teng', 'zero': "0 so'm", 'som': "so'm", 'due': 'muddat',
  'tCode': 'Kod yaratildi — ', 'tSaved': 'Tasdiqsiz yozuv saqlandi', 'tDalil': 'Dalil yaratildi',
  'tArch': "Arxivga ko'chirildi", 'tWelcome': 'Xush kelibsiz, Jasur!',
  'tSum': 'Summani kiriting', 'tNum': "Raqamni to'liq kiriting", 'tEnterCode': 'Kodni kiriting',
  'profTil': 'Til', 'profTilVal': "O'zbek (lotin)", 'profCur': 'Asosiy valyuta', 'profPin': 'PIN-kod',
  'profNotif': 'Bildirishnomalar', 'profArch': 'Arxivlangan yozuvlar', 'on': 'Yoqilgan',
};

const Map<String, dynamic> _ru = {
  'slogan': '«Счёт дружбы не портит»',
  'tagline': 'Записывайте долги с подтверждением обеих сторон. Каждая запись — честное доказательство, которое нельзя удалить.',
  'start': 'Начать', 'terms': 'Продолжая, вы соглашаетесь с условиями использования',
  'phoneTitle': 'Номер телефона', 'phoneSub': 'Аккаунт будет привязан к этому номеру', 'cont': 'Продолжить',
  'otpTitle': 'Код подтверждения', 'otpDemo': 'Демо: подойдут любые 5 цифр', 'confirm': 'Подтвердить',
  'pinTitle': 'Установите PIN', 'pinSub': 'Код из 4 цифр для входа в приложение',
  'appSub': 'учёт долгов', 'netCap': 'ЧИСТЫЙ БАЛАНС', 'owedTo': 'Вам должны', 'owedBy': 'Вы должны', 'searchPh': 'Поиск',
  'navClients': 'Клиенты', 'navFin': 'Финансы', 'navProfile': 'Профиль',
  'tabChat': 'Чат', 'tabOps': 'Операции', 'opCap': 'Операция',
  'codeWrong': 'Неверный код. Попробуйте ещё раз.',
  'openDalil': 'Открыть далил', 'msgPh': 'Напишите сообщение',
  'receiptTitle': 'Далил', 'lockedCap': 'ЗАЩИЩЁННАЯ ЗАПИСЬ', 'from': 'От кого', 'to': 'Кому', 'date': 'Дата',
  'codeLabel': 'Код подтверждения', 'statusL': 'Статус', 'statusVal': 'Подтверждено обеими сторонами',
  'receiptNote': 'Эту запись нельзя удалить. Изменения — только с согласия обеих сторон.',
  'share': 'Поделиться (PDF)', 'changeReq': 'Запрос на изменение', 'archive': 'В архив',
  'finTitle': 'Финансы', 'turnover': 'ОБОРОТ ПО МЕСЯЦАМ', 'mlnHint': 'в млн сумов', 'remindersCap': 'НАПОМИНАНИЯ', 'remind': 'Напомнить',
  'given': 'Выдано в долг', 'taken': 'Взято в долг', 'repaid': 'Возвращено', 'netLabel': 'Чистый баланс',
  'logout': 'Выйти',
  'namePh': 'Введите имя', 'notePh': 'Например: за товар',
  'sheetNew': 'Новая операция', 'sheetNewBook': 'Запись без подтверждения', 'makeCode': 'Создать код', 'saveUnconf': 'Сохранить (без подтв.)',
  'hintClient': 'Код появится в чате. Когда вторая сторона введёт код, запись будет заблокирована.',
  'hintBook': 'Эта запись хранится только в вашей тетради — это не далил.',
  'balPfx': 'Баланс: ', 'stPending': 'Ожидание', 'stOk': 'Подтверждено', 'stArch': 'В архиве', 'kod': 'код',
  'me': 'Жасур Тошматов (вы)', 'last': 'Последняя: ', 'noOps': 'Нет операций',
  'subPos': 'вам должны', 'subNeg': 'вы должны', 'subZero': 'счёт равный', 'zero': '0 сум', 'som': 'сум', 'due': 'срок',
  'tCode': 'Код создан — ', 'tSaved': 'Запись сохранена (без подтв.)', 'tDalil': 'Далил создан',
  'tArch': 'Перенесено в архив', 'tWelcome': 'Добро пожаловать, Жасур!',
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
    'xarTab': 'chat', 'xarPeriod': 'oy', 'voiceStage': null, 'vText': '', 'xarText': '', 'vReal': false,
    'xarLimit': 3000000, 'limEdit': null,
    'xarEntries': <Map<String, dynamic>>[
      {'id': 'x1', 'kind': 'x', 'cat': 'Oziq-ovqat', 'note': 'Bozorlik', 'a': 85000, 'days': 0, 't': '09:40'},
      {'id': 'x2', 'kind': 'x', 'cat': 'Transport', 'note': 'Taksi', 'a': 25000, 'days': 1, 't': '18:22'},
      {'id': 'x3', 'kind': 'd', 'cat': 'Daromad', 'note': 'Oylik', 'a': 5000000, 'days': 2, 't': '12:05'},
      {'id': 'x4', 'kind': 'x', 'cat': "Ko'ngilochar", 'note': 'Kino', 'a': 60000, 'days': 3, 't': '20:15'},
      {'id': 'x5', 'kind': 'x', 'cat': 'Salomatlik', 'note': 'Dori-darmon', 'a': 42000, 'days': 5, 't': '11:30'},
      {'id': 'x6', 'kind': 'x', 'cat': 'Kommunal', 'note': 'Internet', 'a': 89000, 'days': 6, 't': '09:00'},
      {'id': 'x7', 'kind': 'x', 'cat': 'Kiyim', 'note': "Ko'ylak", 'a': 180000, 'days': 12, 't': '16:45'},
      {'id': 'x8', 'kind': 'x', 'cat': 'Oziq-ovqat', 'note': 'Oylik bozorlik', 'a': 230000, 'days': 20, 't': '10:20'},
      {'id': 'x9', 'kind': 'd', 'cat': 'Daromad', 'note': 'Frilans loyiha', 'a': 1200000, 'days': 45, 't': '14:00'},
      {'id': 'x10', 'kind': 'x', 'cat': 'Transport', 'note': 'Benzin', 'a': 300000, 'days': 90, 't': '08:15'},
    ],
    'screen': 'home', 'clientId': null, 'tab': 'chat',
    'sheetOpen': false, 'sheetMode': 'client', 'sheetClient': 'c1',
    'receiptId': null, 'search': '', 'chatInput': '', 'codeInput': '', 'codeError': false, 'toast': '',
    'notifOpen': false, 'pushOpen': false, 'confirmId': null, 'cfVal': '', 'cfError': false,
    'editFormOpen': false, 'editA': '', 'editNote': '', 'reviewId': null, 'pdfOpen': false,
    'playing': null, 'recOn': false, 'remTimes': <String, int>{}, 'revealed': <String, bool>{},
    'pinOn': true, 'notifOn': true, 'flipped': false,
    'cMenuOpen': false, 'cRen': null, 'pProfOpen': false,
    'skelHome': false, 'skelOps': false, 'homeVis': 6, 'opsVis': 8,
    'swipeId': null, 'swipeDx': 0.0, 'swipeSnap': null,
    'npOpen': false, 'npName': '', 'npPhone': '', 'npType': 'on',
    'homeLoadingMore': false, 'opsLoadingMore': false,
    'onbCc': '+998', 'npCc': '+998', 'ccOpen': null, 'ccSearch': '',
    'form': <String, dynamic>{'type': 'Qarz berdim', 'amount': '', 'currency': 'UZS', 'note': '', 'name': ''},
    'clients': <Map<String, dynamic>>[
      {'id': 'c1', 'name': 'Akmal Karimov', 'phone': '+998 91 234 56 78', 'onTrust': true},
      {'id': 'c2', 'name': 'Dilnoza Yusupova', 'phone': '+998 93 456 78 12', 'onTrust': true},
      {'id': 'c3', 'name': 'Bobur Rahimov', 'phone': '+998 90 765 43 21', 'onTrust': true},
      {'id': 'c4', 'name': 'Sardor Aliyev', 'phone': '+998 97 111 22 33', 'onTrust': true},
      {'id': 'c5', 'name': 'Malika opa', 'phone': '+998 88 300 40 50', 'onTrust': true},
      {'id': 'c6', 'name': "Qo'shni Karim", 'phone': '+998 94 210 33 08', 'onTrust': false},
      {'id': 'c7', 'name': 'Oybek (jiyan)', 'phone': '+998 99 512 74 40', 'onTrust': false},
      {'id': 'c8', 'name': "Zafar aka (do'kon)", 'phone': '+998 95 601 18 25', 'onTrust': false},
    ],
    'txs': <Map<String, dynamic>>[
      {'id': 't1', 'c': 'c1', 'type': 'Qarz berdim', 'a': 2000000, 'cur': 'UZS', 'date': '12-may', 'code': '51274', 'st': 'ok', 'by': 'me'},
      {'id': 't2', 'c': 'c1', 'type': 'Qarz berdim', 'a': 1000000, 'cur': 'UZS', 'date': '2-iyun', 'code': '71346', 'st': 'ok', 'by': 'me'},
      {'id': 't3', 'c': 'c1', 'type': "To'lov oldim", 'a': 600000, 'cur': 'UZS', 'date': '28-iyun', 'code': '90835', 'st': 'ok', 'by': 'them'},
      {'id': 't4', 'c': 'c1', 'type': "To'lov oldim", 'a': 400000, 'cur': 'UZS', 'date': 'Bugun', 'code': '90462', 'st': 'pending', 'by': 'them'},
      {'id': 't5', 'c': 'c2', 'type': 'Qarz oldim', 'a': 350000, 'cur': 'UZS', 'date': '20-iyun', 'code': '33581', 'st': 'ok', 'by': 'them'},
      {'id': 't6', 'c': 'c3', 'type': 'Qarz berdim', 'a': 1150000, 'cur': 'UZS', 'date': '5-iyul', 'code': '88127', 'st': 'ok', 'by': 'me'},
      {'id': 't7', 'c': 'c5', 'type': 'Qarz berdim', 'a': 120, 'cur': 'USD', 'date': '30-iyun', 'code': '22643', 'st': 'ok', 'by': 'me'},
      {'id': 't8', 'c': 'c4', 'type': 'Qarz berdim', 'a': 500000, 'cur': 'UZS', 'date': '3-aprel', 'code': '66125', 'st': 'ok', 'by': 'me'},
      {'id': 't9', 'c': 'c4', 'type': "To'lov oldim", 'a': 500000, 'cur': 'UZS', 'date': '30-aprel', 'code': '11478', 'st': 'ok', 'by': 'them'},
      {'id': 't10', 'c': 'c1', 'type': 'Qarz oldim', 'a': 500000, 'cur': 'UZS', 'date': 'Bugun', 'code': '48215', 'st': 'pending', 'by': 'them'},
      {'id': 't11', 'c': 'c6', 'type': 'Qarz berdim', 'a': 50000, 'cur': 'UZS', 'date': '8-iyul', 'code': '', 'st': 'unconf', 'by': 'me'},
      {'id': 't12', 'c': 'c7', 'type': 'Qarz berdim', 'a': 15, 'cur': 'USD', 'date': '1-iyul', 'code': '', 'st': 'unconf', 'by': 'me'},
      {'id': 't13', 'c': 'c8', 'type': 'Qarz oldim', 'a': 200000, 'cur': 'UZS', 'date': '11-iyul', 'code': '', 'st': 'unconf', 'by': 'me'},
    ],
    'msgs': <String, List<Map<String, dynamic>>>{
      'c1': [
        {'k': 'text', 'mine': false, 'text': 'Assalomu alaykum, Jasur aka', 'time': '09:12'},
        {'k': 'text', 'mine': true, 'text': 'Vaalaykum assalom, Akmal', 'time': '09:14', 'read': true},
        {'k': 'voice', 'mine': false, 'dur': 12, 'time': '09:15'},
        {'k': 'voice', 'mine': true, 'dur': 7, 'time': '09:16', 'read': true},
        {'k': 'vnote', 'mine': false, 'dur': 23, 'time': '09:18'},
        {'k': 'text', 'mine': false, 'text': "400 ming to'lov qildim, tasdiqlab bering", 'time': '09:20'},
        {'k': 'tx', 'tx': 't4'},
        {'k': 'code', 'mine': false, 'code': '90462', 'time': '09:21'},
        {'k': 'tx', 'tx': 't10'},
        {'k': 'text', 'mine': true, 'text': 'Hozir tekshiraman', 'time': '09:22', 'read': false},
      ],
      'c2': [
        {'k': 'text', 'mine': false, 'text': 'Oyning 15-igacha qaytaraman, xavotir olmang', 'time': '18:02'},
        {'k': 'tx', 'tx': 't5'},
      ],
      'c3': [{'k': 'tx', 'tx': 't6'}],
      'c4': [
        {'k': 'tx', 'tx': 't8'},
        {'k': 'tx', 'tx': 't9'},
        {'k': 'text', 'mine': false, 'text': 'Rahmat, hisob teng!', 'time': '12:40'},
      ],
      'c5': [{'k': 'tx', 'tx': 't7'}],
      'c6': [{'k': 'tx', 'tx': 't11'}],
      'c7': [{'k': 'tx', 'tx': 't12'}],
      'c8': [
        {'k': 'tx', 'tx': 't13'},
        {'k': 'text', 'mine': true, 'text': "Do'kondan olingan mol uchun yozib qo'ydim", 'time': '11-iyul', 'read': false},
      ],
    },
    'notifs': <Map<String, dynamic>>[
      {'id': 'n1', 'kind': 'request', 'unread': true, 'title': "Tasdiq so'rovi", 'detail': "Akmal Karimov · 500 000 so'm · kod kerak", 'time': 'Hozir', 'tx': 't10'},
      {'id': 'n2', 'kind': 'confirmed', 'unread': true, 'title': 'Tasdiqlandi', 'detail': "Bobur Rahimov 1 150 000 so'm amalini tasdiqladi", 'time': 'Kecha', 'tx': 't6'},
      {'id': 'n3', 'kind': 'reminder', 'unread': false, 'title': 'Eslatma', 'detail': "Dilnoza Yusupova · 350 000 so'm · muddat: 15-iyul", 'time': '2 kun oldin', 'client': 'c2'},
    ],
  };

  Timer? _tt, _pi, _lp, _xt;
  Map<String, dynamic>? _sw;
  bool _swClick = false;
  String? _inv;
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

  void replyFrom(String cid, String text, [int delay = 1500]) {
    Timer(Duration(milliseconds: delay), () {
      final fl = S['flipped'] == true && S['clientId'] == cid;
      final msgs = Map<String, List<Map<String, dynamic>>>.from(S['msgs']);
      final arr = (msgs[cid] ?? [])
          .map((m) => (m['mine'] ?? false) != fl ? {...m, 'read': true} : m)
          .toList();
      arr.add({'k': 'text', 'mine': fl, 'text': text, 'time': 'Hozir'});
      msgs[cid] = arr;
      set({'msgs': msgs});
    });
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
  Map<String, List<Map<String, dynamic>>> _msgs() =>
      Map<String, List<Map<String, dynamic>>>.from(S['msgs']);

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

  void archive_(String id) {
    set({
      'clients': _clients().map((x) => x['id'] == id ? {...x, 'archived': true} : x).toList(),
      'swipeSnap': null, 'swipeId': null, 'swipeDx': 0.0,
    });
    toast_(L()['tArch']);
  }

  void restore_(String id) {
    set({
      'clients': _clients().map((x) => x['id'] == id ? {...x, 'archived': false} : x).toList(),
      'swipeSnap': null, 'swipeId': null, 'swipeDx': 0.0,
    });
    toast_('Arxivdan qaytarildi');
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

  void renSave_() {
    if (S['cRen'] == null) return;
    final v = (S['cRen'] as String).trim();
    if (v.isEmpty) {
      set({'cRen': null});
      return;
    }
    set({
      'clients': _clients().map((x) => x['id'] == S['clientId'] ? {...x, 'name': v} : x).toList(),
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

  void confirmTx(String id) {
    final t = _tx(id)!;
    if ((S['codeInput'] as String).trim() == t['code']) {
      final msgs = _msgs();
      final cc = _client(t['c'])!;
      msgs[t['c']] = [
        ...(msgs[t['c']] ?? []),
        {'k': 'sys', 'text': '${(cc['name'] as String).split(' ')[0]} yaratdi (09:20) · Siz kodni kiritdingiz (hozir) · Dalil yaratildi'},
      ];
      set({
        'txs': _txs().map((x) => x['id'] == id ? {...x, 'st': 'ok'} : x).toList(),
        'msgs': msgs, 'codeInput': '', 'codeError': false,
      });
      toast_(L()['tDalil']);
      replyFrom(t['c'], "Rahmat! Hammasi to'g'ri.", 1600);
    } else {
      set({'codeError': true});
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
      final msgs = _msgs();
      final cid = S['clientId'] as String;
      msgs[cid] = [
        ...(msgs[cid] ?? []),
        {'k': 'voice', 'mine': S['flipped'] != true, 'dur': 7, 'time': 'Hozir', 'read': false},
      ];
      set({'recOn': false, 'msgs': msgs});
    });
  }

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');

  String fmtA(int a, String cur) => _fmt(a) + (cur == 'USD' ? ' \$' : " so'm");

  void submitEdit() {
    final t = _tx(S['receiptId']);
    if (t == null) return;
    final newA = int.tryParse(S['editA'] as String) ?? (t['a'] as int);
    final newNote = (S['editNote'] as String).trim();
    if (newA == t['a'] && newNote == (t['note'] ?? '')) {
      toast_("O'zgarish kiritilmadi");
      return;
    }
    final c = _client(t['c'])!;
    final notifs = [
      {
        'id': 'n${DateTime.now().millisecondsSinceEpoch}', 'kind': 'editreq', 'unread': true,
        'title': "O'zgartirish so'rovi",
        'detail': "${c['name']} yozuvni o'zgartirmoqchi: ${fmtA(t['a'], t['cur'])} → ${fmtA(newA, t['cur'])}. Tasdiqlaysizmi?",
        'time': 'Hozir', 'tx': t['id'],
      },
      ..._notifs(),
    ];
    set({
      'txs': _txs().map((x) => x['id'] == t['id'] ? {...x, 'edit': {'a': newA, 'note': newNote, 'date': '13-iyul'}} : x).toList(),
      'notifs': notifs, 'editFormOpen': false, 'editA': '', 'editNote': '',
    });
    toast_("So'rov yuborildi — ikkinchi tomon tasdiqlashi kerak");
  }

  void approveEdit() {
    final t = _tx(S['reviewId']);
    if (t == null || t['edit'] == null) return;
    final edit = t['edit'] as Map<String, dynamic>;
    final line = '${fmtA(t['a'], t['cur'])} → ${fmtA(edit['a'], t['cur'])} · ikki tomon tasdiqi · 13-iyul';
    final notifs = [
      {'id': 'n${DateTime.now().millisecondsSinceEpoch}', 'kind': 'confirmed', 'unread': true, 'title': "O'zgartirish tasdiqlandi", 'detail': line, 'time': 'Hozir', 'tx': t['id']},
      ..._notifs(),
    ];
    set({
      'txs': _txs().map((x) {
        if (x['id'] != t['id']) return x;
        return {
          ...x,
          'a': edit['a'],
          'note': (edit['note'] as String).isNotEmpty ? edit['note'] : x['note'],
          'edit': null,
          'hist': [...((t['hist'] as List?) ?? []), {'txt': line}],
        };
      }).toList(),
      'notifs': notifs, 'reviewId': null, 'receiptId': t['id'],
    });
    toast_('Yozuv tuzatildi — tarix saqlandi');
  }

  void rejectEdit() {
    final t = _tx(S['reviewId']);
    if (t == null) return;
    final notifs = [
      {'id': 'n${DateTime.now().millisecondsSinceEpoch}', 'kind': 'rejected', 'unread': true, 'title': "O'zgartirish rad etildi", 'detail': "Asl qiymat o'zgarishsiz qoladi — ${fmtA(t['a'], t['cur'])}", 'time': 'Hozir', 'tx': t['id']},
      ..._notifs(),
    ];
    set({
      'txs': _txs().map((x) => x['id'] == t['id'] ? {...x, 'edit': null} : x).toList(),
      'notifs': notifs, 'reviewId': null,
    });
    toast_('Rad etildi — asl yozuv saqlanadi');
  }

  void confirmSecond() {
    final t = _tx(S['confirmId']);
    if (t == null) return;
    if (S['cfVal'] == t['code']) {
      final c = _client(t['c'])!;
      final msgs = _msgs();
      msgs[t['c']] = [
        ...(msgs[t['c']] ?? []),
        {'k': 'sys', 'text': '${(c['name'] as String).split(' ')[0]} yaratdi (09:41) · Siz tasdiqladingiz (hozir) · Dalil yaratildi'},
      ];
      final amt = fmtA(t['a'], t['cur']);
      final notifs = [
        {'id': 'n${DateTime.now().millisecondsSinceEpoch}', 'kind': 'confirmed', 'unread': true, 'title': 'Tasdiqlandi', 'detail': '${c['name']} bilan $amt amali dalilga aylandi', 'time': 'Hozir', 'tx': t['id']},
        ..._notifs().map((n) => (n['tx'] == t['id'] && n['kind'] == 'request') ? {...n, 'unread': false} : n),
      ];
      set({
        'txs': _txs().map((x) => x['id'] == t['id'] ? {...x, 'st': 'ok'} : x).toList(),
        'msgs': msgs, 'notifs': notifs, 'confirmId': null, 'cfVal': '', 'cfError': false, 'receiptId': t['id'],
      });
      toast_('Dalil yaratildi');
      replyFrom(t['c'], 'Rahmat, Jasur aka!', 1800);
    } else {
      set({'cfError': true});
    }
  }

  void createTx() {
    final f = Map<String, dynamic>.from(S['form']);
    final a = int.tryParse(f['amount'] as String) ?? 0;
    if (a == 0) {
      toast_(L()['tSum']);
      return;
    }
    final code = (10000 + math.Random().nextInt(90000)).toString();
    final cl0 = _client(S['sheetClient']);
    final two = cl0 != null ? cl0['onTrust'] != false : true;
    final id = 't${DateTime.now().millisecondsSinceEpoch}';
    final tx = {
      'id': id, 'c': S['sheetClient'], 'type': f['type'], 'a': a, 'cur': f['currency'],
      'date': 'Bugun', 'code': two ? code : '', 'st': two ? 'pending' : 'unconf', 'by': 'me', 'note': f['note'],
    };
    final msgs = _msgs();
    final shc = S['sheetClient'] as String;
    msgs[shc] = [...(msgs[shc] ?? []), {'k': 'tx', 'tx': id}];
    set({
      'txs': [..._txs(), tx], 'msgs': msgs, 'sheetOpen': false,
      'clientId': shc, 'tab': 'chat',
      'form': {'type': 'Qarz berdim', 'amount': '', 'currency': 'UZS', 'note': '', 'name': ''},
    });
    if (!two) {
      toast_(L()['tSaved']);
      return;
    }
    toast_('${L()['tCode']}$code');
    Timer(const Duration(milliseconds: 4200), () {
      final t2 = _tx(id);
      if (t2 == null || t2['st'] != 'pending') return;
      final cl = _client(t2['c'])!;
      final msgs2 = _msgs();
      msgs2[t2['c']] = [
        ...(msgs2[t2['c']] ?? []),
        {'k': 'sys', 'text': '${(cl['name'] as String).split(' ')[0]} kodni kiritdi (hozir) · Dalil yaratildi'},
      ];
      final notifs2 = [
        {'id': 'n${DateTime.now().millisecondsSinceEpoch}', 'kind': 'confirmed', 'unread': true, 'title': 'Tasdiqlandi', 'detail': '${cl['name']} ${fmtA(t2['a'], t2['cur'])} amalini tasdiqladi · hozir', 'time': 'Hozir', 'tx': id},
        ..._notifs(),
      ];
      set({
        'txs': _txs().map((x) => x['id'] == id ? {...x, 'st': 'ok'} : x).toList(),
        'msgs': msgs2, 'notifs': notifs2,
      });
      toast_('${(cl['name'] as String).split(' ')[0]} kodni kiritdi — dalil yaratildi');
    });
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

  // Real ovoz yozish (STT) — XOTIRA spec: mikrofon -> backend (Groq, zaxira OpenAI) -> matn
  void voiceStart_() {
    set({'voiceStage': 'listen', 'vText': '', 'vReal': false});
    Stt.start(
      onStarted: () {
        if (S['voiceStage'] == 'listen') set({'vReal': true});
      },
      onDone: _voiceDone,
    );
  }

  void _voiceDone(String? text) {
    if (S['voiceStage'] != 'listen') return; // yopilgan yoki demo tanlangan
    if (text != null && text.trim().isNotEmpty) {
      xarPick_(text.trim());
    } else {
      set({'voiceStage': null, 'vText': '', 'vReal': false});
      toast_("Ovoz matnga aylanmadi — yozib yuboring yoki qayta urining");
    }
  }

  void xarPick_(String txt) {
    Stt.cancel();
    set({'voiceStage': 'parsing', 'vText': txt, 'xarText': ''});
    _xt?.cancel();
    _xt = Timer(const Duration(milliseconds: 1400), () {
      final f = xarParse_(txt);
      final a = int.tryParse(f['amount'] as String) ?? 0;
      if (a == 0) {
        set({'voiceStage': null, 'vText': ''});
        toast_('Summa aniqlanmadi — masalan: «taksiga 25 ming»');
        return;
      }
      final now = DateTime.now();
      final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final e = {'id': 'xe${now.millisecondsSinceEpoch}', 'kind': f['kind'], 'cat': f['cat'], 'note': f['note'], 'a': a, 'days': 0, 't': t};
      set({'xarEntries': [e, ..._xar()], 'voiceStage': null, 'vText': ''});
      toast_('AI toifaladi: ${f['cat']} — chatga yozildi');
    });
  }

  void limSave_() {
    final v = int.tryParse((S['limEdit'] ?? '') as String) ?? 0;
    if (v == 0) {
      toast_('Summani kiriting');
      return;
    }
    set({'xarLimit': v, 'limEdit': null});
    toast_('Oylik limit yangilandi');
  }

  // Onboarding — real API + demo fallback
  void sendOtpApi() {
    Api.sendOtp('${S['onbCc']}${S['phone']}');
  }

  Future<void> verifyOtpApi() async {
    final r = await Api.verifyOtp('${S['onbCc']}${S['phone']}', S['otpVal'] as String);
    if (r != null && r['token'] != null) {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('trust_token', r['token'] as String);
    }
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
      visual.add({
        'key': e['id'],
        'sep': false, 'bub': true,
        'just': isD ? 'start' : 'end',
        'rad': isD ? [4.0, 16.0, 16.0, 16.0] : [16.0, 4.0, 16.0, 16.0],
        'abbr': abbr(e['cat'] as String), 'cat': (e['cat'] as String).toUpperCase(),
        'amt': (isD ? '+' : '−') + money(e['a'] as int, 'UZS'),
        'color': isD ? green : red,
        'note': e['note'],
        'hasNote': (e['note'] as String? ?? '').isNotEmpty && (e['note'] as String).toLowerCase() != (e['cat'] as String).toLowerCase(),
        'time': e['t'] ?? '',
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
      'limRemainTxt': limOver ? 'Limitdan oshdi' : 'Qoldi: ${money(limRem, 'UZS')}',
      'limNoteTxt': limOver
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
      'xHasText': (S['xarText'] as String).trim().isNotEmpty,
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
      'xarMicTap': () => voiceStart_(),
      'vStop': () => Stt.finish(),
      'vHint': S['vReal'] == true
          ? "Gapiring… bo'lgach to'lqinni bosing (maks 10 s)"
          : "Demo: aytmoqchi bo'lgan jumlani tanlang",
      'xarTextVal': S['xarText'],
      'xarTextSet': (String t) => set({'xarText': t}),
      'xarTextGo': () {
        final t = (S['xarText'] as String).trim();
        if (t.isEmpty) {
          toast_('Jumla yozing');
          return;
        }
        xarPick_(t);
      },
      'vOpen': S['voiceStage'] != null,
      'vListen': S['voiceStage'] == 'listen',
      'vParsing': S['voiceStage'] == 'parsing',
      'vText': S['vText'],
      'vClose': () {
        _xt?.cancel();
        Stt.cancel();
        set({'voiceStage': null, 'vText': '', 'vReal': false});
      },
      'vSamples': ['Taksiga 25 ming', 'Oyligim 5 million tushdi', '50 ming oziq-ovqatga']
          .map((text) => {'text': text, 'pick': () => xarPick_(text)})
          .toList(),
      'vWave': List.generate(21, (i) => {
            'h': 10.0 + ((i * 53) % 37),
            'dur': 550 + ((i * 29) % 40) * 10,
            'delay': i * 90,
          }),
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
          set({'clientId': cid, 'tab': 'chat', 'codeInput': '', 'codeError': false, 'flipped': false, 'cMenuOpen': false, 'cRen': null, 'pProfOpen': false, 'opsVis': 8});
        },
      };
    }).toList();

    int toMeUZS = 0, toMeUSD = 0, byMe = 0;
    for (final c in _clients()) {
      final b = bal(c['id']);
      if (b['UZS']! > 0) toMeUZS += b['UZS']!;
      if (b['UZS']! < 0) byMe += -b['UZS']!;
      if (b['USD']! > 0) toMeUSD += b['USD']!;
    }
    final net = toMeUZS - byMe;

    // Client detail
    final client = _client(S['clientId']);
    final flip = S['flipped'] == true && client != null && client['onTrust'] != false;
    String flipT(String tp) => flip
        ? ({'Qarz berdim': 'Qarz oldim', 'Qarz oldim': 'Qarz berdim', "To'lov oldim": "To'lov berdim", "To'lov berdim": "To'lov oldim"}[tp] ?? tp)
        : tp;
    String cName = '', cInitials = '', cBal = '';
    Color cBalColor = ink;
    String pendText = '';
    bool hasPend = false;
    var chatItems = <Map<String, dynamic>>[];
    var opsRows = <Map<String, dynamic>>[];
    if (client != null) {
      final b0 = bal(client['id']);
      final b = balMain(flip ? {'UZS': -b0['UZS']!, 'USD': -b0['USD']!} : b0);
      cName = flip ? 'Jasur Toshmatov' : client['name'];
      cInitials = flip ? 'JT' : initials(client['name']);
      cBal = '${L0['balPfx']}${b['text']}';
      cBalColor = b['color'];
      final pend = _txs().where((t) => t['c'] == client['id'] && t['st'] == 'pending').toList();
      hasPend = pend.isNotEmpty;
      if (hasPend) {
        int pSum(String cur) => pend.where((t) => t['cur'] == cur).fold<int>(0, (s, t) => s + sign(flipT(t['type'])) * (t['a'] as int));
        final parts = ['UZS', 'USD']
            .map((cur) => {'cur': cur, 'v': pSum(cur)})
            .where((p) => p['v'] != 0)
            .map((p) => ((p['v'] as int) > 0 ? '+' : '−') + money((p['v'] as int).abs(), p['cur'] as String))
            .toList();
        pendText = 'Kutilmoqda: ${pend.length} amal${parts.isNotEmpty ? ' · ${parts.join(' · ')}' : ''}';
      }

      Map<String, dynamic> txRow(Map<String, dynamic> t) {
        final et = flipT(t['type']);
        return {
          'stLabel': t['st'] == 'pending' ? L0['stPending'] : (t['st'] == 'unconf' ? 'Tasdiqsiz' : (t['st'] == 'arch' ? L0['stArch'] : L0['stOk'])),
          'dot': (t['st'] == 'pending' || t['st'] == 'unconf') ? P.skelDot : ink,
          'type': typeLabel(et),
          'amount': (sign(et) > 0 ? '+' : '−') + money(t['a'], t['cur']),
          'acolor': sign(et) > 0 ? green : red,
          'date': t['date'],
          'code': t['code'],
          'showInput': t['st'] == 'pending' && (flip ? t['by'] == 'me' : t['by'] == 'them'),
          'showMyCode': t['st'] == 'pending' && (flip ? t['by'] == 'them' : t['by'] == 'me'),
          'done': t['st'] == 'ok' || t['st'] == 'arch',
          'unconf': t['st'] == 'unconf',
          'confirm': () => confirmTx(t['id']),
          'fillCode': flip ? () => set({'codeInput': t['code'], 'codeError': false}) : () {},
          'fillText': flip ? 'Kod push-bildirishnomada keldi — shu yerni bosib joylashtiring' : "Kod chatdagi xabarda — uni bosib oching, kataklar o'zi to'ladi",
          'openReceipt': () => set({'receiptId': t['id']}),
        };
      }

      final msgsList = _msgs()[client['id']] ?? [];
      chatItems = List.generate(msgsList.length, (mi) {
        final m = msgsList[mi];
        final mn = flip ? m['mine'] != true : m['mine'] == true;
        if (m['k'] == 'voice' || m['k'] == 'vnote') {
          final key = '${client['id']}:$mi';
          final playing = S['playing'] as Map<String, dynamic>?;
          final p = (playing != null && playing['key'] == key) ? playing : null;
          final prog = p != null ? p['prog'] as double : 0.0;
          final isPlaying = p != null && p['paused'] != true;
          final checks = mn ? ((flip ? m['read'] != false : m['read'] == true) ? ' ✓✓' : ' ✓') : '';
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
        if (m['k'] == 'code') {
          final key = '${client['id']}:$mi';
          final revealed = (S['revealed'] as Map)[key] == true;
          return {
            'key': key, 'isCode': true, 'isText': false, 'isSys': false, 'isTx': false, 'isVoice': false, 'isVnote': false,
            'bg': P.field, 'fg': ink,
            'cap': dk ? const Color(0xFF77777C) : const Color(0xFFA6A6A2),
            'align': mn ? 'end' : 'start',
            'capText': flip ? 'Kodni ikkinchi tomon kiritadi' : 'Kod pastdagi kataklarga joylashtirildi',
            'hidden': !revealed, 'revealed': revealed,
            'codeText': (m['code'] as String).split('').join(' '),
            'time': m['time'],
            'revealTap': () => set({
              'revealed': {...(S['revealed'] as Map), key: true},
              'codeInput': m['code'], 'codeError': false,
            }),
          };
        }
        if (m['k'] == 'text') {
          return {
            'key': '${client['id']}:$mi',
            'isText': true, 'isTx': false, 'isSys': false, 'isVoice': false, 'isVnote': false, 'isCode': false,
            'checks': mn ? ((flip ? m['read'] != false : m['read'] == true) ? ' ✓✓' : ' ✓') : '',
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
          'type': typeLabel(flipT(t['type'])),
          'date': '${t['date']}${t['st'] == 'ok' ? ' · ${L0['kod']} ${t['code']}' : ''}',
          'amount': r['amount'], 'color': r['acolor'], 'st': r['stLabel'], 'dot': r['dot'],
          'canOpen': t['st'] == 'ok' || t['st'] == 'arch',
          'open': (t['st'] == 'ok' || t['st'] == 'arch') ? () => set({'receiptId': t['id']}) : () {},
        };
      }).toList();
    }

    // Receipt
    Map<String, dynamic> receipt = {'close': () {}, 'share': () {}, 'change': () {}, 'archive': () {}};
    final rt = _tx(S['receiptId']);
    if (rt != null) {
      final rc = _client(rt['c'])!;
      final meGives = rt['type'] == 'Qarz berdim' || rt['type'] == "To'lov berdim";
      final txsIdx = _txs().indexWhere((x) => x['id'] == rt['id']);
      receipt = {
        'id': 'TR-${2480 + txsIdx}',
        'type': typeLabel(rt['type']),
        'amount': money(rt['a'], rt['cur']),
        'from': meGives ? L0['me'] : rc['name'],
        'to': meGives ? rc['name'] : L0['me'],
        'date': rt['date'] == 'Bugun' ? '12-iyul, 2026' : '${rt['date']}, 2026',
        'code': (rt['code'] as String).split('').join(' '),
        'editPending': rt['edit'] != null,
        'editLine': rt['edit'] != null ? '${money(rt['a'], rt['cur'])} → ${money((rt['edit'] as Map)['a'], rt['cur'])}' : '',
        'corrected': (rt['hist'] as List?)?.isNotEmpty == true,
        'histRows': (rt['hist'] as List?) ?? [],
        'close': () => set({'receiptId': null, 'pdfOpen': false}),
        'share': () => set({'pdfOpen': true}),
        'change': () {
          if (rt['edit'] != null) {
            toast_("So'rov allaqachon yuborilgan");
          } else {
            set({'editFormOpen': true, 'editA': '', 'editNote': rt['note'] ?? ''});
          }
        },
        'archive': () {
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
      final rc2 = _client(rt['c'])!;
      final meGives2 = rt['type'] == 'Qarz berdim' || rt['type'] == "To'lov berdim";
      const myPhone = '+998 90 123 45 67';
      final txsIdx = _txs().indexWhere((x) => x['id'] == rt['id']);
      pdf = {
        'docId': 'TR-2026-000${510 + txsIdx}',
        'fromName': meGives2 ? 'Jasur Toshmatov' : rc2['name'],
        'fromPhone': meGives2 ? myPhone : (rc2['phone'] ?? ''),
        'toName': meGives2 ? rc2['name'] : 'Jasur Toshmatov',
        'toPhone': meGives2 ? (rc2['phone'] ?? '') : myPhone,
        'amount': money(rt['a'], rt['cur']),
        'type': typeLabel(rt['type']),
        'dateTime': '${rt['date'] == 'Bugun' ? '13-iyul 2026' : '${rt['date']} 2026'} · 09:41',
        'madeAt': '09:20', 'okAt': '09:41',
        'code': (rt['code'] as String).split('').join(' '),
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
    const barData = [['Fev', 1.1], ['Mar', 0.7], ['Apr', 1.9], ['May', 0.9], ['Iyn', 2.3], ['Iyl', 3.1]];
    final bars = List.generate(barData.length, (i) {
      final label = barData[i][0] as String;
      final v = barData[i][1] as double;
      return {
        'label': label, 'val': v.toStringAsFixed(1),
        'h': (v / 3.1 * 80).roundToDouble(),
        'bg': i == barData.length - 1 ? ink : (dk ? const Color(0xFF2E2E2F) : const Color(0xFFE6E6E2)),
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
        'remind': () {
          final lt = ((S['remTimes'] as Map)[key] as int?) ?? 0;
          if (DateTime.now().millisecondsSinceEpoch - lt < 10800000) return;
          set({'remTimes': {...(S['remTimes'] as Map), key: DateTime.now().millisecondsSinceEpoch}});
          toast_('Eslatma yuborildi — ${name.split(' ')[0]} push oladi');
        },
      };
    }
    final reminders = [
      mkRem('r1', 'Dilnoza Yusupova', '${money(350000, 'UZS')} · ${L0['due']}: 15-iyul'),
      mkRem('r2', "Qo'shni Karim", '${money(50000, 'UZS')} · ${L0['due']}: 20-iyul'),
    ];

    final xarV = _xarVals(P, money);

    // Profil
    Map<String, dynamic> mkSwitch(String label, bool on, VoidCallback tap) => {
          'label': label, 'isSwitch': true, 'isPlain': false, 'value': '',
          'trk': on ? ink : (dk ? const Color(0xFF3A3A3C) : const Color(0xFFD9D9D5)),
          'knob': dk ? const Color(0xFF0F0F10) : const Color(0xFFFFFFFF),
          'knobLeft': on ? 21.0 : 3.0,
          'tap': tap,
        };
    final profRows = [
      {'label': L0['profTil'], 'value': L0['profTilVal'], 'isPlain': true, 'isSwitch': false, 'tap': () => setLang(S['lang'] == 'uz' ? 'ru' : 'uz')},
      {'label': L0['profCur'], 'value': 'UZS', 'isPlain': true, 'isSwitch': false, 'tap': () {}},
      mkSwitch('Tungi rejim', dk, () => setDark(!dk)),
      mkSwitch(L0['profPin'], S['pinOn'] == true, () => set({'pinOn': S['pinOn'] != true})),
      mkSwitch(L0['profNotif'], S['notifOn'] == true, () => set({'notifOn': S['notifOn'] != true})),
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
    final shTwo = shCl != null ? shCl['onTrust'] != false : true;
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

    // Notifications + second-party confirm
    final notifRows = _notifs().map((n) {
      return {
        'key': n['id'],
        'title': n['title'], 'detail': n['detail'], 'time': n['time'], 'unread': n['unread'] == true,
        'isReq': n['kind'] == 'request', 'isOk': n['kind'] == 'confirmed', 'isRem': n['kind'] == 'reminder',
        'isEdit': n['kind'] == 'editreq', 'isRej': n['kind'] == 'rejected',
        'tap': () {
          final notifs = _notifs().map((x) => x['id'] == n['id'] ? {...x, 'unread': false} : x).toList();
          if (n['kind'] == 'request') {
            final t = _tx(n['tx']);
            if (t != null && t['st'] == 'pending') {
              set({'notifs': notifs, 'confirmId': n['tx'], 'cfVal': '', 'cfError': false});
            } else {
              set({'notifs': notifs, 'receiptId': n['tx']});
            }
          } else if (n['kind'] == 'editreq') {
            final t = _tx(n['tx']);
            if (t != null && t['edit'] != null) {
              set({'notifs': notifs, 'reviewId': n['tx']});
            } else {
              set({'notifs': notifs, 'receiptId': n['tx']});
            }
          } else if (n['kind'] == 'confirmed' || n['kind'] == 'rejected') {
            set({'notifs': notifs, 'receiptId': n['tx']});
          } else {
            set({'notifs': notifs, 'notifOpen': false, 'clientId': n['client'] ?? 'c2', 'tab': 'chat', 'codeInput': '', 'codeError': false});
          }
        },
      };
    }).toList();
    final cfTx = _tx(S['confirmId']);
    final cfClient = cfTx != null ? _client(cfTx['c']) : null;
    final cfVal = S['cfVal'] as String;
    final cfBoxes = List.generate(5, (i) => {
          'key': 'cf$i',
          'd': i < cfVal.length ? cfVal[i] : '',
          'bd': i == math.min(cfVal.length, 4) ? ink : bd,
        });
    final codeInput = S['codeInput'] as String;
    final codeBoxes = List.generate(5, (i) => {
          'key': 'cb$i',
          'd': i < codeInput.length ? codeInput[i] : '',
          'bd': i < codeInput.length ? ink : bd,
        });
    final cfTitle = cfClient != null ? "${cfClient['name']} ${money(cfTx!['a'], cfTx['cur'])} amalini tasdiqlashingizni so'rayapti" : '';
    final cfSub = cfTx != null ? '${typeLabel(cfTx['type'])} · ${cfTx['date']} · kod push-bildirishnomada' : '';
    final cfInitials = cfClient != null ? initials(cfClient['name']) : '';
    final rvTx = _tx(S['reviewId']);
    final rvClient = rvTx != null ? _client(rvTx['c']) : null;
    void openSecond() {
      final t = _tx('t10');
      if (t != null && t['st'] == 'pending') {
        set({'pushOpen': false, 'notifOpen': true, 'confirmId': 't10', 'cfVal': '', 'cfError': false});
      } else {
        set({'pushOpen': false, 'notifOpen': true, 'receiptId': 't10'});
      }
    }

    final active = ink, idle = P.idle;
    final noClient = S['clientId'] == null;

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
      'clientRows': clientRows,
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
      'openSheetHome': () => set({'npOpen': true, 'npName': '', 'npPhone': '', 'npType': 'on'}),
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
      'npPickOn': () => set({'npType': 'on'}),
      'npPickInv': () => set({'npType': 'inv'}),
      'npOnBg': S['npType'] == 'on' ? ink : bg, 'npOnFg': S['npType'] == 'on' ? bg : ink, 'npOnBd': S['npType'] == 'on' ? ink : bd,
      'npInvBg': S['npType'] == 'inv' ? ink : bg, 'npInvFg': S['npType'] == 'inv' ? bg : ink, 'npInvBd': S['npType'] == 'inv' ? ink : bd,
      'npHint': S['npType'] == 'on'
          ? "Hamkor Trust'da — yozuvlar ikki tomonlama tasdiqlanadi va dalil bo'ladi"
          : "SMS taklif yuboriladi. Hamkor qo'shilguncha yozuvlar tasdiqsiz saqlanadi",
      'npCreate': () {
        final nm = (S['npName'] as String).trim();
        if (nm.isEmpty) {
          toast_('Ismni kiriting');
          return;
        }
        if ((S['npPhone'] as String).length != ccNp['len']) {
          toast_(L0['tNum']);
          return;
        }
        final id = 'c${DateTime.now().millisecondsSinceEpoch}';
        final cl = {'id': id, 'name': nm, 'phone': '${S['npCc']} ${fmtIntl(S['npPhone'], S['npCc'])}', 'onTrust': S['npType'] == 'on'};
        set({
          'clients': [cl, ..._clients()],
          'npOpen': false, 'clientId': id, 'tab': 'chat', 'flipped': false, 'cMenuOpen': false, 'cRen': null,
          'pProfOpen': false, 'codeInput': '', 'codeError': false, 'opsVis': 8,
        });
        toast_(S['npType'] == 'on' ? "Hamkor qo'shildi" : 'Taklif SMS yuborildi');
      },
      'goHome': () => set({'screen': 'home', 'clientId': null, 'receiptId': null}),
      'goMoliya': () => set({'screen': 'moliya', 'clientId': null, 'receiptId': null}),
      'goProfil': () => set({'screen': 'profil', 'clientId': null, 'receiptId': null}),
      'goXarajat': () => set({'screen': 'xarajat', 'clientId': null, 'receiptId': null}),
      'cMij': S['screen'] == 'home' ? active : idle,
      'cMol': S['screen'] == 'moliya' ? active : idle,
      'cXar': S['screen'] == 'xarajat' ? active : idle,
      'cProf': S['screen'] == 'profil' ? active : idle,
      ...xarV,

      'clientOpen': client != null,
      'cName': cName, 'cInitials': cInitials, 'cBal': cBal, 'cBalColor': cBalColor,
      'hasPend': hasPend, 'pendText': pendText,
      'canFlip': client != null && client['onTrust'] != false,
      'oneSided': client != null && client['onTrust'] == false,
      'cOnTrust': client != null && client['onTrust'] != false,
      'menuOpen': S['cMenuOpen'],
      'menuTap': () {
        if (flip) return;
        set({'cMenuOpen': S['cMenuOpen'] != true});
      },
      'menuClose': () => set({'cMenuOpen': false}),
      'menuRename': () => set({'cMenuOpen': false, 'cRen': client != null ? client['name'] : ''}),
      'menuArchive': () {
        if (client == null) return;
        set({
          'clients': _clients().map((x) => x['id'] == client['id'] ? {...x, 'archived': true} : x).toList(),
          'cMenuOpen': false, 'clientId': null,
        });
        toast_(L0['tArch']);
      },
      'menuProfile': () => set({'cMenuOpen': false, 'pProfOpen': true}),
      'renaming': S['cRen'] != null,
      'notRenaming': S['cRen'] == null,
      'showChev': !flip,
      'renVal': S['cRen'] ?? '',
      'onRen': (String t) => set({'cRen': t}),
      'renSave': () => renSave_(),
      'pProfOpen': S['pProfOpen'],
      'pProfClose': () => set({'pProfOpen': false}),
      'pPhone': client != null ? client['phone'] : '',
      'pStatus': client != null
          ? (client['onTrust'] != false ? "Trust'da — ikki tomonlama tasdiq" : "Trust'da yo'q — yozuvlar tasdiqsiz")
          : '',
      'pOps': client != null ? _txs().where((t) => t['c'] == client['id']).length.toString() : '',
      'pBal': cBal.replaceFirst(L0['balPfx'] as String, ''),
      'inviteTap': () {
        if (client == null || _inv != null) return;
        _inv = client['id'];
        final cid = client['id'] as String;
        toast_('Taklif SMS yuborildi — ${(client['name'] as String).split(' ')[0]} kutilmoqda');
        Timer(const Duration(milliseconds: 2600), () {
          _inv = null;
          final cl2 = _client(cid);
          if (cl2 == null || cl2['onTrust'] == true) return;
          final msgs = _msgs();
          msgs[cid] = [
            ...(msgs[cid] ?? []),
            {'k': 'sys', 'text': "${(cl2['name'] as String).split(' ')[0]} Trust'ga qo'shildi · endi yozuvlar ikki tomonlama tasdiqlanadi"},
          ];
          set({
            'clients': _clients().map((x) => x['id'] == cid ? {...x, 'onTrust': true} : x).toList(),
            'msgs': msgs,
          });
          toast_("${(cl2['name'] as String).split(' ')[0]} Trust'ga qo'shildi");
        });
      },
      'flipped': flip,
      'flipWho': flip ? client['name'] : '',
      'flipTap': () {
        if (client == null) return;
        final nf = S['flipped'] != true;
        set({'flipped': nf});
        toast_(nf ? "${(client['name'] as String).split(' ')[0]} ko'rinishi (demo)" : "O'z ko'rinishingizga qaytdingiz");
      },
      'flipBg': flip ? ink : Colors.transparent,
      'flipFg': flip ? bg : ink,
      'flipBd': flip ? ink : bd,
      'back': () => set({'clientId': null, 'flipped': false, 'cMenuOpen': false, 'cRen': null, 'pProfOpen': false}),
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
      'codeBoxes': codeBoxes,
      'codeInput': S['codeInput'],
      'onCodeInput': (String t) {
        var d = t.replaceAll(RegExp(r'\D'), '');
        if (d.length > 5) d = d.substring(0, 5);
        set({'codeInput': d, 'codeError': false});
      },
      'codeError': S['codeError'],
      'chatInput': S['chatInput'],
      'onChatInput': (String t) => set({'chatInput': t}),
      'sendChat': () {
        if ((S['chatInput'] as String).trim().isEmpty || client == null) return;
        final msgs = _msgs();
        final cid = client['id'] as String;
        msgs[cid] = [
          ...(msgs[cid] ?? []),
          {'k': 'text', 'mine': !flip, 'text': (S['chatInput'] as String).trim(), 'time': 'Hozir', 'read': false},
        ];
        set({'msgs': msgs, 'chatInput': ''});
        const replies = ["Xo'p bo'ladi", 'Rahmat!', "Ko'rdim, hozir javob yozaman"];
        replyFrom(cid, replies[msgs[cid]!.length % replies.length], 1600);
      },
      'openSheetClient': () => set({'sheetOpen': true, 'sheetMode': 'fixed', 'sheetClient': client!['id']}),
      'hasText': (S['chatInput'] as String).trim().isNotEmpty,
      'noText': (S['chatInput'] as String).trim().isEmpty,
      'recOn': S['recOn'],
      'recOff': S['recOn'] != true,
      'micTap': () => startRec(),
      'camTap': () => toast_('Kamera (demo)'),
      'attachTap': () => toast_('Fayl biriktirish (demo)'),

      'receiptOpen': rt != null, 'receipt': receipt,
      'molTotals': molTotals, 'bars': bars, 'reminders': reminders, 'profRows': profRows,

      'sheetOpen': S['sheetOpen'],
      'closeSheet': () => set({'sheetOpen': false}),
      'sheetTitle': shTwo ? L0['sheetNew'] : L0['sheetNewBook'],
      'sheetClientMode': S['sheetMode'] != 'fixed',
      'shTwoSided': shTwo,
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
      'sheetBtnLabel': shTwo ? L0['makeCode'] : L0['saveUnconf'],
      'sheetHint': shTwo ? L0['hintClient'] : L0['hintBook'],
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
      'phoneNext': () {
        if ((S['phone'] as String).length == ccOnb['len']) {
          sendOtpApi();
          set({'stage': 'otp', 'otpVal': ''});
        } else {
          toast_(L0['tNum']);
        }
      },
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
      'otpConfirm': () {
        if ((S['otpVal'] as String).length == 5) {
          verifyOtpApi();
          set({'stage': 'pin', 'pinVal': ''});
        } else {
          toast_(L0['tEnterCode']);
        }
      },
      'pinDots': pinDots,
      'pinKeys': makeKeys('pinVal'),
      'logout': () => set({'stage': 'welcome', 'phone': '', 'otpVal': '', 'pinVal': '', 'screen': 'home', 'clientId': null, 'receiptId': null, 'sheetOpen': false}),
      'L': L0,

      'openNotifs': () => set({'notifOpen': true}),
      'closeNotifs': () => set({'notifOpen': false}),
      'notifOpen': S['notifOpen'],
      'notifRows': notifRows,
      'bellDot': _notifs().any((n) => n['unread'] == true),
      'pushOpen': S['pushOpen'],
      'openPush': () => set({'pushOpen': true}),
      'closePush': () => set({'pushOpen': false}),
      'pushView': openSecond,
      'pushConfirmBtn': openSecond,
      'confirmOpen': cfTx != null,
      'closeConfirm': () => set({'confirmId': null, 'cfVal': '', 'cfError': false}),
      'cfTitle': cfTitle, 'cfSub': cfSub, 'cfInitials': cfInitials, 'cfBoxes': cfBoxes,
      'cfKeys': makeKeys('cfVal'),
      'cfConfirm': () => confirmSecond(),
      'cfError': S['cfError'],

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
      'reviewOpen': rvTx != null && rvTx['edit'] != null,
      'rv': (rvTx != null && rvTx['edit'] != null)
          ? {
              'initials': initials(rvClient!['name']),
              'title': "${rvClient['name']} yozuvni o'zgartirmoqchi",
              'sub': '${typeLabel(rvTx['type'])} · ${rvTx['date']} · TR-${2480 + _txs().indexWhere((x) => x['id'] == rvTx['id'])}',
              'oldAmt': money(rvTx['a'], rvTx['cur']),
              'newAmt': money((rvTx['edit'] as Map)['a'], rvTx['cur']),
              'hasNote': ((rvTx['edit'] as Map)['note'] as String? ?? '').isNotEmpty && (rvTx['edit'] as Map)['note'] != (rvTx['note'] ?? ''),
              'newNote': (rvTx['edit'] as Map)['note'] ?? '',
            }
          : <String, dynamic>{},
      'approveEdit': () => approveEdit(),
      'rejectEdit': () => rejectEdit(),
      'closeReview': () => set({'reviewId': null}),

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

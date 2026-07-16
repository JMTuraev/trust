// Trust — Circles (guruhli navbatli jamg'arma / ROSCA) ma'lumot qatlami.
// Backend bilan uzviy: /api/circles. Mock/seed YO'Q — hamma ma'lumot serverdan.
// Modellar backend JSON'idan fromJson bilan quriladi.
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';

/// Circles'ga xos qo'shimcha endpointlar (remind, join/:token) uchun mahalliy
/// so'rov yordamchisi. api.dart (umumiy fayl) tegilmasin deb shu yerda —
/// xatti-harakati Api._req bilan bir xil (auth header, 401 -> markazlashgan
/// logout, timeout xabarlari). method: 'GET' yoki 'POST' (bodysiz).
Future<ApiRes> _circlesReq(String method, String path) async {
  try {
    final uri = Uri.parse('$apiUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      if (Api.token != null) 'Authorization': 'Bearer ${Api.token}',
    };
    const t = Duration(seconds: 20);
    final res = method == 'GET'
        ? await http.get(uri, headers: headers).timeout(t)
        : await http.post(uri, headers: headers, body: jsonEncode(const <String, dynamic>{})).timeout(t);
    final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode >= 400 || map['success'] == false) {
      if (res.statusCode == 401 && Api.token != null) Api.onUnauthorized?.call();
      return ApiRes(false, null, (map['error'] as String?) ?? 'Server xatosi (${res.statusCode})', res.statusCode);
    }
    return ApiRes(true, map['data'], '', res.statusCode);
  } on TimeoutException {
    return ApiRes(false, null, 'Server uyg\'onmoqda — biroz kuting va qayta urinib ko\'ring', 0);
  } catch (_) {
    return ApiRes(false, null, 'Server bilan aloqa yo\'q — internetni tekshiring', 0);
  }
}

/// Foydalanuvchi kiritgan/pastelagan matndan taklif kodini ajratadi.
/// Ulashish matni ("... invite code: a1b2c3...") pastelansa ham ishlaydi:
/// eng uzun 12..64 belgili hex ketma-ketligi olinadi (join_token — 18 hex).
String extractInviteCode(String raw) {
  final matches = RegExp(r'[A-Fa-f0-9]{12,64}').allMatches(raw).map((m) => m.group(0)!).toList();
  if (matches.isEmpty) return '';
  matches.sort((a, b) => b.length.compareTo(a.length));
  return matches.first.toLowerCase();
}

/// Avatar rangi (tint) — klient tomonda pozitsiya bo'yicha beriladi.
enum Tint { warm, green, blue, me, more }

enum Freq { monthly, custom }

enum PayoutOrder { inTurn, random, iPick }

/// closed — egasi muddatidan oldin yopgan (dalillar saqlangan, soft-close).
enum CircleStatus { active, complete, closed }

enum RoundStatus { done, current, upcoming }

// Valyuta: backend KOD saqlaydi (USD/UZS...), klient BELGI ko'rsatadi.
const Map<String, String> kCurSymbol = {'USD': '\$', 'UZS': "so'm", 'EUR': '€', 'RUB': '₽', 'GBP': '£', 'KZT': '₸'};
const Map<String, String> kCurCode = {'\$': 'USD', "so'm": 'UZS', '€': 'EUR', '₽': 'RUB', '£': 'GBP', '₸': 'KZT'};
String curSymbol(String code) => kCurSymbol[code] ?? code;
String curCode(String symbol) => kCurCode[symbol] ?? symbol;

String _initials(String n) {
  final parts = n.split(' ').where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.first.toLowerCase() == 'you') return 'You';
  return parts.map((w) => w[0]).take(2).join().toUpperCase();
}

Tint _tintFor(int idx, bool isYou) {
  if (isYou) return Tint.me;
  const cyc = [Tint.warm, Tint.green, Tint.blue];
  return cyc[idx % cyc.length];
}

class CircleMember {
  final String id;
  final String name;
  final String initials;
  final Tint tint;
  final int payoutPosition;
  final bool isYou;
  final bool isAdmin;
  final bool onApp;
  final String status; // active | invited | declined
  const CircleMember({
    required this.id,
    required this.name,
    required this.initials,
    required this.tint,
    required this.payoutPosition,
    this.isYou = false,
    this.isAdmin = false,
    this.onApp = false,
    this.status = 'active',
  });
}

class CircleRound {
  final int index;
  final String recipientId;
  final String dueDate;
  final RoundStatus status;
  final bool receiptConfirmed;
  final Set<String> paidIds;
  const CircleRound({
    required this.index,
    required this.recipientId,
    required this.dueDate,
    required this.status,
    this.receiptConfirmed = false,
    this.paidIds = const {},
  });

  static RoundStatus _st(String? s) =>
      s == 'done' ? RoundStatus.done : (s == 'current' ? RoundStatus.current : RoundStatus.upcoming);

  factory CircleRound.fromJson(Map<String, dynamic> j) => CircleRound(
        index: (j['idx'] as num).toInt(),
        recipientId: '${j['recipient_id']}',
        dueDate: (j['due_date'] as String?) ?? '',
        status: _st(j['status'] as String?),
        receiptConfirmed: j['receipt_confirmed'] == true,
        paidIds: ((j['paid_ids'] as List?) ?? const []).map((e) => '$e').toSet(),
      );
}

class Circle {
  final String id;
  final String name;
  final int amount;
  final String currency; // BELGI ('$', "so'm"...)
  final Freq frequency;
  final PayoutOrder payoutOrder;
  final CircleStatus status;
  final List<CircleMember> members;
  final List<CircleRound> rounds;
  final int currentRoundIndex; // 0-based
  final String period;
  final bool isOwner;
  final String? joinToken;
  final String? myStatus; // active | invited | null

  const Circle({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.payoutOrder,
    required this.status,
    required this.members,
    required this.rounds,
    required this.currentRoundIndex,
    this.period = '',
    this.isOwner = false,
    this.joinToken,
    this.myStatus,
  });

  factory Circle.fromJson(Map<String, dynamic> j) {
    final rawMembers = ((j['members'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final members = <CircleMember>[];
    for (var i = 0; i < rawMembers.length; i++) {
      final m = rawMembers[i];
      final isYou = m['is_you'] == true;
      members.add(CircleMember(
        id: '${m['id']}',
        name: (m['name'] as String?) ?? '',
        initials: _initials((m['name'] as String?) ?? ''),
        tint: _tintFor(i, isYou),
        payoutPosition: (m['payout_position'] as num?)?.toInt() ?? (i + 1),
        isYou: isYou,
        isAdmin: m['is_admin'] == true,
        onApp: m['on_app'] == true,
        status: (m['status'] as String?) ?? 'active',
      ));
    }
    final rounds = ((j['rounds'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(CircleRound.fromJson)
        .toList();
    final cur = (j['current_round'] as num?)?.toInt() ?? 1;
    return Circle(
      id: '${j['id']}',
      name: (j['name'] as String?) ?? '',
      amount: (j['amount'] as num?)?.toInt() ?? 0,
      currency: curSymbol((j['currency'] as String?) ?? 'UZS'),
      frequency: j['frequency'] == 'custom' ? Freq.custom : Freq.monthly,
      payoutOrder: switch (j['payout_order']) {
        'random' => PayoutOrder.random,
        'iPick' => PayoutOrder.iPick,
        _ => PayoutOrder.inTurn,
      },
      status: switch (j['status']) {
        'complete' => CircleStatus.complete,
        'closed' => CircleStatus.closed,
        _ => CircleStatus.active,
      },
      members: members,
      rounds: rounds,
      currentRoundIndex: cur - 1,
      period: (j['period'] as String?) ?? '',
      isOwner: j['is_owner'] == true,
      joinToken: j['join_token'] as String?,
      myStatus: j['my_status'] as String?,
    );
  }

  // ---- Hosilaviy ----
  int get pool => amount * members.length;
  int get totalPooled => pool * rounds.length;
  int get roundsTotal => rounds.length;
  int get doneRounds => rounds.where((r) => r.status == RoundStatus.done).length;

  /// Round'i yopilgan (pulini olgan) a'zolar id'lari — closed/complete ko'rinishlar uchun.
  Set<String> get receivedIds =>
      rounds.where((r) => r.status == RoundStatus.done).map((r) => r.recipientId).toSet();

  CircleMember? memberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  CircleMember? get you {
    for (final m in members) {
      if (m.isYou) return m;
    }
    return null;
  }

  CircleRound get currentRound =>
      rounds.isEmpty ? const CircleRound(index: 1, recipientId: '', dueDate: '', status: RoundStatus.current)
                     : rounds[currentRoundIndex.clamp(0, rounds.length - 1)];

  CircleMember? get currentRecipient => memberById(currentRound.recipientId);

  bool get isMyTurn => status == CircleStatus.active && currentRound.recipientId == (you?.id ?? '_');

  int get paidCount => currentRound.paidIds.length;

  bool paid(String memberId) => currentRound.paidIds.contains(memberId);

  /// Men (to'lovchi sifatida) joriy round uchun to'laganmanmi.
  bool get youPaid => paid(you?.id ?? '_');

  /// Joriy round'da hali to'lamaganlar (oluvchi va rad etganlar hisobga olinmaydi).
  int get unpaidCount => members
      .where((m) =>
          m.id != currentRound.recipientId &&
          m.status != 'declined' &&
          !currentRound.paidIds.contains(m.id))
      .length;
}

/// Tarmoqli repozitoriy (mock YO'Q). Ma'lumot serverdan yuklanadi va keshda saqlanadi.
/// UI keshni sinxron o'qiydi; store.loadCircles() yuklaydi va rebuild qiladi.
class CirclesRepo {
  final List<Circle> _circles = [];
  bool loading = false;
  bool loaded = false;
  String? error;
  int errorStatus = 0; // oxirgi xato HTTP kodi (402 = obuna tugagan — UI lokalizatsiyalangan xabar beradi)

  List<Circle> all() => _circles;
  List<Circle> active() => _circles.where((c) => c.status == CircleStatus.active).toList();

  Circle? byId(String? id) {
    for (final c in _circles) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Faol circle'lar oylik jamg'armasi (asosiy valyuta belgisi bilan — aralash bo'lsa birinchisiniki).
  int get monthlySaving => active().fold(0, (s, c) => s + c.amount);
  String get savingSymbol => active().isNotEmpty ? active().first.currency : '\$';

  void _setAll(List list) {
    _circles
      ..clear()
      ..addAll(list.cast<Map<String, dynamic>>().map(Circle.fromJson));
  }

  void _upsert(dynamic data) {
    if (data is Map && data['id'] != null) {
      final c = Circle.fromJson(Map<String, dynamic>.from(data));
      final i = _circles.indexWhere((x) => x.id == c.id);
      if (i >= 0) {
        _circles[i] = c;
      } else {
        _circles.insert(0, c);
      }
    }
  }

  /// Serverdan yuklash (store.loadCircles orqali chaqiriladi; set() store tomonida).
  Future<void> load() async {
    final r = await Api.circles();
    if (r.ok && r.data is List) {
      _setAll(r.data as List);
      loaded = true;
      error = null;
    } else {
      error = r.error;
      errorStatus = r.status;
    }
  }

  Future<bool> _mutate(Future<ApiRes> Function() call) async {
    final r = await call();
    if (r.ok) {
      _upsert(r.data);
      return true;
    }
    error = r.error;
    errorStatus = r.status;
    return false;
  }

  Future<bool> markPaid(String id) => _mutate(() => Api.circlePay(id));
  Future<bool> confirmReceipt(String id) => _mutate(() => Api.circleConfirm(id));
  Future<bool> join(String id) => _mutate(() => Api.circleAccept(id));
  Future<bool> invite(String id, List<Map<String, dynamic>> members) => _mutate(() => Api.circleInvite(id, members));
  Future<bool> rename(String id, String name) => _mutate(() => Api.circlePatch(id, name: name));

  Future<Circle?> createCircle(Map<String, dynamic> body) async {
    final r = await Api.createCircle(body);
    if (r.ok) {
      _upsert(r.data);
      return byId('${(r.data as Map)['id']}');
    }
    error = r.error;
    errorStatus = r.status;
    return null;
  }

  Future<bool> declineInvite(String id) async {
    final r = await Api.circleDecline(id);
    if (r.ok) _circles.removeWhere((c) => c.id == id);
    else { error = r.error; errorStatus = r.status; }
    return r.ok;
  }

  /// Yopish: server dalilli doirani SOFT-close qiladi (circle JSON qaytadi) —
  /// keshda 'closed' bo'lib qoladi; dalilsiz doira o'chiriladi ({ok:true}).
  Future<bool> closeCircle(String id) async {
    final r = await Api.circleClose(id);
    if (r.ok) {
      if (r.data is Map && (r.data as Map)['id'] != null) {
        _upsert(r.data);
      } else {
        _circles.removeWhere((c) => c.id == id);
      }
    } else {
      error = r.error;
      errorStatus = r.status;
    }
    return r.ok;
  }

  /// To'lamaganlarga eslatma (server: faqat joriy oluvchi yoki egasi).
  /// Muvaffaqiyatda nechta a'zoga yuborilgani qaytadi, aks holda null (error to'ladi).
  Future<int?> remindUnpaid(String id) async {
    final r = await _circlesReq('POST', '/api/circles/$id/remind');
    if (r.ok) return ((r.data as Map?)?['reminded'] as num?)?.toInt() ?? 0;
    error = r.error;
    errorStatus = r.status;
    return null;
  }

  /// Taklif kodi PREVIEW (GET /api/circles/join/:token) — doira nomi, a'zolar
  /// soni, badal va h.k. XOM ApiRes qaytadi: UI status kodga qarab (404 —
  /// noto'g'ri kod) lokalizatsiyalangan xabar ko'rsatadi.
  Future<ApiRes> joinPreview(String token) =>
      _circlesReq('GET', '/api/circles/join/${Uri.encodeComponent(token)}');

  /// Kod orqali qo'shilish (POST /api/circles/join/:token). Muvaffaqiyatda
  /// doira keshga upsert qilinadi (data — to'liq circle JSON). XOM ApiRes:
  /// 404 — noto'g'ri kod, 400 — to'lgan/yakunlangan, 402 — obuna tugagan.
  Future<ApiRes> joinByToken(String token) async {
    final r = await _circlesReq('POST', '/api/circles/join/${Uri.encodeComponent(token)}');
    if (r.ok) {
      _upsert(r.data);
      loaded = true; // birinchi doira kod orqali kelgan bo'lishi mumkin
      error = null;
    }
    return r;
  }
}

final CirclesRepo circlesRepo = CirclesRepo();

/// Minglik ajratgichli summa + valyuta belgisi. money(2000,"so'm") -> "2,000 so'm".
String money(int n, [String cur = '\$']) {
  final f = n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return cur.length <= 1 ? '$cur$f' : '$f $cur';
}

String usd(int n) => money(n, '\$');

String firstName(String full) {
  final parts = full.split(' ').where((w) => w.isNotEmpty);
  return parts.isEmpty ? full : parts.first;
}

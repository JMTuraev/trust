// Xarajatlar — papka (folder) UI, dizayn "Xarajatlar Trust.html" bilan 1:1.
// TO'LIQ EKRAN: bottom navsiz, header'da orqaga. Matn-birinchi: input -> AI -> papka.
// Dinamika (dizayn kabi): input ichida rangli belgilash (summa yashil/qizil, toifa/buyruq/sana
// fonli), yozuv papkaga "uchadi" (fly chip + papka pulsi), sparkline jonli (oxirgi 8 yozuv,
// yangisida siljiydi), yangi papka "pop", tray "shake", toastlar "Bekor qilish" bilan.
import 'dart:async' show Timer;
import 'dart:convert' show jsonDecode, utf8;
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter, TextEditingValue;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../api.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

// RANG QOIDASI (dizayn: Xarajatlar Trust / Trust_STT-off — redC/greenC):
// summa raqamlari HAR DOIM brend rangda — chiqim = p.red, kirim = p.green.
// Hech qayerda p.ink yoki Colors.red/green ishlatilmaydi (rang bugi tuzatildi).

class XarajatScreen extends StatefulWidget {
  const XarajatScreen({super.key});

  @override
  State<XarajatScreen> createState() => _XarajatScreenState();
}

class _XarajatScreenState extends State<XarajatScreen> with TickerProviderStateMixin {
  // Papka kartalari pozitsiyasi (fly nishoni) va pulslash hisoblagichi
  final Map<String, GlobalKey> _fk = {};
  final GlobalKey _inputKey = GlobalKey();
  final Map<String, int> _pulse = {};

  // ---- Papka tahriri (rename/arxiv) va yozuvni ko'chirish holati ----
  // Ekran-lokal holat: store'ga tegilmaydi (store faqat public API orqali yangilanadi)
  Map<String, dynamic>? _fEdit; // {name, inc, renaming: bool}
  Map<String, dynamic>? _mv; // {id, desc, amtTxt, a, cat}
  List<Map<String, dynamic>>? _cats; // server toifalari (?all=1: id/name/is_base/archived)
  bool _fBusy = false; // server so'rovi ketmoqda (ikkilangan bosishdan himoya)
  String _fName = ''; // rename buferi

  GlobalKey _keyFor(String name) => _fk.putIfAbsent(name, () => GlobalKey());

  // Rename maydoni — barqaror controller (poll-rebuild matnni o'chirmasin)
  final TextEditingController _fCtl = TextEditingController();

  @override
  void dispose() {
    _fCtl.dispose();
    super.dispose();
  }

  // ---- l10n zaxira: kalit hali qo'shilmagan bo'lsa o'zbekcha matn ----
  String _t(String key, String fb) => (store.L()[key] as String?) ?? fb;
  String _tf(String key, Map<String, String> vars, String fb) {
    var s = (store.L()[key] as String?) ?? fb;
    vars.forEach((k, val) => s = s.replaceAll('{$k}', val));
    return s;
  }

  // 1234567 -> "1 234 567" (store._fx bilan bir xil format)
  static String _fx(num v) {
    final s = v.abs().round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String _norm(String s) => s.toLowerCase()
      .replaceAll('’', "'").replaceAll('ʻ', "'").replaceAll('`', "'").replaceAll('ʼ', "'");

  // Sessiya jurnaliga yozish — store._xfLogAdd shakli bilan 1:1 (public set orqali)
  void _log(String type,
      {required String cat, required String desc, required int amount, required bool income, String? eid}) {
    final log = List<Map<String, dynamic>>.from(store.S['xfLog'] as List);
    final now = DateTime.now();
    log.insert(0, {
      'id': 'l${now.microsecondsSinceEpoch}', 'type': type,
      'cat': cat, 'desc': desc, 'a': amount, 'income': income, 'eid': eid,
      't': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    });
    store.set({'xfLog': log.take(12).toList(), if (store.S['xfLogOpen'] != true) 'xfLogDot': true});
  }

  // Toifalar ro'yxati (?all=1 — arxivlangan holati bilan). Eski backend all'ni
  // bilmasa ham xuddi shu shakldagi faol ro'yxat qaytadi — UI buzilmaydi.
  Future<List<Map<String, dynamic>>?> _loadCats({bool all = true}) async {
    try {
      final res = await http.get(
        Uri.parse('$apiUrl/api/categories${all ? '?all=1' : ''}'),
        headers: {
          'Content-Type': 'application/json',
          if (Api.token != null) 'Authorization': 'Bearer ${Api.token}',
        },
      ).timeout(const Duration(seconds: 12));
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 400 || map['success'] == false) return null;
      return ((map['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return null; // oflayn — karta ichida xabar ko'rsatiladi
    }
  }

  Map<String, dynamic>? _catByName(String name) {
    for (final c in _cats ?? const <Map<String, dynamic>>[]) {
      if (_norm('${c['name']}') == _norm(name)) return c;
    }
    return null;
  }

  // ---- PAPKA TAHRIRI: uzoq bosishdan ochiladi ----
  void _openFolderEdit(Map<String, dynamic> f) {
    if (f['inc'] == true) {
      // Kirim papkasi ('Daromad') — server uni o'zi boshqaradi, qo'lda tahrir yo'q
      store.toast_(_t('tIncomeFolderFixed', "Kirim papkasi tizim tomonidan boshqariladi"));
      return;
    }
    setState(() {
      _mv = null;
      _fEdit = {'name': f['name'], 'inc': f['inc'] == true, 'renaming': false};
      _fName = '${f['name']}';
      _cats = null;
    });
    _loadCats().then((cs) {
      if (mounted && _fEdit != null) setState(() => _cats = cs ?? []);
    });
  }

  Future<void> _renameFolder(String oldName) async {
    final newName = _fName.trim();
    if (newName.length < 2) {
      store.toast_(store.L()['tNameMin2'] as String);
      return;
    }
    if (newName == oldName) {
      setState(() => _fEdit = null);
      return;
    }
    final cat = _catByName(oldName);
    if (cat == null || _fBusy) {
      if (cat == null) store.toast_(_t('tFolderNoCat', 'Papka toifasi serverda topilmadi'));
      return;
    }
    setState(() => _fBusy = true);
    final r = await Api.patchCategory('${cat['id']}', name: newName);
    if (!mounted) return;
    setState(() => _fBusy = false);
    if (!r.ok) {
      store.toast_(r.error);
      return;
    }
    final saved = ((r.data as Map?)?['name'] as String?) ?? newName;
    // Lokal holat: yozuvlar toifasi, "Yangi" belgisi, ochiq tafsilot nomi — hammasi ko'chadi
    final entries = (store.S['xarEntries'] as List).cast<Map<String, dynamic>>()
        .map((e) => '${e['cat']}' == oldName ? {...e, 'cat': saved} : e).toList();
    final newCats = (store.S['xfNewCats'] as List).cast<String>()
        .map((c) => c == oldName ? saved : c).toList();
    var total = 0;
    for (final e in entries) {
      if ('${e['cat']}' == saved && e['kind'] == 'x') total += e['a'] as int;
    }
    store.set({
      'xarEntries': entries,
      'xfNewCats': newCats,
      'xcCats': <String>[], // tahrir chiplari keyingi ochilishda qayta yuklanadi
      if (store.S['xfDetail'] == oldName) 'xfDetail': saved,
    });
    _log('edit', cat: saved, desc: '$oldName → $saved', amount: total, income: false);
    store.toast_(_t('tFolderRenamed', 'Papka nomi yangilandi — yozuvlar birga ko\'chdi'));
    setState(() => _fEdit = null);
    store.hydrate(full: false); // server haqiqati bilan sinxron
  }

  Future<void> _archiveFolder(String name, bool archive) async {
    final cat = _catByName(name);
    if (cat == null || _fBusy) {
      if (cat == null) store.toast_(_t('tFolderNoCat', 'Papka toifasi serverda topilmadi'));
      return;
    }
    setState(() => _fBusy = true);
    final r = await Api.patchCategory('${cat['id']}', archived: archive);
    if (!mounted) return;
    setState(() => _fBusy = false);
    if (!r.ok) {
      store.toast_(r.error);
      return;
    }
    store.set({'xcCats': <String>[]});
    _log('edit', cat: name, desc: archive
        ? '$name — ${_t('logArchived', 'arxivga')}'
        : '$name — ${_t('logUnarchived', 'arxivdan')}', amount: 0, income: false);
    store.toast_(archive
        ? _t('tFolderArchived', "Arxivlandi — AI endi bu papkani taklif qilmaydi, tarix saqlanadi")
        : _t('tFolderUnarchived', 'Arxivdan qaytarildi — papka yana taklif qilinadi'));
    setState(() => _fEdit = null);
  }

  // ---- YOZUVNI KO'CHIRISH: tafsilot qatori bosilganda ----
  void _openMove(Map<String, dynamic> r, String folderName) {
    // Qator id'si store'dan kelsa — bevosita; kelmasa oy yozuvlari ichidan
    // desc+vaqt+summa bo'yicha topamiz (bir xil egizaklarda natija farqsiz)
    var id = r['id'] as String?;
    var amount = r['a'] as int?;
    if (id == null) {
      final now = DateTime.now();
      final ym = '${now.year}-${now.month}';
      for (final e in (store.S['xarEntries'] as List).cast<Map<String, dynamic>>()) {
        if ('${e['ym']}' != ym || '${e['cat']}' != folderName || e['kind'] == 'd') continue;
        final amtTxt = '−${_fx(e['a'] as int)}';
        final desc = (e['note'] as String?)?.isNotEmpty == true ? e['note'] : e['cat'];
        if (amtTxt == '${r['amtTxt']}' && '${e['t']}' == '${r['time']}' && '$desc' == '${r['desc']}') {
          id = e['id'] as String?;
          amount = e['a'] as int?;
          break;
        }
      }
    }
    if (id == null) {
      store.toast_(_t('tEntryNotFound', 'Yozuv topilmadi — yangilab qayta urinib ko\'ring'));
      return;
    }
    setState(() {
      _fEdit = null;
      _mv = {'id': id, 'desc': r['desc'], 'amtTxt': r['amtTxt'], 'a': amount ?? 0, 'cat': folderName};
      _cats = null;
    });
    _loadCats().then((cs) {
      if (mounted && _mv != null) setState(() => _cats = cs ?? []);
    });
  }

  Future<void> _moveTo(String cat) async {
    final mv = _mv;
    if (mv == null || _fBusy) return;
    setState(() => _fBusy = true);
    final r = await Api.patchExpense('${mv['id']}', category: cat);
    if (!mounted) return;
    setState(() => _fBusy = false);
    if (!r.ok) {
      store.toast_(r.error);
      return;
    }
    // Server yakuniy toifani qaytaradi (ro'yxatda bo'lmasa 'Boshqa'ga tushadi)
    final srvCat = ((r.data as Map?)?['category'] as String?) ?? cat;
    final entries = (store.S['xarEntries'] as List).cast<Map<String, dynamic>>()
        .map((e) => e['id'] == mv['id'] ? {...e, 'cat': srvCat} : e).toList();
    store.set({'xarEntries': entries});
    _log('edit', cat: srvCat, desc: '${mv['desc']}', amount: mv['a'] as int? ?? 0,
        income: false, eid: '${mv['id']}');
    store.toast_(_tf('tMovedTo', {'cat': srvCat}, 'Ko\'chirildi: $srvCat'));
    setState(() {
      _mv = null;
      _pulse[srvCat] = (_pulse[srvCat] ?? 0) + 1; // nishon papka "yutish" pulsi
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();

    // Fly hodisalarini iste'mol qilamiz — kadr chizilgach uchiramiz (pozitsiyalar tayyor)
    final flyEvents = (v['xfFlyEvents'] as List).cast<Map<String, dynamic>>();
    if (flyEvents.isNotEmpty) {
      final events = List<Map<String, dynamic>>.from(flyEvents);
      (v['xfFlyDone'] as Function)();
      WidgetsBinding.instance.addPostFrameCallback((_) => _launchFly(events));
    }

    return Stack(
      children: [
        // ------- Asosiy sahifa -------
        Column(
          children: [
            _header(v, p),
            _balance(v, p),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 210),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (v['xfEmptyAll'] == true) _emptyAll(p),
                    // BITTA uzluksiz grid: kirim papkalari BOSHIDA, keyin chiqim
                    // (foydalanuvchi so'rovi: alohida bo'limlarga ajratilmaydi)
                    if ((v['xfInFolders'] as List).isNotEmpty ||
                        (v['xfOutFolders'] as List).isNotEmpty) ...[
                      _cap(store.L()['capFolders'] as String, p),
                      const SizedBox(height: 10),
                      _grid([
                        ...(v['xfInFolders'] as List).cast<Map<String, dynamic>>(),
                        ...(v['xfOutFolders'] as List).cast<Map<String, dynamic>>(),
                      ], p),
                      const SizedBox(height: 18),
                    ],
                    if (v['xfShowTray'] == true) _tray(v, p),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ------- Papka tafsiloti (to'liq ekran) -------
        if (v['xfDetailOpen'] == true) Positioned.fill(child: _detail(v, p)),

        // ------- Oxirgi o'zgarishlar (jurnal) -------
        if (v['xfLogOpen'] == true) Positioned.fill(child: _logPanel(v, p)),

        // ------- Pastki qatlam -------
        Positioned(left: 0, right: 0, bottom: 0, child: _bottomOverlay(v, p)),
      ],
    );
  }

  // ================= FLY ANIMATSIYASI (dizayn: flyToFolder) =================
  // QAT'IY KETMA-KET xoreografiya: chip uchadi -> qo'nadi -> yozuv kiritiladi
  // (papka + balans raqamlari SANAB ko'tariladi) -> sanash tugagach KEYINGI chip.
  // Bir inputdagi 2-3 summa "kapalakday" birdan uchmaydi — birma-bir.
  Future<void> _launchFly(List<Map<String, dynamic>> events) async {
    // Klaviatura odatda SEND bosilganda yopilgan (store.xfSend_) — bu zaxira;
    // parse davomida (~1-2s) layout kengayib ulgurgan, qisqa pauza yetadi
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    for (var i = 0; i < events.length; i++) {
      final cat = events[i]['cat'] as String;
      final ctx = _fk[cat]?.currentContext;
      if (ctx != null) {
        // Nishon papkani ko'rinadigan joyga silliq keltiramiz
        await Scrollable.ensureVisible(ctx,
            alignment: 0.35, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
        await Future.delayed(const Duration(milliseconds: 60));
      }
      if (!mounted) return;
      await _flyOne(events[i], i); // chip qo'nguncha kutamiz
      // Qo'nish: yozuv kiritiladi -> papka summasi va balans sanay boshlaydi + puls
      (events[i]['land'] as Function?)?.call();
      if (mounted) {
        setState(() => _pulse[cat] = (_pulse[cat] ?? 0) + 1);
      }
      // Raqam sanashi (900ms) tugagach keyingi operatsiya "kapalagi" jonlanadi
      await Future.delayed(const Duration(milliseconds: 950));
    }
  }

  Future<void> _flyOne(Map<String, dynamic> e, int i) async {
    final p = curPal();
    final overlay = Overlay.of(context);
    final inputBox = _inputKey.currentContext?.findRenderObject() as RenderBox?;
    final folderBox = _fk[e['cat']]?.currentContext?.findRenderObject() as RenderBox?;
    if (inputBox == null) return;
    final start = inputBox.localToGlobal(const Offset(20, -46));
    // Nishon: papka kartasi markazi. Yangi toifada ham karta bor (ghost) — store
    // uni uchishdan OLDIN chiqaradi; baribir topilmasa yuqoriga uchib so'nadi.
    final end = folderBox != null
        ? folderBox.localToGlobal(Offset.zero) +
            Offset(folderBox.size.width / 2 - 56, folderBox.size.height / 2 - 16)
        : start - const Offset(0, 220);

    // Kvadratik Bezier "swoop": nazorat nuqtasi yon+yuqoriga surilgan — chip
    // to'g'ri chiziqda emas, burilib uchadi (zamonaviy his)
    final side = end.dx >= start.dx ? 1.0 : -1.0;
    final ctl = Offset(
      (start.dx + end.dx) / 2 + side * 90,
      math.min(start.dy, end.dy) - 110,
    );
    Offset bezier(double t) {
      final u = 1 - t;
      return start * (u * u) + ctl * (2 * u * t) + end * (t * t);
    }

    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 820));
    // M3 emphasized easing — shiddat bilan ko'tarilib, nishonga yumshoq qo'nadi
    final curve = CurvedAnimation(parent: ctrl, curve: Curves.easeInOutCubicEmphasized);
    final inc = e['inc'] == true;
    final glow = inc ? p.green : p.red;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: curve,
        builder: (_, __) {
          final t = curve.value;
          final pos = bezier(t);
          // Harakat yo'nalishi bo'yicha engil QIYALIK (banking) — uchayotgan his
          final dv = bezier(math.min(1.0, t + .02)) - pos;
          final ang = dv.distance == 0 ? 0.0 : (dv.dx / dv.distance) * .22;
          // Nafas oluvchi glow — parvoz cho'qqisida eng yorqin
          final breathe = math.sin(t * math.pi);
          final op = t < .06 ? t / .06 : (t > .9 ? (1 - t) / .1 : 1.0);
          // Ko'tarilishda KATTALASHADI (1.18x), so'ng kichrayib papkaga "singib ketadi"
          final sc = t < .35
              ? lerpDouble(.7, 1.18, Curves.easeOutCubic.transform(t / .35))!
              : lerpDouble(1.18, .3, Curves.easeInCubic.transform((t - .35) / .65))!;
          // Zarracha izi — chip markazi ortida so'nib boruvchi glow nuqtalari
          final trail = <List<double>>[];
          for (var k = 1; k <= 6; k++) {
            final tp = t - k * .05;
            if (tp <= 0) break;
            final dp = bezier(tp) + const Offset(56, 16); // chip markaziga moslash
            trail.add([dp.dx, dp.dy, (1 - k / 7) * .45 * op.clamp(0.0, 1.0), 4.2 - k * .5]);
          }
          return Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _TrailPaint(trail, glow))),
                  Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    child: Opacity(
                      opacity: op.clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: ang,
                        child: Transform.scale(
                          scale: sc,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                            decoration: BoxDecoration(
                              color: p.card2,
                              border: Border.all(color: p.bd2),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 32, offset: const Offset(0, 14)),
                                // Parvoz cho'qqisida glow kuchayadi, qo'nishga so'nadi
                                BoxShadow(
                                  color: glow.withValues(alpha: (inc ? .42 : .30) * breathe + .10),
                                  blurRadius: 22 + 12 * breathe,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tx('${e['emoji']} ${e['cat']}', size: 13, w: FontWeight.w500, color: p.ink),
                                const SizedBox(width: 8),
                                Tx('${e['amtTxt']}', size: 13, w: FontWeight.w600, color: inc ? p.green : p.red),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    overlay.insert(entry);
    await ctrl.forward(); // qo'nguncha kutamiz — puls va sanash caller'da
    entry.remove();
    ctrl.dispose();
  }

  // ================= SARLAVHA (dizayn: back + title + jurnal) =================
  Widget _header(Map<String, dynamic> v, Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
      child: Row(
        children: [
          Tap(
            onTap: v['xfBack'],
            child: SizedBox(width: 34, height: 34, child: Center(child: BackChevron(color: p.ink))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(store.L()['xarTitle'] as String, size: 17, w: FontWeight.w700, color: p.ink, ls: -0.2),
                const SizedBox(height: 1),
                Tx('${v['xfMonth']}', size: 11.5, color: p.t3),
              ],
            ),
          ),
          // Jurnal tugmasi (soat + yangilik nuqtasi)
          Tap(
            onTap: v['xfLogToggle'],
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd)),
              child: Stack(
                children: [
                  Center(child: Icon(Icons.history, size: 18, color: p.ink)),
                  if (v['xfLogDot'] == true)
                    Positioned(
                      top: 4, right: 4,
                      child: Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: p.green,
                          border: Border.all(color: p.bg, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= OY BALANSI =================
  Widget _balance(Map<String, dynamic> v, Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tx('${v['xfBalCap']}', size: 11, w: FontWeight.w600, color: p.t2, ls: 1.6),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _AnimNum(
                value: v['xfBalVal'] as int? ?? 0,
                prefix: v['xfBalPos'] == true ? '+' : '−',
                size: 30, weight: FontWeight.w700,
                color: v['xfBalPos'] == true ? p.green : p.red, ls: -0.6,
              ),
              const SizedBox(width: 7),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Tx(store.L()['som'] as String, size: 13, color: p.t3),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Tx(store.L()['income'] as String, size: 12, color: p.t2),
              _AnimNum(value: v['xfInVal'] as int? ?? 0, prefix: '+',
                  size: 12, weight: FontWeight.w600, color: p.green),
              const SizedBox(width: 18),
              Tx(store.L()['expense'] as String, size: 12, color: p.t2),
              _AnimNum(value: v['xfOutVal'] as int? ?? 0, prefix: '−',
                  size: 12, weight: FontWeight.w600, color: p.red),
            ],
          ),
        ],
      ),
    );
  }

  // ================= PAPKALAR =================
  Widget _cap(String t, Pal p) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Tx(t, size: 11, w: FontWeight.w600, color: p.t2, ls: 1.6),
      );

  Widget _grid(List<Map<String, dynamic>> fs, Pal p) {
    final rows = <Widget>[];
    for (var i = 0; i < fs.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _folderCard(fs[i], p)),
          const SizedBox(width: 10),
          Expanded(child: i + 1 < fs.length ? _folderCard(fs[i + 1], p) : const SizedBox()),
        ],
      ));
      if (i + 2 < fs.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _folderCard(Map<String, dynamic> f, Pal p) {
    final inc = f['inc'] == true;
    final accent = inc ? p.green : p.red;
    final name = '${f['name']}';
    // Ghost: chip hali uchmoqda — karta nishon sifatida xira turadi, summa o'rnida "···"
    final ghost = f['ghost'] == true;

    // Uzoq bosish — papkani TAHRIRLASH (nomlash/arxivlash, XOTIRA §4 CRUD).
    // Ghost karta hali serverda yo'q; kirim papkasi ('Daromad') tizim boshqaruvida.
    Widget card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: f['open'] as VoidCallback?,
      onLongPress: ghost ? null : () => _openFolderEdit(f),
      child: Container(
        key: _keyFor(name),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: inc ? Color.alphaBlend(p.green.withValues(alpha: .05), p.hov2) : p.hov2,
          border: Border.all(color: p.hair2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Mazmunga mos KATTA fon-glif — kartaning o'ng qismida, suv belgisi kabi
            Positioned(
              right: -18, top: -8,
              child: Transform.rotate(
                angle: -0.18,
                child: CatIcon(cat: name, size: 92, color: accent.withValues(alpha: .09)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Vektor ikonka-chip (emoji o'rniga)
                      Container(
                        width: 31, height: 31, alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: CatIcon(cat: name, size: 17.5, color: accent),
                      ),
                      if (f['isNew'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: p.card2,
                            border: Border.all(color: p.bd2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Tx(store.L()['newBadge'] as String, size: 10, w: FontWeight.w600, color: p.t1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Tx(name, size: 12.5, w: FontWeight.w500, color: p.t2, maxLines: 1),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Flexible(
                        child: ghost
                            ? Tx('· · ·', size: 15, w: FontWeight.w600, color: p.t4)
                            : _AnimNum(
                                value: f['totalVal'] as int? ?? 0,
                                prefix: inc ? '+' : '−',
                                size: 15, weight: FontWeight.w600,
                                color: inc ? p.green : p.red,
                                fromZero: true, // yangi papka 0 dan sanab chiqadi
                              ),
                      ),
                      if (inc) ...[
                        const SizedBox(width: 5),
                        Container(
                          width: 14, height: 14, alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.green.withValues(alpha: .18),
                          ),
                          child: Tx('↑', size: 9, color: p.green),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity, height: 22,
                    child: _AnimSpark(
                      pts: (f['spark'] as List).cast<double>(),
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Ghost — xira nishon (chip qo'nganda AnimatedOpacity bilan to'liq yonadi)
    card = AnimatedOpacity(
      opacity: ghost ? .5 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: card,
    );

    // Yangi papka "pop" (dizayn: xkPop scale-bounce)
    if (f['isNew'] == true) {
      card = TweenAnimationBuilder<double>(
        key: ValueKey('pop-$name'),
        tween: Tween(begin: 0.82, end: 1.0),
        duration: const Duration(milliseconds: 550),
        curve: Curves.elasticOut,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: card,
      );
    }

    // Fly qo'nganda "YUTISH" squash-stretch: karta eniga cho'zilib, bo'yiga
    // bosiladi, so'ng prujinali (elasticOut) holiga qaytadi — chip singib ketgan his
    final pc = _pulse[name] ?? 0;
    if (pc > 0) {
      card = TweenAnimationBuilder<double>(
        key: ValueKey('pulse-$name-$pc'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 560),
        curve: Curves.elasticOut,
        builder: (_, t, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(
            lerpDouble(1.12, 1.0, t)!, // eni: cho'zilgan -> normal (overshoot bilan)
            lerpDouble(0.86, 1.0, t)!, // bo'yi: bosilgan -> normal
            1,
          ),
          child: child,
        ),
        child: card,
      );
    }
    return card;
  }

  Widget _emptyAll(Pal p) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 30),
      decoration: BoxDecoration(
        color: p.hov2,
        border: Border.all(color: p.hair2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Tx(store.L()['xarEmptyTitle'] as String, size: 14, w: FontWeight.w600, color: p.t1,
              align: TextAlign.center),
          const SizedBox(height: 6),
          Tx(store.L()['xarEmptySub'] as String, size: 12,
              color: p.t4, align: TextAlign.center),
        ],
      ),
    );
  }

  // ================= ANIQLANMAGAN (tray) =================
  Widget _tray(Map<String, dynamic> v, Pal p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Tx(store.L()['unidentifiedCap'] as String, size: 11, w: FontWeight.w600, color: p.t2, ls: 1.6),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: p.red.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Tx('${v['xfTrayCount']}', size: 10, w: FontWeight.w600, color: p.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final t in (v['xfTrayRows'] as List).cast<Map<String, dynamic>>()) ...[
          _Shake(
            key: ValueKey('shake-${t['id']}'),
            child: Tap(
              onTap: t['toggle'],
              child: _Dashed(
                color: p.red.withValues(alpha: .45),
                radius: 14,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Tx('${t['text']}', size: 13, color: p.t1, maxLines: 1),
                          ),
                          const SizedBox(width: 8),
                          Tx(store.L()['pickFolderRow'] as String, size: 11, color: p.t4),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Tx('${t['amtTxt']} ${store.L()['som'] as String}', size: 13, w: FontWeight.w600, color: p.red),
                      if (t['open'] == true) ...[
                        const SizedBox(height: 10),
                        if (t['naming'] == true)
                          // Qo'lda yangi papka nomi
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: p.card2,
                                    border: Border.all(color: p.bd),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Center(
                                    child: TextField(
                                      autofocus: true,
                                      onChanged: t['nameSet'],
                                      onSubmitted: (_) => (t['nameOk'] as Function)(),
                                      style: GoogleFonts.inter(fontSize: 13, color: p.ink),
                                      cursorColor: p.ink,
                                      decoration: InputDecoration(
                                        isDense: true, isCollapsed: true, border: InputBorder.none,
                                        hintText: store.L()['newFolderHint'] as String,
                                        hintStyle: GoogleFonts.inter(fontSize: 13, color: p.t5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tap(
                                onTap: t['nameOk'],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(999)),
                                  child: Tx(store.L()['btnOk'] as String, size: 12, w: FontWeight.w600, color: p.bg),
                                ),
                              ),
                            ],
                          )
                        else
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: [
                              for (final c in (t['chips'] as List).cast<Map<String, dynamic>>())
                                Tap(
                                  onTap: c['pick'],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                    decoration: BoxDecoration(
                                      // AI taklifi (✨ yangi) — ajralib turadigan urg'u
                                      color: c['isNew'] == true ? p.ink.withValues(alpha: .08) : p.card2,
                                      border: Border.all(color: c['isNew'] == true ? p.ink : p.bd),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Tx('${c['label']}', size: 12,
                                        w: c['isNew'] == true ? FontWeight.w600 : FontWeight.w500, color: p.ink),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ================= PAPKA TAFSILOTI =================
  Widget _detail(Map<String, dynamic> v, Pal p) {
    return Container(
      color: p.bg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 20, 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
            child: Row(
              children: [
                Tap(
                  onTap: v['xfDetailClose'],
                  child: SizedBox(width: 34, height: 34, child: Center(child: BackChevron(color: p.ink))),
                ),
                Container(
                  width: 36, height: 36, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (v['xfDInc'] == true ? p.green : p.red).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CatIcon(cat: '${v['xfDName']}', size: 20,
                      color: v['xfDInc'] == true ? p.green : p.red),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tx('${v['xfDName']}', size: 16, w: FontWeight.w700, color: p.ink, maxLines: 1),
                      const SizedBox(height: 1),
                      Tx('${v['xfDCount']}', size: 11.5, color: p.t3),
                    ],
                  ),
                ),
                SizedBox(
                  width: 60, height: 20,
                  child: _AnimSpark(
                    pts: (v['xfDSpark'] as List).cast<double>(),
                    color: v['xfDInc'] == true ? p.green : p.red,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _AnimNum(
                      value: v['xfDTotalVal'] as int? ?? 0,
                      prefix: v['xfDInc'] == true ? '+' : '−',
                      size: 28, weight: FontWeight.w700,
                      // RANG BUGI TUZATILDI: chiqim jami p.ink emas — brend qizil
                      color: v['xfDInc'] == true ? p.green : p.red, ls: -0.5,
                    ),
                    const SizedBox(width: 7),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Tx(store.L()['som'] as String, size: 13, color: p.t3),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Tx(store.L()['folderDetailHint'] as String, size: 11, color: p.t4),
              ],
            ),
          ),
          Expanded(
            child: v['xfDEmpty'] == true
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                    child: Column(
                      children: [
                        Tx(store.L()['xarEmptyTitle'] as String, size: 14, w: FontWeight.w600, color: p.t1,
                            align: TextAlign.center),
                        const SizedBox(height: 6),
                        Tx(store.L()['folderEmptySub'] as String, size: 12,
                            color: p.t4, align: TextAlign.center),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 210),
                    children: [
                      for (final g in (v['xfDGroups'] as List).cast<Map<String, dynamic>>()) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                          child: Tx('${g['label']}'.toUpperCase(), size: 11, w: FontWeight.w600,
                              color: p.t2, ls: 1.6),
                        ),
                        for (final r in (g['rows'] as List).cast<Map<String, dynamic>>())
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _entryRow(r, '${v['xfDName']}', p),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _entryRow(Map<String, dynamic> r, String folderName, Pal p) {
    return Tap(
      // Qator bosilsa — yozuvni boshqa papkaga KO'CHIRISH kartasi (XOTIRA §4:
      // saqlangan yozuv toifasini qo'lda o'zgartirish). Kirim yozuvlari ko'chmaydi.
      onTap: r['inc'] == true ? null : () => _openMove(r, folderName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.hov2,
          border: Border.all(color: p.hair2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx('${r['desc']}', size: 13.5, w: FontWeight.w500, color: p.ink, maxLines: 1),
                  const SizedBox(height: 2),
                  Tx('${r['time']}', size: 11, color: p.t4),
                ],
              ),
            ),
            Tx('${r['amtTxt']}', size: 13.5, w: FontWeight.w600,
                // RANG BUGI TUZATILDI: chiqim raqamlari brend qizil (p.ink emas)
                color: r['inc'] == true ? p.green : p.red),
            const SizedBox(width: 8),
            _roundBtn('✎', r['edit'], p),
            const SizedBox(width: 6),
            _roundBtn('✕', r['del'], p),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn(String glyph, dynamic onTap, Pal p) {
    return Tap(
      onTap: onTap,
      child: Container(
        width: 28, height: 28, alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.bd)),
        child: Tx(glyph, size: 11, color: p.t2),
      ),
    );
  }

  // ================= JURNAL =================
  Widget _logPanel(Map<String, dynamic> v, Pal p) {
    return Container(
      color: p.bg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 16, 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tx(store.L()['logTitle'] as String, size: 16, w: FontWeight.w700, color: p.ink),
                      const SizedBox(height: 1),
                      Tx(store.L()['logSub'] as String, size: 11.5, color: p.t3),
                    ],
                  ),
                ),
                _roundBtn('✕', v['xfLogToggle'], p),
              ],
            ),
          ),
          Expanded(
            child: v['xfLogEmpty'] == true
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                    child: Column(
                      children: [
                        Tx(store.L()['logEmptyTitle'] as String, size: 14, w: FontWeight.w600, color: p.t1,
                            align: TextAlign.center),
                        const SizedBox(height: 6),
                        Tx(store.L()['logEmptySub'] as String,
                            size: 12, color: p.t4, align: TextAlign.center),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 210),
                    children: [
                      for (final o in (v['xfLogRows'] as List).cast<Map<String, dynamic>>())
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _logRow(o, p),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _logRow(Map<String, dynamic> o, Pal p) {
    final isDel = o['isDel'] == true;
    final type = '${o['type']}';
    final badgeColor = type == 'add' ? p.green : type == 'del' ? p.red : p.t1;
    final badgeBg = type == 'add'
        ? p.green.withValues(alpha: .14)
        : type == 'del' ? p.red.withValues(alpha: .14) : p.card2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.hov2,
        border: Border.all(color: p.hair2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Tx('${o['emoji']}', size: 16, color: p.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${o['desc']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.5, fontWeight: FontWeight.w500,
                          color: isDel ? p.t3 : p.ink,
                          decoration: isDel ? TextDecoration.lineThrough : TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg, borderRadius: BorderRadius.circular(999)),
                      child: Tx('${o['badge']}', size: 9.5, w: FontWeight.w600, color: badgeColor),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Tx('${o['sub']}', size: 11, color: p.t4, maxLines: 1),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${o['amtTxt']}',
            style: GoogleFonts.inter(
              fontSize: 13.5, fontWeight: FontWeight.w600,
              // RANG BUGI TUZATILDI: jurnalda ham chiqim brend qizil (p.ink emas);
              // o'chirilgan qator xira (t3) qoladi — dizayndagi lineThrough holati
              color: isDel ? p.t3 : (o['inc'] == true ? p.green : p.red),
              decoration: isDel ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
          if (o['canAct'] == true) ...[
            const SizedBox(width: 8),
            _roundBtn('✎', o['edit'], p),
            const SizedBox(width: 6),
            _roundBtn('✕', o['delTap'], p),
          ],
        ],
      ),
    );
  }

  // ================= PASTKI QATLAM =================
  Widget _bottomOverlay(Map<String, dynamic> v, Pal p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 60, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [p.bg.withValues(alpha: 0), p.bg.withValues(alpha: .88), p.bg],
          stops: const [0, .46, .82],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (v['xfEditingOpen'] == true) ...[
            _SlideIn(
              key: const ValueKey('editchip'),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 5, 6, 5),
                decoration: BoxDecoration(
                  color: p.card2,
                  border: Border.all(color: p.bd2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tx(store.L()['editingLabel'] as String, size: 12, color: p.t2),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Tx('${v['xfEditLabel']}', size: 12, w: FontWeight.w600,
                          color: p.ink, maxLines: 1),
                    ),
                    const SizedBox(width: 8),
                    Tap(
                      onTap: v['xfEditCancel'],
                      child: Container(
                        width: 22, height: 22, alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: p.hair2),
                        child: Tx('✕', size: 10, color: p.t1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (v['xfToastOpen'] == true) ...[
            _SlideIn(
              key: ValueKey('toast-${v['xfToastText']}'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: p.card2,
                  border: Border.all(color: p.bd2),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .45), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: Row(
                  children: [
                    Expanded(child: Tx('${v['xfToastText']}', size: 13, color: p.ink)),
                    Tap(
                      onTap: v['xfUndo'],
                      child: Text(
                        '${v['xfToastBtn'] ?? (store.L()['btnCancelFull'] as String)}',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600, color: p.ink,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (v['xfCfOpen'] == true) ...[
            _SlideIn(key: const ValueKey('confirm'), child: _confirmCard(v, p)),
            const SizedBox(height: 10),
          ],

          // Papka tahriri (uzoq bosish) — rename / arxivlash kartasi
          if (_fEdit != null) ...[
            _SlideIn(key: ValueKey('fedit-${_fEdit!['name']}'), child: _folderEditCard(p)),
            const SizedBox(height: 10),
          ],
          // Yozuvni papkaga ko'chirish kartasi (tafsilot qatori bosilganda)
          if (_mv != null) ...[
            _SlideIn(key: ValueKey('mv-${_mv!['id']}'), child: _moveCard(p)),
            const SizedBox(height: 10),
          ],

          // Yo'riqnoma — inputdan yuqorida
          Center(
            child: Tx(store.L()['xarInputHint'] as String, size: 11, color: p.t4),
          ),
          const SizedBox(height: 8),
          // Matn input (rangli highlight bilan) + yuborish
          Container(
            key: _inputKey,
            height: 46,
            decoration: BoxDecoration(
              color: p.field.withValues(alpha: .95),
              border: Border.all(color: p.bd),
              borderRadius: BorderRadius.circular(23),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 28, offset: const Offset(0, 10))],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  left: 16, right: 52,
                  child: Center(
                    child: _HlField(
                      value: '${v['xarTextVal'] ?? ''}',
                      onChanged: (t) => v['xarTextSet'](t),
                      hint: store.L()['xarInputHintEx'] as String,
                      onSubmit: v['xfSend'],
                    ),
                  ),
                ),
                Positioned(
                  right: 6, top: 6,
                  child: Tap(
                    onTap: v['xfSend'],
                    child: Opacity(
                      opacity: '${v['xarTextVal'] ?? ''}'.trim().isEmpty && v['xfBusy'] != true ? .4 : 1,
                      child: Container(
                        width: 34, height: 34, alignment: Alignment.center,
                        decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                        child: v['xfBusy'] == true
                            ? _PulseDots(color: p.bg)
                            : Tx('↑', size: 16, w: FontWeight.w700, color: p.bg),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmCard(Map<String, dynamic> v, Pal p) {
    final isMerge = v['xfCfMerge'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.field,
        border: Border.all(color: p.bd2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 40, offset: const Offset(0, 16))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tx(isMerge ? (store.L()['confirmMergeCap'] as String) : (store.L()['confirmDeleteCap'] as String),
              size: 11, w: FontWeight.w600, color: p.t2, ls: 1.6),
          const SizedBox(height: 12),
          if (isMerge)
            Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: .55,
                    child: _Dashed(
                      color: p.t5, radius: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tx('${v['xfCfFromTxt']}', size: 13, w: FontWeight.w500, color: p.ink, maxLines: 1),
                            const SizedBox(height: 4),
                            Tx('${v['xfCfFromSum']}', size: 12.5, color: p.t2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Tx('→', size: 16, color: p.t3),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: p.ink, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tx('${v['xfCfToTxt']}', size: 13, w: FontWeight.w500, color: p.ink, maxLines: 1),
                        const SizedBox(height: 4),
                        Tx('${v['xfCfToSum']}', size: 12.5, color: p.t2),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Opacity(
              opacity: .8,
              child: _Dashed(
                color: p.red.withValues(alpha: .55), radius: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Tx('${v['xfCfFromTxt']}', size: 13, w: FontWeight.w500, color: p.ink),
                      Tx(store.L()['willDelete'] as String, size: 11, color: p.red),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Tap(
                  onTap: v['xfCfOk'],
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isMerge ? p.ink : p.red,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Tx(store.L()['btnConfirm'] as String, size: 13, w: FontWeight.w700,
                        color: isMerge ? p.bg : const Color(0xFF140807)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tap(
                  onTap: v['xfCfNo'],
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: p.bd),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Tx(store.L()['btnCancelShort'] as String, size: 13, w: FontWeight.w600, color: p.t1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Kartalar uchun umumiy qobiq (confirm karta bilan bir xil ko'rinish)
  BoxDecoration _cardDeco(Pal p) => BoxDecoration(
        color: p.field,
        border: Border.all(color: p.bd2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 40, offset: const Offset(0, 16)),
        ],
      );

  // ============ PAPKA TAHRIRI KARTASI (uzoq bosish: rename / arxiv) ============
  Widget _folderEditCard(Pal p) {
    final f = _fEdit!;
    final name = '${f['name']}';
    final cat = _catByName(name);
    final archived = cat?['archived'] == true;
    final renaming = f['renaming'] == true;
    final loading = _cats == null;
    final missing = !loading && cat == null;
    // 'Boshqa' — zaxira papka (parser fallback'i): nomi va arxiv holati qat'iy
    final isBoshqa = _norm(name) == 'boshqa';

    Widget btn(String label, VoidCallback? onTap, {bool primary = false}) => Expanded(
          child: Tap(
            onTap: _fBusy ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primary ? p.ink : null,
                border: primary ? null : Border.all(color: p.bd),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Tx(label, size: 13, w: primary ? FontWeight.w700 : FontWeight.w600,
                  color: primary ? p.bg : p.t1, maxLines: 1),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Tx(_t('xfEditFolderCap', 'PAPKANI TAHRIRLASH'),
                    size: 11, w: FontWeight.w600, color: p.t2, ls: 1.6),
              ),
              _roundBtn('✕', () => setState(() => _fEdit = null), p),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 31, height: 31, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.red.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CatIcon(cat: name, size: 17.5, color: p.red),
              ),
              const SizedBox(width: 10),
              Expanded(child: Tx(name, size: 14, w: FontWeight.w600, color: p.ink, maxLines: 1)),
              if (archived)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.card2,
                    border: Border.all(color: p.bd2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Tx(_t('xfArchivedBadge', 'Arxivda'), size: 10, w: FontWeight.w600, color: p.t1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(child: _PulseDots(color: p.t2)),
            )
          else if (isBoshqa)
            Tx(_t('xfBoshqaFixedHint', "«Boshqa» — zaxira papka: aniqlanmagan yozuvlar shu yerga tushadi, tahrirlanmaydi"),
                size: 12, color: p.t3)
          else if (missing)
            Tx(_t('xfFolderNoCatHint', "Bu papka toifalar ro'yxatida topilmadi — tahrirlash uchun internetni tekshiring"),
                size: 12, color: p.t3)
          else if (renaming)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: p.card2,
                      border: Border.all(color: p.bd),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: TextField(
                        autofocus: true,
                        controller: _fCtl,
                        onChanged: (t) => _fName = t,
                        onSubmitted: (_) => _renameFolder(name),
                        style: GoogleFonts.inter(fontSize: 13, color: p.ink),
                        cursorColor: p.ink,
                        decoration: InputDecoration(
                          isDense: true, isCollapsed: true, border: InputBorder.none,
                          hintText: _t('newFolderHint', 'Yangi papka nomi…'),
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: p.t5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tap(
                  onTap: _fBusy ? null : () => _renameFolder(name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(999)),
                    child: _fBusy
                        ? _PulseDots(color: p.bg)
                        : Tx(store.L()['btnOk'] as String, size: 12, w: FontWeight.w600, color: p.bg),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                btn(_t('xfRename', "Nomini o'zgartirish"), () {
                  setState(() {
                    _fEdit = {...f, 'renaming': true};
                    _fCtl.text = _fName;
                    _fCtl.selection = TextSelection.collapsed(offset: _fName.length);
                  });
                }, primary: true),
                const SizedBox(width: 8),
                btn(
                  archived ? _t('xfUnarchive', 'Arxivdan qaytarish') : _t('xfArchive', 'Arxivlash'),
                  () => _archiveFolder(name, !archived),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Tx(
              archived
                  ? _t('xfArchivedHint', 'Arxivda: AI taklif qilmaydi, eski yozuvlar saqlanadi')
                  : _t('xfArchiveHint', "Arxivlash — o'chirish emas: tarix saqlanadi, AI taklif qilmaydi"),
              size: 11, color: p.t4,
            ),
          ],
        ],
      ),
    );
  }

  // ============ YOZUVNI KO'CHIRISH KARTASI (papkadan papkaga) ============
  Widget _moveCard(Pal p) {
    final mv = _mv!;
    final cur = '${mv['cat']}';
    final loading = _cats == null;
    final chips = (_cats ?? const <Map<String, dynamic>>[])
        .where((c) => c['archived'] != true && _norm('${c['name']}') != _norm(cur))
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Tx(_t('xfMoveCap', "PAPKAGA KO'CHIRISH"),
                    size: 11, w: FontWeight.w600, color: p.t2, ls: 1.6),
              ),
              _roundBtn('✕', () => setState(() => _mv = null), p),
            ],
          ),
          const SizedBox(height: 12),
          _Dashed(
            color: p.t5, radius: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Tx('${mv['desc']}', size: 13, w: FontWeight.w500, color: p.ink, maxLines: 1)),
                  const SizedBox(width: 8),
                  Tx('${mv['amtTxt']}', size: 13, w: FontWeight.w600, color: p.red),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Tx(_tf('xfMoveFrom', {'cat': cur}, "Hozir: {cat} — qaysi papkaga o'tsin?".replaceAll('{cat}', cur)),
              size: 11, color: p.t4),
          const SizedBox(height: 10),
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(child: _PulseDots(color: p.t2)),
            )
          else if (chips.isEmpty)
            Tx(_t('xfMoveNoCats', "Boshqa faol papka yo'q — internetni tekshiring yoki yangi toifa oching"),
                size: 12, color: p.t3)
          else
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                for (final c in chips)
                  Tap(
                    onTap: _fBusy ? null : () => _moveTo('${c['name']}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: p.card2,
                        border: Border.all(color: p.bd),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Tx('${store.xfEmoji('${c['name']}')} ${c['name']}',
                          size: 12, w: FontWeight.w500, color: p.ink),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ================= RANGLI INPUT (dizayn: highlight) =================
// Summa — yashil/qizil (+13% fon), toifa so'zi — card2 fon, buyruq/sana — hair2 fon.
// RANG IKKI QATLAMDA: (1) lokal kalit so'z heuristikasi — DARHOL taxmin;
// (2) server /api/expenses/preview (LLM, istalgan til) — 550ms debounce bilan
// kelib rangni tasdiqlaydi/tuzatadi. Server saqlashda ishlaydigan parser bilan
// BIR MANBA — input rangi endi yakuniy natijaga zid ko'rsatmaydi.
class _HlController extends TextEditingController {
  _HlController() {
    addListener(_onEdit);
  }

  // ---- SUMMA: tilga bog'liq EMAS — raqam + ko'p tilli multiplikator + valyuta ----
  // (server parse.js amountSpans bilan sinxron: ming/минг/тыс/k/к = x1000,
  // mln/million/млн/миллион/m/м = x1000000). Qisqa k|к|m|м faqat alohida
  // turganda multiplikator ("5000 kofe"dagi "k" emas — lookahead bilan).
  static final _amtRe = RegExp(
      r"(\d{1,3}(?:[  .]\d{3})+|\d{1,3}(?:,\d{3})+|\d+(?:[.,]\d+)?)"
      r"(\s*(?:ming[a-z]*|минг[а-яё]*|тыс[а-яё]*|mln[a-z]*|million[a-z]*|milion[a-z]*|млн|миллион[а-яё]*|милион[а-яё]*|[kк](?![a-zа-яё0-9])|[mм](?![a-zа-яё0-9])))?"
      r"(\s*(?:so['’ʻ`]?m|сум[а-яё]*|сўм[а-яё]*|uzs))?",
      caseSensitive: false);
  static final _catRe = RegExp(
      r"oziq-ovqat|oziq|tushlik|nonushta|ovqat|bozor|market|taksi|avtobus|metro|benzin|transport|kofe|qahva|kommunal|svet|gaz|internet|telefon|kiyim|xarid\w*|do['’ʻ`]?kon|dori\w*|shifokor|apteka|kino|konsert|sport|zal|fitnes|kitob\w*|papka\w*|oylik|maosh|avans|mijoz\w*|sotuv\w*|biznes|daromad|bonus",
      caseSensitive: false);
  static final _cmdRe = RegExp(r"birlashtir\w*|o['’ʻ`]?chir\w*|keldi|tushdi|qaytdi",
      caseSensitive: false);
  static final _dateRe = RegExp(r"bugun|kechqurun|kecha|ertalab|ertaga", caseSensitive: false);
  // Kirim/chiqim kalit so'zlari IKKI sinfda: OT (odatda summadan OLDIN keladi —
  // "oylik 4 mln", "kreditga 200 ming" -> KEYINGI summaga bog'lanadi) va FE'L
  // (summadan KEYIN keladi — "4 mln oldim", "200 ming berdim" -> OLDINGI summaga).
  // Har summa uchun eng yaqin da'vogar kalit so'z g'olib — shu bilan
  // "oylik oldim 4 mln kreditga 200 ming berdim" da 1-summa yashil, 2-si qizil.
  // Bu faqat DARHOL taxmin (rus/ingliz/kirill tez-tez uchraydigan so'zlar bilan);
  // yakuniy rang server LLM preview'idan keladi — lug'atni cheksiz kengaytirish shart emas.
  static final _incNounRe = RegExp(
      // 'foyda' server INC_NOUN bilan sinxronlandi (rang bugi: lokal taxmin qizil,
      // server esa kirim derdi — endi ikkala qatlam bir xil)
      r"\b(oylik|maosh|avans|daromad|bonus|kirim|foyda|salary|income|profit|revenue)\b"
      r"|mijoz\w*|sotuv\w*|ойлик|маош|даромад|кирим|фойда|аванс|бонус|зарплат[а-яё]*|доход[а-яё]*|мижоз[а-яё]*|сотув[а-яё]*",
      caseSensitive: false);
  static final _incVerbRe = RegExp(
      // \b anchor: "qaytardi" (u menga qaytardi = kirim) ichida "qaytardim"
      // (men qaytardim = chiqim) yutilib ketmasin — 1-shaxs endi chiqim ro'yxatida
      r"\boldim\b|\bsotdim\b|keldi|tushdi|qaytdi\b|qaytardi\b"
      r"|\breceived\b|\bearned\b|\bgot\b|\bsold\b"
      r"|олдим|сотдим|келди|тушди|қайтди|получил[а-яё]*|заработал[а-яё]*|пришл[а-яё]*|поступил[а-яё]*|продал[а-яё]*",
      caseSensitive: false);
  static final _expNounRe = RegExp(
      r"kredit\w*|xarid\w*|\bqarzga\b|\brent\b|кредит[а-яё]*|аренд[а-яё]*|харид[а-яё]*",
      caseSensitive: false);
  static final _expVerbRe = RegExp(
      r"berdim|sarfladim|ishlatdim|to['’ʻ`]?ladim|ketdi|sotib\s+oldim|qaytardim|qaytarib\s+berdim"
      r"|\bspent\b|\bpaid\b|\bbought\b|\bgave\b"
      r"|бердим|сарфладим|тўладим|туладим|кетди|сотиб\s+олдим|потратил[а-яё]*|купил[а-яё]*|заплатил[а-яё]*|оплатил[а-яё]*|отдал[а-яё]*",
      caseSensitive: false);

  // ---- SERVER PREVIEW: yakuniy rang manbai (saqlashdagi parser bilan bir xil) ----
  Timer? _debTimer;
  int _seq = 0;
  String _lastKey = '';
  bool _disposed = false;
  // Kesh statik — field qayta qurilsa ham saqlanadi; qiymat: [[amount, 'in'|'out'], ...]
  static final Map<String, List<List<dynamic>>> _srvCache = {};
  List<List<dynamic>>? _srv;
  String _srvKey = '';

  static final _gapRe = RegExp(r"(\d)[  ](?=\d)");
  static final _digitRe = RegExp(r"\d");

  // Ko'rinishdagi "400 000" guruh bo'shliqlari tozalanadi (xfSend_ bilan bir xil) —
  // server so'rovi va kesh kaliti shu.
  String get _cleanKey =>
      text.replaceAllMapped(_gapRe, (m) => m[1]!).trim().toLowerCase();

  void _onEdit() {
    final k = _cleanKey;
    if (k == _lastKey) return; // selection/composing o'zgarishi — matn o'sha
    _lastKey = k;
    _debTimer?.cancel();
    final hit = _srvCache[k];
    if (hit != null) {
      // Kesh — darhol (repaint shu notifikatsiya tsiklining o'zida bo'ladi)
      _srv = hit;
      _srvKey = k;
      return;
    }
    if (k.isEmpty || !_digitRe.hasMatch(k)) return; // summasiz matnga so'rov yo'q
    _debTimer = Timer(const Duration(milliseconds: 550), () => _fetchPreview(k));
  }

  Future<void> _fetchPreview(String k) async {
    final id = ++_seq;
    try {
      final r = await Api.previewExpense(k);
      if (!r.ok) return;
      final list = [
        for (final e in ((r.data?['amounts'] as List?) ?? const []))
          [((e as Map)['amount'] as num).round(), '${e['kind']}'],
      ];
      _srvCache[k] = list;
      if (_srvCache.length > 80) _srvCache.remove(_srvCache.keys.first);
      if (_disposed || id != _seq || _cleanKey != k) return; // eskirgan javob
      _srv = list;
      _srvKey = k;
      notifyListeners(); // rang yangilansin
    } catch (_) {
      // oflayn/server xatosi — lokal heuristika rangi qolaveradi
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debTimer?.cancel();
    super.dispose();
  }

  // Match qiymati so'mda — server previewdagi amount bilan solishtirish uchun
  static final _grpNumRe = RegExp(r"^\d{1,3}(?:[  .]\d{3})+$");
  static final _grpSepRe = RegExp(r"[  .]");
  static final _commaNumRe = RegExp(r"^\d{1,3}(?:,\d{3})+$");
  static int _amtValue(RegExpMatch m) {
    final raw = m.group(1)!;
    double v;
    if (_grpNumRe.hasMatch(raw)) {
      v = double.parse(raw.replaceAll(_grpSepRe, ''));
    } else if (_commaNumRe.hasMatch(raw)) {
      v = double.parse(raw.replaceAll(',', ''));
    } else {
      v = double.parse(raw.replaceAll(',', '.'));
    }
    final mul = (m.group(2) ?? '').trim().toLowerCase();
    if (mul.isNotEmpty) {
      final thousand = mul.startsWith('ming') || mul.startsWith('минг') ||
          mul.startsWith('тыс') || mul == 'k' || mul == 'к';
      v *= thousand ? 1000 : 1000000;
    }
    return v.round();
  }

  /// Har bir summa (amts — [s, e, 'amt'] ro'yxati) kirimmi? Kalit so'zlar o'z
  /// yo'nalishidagi eng yaqin summaga da'vo qiladi; masofada teng bo'lsa chiqim ustun.
  static List<bool> _amtKinds(String t, List<List<dynamic>> amts) {
    final n = amts.length;
    final kind = List<bool>.filled(n, false); // sukut: chiqim (qizil)
    final best = List<double>.filled(n, double.infinity);
    if (n == 0) return kind;

    final ms = <List<dynamic>>[]; // [start, end, inc, forward]
    void collect(RegExp re, bool inc, bool forward) {
      for (final m in re.allMatches(t)) {
        // Chiqim avval yig'iladi — uning ichiga tushgan kirim matchi tashlanadi
        // ("sotib oldim" ichidagi "oldim" kabi)
        final overlapped =
            ms.any((x) => !(m.end <= (x[0] as int) || m.start >= (x[1] as int)));
        if (inc && overlapped) continue;
        ms.add([m.start, m.end, inc, forward]);
      }
    }

    collect(_expVerbRe, false, false);
    collect(_expNounRe, false, true);
    collect(_incVerbRe, true, false);
    collect(_incNounRe, true, true);

    for (final m in ms) {
      final s = m[0] as int, e = m[1] as int;
      final inc = m[2] as bool, fwd = m[3] as bool;
      int? target;
      var dist = double.infinity;
      if (fwd) {
        // Keyingi summa; topilmasa — oldingisi (kuchsizroq, +0.5)
        for (var i = 0; i < n; i++) {
          if ((amts[i][0] as int) >= e) {
            target = i;
            dist = ((amts[i][0] as int) - e).toDouble();
            break;
          }
        }
        if (target == null) {
          for (var i = n - 1; i >= 0; i--) {
            if ((amts[i][1] as int) <= s) {
              target = i;
              dist = (s - (amts[i][1] as int)) + 0.5;
              break;
            }
          }
        }
      } else {
        // Oldingi summa; topilmasa — keyingisi (kuchsizroq, +0.5)
        for (var i = n - 1; i >= 0; i--) {
          if ((amts[i][1] as int) <= s) {
            target = i;
            dist = (s - (amts[i][1] as int)).toDouble();
            break;
          }
        }
        if (target == null) {
          for (var i = 0; i < n; i++) {
            if ((amts[i][0] as int) >= e) {
              target = i;
              dist = ((amts[i][0] as int) - e) + 0.5;
              break;
            }
          }
        }
      }
      if (target == null) continue;
      if (dist < best[target] || (dist == best[target] && !inc)) {
        best[target] = dist;
        kind[target] = inc;
      }
    }
    return kind;
  }

  // Rang qarori: server preview javobi AYNAN shu matnga tegishli bo'lsa — u ustun
  // (summalar qiymat bo'yicha moslanadi), aks holda lokal heuristika (darhol taxmin).
  List<bool> _resolveKinds(String t, List<List<dynamic>> amts) {
    final local = _amtKinds(t, amts);
    final srv = (_srv != null && _srvKey == _cleanKey) ? _srv! : null;
    if (srv == null) return local;
    final used = List<bool>.filled(srv.length, false);
    return List<bool>.generate(amts.length, (i) {
      final v = amts[i][3] as int;
      // 1) tartib bo'yicha to'g'ridan-to'g'ri moslik
      if (i < srv.length && !used[i] && srv[i][0] == v) {
        used[i] = true;
        return srv[i][1] == 'in';
      }
      // 2) qiymati teng birinchi ishlatilmagan server yozuvi
      for (var j = 0; j < srv.length; j++) {
        if (!used[j] && srv[j][0] == v) {
          used[j] = true;
          return srv[j][1] == 'in';
        }
      }
      // 3) mos kelmadi (sanoq farqi) — lokal taxmin
      return local[i];
    });
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final p = curPal();
    final t = text;
    if (t.isEmpty) return TextSpan(style: style);

    final ranges = <List<dynamic>>[]; // [s, e, type, (amt uchun) so'mdagi qiymat]
    for (final m in _amtRe.allMatches(t)) {
      if (m.end > m.start) ranges.add([m.start, m.end, 'amt', _amtValue(m)]);
    }
    void push(RegExp re, String type) {
      for (final m in re.allMatches(t)) {
        if (m.end > m.start) ranges.add([m.start, m.end, type]);
      }
    }

    push(_catRe, 'cat');
    push(_cmdRe, 'cmd');
    push(_dateRe, 'date');
    ranges.sort((a, b) => (a[0] as int) != (b[0] as int)
        ? (a[0] as int) - (b[0] as int)
        : ((b[1] as int) - (b[0] as int)) - ((a[1] as int) - (a[0] as int)));
    final kept = <List<dynamic>>[];
    var last = 0;
    for (final r in ranges) {
      if ((r[0] as int) >= last) {
        kept.add(r);
        last = r[1] as int;
      }
    }

    // Har summa rangi: server preview (shu matnga kelgan bo'lsa) yoki lokal heuristika
    final amts = kept.where((r) => r[2] == 'amt').toList();
    final amtKinds = _resolveKinds(t, amts);

    final spans = <TextSpan>[];
    var pos = 0;
    var amtIdx = 0;
    for (final r in kept) {
      final s = r[0] as int, e = r[1] as int, type = r[2] as String;
      if (s > pos) spans.add(TextSpan(text: t.substring(pos, s)));
      Color c;
      Color bg;
      if (type == 'amt') {
        final cc = amtKinds[amtIdx++] ? p.green : p.red;
        c = cc;
        bg = cc.withValues(alpha: .13);
      } else if (type == 'cat') {
        c = p.ink;
        bg = p.card2;
      } else if (type == 'cmd') {
        c = p.t1;
        bg = p.hair2;
      } else {
        c = p.t2;
        bg = p.hair2;
      }
      spans.add(TextSpan(
        text: t.substring(s, e),
        style: TextStyle(color: c, background: Paint()..color = bg),
      ));
      pos = e;
    }
    if (pos < t.length) spans.add(TextSpan(text: t.substring(pos)));
    return TextSpan(style: style, children: spans);
  }
}

/// Store bilan sinxron RANGLI TextField (StoreField + _HlController)
class _HlField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final VoidCallback? onSubmit;
  const _HlField({required this.value, required this.onChanged, this.hint, this.onSubmit});

  @override
  State<_HlField> createState() => _HlFieldState();
}

class _HlFieldState extends State<_HlField> {
  late final _HlController _c = _HlController()..text = widget.value;

  @override
  void didUpdateWidget(covariant _HlField old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) {
      _c.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final st = GoogleFonts.inter(fontSize: 14, color: p.ink);
    return TextField(
      controller: _c,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmit != null ? (_) => widget.onSubmit!() : null,
      inputFormatters: [_NumGroupFmt()], // raqamlar jonli 0 000 000 ko'rinishida
      style: st,
      cursorColor: p.ink,
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        border: InputBorder.none,
        hintText: widget.hint,
        hintStyle: st.copyWith(color: p.t5),
      ),
    );
  }
}

/// Yozish paytida raqamlarni 3 talik guruhlab ko'rsatadi: 400000 -> "400 000".
/// Kursor pozitsiyasi raqamlar soni bo'yicha saqlanadi.
class _NumGroupFmt extends TextInputFormatter {
  static final _d = RegExp(r'\d');

  String _group(String digits) {
    final b = StringBuffer();
    for (var k = 0; k < digits.length; k++) {
      if (k > 0 && (digits.length - k) % 3 == 0) b.write(' ');
      b.write(digits[k]);
    }
    return b.toString();
  }

  // Guruh bo'shlig'i: ikki raqam ORASIDAGI yolg'iz bo'shliq (format belgisi)
  bool _isGroupSpace(String s, int i) =>
      s[i] == ' ' && i > 0 && i + 1 < s.length && _d.hasMatch(s[i - 1]) && _d.hasMatch(s[i + 1]);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    final t = newV.text;
    if (t.isEmpty || !_d.hasMatch(t)) return newV;

    // Kursordan oldingi MA'NOLI belgilar soni (guruh bo'shliqlari hisobga OLINMAYDI) —
    // faqat raqam sanash harf yozilganda kursorni orqada qoldirib, matnni teskari yozdirardi
    var meaningfulBefore = 0;
    final selEnd = newV.selection.end.clamp(0, t.length);
    for (var i = 0; i < selEnd; i++) {
      if (!_isGroupSpace(t, i)) meaningfulBefore++;
    }

    // Raqam oqimlarini yig'ish: raqamlar orasidagi YOLG'IZ bo'shliq format qoldig'i
    // sifatida yutiladi ("400 000" -> 400000), keyin qaytadan 3 talik guruhlanadi.
    final out = StringBuffer();
    var i = 0;
    while (i < t.length) {
      if (_d.hasMatch(t[i])) {
        final run = StringBuffer();
        var j = i;
        while (j < t.length) {
          if (_d.hasMatch(t[j])) {
            run.write(t[j]);
            j++;
          } else if (t[j] == ' ' && j + 1 < t.length && _d.hasMatch(t[j + 1])) {
            j++; // raqamlar orasidagi bo'shliq — guruh belgisi
          } else {
            break;
          }
        }
        out.write(_group(run.toString()));
        i = j;
      } else {
        out.write(t[i]);
        i++;
      }
    }
    final res = out.toString();

    // Kursorni ma'noli belgilar soni bo'yicha qayta joylash
    var pos = 0, seen = 0;
    while (pos < res.length && seen < meaningfulBefore) {
      if (!_isGroupSpace(res, pos)) seen++;
      pos++;
    }
    return TextEditingValue(text: res, selection: TextSelection.collapsed(offset: pos));
  }
}

// ================= YORDAMCHI ANIMATSIYALAR =================

/// Sanab boruvchi raqam (count-up): qiymat o'zgarganda eski sondan yangisiga
/// SANAB o'tadi — sekin boshlanib tezlashadi (151, 152, 155, 163, ... 200).
/// Tabular raqamlar bilan kenglik sakramaydi.
class _AnimNum extends StatefulWidget {
  final int value; // maqsad (absolyut qiymat)
  final String prefix; // '+' yoki '−'
  final double size;
  final FontWeight weight;
  final Color color;
  final double ls;
  // true: widget YARATILGANDA ham 0 dan sanab chiqadi (yangi papka summasi) —
  // false: birinchi ko'rinishda darhol, faqat O'ZGARISHDA sanaydi (balans)
  final bool fromZero;
  const _AnimNum({
    required this.value,
    required this.prefix,
    required this.size,
    required this.weight,
    required this.color,
    this.ls = 0,
    this.fromZero = false,
  });

  @override
  State<_AnimNum> createState() => _AnimNumState();
}

class _AnimNumState extends State<_AnimNum> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900), value: 1);
  late int _from = widget.fromZero ? 0 : widget.value;
  late int _to = widget.value;

  @override
  void initState() {
    super.initState();
    if (widget.fromZero && widget.value != 0) _c.forward(from: 0);
  }

  // Sekin boshlanib TEZLASHADI (foydalanuvchi so'ragan his) — easeIn
  int _now() {
    final t = Curves.easeInCubic.transform(_c.value);
    return (_from + (_to - _from) * t).round();
  }

  String _fmt(int v) {
    final s = v.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  void didUpdateWidget(covariant _AnimNum old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = _now(); // yarim yo'lda o'zgarsa — joriy sondan davom etadi
      _to = widget.value;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Text(
        '${widget.prefix}${_fmt(_now())}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: widget.size,
          fontWeight: widget.weight,
          color: widget.color,
          letterSpacing: widget.ls,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Jonli sparkline — har o'zgarishda YANGI shakl boshlanish nuqtasidan oxirgi
/// nuqtagacha CHIZILIB boradi (draw-on, trim-path), uchida yorqin nuqta yuradi
/// va oxirgi nuqtada to'xtaydi.
class _AnimSpark extends StatefulWidget {
  final List<double> pts;
  final Color color;
  const _AnimSpark({required this.pts, required this.color});

  @override
  State<_AnimSpark> createState() => _AnimSparkState();
}

class _AnimSparkState extends State<_AnimSpark> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 750), value: 1);

  @override
  void didUpdateWidget(covariant _AnimSpark old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.pts, widget.pts)) {
      _c.forward(from: 0); // yangi shakl boshidan chizilib boradi
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        painter: _Spark(widget.pts, widget.color,
            progress: Curves.easeInOutCubic.transform(_c.value)),
      ),
    );
  }
}

/// Sparkline chizuvchi — silliq egri chiziq, gradient stroke + osti gradient bilan
/// to'ldirilgan maydon (modern "area chart" ko'rinishi).
class _Spark extends CustomPainter {
  final List<double> pts;
  final Color color;
  final double progress; // 0..1 — chiziq boshidan shu ulushigacha chizilgan
  _Spark(this.pts, this.color, {this.progress = 1});

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty || progress <= 0) return;
    final w = size.width, h = size.height;
    Offset pt(int i) {
      final x = pts.length == 1 ? 0.0 : i / (pts.length - 1) * w;
      final y = h - (pts[i].clamp(0.0, 1.0) * h * 0.78) - h * 0.08;
      return Offset(x, y);
    }

    // Silliq egri: nuqtalar orasида o'rta nuqta orqali kvadratik bezier
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pt(i - 1), b = pt(i);
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      line.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
      if (i == pts.length - 1) line.quadraticBezierTo(b.dx, b.dy, b.dx, b.dy);
    }

    // Draw-on: chiziq boshidan progress ulushigacha kesib olinadi, yorqin
    // nuqta uchida yuradi va oxirgi nuqtada to'xtaydi
    var draw = line;
    var tip = pt(pts.length - 1);
    if (progress < 1) {
      final ms = line.computeMetrics().toList();
      if (ms.isNotEmpty) {
        final m = ms.first;
        final len = m.length * progress;
        draw = m.extractPath(0, len);
        tip = m.getTangentForOffset(len)?.position ?? tip;
      }
    }

    // Chizilgan qism ostidagi maydon — pastga shaffoflashib ketadigan gradient
    final area = Path.from(draw)
      ..lineTo(tip.dx, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .20), color.withValues(alpha: .0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Chiziqning o'zi — chapdan o'ngga quyuqlashadigan gradient stroke
    canvas.drawPath(
      draw,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: .25), color.withValues(alpha: .85)],
        ).createShader(Rect.fromLTWH(0, 0, w, h))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Uch nuqtasi — kichik yorqin doira (chizilish davomida birga yuradi)
    canvas.drawCircle(tip, 2.2, Paint()..color = color.withValues(alpha: .9));
    canvas.drawCircle(tip, 4.2, Paint()..color = color.withValues(alpha: .18));
  }

  @override
  bool shouldRepaint(_Spark old) =>
      old.pts != pts || old.color != color || old.progress != progress;
}

/// Fly-chip ortidagi zarracha izi — so'nib boruvchi glow nuqtalari
class _TrailPaint extends CustomPainter {
  final List<List<double>> dots; // [x, y, alpha, radius]
  final Color color;
  _TrailPaint(this.dots, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in dots) {
      canvas.drawCircle(
        Offset(d[0], d[1]), d[3],
        Paint()..color = color.withValues(alpha: d[2].clamp(0.0, 1.0)),
      );
      // Yumshoq halo
      canvas.drawCircle(
        Offset(d[0], d[1]), d[3] * 2.2,
        Paint()..color = color.withValues(alpha: (d[2] * .35).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_TrailPaint old) => true;
}

/// Shtrixli (dashed) ramka — dizayndagi 1.5px dashed
class _Dashed extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  const _Dashed({required this.child, required this.color, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashPainter(color, radius),
      child: child,
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashPainter(this.color, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, (d + dash).clamp(0, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color || old.radius != radius;
}

/// Paydo bo'lishda pastdan siljib kirish (dizayn: xkSlidein)
class _SlideIn extends StatelessWidget {
  final Widget child;
  const _SlideIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: c),
      ),
      child: child,
    );
  }
}

/// Paydo bo'lishda chayqalish (dizayn: xkShake — tray e'tibor tortadi)
class _Shake extends StatelessWidget {
  final Widget child;
  const _Shake({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (_, t, c) {
        final amp = (1 - t) * 5;
        final dx = amp * ((t * 25).floor() % 2 == 0 ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: c);
      },
      child: child,
    );
  }
}

/// Band holat: nuqtalar pulslashi (yuborish tugmasida)
class _PulseDots extends StatefulWidget {
  final Color color;
  const _PulseDots({required this.color});

  @override
  State<_PulseDots> createState() => _PulseDotsState();
}

class _PulseDotsState extends State<_PulseDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Opacity(
                opacity: (0.35 + 0.65 * ((t * 3 - i).clamp(0.0, 1.0) - ((t * 3 - i - 1).clamp(0.0, 1.0)))).clamp(0.2, 1.0),
                child: Container(
                  width: 3.5, height: 3.5,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ================= TOIFA VEKTOR IKONKALARI (emoji o'rniga, SVG-uslub) =================
/// Toifaga mazmunan mos zamonaviy chiziqli ikonka. Kichik chip va katta fon-glif
/// (watermark) uchun bir xil ishlatiladi — o'lcham va rang tashqaridan beriladi.
class CatIcon extends StatelessWidget {
  final String cat;
  final double size;
  final Color color;
  const CatIcon({super.key, required this.cat, required this.size, required this.color});

  static String _norm(String s) => s.toLowerCase()
      .replaceAll('’', "'").replaceAll('ʻ', "'").replaceAll('`', "'").replaceAll('ʼ', "'");

  /// Toifa nomi -> glif kaliti (store._xfEmojiMap bilan bir xil ro'yxat)
  static String glyphFor(String cat) {
    const map = {
      'oylik': 'briefcase', 'biznes': 'chart', 'boshqa kirim': 'coins', 'daromad': 'coins',
      'transport': 'bus', 'taksi': 'taxi', 'kofe': 'coffee', 'oziq-ovqat': 'bowl',
      'kommunal': 'bulb', 'xaridlar': 'bag', 'kiyim': 'bag', 'salomatlik': 'cross',
      "ko'ngilochar": 'play', 'sport': 'dumbbell', 'kitoblar': 'book', 'uy': 'home',
      'aloqa': 'phone', "ta'lim": 'cap', 'boshqa': 'box',
    };
    return map[_norm(cat)] ?? 'folder';
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CatIconPainter(glyphFor(cat), color),
    );
  }
}

/// 24x24 koordinata maydonida chizadi, keyin kerakli o'lchamga masshtablanadi.
class _CatIconPainter extends CustomPainter {
  final String glyph;
  final Color color;
  _CatIconPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k, k);
    final st = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fl = Paint()..color = color;

    switch (glyph) {
      case 'briefcase': // portfel — oylik/maosh
        canvas.drawRRect(RRect.fromLTRBR(3.2, 8, 20.8, 19, const Radius.circular(2.6)), st);
        canvas.drawPath(Path()..moveTo(9, 8)..lineTo(9, 6.4)..cubicTo(9, 5.3, 9.9, 4.5, 11, 4.5)
          ..lineTo(13, 4.5)..cubicTo(14.1, 4.5, 15, 5.3, 15, 6.4)..lineTo(15, 8), st);
        canvas.drawLine(const Offset(3.2, 12.6), const Offset(20.8, 12.6), st);
        canvas.drawLine(const Offset(12, 12.6), const Offset(12, 14.8), st);
        break;
      case 'chart': // o'sish grafigi — biznes
        canvas.drawPath(Path()..moveTo(4, 17.5)..lineTo(9.8, 11.6)..lineTo(13.4, 14.6)..lineTo(20, 7.2), st);
        canvas.drawPath(Path()..moveTo(15.6, 7.2)..lineTo(20, 7.2)..lineTo(20, 11.6), st);
        break;
      case 'coins': // ustma-ust tangalar — daromad
        canvas.drawOval(const Rect.fromLTRB(6, 4.6, 18, 9.6), st);
        canvas.drawPath(Path()..moveTo(6, 7.1)..lineTo(6, 12)..cubicTo(6, 13.4, 8.7, 14.5, 12, 14.5)
          ..cubicTo(15.3, 14.5, 18, 13.4, 18, 12)..lineTo(18, 7.1), st);
        canvas.drawPath(Path()..moveTo(6, 12)..lineTo(6, 16.9)..cubicTo(6, 18.3, 8.7, 19.4, 12, 19.4)
          ..cubicTo(15.3, 19.4, 18, 18.3, 18, 16.9)..lineTo(18, 12), st);
        break;
      case 'bus': // avtobus — transport
        canvas.drawRRect(RRect.fromLTRBR(4.2, 4, 19.8, 17.4, const Radius.circular(3)), st);
        canvas.drawLine(const Offset(4.2, 10), const Offset(19.8, 10), st);
        canvas.drawLine(const Offset(9.4, 13.7), const Offset(14.6, 13.7), st);
        canvas.drawCircle(const Offset(7.6, 19.6), 1.5, fl);
        canvas.drawCircle(const Offset(16.4, 19.6), 1.5, fl);
        break;
      case 'taxi': // yengil mashina — taksi
        canvas.drawPath(Path()..moveTo(3.6, 16.2)..lineTo(3.6, 13.6)..cubicTo(3.6, 12.3, 4.5, 11.4, 5.9, 11.2)
          ..lineTo(7.9, 7.7)..cubicTo(8.3, 6.9, 9.1, 6.5, 10, 6.5)..lineTo(14, 6.5)
          ..cubicTo(14.9, 6.5, 15.7, 6.9, 16.1, 7.7)..lineTo(18.1, 11.2)
          ..cubicTo(19.5, 11.4, 20.4, 12.3, 20.4, 13.6)..lineTo(20.4, 16.2), st);
        canvas.drawLine(const Offset(6.4, 11.2), const Offset(17.6, 11.2), st);
        canvas.drawCircle(const Offset(7.6, 16.8), 1.9, st);
        canvas.drawCircle(const Offset(16.4, 16.8), 1.9, st);
        break;
      case 'coffee': // piyola + bug' — kofe
        canvas.drawPath(Path()..moveTo(5, 10.4)..lineTo(16.2, 10.4)..lineTo(16.2, 15)
          ..cubicTo(16.2, 17.6, 13.9, 19.4, 10.6, 19.4)..cubicTo(7.3, 19.4, 5, 17.6, 5, 15)..close(), st);
        canvas.drawPath(Path()..moveTo(16.2, 11.8)..lineTo(17.4, 11.8)
          ..cubicTo(19, 11.8, 19.8, 13, 19.4, 14.3)..cubicTo(19, 15.5, 17.8, 16.2, 16.2, 15.9), st);
        canvas.drawLine(const Offset(8.6, 4.6), const Offset(8.6, 7), st);
        canvas.drawLine(const Offset(12.4, 4.6), const Offset(12.4, 7), st);
        break;
      case 'bowl': // kosa + bug' — oziq-ovqat
        canvas.drawPath(Path()..moveTo(4.4, 12)..lineTo(19.6, 12)
          ..cubicTo(19.6, 15.8, 16.6, 18.6, 12, 18.6)..cubicTo(7.4, 18.6, 4.4, 15.8, 4.4, 12)..close(), st);
        canvas.drawLine(const Offset(9.4, 6), const Offset(9.4, 8.6), st);
        canvas.drawLine(const Offset(14.6, 6), const Offset(14.6, 8.6), st);
        break;
      case 'bulb': // lampochka — kommunal
        canvas.drawCircle(const Offset(12, 10), 5, st);
        canvas.drawLine(const Offset(9.9, 17.4), const Offset(14.1, 17.4), st);
        canvas.drawLine(const Offset(10.5, 19.8), const Offset(13.5, 19.8), st);
        canvas.drawLine(const Offset(12, 15), const Offset(12, 17.4), st);
        break;
      case 'bag': // xarid sumkasi — xaridlar/kiyim
        canvas.drawRRect(RRect.fromLTRBR(5, 8.4, 19, 20, const Radius.circular(3)), st);
        canvas.drawPath(Path()..moveTo(8.8, 8.4)..lineTo(8.8, 7)
          ..cubicTo(8.8, 4.9, 10.2, 3.6, 12, 3.6)..cubicTo(13.8, 3.6, 15.2, 4.9, 15.2, 7)..lineTo(15.2, 8.4), st);
        break;
      case 'cross': // tibbiy xoch — salomatlik
        canvas.drawPath(Path()..moveTo(9.8, 4.6)..lineTo(14.2, 4.6)..lineTo(14.2, 9.8)..lineTo(19.4, 9.8)
          ..lineTo(19.4, 14.2)..lineTo(14.2, 14.2)..lineTo(14.2, 19.4)..lineTo(9.8, 19.4)
          ..lineTo(9.8, 14.2)..lineTo(4.6, 14.2)..lineTo(4.6, 9.8)..lineTo(9.8, 9.8)..close(), st);
        break;
      case 'play': // ijro doirasi — ko'ngilochar
        canvas.drawCircle(const Offset(12, 12), 8.4, st);
        canvas.drawPath(Path()..moveTo(10.3, 8.9)..lineTo(15.9, 12)..lineTo(10.3, 15.1)..close(), fl);
        break;
      case 'dumbbell': // gantel — sport
        canvas.drawLine(const Offset(8.6, 12), const Offset(15.4, 12), st);
        canvas.drawRRect(RRect.fromLTRBR(5.4, 8.4, 8.6, 15.6, const Radius.circular(1.2)), st);
        canvas.drawRRect(RRect.fromLTRBR(15.4, 8.4, 18.6, 15.6, const Radius.circular(1.2)), st);
        canvas.drawLine(const Offset(3.4, 10), const Offset(3.4, 14), st);
        canvas.drawLine(const Offset(20.6, 10), const Offset(20.6, 14), st);
        break;
      case 'book': // ochiq kitob — kitoblar
        canvas.drawPath(Path()..moveTo(12, 6.6)..cubicTo(10.4, 5, 8, 4.5, 4.6, 4.9)..lineTo(4.6, 17.7)
          ..cubicTo(8, 17.3, 10.4, 17.9, 12, 19.4)..cubicTo(13.6, 17.9, 16, 17.3, 19.4, 17.7)
          ..lineTo(19.4, 4.9)..cubicTo(16, 4.5, 13.6, 5, 12, 6.6)..close(), st);
        canvas.drawLine(const Offset(12, 6.6), const Offset(12, 19.4), st);
        break;
      case 'home': // uy
        canvas.drawPath(Path()..moveTo(4.4, 11.4)..lineTo(12, 4.4)..lineTo(19.6, 11.4), st);
        canvas.drawPath(Path()..moveTo(6.4, 10)..lineTo(6.4, 19.4)..lineTo(17.6, 19.4)..lineTo(17.6, 10), st);
        canvas.drawPath(Path()..moveTo(10.4, 19.4)..lineTo(10.4, 14.6)
          ..cubicTo(10.4, 13.7, 11.1, 13, 12, 13)..cubicTo(12.9, 13, 13.6, 13.7, 13.6, 14.6)..lineTo(13.6, 19.4), st);
        break;
      case 'phone': // telefon — aloqa
        canvas.drawRRect(RRect.fromLTRBR(7, 3.6, 17, 20.4, const Radius.circular(2.8)), st);
        canvas.drawLine(const Offset(10.6, 6.4), const Offset(13.4, 6.4), st);
        canvas.drawCircle(const Offset(12, 17.6), 1, fl);
        break;
      case 'cap': // bitiruv qalpog'i — ta'lim
        canvas.drawPath(Path()..moveTo(12, 5)..lineTo(21, 9.4)..lineTo(12, 13.8)..lineTo(3, 9.4)..close(), st);
        canvas.drawLine(const Offset(21, 9.4), const Offset(21, 13.4), st);
        canvas.drawPath(Path()..moveTo(7, 11.6)..lineTo(7, 15)
          ..cubicTo(7, 16.7, 9.2, 18, 12, 18)..cubicTo(14.8, 18, 17, 16.7, 17, 15)..lineTo(17, 11.6), st);
        break;
      case 'box': // quti — boshqa
        canvas.drawPath(Path()..moveTo(4.6, 8)..lineTo(12, 4.4)..lineTo(19.4, 8)..lineTo(19.4, 16)
          ..lineTo(12, 19.6)..lineTo(4.6, 16)..close(), st);
        canvas.drawPath(Path()..moveTo(4.6, 8)..lineTo(12, 11.6)..lineTo(19.4, 8), st);
        canvas.drawLine(const Offset(12, 11.6), const Offset(12, 19.6), st);
        break;
      default: // papka — noma'lum toifa
        canvas.drawPath(Path()..moveTo(4, 16.6)..lineTo(4, 7.4)..cubicTo(4, 6.3, 4.9, 5.4, 6, 5.4)
          ..lineTo(9.1, 5.4)..cubicTo(9.7, 5.4, 10.3, 5.7, 10.7, 6.1)..lineTo(12, 7.5)..lineTo(18, 7.5)
          ..cubicTo(19.1, 7.5, 20, 8.4, 20, 9.5)..lineTo(20, 16.6)..cubicTo(20, 17.7, 19.1, 18.6, 18, 18.6)
          ..lineTo(6, 18.6)..cubicTo(4.9, 18.6, 4, 17.7, 4, 16.6)..close(), st);
        break;
    }
  }

  @override
  bool shouldRepaint(_CatIconPainter old) => old.glyph != glyph || old.color != color;
}

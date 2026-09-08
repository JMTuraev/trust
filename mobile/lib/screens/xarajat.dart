// Xarajatlar — papka (folder) UI. Vizual qatlam: prototype/redesign/DESIGN_SPEC.md §5.11
// ("dark glass + gradient", 2026-09-07); mantiq — avvalgi "Xarajatlar Trust.html" oqimi 1:1.
// TO'LIQ EKRAN: bottom navsiz, header'da orqaga. Matn-birinchi: input -> AI -> papka.
// Dinamika (dizayn kabi): input ichida rangli belgilash (summa qizil, toifa/buyruq/sana
// fonli), yozuv papkaga "uchadi" (fly chip + papka pulsi), sparkline jonli (oxirgi 8 yozuv,
// yangisida siljiydi), yangi papka "pop", tray "shake", toastlar "Bekor qilish" bilan.
import 'dart:async' show Timer;
import 'dart:convert' show jsonDecode, utf8;
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show TextInputFormatter, TextEditingValue, HapticFeedback, SystemSound, SystemSoundType;
import 'package:http/http.dart' as http;
import '../api.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

// RANG QOIDASI (DESIGN_SPEC §1): kirim -> p.mint, chiqim -> p.coral, AI/havola -> p.cyan.
// INPUT'dagi summa HAR DOIM p.coral — bu input FAQAT xarajat yozadi (store
// xarPick_ 'daromad'ni ham 'xarajat'ga o'giradi), kirim esa Daromad paneli
// ichidan kiritiladi. Papka kartasidagi chiqim summasi neytral (p.t1) — dizayn §5.11.

/// Diagonal gradientlar (ikonka qutilari) — DESIGN_SPEC §5.11 papka ranglari
const LinearGradient _gMintCyan = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kMint, kCyan]);
const LinearGradient _gPinkViolet = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF472B6), kViolet]);
const LinearGradient _gAmberCoral = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kAmber, kCoral]);

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

  // Qayta-tartib siljish animatsiyasi: nom -> eski o'rnidan px farqi (bir martalik)
  Map<String, Offset> _reShift = {};
  int _reEpoch = 0; // har bo'shatishda yangi animatsiya kaliti
  Timer? _reClearT;

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
  // Ko'chirish kartasidagi "Boshqa nom" maydoni — xuddi shu sabab barqaror
  final TextEditingController _mvCtl = TextEditingController();

  // ---- #15v2/#35/#36: modal holatlari (ekran-lokal) ----
  Map<String, dynamic>? _rowMenu; // ⋮ menyu: {'edit': fn?, 'move': fn?, 'del': fn}
  bool _perMenu = false; // davr filtri — header ostidagi anchored dropdown
  Map<String, dynamic>? _delAsk; // o'chirish tasdiqi: {'title', 'run': fn}
  Map<String, dynamic>? _incEdit; // kirim tahriri: {'id'}
  bool _incNew = false; // yangi sub-papka modali
  bool _mBusy = false; // modal ichida server kutilmoqda
  final TextEditingController _ieAmt = TextEditingController();
  final TextEditingController _ieNote = TextEditingController();
  final TextEditingController _inName = TextEditingController();

  @override
  void dispose() {
    _reClearT?.cancel();
    _fCtl.dispose();
    _mvCtl.dispose();
    _ieAmt.dispose();
    _ieNote.dispose();
    _inName.dispose();
    super.dispose();
  }

  // ---- l10n zaxira: kalit hali qo'shilmagan bo'lsa o'zbekcha matn ----
  String _t(String key, String fb) => (store.L()[key] as String?) ?? fb;
  String _tf(String key, Map<String, String> vars, String fb) {
    var s = (store.L()[key] as String?) ?? fb;
    vars.forEach((k, val) => s = s.replaceAll('{$k}', val));
    return s;
  }

  // ---- Modul obunasi (xarajat) — home_hub._modOf bilan bir xil HIMOYALI o'qish:
  // kalitlar yo'q bo'lsa "bepul" deb qaraladi, ilova buzilmaydi ----
  Map<String, dynamic>? _modXar(Map<String, dynamic> v) {
    final raw = v['modSubs'];
    if (raw is! List) return null;
    for (final e in raw) {
      if (e is Map && e['module'] == 'xarajat') return e.cast<String, dynamic>();
    }
    return null;
  }

  bool _isPro(Map<String, dynamic> v) =>
      v['modSubsLegacy'] == true || _modXar(v)?['active'] == true;

  void _openPaywall(Map<String, dynamic> v) {
    final f = v['openPaywall'];
    if (f is Function) f('xarajat');
  }

  /// Papka ikonka qutisi gradienti (DESIGN_SPEC §5.11): transport → brend,
  /// oziq-ovqat → mint→cyan, uy → pink→violet, boshqa → amber→coral,
  /// kirim → mint→cyan, qolganlari — nomdan barqaror halqa rangi.
  static LinearGradient _folderGrad(String name, bool inc) {
    if (inc) return _gMintCyan;
    switch (CatIcon.glyphFor(name)) {
      case 'bus':
      case 'taxi':
        return Tb.brandDiag;
      case 'bowl':
      case 'coffee':
        return _gMintCyan;
      case 'home':
        return _gPinkViolet;
      case 'box':
        return _gAmberCoral;
      default:
        return Tb.ringFor(name);
    }
  }

  /// Papka ikonkasi: 4 asosiy toifa — Material ikonka (spec), qolganlari —
  /// mavjud mazmunli CatIcon glifi (oq, gradient quti ustida).
  static Widget _folderIcon(String name, double size) {
    IconData? ic;
    switch (CatIcon.glyphFor(name)) {
      case 'bus':
      case 'taxi':
        ic = Icons.directions_car_outlined;
        break;
      case 'bowl':
      case 'coffee':
        ic = Icons.restaurant_outlined;
        break;
      case 'home':
        ic = Icons.home_outlined;
        break;
      case 'box':
      case 'bag':
        ic = Icons.shopping_bag_outlined;
        break;
      case 'folder':
        ic = Icons.folder_outlined;
        break;
    }
    if (ic != null) return Icon(ic, size: size, color: Colors.white);
    return CatIcon(cat: name, size: size * 0.95, color: Colors.white);
  }

  /// Suzuvchi kartalar (confirm / papka tahriri / ko'chirish / modal) — kontent
  /// ustida turadi, shuning uchun shaffofsiz surface + shisha chegara + soya.
  BoxDecoration _floatDeco(Pal p) => BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.glassBd),
        borderRadius: BorderRadius.circular(Tb.rCard),
        boxShadow: Tb.panelShadow,
      );

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
    // Bekor qilish tugmali toast — bosilsa PATCH eski papkaga qaytaradi
    store.xfMovedToast_(id: '${mv['id']}', oldCat: '${mv['cat']}', newCat: srvCat,
        desc: '${mv['desc']}', amount: mv['a'] as int? ?? 0);
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

    // Qayta-tartib: muzlatish bo'shagach store ESKI tartibni bir martalik beradi —
    // har karta eski o'rnidan yangi o'rniga siljib borishi uchun px farqini hisoblaymiz.
    // Filtr/davr almashuvi bu yo'ldan O'TMAYDI (u data swap — darhol qayta chiziladi).
    final reFrom = (v['xfReorderFrom'] as List?)?.cast<String>();
    if (reFrom != null) {
      (v['xfReorderTaken'] as Function)();
      final newOrder = [
        for (final f in (v['xfInFolders'] as List).cast<Map<String, dynamic>>()) '${f['name']}',
        for (final f in (v['xfOutFolders'] as List).cast<Map<String, dynamic>>()) '${f['name']}',
      ];
      final shifts = _calcReorderShifts(reFrom, newOrder);
      if (shifts.isNotEmpty) {
        _reShift = shifts;
        _reEpoch++;
        // Animatsiya tugagach siljish xaritasi tozalanadi (ortiqcha wrap qolmasin)
        _reClearT?.cancel();
        _reClearT = Timer(const Duration(milliseconds: 450), () {
          if (mounted && _reShift.isNotEmpty) setState(() => _reShift = {});
        });
      }
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
                padding: const EdgeInsets.fromLTRB(Tb.padX, 20, Tb.padX, 210),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (v['xfEmptyAll'] == true) _emptyAll(p),
                    // BITTA uzluksiz grid: kirim papkalari BOSHIDA, keyin chiqim
                    // (foydalanuvchi so'rovi: alohida bo'limlarga ajratilmaydi)
                    if ((v['xfInFolders'] as List).isNotEmpty ||
                        (v['xfOutFolders'] as List).isNotEmpty) ...[
                      _cap(store.L()['capFolders'] as String, p),
                      const SizedBox(height: 12),
                      _grid([
                        ...(v['xfInFolders'] as List).cast<Map<String, dynamic>>(),
                        ...(v['xfOutFolders'] as List).cast<Map<String, dynamic>>(),
                      ], p),
                      const SizedBox(height: 24),
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

        // ------- #15v2/#35/#36: modallar (hamma narsaning ustida) -------
        if (_perMenu) _perMenuModal(v, p),
        if (_rowMenu != null) _menuModal(p),
        if (_delAsk != null) _delModal(p),
        if (_incEdit != null) _incEditModal(v, p),
        if (_incNew) _incNewModal(v, p),
      ],
    );
  }

  // ================= #15v2/#35/#36 MODALLAR =================

  /// Qoraytirilgan fon + markazda karta (tashqarisi bosilsa yopiladi)
  Widget _scrimCard(Pal p, VoidCallback close, Widget card) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _mBusy ? null : close,
        child: Container(
          color: p.dim,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: GestureDetector(onTap: () {}, child: card),
        ),
      ),
    );
  }

  BoxDecoration _modalDeco(Pal p) => _floatDeco(p);

  /// Davr filtri — header trigger ostidagi ANCHORED dropdown (home.dart
  /// idiomi 1:1: shaffof tap-away to'siq + karta; dim YO'Q). Joriy davr —
  /// 6px nuqta bilan. "Maxsus davr" — tizim date-range picker'i.
  Widget _perMenuModal(Map<String, dynamic> v, Pal p) {
    final cur = '${v['xfPerKind']}';
    final opts = (v['xfPerOpts'] as List).cast<Map<String, dynamic>>();
    return Positioned.fill(
      child: Stack(
        children: [
          // Shaffof to'liq-ekran to'siq — tashqarisi bosilsa yopiladi
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _perMenu = false),
            child: const SizedBox.expand(),
          ),
          Positioned(
            // Header: top 12 + qator 44 (BackBtn balandligi) + 4 = trigger (subtitle) pasti
            top: 60,
            // Trigger chap cheti: 20 (header pad) + 44 (BackBtn) + 12 (oraliq)
            left: 76,
            child: Container(
              constraints: const BoxConstraints(minWidth: 186),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border.all(color: p.glassBd),
                borderRadius: BorderRadius.circular(Tb.rRow),
                boxShadow: Tb.panelShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Tb.rRow),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < opts.length; i++)
                        _perItem(p, '${opts[i]['label']}', cur == opts[i]['k'],
                            i == 0, () => _perPick(v, '${opts[i]['k']}')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Davr varianti qatori: 14px yorliq, tanlanganida w600 + o'ngda 6px cyan
  /// nuqta, qatorlar orasida hairline.
  Widget _perItem(Pal p, String label, bool on, bool first, VoidCallback onTap) {
    return Tap(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: first
            ? null
            : BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Tx(label, size: 14, w: on ? FontWeight.w600 : FontWeight.w500, color: on ? p.ink : p.t1),
            if (on) ...[
              const SizedBox(width: 12),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: p.cyan, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _perPick(Map<String, dynamic> v, String k) async {
    setState(() => _perMenu = false);
    if (k != 'custom') {
      (v['xfPerPick'] as Function)(k);
      return;
    }
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 6)),
        end: now,
      ),
    );
    if (range == null || !mounted) return;
    (v['xfPerCustom'] as Function)(range.start, range.end);
  }

  /// #36: ⋮ menyu — Tahrirlash / Ko'chirish / O'chirish
  Widget _menuModal(Pal p) {
    final m = _rowMenu!;
    final hasEdit = m['edit'] != null;
    final hasMove = m['move'] != null;
    return _scrimCard(
      p,
      () => setState(() => _rowMenu = null),
      Container(
        width: 260,
        clipBehavior: Clip.antiAlias,
        decoration: _modalDeco(p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasEdit)
              ListRow(
                icon: Icons.edit_outlined,
                title: _t('btnEdit', 'Tahrirlash'),
                chevron: false,
                onTap: () {
                  final f = m['edit'] as Function;
                  setState(() => _rowMenu = null);
                  f();
                },
              ),
            if (hasMove)
              ListRow(
                icon: Icons.folder_outlined,
                title: _t('btnMove', "Ko'chirish"),
                chevron: false,
                onTap: () {
                  final f = m['move'] as Function;
                  setState(() => _rowMenu = null);
                  f();
                },
              ),
            ListRow(
              icon: Icons.delete_outline_rounded,
              iconColor: p.coral,
              title: _t('btnDelete', "O'chirish"),
              titleColor: p.coral,
              chevron: false,
              last: true,
              onTap: () {
                (m['del'] as Function)();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// #35: o'chirish tasdiqi — modal ogohlantirish
  Widget _delModal(Pal p) {
    final d = _delAsk!;
    return _scrimCard(
      p,
      () => setState(() => _delAsk = null),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: _modalDeco(p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tx(_t('xfDelAskTitle', "Yozuv o'chirilsinmi?"), size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head),
            const SizedBox(height: 8),
            // Yozuv nomi to'liq ko'rinsin — "..." bilan kesilmaydi
            Tx('${d['title']}', size: 15, color: p.t1, lh: 20),
            const SizedBox(height: 4),
            Tx(_t('xfDelAskSub', "Tasdiqlasangiz yozuv o'chiriladi."), size: 13, color: p.t3),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GlassBtn(
                    label: _t('btnCancel', 'Bekor qilish'), h: 48, fs: 15,
                    onTap: () => setState(() => _delAsk = null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SolidBtn.coral(
                    _t('btnDelete', "O'chirish"),
                    () {
                      final run = d['run'] as Function;
                      setState(() => _delAsk = null);
                      run(); // karta "o'chirilmoqda" spinneriga o'tadi (store xfDeleting)
                    },
                    h: 48,
                    fs: 15,
                    icon: Icons.delete_outline_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _mFieldDeco(Pal p, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: tbStyle(size: 15, color: p.t5),
        isDense: true,
        filled: true,
        fillColor: p.glass,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Tb.rKey), borderSide: BorderSide(color: p.glassBd)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tb.rKey), borderSide: BorderSide(color: p.glassBd)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Tb.rKey), borderSide: BorderSide(color: p.violet.withValues(alpha: .6))),
      );

  /// #15v2: kirim yozuvini tahrirlash (summa + izoh)
  Widget _incEditModal(Map<String, dynamic> v, Pal p) {
    return _scrimCard(
      p,
      () => setState(() => _incEdit = null),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: _modalDeco(p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tx(_t('xfIncEditTitle', 'Kirimni tahrirlash'), size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head),
            const SizedBox(height: 16),
            TextField(
              controller: _ieAmt,
              keyboardType: TextInputType.number,
              inputFormatters: [_ThousandsFmt()], // 1 234 567 guruhlash (add-bar bilan bir xil)
              style: tbStyle(size: 20, w: FontWeight.w600, color: p.ink, tab: true),
              cursorColor: p.cyan,
              decoration: _mFieldDeco(p, _t('xfIncAmtHint', 'Summa')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ieNote,
              style: tbStyle(size: 15, color: p.ink),
              cursorColor: p.cyan,
              decoration: _mFieldDeco(p, _t('xfIncNoteHint', 'Izoh (ixtiyoriy)')),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GlassBtn(
                    label: _t('btnCancel', 'Bekor qilish'), h: 48, fs: 15,
                    onTap: () { if (!_mBusy) setState(() => _incEdit = null); },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GradientBtn(
                    label: _t('btnSave', 'Saqlash'), h: 48, fs: 15, loading: _mBusy, glow: false,
                    onTap: () async {
                      if (_mBusy) return;
                      setState(() => _mBusy = true);
                      final ok = await (v['xfIncEditSave'] as Future<bool> Function(String, String, String))(
                          '${_incEdit!['id']}', _ieAmt.text, _ieNote.text);
                      if (!mounted) return;
                      setState(() {
                        _mBusy = false;
                        if (ok) _incEdit = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// #15v2: yangi sub-daromad papkasi yaratish
  Widget _incNewModal(Map<String, dynamic> v, Pal p) {
    return _scrimCard(
      p,
      () => setState(() => _incNew = false),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: _modalDeco(p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tx(_t('xfIncNewTitle', 'Yangi daromad manbasi'), size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head),
            const SizedBox(height: 6),
            Tx(_t('xfIncNewSub', "Masalan: dokon, oylik, ijara — '@' o'zi qo'shiladi"),
                size: 14, color: p.t2, lh: 19),
            const SizedBox(height: 16),
            TextField(
              controller: _inName,
              autofocus: true,
              style: tbStyle(size: 15, w: FontWeight.w600, color: p.ink),
              cursorColor: p.cyan,
              decoration: _mFieldDeco(p, _t('xfIncNewHint', '@nomi')),
              onSubmitted: (_) => _incCreateGo(v),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GlassBtn(
                    label: _t('btnCancel', 'Bekor qilish'), h: 48, fs: 15,
                    onTap: () { if (!_mBusy) setState(() => _incNew = false); },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GradientBtn(
                    label: _t('btnCreate', 'Yaratish'), h: 48, fs: 15, loading: _mBusy, glow: false,
                    onTap: () => _incCreateGo(v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _incCreateGo(Map<String, dynamic> v) async {
    if (_mBusy) return;
    setState(() => _mBusy = true);
    final ok = await (v['xfIncCreate'] as Future<bool> Function(String))(_inName.text);
    if (!mounted) return;
    setState(() {
      _mBusy = false;
      if (ok) {
        _incNew = false;
        _inName.clear();
      }
    });
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
      // His-tuyg'u: qo'nish zarbi + yumshoq tizim tovushi (emotsiya). Partiyaning
      // OXIRGI qo'nishi kuchliroq (medium) — "yakunlandi" hissi. Ikkala platformada
      // bir xil API (HapticFeedback/SystemSound), qo'shimcha paket/asset yo'q.
      if (i == events.length - 1) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      SystemSound.play(SystemSoundType.click);
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
    // Iz va nafas-glow: kirim — mint, chiqim — brend (violet) — chip o'zi gradient pill
    final glow = inc ? p.mint : p.violet;
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
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              // Dizayn §5.11: chip — brend gradient pill (kirim: mint→cyan)
                              gradient: inc ? _gMintCyan : Tb.brand,
                              borderRadius: BorderRadius.circular(Tb.rPill),
                              boxShadow: [
                                ...Tb.glow,
                                // Parvoz cho'qqisida glow kuchayadi, qo'nishga so'nadi
                                BoxShadow(
                                  color: glow.withValues(alpha: .35 * breathe + .10),
                                  blurRadius: 22 + 12 * breathe,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tx('${e['emoji']} ${e['cat']}', size: 14, w: FontWeight.w600, color: Colors.white, font: TbFont.body),
                                const SizedBox(width: 8),
                                Tx('${e['amtTxt']}', size: 14, w: FontWeight.w600, color: Colors.white, tab: true),
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

  // ================= SARLAVHA (DESIGN_SPEC §5.11: back + title/davr + jurnal + PRO) =================
  // ScreenHeader tuzilmasi 1:1 (BackBtn · 20/600 head · 13 t2 subtitle · trailing), lekin
  // subtitle BOSILADI — u davr filtri (dropdown) triggeri; shu sabab qo'lda yig'ilgan.
  Widget _header(Map<String, dynamic> v, Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 0),
      child: Row(
        children: [
          BackBtn(onTap: () => (v['xfBack'] as Function)()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Tx(store.L()['xarTitle'] as String, size: 20, w: FontWeight.w600, color: p.ink,
                    font: TbFont.head, maxLines: 1, ellipsis: true),
                // Davr filtri (dropdown) — subtitle: "Sentabr 2026 ▾" (xfMonth == xfPerLabel)
                Tap(
                  onTap: () => setState(() => _perMenu = true),
                  scale: 0.98,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Tx('${v['xfMonth']}', size: 13, color: p.t2, maxLines: 1, ellipsis: true),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: p.t2),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Jurnal tugmasi (soat + yangilik nuqtasi)
          Stack(
            clipBehavior: Clip.none,
            children: [
              GlassIconBtn(
                icon: Icons.schedule_rounded,
                onTap: () => (v['xfLogToggle'] as Function)(),
                size: 40,
                iconSize: 20,
              ),
              if (v['xfLogDot'] == true)
                Positioned(
                  top: 1, right: 1,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: p.cyan,
                      border: Border.all(color: p.bg, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          _proPill(v, p),
        ],
      ),
    );
  }

  /// h36 gradient pill: obuna faol — "PRO" (bosilmaydi); aks holda "PRO oling" →
  /// modul paywall'i (v['openPaywall']('xarajat') — hub kartasi bilan bir xil callback).
  Widget _proPill(Map<String, dynamic> v, Pal p) {
    final pro = _isPro(v);
    final pill = Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: Tb.brand,
        borderRadius: BorderRadius.circular(Tb.rPill),
        boxShadow: pro ? null : Tb.glow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Tx(pro ? 'PRO' : 'PRO oling', // TODO l10n ("PRO oling" — dizayn §5.11 matni)
              size: 13, w: FontWeight.w700, color: Colors.white, font: TbFont.body, maxLines: 1),
        ],
      ),
    );
    if (pro) return pill;
    return Tap(onTap: () => _openPaywall(v), child: pill);
  }

  // ================= JAMI KARTASI (DESIGN_SPEC §5.11) =================
  // Chap: davr balansi (count-up), kirim/chiqim, oylik limit + qoldiq.
  // O'ng: 110px halqa (limitdan foiz) yoki limit yo'q bo'lsa "Chegarani qo'yish" CTA.
  // Limit mantig'i — store: xarLimit / limEdit (limEditToggle, limEditSet, limSave).
  Widget _balance(Map<String, dynamic> v, Pal p) {
    final L0 = store.L();
    final lim = store.S['xarLimit'] as int? ?? 0;
    final hasLim = lim > 0;
    final editing = v['limEditOpen'] == true;
    final pctInt = (v['limPct'] as int? ?? 0).clamp(0, 100);
    final over = hasLim && pctInt >= 100;
    final limColor = over ? p.coral : p.mint;
    void toggleEdit() {
      final f = v['limEditToggle'];
      if (f is Function) f();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 0),
      child: GlassCard(
        r: Tb.rCard,
        pad: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tx('${v['xfBalCap']}', size: 14, color: p.t2, maxLines: 1, ellipsis: true),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Flexible — FittedBox chegaralangan slotda ishlasin (aks holda Row
                          // cheksiz kenglik beradi va uzun summa baribir overflow bo'ladi)
                          Flexible(
                            child: _AnimNum(
                              value: v['xfBalVal'] as int? ?? 0,
                              prefix: v['xfBalPos'] == true ? '+' : '−',
                              size: 32, weight: FontWeight.w600,
                              color: v['xfBalPos'] == true ? p.mint : p.coral, ls: -0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Tx(L0['som'] as String, size: 14, color: p.t2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Tx(L0['income'] as String, size: 13, color: p.t3),
                          Flexible(
                            child: _AnimNum(value: v['xfInVal'] as int? ?? 0, prefix: '+',
                                size: 13, weight: FontWeight.w600, color: p.mint),
                          ),
                          const SizedBox(width: 14),
                          Tx(L0['expense'] as String, size: 13, color: p.t3),
                          Flexible(
                            child: _AnimNum(value: v['xfOutVal'] as int? ?? 0, prefix: '−',
                                size: 13, weight: FontWeight.w600, color: p.coral),
                          ),
                        ],
                      ),
                      if (hasLim) ...[
                        const SizedBox(height: 12),
                        Tap(
                          onTap: toggleEdit,
                          scale: 0.98,
                          child: Tx('Limit ${v['limTotTxt'] ?? ''}', // TODO l10n ("Limit" — barcha tillarda o'xshash)
                              size: 14, color: p.t2, maxLines: 1, ellipsis: true),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Tx('${v['limRemainTxt'] ?? ''}', size: 15, w: FontWeight.w600,
                              color: limColor, maxLines: 1),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (hasLim)
                  Tap(
                    onTap: toggleEdit,
                    child: _LimitRing(
                      pct: pctInt / 100,
                      color: over ? p.coral : p.cyan,
                      track: p.ink.withValues(alpha: .08),
                      label: '${v['limPctTxt'] ?? '$pctInt%'}',
                      sub: 'limitdan', // TODO l10n
                    ),
                  )
                else
                  // Limit yo'q — "Chegarani qo'yish" CTA (GlassBtn'ga aniq kenglik: Row ichida
                  // Container shrink-wrap bo'lib, matn chetga yopishib qolmasin)
                  SizedBox(
                    width: 132,
                    child: GlassBtn(
                      label: editing
                          ? (L0['btnCancelShort'] as String? ?? 'Bekor')
                          : (L0['aiBudgetSet'] as String? ?? "Chegarani qo'yish"),
                      onTap: toggleEdit,
                      h: 44,
                      fs: 13,
                    ),
                  ),
              ],
            ),
            // Limit tahriri (inline): summa maydoni + Saqlash
            if (editing) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GlassField(
                      h: 48,
                      icon: Icons.account_balance_wallet_outlined,
                      focused: true,
                      child: StoreField(
                        value: '${v['limEditVal'] ?? ''}',
                        onChanged: (t) => (v['limEditSet'] as Function)(t),
                        hint: L0['xfIncAmtHint'] as String? ?? 'Summa',
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: tbStyle(size: 16, w: FontWeight.w600, color: p.ink, tab: true),
                        onSubmit: () => (v['limSave'] as Function)(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 112,
                    child: GradientBtn(
                      label: L0['btnSave'] as String? ?? 'Saqlash',
                      onTap: () => (v['limSave'] as Function)(),
                      h: 48,
                      fs: 14,
                      glow: false,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ================= PAPKALAR =================
  Widget _cap(String t, Pal p) => Cap(t);

  /// Eski/yangi indekslardan px siljish: grid 2 ustunli, kartalar bir xil
  /// o'lchamda — qadam AVVALGI kadrda chizilgan real karta RenderBox'idan
  /// o'lchanadi (taxminiy konstanta emas). Karta topilmasa — animatsiyasiz.
  Map<String, Offset> _calcReorderShifts(List<String> from, List<String> to) {
    RenderBox? sample;
    for (final n in to) {
      final b = _fk[n]?.currentContext?.findRenderObject();
      if (b is RenderBox && b.hasSize) {
        sample = b;
        break;
      }
    }
    if (sample == null) return {};
    final stepX = sample.size.width + 12; // ustunlar orasi (SizedBox width: 12)
    final stepY = sample.size.height + 12; // qatorlar orasi (SizedBox height: 12)
    final res = <String, Offset>{};
    for (var ni = 0; ni < to.length; ni++) {
      final oi = from.indexOf(to[ni]);
      if (oi < 0 || oi == ni) continue; // yangi karta yoki joyi o'zgarmagan
      final dx = ((oi % 2) - (ni % 2)) * stepX;
      final dy = ((oi ~/ 2) - (ni ~/ 2)) * stepY;
      if (dx != 0 || dy != 0) res[to[ni]] = Offset(dx, dy);
    }
    return res;
  }

  Widget _grid(List<Map<String, dynamic>> fs, Pal p) {
    final rows = <Widget>[];
    for (var i = 0; i < fs.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _folderCard(fs[i], p)),
          const SizedBox(width: 12),
          Expanded(child: i + 1 < fs.length ? _folderCard(fs[i + 1], p) : const SizedBox()),
        ],
      ));
      if (i + 2 < fs.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  Widget _folderCard(Map<String, dynamic> f, Pal p) {
    final inc = f['inc'] == true;
    final name = '${f['name']}';
    // Ghost: chip hali uchmoqda — karta nishon sifatida xira turadi, summa o'rnida "···"
    final ghost = f['ghost'] == true;
    final pc = _pulse[name] ?? 0;

    // Karta ichi (DESIGN_SPEC §5.11): 44px r14 gradient ikonka qutisi · nom 15/600 ·
    // summa 15 num (kirim mint, chiqim neytral t1) · jonli sparkline (cyan).
    // border — qo'nish paytida cyan halqa (pastda TweenAnimationBuilder bilan so'nadi).
    Widget inner(Color border) => GlassCard(
          key: _keyFor(name),
          r: Tb.rRow,
          pad: const EdgeInsets.all(16),
          border: border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44, height: 44, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: _folderGrad(name, inc),
                      borderRadius: BorderRadius.circular(Tb.rIcon),
                    ),
                    child: _folderIcon(name, 22),
                  ),
                  if (f['isNew'] == true) PillBadge.cyan(store.L()['newBadge'] as String),
                ],
              ),
              const SizedBox(height: 12),
              Tx(name, size: 15, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: ghost
                        ? Tx('· · ·', size: 15, w: FontWeight.w600, color: p.t4, tab: true)
                        : _AnimNum(
                            value: f['totalVal'] as int? ?? 0,
                            prefix: inc ? '+' : '−',
                            size: 15, weight: FontWeight.w600,
                            color: inc ? p.mint : p.t1,
                            fromZero: true, // yangi papka 0 dan sanab chiqadi
                          ),
                  ),
                  if (inc) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.north_east_rounded, size: 14, color: p.mint),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity, height: 22,
                child: _AnimSpark(
                  pts: (f['spark'] as List).cast<double>(),
                  color: inc ? p.mint : p.cyan,
                ),
              ),
            ],
          ),
        );

    // Qo'nish halqasi: chip qo'ngach chegara cyan yonadi va 0.9s ichida so'nadi
    final body = pc > 0
        ? TweenAnimationBuilder<double>(
            key: ValueKey('ring-$name-$pc'),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeIn,
            builder: (_, t, __) => inner(Color.lerp(p.cyan, p.glassBd, t) ?? p.glassBd),
          )
        : inner(p.glassBd);

    // Uzoq bosish — papkani TAHRIRLASH (nomlash/arxivlash, XOTIRA §4 CRUD).
    // Ghost karta hali serverda yo'q; kirim papkasi ('Daromad') tizim boshqaruvida.
    Widget card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: f['open'] as VoidCallback?,
      onLongPress: ghost ? null : () => _openFolderEdit(f),
      child: body,
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
    // pc — yuqorida (_folderCard boshida) hisoblangan
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

    // Qayta-tartib siljishi: karta ESKI o'rnidan joriy o'rniga suriladi (sanash
    // tugagach muzlatish bo'shaganda) — joy almashuvi ko'zga ko'rinadi
    final sh = _reShift[name];
    if (sh != null) {
      card = TweenAnimationBuilder<double>(
        key: ValueKey('reorder-$name-$_reEpoch'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        builder: (_, t, child) => Transform.translate(
          offset: Offset(sh.dx * (1 - t), sh.dy * (1 - t)),
          child: child,
        ),
        child: card,
      );
    }
    return card;
  }

  Widget _emptyAll(Pal p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        r: Tb.rCard,
        pad: const EdgeInsets.symmetric(vertical: 40, horizontal: 28),
        child: Column(
          children: [
            Container(
              width: 56, height: 56, alignment: Alignment.center,
              decoration: BoxDecoration(gradient: Tb.brandDiag, borderRadius: BorderRadius.circular(18), boxShadow: Tb.glow),
              child: const Icon(Icons.auto_awesome_rounded, size: 26, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Tx(store.L()['xarEmptyTitle'] as String, size: 17, w: FontWeight.w600, color: p.ink,
                font: TbFont.head, align: TextAlign.center),
            const SizedBox(height: 6),
            Tx(store.L()['xarEmptySub'] as String, size: 14,
                color: p.t2, align: TextAlign.center, lh: 19),
          ],
        ),
      ),
    );
  }

  // ================= ANIQLANMAGAN (tray) =================
  // DESIGN_SPEC §5.11: Cap + son → punktir chegarali (white15, r20) tray, ichida h40
  // pill chiplar "Nom · summa". Chip bosilsa (toggle) ostida papka tanlash paneli
  // ochiladi — oqim avvalgidek (xfTrayToggle / xfTrayPick / qo'lda nom).
  Widget _tray(Map<String, dynamic> v, Pal p) {
    final L0 = store.L();
    final rows = (v['xfTrayRows'] as List).cast<Map<String, dynamic>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Cap(L0['unidentifiedCap'] as String),
            const SizedBox(width: 8),
            PillBadge.coral('${v['xfTrayCount']}', h: 20),
          ],
        ),
        const SizedBox(height: 12),
        _Dashed(
          color: p.ink.withValues(alpha: .15),
          radius: Tb.rRow,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.ink.withValues(alpha: .02),
              borderRadius: BorderRadius.circular(Tb.rRow),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Tx(_t('xfTrayEmpty', 'AI tanimagan xarajatlar shu yerga tushadi'),
                        size: 14, color: p.t5, align: TextAlign.center),
                  ),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    for (final t in rows)
                      _Shake(
                        key: ValueKey('shake-${t['id']}'),
                        child: Tap(
                          onTap: t['toggle'],
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: t['open'] == true ? p.ink : p.glass2,
                              border: Border.all(color: t['open'] == true ? p.ink : p.glassBd),
                              borderRadius: BorderRadius.circular(Tb.rPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 170),
                                  child: Tx('${t['text']}', size: 14, w: FontWeight.w600,
                                      color: t['open'] == true ? p.bg : p.ink, maxLines: 1, ellipsis: true, font: TbFont.body),
                                ),
                                const SizedBox(width: 6),
                                Tx('${t['amtTxt']}', size: 13, w: FontWeight.w600,
                                    color: t['open'] == true ? p.bg.withValues(alpha: .7) : p.t4, tab: true),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Ochiq chip(lar) uchun papka tanlash paneli
                for (final t in rows)
                  if (t['open'] == true) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Tx('${t['text']} · ${t['amtTxt']} ${L0['som'] as String}',
                              size: 13, w: FontWeight.w600, color: p.coral, maxLines: 1, ellipsis: true),
                        ),
                        const SizedBox(width: 8),
                        Tx(L0['pickFolderRow'] as String, size: 12, color: p.t4),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (t['naming'] == true)
                      // Qo'lda yangi papka nomi
                      Row(
                        children: [
                          Expanded(
                            child: GlassField(
                              h: 44,
                              focused: true,
                              child: TextField(
                                autofocus: true,
                                onChanged: t['nameSet'],
                                onSubmitted: (_) => (t['nameOk'] as Function)(),
                                style: tbStyle(size: 14, color: p.ink),
                                cursorColor: p.cyan,
                                decoration: InputDecoration(
                                  isDense: true, isCollapsed: true, border: InputBorder.none,
                                  hintText: L0['newFolderHint'] as String,
                                  hintStyle: tbStyle(size: 14, color: p.t5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 76,
                            child: GradientBtn(
                              label: L0['btnOk'] as String,
                              onTap: () => (t['nameOk'] as Function)(),
                              h: 44, fs: 14, glow: false,
                            ),
                          ),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          for (final c in (t['chips'] as List).cast<Map<String, dynamic>>())
                            // AI taklifi (✨ yangi) — tanlangan (oq) chip ko'rinishida ajralib turadi
                            PillChip(
                              label: '${c['label']}',
                              selected: c['isNew'] == true,
                              onTap: c['pick'],
                              h: 36,
                            ),
                        ],
                      ),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================= PAPKA TAFSILOTI =================
  Widget _detail(Map<String, dynamic> v, Pal p) {
    final inc = v['xfDInc'] == true;
    final name = '${v['xfDName']}';
    return ScreenBg(
      child: Column(
        children: [
          // Sarlavha: BackBtn · 40px gradient ikonka qutisi · nom 17/600 + son 13 t2 · sparkline
          Padding(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 0),
            child: Row(
              children: [
                BackBtn(onTap: () => (v['xfDetailClose'] as Function)()),
                const SizedBox(width: 12),
                Container(
                  width: 40, height: 40, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: _folderGrad(name, inc),
                    borderRadius: BorderRadius.circular(Tb.rIcon),
                  ),
                  child: _folderIcon(name, 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tx(name, size: 17, w: FontWeight.w600, color: p.ink, font: TbFont.head, maxLines: 1, ellipsis: true),
                      Tx('${v['xfDCount']}', size: 13, color: p.t2, maxLines: 1, ellipsis: true),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60, height: 22,
                  child: _AnimSpark(
                    pts: (v['xfDSpark'] as List).cast<double>(),
                    color: inc ? p.mint : p.cyan,
                  ),
                ),
              ],
            ),
          ),
          // Jami kartasi
          Padding(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 4),
            child: GlassCard(
              r: Tb.rCard,
              pad: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: _AnimNum(
                      // 2026-08-03: har papka/manba O'Z animatsiya holatini oladi (key) —
                      // ilgari Daromad -> manba (yoki papka -> papka) o'tishda widget holati
                      // qayta ishlatilib, raqam OLDINGI sahifa summasidan PASTGA "sanab"
                      // tushardi. Endi sahifaga kirilganda doim 0 dan n ga O'SIB chiqadi;
                      // shu sahifada yangi kirim qo'shilsa — eski qiymatdan silliq davom etadi.
                      key: ValueKey('xfDSum|${v['xfDName']}|${v['xfIncMain']}'),
                      value: v['xfDTotalVal'] as int? ?? 0,
                      fromZero: true,
                      // #15v2: sub-daromadda QOLDIQ manfiy bo'lishi mumkin — prefiks store'dan
                      prefix: '${v['xfDPrefix'] ?? (inc ? '+' : '−')}',
                      size: 32, weight: FontWeight.w600,
                      // Kirim — mint (manfiy qoldiq coral), chiqim jami — coral
                      color: inc
                          ? (('${v['xfDPrefix'] ?? '+'}' == '−') ? p.coral : p.mint)
                          : p.coral,
                      ls: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Tx(store.L()['som'] as String, size: 14, color: p.t2),
                  ),
                ],
              ),
            ),
          ),
          // #15v2: Daromad — sub-papkalar + kirim-chiqim oqimi (alohida body)
          if (v['xfDIsIncome'] == true)
            Expanded(child: _incomeBody(v, p))
          else
          Expanded(
            child: v['xfDEmpty'] == true
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                    child: Column(
                      children: [
                        Tx(store.L()['xarEmptyTitle'] as String, size: 15, w: FontWeight.w600, color: p.ink,
                            align: TextAlign.center),
                        const SizedBox(height: 6),
                        Tx(store.L()['folderEmptySub'] as String, size: 14,
                            color: p.t3, align: TextAlign.center, lh: 19),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(Tb.padX, 8, Tb.padX, 210),
                    children: [
                      for (final g in (v['xfDGroups'] as List).cast<Map<String, dynamic>>()) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                          child: Cap('${g['label']}'),
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

  // ================= #15v2: DAROMAD BO'LIMI =================
  // Asosiy ko'rinish: sub-papkalar (nomi + QOLDIQ) + barcha kirim-chiqim oqimi.
  // Sub ko'rinish: kirim qo'shish paneli (summa+izoh) + shu manba oqimi.
  Widget _incomeBody(Map<String, dynamic> v, Pal p) {
    final main = v['xfIncMain'] == true;
    final flow = (v['xfIncFlow'] as List).cast<Map<String, dynamic>>();

    if (!main) {
      // ---- SUB ko'rinish ----
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 8, Tb.padX, 12),
            child: _IncomeAddBar(
              busy: v['xfIncBusy'] == true,
              onAdd: (a, n) => (v['xfAddIncome'] as Future<bool> Function(String, String))(a, n),
            ),
          ),
          Expanded(
            child: flow.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                    child: Tx(_t('xfIncSubEmpty', "Hali yozuv yo'q — yuqorida summa kiritib qo'shing"),
                        size: 14, color: p.t3, align: TextAlign.center, lh: 19),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(Tb.padX, 0, Tb.padX, 40),
                    children: [
                      for (final r in flow)
                        Padding(padding: const EdgeInsets.only(bottom: 8), child: _incFlowRow(r, p)),
                    ],
                  ),
          ),
        ],
      );
    }

    // ---- ASOSIY (Daromad) ko'rinish ----
    final subs = (v['xfIncSubRows'] as List).cast<Map<String, dynamic>>();
    final cards = <Widget>[
      for (final f in subs) _incSubCard(f, p),
      _incNewCard(p), // + Yangi manba
    ];
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cards[i]),
          const SizedBox(width: 12),
          Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
        ],
      ));
      if (i + 2 < cards.length) rows.add(const SizedBox(height: 12));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 8, Tb.padX, 40),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Cap(_t('xfIncSrcCap', 'MANBALAR')),
        ),
        ...rows,
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Cap(_t('xfIncFlowCap', 'HARAKATLAR')),
        ),
        if (flow.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Tx(_t('xfIncEmpty', "Hali harakat yo'q — manba ochib kirim qo'shing"),
                size: 14, color: p.t3, align: TextAlign.center, lh: 19),
          )
        else
          for (final r in flow)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: _incFlowRow(r, p)),
      ],
    );
  }

  /// Sub-daromad kartasi (GlassCard r20 pad16): @ ikonka qutisi · nomi ·
  /// QOLDIQ (katta, mint/coral) · kirimlar soni
  Widget _incSubCard(Map<String, dynamic> f, Pal p) {
    final name = '${f['name']}';
    return Tap(
      onTap: f['open'] as VoidCallback,
      child: GlassCard(
        r: Tb.rRow,
        pad: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40, alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: Tb.ringFor(name),
                borderRadius: BorderRadius.circular(Tb.rIcon),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 12),
            // Manba nomi to'liq ko'rinsin — 2 qatorgacha o'raladi
            Tx(name, size: 15, w: FontWeight.w600, color: p.ink, maxLines: 2),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Tx('${f['leftTxt']}', size: 16, w: FontWeight.w600,
                  color: f['neg'] == true ? p.coral : p.mint, tab: true, maxLines: 1),
            ),
            const SizedBox(height: 4),
            // Summali qator "..." bilan kesilmasin — torlik qilsa kichraytiriladi
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Tx('${f['n']} ${_t('xfIncCardN', 'ta kirim')} · ${f['inTxt']}',
                  size: 13, color: p.t3, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }

  /// "+ Yangi manba" kartasi (shtrixli)
  Widget _incNewCard(Pal p) {
    return Tap(
      onTap: () => setState(() { _incNew = true; _inName.clear(); }),
      child: _Dashed(
        color: p.ink.withValues(alpha: .15),
        radius: Tb.rRow,
        child: Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 140),
          decoration: BoxDecoration(
            color: p.ink.withValues(alpha: .02),
            borderRadius: BorderRadius.circular(Tb.rRow),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.glass2,
                  border: Border.all(color: p.glassBd),
                  borderRadius: BorderRadius.circular(Tb.rIcon),
                ),
                child: Icon(Icons.add_rounded, size: 22, color: p.t1),
              ),
              const SizedBox(height: 10),
              Tx(_t('xfIncNewCard', 'Yangi manba'), size: 14, w: FontWeight.w600, color: p.t2,
                  align: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  /// Oqim qatori: kirim (mint, ⋮ bilan) yoki @chiqim (coral).
  /// Chiqim bu yerda faqat ko'rinadi (tahriri o'z xarajat papkasida); ⋮da faqat o'chirish.
  Widget _incFlowRow(Map<String, dynamic> r, Pal p) {
    final inc = r['inc'] == true;
    return GlassCard(
      r: Tb.rRow,
      pad: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx('${r['title']}', size: 15, w: FontWeight.w500, color: p.ink),
                const SizedBox(height: 2),
                // Sana + papka nomi to'liq ko'rinsin — 2 qatorgacha o'raladi
                Tx(
                  '${r['when']}${(r['chip'] as String? ?? '').isNotEmpty ? ' · ${r['chip']}' : ''}',
                  size: 13, color: p.t4, maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tx('${r['amtTxt']}', size: 15, w: FontWeight.w600, color: inc ? p.mint : p.coral, tab: true),
          const SizedBox(width: 6),
          if (r['deleting'] == true)
            SizedBox(
              width: 32, height: 32,
              child: Center(
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(p.cyan)),
                ),
              ),
            )
          else
            _dotsBtn(
              p,
              onEdit: inc
                  ? () => setState(() {
                        _incEdit = {'id': r['id']};
                        _ieAmt.text = _groupDigits('${r['a']}'); // ochilishda ham 1 234 567 ko'rinishi
                        _ieNote.text = '${r['note'] ?? ''}';
                      })
                  : null,
              onDelete: () => _askDelete('${r['title']}', r['del'] as Function),
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
      scale: 0.99,
      child: GlassCard(
        r: Tb.rRow,
        pad: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PO 2026-07-28: izoh TO'LIQ ko'rinsin — maxLines olib tashlandi (o'rab yozadi)
                  Tx('${r['desc']}', size: 15, w: FontWeight.w500, color: p.ink),
                  const SizedBox(height: 2),
                  Tx('${r['time']}', size: 13, color: p.t4),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tx('${r['amtTxt']}', size: 15, w: FontWeight.w600, tab: true,
                // Kirim — mint, chiqim — coral (DESIGN_SPEC §1)
                color: r['inc'] == true ? p.mint : p.coral),
            const SizedBox(width: 6),
            // #35/#36: o'chirilayotganda spinner; aks holda 3-nuqta menyu (edit/delete)
            if (r['deleting'] == true)
              SizedBox(
                width: 32, height: 32,
                child: Center(
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(p.cyan)),
                  ),
                ),
              )
            else
              _dotsBtn(
                p,
                onEdit: () => (r['edit'] as Function)(),
                // Ko'chirish faqat chiqim yozuvida (kirim Daromad panelida yashaydi)
                onMove: r['inc'] == true ? null : () => _openMove(r, folderName),
                onDelete: () {
                  _askDelete('${r['desc']}', r['del'] as Function);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// #36: 3-nuqta (⋮) tugmasi — bosilsa yonida kichik menyu
  /// (Tahrirlash / Ko'chirish / O'chirish). null bo'lgan amal menyuda ko'rinmaydi.
  Widget _dotsBtn(Pal p, {Function? onEdit, Function? onMove, required Function onDelete}) {
    return GlassIconBtn(
      icon: Icons.more_horiz_rounded,
      onTap: () => setState(() => _rowMenu = {'edit': onEdit, 'move': onMove, 'del': onDelete}),
      size: 32,
      iconSize: 18,
      color: p.t2,
    );
  }

  /// #35: o'chirishdan oldin tasdiq modalini ochish
  void _askDelete(String title, Function run) {
    setState(() {
      _rowMenu = null;
      _delAsk = {'title': title, 'run': run};
    });
  }

  /// Dumaloq shisha ikonka tugmasi (eski imzo: glif '✕' / '✎' → Material ikonka)
  Widget _roundBtn(String glyph, dynamic onTap, Pal p, {double size = 32}) {
    final icon = glyph == '✎' ? Icons.edit_outlined : Icons.close_rounded;
    return GlassIconBtn(
      icon: icon,
      onTap: onTap is Function ? () => onTap() : null,
      size: size,
      iconSize: size * 0.55,
      color: p.t1,
    );
  }

  // ================= JURNAL =================
  Widget _logPanel(Map<String, dynamic> v, Pal p) {
    return ScreenBg(
      child: Column(
        children: [
          ScreenHeader(
            title: store.L()['logTitle'] as String,
            subtitle: store.L()['logSub'] as String,
            trailing: [
              GlassIconBtn(icon: Icons.close_rounded, onTap: () => (v['xfLogToggle'] as Function)()),
            ],
          ),
          Expanded(
            child: v['xfLogEmpty'] == true
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                    child: Column(
                      children: [
                        Tx(store.L()['logEmptyTitle'] as String, size: 15, w: FontWeight.w600, color: p.ink,
                            align: TextAlign.center),
                        const SizedBox(height: 6),
                        Tx(store.L()['logEmptySub'] as String,
                            size: 14, color: p.t3, align: TextAlign.center, lh: 19),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 210),
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
    final badge = type == 'add'
        ? PillBadge.mint('${o['badge']}', h: 20)
        : type == 'del'
            ? PillBadge.coral('${o['badge']}', h: 20)
            : PillBadge.muted('${o['badge']}', h: 20);
    return GlassCard(
      r: Tb.rRow,
      pad: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36, alignment: Alignment.center,
            decoration: BoxDecoration(color: p.glass2, borderRadius: BorderRadius.circular(12)),
            child: Tx('${o['emoji']}', size: 16, color: p.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${o['desc']}',
                        textScaler: TextScaler.noScaling,
                        // PO 2026-07-28: jurnal qatorida ham izoh to'liq o'raladi (kesilmaydi)
                        style: tbStyle(size: 15, w: FontWeight.w500, color: isDel ? p.t3 : p.ink).copyWith(
                          decoration: isDel ? TextDecoration.lineThrough : TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    badge,
                  ],
                ),
                const SizedBox(height: 2),
                Tx('${o['sub']}', size: 13, color: p.t4, maxLines: 1, ellipsis: true),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${o['amtTxt']}',
            textScaler: TextScaler.noScaling,
            style: tbStyle(
              size: 15, w: FontWeight.w600, tab: true,
              // Kirim mint, chiqim coral; o'chirilgan qator xira (t3) — lineThrough holati
              color: isDel ? p.t3 : (o['inc'] == true ? p.mint : p.coral),
            ).copyWith(decoration: isDel ? TextDecoration.lineThrough : TextDecoration.none),
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
  /// Input ustidagi yo'riqnoma (DESIGN_SPEC §5.11): bepul hisoblagich "3/5 bepul
  /// yozuv ishlatildi"; PRO — "PRO · Cheksiz xarajat yozuvi"; limit noma'lum yoki
  /// sinov qiymati (> kSubLimitDisplayMax, hub chipi bilan bir xil qoida) — avvalgi
  /// AI yo'riqnomasi. Qaytadi: [matn, rang].
  List<dynamic> _inputHint(Map<String, dynamic> v, Pal p) {
    final L0 = store.L();
    if (_isPro(v)) return ['PRO · ${L0['pwBenXar1'] as String? ?? 'Cheksiz xarajat yozuvi'}', p.cyan];
    final e = _modXar(v);
    final used = (e?['used'] as int?) ?? 0;
    final limit = (e?['limit'] as int?) ?? 0;
    if (e != null && limit > 0 && limit <= kSubLimitDisplayMax) {
      final txt = _tf('pwUsed', {'used': '$used', 'limit': '$limit'}, '$used/$limit bepul yozuv ishlatildi');
      return [txt, used >= limit ? p.amber : p.t4];
    }
    return [L0['xarInputHint'] as String, p.t4];
  }

  Widget _bottomOverlay(Map<String, dynamic> v, Pal p) {
    final hint = _inputHint(v, p);
    final empty = '${v['xarTextVal'] ?? ''}'.trim().isEmpty && v['xfBusy'] != true;
    return Container(
      // Pastki 16 (spec: left/right/bottom 16); SafeArea main.dart'da
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
      decoration: BoxDecoration(
        // Kontent ostida yumshoq so'nish — panel suzuvchi, matn o'qiladigan bo'lsin
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [p.bg.withValues(alpha: 0), p.bg.withValues(alpha: .85), p.bg.withValues(alpha: .95)],
          stops: const [0, .5, .85],
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
                height: 40,
                padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border.all(color: p.glassBd),
                  borderRadius: BorderRadius.circular(Tb.rPill),
                  boxShadow: Tb.panelShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 14, color: p.cyan),
                    const SizedBox(width: 6),
                    Tx(store.L()['editingLabel'] as String, size: 13, color: p.t2),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Tx('${v['xfEditLabel']}', size: 13, w: FontWeight.w600,
                          color: p.ink, maxLines: 1, ellipsis: true),
                    ),
                    const SizedBox(width: 6),
                    GlassIconBtn(
                      icon: Icons.close_rounded,
                      onTap: () => (v['xfEditCancel'] as Function)(),
                      size: 28, iconSize: 16, color: p.t1,
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
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                decoration: BoxDecoration(
                  color: p.isDark ? const Color(0xF21A1D28) : const Color(0xF2FFFFFF),
                  border: Border.all(color: p.ink.withValues(alpha: .15)),
                  borderRadius: BorderRadius.circular(Tb.rRow),
                  boxShadow: Tb.panelShadow,
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 18, color: p.mint),
                    const SizedBox(width: 8),
                    Expanded(child: Tx('${v['xfToastText']}', size: 14, w: FontWeight.w600, color: p.ink, maxLines: 2)),
                    if ('${v['xfToastBtn'] ?? (store.L()['btnCancelFull'] as String)}'.isNotEmpty)
                      TextBtn(
                        label: '${v['xfToastBtn'] ?? (store.L()['btnCancelFull'] as String)}',
                        onTap: () => (v['xfUndo'] as Function)(),
                        color: p.cyan,
                        h: 32,
                        fs: 14,
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

          // #15v2: Daromad sahifalarida pastki xarajat inputi KO'RINMAYDI
          if (v['xfHideInput'] != true) ...[
          // @ tanlov popupi — '@...' yozilganda manbalar ro'yxati (nomi + qoldiq)
          if (_atList(v).isNotEmpty) _atOverlay(v, p),
          // Yo'riqnoma / bepul limit hisoblagichi — inputdan yuqorida
          Center(
            child: Tx('${hint[0]}', size: 13, color: hint[1] as Color, maxLines: 1, ellipsis: true),
          ),
          const SizedBox(height: 8),
          // Matn input (rangli highlight bilan) + yuborish — BottomPanel h56
          // _inputKey — fly-chip start nuqtasi (avvalgidek shu qutidan hisoblanadi)
          BottomPanel(
            key: _inputKey,
            h: 56,
            padding: const EdgeInsets.only(left: 16, right: 6),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 20, color: p.cyan),
                const SizedBox(width: 8),
                Expanded(
                  child: _HlField(
                    value: '${v['xarTextVal'] ?? ''}',
                    onChanged: (t) => v['xarTextSet'](t),
                    hint: store.L()['xarInputHintEx'] as String,
                    onSubmit: v['xfSend'],
                  ),
                ),
                const SizedBox(width: 8),
                Tap(
                  onTap: v['xfSend'],
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: empty ? .45 : 1,
                    child: Container(
                      width: 44, height: 44, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: Tb.brandDiag,
                        boxShadow: empty ? null : Tb.glow,
                      ),
                      child: v['xfBusy'] == true
                          ? const _PulseDots(color: Colors.white)
                          : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ], // xfHideInput gate tugadi
        ],
      ),
    );
  }

  // ---- #15v2: @ tanlov popupi (asosiy inputda '@...' yozilganda) ----
  /// Matn oxiridagi '@so'z' bo'lagiga mos manbalar (maks 4 ta)
  List<Map<String, dynamic>> _atList(Map<String, dynamic> v) {
    final txt = '${v['xarTextVal'] ?? ''}';
    final m = RegExp(r'@[^\s@]*$').firstMatch(txt);
    if (m == null) return const [];
    final q = m.group(0)!.toLowerCase();
    final subs = (v['xfAtSubs'] as List? ?? const []).cast<Map<String, dynamic>>();
    return subs.where((s) => '${s['name']}'.toLowerCase().startsWith(q)).take(4).toList();
  }

  void _atPick(Map<String, dynamic> v, String name) {
    final txt = '${v['xarTextVal'] ?? ''}';
    final nt = txt.replaceFirst(RegExp(r'@[^\s@]*$'), '$name ');
    (v['xarTextSet'] as Function)(nt);
  }

  Widget _atOverlay(Map<String, dynamic> v, Pal p) {
    final list = _atList(v);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: _floatDeco(p).copyWith(borderRadius: BorderRadius.circular(Tb.rRow)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < list.length; i++)
            ListRow(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: p.cyan,
              title: '${list[i]['name']}',
              chevron: false,
              last: i == list.length - 1,
              h: 52,
              trailing: Tx('${list[i]['leftTxt']}', size: 14, w: FontWeight.w600,
                  color: list[i]['neg'] == true ? p.coral : p.mint, tab: true),
              onTap: () => _atPick(v, '${list[i]['name']}'),
            ),
        ],
      ),
    );
  }

  Widget _confirmCard(Map<String, dynamic> v, Pal p) {
    final isMerge = v['xfCfMerge'] == true;
    final L0 = store.L();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Cap(isMerge ? (L0['confirmMergeCap'] as String) : (L0['confirmDeleteCap'] as String)),
          const SizedBox(height: 12),
          if (isMerge)
            Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: .6,
                    child: _Dashed(
                      color: p.ink.withValues(alpha: .2), radius: Tb.rIcon,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tx('${v['xfCfFromTxt']}', size: 14, w: FontWeight.w500, color: p.ink, maxLines: 1, ellipsis: true),
                            const SizedBox(height: 4),
                            Tx('${v['xfCfFromSum']}', size: 13, color: p.t2, tab: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, size: 18, color: p.t3),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: p.cyan.withValues(alpha: .08),
                      border: Border.all(color: p.cyan, width: 1.5),
                      borderRadius: BorderRadius.circular(Tb.rIcon),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tx('${v['xfCfToTxt']}', size: 14, w: FontWeight.w500, color: p.ink, maxLines: 1, ellipsis: true),
                        const SizedBox(height: 4),
                        Tx('${v['xfCfToSum']}', size: 13, color: p.t2, tab: true),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            _Dashed(
              color: p.coral.withValues(alpha: .55), radius: Tb.rIcon,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: p.coral.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(Tb.rIcon),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Tx('${v['xfCfFromTxt']}', size: 14, w: FontWeight.w500, color: p.ink)),
                    const SizedBox(width: 8),
                    Tx(L0['willDelete'] as String, size: 12, w: FontWeight.w600, color: p.coral),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: isMerge
                    ? GradientBtn(
                        label: L0['btnConfirm'] as String,
                        onTap: () => (v['xfCfOk'] as Function)(),
                        h: 48, fs: 15, glow: false,
                      )
                    : SolidBtn.coral(
                        L0['btnConfirm'] as String,
                        () => (v['xfCfOk'] as Function)(),
                        h: 48, fs: 15,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassBtn(
                  label: L0['btnCancelShort'] as String,
                  onTap: () => (v['xfCfNo'] as Function)(),
                  h: 48, fs: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Suzuvchi kartalar uchun umumiy qobiq (confirm / papka tahriri / ko'chirish)
  BoxDecoration _cardDeco(Pal p) => _floatDeco(p);

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Cap(_t('xfEditFolderCap', 'PAPKANI TAHRIRLASH'))),
              _roundBtn('✕', () => setState(() => _fEdit = null), p),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40, height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _folderGrad(name, false),
                  borderRadius: BorderRadius.circular(Tb.rIcon),
                ),
                child: _folderIcon(name, 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Tx(name, size: 16, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true)),
              if (archived) ...[
                const SizedBox(width: 8),
                PillBadge.muted(_t('xfArchivedBadge', 'Arxivda'), icon: Icons.archive_outlined),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(child: _PulseDots(color: p.t2)),
            )
          else if (isBoshqa)
            Tx(_t('xfBoshqaFixedHint', "«Boshqa» — zaxira papka: aniqlanmagan yozuvlar shu yerga tushadi, tahrirlanmaydi"),
                size: 13, color: p.t3, lh: 18)
          else if (missing)
            Tx(_t('xfFolderNoCatHint', "Bu papka toifalar ro'yxatida topilmadi — tahrirlash uchun internetni tekshiring"),
                size: 13, color: p.t3, lh: 18)
          else if (renaming)
            Row(
              children: [
                Expanded(
                  child: GlassField(
                    h: 44,
                    focused: true,
                    icon: Icons.edit_outlined,
                    child: TextField(
                      autofocus: true,
                      controller: _fCtl,
                      onChanged: (t) => _fName = t,
                      onSubmitted: (_) => _renameFolder(name),
                      style: tbStyle(size: 14, color: p.ink),
                      cursorColor: p.cyan,
                      decoration: InputDecoration(
                        isDense: true, isCollapsed: true, border: InputBorder.none,
                        hintText: _t('newFolderHint', 'Yangi papka nomi…'),
                        hintStyle: tbStyle(size: 14, color: p.t5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: GradientBtn(
                    label: store.L()['btnOk'] as String,
                    onTap: _fBusy ? null : () => _renameFolder(name),
                    h: 44, fs: 14, glow: false, loading: _fBusy,
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: GradientBtn(
                    label: _t('xfRename', "Nomini o'zgartirish"),
                    icon: Icons.edit_outlined,
                    h: 44, fs: 14, glow: false,
                    onTap: _fBusy
                        ? null
                        : () {
                            setState(() {
                              _fEdit = {...f, 'renaming': true};
                              _fCtl.text = _fName;
                              _fCtl.selection = TextSelection.collapsed(offset: _fName.length);
                            });
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassBtn(
                    label: archived ? _t('xfUnarchive', 'Arxivdan qaytarish') : _t('xfArchive', 'Arxivlash'),
                    icon: Icons.archive_outlined,
                    h: 44, fs: 14,
                    onTap: _fBusy ? null : () => _archiveFolder(name, !archived),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Tx(
              archived
                  ? _t('xfArchivedHint', 'Arxivda: AI taklif qilmaydi, eski yozuvlar saqlanadi')
                  : _t('xfArchiveHint', "Arxivlash — o'chirish emas: tarix saqlanadi, AI taklif qilmaydi"),
              size: 12, color: p.t4, lh: 16,
            ),
          ],
        ],
      ),
    );
  }

  /// "Boshqa nom" tasdiqi: AVVAL toifa yaratiladi (Api.addCategory), KEYIN
  /// PATCH shu nom bilan ko'chiradi. To'g'ridan-to'g'ri PATCH bo'lmaydi —
  /// server noma'lum toifani 'Boshqa'ga tushiradi va yozilgan nom jimgina
  /// yo'qolardi (tray oqimi /confirm+accept_new_category bilan yaratadi).
  /// 409 (toifa allaqachon bor) — o'sha mavjud toifaga ko'chiraveramiz.
  Future<void> _mvNameOk() async {
    final n = _mvCtl.text.trim();
    if (n.length < 2) {
      store.toast_(store.L()['tNameMin2'] as String);
      return;
    }
    if (_fBusy) return;
    setState(() => _fBusy = true);
    final r = await Api.addCategory(n);
    if (!mounted) return;
    setState(() => _fBusy = false);
    if (!r.ok && r.status != 409) {
      store.toast_(r.error); // karta ochiq qoladi — qayta urinish mumkin
      return;
    }
    store.set({'xcCats': <String>[]}); // toifa keshi eskirdi — keyingi ochilishda yangilanadi
    // Muvaffaqiyatda server qaytargan kanonik nom; 409 da yozilgan nomning o'zi
    final canon = r.ok ? (((r.data as Map?)?['name'] as String?) ?? n) : n;
    await _moveTo(canon);
  }

  // ============ YOZUVNI KO'CHIRISH KARTASI (papkadan papkaga) ============
  Widget _moveCard(Pal p) {
    final mv = _mv!;
    final cur = '${mv['cat']}';
    final loading = _cats == null;
    final naming = mv['naming'] == true;
    // Joriy papka va Daromad chiqariladi: kirim Daromad panelida yashaydi,
    // xarajat yozuvi u yerga ko'chmaydi
    final chips = (_cats ?? const <Map<String, dynamic>>[])
        .where((c) => c['archived'] != true &&
            _norm('${c['name']}') != _norm(cur) &&
            _norm('${c['name']}') != 'daromad')
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Cap(_t('xfMoveCap', "PAPKAGA KO'CHIRISH"))),
              _roundBtn('✕', () => setState(() => _mv = null), p),
            ],
          ),
          const SizedBox(height: 12),
          _Dashed(
            color: p.ink.withValues(alpha: .2), radius: Tb.rIcon,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Tx('${mv['desc']}', size: 14, w: FontWeight.w500, color: p.ink, maxLines: 1, ellipsis: true)),
                  const SizedBox(width: 8),
                  Tx('${mv['amtTxt']}', size: 14, w: FontWeight.w600, color: p.coral, tab: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Tx(_tf('xfMoveFrom', {'cat': cur}, "Hozir: {cat} — qaysi papkaga o'tsin?".replaceAll('{cat}', cur)),
              size: 13, color: p.t4),
          const SizedBox(height: 10),
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(child: _PulseDots(color: p.t2)),
            )
          else if (naming)
            // Qo'lda yangi papka nomi — tray "Boshqa nom" oqimi bilan bir xil uslub
            Row(
              children: [
                Expanded(
                  child: GlassField(
                    h: 44,
                    focused: true,
                    icon: Icons.folder_outlined,
                    child: TextField(
                      autofocus: true,
                      controller: _mvCtl,
                      onSubmitted: (_) => _mvNameOk(),
                      style: tbStyle(size: 14, color: p.ink),
                      cursorColor: p.cyan,
                      decoration: InputDecoration(
                        isDense: true, isCollapsed: true, border: InputBorder.none,
                        hintText: _t('newFolderHint', 'Yangi papka nomi…'),
                        hintStyle: tbStyle(size: 14, color: p.t5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: GradientBtn(
                    label: store.L()['btnOk'] as String,
                    onTap: _fBusy ? null : _mvNameOk,
                    h: 44, fs: 14, glow: false, loading: _fBusy,
                  ),
                ),
              ],
            )
          else ...[
            if (chips.isEmpty) ...[
              Tx(_t('xfMoveNoCats', "Boshqa faol papka yo'q — internetni tekshiring yoki yangi toifa oching"),
                  size: 13, color: p.t3, lh: 18),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                for (final c in chips)
                  PillChip(
                    label: '${store.xfEmoji('${c['name']}')} ${c['name']}',
                    selected: false,
                    h: 36,
                    onTap: _fBusy ? null : () => _moveTo('${c['name']}'),
                  ),
                // Yangi papka nomi — tray'dagi "➕ Boshqa nom" bilan bir xil chip
                PillChip(
                  label: store.L()['otherName'] as String,
                  selected: false,
                  h: 36,
                  onTap: _fBusy
                      ? null
                      : () => setState(() {
                            _mv!['naming'] = true;
                            _mvCtl.text = '';
                          }),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ================= RANGLI INPUT (dizayn: highlight) =================
// Summa — HAR DOIM coral (+13% fon), toifa so'zi — glass2 fon, buyruq/sana — hairline fon.
// Bu input FAQAT xarajat yozadi (store xarPick_ 'daromad' amalini ham
// 'xarajat'ga o'giradi), kirim Daromad paneli ichidan kiritiladi — shuning
// uchun yashil (kirim) taxmin bu yerda chalg'itardi va olib tashlandi:
// kirim/chiqim heuristikasi ham, server preview so'rovi ham yo'q.
class _HlController extends TextEditingController {
  // ---- SUMMA: tilga bog'liq EMAS — raqam + ko'p tilli multiplikator + valyuta ----
  // (server parse.js amountSpans bilan sinxron, 3 sinf: MING x1e3 —
  // ming/минг/тыс/thousand/mil(le)/千/k/к; WAN x1e4 — 万; MILLION x1e6 —
  // mln/million/milion/millón/млн/миллион/百万/m/м). UZUNLARI OLDIN turadi —
  // "million/milion/millón" hech qachon "mil"ga yutilmaydi. Qisqa k|к|m|м faqat
  // alohida turganda multiplikator ("5000 kofe"dagi "k" emas — lookahead bilan).
  static final _amtRe = RegExp(
      r"(\d{1,3}(?:[  .]\d{3})+|\d{1,3}(?:,\d{3})+|\d+(?:[.,]\d+)?)"
      r"(\s*(?:million[a-z]*|milion[a-z]*|mill[oó]n[a-z]*|миллион[а-яё]*|милион[а-яё]*|mln[a-z]*|млн|百万|ming[a-z]*|минг[а-яё]*|тыс[а-яё]*|thousand|mil(?:le)?(?![a-zа-яё])|千|万|[kк](?![a-zа-яё0-9])|[mм](?![a-zа-яё0-9])))?"
      r"(\s*(?:so['’ʻ`]?m|сум[а-яё]*|сўм[а-яё]*|uzs))?",
      caseSensitive: false);
  static final _catRe = RegExp(
      r"oziq-ovqat|oziq|tushlik|nonushta|ovqat|bozor|market|taksi|avtobus|metro|benzin|transport|kofe|qahva|kommunal|svet|gaz|internet|telefon|kiyim|xarid\w*|do['’ʻ`]?kon|dori\w*|shifokor|apteka|kino|konsert|sport|zal|fitnes|kitob\w*|papka\w*|oylik|maosh|avans|mijoz\w*|sotuv\w*|biznes|daromad|bonus",
      caseSensitive: false);
  static final _cmdRe = RegExp(r"birlashtir\w*|o['’ʻ`]?chir\w*|keldi|tushdi|qaytdi",
      caseSensitive: false);
  static final _dateRe = RegExp(r"bugun|kechqurun|kecha|ertalab|ertaga", caseSensitive: false);

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final p = curPal();
    final t = text;
    if (t.isEmpty) return TextSpan(style: style);

    final ranges = <List<dynamic>>[]; // [s, e, type]
    for (final m in _amtRe.allMatches(t)) {
      if (m.end > m.start) ranges.add([m.start, m.end, 'amt']);
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

    final spans = <TextSpan>[];
    var pos = 0;
    for (final r in kept) {
      final s = r[0] as int, e = r[1] as int, type = r[2] as String;
      if (s > pos) spans.add(TextSpan(text: t.substring(pos, s)));
      Color c;
      Color bg;
      if (type == 'amt') {
        // Summa doim coral — bu input faqat xarajat yozadi (RANG QOIDASI, fayl boshida)
        c = p.coral;
        bg = p.coral.withValues(alpha: .13);
      } else if (type == 'cat') {
        c = p.ink;
        bg = p.glass2;
      } else if (type == 'cmd') {
        c = p.t1;
        bg = p.hairline;
      } else {
        c = p.t2;
        bg = p.hairline;
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
    final st = tbStyle(size: 15, color: p.ink);
    return TextField(
      controller: _c,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmit != null ? (_) => widget.onSubmit!() : null,
      inputFormatters: [_NumGroupFmt()], // raqamlar jonli 0 000 000 ko'rinishida
      style: st,
      cursorColor: p.cyan,
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
    super.key, // sahifa/papka almashganda holatni qayta boshlash uchun (ValueKey)
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
      // Moliyaviy qoida: summa hech qachon "..." bilan kesilmaydi —
      // torlik qilsa FittedBox butun raqamni kichraytirib sig'diradi.
      builder: (_, __) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          '${widget.prefix}${_fmt(_now())}',
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          // Summalar — Space Grotesk, tabular (DESIGN_SPEC §2)
          style: tbStyle(size: widget.size, w: widget.weight, color: widget.color, ls: widget.ls, tab: true),
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
          colors: [color.withValues(alpha: .15), color.withValues(alpha: .0)],
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

/// Limit halqasi (DESIGN_SPEC §5.11): 110px, stroke 10, fon ink 8%, progress cyan
/// (limit oshsa coral), round cap, -90° dan boshlanadi; ichida "41%" 22/600 num +
/// "limitdan" 12 t3. Foiz o'zgarganda silliq to'ladi.
class _LimitRing extends StatelessWidget {
  final double pct; // 0..1
  final Color color;
  final Color track;
  final String label;
  final String sub;
  final double size;
  const _LimitRing({
    required this.pct,
    required this.color,
    required this.track,
    required this.label,
    required this.sub,
    this.size = 110,
  });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: pct.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(pct: t, color: color, track: track, stroke: 10),
          child: child,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tx(label, size: 22, w: FontWeight.w600, color: p.ink, tab: true, maxLines: 1),
            Tx(sub, size: 12, color: p.t3, maxLines: 1),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color color;
  final Color track;
  final double stroke;
  _RingPainter({required this.pct, required this.color, required this.track, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (math.min(size.width, size.height) - stroke) / 2;
    canvas.drawCircle(
      c, r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (pct <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * pct.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.pct != pct || old.color != color || old.track != track || old.stroke != stroke;
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
      'aloqa': 'phone', "ta'lim": 'cap', 'talim': 'cap', 'boshqa': 'box',
      // 2026-08-04: real toifalar to'plami (Talim/Sovg'a default papka bo'lib qolardi)
      "sovg'a": 'gift', "to'y": 'ring', 'marosim': 'ring', 'dehqonchilik': 'leaf',
      'remont': 'wrench', 'avto': 'taxi', "go'zallik": 'scissors', 'hayvonot': 'paw',
      'bolalar': 'baby', 'soliq': 'receipt', 'ijara': 'key', 'safar': 'plane',
      'sayohat': 'plane', 'kitob': 'book', 'telefon': 'phone', 'internet': 'phone',
      'choyxona': 'coffee', 'qahva': 'coffee',
    };
    final n = _norm(cat);
    final hit = map[n];
    if (hit != null) return hit;
    // KALIT SO'Z zaxirasi: foydalanuvchi yaratgan nomlar ("To'y xarajatlari",
    // "Talim kurslari") ham mazmunli glif olsin — birinchi moslik g'olib.
    // store._xfEmojiKw bilan SEMANTIK sinxron (emoji va glif bir ma'noda).
    for (final e in _kw) {
      if (n.contains(e[0])) return e[1];
    }
    return 'folder';
  }

  static const List<List<String>> _kw = [
    ["ta'lim", 'cap'], ['talim', 'cap'], ['kurs', 'cap'], ['maktab', 'cap'],
    ['sovg', 'gift'],
    ["to'y", 'ring'], ['marosim', 'ring'], ['nikoh', 'ring'],
    ['sport', 'dumbbell'], ['fitnes', 'dumbbell'], ['zal', 'dumbbell'],
    ['dehqon', 'leaf'], ["bog'", 'leaf'], ['ekin', 'leaf'],
    ['remont', 'wrench'], ['usta', 'wrench'], ["ta'mir", 'wrench'],
    ['avto', 'taxi'], ['mashina', 'taxi'], ['benzin', 'taxi'],
    ["go'zallik", 'scissors'], ['gozallik', 'scissors'], ['salon', 'scissors'], ['soch', 'scissors'],
    ['hayvon', 'paw'], ['mushuk', 'paw'],
    ['bola', 'baby'], ['farzand', 'baby'],
    ['soliq', 'receipt'], ['jarima', 'receipt'],
    ['ijara', 'key'], ['arenda', 'key'], ['kvartira', 'key'],
    ['safar', 'plane'], ['sayohat', 'plane'],
    ['kitob', 'book'],
    ['telefon', 'phone'], ['internet', 'phone'], ['aloqa', 'phone'],
    ['choy', 'coffee'], ['kofe', 'coffee'], ['qahva', 'coffee'], ['kafe', 'coffee'],
    ['taksi', 'taxi'], ['transport', 'bus'],
    ['ovqat', 'bowl'], ['oziq', 'bowl'], ['bozor', 'bowl'], ['market', 'bowl'],
    ['kommunal', 'bulb'], ['svet', 'bulb'], ['gaz', 'bulb'],
    ['kiyim', 'bag'], ['xarid', 'bag'], ["do'kon", 'bag'], ['dokon', 'bag'],
    ['dori', 'cross'], ['shifokor', 'cross'], ['apteka', 'cross'], ['salomatlik', 'cross'],
    ['uy', 'home'],
  ];

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
      case 'gift': // sovg'a qutisi — sovg'a
        canvas.drawRRect(RRect.fromLTRBR(4.6, 10.4, 19.4, 19.6, const Radius.circular(2)), st);
        canvas.drawRRect(RRect.fromLTRBR(3.6, 7.2, 20.4, 10.4, const Radius.circular(1.4)), st);
        canvas.drawLine(const Offset(12, 7.2), const Offset(12, 19.6), st);
        canvas.drawCircle(const Offset(9.6, 5.4), 1.9, st);
        canvas.drawCircle(const Offset(14.4, 5.4), 1.9, st);
        break;
      case 'ring': // uzuk (olmos bilan) — to'y/marosim
        canvas.drawCircle(const Offset(12, 14.2), 5.2, st);
        canvas.drawPath(Path()..moveTo(12, 3.8)..lineTo(14.6, 6.4)..lineTo(12, 9)
          ..lineTo(9.4, 6.4)..close(), st);
        break;
      case 'leaf': // barg — dehqonchilik
        canvas.drawPath(Path()..moveTo(5.4, 18.6)..cubicTo(5.4, 10, 10.4, 5.4, 18.6, 5.4)
          ..cubicTo(18.6, 13.8, 13.8, 18.6, 5.4, 18.6)..close(), st);
        canvas.drawLine(const Offset(6.8, 17.2), const Offset(15.2, 8.8), st);
        break;
      case 'wrench': // gayka kaliti — remont
        canvas.drawArc(Rect.fromCircle(center: const Offset(15.8, 8.2), radius: 3.4),
            0.6, 4.9, false, st);
        canvas.drawLine(const Offset(13.2, 10.8), const Offset(6.4, 17.6), st);
        canvas.drawCircle(const Offset(6.4, 17.6), 1.6, st);
        break;
      case 'scissors': // qaychi — go'zallik
        canvas.drawCircle(const Offset(7, 7.4), 2.4, st);
        canvas.drawCircle(const Offset(7, 16.6), 2.4, st);
        canvas.drawLine(const Offset(9, 8.6), const Offset(19.4, 17.6), st);
        canvas.drawLine(const Offset(9, 15.4), const Offset(19.4, 6.4), st);
        break;
      case 'paw': // panja izi — hayvonot
        canvas.drawCircle(const Offset(6.6, 10.6), 1.7, fl);
        canvas.drawCircle(const Offset(10.2, 7.4), 1.7, fl);
        canvas.drawCircle(const Offset(13.8, 7.4), 1.7, fl);
        canvas.drawCircle(const Offset(17.4, 10.6), 1.7, fl);
        canvas.drawPath(Path()..moveTo(12, 11.6)..cubicTo(15, 11.6, 17, 13.6, 17, 15.6)
          ..cubicTo(17, 17.8, 14.8, 19, 12, 19)..cubicTo(9.2, 19, 7, 17.8, 7, 15.6)
          ..cubicTo(7, 13.6, 9, 11.6, 12, 11.6)..close(), st);
        break;
      case 'baby': // chaqaloq yuzi — bolalar
        canvas.drawCircle(const Offset(12, 13), 6.4, st);
        canvas.drawCircle(const Offset(9.8, 12.4), 0.9, fl);
        canvas.drawCircle(const Offset(14.2, 12.4), 0.9, fl);
        canvas.drawArc(Rect.fromCircle(center: const Offset(12, 14.2), radius: 2.6),
            0.5, 2.1, false, st);
        canvas.drawPath(Path()..moveTo(12, 6.6)..cubicTo(11.6, 4.8, 13.4, 4, 14.2, 5.2), st);
        break;
      case 'plane': // qog'oz samolyot — safar/sayohat
        canvas.drawPath(Path()..moveTo(3.6, 12.6)..lineTo(20.4, 4.6)..lineTo(14.6, 19.4)
          ..lineTo(11.4, 13.8)..close(), st);
        canvas.drawLine(const Offset(11.4, 13.8), const Offset(20.4, 4.6), st);
        break;
      case 'receipt': // chek (tishli pastki) — soliq
        canvas.drawPath(Path()..moveTo(6, 4.6)..lineTo(18, 4.6)..lineTo(18, 19.4)
          ..lineTo(16, 18)..lineTo(14, 19.4)..lineTo(12, 18)..lineTo(10, 19.4)
          ..lineTo(8, 18)..lineTo(6, 19.4)..close(), st);
        canvas.drawLine(const Offset(8.6, 9), const Offset(15.4, 9), st);
        canvas.drawLine(const Offset(8.6, 12.2), const Offset(13.4, 12.2), st);
        break;
      case 'key': // kalit — ijara
        canvas.drawCircle(const Offset(8, 8), 3.4, st);
        canvas.drawLine(const Offset(10.4, 10.4), const Offset(18.6, 18.6), st);
        canvas.drawLine(const Offset(16.6, 16.6), const Offset(14.8, 18.4), st);
        canvas.drawLine(const Offset(13.6, 13.6), const Offset(12.2, 15), st);
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

/// Yozish paytida raqamni 3 xonadan guruhlaydi: 1234567 -> «1 234 567».
/// (server 13 xonagacha qabul qiladi — undan uzuni kesiladi)
String _groupDigits(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.length > 13) digits = digits.substring(0, 13);
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(' ');
    b.write(digits[i]);
  }
  return b.toString();
}

class _ThousandsFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    final t = _groupDigits(newV.text);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// #15v2: SUB-papka ichida "kirim qo'shish" paneli — summa + izoh.
/// onAdd true qaytarsa (server saqladi) — maydonlar tozalanadi.
/// 2026-08-03 UI/UX: siqilgan 3-ustunli qator o'rniga karta ko'rinishi —
/// katta Summa maydoni (21px, «so'm» suffiks, avto 1 234 567 guruhlash),
/// to'liq enli Izoh va 50dp yashil «Qo'shish» tugmasi (summa bo'sh — xira).
class _IncomeAddBar extends StatefulWidget {
  final Future<bool> Function(String amount, String note) onAdd;
  final bool busy;
  const _IncomeAddBar({required this.onAdd, required this.busy});

  @override
  State<_IncomeAddBar> createState() => _IncomeAddBarState();
}

class _IncomeAddBarState extends State<_IncomeAddBar> {
  final _amt = TextEditingController();
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _amt.addListener(_onAmt); // «Qo'shish» tugmasi holati jonli yangilansin
  }

  void _onAmt() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amt.removeListener(_onAmt);
    _amt.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || widget.busy) return;
    setState(() => _sending = true);
    final ok = await widget.onAdd(_amt.text, _note.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _amt.clear();
      _note.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final busy = _sending || widget.busy;
    final hasAmt = _amt.text.trim().isNotEmpty;
    return GlassCard(
      r: Tb.rCard,
      pad: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summa — katta (20 num), «so'm» suffiks, avto 1 234 567 guruhlash
          GlassField(
            h: 56,
            icon: Icons.payments_outlined,
            iconColor: p.mint,
            trailing: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Tx(store.L()['som'] as String? ?? "so'm", size: 14, color: p.t3),
            ),
            child: TextField(
              controller: _amt,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [_ThousandsFmt()],
              style: tbStyle(size: 20, w: FontWeight.w600, color: p.ink, tab: true),
              cursorColor: p.cyan,
              decoration: InputDecoration(
                isDense: true, isCollapsed: true, border: InputBorder.none,
                hintText: store.L()['xfIncAmtHint'] as String? ?? 'Summa',
                hintStyle: tbStyle(size: 20, w: FontWeight.w600, color: p.t5, tab: true),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GlassField(
            h: 48,
            icon: Icons.description_outlined,
            child: TextField(
              controller: _note,
              style: tbStyle(size: 15, color: p.ink),
              cursorColor: p.cyan,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                isDense: true, isCollapsed: true, border: InputBorder.none,
                hintText: store.L()['xfIncNoteHint'] as String? ?? 'Izoh (ixtiyoriy)',
                hintStyle: tbStyle(size: 15, color: p.t5),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 12),
          // Summa bo'sh — xira (bosilmaydi); band — spinner
          Opacity(
            opacity: (busy || hasAmt) ? 1 : .45,
            child: SolidBtn.mint(
              store.L()['xfIncAddBtn'] as String? ?? "Qo'shish",
              (busy || !hasAmt) ? null : _submit,
              h: 52,
              fs: 15,
              icon: Icons.add_rounded,
              loading: busy,
              glow: hasAmt && !busy,
            ),
          ),
          const SizedBox(height: 10),
          Tx(
            store.L()['xfIncHint'] as String? ??
                "Shu manbaga kirim qo'shish — summa yozib «Qo'shish»ni bosing",
            size: 12,
            color: p.t4,
            lh: 16,
          ),
        ],
      ),
    );
  }
}

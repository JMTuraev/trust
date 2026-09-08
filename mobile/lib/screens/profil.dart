// Profil ekrani — dizayn: prototype/redesign/DESIGN_SPEC.md §5.16
// (RingAvatar + ism + telefon, SOZLAMALAR shisha kartasi (profRows),
// OBUNA kartasi (_SubCard), Chiqish / Profilni o'chirish kartasi, versiya).
// Obuna bo'limi — 2026-08-04 dan HAR BO'LIM uchun alohida qator (_SubCard izohiga qarang).
//
// Store shartnomasi o'zgarmadi: profRows (label/value/isSwitch/isPlain/danger/tap),
// meName/meInitials/meAvatar/pickAvatar/mePhoneFmt/meNoFmt, meEditing/meEditVal/
// onMeName/meNameSave/meEditToggle, logout, delOtp*, modSubs/modSubsLegacy/openPaywall.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';
import '../iap.dart';
import '../api.dart' show apiUrl;
import 'tab_bar.dart' show SubInfo, subTr, subWarnInk;

/// Apple obunalarni boshqarish sahifasi (App Store → Apple ID → Obunalar).
/// Modul obunalarini bekor qilish/almashtirish faqat shu yerda bo'ladi.
const String _kAppleSubsUrl = 'https://apps.apple.com/account/subscriptions';

/// Tashqi havolani ochish (Apple 3.1.2 — Shartlar / Maxfiylik). Ochib bo'lmasa jim o'tadi.
Future<void> _openUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {/* havola ochilmadi — jim o'tamiz */}
}

/// profRows qatori uchun ikonka — store qatorida ikonka kaliti yo'q, shuning
/// uchun yorliq L() kalitlari bilan solishtiriladi (tarjimadan mustaqil).
IconData _rowIcon(Map<String, dynamic> pr, Map<String, dynamic> L0) {
  final l = '${pr['label'] ?? ''}';
  if (l.isEmpty) return Icons.chevron_right_rounded;
  if (l == L0['profTil']) return Icons.language_rounded;
  if (l == L0['profCur']) return Icons.payments_outlined;
  if (l == L0['darkMode']) return Icons.dark_mode_outlined;
  if (l == L0['profPin']) return Icons.key_rounded;
  if (l == L0['profPinChange']) return Icons.lock_outline_rounded;
  if (l == L0['profNotif']) return Icons.notifications_none_rounded;
  if (l == L0['profSupport']) return Icons.help_outline_rounded;
  if (l == L0['rejLinks']) return Icons.people_outline_rounded;
  if (l == L0['profArch']) return Icons.archive_outlined;
  if (l == L0['profSub']) return Icons.workspace_premium_rounded;
  if (l == L0['profDelete']) return Icons.delete_outline_rounded;
  return Icons.info_outline_rounded;
}

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final p = curPal();
    final rows = (v['profRows'] as List).cast<Map<String, dynamic>>();
    // Sozlamalar kartasi — oddiy qatorlar; xavfli (o'chirish) qatori oxirgi kartada
    final settingRows = rows.where((r) => r['danger'] != true).toList();
    final dangerRows = rows.where((r) => r['danger'] == true).toList();
    // Avatar picker keshida saqlanadi — OS keshni tozalasa fayl yo'qoladi;
    // yo'q faylni FileImage'ga bersak render xatosi bo'ladi, shuning uchun tekshiramiz.
    final avatarPath = v['meAvatar'] as String?;
    final File? avatarFile =
        (avatarPath != null && File(avatarPath).existsSync()) ? File(avatarPath) : null;

    return Stack(
      children: [
        // SingleChildScrollView (lazy ListView EMAS): butun profil bir vaqtda quriladi —
        // OBUNA kartasi qisqa ekranda ham daraxtda (profil_subs_test find.text bilan qaraydi).
        SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Sarlavha. Orqaga tugmasi main.dart'dagi HubSection o'ramida (goHub) —
            // shu sababli bu yerda onBack berilmaydi (ikkita "<" bo'lmasin).
            ScreenHeader(title: (L0['navProfile'] as String?) ?? 'Profil'),
            // ── Avatar + ism + telefon ──
            Padding(
              padding: const EdgeInsets.fromLTRB(Tb.padX, 20, Tb.padX, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar — bosilsa galereyadan rasm tanlanadi (edit photo)
                  Tap(
                    onTap: () => v['pickAvatar'](),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (avatarFile != null)
                          Container(
                            width: 72,
                            height: 72,
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Tb.brandDiag),
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p.surface2,
                                image: DecorationImage(image: FileImage(avatarFile), fit: BoxFit.cover),
                              ),
                            ),
                          )
                        else
                          RingAvatar(initials: '${v['meInitials'] ?? ''}', size: 72, ring: 3, gradient: Tb.brandDiag),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: p.glassBd),
                            ),
                            child: Icon(Icons.edit_outlined, size: 13, color: p.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (v['meEditing'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 220,
                            child: GlassField(
                              h: 44,
                              child: StoreField(
                                value: v['meEditVal'],
                                onChanged: (t) => v['onMeName'](t),
                                hint: L0['yourNameHint'] as String,
                                style: tbStyle(size: 15, w: FontWeight.w600, color: p.ink),
                                onSubmit: () => v['meNameSave'](),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GlassIconBtn(icon: Icons.check_rounded, gradient: true, onTap: () => v['meNameSave']()),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      // Ism — mijozlarga shu ko'rinadi; bosib tahrirlash mumkin
                      child: Tap(
                        onTap: () => v['meEditToggle'](),
                        child: Tx('${v['meName'] ?? ''}', size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Tx('${v['mePhoneFmt'] ?? ''}', size: 15, color: p.t2, tab: true),
                  ),
                  // 8 xonali unikal ID (PO 2026-07-28) — kengayish uchun; nusxalash oson format
                  if ('${v['meNoFmt'] ?? ''}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Tx('${v['meNoFmt']}', size: 12, w: FontWeight.w600, color: p.t4, tab: true),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_outlined, size: 14, color: p.mint),
                        const SizedBox(width: 5),
                        // TODO l10n: "Tasdiqlangan hisob"
                        Tx('Tasdiqlangan hisob', size: 13, w: FontWeight.w500, color: p.mint),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── SOZLAMALAR ──
            if (settingRows.isNotEmpty) ...[
              // TODO l10n: "Sozlamalar"
              const Padding(padding: EdgeInsets.fromLTRB(Tb.padX, 0, Tb.padX, 10), child: Cap('Sozlamalar')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tb.padX),
                child: GlassCard(
                  r: 24,
                  child: Column(
                    children: [
                      for (var i = 0; i < settingRows.length; i++)
                        _settingRow(settingRows[i], L0, p, last: i == settingRows.length - 1),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            // ── OBUNA — har bo'lim uchun alohida qator (_SubCard).
            // DIQQAT: const EMAS — store o'zgarganda qayta qurilishi kerak.
            _SubCard(v: v),
            const SizedBox(height: 20),
            // ── Chiqish / Profilni o'chirish ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tb.padX),
              child: GlassCard(
                r: 24,
                child: Column(
                  children: [
                    ListRow(
                      icon: Icons.logout_rounded,
                      iconColor: p.coral,
                      title: (v['L'] as Map)['logout'] as String,
                      titleColor: p.coral,
                      chevron: false,
                      last: dangerRows.isEmpty,
                      onTap: v['logout'],
                    ),
                    for (var i = 0; i < dangerRows.length; i++)
                      ListRow(
                        icon: _rowIcon(dangerRows[i], L0),
                        iconColor: p.coral,
                        title: '${dangerRows[i]['label'] ?? ''}',
                        titleColor: p.coral,
                        chevron: false,
                        last: i == dangerRows.length - 1,
                        onTap: dangerRows[i]['tap'],
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Tx(L0['versionFooter'] as String, size: 13, color: p.t6)),
            ),
            ],
          ),
        ),
        // #34: profil o'chirish — SMS kod bilan tasdiqlash modali
        if (v['delOtpOpen'] == true) _DelOtpModal(v: v),
      ],
    );
  }

  /// Sozlamalar qatori: ikonka · nom · qiymat/toggle · chevron. Bosish — store 'tap'.
  Widget _settingRow(Map<String, dynamic> pr, Map<String, dynamic> L0, Pal p, {required bool last}) {
    final value = '${pr['value'] ?? ''}';
    if (pr['isSwitch'] == true) {
      // Store toggle holatini 'knobLeft' (21 = yoqilgan, 3 = o'chiq) bilan beradi
      final on = ((pr['knobLeft'] as num?) ?? 0) > 10;
      return ListRow(
        icon: _rowIcon(pr, L0),
        title: '${pr['label'] ?? ''}',
        chevron: false,
        last: last,
        trailing: TbToggle(value: on, onChanged: (_) => pr['tap']()),
        onTap: pr['tap'],
      );
    }
    return ListRow(
      icon: _rowIcon(pr, L0),
      title: '${pr['label'] ?? ''}',
      value: value.isEmpty ? null : value,
      last: last,
      onTap: pr['tap'],
    );
  }
}

/// #34: Profilni o'chirish — OTP tasdiqlash modali.
/// Telefon QAYTA yozilmaydi (bazadagi raqamga kod yuborilgan); faqat kod kiritiladi.
/// Ogohlantirish: tasdiqlansa profil o'chiriladi va yozuvlarga kirish yopiladi.
class _DelOtpModal extends StatefulWidget {
  final Map<String, dynamic> v;
  const _DelOtpModal({required this.v});

  @override
  State<_DelOtpModal> createState() => _DelOtpModalState();
}

class _DelOtpModalState extends State<_DelOtpModal> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String _t(String key, String fb) => (store.L()[key] as String?) ?? fb;

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final v = widget.v;
    final busy = v['delOtpBusy'] == true;
    final phone = '${v['delOtpPhone'] ?? ''}';
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : () => (v['delOtpCancel'] as Function)(),
        child: Container(
          color: p.dim,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border.all(color: p.glassBd),
                borderRadius: BorderRadius.circular(Tb.rCard),
                boxShadow: Tb.panelShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(_t('delOtpTitle', "Profil o'chirilsinmi?"), size: 20, w: FontWeight.w600, color: p.coral, font: TbFont.head),
                  const SizedBox(height: 8),
                  Tx(
                    _t('delOtpWarn',
                        "Diqqat: profilingiz o'chiriladi va barcha yozuvlaringizga kirish yopiladi."),
                    size: 14, color: p.t1, lh: 20,
                  ),
                  const SizedBox(height: 4),
                  Tx(
                    phone.isEmpty
                        ? _t('delOtpSentTo', 'Raqamingizga yuborilgan SMS kodni kiriting:')
                        : '${_t('delOtpSentTo2', 'SMS kod yuborildi:')} $phone',
                    size: 13, color: p.t3, lh: 18,
                  ),
                  const SizedBox(height: 14),
                  GlassField(
                    h: 52,
                    child: TextField(
                      controller: _code,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: tbStyle(size: 22, w: FontWeight.w600, color: p.ink, tab: true, ls: 6),
                      textAlign: TextAlign.center,
                      cursorColor: p.cyan,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '•••••',
                        hintStyle: tbStyle(size: 22, color: p.t5, tab: true, ls: 6),
                        isDense: true,
                        isCollapsed: true,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GlassBtn(
                          label: _t('btnCancel', 'Bekor qilish'), h: 48, fs: 14,
                          onTap: () { if (!busy) (v['delOtpCancel'] as Function)(); },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SolidBtn.coral(
                          _t('delOtpBtn', "O'chirish"),
                          () => (v['delOtpConfirm'] as Function)(_code.text),
                          h: 48, fs: 14, loading: busy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Obuna bo'limi — profil ekranidagi karta. 2026-08-04 dan HAR BO'LIM uchun
/// alohida qator (PO qarori).
///
/// NEGA RO'YXAT: tarif bitta $9 lik "butun ilova" premiumidan har bo'lim
/// obunasiga o'tdi (xarajat, qarz, ijaradagi uylar, to'yxona). Profil esa
/// bitta umumiy karta ko'rsatib turardi va hech qachon obuna bo'lmagan odamga
/// «Obunani yangilash» CTAsini chiqarardi — ma'nosiz.
///
/// NARX QOIDASI (o'zgarmadi, ATAYLAB): bu ekranda HECH QACHON qotirilgan summa
/// chizilmaydi. Modul qatorlarida summa UMUMAN yo'q — aniq narx modul
/// paywall'ida (`openPaywall`) ko'rsatiladi. Eski premium ko'rinishida summa
/// faqat do'kondan (StoreKit `IapService.priceLabel`) kelsa chiziladi.
///
/// UCH KO'RINISH:
///   1) `modSubs` bor, legacy yo'q  -> MODUL RO'YXATI (asosiy holat)
///   2) `modSubsLegacy` = true      -> eski «Premium · {sana} gacha» kartasi
///        AYNAN avvalgidek + har bir modul «Premium obunangizga kiritilgan»
///        deb ko'rsatiladi (legacy egasi hech narsa yo'qotmaydi)
///   3) `modSubs` BO'SH             -> eski umumiy karta (narxsiz): server
///        /api/subs/status ni qo'llamasa yoki bayroq o'chiq bo'lsa
///
/// iOS: Apple Guideline 3.1.2 MAJBURIY ma'lumotlari har uchala ko'rinishda
///   qoladi — "Xaridni tiklash", avtomatik yangilanish sharti + bekor qilish
///   yo'li, Foydalanish shartlari + Maxfiylik havolalari.
/// Android: to'lov kanali hali ulanmagan — paywall halol xabar beradi.
class _SubCard extends StatelessWidget {
  /// store.vals() — ProfilScreen bir marta hisoblab beradi (ikki marta emas).
  final Map<String, dynamic> v;
  const _SubCard({required this.v});

  String _d2(int x) => x.toString().padLeft(2, '0');

  /// ISO sana -> «04.09.2026». Sana yo'q yoki buzuq bo'lsa — bo'sh satr
  /// (qatorda sanasiz «Faol» ko'rinadi, xato sana emas).
  String _fmtDate(dynamic raw) {
    final d = raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
    return d == null ? '' : '${_d2(d.day)}.${_d2(d.month)}.${d.year}';
  }

  /// Modul nomi joriy tilda. Notanish modulda modul KODI qaytadi —
  /// paywall_sheet.dart bilan bir xil qoida: boshqa modulning nomiga
  /// zaxira QILINMAYDI (pul ekranida jim xato bo'lmasin).
  String _modName(String module) {
    final k = kSubModuleNameKey[module];
    final s = k == null ? null : store.L()[k];
    return s is String && s.isNotEmpty ? s : module;
  }

  /// Modul ikonkasi (dizayn §5.16: wallet / daftar / apartment / heart).
  IconData _modIcon(String module) {
    switch (module) {
      case 'xarajat':
        return Icons.account_balance_wallet_outlined;
      case 'qarz':
        return Icons.description_outlined;
      case 'ijarachi':
        return Icons.apartment_rounded;
      case 'toyxona':
        return Icons.favorite_border_rounded;
    }
    return Icons.workspace_premium_rounded;
  }

  void _renewTap() {
    // To'lov kanali yo'q — halol xabar. Matnda narx YO'Q: obuna endi
    // per-modul, aniq summa modul paywall'ida ko'rsatiladi.
    store.toast_(subTr('subInfo',
        "Har bo'lim alohida obuna — bepul limitdan keyin faqat kerakli "
        "bo'limni ochasiz. To'lov tez orada ulanadi"));
  }

  /// Modul paywall'i — YAGONA umumiy sheet (store: openPaywall_ -> S['paywall'],
  /// ko'rinishi main.dart overlay'ida). Bu yerda IKKINCHI paywall qurilmaydi.
  /// Store kaliti hali yo'q bo'lsa — halol xabar (ekran "o'lik" bo'lib qolmaydi).
  void _openPaywall(String module) {
    final f = v['openPaywall'];
    if (f is Function) {
      f(module);
      return;
    }
    _renewTap();
  }

  /// Ko'rsatiladigan modul qatorlari.
  ///
  /// Asos — server ro'yxati (`modSubs`). Unda yo'q, lekin bizga MA'LUM
  /// modullar ham qo'shiladi: backend bosqichma-bosqich yoyilganda profilda
  /// 2 ta, bosh hubda 4 ta bo'lim ko'rinib qolmasin. Server ro'yxati bo'sh
  /// bo'lsa — bo'sh qaytadi (zaxira karta chiziladi, ro'yxat emas).
  List<Map<String, dynamic>> _rows() {
    final raw = v['modSubs'];
    if (raw is! List || raw.isEmpty) return const [];
    // LinkedHashMap — server tartibini saqlaydi va dublikatni yutadi.
    final byKey = <String, Map<String, dynamic>>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final m = '${e['module'] ?? ''}'.trim();
      if (m.isEmpty) continue;
      byKey[m] = e.cast<String, dynamic>();
    }
    if (byKey.isEmpty) return const [];
    final out = <Map<String, dynamic>>[
      for (final m in kSubModuleOrder) byKey[m] ?? <String, dynamic>{'module': m},
    ];
    // Serverda paydo bo'lgan notanish modul — oxirida (UI yiqilmasin).
    for (final e in byKey.entries) {
      if (!kSubModuleOrder.contains(e.key)) out.add(e.value);
    }
    return out;
  }

  /// Bitta modul qatori: ikonka + nom + holat + o'ngda PRO / «Obuna bo'lish» pill'i.
  /// `legacy` — eski butun-ilova premiumi faol: hamma modul qamrab olingan.
  Widget _modRow(Pal p, Map<String, dynamic> e,
      {required bool legacy, required bool last, required bool dark}) {
    final String module = '${e['module'] ?? ''}';
    // Bepul modul (Xarajatlar, PO 2026-09-08): «Bepul» holati + mint pill, bosilmaydi
    final bool free = subsModuleFree(module, v['modSubs']);
    final bool active = free || legacy || e['active'] == true;
    final bool soon = e['soon'] == true;
    final int used = (e['used'] as int?) ?? 0;
    final int limit = (e['limit'] as int?) ?? 0;
    final bool locked = !active && limit > 0 && used >= limit;
    // Hisoblagich qachon MA'NOLI (home_hub.dart `_modChip` bilan bir xil qoida,
    // YAGONA MANBA — store.dart `kSubLimitDisplayMax`): limit noma'lum (<=0)
    // yoki env sinov qiymati (production'da 300) bo'lsa son ko'rsatilmaydi —
    // aks holda profilda ham «7/300» chiqib, ichki qiymat oshkor bo'lardi.
    final bool showCount =
        !active && !soon && !locked && limit > 0 && limit <= kSubLimitDisplayMax;

    String state;
    Color stateColor = p.t2;
    if (free) {
      state = subTr('subFree', 'Bepul');
      stateColor = p.mint;
    } else if (legacy) {
      state = subTr('subModLegacy', 'Premium obunangizga kiritilgan');
      stateColor = p.mint;
    } else if (active) {
      final d = _fmtDate(e['until']);
      state = d.isEmpty
          ? subTr('subModActive', 'Faol')
          : subTr('subModActiveUntil', 'Faol · {d} gacha', {'d': d});
      stateColor = p.mint;
    } else if (soon) {
      state = subTr('modSoon', 'Tez kunda');
    } else if (locked) {
      state = subTr('subModLimitOut', 'Bepul limit tugagan');
      stateColor = subWarnInk(dark); // qizil emas — bu xato emas, chegara
    } else if (showCount) {
      state = subTr('pwUsed', '{used}/{limit} bepul yozuv ishlatildi',
          {'used': '$used', 'limit': '$limit'});
    } else {
      state = subTr('subFreeTitle', 'Bepul reja');
    }

    // O'ngdagi pill: faol → PRO (gradient); sotuvda → «Obuna bo'lish» (gradient,
    // limit tugagan bo'lsa glow bilan); tez kunda → hech narsa.
    Widget? trailing;
    if (free) {
      trailing = PillBadge.mint(subTr('subFree', 'Bepul'), h: 28);
    } else if (active) {
      trailing = PillBadge.pro(h: 28);
    } else if (!soon) {
      trailing = ConstrainedBox(
        // Tugma kengligi cheklangan: ism uchun joy qolsin
        constraints: const BoxConstraints(maxWidth: 140),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: locked ? Tb.brand : null,
            color: locked ? null : p.glass2,
            border: locked ? null : Border.all(color: p.glassBd),
            borderRadius: BorderRadius.circular(Tb.rPill),
          ),
          // Uzun tarjimada («S'abonner») «...» yo'q — sig'masa kichrayadi
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Tx(subTr('subModSubscribe', "Obuna bo'lish"),
                size: 13, w: FontWeight.w700,
                color: locked ? Colors.white : p.ink, maxLines: 1, font: TbFont.body),
          ),
        ),
      );
    }

    final row = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
      child: Row(
        children: [
          Icon(_modIcon(module), size: 20, color: p.t1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Uzun tarjima («Propiedades en alquiler») kesilmasin — o'raladi
                Tx(_modName(module), size: 15, w: FontWeight.w500, color: p.ink, maxLines: 2),
                const SizedBox(height: 2),
                Tx(state, size: 12, color: stateColor, lh: 16, maxLines: 2),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing],
        ],
      ),
    );

    // Faol modulda bosish yo'q; qolganida butun qator paywall'ni ochadi.
    return active ? row : Tap(onTap: () => _openPaywall(module), scale: 0.99, child: row);
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final sub = SubInfo.read();
    final L0 = store.L();
    final bool dark = store.S['dark'] == true;
    final w = subWarnInk(dark);
    final bool ios = Platform.isIOS;
    final bool busy = store.S['iapBusy'] == true;
    final bool isPremium = sub.status == 'premium';
    final bool legacy = v['modSubsLegacy'] == true;
    final rows = _rows();
    // Asosiy (yangi) ko'rinish: modul ro'yxati eski premium O'RNIGA turadi.
    final bool perModule = rows.isNotEmpty && !legacy;

    // Narx — FAQAT StoreKit lokalizatsiyalangan narxi (masalan "$8.99" yoki
    // "89 000 so'm"). Qotirilgan «$9/oy» zaxirasi OLIB TASHLANDI: u endi
    // noto'g'ri tarif (per-modul narxlarga qarang, sinf izohi). Do'kon narx
    // bermasa — hech qanday summa chizilmaydi.
    // «/oy» qo'shimchasi ham tarjimadan keladi (ilgari dartda qotirilgan edi).
    final String storePrice = IapService.priceLabel;
    final bool hasPrice = storePrice.isNotEmpty;
    final String priceMonthly =
        hasPrice ? subTr('subPerMonth', '{price}/oy', {'price': storePrice}) : '';

    final children = <Widget>[];

    if (perModule) {
      // Bir qatorli izoh — modelni tushuntiradi, narx ATAMAYDI.
      children.add(Tx(
        subTr('subInfo',
            "Har bo'lim alohida obuna — bepul limitdan keyin faqat kerakli "
            "bo'limni ochasiz. To'lov tez orada ulanadi"),
        size: 13, color: p.t2, lh: 18,
      ));
    } else {
      // ---- Eski (legacy / zaxira) ko'rinish: holat sarlavhasi + matn ----
      String title;
      Color titleColor = p.ink;
      if (isPremium) {
        final u = sub.until;
        title = u == null
            ? (L0['subPremium'] as String? ?? 'Premium')
            : subTr('subPremiumUntil', 'Premium · {d} gacha',
                {'d': '${_d2(u.day)}.${_d2(u.month)}.${u.year}'});
      } else if (sub.expired) {
        title = subTr('subExpiredTitle', "To'lov muddati tugagan");
        titleColor = p.coral;
      } else {
        title = subTr('subFreeTitle', 'Bepul reja');
      }

      // `subPitch` (eski butun-ilova taklifi) FAQAT do'kon narxi bor bo'lsa
      // ishlatiladi — ya'ni ichidagi {price} har doim haqiqiy do'kon summasi.
      // Narx yo'q bo'lsa narxsiz, per-modul modelini tushuntiruvchi `subInfo`.
      final String body = isPremium
          ? subTr('subPremiumBody', 'Cheksiz qarz va xarajat yozuvlari yoqilgan. Rahmat!')
          : sub.expired
              ? subTr('subExpiredBody', 'Yangi yozuv kirita olmaysiz — obunani yangilang')
              : (ios && hasPrice)
                  ? subTr('subPitch', 'Cheksiz qarz va xarajat yozuvlari — {price}.',
                      {'price': priceMonthly})
                  : subTr('subInfo',
                      "Har bo'lim alohida obuna — bepul limitdan keyin faqat kerakli "
                      "bo'limni ochasiz. To'lov tez orada ulanadi");

      children.addAll([
        Row(
          children: [
            Expanded(child: Tx(title, size: 17, w: FontWeight.w600, color: titleColor)),
            // Narx — FAQAT do'kon (StoreKit) summasi va FAQAT eski premium
            // ko'rinishida. Modul ro'yxatida bitta summa bo'lishi mumkin emas
            // (har bo'lim har xil), shuning uchun u yerda umuman chizilmaydi.
            if (hasPrice && !perModule) ...[
              const SizedBox(width: 8),
              Tx(priceMonthly, size: 13, w: FontWeight.w700, color: p.ink, tab: true),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Tx(body, size: 13, color: p.t2, lh: 18),
      ]);

      // ≤3 kun qolgan bo'lsa — kartada ham ogohlantirish (banner bilan bir ohangda)
      if (sub.warnSoon) {
        children.addAll([
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: w),
              const SizedBox(width: 6),
              Expanded(
                child: Tx(
                  subTr('subWarnSoon', "To'lov muddati yaqinlashdi — {n} kun qoldi",
                      {'n': '${sub.daysLeft}'}),
                  size: 12, w: FontWeight.w600, color: w, lh: 16,
                ),
              ),
            ],
          ),
        ]);
      }
    }

    // ---- MODUL QATORLARI ----
    // Legacy egasida ham ko'rsatiladi: premiumi aynan nimani qamrab olganini
    // ko'rsatadi (CTA yo'q — hammasi allaqachon ochiq).
    if (rows.isNotEmpty) {
      children.add(const SizedBox(height: 6));
      for (var i = 0; i < rows.length; i++) {
        children.add(_modRow(p, rows[i],
            legacy: legacy, last: i == rows.length - 1, dark: dark));
      }
    }

    if (!perModule) {
      // Eski CTA. «Obunani yangilash» faqat HAQIQATAN tugagan obunada — hech
      // qachon obuna bo'lmagan odamga «yangilash» deyish ma'nosiz edi (PO).
      final VoidCallback cta = ios ? () => store.buyPremium() : _renewTap;
      final String ctaLabel = isPremium
          ? subTr('subManage', 'Obunani boshqarish')
          : sub.expired
              ? subTr('subRenew', 'Obunani yangilash')
              : subTr('subModSubscribe', "Obuna bo'lish");
      children.addAll([
        const SizedBox(height: 14),
        // busy bo'lsa spinnerli (bosish bloklangan). Tugaganda asosiy (gradient),
        // aks holda shisha.
        sub.expired
            ? GradientBtn(label: ctaLabel, h: 48, fs: 15, onTap: cta, loading: busy)
            : GlassBtn(label: ctaLabel, h: 48, fs: 15, onTap: cta, loading: busy),
      ]);
    } else if (ios && rows.any((e) => e['active'] == true)) {
      // Faol modul obunasi bor — Apple'da bekor qilish/almashtirish faqat
      // App Store obunalar sahifasida bo'ladi (store.buyPremium ESKI mahsulotni
      // sotib olardi — modul obunalari uchun noto'g'ri).
      children.addAll([
        const SizedBox(height: 14),
        GlassBtn(
          label: subTr('subManage', 'Obunani boshqarish'),
          h: 48, fs: 15,
          onTap: () => _openUrl(_kAppleSubsUrl),
        ),
      ]);
    }

    // ---- iOS: Apple 3.1.2 majburiy ma'lumotlari + Restore + havolalar ----
    if (ios) {
      children.addAll([
        const SizedBox(height: 6),
        // "Xaridni tiklash" — Apple talabi (qurilma almashsa obuna qaytadi)
        Center(
          child: TextBtn(
            label: subTr('subRestore', 'Xaridni tiklash'),
            h: 40, fs: 14, color: p.t1,
            onTap: busy ? () {} : () => store.restorePremium(),
          ),
        ),
        const SizedBox(height: 4),
      ]);
      // Avtomatik yangilanish sharti + bekor qilish yo'li (Apple 3.1.2).
      // Modul ro'yxatida NARXSIZ variant: bo'limlar summasi har xil, bitta
      // summa yozish noto'g'ri oshkorlik bo'lardi (aniq summa paywall'da).
      // Eski ko'rinishda esa do'kon narxi bo'lmasa matn umuman chizilmaydi —
      // noto'g'ri summali oshkorlik oshkorlik emas.
      if (perModule) {
        children.addAll([
          Tx(
            subTr('subAutoRenewNoteMod',
                "Har bo'lim obunasi avtomatik yangilanadi. Aniq summa o'sha "
                "bo'limning obuna oynasida ko'rsatiladi. Istalgan vaqtda bekor "
                "qilish: App Store → Apple ID → Obunalar."),
            size: 12, color: p.t4, lh: 16,
          ),
          const SizedBox(height: 7),
        ]);
      } else if (hasPrice) {
        children.addAll([
          Tx(
            subTr(
              'subAutoRenewNote',
              'Obuna avtomatik yangilanadi. Joriy davr tugashidan 24 soat oldin '
                  'hisobingizdan {price} yechiladi. Istalgan vaqtda bekor qilish: '
                  'App Store → Apple ID → Obunalar.',
              {'price': priceMonthly},
            ),
            size: 12, color: p.t4, lh: 16,
          ),
          const SizedBox(height: 7),
        ]);
      }
      // Foydalanish shartlari (Apple standart EULA) + Maxfiylik siyosati — tappable
      final linkStyle = tbStyle(size: 12, w: FontWeight.w600, color: p.t2).copyWith(decoration: TextDecoration.underline);
      children.add(Row(
        children: [
          Tap(
            onTap: () => _openUrl(
                'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
            child: Text(subTr('subTerms', 'Foydalanish shartlari'), style: linkStyle, textScaler: TextScaler.noScaling),
          ),
          Tx('   ·   ', size: 12, color: p.t6),
          Tap(
            onTap: () => _openUrl('$apiUrl/privacy'),
            child: Text(subTr('subPrivacy', 'Maxfiylik siyosati'), style: linkStyle, textScaler: TextScaler.noScaling),
          ),
        ],
      ));
    }

    // Qizil (tugagan) ko'rinish faqat ESKI kartaga tegishli — modul ro'yxatida
    // holat har qatorda alohida, butun kartani qizartirish yolg'on bo'lardi.
    final bool expiredLook = sub.expired && !perModule;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tb.padX),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Cap((L0['profSub'] as String? ?? 'Obuna')),
          ),
          GlassCard(
            r: 24,
            pad: const EdgeInsets.all(16),
            color: expiredLook ? p.coral.withValues(alpha: .08) : null,
            border: expiredLook ? p.coral.withValues(alpha: .30) : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}

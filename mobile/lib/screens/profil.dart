// Profil ekrani — prototype/template.html «isProfil» bloki bilan 1:1
// (avatar + ism + telefon sarlavhasi, profRows qatorlari, «Chiqish», versiya).
// Qo'shimcha (prototipdan keyingi mahsulot qarori): obuna bo'limi — 2026-08-04
// dan HAR BO'LIM uchun alohida qator (_SubCard izohiga qarang).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final p = curPal();
    final rows = (v['profRows'] as List).cast<Map<String, dynamic>>();
    // Avatar picker keshida saqlanadi — OS keshni tozalasa fayl yo'qoladi;
    // yo'q faylni FileImage'ga bersak render xatosi bo'ladi, shuning uchun tekshiramiz.
    final avatarPath = v['meAvatar'] as String?;
    final File? avatarFile =
        (avatarPath != null && File(avatarPath).existsSync()) ? File(avatarPath) : null;

    return Stack(
      children: [
        ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar — bosilsa galereyadan rasm tanlanadi (edit photo)
              Tap(
                onTap: () => v['pickAvatar'](),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: p.card2,
                        shape: BoxShape.circle,
                        image: avatarFile != null
                            ? DecorationImage(image: FileImage(avatarFile), fit: BoxFit.cover)
                            : null,
                      ),
                      child: avatarFile == null
                          ? Tx(v['meInitials'], size: 22, w: FontWeight.w600, color: p.ink)
                          : null,
                    ),
                    Positioned(
                      right: -2, bottom: -2,
                      child: Container(
                        width: 24, height: 24, alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.ink, shape: BoxShape.circle,
                          border: Border.all(color: p.bg, width: 2),
                        ),
                        child: Icon(Icons.photo_camera_outlined, size: 12, color: p.bg),
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
                        width: 200,
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            border: Border.all(color: p.bd),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: StoreField(
                            value: v['meEditVal'],
                            onChanged: (t) => v['onMeName'](t),
                            hint: L0['yourNameHint'] as String,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink),
                            onSubmit: () => v['meNameSave'](),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tap(
                        onTap: () => v['meNameSave'](),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(18)),
                          child: Tx(L0['btnOk'] as String, size: 12.5, w: FontWeight.w600, color: p.bg),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  // Ism — mijozlarga shu ko'rinadi; bosib tahrirlash mumkin
                  child: Tap(
                    onTap: () => v['meEditToggle'](),
                    child: Tx(v['meName'], size: 18, w: FontWeight.w700, color: p.ink),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Tx(v['mePhoneFmt'], size: 13, color: p.t2),
              ),
              // 8 xonali unikal ID (PO 2026-07-28) — kengayish uchun; nusxalash oson format
              if ('${v['meNoFmt'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Tx('${v['meNoFmt']}', size: 12, w: FontWeight.w600, color: p.t4, tab: true),
                ),
            ],
          ),
        ),
        // Obuna bo'limi — har bo'lim uchun alohida qator (_SubCard).
        // DIQQAT: const EMAS — store o'zgarganda qayta qurilishi kerak.
        _SubCard(v: v),
        for (final pr in rows)
          Tap(
            onTap: pr['tap'],
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 24),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
              child: Row(
                children: [
                  // danger (profil o'chirish) — qizil rangda
                  Expanded(child: Tx(pr['label'], size: 14.5, color: pr['danger'] == true ? p.red : p.ink)),
                  const SizedBox(width: 12),
                  if (pr['isSwitch'] == true)
                    Container(
                      width: 44,
                      height: 26,
                      decoration: BoxDecoration(
                        color: pr['trk'],
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 200),
                            top: 3,
                            left: pr['knobLeft'],
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: pr['knob'],
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x40000000),
                                    offset: Offset(0, 1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (pr['isPlain'] == true) ...[
                    Tx(pr['value'], size: 13, color: p.t3),
                    const SizedBox(width: 12),
                    ChevRight(color: p.t6),
                  ],
                ],
              ),
            ),
          ),
        Tap(
          onTap: v['logout'],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tx((v['L'] as Map)['logout'] as String, size: 14.5, w: FontWeight.w600, color: p.ink),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Tx(L0['versionFooter'] as String, size: 11, color: p.t6)),
        ),
      ],
        ),
        // #34: profil o'chirish — SMS kod bilan tasdiqlash modali
        if (v['delOtpOpen'] == true) _DelOtpModal(v: v),
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: p.bg,
                border: Border.all(color: p.bd2),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 40, offset: const Offset(0, 16)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(_t('delOtpTitle', "Profil o'chirilsinmi?"), size: 16, w: FontWeight.w700, color: p.red),
                  const SizedBox(height: 6),
                  Tx(
                    _t('delOtpWarn',
                        "Diqqat: profilingiz o'chiriladi va barcha yozuvlaringizga kirish yopiladi."),
                    size: 12.5, color: p.t1, lh: 17,
                  ),
                  const SizedBox(height: 4),
                  Tx(
                    phone.isEmpty
                        ? _t('delOtpSentTo', 'Raqamingizga yuborilgan SMS kodni kiriting:')
                        : '${_t('delOtpSentTo2', 'SMS kod yuborildi:')} $phone',
                    size: 12.5, color: p.t3, lh: 17,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: TextStyle(
                        color: p.ink, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 6),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '•••••',
                      hintStyle: TextStyle(color: p.t5, letterSpacing: 6),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.bd)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.bd)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.red)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GhostBtn(
                          label: _t('btnCancel', 'Bekor qilish'), h: 42, fs: 13.5,
                          onTap: () { if (!busy) (v['delOtpCancel'] as Function)(); },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkBtn(
                          label: _t('delOtpBtn', "O'chirish"), h: 42, fs: 13.5, loading: busy,
                          onTap: () => (v['delOtpConfirm'] as Function)(_code.text),
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

  /// Bitta modul qatori: nom + holat + CTA.
  /// `legacy` — eski butun-ilova premiumi faol: hamma modul qamrab olingan.
  Widget _modRow(Pal p, Map<String, dynamic> e,
      {required bool legacy, required bool last, required bool dark}) {
    final String module = '${e['module'] ?? ''}';
    final bool active = legacy || e['active'] == true;
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
    Color stateColor = p.t1;
    if (legacy) {
      state = subTr('subModLegacy', 'Premium obunangizga kiritilgan');
      stateColor = p.green;
    } else if (active) {
      final d = _fmtDate(e['until']);
      state = d.isEmpty
          ? subTr('subModActive', 'Faol')
          : subTr('subModActiveUntil', 'Faol · {d} gacha', {'d': d});
      stateColor = p.green;
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

    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: last
          ? null
          : BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Uzun tarjima («Propiedades en alquiler») kesilmasin — o'raladi
                Tx(_modName(module), size: 13.5, w: FontWeight.w600, color: p.ink, maxLines: 2),
                const SizedBox(height: 2),
                Tx(state, size: 11.5, color: stateColor, lh: 15, maxLines: 2),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (active)
            // Faol obuna — CTA kerak emas (paywall "sotib olish" degan bo'lardi)
            Icon(Icons.check_circle_outline, size: 18, color: p.green)
          else
            ConstrainedBox(
              // Tugma kengligi cheklangan: ism uchun joy qolsin
              constraints: const BoxConstraints(maxWidth: 128),
              child: Container(
                height: 32,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  // Limit tugagan bo'lsa — asosiy (to'ldirilgan) tugma
                  color: locked ? p.ink : null,
                  border: locked ? null : Border.all(color: p.bd),
                  borderRadius: BorderRadius.circular(16),
                ),
                // Uzun tarjimada («S'abonner») «...» yo'q — sig'masa kichrayadi
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Tx(subTr('subModSubscribe', "Obuna bo'lish"),
                      size: 12.5, w: FontWeight.w600,
                      color: locked ? p.bg : p.ink, maxLines: 1),
                ),
              ),
            ),
        ],
      ),
    );

    // Faol modulda bosish yo'q; qolganida butun qator paywall'ni ochadi.
    return active ? row : Tap(onTap: () => _openPaywall(module), child: row);
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

    final children = <Widget>[
      Row(
        children: [
          Expanded(child: Cap((L0['profSub'] as String? ?? 'Obuna').toUpperCase())),
          // Narx — FAQAT do'kon (StoreKit) summasi va FAQAT eski premium
          // ko'rinishida. Modul ro'yxatida bitta summa bo'lishi mumkin emas
          // (har bo'lim har xil), shuning uchun u yerda umuman chizilmaydi.
          if (hasPrice && !perModule)
            Tx(priceMonthly, size: 12.5, w: FontWeight.w700, color: p.ink, tab: true),
        ],
      ),
      const SizedBox(height: 10),
    ];

    if (perModule) {
      // Bir qatorli izoh — modelni tushuntiradi, narx ATAMAYDI.
      children.add(Tx(
        subTr('subInfo',
            "Har bo'lim alohida obuna — bepul limitdan keyin faqat kerakli "
            "bo'limni ochasiz. To'lov tez orada ulanadi"),
        size: 12.5, color: p.t1, lh: 17,
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
        titleColor = p.red;
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
        Tx(title, size: 16, w: FontWeight.w700, color: titleColor),
        const SizedBox(height: 4),
        Tx(body, size: 12.5, color: p.t1, lh: 17),
      ]);

      // ≤3 kun qolgan bo'lsa — kartada ham ogohlantirish (banner bilan bir ohangda)
      if (sub.warnSoon) {
        children.addAll([
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, size: 15, color: w),
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
        // busy bo'lsa spinnerli (bosish bloklangan). Tugaganda asosiy (qora),
        // aks holda kontur — loading param InkBtn/GhostBtn'da o'zi ishlaydi.
        sub.expired
            ? InkBtn(label: ctaLabel, h: 44, fs: 14, onTap: cta, loading: busy)
            : GhostBtn(label: ctaLabel, h: 42, fs: 13.5, onTap: cta, loading: busy),
      ]);
    } else if (ios && rows.any((e) => e['active'] == true)) {
      // Faol modul obunasi bor — Apple'da bekor qilish/almashtirish faqat
      // App Store obunalar sahifasida bo'ladi (store.buyPremium ESKI mahsulotni
      // sotib olardi — modul obunalari uchun noto'g'ri).
      children.addAll([
        const SizedBox(height: 14),
        GhostBtn(
          label: subTr('subManage', 'Obunani boshqarish'),
          h: 42, fs: 13.5,
          onTap: () => _openUrl(_kAppleSubsUrl),
        ),
      ]);
    }

    // ---- iOS: Apple 3.1.2 majburiy ma'lumotlari + Restore + havolalar ----
    if (ios) {
      children.addAll([
        const SizedBox(height: 10),
        // "Xaridni tiklash" — Apple talabi (qurilma almashsa obuna qaytadi)
        Center(
          child: Tap(
            onTap: busy ? () {} : () => store.restorePremium(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Tx(subTr('subRestore', 'Xaridni tiklash'),
                  size: 12.5, w: FontWeight.w600, color: p.t2),
            ),
          ),
        ),
        const SizedBox(height: 8),
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
            size: 11, color: p.t4, lh: 15,
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
            size: 11, color: p.t4, lh: 15,
          ),
          const SizedBox(height: 7),
        ]);
      }
      // Foydalanish shartlari (Apple standart EULA) + Maxfiylik siyosati — tappable
      children.add(Row(
        children: [
          Tap(
            onTap: () => _openUrl(
                'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
            child: Text(
              subTr('subTerms', 'Foydalanish shartlari'),
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: p.t2,
                  decoration: TextDecoration.underline),
            ),
          ),
          Tx('   ·   ', size: 11, color: p.t6),
          Tap(
            onTap: () => _openUrl('$apiUrl/privacy'),
            child: Text(
              subTr('subPrivacy', 'Maxfiylik siyosati'),
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: p.t2,
                  decoration: TextDecoration.underline),
            ),
          ),
        ],
      ));
    }

    // Qizil (tugagan) ko'rinish faqat ESKI kartaga tegishli — modul ro'yxatida
    // holat har qatorda alohida, butun kartani qizartirish yolg'on bo'lardi.
    final bool expiredLook = sub.expired && !perModule;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 18, 24, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: expiredLook ? p.red.withValues(alpha: .07) : p.hov2,
        border: Border.all(color: expiredLook ? p.red.withValues(alpha: .30) : p.bd2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

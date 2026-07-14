import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';

/// Ekranlarga uzatiladigan navigatsiya + palitra konteyneri.
class Nav {
  final P p;
  final bool isDark;
  final int tab;
  final Partner? client;
  final VoidCallback toggleDark;
  final void Function(int) goTab;
  final void Function(Partner) openClient;
  final VoidCallback back;
  final VoidCallback openSheet;
  final VoidCallback closeSheet;
  final VoidCallback openNotifs;
  final VoidCallback closeNotifs;
  final VoidCallback openReceipt;
  final VoidCallback closeReceipt;
  const Nav({
    required this.p, required this.isDark, required this.tab, required this.client,
    required this.toggleDark, required this.goTab, required this.openClient,
    required this.back, required this.openSheet, required this.closeSheet,
    required this.openNotifs, required this.closeNotifs,
    required this.openReceipt, required this.closeReceipt,
  });
}

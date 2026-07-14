import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';

/// Navigatsiya + palitra. Overlay'lar Set orqali boshqariladi.
class Nav {
  final P p;
  final bool isDark;
  final int tab;
  final Partner? client;
  final bool flipped;
  final VoidCallback toggleDark;
  final void Function(int) goTab;
  final void Function(Partner) openClient;
  final VoidCallback back;
  final void Function(String) open;
  final void Function(String) close;
  final bool Function(String) isOpen;
  final VoidCallback toggleFlip;
  const Nav({
    required this.p, required this.isDark, required this.tab, required this.client,
    required this.flipped, required this.toggleDark, required this.goTab,
    required this.openClient, required this.back, required this.open,
    required this.close, required this.isOpen, required this.toggleFlip,
  });
}

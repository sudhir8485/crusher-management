import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  // ── Body ──────────────────────────────────────────────────────────────────
  static const TextStyle bodySmall  = TextStyle(fontSize: 11, height: 1.4);
  static const TextStyle bodyBase   = TextStyle(fontSize: 13, height: 1.45);
  static const TextStyle bodyMedium = TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w500);

  // ── Labels (semi-bold) ────────────────────────────────────────────────────
  static const TextStyle labelXS   = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.2);
  static const TextStyle labelSM   = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2);
  static const TextStyle labelBase = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

  // ── Section caps ──────────────────────────────────────────────────────────
  static const TextStyle sectionCap = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8);

  // ── Numeric / financial values ────────────────────────────────────────────
  static const TextStyle numericSM   = TextStyle(fontSize: 13, fontWeight: FontWeight.bold);
  static const TextStyle numericBase = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);

  // ── Titles ────────────────────────────────────────────────────────────────
  static const TextStyle titleSM   = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const TextStyle titleBase = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);
  static const TextStyle titleLG   = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
}

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const Color surface      = Color(0xFFF7F8FA); // scaffold bg (not pure white)
  static const Color surfaceMuted = Color(0xFFEEF0F4); // filter bars, summary bars

  // ── Status: success (green) ───────────────────────────────────────────────
  static const Color successText   = Color(0xFF1B6B3A);
  static const Color successBg     = Color(0xFFDFF0E8);
  static const Color successBorder = Color(0xFF8FC7AB);

  // ── Status: warning (amber/orange) ────────────────────────────────────────
  static const Color warningText   = Color(0xFF874D00);
  static const Color warningBg     = Color(0xFFFAEFD7);
  static const Color warningBorder = Color(0xFFD4A849);

  // ── Status: danger (red) ─────────────────────────────────────────────────
  static const Color dangerText   = Color(0xFF9B1C1C);
  static const Color dangerBg     = Color(0xFFFDE8E8);
  static const Color dangerBorder = Color(0xFFE8A0A0);

  // ── Status: info (blue) ───────────────────────────────────────────────────
  static const Color infoText   = Color(0xFF1A4A8A);
  static const Color infoBg     = Color(0xFFDEEAF8);
  static const Color infoBorder = Color(0xFF93BAE3);

  // ── Financial aliases ─────────────────────────────────────────────────────
  static const Color debitColor   = dangerText;
  static const Color creditColor  = successText;
  static const Color balanceColor = warningText;
  static const Color advanceColor = infoText;

  // ── Neutral text scale ────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted     = Color(0xFF9CA3AF);

  // ── Borders ───────────────────────────────────────────────────────────────
  static const Color borderSubtle  = Color(0xFFE5E7EB); // card borders
  static const Color borderDefault = Color(0xFFD1D5DB); // input borders

  // ── Attendance status ─────────────────────────────────────────────────────
  static const Color statusPresent = Color(0xFF166534);
  static const Color statusHalfDay = Color(0xFF92400E);
  static const Color statusAbsent  = Color(0xFF991B1B);
  static const Color statusLeave   = Color(0xFF1E40AF);
}

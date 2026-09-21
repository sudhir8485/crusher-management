import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double base = 16.0;
  static const double lg   = 20.0;
  static const double xl   = 24.0;

  static const EdgeInsets cardPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 12);

  static const BorderRadius cardRadius   = BorderRadius.all(Radius.circular(12));
  static const BorderRadius chipRadius   = BorderRadius.all(Radius.circular(8));
  static const BorderRadius dialogRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius badgeRadius  = BorderRadius.all(Radius.circular(8));
}

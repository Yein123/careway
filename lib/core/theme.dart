import 'package:flutter/material.dart';

class CwColors {
  static const primary = Color(0xFF6C4EE3);
  static const primaryDark = Color(0xFF4B32B8);
  static const ink = Color(0xFF1E1B2E);
  static const muted = Color(0xFF625E78);
  static const surface = Color(0xFFF7F6FB);
  static const line = Color(0xFFE7E4F0);
  static const lilac = Color(0xFFF1EDFD);
  static const lilacLine = Color(0xFFD6CDF8);
  static const teal = Color(0xFF127A94);
  static const tealDark = Color(0xFF0E5E72);
  static const tealSoft = Color(0xFFDDF2F7);
  static const pink = Color(0xFFC2365E);
  static const pinkSoft = Color(0xFFFCE4EB);
  static const deliveryBlue = Color(0xFF2F64A8);
  static const deliverySoft = Color(0xFFE3ECF8);
  static const success = Color(0xFF1D9E5F);
  static const successDark = Color(0xFF17785A);
  static const successSoft = Color(0xFFE3F5EC);
  static const amber = Color(0xFF8A4510);
  static const amberSoft = Color(0xFFFDEBD9);
  static const star = Color(0xFFF5B740);
  static const white = Color(0xFFFFFFFF);
}

const cwFont = 'PlusJakartaSans';

class CwTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: CwColors.primary,
      primary: CwColors.primary,
      surface: CwColors.white,
      error: CwColors.pink,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: cwFont,
      scaffoldBackgroundColor: CwColors.surface,
    );
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: 2),
        );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: CwColors.ink,
        displayColor: CwColors.ink,
        fontFamily: cwFont,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: CwColors.surface,
        foregroundColor: CwColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CwColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: border(CwColors.line),
        enabledBorder: border(CwColors.line),
        focusedBorder: border(CwColors.primary),
        errorBorder: border(CwColors.pink),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

/// Text styles matching the design's sizes.
class CwText {
  static const h1 = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: CwColors.ink);
  static const h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CwColors.ink);
  static const h3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CwColors.ink);
  static const body = TextStyle(fontSize: 15, height: 1.5, color: CwColors.ink);
  static const bodyBold = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CwColors.ink);
  static const muted = TextStyle(fontSize: 14, height: 1.5, color: CwColors.muted);
  static const small = TextStyle(fontSize: 13, color: CwColors.muted);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CwColors.ink);
  static const overline = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: CwColors.primary);
}

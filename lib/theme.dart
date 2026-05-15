// lib/theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Brand colours ────────────────────────────────────────────────────────────
const kAccent       = Color(0xFF7C6EF5);
const kAccentHover  = Color(0xFF6355E0);
const kAccent2      = Color(0xFFA89DF8);
const kSuccess      = Color(0xFF0FCF8A);
const kWarning      = Color(0xFFF6A614);
const kDanger       = Color(0xFFF4366A);

// ── Dark palette ──────────────────────────────────────────────────────────────
const kDarkBgPrimary   = Color(0xFF06091A);
const kDarkBgSecondary = Color(0xFF0A0F24);
const kDarkCard        = Color(0xFF0E1630);
const kDarkHover       = Color(0xFF162040);
const kDarkText        = Color(0xFFEEF2FF);
const kDarkTextSec     = Color(0xFF7A8FBA);
const kDarkBorder      = Color(0xFF1A2848);
const kDarkInputBg     = Color(0xFF0C1228);

// ── Light palette ─────────────────────────────────────────────────────────────
const kLightBgPrimary   = Color(0xFFF0F2F8);
const kLightBgSecondary = Color(0xFFE8EAF2);
const kLightCard        = Color(0xFFFFFFFF);
const kLightText        = Color(0xFF0F1630);
const kLightTextSec     = Color(0xFF4A5680);
const kLightBorder      = Color(0xFFC8CEDF);

// ─────────────────────────────────────────────────────────────────────────────

ThemeData buildDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    colorScheme: ColorScheme.dark(
      primary:   kAccent,
      secondary: kAccent2,
      surface:   kDarkCard,
      error:     kDanger,
      onPrimary: Colors.white,
      onSurface: kDarkText,
    ),
    scaffoldBackgroundColor: kDarkBgPrimary,
    cardColor: kDarkCard,
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor:    kDarkText,
      displayColor: kDarkText,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor:  kDarkBgSecondary,
      foregroundColor:  kDarkText,
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: kDarkBgPrimary,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: kDarkBgSecondary,
      selectedItemColor: kAccent,
      unselectedItemColor: kDarkTextSec,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kDarkInputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kDarkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kDarkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: kDarkTextSec),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kDarkHover,
      selectedColor: kAccent.withOpacity(0.2),
      labelStyle: const TextStyle(color: kDarkText, fontSize: 12),
      side: const BorderSide(color: kDarkBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerColor: kDarkBorder,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kAccent,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

ThemeData buildLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    colorScheme: ColorScheme.light(
      primary:   kAccent,
      secondary: kAccent2,
      surface:   kLightCard,
      error:     kDanger,
      onPrimary: Colors.white,
      onSurface: kLightText,
    ),
    scaffoldBackgroundColor: kLightBgPrimary,
    cardColor: kLightCard,
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor:    kLightText,
      displayColor: kLightText,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kLightCard,
      foregroundColor: kLightText,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: kLightCard,
      selectedItemColor: kAccent,
      unselectedItemColor: kLightTextSec,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kLightBgSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kLightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kLightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: kLightTextSec),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    dividerColor: kLightBorder,
  );
}

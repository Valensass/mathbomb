import 'package:flutter/material.dart';

/// BOMB MATH visual identity: bomb-squad industrial.
abstract final class AppColors {
  static const bg = Color(0xFF05090D);
  static const bgDeep = Color(0xFF020507);
  static const panel = Color(0xFF0E1820);
  static const panelHi = Color(0xFF15222D);
  static const line = Color(0xFF22333F);
  static const amber = Color(0xFFFFC43D);
  static const amberDeep = Color(0xFFE09A12);
  static const cyan = Color(0xFF3BE8D2);
  static const red = Color(0xFFFF5252);
  static const redDeep = Color(0xFFB31F1F);
  static const green = Color(0xFF62E58C);
  static const text = Color(0xFFEAF3F8);
  static const muted = Color(0xFF8BA1B0);
  static const steel = Color(0xFF3A4C59);

  static const wires = <Color>[
    Color(0xFFFF5A5A), // A red
    Color(0xFF3FA9FF), // B blue
    Color(0xFFFFC43D), // C amber
    Color(0xFF5CE08A), // D green
  ];

  static const wireNames = <String>['A', 'B', 'C', 'D'];
}

abstract final class AppRadius {
  static const s = 10.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
}

ThemeData buildTheme({required bool highContrast}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.amber,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.amber,
    onPrimary: const Color(0xFF1A1200),
    secondary: AppColors.cyan,
    onSecondary: const Color(0xFF00201C),
    surface: AppColors.panel,
    onSurface: AppColors.text,
    error: AppColors.red,
    outline: highContrast ? AppColors.text : AppColors.line,
  );

  const base = TextTheme(
    displayLarge: TextStyle(
      fontSize: 54,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.5,
      height: 1.0,
    ),
    displayMedium: TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
      height: 1.0,
    ),
    headlineLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    ),
    titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 16, height: 1.35),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4),
    bodySmall: TextStyle(fontSize: 12.5, height: 1.35),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
    labelMedium: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    textTheme: base.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    splashFactory: InkSparkle.splashFactory,
    dividerColor: AppColors.line,
    iconTheme: const IconThemeData(color: AppColors.text, size: 22),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.panelHi,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        side: const BorderSide(color: AppColors.line),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 14.5,
        height: 1.45,
        color: AppColors.muted,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.panelHi,
      contentTextStyle: const TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.s),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel,
      hintStyle: const TextStyle(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.s),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.s),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.s),
        borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.panelHi,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
      ),
    ),
  );
}

/// Tabular, condensed numerals for the bomb display and HUD.
const monoDigit = TextStyle(
  fontFamily: 'monospace',
  fontWeight: FontWeight.w900,
  fontFeatures: [FontFeature.tabularFigures()],
  letterSpacing: 1,
  color: AppColors.amber,
);

const hudLabel = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.8,
  color: AppColors.muted,
);

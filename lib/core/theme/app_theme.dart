import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Brand palette ────────────────────────────────────────────────────────
  static const _primaryColor   = Color(0xFF6C3CE1); // deep violet
  static const _secondaryColor = Color(0xFFE53935); // battle red
  static const _bgColor        = Color(0xFF0F0F1A); // dark arena
  static const _surfaceColor   = Color(0xFF1A1A2E);
  static const _cardColor      = Color(0xFF1A1A2E);

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bgColor,
        colorScheme: ColorScheme.dark(
          primary: _primaryColor,
          secondary: _secondaryColor,
          surface: _surfaceColor,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        cardTheme: CardThemeData(
          color: _cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _secondaryColor,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22),
          bodyMedium: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
          labelSmall: TextStyle(color: Color(0xFF888888), fontSize: 12),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF252540),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primaryColor, width: 1.5),
          ),
          hintStyle: const TextStyle(color: Color(0xFF666688)),
        ),
      );
}

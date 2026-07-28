import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1a0a2e);
  static const Color primaryLight = Color(0xFF2d1b4e);
  static const Color accent = Color(0xFFc9a227);
  static const Color accentDark = Color(0xFF9a7a1a);
  static const Color danger = Color(0xFFc0392b);
  static const Color success = Color(0xFF27ae60);
  static const Color warning = Color(0xFFe67e22);
  static const Color background = Color(0xFF0d0d1a);
  static const Color surface = Color(0xFF1e1e2e);
  static const Color surfaceVariant = Color(0xFF2a2a3e);
  static const Color onSurface = Color(0xFFe8e8f0);
  static const Color onSurfaceMuted = Color(0xFF8888a0);
  static const Color masterRed = Color(0xFF8b0000);

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          onPrimary: Color(0xFF1a0a2e),
          secondary: masterRed,
          onSecondary: Colors.white,
          surface: surface,
          onSurface: onSurface,
          error: danger,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: accent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: accent),
        ),
        cardTheme: const CardThemeData(
          color: surface,
          elevation: 2,
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Color(0xFF1a0a2e),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: const BorderSide(color: accent),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: accent),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: surfaceVariant,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF404060)),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF404060)),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: accent, width: 1.5),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          labelStyle: TextStyle(color: onSurfaceMuted),
          hintStyle: TextStyle(color: onSurfaceMuted),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2a2a3e),
          thickness: 1,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accent,
          foregroundColor: Color(0xFF1a0a2e),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: surfaceVariant,
          labelStyle: TextStyle(color: onSurface, fontSize: 12),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: accent,
          unselectedLabelColor: onSurfaceMuted,
          indicatorColor: accent,
          dividerColor: Colors.transparent,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? accent : null),
          checkColor: WidgetStateProperty.all(const Color(0xFF1a0a2e)),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              color: accent, fontWeight: FontWeight.bold, fontSize: 28),
          headlineMedium: TextStyle(
              color: accent, fontWeight: FontWeight.bold, fontSize: 22),
          headlineSmall: TextStyle(
              color: onSurface, fontWeight: FontWeight.bold, fontSize: 18),
          titleLarge: TextStyle(
              color: onSurface, fontWeight: FontWeight.w600, fontSize: 16),
          titleMedium: TextStyle(color: onSurface, fontSize: 14),
          bodyLarge: TextStyle(color: onSurface, fontSize: 14),
          bodyMedium: TextStyle(color: onSurfaceMuted, fontSize: 12),
          labelLarge: TextStyle(
              color: onSurface, fontWeight: FontWeight.w600, fontSize: 14),
          labelMedium: TextStyle(color: onSurfaceMuted, fontSize: 11),
        ),
      );
}

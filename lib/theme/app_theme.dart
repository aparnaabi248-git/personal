import 'package:flutter/material.dart';

/// Colour tokens for the app's colourful dashboard look.
///
/// Kept in one place so screens never hard-code a hex value, which is what
/// makes the palette stay consistent as screens are added.
class AppColors {
  const AppColors._();

  // Accents
  static const Color indigo = Color(0xFF4F46E5);
  static const Color purple = Color(0xFF7C5CFF);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color blue = Color(0xFF4A8BFF);
  static const Color cyan = Color(0xFF22B8F0);
  static const Color teal = Color(0xFF22C7A9);
  static const Color green = Color(0xFF34D399);
  static const Color orange = Color(0xFFFF9F43);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color pink = Color(0xFFFF5C8A);

  // Neutrals
  static const Color ink = Color(0xFF1F2340);
  static const Color muted = Color(0xFF8A8FA3);
  static const Color canvas = Color(0xFFF5F6FB);
  static const Color sidebar = Color(0xFF1A1B3D);
  static const Color sidebarHover = Color(0xFF272B5E);

  /// Positive / negative money states.
  static const Color income = Color(0xFF22C7A9);
  static const Color expense = Color(0xFFFF6B6B);
}

/// The gradient presets used by stat tiles and badges.
class AppGradients {
  const AppGradients._();

  static const LinearGradient violetBlue = LinearGradient(
    colors: <Color>[AppColors.purple, AppColors.blue],
  );
  static const LinearGradient blueCyan = LinearGradient(
    colors: <Color>[AppColors.blue, AppColors.cyan],
  );
  static const LinearGradient orangeCoral = LinearGradient(
    colors: <Color>[AppColors.orange, AppColors.coral],
  );
  static const LinearGradient tealGreen = LinearGradient(
    colors: <Color>[AppColors.teal, AppColors.green],
  );
}

/// The single app theme.
///
/// Deliberately colourful and rounded, but with restrained typography so the
/// gradients in the stat tiles stay the loudest thing on screen.
ThemeData buildAppTheme() {
  final ColorScheme scheme =
      ColorScheme.fromSeed(seedColor: AppColors.indigo);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    splashFactory: InkSparkle.splashFactory,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: Color(0xFFE4E6F2)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4E6F2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4E6F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.indigo, width: 1.6),
      ),
      labelStyle: const TextStyle(color: AppColors.muted),
    ),

    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.sidebar,
      indicatorColor: Colors.white24,
      selectedIconTheme: IconThemeData(color: Colors.white),
      unselectedIconTheme: IconThemeData(color: Colors.white54),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFEFF0F7),
      thickness: 1,
      space: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(color: AppColors.ink),
      bodySmall: TextStyle(color: AppColors.muted),
    ),
  );
}
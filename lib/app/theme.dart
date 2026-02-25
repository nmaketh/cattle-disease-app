import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme() {
  const primary = Color(0xFF2E7D4F);
  const secondary = Color(0xFF6A8B78);
  const tertiary = Color(0xFFC79A3B);
  const surfaceWarm = Color(0xFFF7F5EF);
  const surfaceSoft = Color(0xFFEFEEE6);
  const borderSoft = Color(0xFFD8DCCF);
  const textDark = Color(0xFF1E241F);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
    secondary: secondary,
    tertiary: tertiary,
    brightness: Brightness.light,
  );

  final baseText = const TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.4),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  final textTheme = GoogleFonts.manropeTextTheme(baseText).copyWith(
    headlineMedium: GoogleFonts.sora(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      height: 1.05,
    ),
    titleLarge: GoogleFonts.sora(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.35,
      height: 1.1,
    ),
    titleMedium: GoogleFonts.manrope(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.15,
    ),
    titleSmall: GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.15,
    ),
    bodyLarge: GoogleFonts.manrope(fontSize: 16, height: 1.42),
    bodyMedium: GoogleFonts.manrope(fontSize: 14, height: 1.42),
    labelLarge: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surfaceWarm,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: surfaceWarm,
      foregroundColor: textDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: borderSoft),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFFEFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        foregroundColor: textDark,
        side: const BorderSide(color: borderSoft),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      height: 72,
      indicatorColor: const Color(0xFFE5F0E7),
      backgroundColor: const Color(0xFFFFFEFB),
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2B332C),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF414B42)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: borderSoft, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceSoft,
      selectedColor: const Color(0xFFE5F0E7),
      labelStyle: const TextStyle(color: textDark, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: textDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: borderSoft),
      ),
      side: const BorderSide(color: borderSoft),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      iconColor: primary,
      textColor: textDark,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: primary.withValues(alpha: 0.18),
      selectionHandleColor: primary,
    ),
    iconTheme: const IconThemeData(color: primary),
    extensions: const <ThemeExtension<dynamic>>[],
  );
}

ThemeData buildAppDarkTheme() {
  const primary = Color(0xFF6FC48E);
  const secondary = Color(0xFF9FB5A7);
  const tertiary = Color(0xFFD9AE5D);
  const surface = Color(0xFF121612);
  const surfaceSoft = Color(0xFF1A201A);
  const surfacePanel = Color(0xFF171D17);
  const borderSoft = Color(0xFF313B33);
  const textLight = Color(0xFFEAF0E7);
  const textMuted = Color(0xFFB7C2B6);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
    secondary: secondary,
    tertiary: tertiary,
    brightness: Brightness.dark,
  );

  final baseText = const TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.4),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  final textTheme = GoogleFonts.manropeTextTheme(baseText).copyWith(
    headlineMedium: GoogleFonts.sora(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      height: 1.05,
      color: textLight,
    ),
    titleLarge: GoogleFonts.sora(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.35,
      height: 1.1,
      color: textLight,
    ),
    titleMedium: GoogleFonts.manrope(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.15,
      color: textLight,
    ),
    titleSmall: GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.15,
      color: textLight,
    ),
    bodyLarge: GoogleFonts.manrope(fontSize: 16, height: 1.42, color: textLight),
    bodyMedium: GoogleFonts.manrope(fontSize: 14, height: 1.42, color: textLight),
    bodySmall: GoogleFonts.manrope(fontSize: 12, height: 1.35, color: textMuted),
    labelLarge: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: textLight),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surface,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: surface,
      foregroundColor: textLight,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: surfacePanel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: borderSoft),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1C231D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2F7C4D),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        foregroundColor: textLight,
        side: const BorderSide(color: borderSoft),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      height: 72,
      indicatorColor: const Color(0xFF233528),
      backgroundColor: const Color(0xFF141914),
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1E2520),
      contentTextStyle: const TextStyle(color: textLight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2F3A34)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: borderSoft, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceSoft,
      selectedColor: const Color(0xFF24362A),
      labelStyle: const TextStyle(color: textLight, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: textLight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: borderSoft),
      ),
      side: const BorderSide(color: borderSoft),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      iconColor: primary,
      textColor: textLight,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: primary.withValues(alpha: 0.22),
      selectionHandleColor: primary,
    ),
    iconTheme: const IconThemeData(color: primary),
    dialogTheme: DialogThemeData(
      backgroundColor: surfacePanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surfacePanel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    extensions: const <ThemeExtension<dynamic>>[],
  );
}

import 'package:flutter/material.dart';

ThemeData localCompassTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xff101012) : Colors.white;
  final surface = dark ? const Color(0xff1c1c1e) : const Color(0xfff5f5f7);
  final ink = dark ? const Color(0xfff5f5f7) : const Color(0xff1d1d1f);
  final secondary = dark ? const Color(0xff98989e) : const Color(0xff86868b);
  final green = dark ? const Color(0xff0a84ff) : const Color(0xff007aff);
  final sage = dark ? const Color(0xff172b46) : const Color(0xffe5efff);
  final line = dark ? const Color(0xff343437) : const Color(0xffe5e5ea);
  final colors = ColorScheme.fromSeed(seedColor: green, brightness: brightness)
      .copyWith(
        primary: green,
        onPrimary: dark ? const Color(0xffffffff) : Colors.white,
        primaryContainer: sage,
        onPrimaryContainer: green,
        surface: background,
        onSurface: ink,
        onSurfaceVariant: secondary,
        surfaceContainerLow: surface,
        surfaceContainer: surface,
        surfaceContainerHigh: surface,
        surfaceContainerHighest: sage,
        outline: secondary,
        outlineVariant: line,
        surfaceTint: Colors.transparent,
        error: dark ? const Color(0xffffb4ab) : const Color(0xffa73b35),
      );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: colors,
    scaffoldBackgroundColor: background,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(fontFamily: 'Inter')
        .copyWith(
          headlineLarge: TextStyle(
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation('wght', 350)],
            letterSpacing: -.5,
            color: ink,
          ),
          headlineMedium: TextStyle(
            fontSize: 21,
            height: 1.2,
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation('wght', 350)],
            letterSpacing: -.4,
            color: ink,
          ),
          headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation('wght', 350)],
            color: ink,
          ),
          titleSmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation('wght', 350)],
            color: ink,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation('wght', 350)],
            letterSpacing: -.4,
            color: ink,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation('wght', 350)],
            letterSpacing: -.3,
            color: ink,
          ),
          bodyLarge: TextStyle(
            fontWeight: FontWeight.w300,
            fontVariations: const [FontVariation('wght', 300)],
            fontSize: 14.5,
            height: 1.5,
            color: ink,
          ),
          bodyMedium: TextStyle(
            fontWeight: FontWeight.w300,
            fontVariations: const [FontVariation('wght', 300)],
            fontSize: 14,
            height: 1.5,
            color: ink,
          ),
          bodySmall: TextStyle(
            fontWeight: FontWeight.w300,
            fontVariations: const [FontVariation('wght', 300)],
            fontSize: 12.5,
            height: 1.4,
            color: secondary,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation('wght', 350)],
            color: ink,
          ),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: ink,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w400,
        fontVariations: const [FontVariation('wght', 350)],
        color: ink,
      ),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
          fontVariations: [FontVariation('wght', 350)],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: green),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: green, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: sage,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Inter',
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          fontVariations: const [FontVariation('wght', 350)],
          color: ink,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      showCheckmark: false,
      backgroundColor: surface,
      selectedColor: sage,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

ThemeData localCompassTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xff18181a) : const Color(0xfff1f0f6);
  final surface = dark ? const Color(0xff242426) : Colors.white;
  final ink = dark ? const Color(0xfff2f2f7) : const Color(0xff1c1c1e);
  final secondaryInk = dark ? const Color(0xffb5b5ba) : const Color(0xff626267);
  final softFill = dark ? const Color(0xff343438) : const Color(0xffe5e5ea);

  final colors = ColorScheme(
    brightness: brightness,
    primary: ink,
    onPrimary: surface,
    primaryContainer: softFill,
    onPrimaryContainer: ink,
    secondary: secondaryInk,
    onSecondary: surface,
    secondaryContainer: softFill,
    onSecondaryContainer: ink,
    error: ink,
    onError: surface,
    errorContainer: softFill,
    onErrorContainer: ink,
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: secondaryInk,
    surfaceContainerLowest: surface,
    surfaceContainerLow: surface,
    surfaceContainer: background,
    surfaceContainerHigh: dark
        ? const Color(0xff2c2c2e)
        : const Color(0xffededf0),
    surfaceContainerHighest: softFill,
    outline: dark ? const Color(0xff8e8e93) : const Color(0xff747479),
    outlineVariant: dark ? const Color(0xff48484c) : const Color(0xffd1d1d6),
    inverseSurface: ink,
    onInverseSurface: surface,
    inversePrimary: surface,
    surfaceTint: Colors.transparent,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

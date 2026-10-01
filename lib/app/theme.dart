import 'package:flutter/material.dart';

ThemeData buildTheme() {
  const background = Color(0xFFF6F4F1);
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1F4D3A),
    surface: background,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    ),
  );
}

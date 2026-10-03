import 'package:flutter/material.dart';

import 'package:bowie/app/design_tokens.dart';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark
      ? BowieColors.dark
      : BowieColors.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.textOnPrimary,
    primaryContainer: c.infoSoft,
    onPrimaryContainer: c.text,
    secondary: c.accent,
    onSecondary: c.textOnAccent,
    secondaryContainer: c.infoSoft,
    onSecondaryContainer: c.text,
    error: c.danger,
    onError: c.textOnPrimary,
    errorContainer: c.dangerSoft,
    onErrorContainer: c.danger,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.textMuted,
    surfaceContainerLowest: c.surface,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surfaceMuted,
    surfaceContainerHighest: c.surfaceMuted,
    outline: c.border,
    outlineVariant: c.border,
    shadow: BrandColors.night,
    surfaceTint: Colors.transparent,
  );

  final text = TextTheme(
    displayLarge: BowieType.display,
    displayMedium: BowieType.display,
    displaySmall: BowieType.display,
    headlineLarge: BowieType.title1,
    headlineMedium: BowieType.title1,
    headlineSmall: BowieType.title2,
    titleLarge: BowieType.title2,
    titleMedium: BowieType.title3,
    titleSmall: BowieType.bodyStrong,
    bodyLarge: BowieType.body,
    bodyMedium: BowieType.callout,
    bodySmall: BowieType.caption,
    labelLarge: BowieType.bodyStrong,
    labelMedium: BowieType.caption,
    labelSmall: BowieType.overline,
  ).apply(bodyColor: c.text, displayColor: c.text);

  const fieldRadius = BorderRadius.all(Radius.circular(BowieRadius.md));
  const buttonShape = RoundedRectangleBorder(borderRadius: fieldRadius);
  const buttonSize = Size(kBowieTouchTargetMin, 52);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: BowieType.fontFamily,
    textTheme: text,
    scaffoldBackgroundColor: c.background,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: BowieType.title3.copyWith(color: c.text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.infoSoft,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return BowieType.caption.copyWith(
          color: selected ? c.text : c.textMuted,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? c.text : c.textMuted);
      }),
    ),
    iconTheme: IconThemeData(color: c.text),
    dividerTheme: DividerThemeData(color: c.border, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      labelStyle: BowieType.body.copyWith(color: c.textMuted),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BowieSpacing.s4,
        vertical: BowieSpacing.s4,
      ),
      border: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: c.focusRing, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: c.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: c.danger, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        backgroundColor: c.primary,
        foregroundColor: c.textOnPrimary,
        textStyle: BowieType.bodyStrong,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        foregroundColor: c.text,
        side: BorderSide(color: c.border),
        textStyle: BowieType.bodyStrong,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(kBowieTouchTargetMin, kBowieTouchTargetMin),
        foregroundColor: c.link,
        textStyle: BowieType.bodyStrong,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: c.textOnPrimary,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(BowieRadius.lg)),
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(BowieRadius.lg)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.text,
      contentTextStyle: BowieType.callout.copyWith(color: c.background),
      shape: const RoundedRectangleBorder(borderRadius: fieldRadius),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BowieRadius.xl),
        ),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
  );
}

extension BowieThemeContext on BuildContext {
  /// Tokens semânticos de cor do tema atual.
  BowieColors get colors => Theme.of(this).extension<BowieColors>()!;
}

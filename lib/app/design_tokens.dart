// Gerado por scripts/generate-dart-tokens.py a partir de
// design/tokens/tokens.json. Não edite à mão.

import 'package:flutter/material.dart';

/// Cores da marca. Nos widgets, prefira os tokens semânticos de [BowieColors].
abstract final class BrandColors {
  static const night = Color(0xFF1D2B45);
  static const bowieBlue = Color(0xFF6FA8DC);
  static const chestnut = Color(0xFF9A6440);
  static const merle = Color(0xFF8C97A6);
  static const smile = Color(0xFFEE8E98);
  static const mist = Color(0xFFF4F6F8);
  static const white = Color(0xFFFFFFFF);
  static const bowieBlueStrong = Color(0xFF2F6FA8);
  static const chestnutStrong = Color(0xFF7A4C2E);
}

/// Tokens semânticos de cor, com variantes clara e escura.
@immutable
class BowieColors extends ThemeExtension<BowieColors> {
  const BowieColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.textOnPrimary,
    required this.primary,
    required this.primaryPressed,
    required this.accent,
    required this.textOnAccent,
    required this.link,
    required this.focusRing,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.categoryVaccines,
    required this.categoryShopping,
    required this.categoryIncidents,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color textOnPrimary;
  final Color primary;
  final Color primaryPressed;
  final Color accent;
  final Color textOnAccent;
  final Color link;
  final Color focusRing;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;
  final Color categoryVaccines;
  final Color categoryShopping;
  final Color categoryIncidents;

  static const light = BowieColors(
    background: Color(0xFFF4F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEDF0F4),
    border: Color(0xFFDDE2E8),
    text: Color(0xFF1D2B45),
    textMuted: Color(0xFF4A5670),
    textSubtle: Color(0xFF5A6782),
    textOnPrimary: Color(0xFFFFFFFF),
    primary: Color(0xFF1D2B45),
    primaryPressed: Color(0xFF2E3A52),
    accent: Color(0xFF6FA8DC),
    textOnAccent: Color(0xFF1D2B45),
    link: Color(0xFF2F6FA8),
    focusRing: Color(0xFF6FA8DC),
    success: Color(0xFF276B4E),
    successSoft: Color(0xFFE8F4EE),
    warning: Color(0xFFA15C00),
    warningSoft: Color(0xFFFDF1E2),
    danger: Color(0xFFB3364A),
    dangerSoft: Color(0xFFFBE9EC),
    info: Color(0xFF2F6FA8),
    infoSoft: Color(0xFFEAF3FB),
    categoryVaccines: Color(0xFF2F6FA8),
    categoryShopping: Color(0xFF7A4C2E),
    categoryIncidents: Color(0xFFB3364A),
  );

  static const dark = BowieColors(
    background: Color(0xFF0F1626),
    surface: Color(0xFF182235),
    surfaceMuted: Color(0xFF22304A),
    border: Color(0xFF2E3A52),
    text: Color(0xFFE8EDF3),
    textMuted: Color(0xFFAEB8C6),
    textSubtle: Color(0xFF9AA6B8),
    textOnPrimary: Color(0xFF0F1626),
    primary: Color(0xFF6FA8DC),
    primaryPressed: Color(0xFF8CC0EC),
    accent: Color(0xFF6FA8DC),
    textOnAccent: Color(0xFF0F1626),
    link: Color(0xFF8CC0EC),
    focusRing: Color(0xFF8CC0EC),
    success: Color(0xFF5FBF92),
    successSoft: Color(0xFF16352A),
    warning: Color(0xFFE3A44A),
    warningSoft: Color(0xFF3A2A12),
    danger: Color(0xFFF07C8C),
    dangerSoft: Color(0xFF3E1C24),
    info: Color(0xFF8CC0EC),
    infoSoft: Color(0xFF16304A),
    categoryVaccines: Color(0xFF8CC0EC),
    categoryShopping: Color(0xFFC4895F),
    categoryIncidents: Color(0xFFF07C8C),
  );

  @override
  BowieColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? textSubtle,
    Color? textOnPrimary,
    Color? primary,
    Color? primaryPressed,
    Color? accent,
    Color? textOnAccent,
    Color? link,
    Color? focusRing,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? categoryVaccines,
    Color? categoryShopping,
    Color? categoryIncidents,
  }) {
    return BowieColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      accent: accent ?? this.accent,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      link: link ?? this.link,
      focusRing: focusRing ?? this.focusRing,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      categoryVaccines: categoryVaccines ?? this.categoryVaccines,
      categoryShopping: categoryShopping ?? this.categoryShopping,
      categoryIncidents: categoryIncidents ?? this.categoryIncidents,
    );
  }

  @override
  BowieColors lerp(BowieColors? other, double t) {
    if (other == null) return this;
    return BowieColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      link: Color.lerp(link, other.link, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      categoryVaccines: Color.lerp(
        categoryVaccines,
        other.categoryVaccines,
        t,
      )!,
      categoryShopping: Color.lerp(
        categoryShopping,
        other.categoryShopping,
        t,
      )!,
      categoryIncidents: Color.lerp(
        categoryIncidents,
        other.categoryIncidents,
        t,
      )!,
    );
  }
}

/// Escala tipográfica. Use estes estilos; não crie tamanhos novos.
abstract final class BowieType {
  static const fontFamily = 'Figtree';

  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    height: 1.1765,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.68,
  );
  static const title1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 1.2143,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.42,
  );
  static const title2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    height: 1.2727,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.22,
  );
  static const title3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 1.3333,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const callout = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.4667,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 1.3846,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.3333,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.96,
  );
}

/// Espaçamento em grade de 4.
abstract final class BowieSpacing {
  static const double s0 = 0;
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;
}

abstract final class BowieRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
  static const double xl = 28;
  static const double full = 9999;
}

abstract final class BowieShadow {
  static const card = [
    BoxShadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x0F1D2B45)),
    BoxShadow(offset: Offset(0, 4), blurRadius: 12, color: Color(0x0F1D2B45)),
  ];
  static const sheet = [
    BoxShadow(offset: Offset(0, -2), blurRadius: 6, color: Color(0x0F1D2B45)),
    BoxShadow(offset: Offset(0, -12), blurRadius: 32, color: Color(0x1A1D2B45)),
  ];
}

abstract final class BowieMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const easing = Cubic(0.2, 0, 0, 1);
}

const double kBowieTouchTargetMin = 44;

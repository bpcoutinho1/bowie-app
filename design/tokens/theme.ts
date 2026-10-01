// Bowie — tema (gerado de tokens.json; edite lá)
// Funciona em React Native/Expo e em web (valores numéricos = px/dp).

export const brand = {
  "night": "#1D2B45",
  "bowieBlue": "#6FA8DC",
  "chestnut": "#9A6440",
  "merle": "#8C97A6",
  "smile": "#EE8E98",
  "mist": "#F4F6F8",
  "white": "#FFFFFF",
  "bowieBlueStrong": "#2F6FA8",
  "chestnutStrong": "#7A4C2E"
} as const;

export const neutral = {
  "900": "#0F1626",
  "800": "#1D2B45",
  "700": "#2E3A52",
  "600": "#4A5670",
  "500": "#5A6782",
  "400": "#8C97A6",
  "300": "#C3CBD6",
  "200": "#DDE2E8",
  "100": "#EDF0F4",
  "50": "#F4F6F8",
  "0": "#FFFFFF"
} as const;

export const colors = {
  light: {
    "background": "#F4F6F8",
    "surface": "#FFFFFF",
    "surfaceMuted": "#EDF0F4",
    "border": "#DDE2E8",
    "text": "#1D2B45",
    "textMuted": "#4A5670",
    "textSubtle": "#5A6782",
    "textOnPrimary": "#FFFFFF",
    "primary": "#1D2B45",
    "primaryPressed": "#2E3A52",
    "accent": "#6FA8DC",
    "textOnAccent": "#1D2B45",
    "link": "#2F6FA8",
    "focusRing": "#6FA8DC",
    "success": "#276B4E",
    "successSoft": "#E8F4EE",
    "warning": "#A15C00",
    "warningSoft": "#FDF1E2",
    "danger": "#B3364A",
    "dangerSoft": "#FBE9EC",
    "info": "#2F6FA8",
    "infoSoft": "#EAF3FB",
    "categoryVaccines": "#2F6FA8",
    "categoryShopping": "#7A4C2E",
    "categoryIncidents": "#B3364A"
  },
  dark: {
    "background": "#0F1626",
    "surface": "#182235",
    "surfaceMuted": "#22304A",
    "border": "#2E3A52",
    "text": "#E8EDF3",
    "textMuted": "#AEB8C6",
    "textSubtle": "#9AA6B8",
    "textOnPrimary": "#0F1626",
    "primary": "#6FA8DC",
    "primaryPressed": "#8CC0EC",
    "accent": "#6FA8DC",
    "textOnAccent": "#0F1626",
    "link": "#8CC0EC",
    "focusRing": "#8CC0EC",
    "success": "#5FBF92",
    "successSoft": "#16352A",
    "warning": "#E3A44A",
    "warningSoft": "#3A2A12",
    "danger": "#F07C8C",
    "dangerSoft": "#3E1C24",
    "info": "#8CC0EC",
    "infoSoft": "#16304A",
    "categoryVaccines": "#8CC0EC",
    "categoryShopping": "#C4895F",
    "categoryIncidents": "#F07C8C"
  },
} as const;

export type ColorScheme = keyof typeof colors;
export type ThemeColors = typeof colors.light;

export const fontFamily = {
  regular: 'Figtree_400Regular',
  medium: 'Figtree_500Medium',
  semibold: 'Figtree_600SemiBold',
  extrabold: 'Figtree_800ExtraBold',
  web: "'Figtree', 'Nunito Sans', system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif",
} as const;

export const typography = {
  display: { fontFamily: fontFamily.extrabold, fontSize: 34, lineHeight: 40, letterSpacing: -0.68 },
  title1: { fontFamily: fontFamily.extrabold, fontSize: 28, lineHeight: 34, letterSpacing: -0.42 },
  title2: { fontFamily: fontFamily.extrabold, fontSize: 22, lineHeight: 28, letterSpacing: -0.22 },
  title3: { fontFamily: fontFamily.semibold, fontSize: 18, lineHeight: 24, letterSpacing: 0 },
  body: { fontFamily: fontFamily.regular, fontSize: 16, lineHeight: 24, letterSpacing: 0 },
  bodyStrong: { fontFamily: fontFamily.semibold, fontSize: 16, lineHeight: 24, letterSpacing: 0 },
  callout: { fontFamily: fontFamily.regular, fontSize: 15, lineHeight: 22, letterSpacing: 0 },
  caption: { fontFamily: fontFamily.regular, fontSize: 13, lineHeight: 18, letterSpacing: 0 },
  overline: { fontFamily: fontFamily.semibold, fontSize: 12, lineHeight: 16, letterSpacing: 0.96, textTransform: 'uppercase' as const },
} as const;

export const spacing = {0: 0, 1: 4, 2: 8, 3: 12, 4: 16, 5: 20, 6: 24, 8: 32, 10: 40, 12: 48, 16: 64} as const;
export const radius = {sm: 8, md: 12, lg: 18, xl: 28, full: 9999} as const;
export const touchTargetMin = 44;
export const motion = { fast: 150, base: 250 } as const;

export const theme = { brand, neutral, colors, fontFamily, typography, spacing, radius, touchTargetMin, motion };
export default theme;

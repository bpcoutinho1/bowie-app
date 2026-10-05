#!/usr/bin/env python3
"""
Gera lib/app/design_tokens.dart a partir de design/tokens/tokens.json.

Uso:
    python3 scripts/generate-dart-tokens.py

Rode sempre que tokens.json mudar e faça commit dos dois arquivos juntos.
"""
import json
import os
import re
import shutil
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "design", "tokens", "tokens.json")
TARGET = os.path.join(ROOT, "lib", "app", "design_tokens.dart")


def color(hex_value):
    value = hex_value.lstrip("#").upper()
    if len(value) != 6:
        raise ValueError(f"unexpected color {hex_value}")
    return f"Color(0xFF{value})"


def camel(name):
    return re.sub(r"[-_](\w)", lambda m: m.group(1).upper(), name)


def shadows(css):
    out = []
    for part in re.split(r",\s*(?![^()]*\))", css):
        m = re.match(
            r"\s*(-?\d+)(?:px)?\s+(-?\d+)(?:px)?\s+(\d+)(?:px)?\s+rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)",
            part,
        )
        if not m:
            raise ValueError(f"unexpected shadow {part}")
        x, y, blur, r, g, b, a = m.groups()
        alpha = round(float(a) * 255)
        out.append(
            f"BoxShadow(offset: Offset({x}, {y}), blurRadius: {blur}, "
            f"color: Color(0x{alpha:02X}{int(r):02X}{int(g):02X}{int(b):02X}))"
        )
    return "[" + ", ".join(out) + "]"


def number(value):
    text = repr(float(value))
    return text[:-2] if text.endswith(".0") else text


def main():
    tokens = json.load(open(SOURCE, encoding="utf-8"))
    light = dict(tokens["semantic"]["light"])
    dark = dict(tokens["semantic"]["dark"])
    for name, entry in tokens["category"].items():
        key = "category" + name[0].upper() + name[1:]
        light[key] = entry["light"]
        dark[key] = entry["dark"]
    names = list(light)
    if set(names) != set(dark):
        raise ValueError("light and dark tokens differ")

    lines = [
        "// Gerado por scripts/generate-dart-tokens.py a partir de",
        "// design/tokens/tokens.json. Não edite à mão.",
        "",
        "import 'package:flutter/material.dart';",
        "",
        "/// Cores da marca. Nos widgets, prefira os tokens semânticos de [BowieColors].",
        "abstract final class BrandColors {",
    ]
    for group in ("brand", "derived"):
        for name, entry in tokens[group].items():
            lines.append(f"  static const {camel(name)} = {color(entry['value'])};")
    lines += ["}", ""]

    lines += [
        "/// Tokens semânticos de cor, com variantes clara e escura.",
        "@immutable",
        "class BowieColors extends ThemeExtension<BowieColors> {",
        "  const BowieColors({",
    ]
    lines += [f"    required this.{n}," for n in names]
    lines += ["  });", ""]
    lines += [f"  final Color {n};" for n in names]
    lines += ["", "  static const light = BowieColors("]
    lines += [f"    {n}: {color(light[n])}," for n in names]
    lines += ["  );", "", "  static const dark = BowieColors("]
    lines += [f"    {n}: {color(dark[n])}," for n in names]
    lines += ["  );", ""]
    lines += ["  @override", "  BowieColors copyWith({"]
    lines += [f"    Color? {n}," for n in names]
    lines += ["  }) {", "    return BowieColors("]
    lines += [f"      {n}: {n} ?? this.{n}," for n in names]
    lines += ["    );", "  }", ""]
    lines += [
        "  @override",
        "  BowieColors lerp(BowieColors? other, double t) {",
        "    if (other == null) return this;",
        "    return BowieColors(",
    ]
    lines += [f"      {n}: Color.lerp({n}, other.{n}, t)!," for n in names]
    lines += ["    );", "  }", "}", ""]

    typography = tokens["typography"]
    family = typography["fontFamily"]["brand"]
    weights = {400: "w400", 500: "w500", 600: "w600", 800: "w800"}
    lines += [
        "/// Escala tipográfica. Use estes estilos; não crie tamanhos novos.",
        "abstract final class BowieType {",
        f"  static const fontFamily = '{family}';",
        "",
    ]
    for name, s in typography["scale"].items():
        size = s["size"]
        lines.append(f"  static const {name} = TextStyle(")
        lines.append("    fontFamily: fontFamily,")
        lines.append(f"    fontSize: {number(size)},")
        lines.append(f"    height: {number(round(s['lineHeight'] / size, 4))},")
        lines.append(f"    fontWeight: FontWeight.{weights[s['weight']]},")
        lines.append(f"    letterSpacing: {number(round(s['letterSpacing'] * size, 4))},")
        lines.append("  );")
    lines += ["}", ""]

    lines += ["/// Espaçamento em grade de 4.", "abstract final class BowieSpacing {"]
    for key, value in tokens["spacing"].items():
        lines.append(f"  static const double s{key} = {number(value)};")
    lines += ["}", ""]

    lines += ["abstract final class BowieRadius {"]
    for key, value in tokens["radius"].items():
        lines.append(f"  static const double {key} = {number(value)};")
    lines += ["}", ""]

    lines += ["abstract final class BowieShadow {"]
    for key, value in tokens["shadow"].items():
        lines.append(f"  static const {key} = {shadows(value)};")
    lines += ["}", ""]

    motion = tokens["motion"]
    easing = re.match(
        r"cubic-bezier\(([\d.]+),\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)\)", motion["easing"]
    ).groups()
    lines += [
        "abstract final class BowieMotion {",
        f"  static const fast = Duration(milliseconds: {motion['fast']});",
        f"  static const base = Duration(milliseconds: {motion['base']});",
        f"  static const easing = Cubic({', '.join(easing)});",
        "}",
        "",
        f"const double kBowieTouchTargetMin = {number(tokens['touchTargetMin'])};",
        "",
    ]

    with open(TARGET, "w", encoding="utf-8") as out:
        out.write("\n".join(lines))
    dart = shutil.which("dart")
    if dart:
        subprocess.run([dart, "format", TARGET], check=True, capture_output=True)
    else:
        print("aviso: dart não encontrado; rode `dart format lib/app/design_tokens.dart`")
    print(f"gravado {os.path.relpath(TARGET, ROOT)}")


if __name__ == "__main__":
    main()

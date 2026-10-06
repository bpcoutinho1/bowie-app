#!/usr/bin/env python3
"""
Gera o lockup vertical com a tagline e as imagens da tela de abertura (splash).

    pip install fonttools cairosvg
    python3 scripts/make-splash.py
    dart run flutter_native_splash:create

Grava:
  design/brand/logo/bowie-lockup-vertical-tagline.svg (e -negative.svg)
  design/brand/app-icon/splash-lockup.png           iOS e Android até 11
  design/brand/app-icon/splash-branding-android12.png  rodapé do Android 12+

A tagline usa a Figtree SemiBold (600) de assets/fonts, convertida em curvas,
para não depender da fonte instalada. O lockup vem de bowie-lockup-vertical.svg.
"""
import os, re

import cairosvg
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

TAGLINE = "Quem ama, lembra."
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGO = os.path.join(ROOT, "design", "brand", "logo")
APP_ICON = os.path.join(ROOT, "design", "brand", "app-icon")
FONTS = os.path.join(ROOT, "assets", "fonts")

# design/tokens/tokens.json: text e textMuted (claro), textMuted (escuro).
NIGHT = "#1D2B45"
MUTED_LIGHT = "#4A5670"
MUTED_DARK = "#AEB8C6"


def text_path(font, text, size, tracking_em=0.0):
    """(d, xmin, xmax, ymin, ymax) do texto em curvas, baseline em y=0."""
    gs, cmap, upm = font.getGlyphSet(), font.getBestCmap(), font["head"].unitsPerEm
    hmtx = font["hmtx"]
    s = size / upm
    pen, bounds = SVGPathPen(gs), BoundsPen(gs)
    x = 0.0
    for i, ch in enumerate(text):
        name = cmap[ord(ch)]
        t = (s, 0, 0, -s, x, 0)
        gs[name].draw(TransformPen(pen, t))
        gs[name].draw(TransformPen(bounds, t))
        x += hmtx[name][0] * s
        if i < len(text) - 1:
            x += tracking_em * size
    xmin, ymin, xmax, ymax = bounds.bounds
    return pen.getCommands(), xmin, xmax, ymin, ymax


def svg_inner(path):
    svg = open(path).read()
    vb = [float(v) for v in re.search(r'viewBox="([^"]+)"', svg).group(1).split()]
    inner = svg[svg.index(">", svg.index("<svg")) + 1: svg.rindex("</svg>")]
    return inner, vb


def svg(w, h, body, label="Bowie. Quem ama, lembra."):
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.1f} {h:.1f}" '
            f'width="{w:.0f}" height="{h:.0f}" role="img" aria-label="{label}">{body}</svg>\n')


def stacked(top_file, tagline_color, size, gap):
    """Uma imagem em cima e a tagline centralizada embaixo: (largura, altura, corpo)."""
    font = TTFont(os.path.join(FONTS, "Figtree-SemiBold.ttf"))
    inner, vb = svg_inner(top_file)
    d, x0, x1, y0, y1 = text_path(font, TAGLINE, size)
    W = max(vb[2], x1 - x0)
    body = (f'<g transform="translate({(W - vb[2]) / 2 - vb[0]:.2f} {-vb[1]:.2f})">{inner}</g>'
            f'<path transform="translate({(W - (x1 - x0)) / 2 - x0:.2f} {vb[3] + gap - y0:.2f})" '
            f'fill="{tagline_color}" d="{d}"/>')
    return W, vb[3] + gap + (y1 - y0), body


def png(svg_text, out, width, height, content_width):
    """Centraliza o SVG num PNG transparente de width x height."""
    vb = [float(v) for v in re.search(r'viewBox="([^"]+)"', svg_text).group(1).split()]
    scale = content_width / vb[2]
    w, h = vb[2] * scale, vb[3] * scale
    inner = svg_text[svg_text.index(">", svg_text.index("<svg")) + 1: svg_text.rindex("</svg>")]
    canvas = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
              f'viewBox="0 0 {width} {height}">'
              f'<g transform="translate({(width - w) / 2:.2f} {(height - h) / 2:.2f}) scale({scale:.5f})">'
              f'{inner}</g></svg>')
    cairosvg.svg2png(bytestring=canvas.encode(), write_to=out,
                     output_width=width, output_height=height)
    print("gravado", os.path.relpath(out, ROOT))


def main():
    # Lockup vertical com a tagline: a tagline ocupa ~85% da largura de "bowie".
    for src, color, out in (
        ("bowie-lockup-vertical.svg", MUTED_LIGHT, "bowie-lockup-vertical-tagline.svg"),
        ("bowie-lockup-vertical-negative.svg", MUTED_DARK, "bowie-lockup-vertical-tagline-negative.svg"),
    ):
        W, H, body = stacked(os.path.join(LOGO, src), color, size=27, gap=22)
        open(os.path.join(LOGO, out), "w").write(svg(W, H, body))
        print("gravado", os.path.relpath(os.path.join(LOGO, out), ROOT))

    # Splash (iOS e Android até 11): o plugin trata a imagem como 4x, então
    # 1024 px viram 256 pt; o lockup ocupa 200 pt de largura.
    lockup = open(os.path.join(LOGO, "bowie-lockup-vertical-tagline.svg")).read()
    png(lockup, os.path.join(APP_ICON, "splash-lockup.png"), 1024, 1400, 800)

    # Android 12+ só mostra o ícone no centro; "bowie" e a tagline vão no
    # rodapé (branding), que tem até 200 x 80 dp (800 x 320 px em 4x).
    W, H, body = stacked(os.path.join(LOGO, "bowie-wordmark.svg"), MUTED_LIGHT, size=38, gap=22)
    png(svg(W, H, body), os.path.join(APP_ICON, "splash-branding-android12.png"), 800, 320, 520)


if __name__ == "__main__":
    main()

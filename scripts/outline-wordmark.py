#!/usr/bin/env python3
"""
Converte a palavra "bowie" (Figtree ExtraBold 800) em curvas e regenera os
lockups do logo com medidas exatas, sem depender da fonte instalada.

Uso:
    pip install fonttools
    # baixe Figtree (OFL) — https://fonts.google.com/specimen/Figtree
    #   ex.: curl -L -o Figtree.ttf "https://github.com/google/fonts/raw/main/ofl/figtree/Figtree%5Bwght%5D.ttf"
    python3 scripts/outline-wordmark.py Figtree.ttf

Aceita a fonte variável (aplica wght=800) ou o arquivo estático Figtree-ExtraBold.ttf.
Sobrescreve design/brand/logo/bowie-lockup-*.svg (inclusive os negativos) e grava bowie-wordmark*.svg.
"""
import os, re, sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen

WORD = "bowie"
TRACKING_EM = -0.035          # mesmo tracking do canvas
NIGHT, WHITE = "#1D2B45", "#FFFFFF"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGO = os.path.join(ROOT, "design", "brand", "logo")


def load_font(path):
    font = TTFont(path)
    if "fvar" in font:
        from fontTools.varLib.instancer import instantiateVariableFont
        font = instantiateVariableFont(font, {"wght": 800})
    return font


def word_path(font, size):
    """Retorna (d, largura, topo, base) da palavra em unidades de saída, baseline em y=0."""
    gs, cmap, upm = font.getGlyphSet(), font.getBestCmap(), font["head"].unitsPerEm
    hmtx = font["hmtx"]
    s = size / upm
    pen = SVGPathPen(gs)
    bounds = BoundsPen(gs)
    x = 0.0
    for i, ch in enumerate(WORD):
        name = cmap[ord(ch)]
        t = (s, 0, 0, -s, x, 0)               # y para baixo, como no SVG
        gs[name].draw(TransformPen(pen, t))
        gs[name].draw(TransformPen(bounds, t))
        x += hmtx[name][0] * s
        if i < len(WORD) - 1:
            x += TRACKING_EM * size
    xmin, ymin, xmax, ymax = bounds.bounds
    return pen.getCommands(), xmin, xmax, ymin, ymax


def symbol_inner(fname):
    svg = open(os.path.join(LOGO, fname)).read()
    vb = [float(v) for v in re.search(r'viewBox="([^"]+)"', svg).group(1).split()]
    inner = svg[svg.index(">", svg.index("<svg")) + 1: svg.rindex("</svg>")]
    return inner, vb


def write(name, w, h, body):
    out = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.1f} {h:.1f}" '
           f'width="{w:.0f}" height="{h:.0f}" role="img" aria-label="Bowie">{body}</svg>\n')
    open(os.path.join(LOGO, name), "w").write(out)
    print("gravado", name)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    font = load_font(sys.argv[1])

    # wordmark sozinho
    d, x0, x1, y0, y1 = word_path(font, 100)
    for name, col in (("bowie-wordmark.svg", NIGHT), ("bowie-wordmark-negative.svg", WHITE)):
        write(name, x1 - x0, y1 - y0, f'<path transform="translate({-x0:.2f} {-y0:.2f})" fill="{col}" d="{d}"/>')

    # lockup horizontal: símbolo com 210 de altura; x-height da palavra ≈ metade do símbolo
    for fname, col, out in (("bowie-symbol.svg", NIGHT, "bowie-lockup-horizontal.svg"),
                            ("bowie-symbol-negative.svg", WHITE, "bowie-lockup-horizontal-negative.svg")):
        inner, vb = symbol_inner(fname)
        sym_w, sym_h = vb[2], vb[3]
        size = 118
        d, x0, x1, y0, y1 = word_path(font, size)
        gap = 24
        word_h = y1 - y0
        ty = (sym_h - word_h) / 2 - y0 + 6     # centraliza opticamente com o rosto
        body = (f'<g transform="translate({-vb[0]} {-vb[1]})">{inner}</g>'
                f'<path transform="translate({sym_w + gap - x0:.2f} {ty:.2f})" fill="{col}" d="{d}"/>')
        write(out, sym_w + gap + (x1 - x0), sym_h, body)

    # lockup vertical
    for fname, col, out in (("bowie-symbol.svg", NIGHT, "bowie-lockup-vertical.svg"),
                            ("bowie-symbol-negative.svg", WHITE, "bowie-lockup-vertical-negative.svg")):
        inner, vb = symbol_inner(fname)
        size = 84
        d, x0, x1, y0, y1 = word_path(font, size)
        W = max(vb[2], x1 - x0)
        gap = 18
        body = (f'<g transform="translate({(W - vb[2]) / 2 - vb[0]:.2f} {-vb[1]})">{inner}</g>'
                f'<path transform="translate({(W - (x1 - x0)) / 2 - x0:.2f} {vb[3] + gap - y0:.2f})" fill="{col}" d="{d}"/>')
        write(out, W, vb[3] + gap + (y1 - y0), body)


if __name__ == "__main__":
    main()

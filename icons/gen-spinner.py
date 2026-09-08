#!/usr/bin/env python3
"""Turn a glyph into an SVG icon the way the claude-spinner-* frames were made:
the character set at 1000px in a 1200x1200 box, converted to a path so the
result needs no font at render time.

    ./gen-spinner.py codex-spinner '#a6adc8' ⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏   -> codex-spinner-0..9.svg
    ./gen-spinner.py codex '#a6adc8' ⬡                     -> codex.svg

Needs fontTools (python3Packages.fonttools) and fontconfig's fc-match.
"""
import subprocess, sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

name, color, glyphs = sys.argv[1], sys.argv[2], sys.argv[3]
BOX, SIZE = 1200, 1000

for i, ch in enumerate(glyphs):
    fontfile = subprocess.check_output(
        ["fc-match", "-f", "%{file}", f":charset={ord(ch):x}"], text=True)
    font = TTFont(fontfile)
    gname = font.getBestCmap()[ord(ch)]
    glyph = font.getGlyphSet()[gname]
    upm = font["head"].unitsPerEm
    scale = SIZE / upm
    # Centre horizontally on the advance, and vertically on the middle of the
    # ascender/descender span, which is what dominant-baseline:central did.
    asc, desc = font["hhea"].ascent, font["hhea"].descent
    x = BOX / 2 - glyph.width * scale / 2
    y = BOX / 2 + (asc + desc) / 2 * scale
    pen = SVGPathPen(font.getGlyphSet())
    glyph.draw(TransformPen(pen, (scale, 0, 0, -scale, x, y)))
    out = f"{name}-{i}.svg" if len(glyphs) > 1 else f"{name}.svg"
    with open(out, "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{BOX}" height="{BOX}" '
                f'viewBox="0 0 {BOX} {BOX}"><path fill="{color}" d="{pen.getCommands()}"/></svg>\n')
    print(out, ch, fontfile.rsplit("/", 1)[-1])

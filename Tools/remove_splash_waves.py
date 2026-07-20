#!/usr/bin/env python3
"""One-off asset tool: remove the three baked-in sound-wave arcs from the
splash screen PNG so SwiftUI can draw and animate them natively.

Reads Marketing/'TableScore splash screen v1.png', writes the waveless image
into the SplashImage asset set, and prints the fitted arc geometry (center,
radius, angles, stroke width, color) in display points (@3x) for SplashView.

Pure stdlib: decodes/encodes PNG by hand, removes arcs by horizontal linear
interpolation across each masked run (arcs are thin in x, background is a
smooth gradient, so this is seamless).
"""
import json
import math
import os
import struct
import sys
import zlib

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "Marketing", "TableScore splash screen v1.png")
DST = os.path.join(ROOT, "TableScore", "Resources", "Assets.xcassets", "SplashImage.imageset", "splash.png")

# Search window covering the whole logo, in source pixels. The arcs are the
# three largest amber connected components AFTER the meeple+note blob.
REGION_X = (200, 760)
REGION_Y = (200, 1000)


def decode_png(path):
    with open(path, "rb") as f:
        data = f.read()
    pos = 8
    width = height = None
    colortype = None
    idat = b""
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            width, height, bitdepth, colortype = struct.unpack(">IIBB", chunk[:10])
            assert bitdepth == 8, "expected 8-bit PNG"
            assert colortype in (2, 6), f"unsupported color type {colortype}"
        elif typ == b"IDAT":
            idat += chunk
        pos += 12 + ln
    raw = zlib.decompress(idat)
    channels = 3 if colortype == 2 else 4
    stride = width * channels
    rows = []
    prev = bytearray(stride)
    p = 0
    for _ in range(height):
        filt = raw[p]; p += 1
        line = bytearray(raw[p:p + stride]); p += stride
        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            if filt == 1:
                line[i] = (line[i] + a) & 0xFF
            elif filt == 2:
                line[i] = (line[i] + b) & 0xFF
            elif filt == 3:
                line[i] = (line[i] + (a + b) // 2) & 0xFF
            elif filt == 4:
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        rows.append(line)
        prev = line
    return width, height, channels, rows


def encode_png(path, width, height, channels, rows):
    def chunk(typ, payload):
        return (struct.pack(">I", len(payload)) + typ + payload
                + struct.pack(">I", zlib.crc32(typ + payload) & 0xFFFFFFFF))

    colortype = 2 if channels == 3 else 6
    ihdr = struct.pack(">IIBBBBB", width, height, 8, colortype, 0, 0, 0)
    raw = b"".join(b"\x00" + bytes(row) for row in rows)
    out = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(out)


def is_amber(row, x, channels):
    r, g, b = row[x * channels], row[x * channels + 1], row[x * channels + 2]
    return r > 90 and r > g > b and (r - b) > 50


def main():
    width, height, channels, rows = decode_png(SRC)
    x0, x1 = REGION_X
    y0, y1 = REGION_Y

    # All amber pixels in the window (meeple, note, and arcs).
    all_amber = set()
    for y in range(y0, y1):
        for x in range(x0, x1):
            if is_amber(rows[y], x, channels):
                all_amber.add((x, y))

    # Connected components (8-neighbour): largest = meeple+note blob,
    # the next three are the wave arcs.
    comps = []
    unvisited = set(all_amber)
    while unvisited:
        seed = unvisited.pop()
        comp = [seed]
        frontier = [seed]
        while frontier:
            cx, cy = frontier.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (cx + dx, cy + dy)
                    if n in unvisited:
                        unvisited.discard(n)
                        comp.append(n)
                        frontier.append(n)
        comps.append(comp)
    comps = sorted(comps, key=len, reverse=True)
    assert len(comps) >= 4, f"expected logo + 3 arcs, found {len(comps)} components"
    comps = comps[1:4]  # drop the meeple+note blob, keep the three arcs
    assert all(len(c) > 300 for c in comps), "arc components suspiciously small"
    mask = {p for comp in comps for p in comp}

    # Kåsa circle fit per arc: x^2 + y^2 + Dx + Ey + F = 0.
    def fit_circle(points):
        n = len(points)
        sx = sum(p[0] for p in points); sy = sum(p[1] for p in points)
        sxx = sum(p[0] * p[0] for p in points); syy = sum(p[1] * p[1] for p in points)
        sxy = sum(p[0] * p[1] for p in points)
        sxz = sum(p[0] * (p[0] ** 2 + p[1] ** 2) for p in points)
        syz = sum(p[1] * (p[0] ** 2 + p[1] ** 2) for p in points)
        sz = sum(p[0] ** 2 + p[1] ** 2 for p in points)
        # Solve [sxx sxy sx; sxy syy sy; sx sy n] [D E F]^T = -[sxz syz sz]
        A = [[sxx, sxy, sx], [sxy, syy, sy], [sx, sy, n]]
        v = [-sxz, -syz, -sz]
        for i in range(3):  # Gaussian elimination
            piv = max(range(i, 3), key=lambda r: abs(A[r][i]))
            A[i], A[piv] = A[piv], A[i]
            v[i], v[piv] = v[piv], v[i]
            for r in range(i + 1, 3):
                f = A[r][i] / A[i][i]
                for c in range(i, 3):
                    A[r][c] -= f * A[i][c]
                v[r] -= f * v[i]
        D = [0.0, 0.0, 0.0]
        for i in (2, 1, 0):
            D[i] = (v[i] - sum(A[i][c] * D[c] for c in range(i + 1, 3))) / A[i][i]
        cx, cy = -D[0] / 2, -D[1] / 2
        radius = math.sqrt(max(cx * cx + cy * cy - D[2], 0))
        return cx, cy, radius

    arcs = []
    for comp in comps:
        cx, cy, radius = fit_circle(comp)
        angles = sorted(math.degrees(math.atan2(y - cy, x - cx)) for x, y in comp)
        # Median stroke thickness: radial spread of samples.
        spreads = [math.hypot(x - cx, y - cy) - radius for x, y in comp]
        thickness = 2 * (sorted(abs(s) for s in spreads)[int(len(spreads) * 0.9)])
        reds = sorted(rows[y][x * channels] for x, y in comp)
        greens = sorted(rows[y][x * channels + 1] for x, y in comp)
        blues = sorted(rows[y][x * channels + 2] for x, y in comp)
        mid = len(comp) // 2
        arcs.append({
            "center": [round(cx / 3, 2), round(cy / 3, 2)],   # display points @3x
            "radius": round(radius / 3, 2),
            "startAngleDeg": round(angles[int(len(angles) * 0.02)], 1),
            "endAngleDeg": round(angles[int(len(angles) * 0.98)], 1),
            "lineWidthPt": round(thickness / 3, 2),
            "color": [reds[mid], greens[mid], blues[mid]],
            "pixels": len(comp),
        })
    arcs.sort(key=lambda a: a["radius"])

    # Inpaint: dilate the mask slightly, then bridge every horizontal run
    # with linear interpolation between its unmasked neighbours.
    dilated = set()
    for (x, y) in mask:
        for dx in (-3, -2, -1, 0, 1, 2, 3):
            for dy in (-3, -2, -1, 0, 1, 2, 3):
                dilated.add((x + dx, y + dy))
    by_row = {}
    for (x, y) in dilated:
        if 0 <= y < height and 0 <= x < width:
            by_row.setdefault(y, set()).add(x)
    for y, xs in by_row.items():
        xs = sorted(xs)
        run = [xs[0]]
        runs = []
        for x in xs[1:]:
            if x == run[-1] + 1:
                run.append(x)
            else:
                runs.append(run)
                run = [x]
        runs.append(run)
        for run in runs:
            left, right = run[0] - 1, run[-1] + 1
            if left < 0 or right >= width:
                continue
            for c in range(channels):
                lv = rows[y][left * channels + c]
                rv = rows[y][right * channels + c]
                for x in run:
                    t = (x - left) / (right - left)
                    rows[y][x * channels + c] = round(lv + (rv - lv) * t)

    encode_png(DST, width, height, channels, rows)
    print(json.dumps({"imagePointSize": [width / 3, height / 3], "arcs": arcs}, indent=2))


if __name__ == "__main__":
    main()

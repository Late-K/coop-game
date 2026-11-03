"""Generates the placeholder pixel textures into textures/ (standard library only).

Original textures in a late-90s / Signalis-like industrial style, at 16 pixels per metre
(they are laid out in world space by the PS1 shader, see Retro). Replace any PNG with a
hand-made one of the same name and the game uses it.
Run from the project root:  python tools/generate_textures.py
"""
import os
import random
import struct
import zlib

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "textures")


def write_png(name, width, height, pixel):
    """pixel(x, y) -> (r, g, b) in 0..255."""
    rows = b""
    for y in range(height):
        rows += b"\x00" + bytes(c for x in range(width) for c in pixel(x, y))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b"")
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name + ".png"), "wb") as f:
        f.write(png)
    print(f"  {name}.png  {width}x{height}")


def clamp(v):
    return max(0, min(255, int(v)))


def shade(rgb, k):
    return tuple(clamp(c * k) for c in rgb)


def floor_tiles():
    """2 x 2 m of square tiles: per-tile tone variation, dark grout, small dark diamonds where
    four tiles meet, and some grime."""
    size, tile = 32, 16
    rng = random.Random(1)
    base = (150, 158, 160)
    tone = {(tx, ty): rng.uniform(0.86, 1.04) for tx in range(2) for ty in range(2)}
    grime = [[rng.random() for _ in range(size)] for _ in range(size)]

    def pixel(x, y):
        lx, ly = x % tile, y % tile
        if lx == 0 or ly == 0:
            return (58, 62, 66)  # grout
        cx, cy = min(lx, tile - lx), min(ly, tile - ly)
        if cx + cy <= 2:
            return (70, 74, 78)  # diamond inset at the corner
        k = tone[(x // tile, y // tile)] * (0.92 if grime[y][x] < 0.18 else 1.0)
        if lx == 1 or ly == 1:
            k *= 1.06  # worn bevel catching light
        return shade(base, k)

    write_png("floor_tiles", size, size, pixel)


def wall_panel():
    """2 m wide x 2.5 m tall of painted wall: muted blue-teal upper paint, a darker lower
    band with a light trim line, vertical panel seams, and drips of grime."""
    width, height = 32, 40
    rng = random.Random(2)
    upper, lower, trim = (78, 102, 114), (44, 52, 58), (120, 128, 128)
    drips = {rng.randrange(width): rng.randint(8, 30) for _ in range(5)}

    def pixel(x, y):
        if y in (25, 26):
            return trim
        rgb = upper if y < 25 else lower
        k = 1.0
        if x % 16 == 0:
            k *= 0.7  # seam
        if y < 2:
            k *= 0.6  # shadow under the ceiling line
        if x in drips and y < drips[x]:
            k *= 0.85
        return shade(rgb, k * rng.uniform(0.96, 1.03))

    write_png("wall_panel", width, height, pixel)


def hazard():
    """Diagonal yellow and black stripes for door thresholds."""
    size = 16

    def pixel(x, y):
        return (196, 156, 40) if ((x + y) // 4) % 2 == 0 else (28, 26, 24)

    write_png("hazard", size, size, pixel)


def door_panel():
    """One face of a 3 m wide x 2.5 m tall bulkhead door: oxide-red panel in a dark frame,
    a recessed centre seam, vent slats in the lower half, a grey label plate, a small status
    lamp, and hazard stripes along the bottom edge."""
    width, height = 48, 40
    rng = random.Random(4)
    paint, frame, recess = (98, 40, 34), (38, 22, 20), (70, 30, 26)

    def pixel(x, y):
        if x < 2 or x >= width - 2 or y < 2:
            return frame
        if y >= height - 4:
            return (196, 156, 40) if ((x + y) // 3) % 2 == 0 else (28, 26, 24)  # hazard band
        if x in (23, 24):
            return (24, 14, 12)  # centre seam where the halves meet
        if 6 <= x <= 14 and 6 <= y <= 11:
            if y in (8, 10) and 7 <= x <= 13 and x % 3 != 0:
                return (60, 60, 58)  # "text" lines on the plate
            return (150, 150, 144)  # label plate
        if 38 <= x <= 40 and 6 <= y <= 7:
            return (90, 200, 90)  # status lamp
        if 22 <= y < height - 6 and (6 <= x < 20 or 28 <= x < 42):
            return recess if x % 2 == 0 else shade(paint, 0.75)  # vent slats
        return shade(paint, rng.uniform(0.9, 1.05))

    write_png("door_panel", width, height, pixel)


# --- Level kit surfaces (see tools/build_kit.gd). Floors are 2 x 2 m, walls 2 m x 2.5 m. ---

def floor_grate():
    """Metal floor grating: dark slots between bright bars, a heavier frame every metre."""
    size = 32
    rng = random.Random(5)
    bar, gap, frame = (104, 108, 106), (18, 20, 20), (72, 76, 74)

    def pixel(x, y):
        if x % 16 in (0, 15) or y % 16 in (0, 15):
            return shade(frame, rng.uniform(0.9, 1.05))
        if y % 3 == 0:
            return gap
        return shade(bar, (0.85 if x % 4 == 0 else 1.0) * rng.uniform(0.92, 1.05))

    write_png("floor_grate", size, size, pixel)


def floor_concrete():
    """Poured concrete: speckled grey, a saw-cut joint every 2 m, a few dark stains and cracks."""
    size = 32
    rng = random.Random(6)
    base = (118, 116, 110)
    stains = [(rng.randrange(size), rng.randrange(size), rng.randint(3, 6)) for _ in range(3)]
    crack = {(x, 9 + (x // 5) % 3) for x in range(6, 20)}

    def pixel(x, y):
        if x == 0 or y == 0:
            return (70, 68, 64)  # joint
        if (x, y) in crack:
            return (64, 62, 58)
        k = rng.uniform(0.9, 1.06)
        for sx, sy, r in stains:
            if (x - sx) ** 2 + (y - sy) ** 2 < r * r:
                k *= 0.82
        return shade(base, k)

    write_png("floor_concrete", size, size, pixel)


def wall_concrete():
    """Cast concrete: formwork seams every metre, rows of tie holes, damp darkening at the foot."""
    width, height = 32, 40
    rng = random.Random(7)
    base = (104, 104, 100)

    def pixel(x, y):
        if y in (0, 16, 32):
            return (66, 66, 62)  # formwork seam
        if x % 8 == 4 and y % 16 == 8:
            return (40, 40, 38)  # tie hole
        k = rng.uniform(0.92, 1.05) * (1.0 - max(0, y - 30) * 0.04)  # damp foot
        return shade(base, k)

    write_png("wall_concrete", width, height, pixel)


def wall_lab():
    """Lab tiles: small off-white squares (0.5 m) above a dark skirting band, grout lines."""
    width, height = 32, 40
    rng = random.Random(8)
    tile, skirting = (176, 184, 180), (40, 46, 48)
    tone = {(tx, ty): rng.uniform(0.9, 1.04) for tx in range(4) for ty in range(5)}

    def pixel(x, y):
        if y >= 36:
            return shade(skirting, rng.uniform(0.9, 1.1))
        if y == 35:
            return (90, 96, 96)
        if x % 8 == 0 or y % 8 == 0:
            return (98, 104, 102)  # grout
        k = tone[(x // 8, y // 8)] * (0.94 if y < 3 else 1.0)
        return shade(tile, k * rng.uniform(0.97, 1.02))

    write_png("wall_lab", width, height, pixel)


def snow():
    """Packed snow: pale blue-white with soft drifts and a few footprint-dark specks."""
    size = 32
    rng = random.Random(9)

    def pixel(x, y):
        drift = 0.04 * ((x * 3 + y * 5) % 11) / 11
        k = 0.95 + drift + rng.uniform(-0.03, 0.03)
        if rng.random() < 0.01:
            k *= 0.85
        return shade((200, 210, 224), k)

    write_png("snow", size, size, pixel)


# Item icons for the terminal inventory: 32 x 20 pixel art, drawn as text. Characters map to
# colours below ('.' is transparent background, rendered as the terminal's black).
ICON_COLORS = {
    ".": (0, 0, 0), "#": (210, 232, 224), "+": (120, 150, 140), "o": (60, 80, 74),
    "r": (200, 60, 50), "y": (220, 180, 70), "h": (240, 130, 40),
}
ICONS = {
    "pistol": [
        "................................",
        "................................",
        "................................",
        "....##########################..",
        "....#++++++++++++++++++++++++#..",
        "....#+oooooooooooooooooooooo+#..",
        "....#++++++++++++++++++++++++#..",
        "....############+++++#########..",
        "....#++++++++++#+...+#..........",
        "....#+++++++++#+..+#............",
        "....#++++++++#++##..............",
        "....#+++++++#...................",
        "....#++++++#....................",
        "...#++++++#.....................",
        "...#++++++#.....................",
        "...#+++++#......................",
        "...#######......................",
        "................................",
        "................................",
        "................................",
    ],
    "ammo": [
        "................................",
        "................................",
        "....yy..yy..yy..yy..yy..yy......",
        "...y##yy##yy##yy##yy##yy##y.....",
        "...y##yy##yy##yy##yy##yy##y.....",
        "...y++yy++yy++yy++yy++yy++y.....",
        "...yyyyyyyyyyyyyyyyyyyyyyyy.....",
        "...yyyyyyyyyyyyyyyyyyyyyyyy.....",
        "...yyyyyyyyyyyyyyyyyyyyyyyy.....",
        "...yyyyyyyyyyyyyyyyyyyyyyyy.....",
        "...yyyyyyyyyyyyyyyyyyyyyyyy.....",
        "...+yy++yy++yy++yy++yy++yy+.....",
        "...++++++++++++++++++++++++.....",
        "................................",
        "...######################.......",
        "...#++++++++++++++++++++#.......",
        "...#+9MM++++++++++++++++#.......",
        "...######################.......",
        "................................",
        "................................",
    ],
    "medkit": [
        "................................",
        "................................",
        "...........########.............",
        "...........#......#.............",
        "......##################........",
        "......#++++++++++++++++#........",
        "......#+++++++rr+++++++#........",
        "......#+++++++rr+++++++#........",
        "......#++++rrrrrrrr++++#........",
        "......#++++rrrrrrrr++++#........",
        "......#+++++++rr+++++++#........",
        "......#+++++++rr+++++++#........",
        "......#++++++++++++++++#........",
        "......#oooooooooooooooo#........",
        "......##################........",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
    ],
    "service_key": [
        "................................",
        "................................",
        "....######......................",
        "...#++++++#.....................",
        "..#+######+#....................",
        "..#+#....#+#....................",
        "..#+#....#+###################..",
        "..#+#....#+yyyyyyyyyyyyyyyyyyy#.",
        "..#+#....#+###################..",
        "..#+######+#.......#.#..##.#....",
        "...#++++++#........#.#..##.#....",
        "....######.........#....##......",
        "................................",
        "....oooooo......................",
        "....o#####o.....................",
        "....o#+++++o....................",
        "....oooooooo....................",
        "................................",
        "................................",
        "................................",
    ],
    "heat_cell": [
        "................................",
        "............######..............",
        "...........#++++++#.............",
        "..........##########............",
        "..........#hhhhhhhh#............",
        "..........#h######h#............",
        "..........#h#hhhh#h#............",
        "..........#h#hyyh#h#............",
        "..........#h#hyyh#h#............",
        "..........#h#hyyh#h#............",
        "..........#h#hhhh#h#............",
        "..........#h######h#............",
        "..........#hhhhhhhh#............",
        "..........##########............",
        "...........#++++++#.............",
        "............######..............",
        "................................",
        "................................",
        "................................",
        "................................",
    ],
}


def icons():
    os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)
    for name, rows in ICONS.items():
        write_png(os.path.join("icons", name), len(rows[0]), len(rows),
                  lambda x, y, rows=rows: ICON_COLORS.get(rows[y][x], ICON_COLORS["#"]))


if __name__ == "__main__":
    print(f"Writing textures to {OUT}")
    floor_tiles()
    wall_panel()
    hazard()
    door_panel()
    floor_grate()
    floor_concrete()
    wall_concrete()
    wall_lab()
    snow()
    icons()

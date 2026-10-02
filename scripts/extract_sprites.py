#!/usr/bin/env python3
"""
Build Pet.spriteatlas from the labeled fox sprite sheet.

Prefers assets/fox-sprite-sheet.png (clean black background).

Sheet layout (Free Top-Down Hunt Animals pack):
  IDLE  4×4   WALK 6×4   HURT 4×4
  RUN   6×4   DEATH 6×4
Each block has rows: Front, Back, Left, Right.

Outputs separate left/right series (no runtime mirroring):
  walk_l_*, walk_r_*, run_l_*, run_r_*, idle_l_*, idle_r_*, react_l_*, react_r_*
  climb_* / hang_* (rotated side walk)

Idle / walk / run frames come from assets/fox/f-*-*.png (left-facing);
right is mirrored. Climb/hang are rotated from walk.
"""

from __future__ import annotations

import json
import shutil
from collections import Counter, deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
# Prefer the clean black-background sheet; fall back to the old JPEG.
SRC = ROOT / "assets" / "fox-sprite-sheet.png"
if not SRC.exists():
    SRC = ROOT / "assets" / "fox-sprite-sheet.jpg"
FOX_DIR = ROOT / "assets" / "fox"
ATLAS = ROOT / "DesktopPet" / "Resources" / "Assets.xcassets" / "Pet.spriteatlas"
META = ROOT / "scripts" / "sprite_meta.json"

CANVAS = 64
CELL_W = 54
CELL_H = 54

SECTIONS = {
    "idle": {"ox": 43, "oy": 148, "cols": 4, "rows": 4},
    "walk": {"ox": 349, "oy": 148, "cols": 6, "rows": 4},
    "hurt": {"ox": 765, "oy": 148, "cols": 4, "rows": 4},
    "run": {"ox": 96, "oy": 428, "cols": 6, "rows": 4},
    "death": {"ox": 597, "oy": 428, "cols": 6, "rows": 4},
}

ROW_FRONT = 0
ROW_BACK = 1
ROW_LEFT = 2
ROW_RIGHT = 3

# Near-black sheet background (clean export). Keep slightly-darker paw/eye pixels.
BG_MAX = 12


def is_backdrop(c: tuple[int, ...]) -> bool:
    """Solid black (or near-black) sheet background."""
    r, g, b = int(c[0]), int(c[1]), int(c[2])
    return max(r, g, b) <= BG_MAX


def is_fur_color(r: int, g: int, b: int) -> bool:
    return r >= 100 and r >= g - 5 and r > b + 10


def is_paw_color(r: int, g: int, b: int) -> bool:
    mx = max(r, g, b)
    return BG_MAX < mx <= 90


def is_marking_white(r: int, g: int, b: int) -> bool:
    """Muzzle / chest / tail-tip whites — keep bright creams, reject grey/blue halo."""
    mn = min(r, g, b)
    mx = max(r, g, b)
    avg = (r + g + b) / 3
    if mn < 165 or mx - mn > 55:
        return False
    # Near-pure bright white (tail tip / muzzle) — allow slight cool cast.
    if mn >= 200 and avg >= 210:
        return True
    # Strongly cool/grey fringe.
    if b > r + 14 or g > r + 14:
        return False
    return r >= g - 4


def protect_markings(img: Image.Image) -> list[list[bool]]:
    """Bright pixels grown from fur = muzzle/tail tip; never peel these."""
    px = img.load()
    w, h = img.size
    protected = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 20:
                continue
            if is_fur_color(r, g, b) or is_paw_color(r, g, b):
                protected[y][x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if not (0 <= nx < w and 0 <= ny < h) or protected[ny][nx]:
                continue
            r, g, b, a = px[nx, ny]
            if a < 20:
                continue
            if is_marking_white(r, g, b) or min(r, g, b) >= 185:
                protected[ny][nx] = True
                q.append((nx, ny))
    return protected


def chroma_key(img: Image.Image) -> Image.Image:
    """
    Punch out the black sheet background via edge flood-fill.
    Interior near-black (eyes) stays — only bg connected to the cell border is removed.
    """
    out = img.convert("RGBA").copy()
    px = out.load()
    w, h = out.size

    q: deque[tuple[int, int]] = deque()
    seen = [[False] * w for _ in range(h)]
    for x in range(w):
        for y in (0, h - 1):
            if is_backdrop(px[x, y]):
                q.append((x, y))
                seen[y][x] = True
    for y in range(h):
        for x in (0, w - 1):
            if not seen[y][x] and is_backdrop(px[x, y]):
                q.append((x, y))
                seen[y][x] = True

    while q:
        x, y = q.popleft()
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and is_backdrop(px[nx, ny]):
                seen[ny][nx] = True
                q.append((nx, ny))

    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a >= 20:
                px[x, y] = (r, g, b, 255)
    return out


def strip_shadow(img: Image.Image) -> Image.Image:
    """Remove the soft grey oval under the feet."""
    out = img.copy()
    px = out.load()
    w, h = out.size
    y0 = int(h * 0.55)
    for y in range(y0, h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 20:
                continue
            if is_marking_white(r, g, b) or is_fur_color(r, g, b) or is_paw_color(r, g, b):
                continue
            avg = (r + g + b) / 3
            chroma = max(r, g, b) - min(r, g, b)
            if chroma <= 36 and 35 <= avg <= 170:
                px[x, y] = (0, 0, 0, 0)
    return out


def largest_blob(img: Image.Image) -> Image.Image:
    px = img.load()
    w, h = img.size
    seen = [[False] * w for _ in range(h)]
    best: list[tuple[int, int]] = []
    for y in range(h):
        for x in range(w):
            if seen[y][x] or px[x, y][3] < 20:
                continue
            q: deque[tuple[int, int]] = deque([(x, y)])
            seen[y][x] = True
            cells: list[tuple[int, int]] = []
            while q:
                cx, cy = q.popleft()
                cells.append((cx, cy))
                for nx, ny in (
                    (cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1),
                ):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] >= 20:
                        seen[ny][nx] = True
                        q.append((nx, ny))
            if len(cells) > len(best):
                best = cells
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    for x, y in best:
        opx[x, y] = px[x, y]
    return out


def harden_alpha(img: Image.Image) -> Image.Image:
    """Binary alpha — keep all non-transparent body pixels as-is."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < 40:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (r, g, b, 255)
    return out


def scrub_bright_rim(img: Image.Image) -> Image.Image:
    """Peel light cool/grey halo; never eat muzzle/tail-tip whites."""
    out = img.copy()
    protected = protect_markings(out)

    def peel_once(px, w: int, h: int) -> int:
        kill: list[tuple[int, int]] = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a < 20 or is_paw_color(r, g, b) or protected[y][x]:
                    continue
                card_empty = sum(
                    1
                    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
                    if not (0 <= x + dx < w and 0 <= y + dy < h)
                    or px[x + dx, y + dy][3] < 20
                )
                if card_empty < 1:
                    continue
                avg = (r + g + b) / 3
                chroma = max(r, g, b) - min(r, g, b)

                if is_fur_color(r, g, b) and avg < 210:
                    continue
                if is_marking_white(r, g, b) or min(r, g, b) >= 190:
                    continue

                if avg >= 145 and (g >= r + 1 or b >= r + 5):
                    kill.append((x, y))
                elif card_empty >= 2 and avg >= 165:
                    kill.append((x, y))
                elif card_empty >= 2 and chroma <= 35 and avg >= 140:
                    kill.append((x, y))
                elif card_empty >= 3 and avg >= 130:
                    kill.append((x, y))
        for x, y in kill:
            px[x, y] = (0, 0, 0, 0)
        return len(kill)

    px = out.load()
    w, h = out.size
    for _ in range(3):
        if peel_once(px, w, h) == 0:
            break
    return out


def soften_fox_fur(r: int, g: int, b: int, amount: float = 0.5) -> tuple[int, int, int]:
    """Mute saturated red-orange toward tawny; `amount` is blend toward full soften (0–1)."""
    mid = 120.0
    contrast = 0.82
    sat = 0.68
    r2 = mid + (r - mid) * contrast
    g2 = mid + (g - mid) * contrast
    b2 = mid + (b - mid) * contrast
    avg = (r2 + g2 + b2) / 3.0
    r3 = avg + (r2 - avg) * sat
    g3 = avg + (g2 - avg) * sat
    b3 = avg + (b2 - avg) * sat
    fr = r3 * 0.94 + 4
    fg = g3 * 0.88 + r3 * 0.14 + 10
    fb = b3 * 0.92 + g3 * 0.06 + 6
    t = max(0.0, min(1.0, amount))
    nr = r + (fr - r) * t
    ng = g + (fg - g) * t
    nb = b + (fb - b) * t
    return (
        max(0, min(255, int(round(nr)))),
        max(0, min(255, int(round(ng)))),
        max(0, min(255, int(round(nb)))),
    )


def to_brownish(img: Image.Image) -> Image.Image:
    """Tone down fox orange/red saturation and contrast toward real-fox tawny."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < 20:
                continue
            if is_marking_white(r, g, b) or min(r, g, b) >= 175:
                continue
            if max(r, g, b) <= 70:
                continue
            # Warm body + dark red shadows (skip cool greys / black paws).
            if r >= g and r > b + 8 and (r >= 85 or r - b >= 20):
                nr, ng, nb = soften_fox_fur(r, g, b)
                px[x, y] = (nr, ng, nb, a)
    return out


def clean_cell(img: Image.Image) -> Image.Image:
    keyed = harden_alpha(strip_shadow(chroma_key(img)))
    return to_brownish(scrub_bright_rim(largest_blob(keyed)))


def prepare_dedicated_frame(img: Image.Image) -> Image.Image:
    """Clean a dedicated fox PNG (already transparent) and shrink to canvas size."""
    sp = to_brownish(scrub_bright_rim(largest_blob(harden_alpha(strip_shadow(img.convert("RGBA"))))))
    bbox = sp.getbbox()
    if not bbox:
        return Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    sp = sp.crop(bbox)
    max_w, max_h = CANVAS - 2, CANVAS - 2
    if sp.width > max_w or sp.height > max_h:
        fit = min(max_w / sp.width, max_h / sp.height)
        sp = sp.resize(
            (max(1, int(sp.width * fit)), max(1, int(sp.height * fit))),
            Image.Resampling.BOX,
        )
        sp = harden_alpha(sp)
        bbox = sp.getbbox()
        if bbox:
            sp = sp.crop(bbox)
    return sp


def load_dedicated_frames(glob_pat: str) -> list[Image.Image]:
    """Left-facing frames from assets/fox matching glob_pat (e.g. f-walk-*.png)."""
    paths = sorted(FOX_DIR.glob(glob_pat))
    if not paths:
        raise SystemExit(f"Missing frames {FOX_DIR}/{glob_pat}")
    return [prepare_dedicated_frame(Image.open(p)) for p in paths]


def mirror_right(frames: list[Image.Image]) -> list[Image.Image]:
    return [fr.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for fr in frames]


def pad(sprite: Image.Image, anchor: str = "feet", lift: int = 0) -> Image.Image:
    """Pack into CANVAS. `lift` raises feet-anchored sprites by N px (idle bob)."""
    # Avoid re-running chroma on already-extracted sprites (would see transparent
    # holes as empty and is unnecessary). Only clean if still fully opaque sheet cell.
    sample = sprite.getpixel((0, 0)) if sprite.size[0] and sprite.size[1] else (0, 0, 0, 0)
    if sample[3] >= 250 and is_backdrop(sample):
        sp = clean_cell(sprite)
    else:
        sp = sprite.convert("RGBA")
        # Still drop any leftover backdrop crumbs without a full re-key.
        px = sp.load()
        for y in range(sp.height):
            for x in range(sp.width):
                r, g, b, a = px[x, y]
                if a >= 20 and is_backdrop((r, g, b, a)):
                    px[x, y] = (0, 0, 0, 0)
    bbox = sp.getbbox()
    if not bbox:
        return Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    sp = sp.crop(bbox)

    max_w, max_h = CANVAS - 2, CANVAS - 2
    if sp.width > max_w or sp.height > max_h:
        fit = min(max_w / sp.width, max_h / sp.height)
        sp = sp.resize(
            (max(1, int(sp.width * fit)), max(1, int(sp.height * fit))),
            Image.Resampling.NEAREST,
        )
        bbox = sp.getbbox()
        if bbox:
            sp = sp.crop(bbox)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    if anchor == "feet":
        ox = (CANVAS - sp.width) // 2
        oy = max(0, CANVAS - sp.height - max(0, lift))
    elif anchor == "top":
        ox = (CANVAS - sp.width) // 2
        oy = 0
    elif anchor == "left":
        ox = 0
        oy = (CANVAS - sp.height) // 2
    elif anchor == "right":
        ox = CANVAS - sp.width
        oy = (CANVAS - sp.height) // 2
    else:
        ox = (CANVAS - sp.width) // 2
        oy = (CANVAS - sp.height) // 2
    canvas.paste(sp, (ox, oy), sp)

    px = canvas.load()
    for y in range(CANVAS):
        for x in range(CANVAS):
            c = px[x, y]
            if c[3] > 0 and is_backdrop(c):
                px[x, y] = (0, 0, 0, 0)
            elif 0 < c[3] < 255:
                px[x, y] = (c[0], c[1], c[2], 255)

    # Re-seat horizontally only when feet-anchored with lift, so bob survives.
    bb = canvas.getbbox()
    if bb and lift == 0:
        cropped = canvas.crop(bb)
        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        if anchor == "feet":
            ox = (CANVAS - cropped.width) // 2
            oy = CANVAS - cropped.height
        elif anchor == "top":
            ox = (CANVAS - cropped.width) // 2
            oy = 0
        elif anchor == "left":
            ox = 0
            oy = (CANVAS - cropped.height) // 2
        elif anchor == "right":
            ox = CANVAS - cropped.width
            oy = (CANVAS - cropped.height) // 2
        else:
            ox = (CANVAS - cropped.width) // 2
            oy = (CANVAS - cropped.height) // 2
        canvas.paste(cropped, (ox, oy), cropped)
    elif bb and lift > 0 and anchor == "feet":
        cropped = canvas.crop(bb)
        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        ox = (CANVAS - cropped.width) // 2
        oy = max(0, CANVAS - cropped.height - lift)
        canvas.paste(cropped, (ox, oy), cropped)
    return canvas


def save(img: Image.Image, name: str) -> None:
    imageset = ATLAS / f"{name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    img.save(imageset / f"{name}.png")
    (imageset / "Contents.json").write_text(
        json.dumps(
            {
                "images": [
                    {"filename": f"{name}.png", "idiom": "universal", "scale": "1x"}
                ],
                "info": {"author": "xcode", "version": 1},
            },
            indent=2,
        )
    )


def extract_cell(sheet: Image.Image, section: str, col: int, row: int) -> Image.Image:
    s = SECTIONS[section]
    x0 = s["ox"] + col * CELL_W
    y0 = s["oy"] + row * CELL_H
    return sheet.crop((x0, y0, x0 + CELL_W, y0 + CELL_H))


def series(sheet: Image.Image, section: str, row: int) -> list[Image.Image]:
    cols = SECTIONS[section]["cols"]
    return [clean_cell(extract_cell(sheet, section, c, row)) for c in range(cols)]


def save_series(frames: list[Image.Image], prefix: str, anchor: str = "feet") -> None:
    for i, fr in enumerate(frames):
        save(pad(fr, anchor), f"{prefix}_{i:02d}")


def rotate_for_climb(frame: Image.Image, *, left_wall: bool) -> Image.Image:
    """Feet toward the wall, head up (natural climb direction)."""
    # left wall + left-facing walk at -90° → feet left, head up
    # right wall + right-facing walk at +90° → feet right, head up
    angle = -90 if left_wall else 90
    return frame.rotate(angle, expand=True, fillcolor=(0, 0, 0, 0), resample=Image.Resampling.NEAREST)


def rotate_for_hang(frame: Image.Image) -> Image.Image:
    """Feet toward ceiling."""
    return frame.rotate(180, expand=True, fillcolor=(0, 0, 0, 0), resample=Image.Resampling.NEAREST)


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing {SRC}")

    if ATLAS.exists():
        shutil.rmtree(ATLAS)
    ATLAS.mkdir(parents=True)

    sheet = Image.open(SRC).convert("RGBA")

    # Dedicated walk / run / idle art (left-facing); mirror for right.
    # Climb/hang are derived from these walk frames.
    walk_l = load_dedicated_frames("f-walk-*.png")
    walk_r = mirror_right(walk_l)
    run_l = load_dedicated_frames("f-run-*.png")
    run_r = mirror_right(run_l)
    idle_l = load_dedicated_frames("f-idle-*.png")
    idle_r = mirror_right(idle_l)

    # HURT / react still come from the sheet.
    hurt_l = series(sheet, "hurt", ROW_LEFT)
    hurt_r = series(sheet, "hurt", ROW_RIGHT)

    print(
        f"walk_l/r={len(walk_l)}/{len(walk_r)} run={len(run_l)}/{len(run_r)} "
        f"idle_l/r={len(idle_l)}/{len(idle_r)} hurt={len(hurt_l)}/{len(hurt_r)}"
    )
    for i, fr in enumerate(run_l):
        bb = fr.getbbox()
        print(f"  run_l[{i}] opaque={sum(1 for p in fr.getdata() if p[3]>40)} bbox={bb}")

    for i, fr in enumerate(walk_l):
        save(pad(fr, "feet"), f"walk_l_{i:02d}")
        save(pad(walk_r[i], "feet"), f"walk_r_{i:02d}")
    for i, fr in enumerate(run_l):
        save(pad(fr, "feet"), f"run_l_{i:02d}")
        save(pad(run_r[i], "feet"), f"run_r_{i:02d}")

    for i, fr in enumerate(idle_l):
        save(pad(fr, "feet"), f"idle_l_{i:02d}")
        save(pad(idle_r[i], "feet"), f"idle_r_{i:02d}")

    for i in range(8):
        save(pad(hurt_l[i % len(hurt_l)], "feet"), f"react_l_{i:02d}")
        save(pad(hurt_r[i % len(hurt_r)], "feet"), f"react_r_{i:02d}")

    # Climb: rotate side walk — feet on wall, head up.
    # *_d variants are vertically flipped for climbing down.
    for i in range(10):
        up_l = pad(rotate_for_climb(walk_l[i % len(walk_l)], left_wall=True), "left")
        up_r = pad(rotate_for_climb(walk_r[i % len(walk_r)], left_wall=False), "right")
        save(up_l, f"climb_l_{i:02d}")
        save(up_r, f"climb_r_{i:02d}")
        save(up_l.transpose(Image.Transpose.FLIP_TOP_BOTTOM), f"climb_ld_{i:02d}")
        save(up_r.transpose(Image.Transpose.FLIP_TOP_BOTTOM), f"climb_rd_{i:02d}")

    # Hang/top: rotate side walk 180 — feet on ceiling.
    # Note: 180° swaps visual L/R relative to the floor walk art.
    for i in range(8):
        save(pad(rotate_for_hang(walk_l[i % len(walk_l)]), "top"), f"hang_l_{i:02d}")
        save(pad(rotate_for_hang(walk_r[i % len(walk_r)]), "top"), f"hang_r_{i:02d}")

    (ATLAS / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}, "properties": {}}, indent=2)
    )

    sample = Image.open(ATLAS / "walk_l_00.imageset/walk_l_00.png").convert("RGBA")
    idle0 = Image.open(ATLAS / "idle_l_00.imageset/idle_l_00.png").convert("RGBA")
    feet_ok = all(
        Image.open(next(p.glob("*.png"))).getbbox()[3] == CANVAS
        for p in ATLAS.glob("walk_l_*.imageset")
    )
    meta = {
        "source": str(SRC.relative_to(ROOT)),
        "walk_source": "assets/fox/f-walk-*.png (right mirrored)",
        "run_source": "assets/fox/f-run-*.png (right mirrored)",
        "idle_source": "assets/fox/f-idle-*.png (right mirrored)",
        "series": sorted({p.name.rsplit("_", 1)[0] for p in ATLAS.glob("*.imageset")}),
        "feet_on_bottom": feet_ok,
        "idle_l00_opaque": sum(1 for p in idle0.getdata() if p[3] > 40),
        "idle_vs_walk": sum(1 for a, b in zip(sample.getdata(), idle0.getdata()) if a != b),
    }
    META.write_text(json.dumps(meta, indent=2))
    print(json.dumps(meta, indent=2))


if __name__ == "__main__":
    main()

"""Generator gambar sintetis — untuk corpus bootstrap & korban demo.

DUA peran, sengaja beda karakter:
- `synthetic_corpus_image(i)`: banyak, beragam, deterministik per-indeks — mengisi
  registry supaya "tak ada near-duplicate" bermakna sejak awal (jujur: ini corpus
  BOOTSTRAP sintetis, lihat corpus-coverage.md).
- `victim_artwork(i)`: sedikit, kaya, khas — "karya korban" untuk adegan the catch.
"""

from __future__ import annotations

import io
import random

from PIL import Image, ImageDraw


def _rc(rng: random.Random) -> tuple[int, int, int]:
    return (rng.randint(0, 255), rng.randint(0, 255), rng.randint(0, 255))


def to_png(img: Image.Image) -> bytes:
    b = io.BytesIO()
    img.save(b, format="PNG")
    return b.getvalue()


def synthetic_corpus_image(index: int, size: tuple[int, int] = (384, 384)) -> Image.Image:
    """Komposisi acak-deterministik: latar + beberapa bentuk. Cukup beragam
    supaya dua indeks berbeda tidak jadi near-duplicate satu sama lain."""
    rng = random.Random(index * 2654435761 & 0xFFFFFFFF)
    w, h = size
    img = Image.new("RGB", size, _rc(rng))
    d = ImageDraw.Draw(img)
    for _ in range(rng.randint(4, 8)):
        kind = rng.choice(["ellipse", "rectangle", "line", "arc"])
        xs = sorted(rng.sample(range(w), 2))
        ys = sorted(rng.sample(range(h), 2))
        box = [xs[0], ys[0], xs[1], ys[1]]
        col = _rc(rng)
        if kind == "ellipse":
            d.ellipse(box, fill=col)
        elif kind == "rectangle":
            d.rectangle(box, fill=col)
        elif kind == "line":
            d.line(box, fill=col, width=rng.randint(3, 20))
        else:
            d.arc(box, rng.randint(0, 180), rng.randint(180, 360), fill=col, width=rng.randint(3, 16))
    return img


# Seed korban TERKURASI: dipilih lewat scan (scratchpad/curate.py) sebagai
# gambar yang (a) tahan crop 5%/sisi dengan margin (≥2 hash Hamming ≤20) dan
# (b) saling TIDAK near-duplicate. Ini yang membuat test the catch stabil, bukan
# kebetulan — generator acak murni kadang menghasilkan komposisi rapuh-crop.
_VICTIM_SEEDS = [5, 8, 9, 14, 17]


def render_victim(seed: int, size: tuple[int, int] = (512, 512)) -> Image.Image:
    """Render karya korban untuk sebuah seed — gradien vertikal frekuensi-rendah
    (tahan crop) + beberapa elips besar terisi (khas, tanpa outline tipis yang
    merapuhkan pHash). Dipisah dari `victim_artwork` supaya skrip kurasi seed bisa
    memindai memakai fungsi PERSIS sama dengan produksi."""
    rng = random.Random(1000 + seed)
    w, h = size
    img = Image.new("RGB", size)
    d = ImageDraw.Draw(img)
    top, bot = _rc(rng), _rc(rng)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=tuple(int(top[k] * (1 - t) + bot[k] * t) for k in range(3)))
    for _ in range(rng.randint(2, 3)):
        cx, cy = rng.randint(w // 3, 2 * w // 3), rng.randint(h // 3, 2 * h // 3)
        r = rng.randint(w // 4, w // 3)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=_rc(rng))
    return img


def victim_artwork(index: int, size: tuple[int, int] = (512, 512)) -> Image.Image:
    """Korban ke-`index` memakai seed TERKURASI (`_VICTIM_SEEDS`) — dipilih lewat
    scan agar tahan crop 5%/sisi (margin ≥2 hash ≤20) & saling non-near-dup."""
    return render_victim(_VICTIM_SEEDS[index % len(_VICTIM_SEEDS)], size)

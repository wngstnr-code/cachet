"""Normalisasi gambar + sha256 file mentah.

Dua hal yang harus TIDAK tercampur:
- sha256 dihitung dari **byte file mentah** (§3.2 asset_sha256 = "hash file mentah").
- pHash & embedding dihitung dari gambar **ternormalisasi** (RGB, resize sisi
  panjang 512, alpha di-drop) supaya salinan resize/format tetap cocok.
"""

from __future__ import annotations

import hashlib
import io

from PIL import Image

from .config import RESIZE_LONG_SIDE


def sha256_hex(raw: bytes) -> str:
    return "0x" + hashlib.sha256(raw).hexdigest()


def load_normalized(raw: bytes) -> Image.Image:
    """Bytes → PIL RGB ternormalisasi, siap untuk semua hash & embedding.

    Hanya downscale (tidak pernah upscale): memperbesar gambar kecil tidak
    menambah informasi dan bisa menggeser hash. convert('RGB') men-drop alpha.
    """
    img = Image.open(io.BytesIO(raw))
    img.load()  # paksa dekode sekarang supaya error korup ketahuan di sini
    img = img.convert("RGB")

    w, h = img.size
    longest = max(w, h)
    if longest > RESIZE_LONG_SIDE:
        scale = RESIZE_LONG_SIDE / longest
        img = img.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)

    return img

"""Embedding (tier advisory) di belakang interface yang bisa di-swap.

Kenapa interface: tier deterministik (pHash) adalah klaim keras yang WAJIB
berdiri sendiri. Menaruh open_clip di belakang Protocol berarti seluruh logika
inti + test-nya jalan TANPA torch — penting karena wheel torch/open_clip untuk
Python 3.13 belum tentu tersedia (risiko dicatat di be-plan.md). Produksi pakai
ClipEmbedder; test menyuntik FakeEmbedder deterministik.

Kontrak embed(): terima PIL RGB ternormalisasi → np.ndarray float32 shape
(EMBEDDING_DIM,), sudah L2-normalized (norma 1) sehingga inner-product = cosine.
"""

from __future__ import annotations

import hashlib
from typing import Callable, Protocol

import numpy as np
from PIL import Image

from .config import EMBEDDING_DIM


def l2_normalize(v: np.ndarray) -> np.ndarray:
    v = v.astype(np.float32)
    n = float(np.linalg.norm(v))
    if n == 0.0:
        # Vektor nol tidak punya arah; kembalikan nol (cosine jadi 0 ke apa pun).
        return v
    return v / n


class Embedder(Protocol):
    dim: int

    def embed(self, img: Image.Image) -> np.ndarray: ...


class ClipEmbedder:
    """open_clip ViT-B/32 di CPU. Import berat ditunda ke konstruksi."""

    dim = EMBEDDING_DIM

    def __init__(self) -> None:
        import torch  # noqa: WPS433 (lazy — hanya saat produksi)
        import open_clip

        self._torch = torch
        self._model, _, self._preprocess = open_clip.create_model_and_transforms(
            "ViT-B-32", pretrained="openai"
        )
        self._model.eval()

    def embed(self, img: Image.Image) -> np.ndarray:
        torch = self._torch
        with torch.no_grad():
            tensor = self._preprocess(img).unsqueeze(0)
            feats = self._model.encode_image(tensor)
        vec = feats[0].cpu().numpy().astype(np.float32)
        return l2_normalize(vec)


class FakeEmbedder:
    """Embedding deterministik tanpa ML — untuk test & jalan tanpa torch.

    Default: seed dari sha256 piksel → vektor Gaussian ter-normalisasi. Sifatnya:
    gambar identik → vektor identik (cosine 1); gambar berbeda → nyaris ortogonal
    (cosine ≈ 0). Cukup untuk membedakan ORIGINAL vs duplikat.

    Untuk test GRAY_ZONE yang butuh cosine terkendali (0.90–0.97), suntik `fn`
    kustom yang memetakan gambar → vektor buatan tangan.
    """

    dim = EMBEDDING_DIM

    def __init__(self, fn: Callable[[Image.Image], np.ndarray] | None = None) -> None:
        self._fn = fn

    def embed(self, img: Image.Image) -> np.ndarray:
        if self._fn is not None:
            return l2_normalize(self._fn(img))
        small = img.resize((16, 16), Image.LANCZOS).tobytes()
        seed = int.from_bytes(hashlib.sha256(small).digest()[:8], "big")
        rng = np.random.default_rng(seed)
        return l2_normalize(rng.standard_normal(self.dim).astype(np.float32))


def build_embedder(kind: str) -> Embedder:
    if kind == "fake":
        return FakeEmbedder()
    if kind == "clip":
        return ClipEmbedder()
    raise ValueError(f"ENGINE_EMBEDDER tak dikenal: {kind!r} (pakai 'clip' atau 'fake')")

"""Fixture test: store in-memory sementara, FakeEmbedder, TestClient, generator gambar.

Semua test jalan TANPA torch/faiss/c2pa — tier deterministik (pHash) diuji
berdiri sendiri, sesuai desain be-plan.md.
"""

from __future__ import annotations

import base64
import io
from pathlib import Path

import numpy as np
import pytest
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw

from app.config import Settings
from app.embedding import FakeEmbedder
from app.main import create_app
from app.store import EngineStore


# ── Generator gambar deterministik ───────────────────────────────────────────
# Konten frekuensi-rendah (gradien + bentuk besar) tahan resize/crop/JPEG —
# supaya salinan tetap NEAR_DUP di ambang Hamming 25 yang dikunci spec.

def _base_image(seed: int = 1, size: tuple[int, int] = (512, 512)) -> Image.Image:
    """Tiga pita horizontal — struktur frekuensi-rendah yang TAHAN crop/resize/
    JPEG (dibuktikan lewat diagnostik: crop 5%/sisi tetap ≥3 hash cocok). Warna
    dirotasi per-seed; strukturnya sengaja sama supaya transform salinan cocok."""
    w, h = size
    img = Image.new("RGB", size)
    d = ImageDraw.Draw(img)
    cols = [(90, 150, 210), (235, 175, 70), (70, 180, 120)]
    cols = cols[seed % 3:] + cols[: seed % 3]
    d.rectangle([0, 0, w, h // 3], fill=cols[0])
    d.rectangle([0, h // 3, w, 2 * h // 3], fill=cols[1])
    d.rectangle([0, 2 * h // 3, w, h], fill=cols[2])
    return img


def _other_image(size: tuple[int, int] = (512, 512)) -> Image.Image:
    """Gambar yang BEDA STRUKTURAL dari _base_image (bukan sekadar beda warna):
    empat kuadran kontras + diagonal — supaya kasus ORIGINAL tidak tak sengaja
    jadi NEAR_DUP karena struktur mirip."""
    w, h = size
    img = Image.new("RGB", size, (0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w // 2, h // 2], fill=(220, 30, 30))
    d.rectangle([w // 2, 0, w, h // 2], fill=(30, 30, 220))
    d.rectangle([0, h // 2, w // 2, h], fill=(240, 220, 20))
    d.rectangle([w // 2, h // 2, w, h], fill=(20, 200, 60))
    d.line([0, h, w, 0], fill=(255, 255, 255), width=20)
    return img


def with_marker(img: Image.Image, marker: int) -> Image.Image:
    """Tempel blok penanda kecil di pojok kiri-atas (piksel (5,5) = marker).
    Dipakai test GRAY_ZONE: FakeEmbedder membaca penanda → kembalikan vektor
    dengan cosine terkendali. Marker tak mengganggu pHash karena pasangannya
    memang beda struktural (base vs other)."""
    img = img.copy()
    ImageDraw.Draw(img).rectangle([0, 0, 30, 30], fill=(marker, marker, marker))
    return img


def to_bytes(img: Image.Image, fmt: str = "PNG", **kw) -> bytes:
    buf = io.BytesIO()
    img.save(buf, format=fmt, **kw)
    return buf.getvalue()


def to_b64(img: Image.Image, fmt: str = "PNG", **kw) -> str:
    return base64.b64encode(to_bytes(img, fmt, **kw)).decode()


@pytest.fixture
def base_img() -> Image.Image:
    return _base_image(seed=1)


@pytest.fixture
def make_image():
    return _base_image


@pytest.fixture
def store(tmp_path: Path) -> EngineStore:
    return EngineStore(tmp_path / "t.db")


@pytest.fixture
def client(tmp_path: Path) -> TestClient:
    settings = Settings(port=8100, index_dir=tmp_path, embedder_kind="fake")
    app = create_app(settings=settings, store=EngineStore(tmp_path / "t.db"), embedder=FakeEmbedder())
    return TestClient(app)


def make_client_with_embedder(tmp_path: Path, embedder) -> TestClient:
    settings = Settings(port=8100, index_dir=tmp_path, embedder_kind="fake")
    app = create_app(settings=settings, store=EngineStore(tmp_path / "t2.db"), embedder=embedder)
    return TestClient(app)

"""Test e2e endpoint — kasus penerimaan §4-A1.7 (the catch).

Salinan (resize/crop/JPEG/grayscale/identik) WAJIB NEAR_DUP; gambar beda
ORIGINAL; kembar-mirip embedding GRAY_ZONE. Semua pakai FakeEmbedder — tier
pHash yang dijamin diuji berdiri sendiri.
"""

from __future__ import annotations

import numpy as np
from PIL import Image

from app.config import HAMMING_THRESHOLD, EMBEDDING_DIM
from app.embedding import FakeEmbedder

from .conftest import (
    _base_image,
    _other_image,
    make_client_with_embedder,
    to_b64,
    with_marker,
)


def _index(client, img, **kw):
    r = client.post("/index", json={"image_b64": to_b64(img, **kw)})
    assert r.status_code == 200, r.text
    return r.json()["entry_id"]


def _query(client, img, **kw):
    r = client.post("/query", json={"image_b64": to_b64(img, **kw)})
    assert r.status_code == 200, r.text
    return r.json()


# ── The catch: lima transformasi salinan → NEAR_DUP ──────────────────────────

def test_identical_copy_is_near_dup(client):
    base = _base_image(1)
    eid = _index(client, base)
    out = _query(client, base)
    assert out["verdict"] == "NEAR_DUP"
    assert out["first_seen"]["nearest_entry_id"] == eid
    assert out["first_seen"]["min_hamming"] <= HAMMING_THRESHOLD
    assert out["insurable"] is False


def test_resized_copy_is_near_dup(client):
    base = _base_image(1)
    _index(client, base)
    resized = base.resize((256, 256), Image.LANCZOS)
    out = _query(client, resized)
    assert out["verdict"] == "NEAR_DUP"
    assert out["first_seen"]["min_hamming"] <= HAMMING_THRESHOLD


def test_cropped_copy_is_near_dup(client):
    # "crop 10%" = buang ~10% per dimensi (5% tiap sisi). Membuang 10% TIAP sisi
    # (20% per dimensi, 36% area) adalah transform jauh lebih besar dan memang di
    # luar toleransi pHash 256-bit — dibuktikan lewat diagnostik saat menyetel fixture.
    base = _base_image(1)
    _index(client, base)
    w, h = base.size
    dx, dy = w // 20, h // 20  # 5% tiap sisi
    cropped = base.crop((dx, dy, w - dx, h - dy))
    out = _query(client, cropped)
    assert out["verdict"] == "NEAR_DUP"


def test_jpeg_q30_copy_is_near_dup(client):
    base = _base_image(1)
    _index(client, base)
    out = _query(client, base, fmt="JPEG", quality=30)
    assert out["verdict"] == "NEAR_DUP"


def test_grayscale_copy_is_near_dup(client):
    base = _base_image(1)
    _index(client, base)
    gray = base.convert("L").convert("RGB")
    out = _query(client, gray)
    assert out["verdict"] == "NEAR_DUP"


# ── Gambar berbeda → ORIGINAL ────────────────────────────────────────────────

def test_different_image_is_original(client):
    _index(client, _base_image(1))
    out = _query(client, _other_image())
    assert out["verdict"] == "ORIGINAL"
    assert out["first_seen"]["is_first"] is True
    assert out["insurable"] is True


def test_empty_corpus_is_original(client):
    out = _query(client, _base_image(7))
    assert out["verdict"] == "ORIGINAL"
    assert out["first_seen"]["nearest_entry_id"] is None


# ── Zona abu-abu embedding (advisory) ────────────────────────────────────────

def test_gray_zone_via_controlled_cosine(tmp_path):
    # Dua vektor dengan cosine 0.93: vA sepanjang sumbu-0; vB campuran sumbu-0 & 1.
    cos = 0.93
    vA = np.zeros(EMBEDDING_DIM, dtype=np.float32); vA[0] = 1.0
    vB = np.zeros(EMBEDDING_DIM, dtype=np.float32); vB[0] = cos; vB[1] = float(np.sqrt(1 - cos * cos))

    def fn(img: Image.Image) -> np.ndarray:
        r = img.getpixel((5, 5))[0]  # baca penanda pojok
        if r == 100:
            return vA
        if r == 200:
            return vB
        return np.ones(EMBEDDING_DIM, dtype=np.float32)

    client = make_client_with_embedder(tmp_path, FakeEmbedder(fn=fn))
    # base vs other = beda struktural → pHash TIDAK cocok (bukan NEAR_DUP);
    # embedding di pita 0.90–0.97 → GRAY_ZONE murni dari tier advisory.
    _index(client, with_marker(_base_image(1), 100))
    out = _query(client, with_marker(_other_image(), 200))
    assert out["verdict"] == "GRAY_ZONE"
    assert 0.90 <= out["distinctiveness"]["nearest_cosine"] <= 0.97
    assert out["insurable"] is False


# ── /hash & /index kontrak ───────────────────────────────────────────────────

def test_hash_shape_and_determinism(client):
    b64 = to_b64(_base_image(3))
    r1 = client.post("/hash", json={"image_b64": b64}).json()
    r2 = client.post("/hash", json={"image_b64": b64}).json()
    assert r1 == r2
    assert len(r1["phashes"]) == 4
    assert r1["asset_sha256"].startswith("0x")
    assert r1["embedding_commit"].startswith("0x")


def test_index_assigns_incrementing_ids(client):
    e1 = _index(client, _base_image(1))
    e2 = _index(client, _other_image())
    assert e2 == e1 + 1  # id corpus mulai 1, naik


def test_bad_base64_is_422(client):
    r = client.post("/query", json={"image_b64": "!!!not-base64!!!"})
    assert r.status_code == 422


def test_healthz_reports_count(client):
    assert client.get("/healthz").json()["entries"] == 0
    _index(client, _base_image(1))
    assert client.get("/healthz").json()["entries"] == 1

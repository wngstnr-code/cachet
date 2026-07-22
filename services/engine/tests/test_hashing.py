"""Unit hashing: bentuk output, determinisme, jarak Hamming."""

from __future__ import annotations

import numpy as np

from app.config import HASH_BITS
from app.hashing import compute_phashes, hamming_vector, hex_to_phash, phashes_to_hex
from app.imaging import load_normalized

from .conftest import _base_image, to_bytes


def test_produces_four_256bit_hashes():
    img = load_normalized(to_bytes(_base_image(1)))
    phs = compute_phashes(img)
    assert len(phs) == 4
    assert all(len(p) == HASH_BITS // 8 for p in phs)  # 32 byte


def test_deterministic():
    img = load_normalized(to_bytes(_base_image(1)))
    assert compute_phashes(img) == compute_phashes(img)


def test_hex_roundtrip():
    img = load_normalized(to_bytes(_base_image(2)))
    phs = compute_phashes(img)
    hexed = phashes_to_hex(phs)
    assert all(h.startswith("0x") for h in hexed)
    assert [hex_to_phash(h) for h in hexed] == phs


def test_hamming_identical_is_zero():
    img = load_normalized(to_bytes(_base_image(3)))
    p = compute_phashes(img)[0]
    mat = np.frombuffer(p, dtype=np.uint8).reshape(1, 32)
    assert int(hamming_vector(mat, p)[0]) == 0


def test_hamming_empty_matrix():
    empty = np.empty((0, 32), dtype=np.uint8)
    out = hamming_vector(empty, b"\x00" * 32)
    assert out.shape == (0,)

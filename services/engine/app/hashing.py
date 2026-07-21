"""Ensemble perceptual hash ×4 + jarak Hamming tervektorisasi.

Empat algoritma paralel (§F1, anti-evasion G5): mengelabui satu hash ≠
mengelabui semua. Urutan hash DIKUNCI — phash0 adalah `phash`, dan rumus commit
on-chain (§3.1 RFC-P4) memakai phash0. Jangan mengubah urutan ini tanpa
menyepakati perubahan §3.
"""

from __future__ import annotations

import numpy as np
import imagehash
from PIL import Image

from .config import HASH_SIZE, HASH_BITS

# Urutan KUNCI: indeks 0 = phash (dipakai phash0 di commit-reveal & event Registered).
_HASHERS = (
    ("phash", imagehash.phash),
    ("average_hash", imagehash.average_hash),
    ("dhash", imagehash.dhash),
    ("whash", imagehash.whash),
)

_NBYTES = HASH_BITS // 8  # 32

# Lookup popcount 1 byte → jumlah bit — inti Hamming cepat via numpy.
_POPCOUNT = np.array([bin(i).count("1") for i in range(256)], dtype=np.uint16)


def _hash_to_bytes(h: imagehash.ImageHash) -> bytes:
    """ImageHash (array bool 16×16) → 32 byte big-endian yang stabil."""
    packed = np.packbits(h.hash.flatten())  # (32,) uint8
    return packed.tobytes()


def compute_phashes(img: Image.Image) -> list[bytes]:
    """Gambar ternormalisasi → 4 hash, masing-masing 32 byte (256 bit)."""
    out: list[bytes] = []
    for _, fn in _HASHERS:
        h = fn(img, hash_size=HASH_SIZE)
        out.append(_hash_to_bytes(h))
    return out


def phashes_to_hex(phashes: list[bytes]) -> list[str]:
    return ["0x" + p.hex() for p in phashes]


def hex_to_phash(hexstr: str) -> bytes:
    b = bytes.fromhex(hexstr[2:] if hexstr.startswith("0x") else hexstr)
    if len(b) != _NBYTES:
        raise ValueError(f"phash harus {_NBYTES} byte, dapat {len(b)}")
    return b


def hamming_vector(matrix: np.ndarray, query: bytes) -> np.ndarray:
    """Jarak Hamming query terhadap SEMUA baris matrix sekaligus.

    matrix: (N, 32) uint8 — satu jenis hash untuk seluruh corpus.
    query:  32 byte.
    return: (N,) uint16 jarak Hamming (0..256).
    """
    if matrix.shape[0] == 0:
        return np.empty(0, dtype=np.uint16)
    q = np.frombuffer(query, dtype=np.uint8)
    xor = np.bitwise_xor(matrix, q)  # (N, 32)
    return _POPCOUNT[xor].sum(axis=1).astype(np.uint16)

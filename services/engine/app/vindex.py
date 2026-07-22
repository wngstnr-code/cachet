"""Vector index (cosine) di belakang interface — FAISS bila ada, numpy bila tidak.

FAISS IndexFlatIP atas vektor L2-normalized = pencarian cosine eksak. Untuk
≤100k entri, brute-force numpy (matriks @ query) setara secara hasil dan
menghapus ketergantungan wheel faiss-cpu di Python 3.13 (risiko be-plan.md).
Keduanya mengembalikan (entry_id, cosine) tetangga terdekat.
"""

from __future__ import annotations

import numpy as np

from .config import EMBEDDING_DIM


class NumpyIndex:
    """Brute-force cosine. Sederhana, eksak, tanpa dependency tambahan."""

    def __init__(self, dim: int = EMBEDDING_DIM) -> None:
        self.dim = dim
        self._ids: list[int] = []
        self._mat = np.empty((0, dim), dtype=np.float32)

    def add(self, entry_id: int, vec: np.ndarray) -> None:
        self._ids.append(int(entry_id))
        self._mat = np.vstack([self._mat, vec.astype(np.float32).reshape(1, -1)])

    def search(self, vec: np.ndarray, k: int = 1) -> list[tuple[int, float]]:
        if self._mat.shape[0] == 0:
            return []
        sims = self._mat @ vec.astype(np.float32)  # (N,) cosine (vektor sudah L2-norm)
        k = min(k, sims.shape[0])
        top = np.argpartition(-sims, k - 1)[:k]
        top = top[np.argsort(-sims[top])]
        return [(self._ids[i], float(sims[i])) for i in top]

    @property
    def size(self) -> int:
        return len(self._ids)


class FaissIndex:
    """IndexIDMap(IndexFlatIP) — id kustom + cosine eksak."""

    def __init__(self, dim: int = EMBEDDING_DIM) -> None:
        import faiss  # noqa: WPS433 (lazy)

        self._faiss = faiss
        self.dim = dim
        self._index = faiss.IndexIDMap(faiss.IndexFlatIP(dim))
        self._count = 0

    def add(self, entry_id: int, vec: np.ndarray) -> None:
        v = vec.astype(np.float32).reshape(1, -1)
        self._index.add_with_ids(v, np.array([entry_id], dtype=np.int64))
        self._count += 1

    def search(self, vec: np.ndarray, k: int = 1) -> list[tuple[int, float]]:
        if self._count == 0:
            return []
        v = vec.astype(np.float32).reshape(1, -1)
        sims, ids = self._index.search(v, min(k, self._count))
        return [
            (int(i), float(s))
            for i, s in zip(ids[0], sims[0])
            if i != -1
        ]

    @property
    def size(self) -> int:
        return self._count


def build_vector_index(dim: int = EMBEDDING_DIM):
    """FAISS bila importable, selain itu numpy. Hasil identik untuk skala MVP."""
    try:
        return FaissIndex(dim)
    except Exception:
        return NumpyIndex(dim)

"""OriginalityService — merangkai hashing + embedding + store + verdict.

Satu tempat yang tahu urutan penuh: normalisasi → 4 pHash + embedding →
kueri corpus → verdict. Routes tinggal memanggil ini; test bisa memakainya
langsung tanpa HTTP.
"""

from __future__ import annotations

import base64
import time

import numpy as np

from . import verdict as V
from .c2pa_reader import read_c2pa
from .embedding import Embedder
from .hashing import compute_phashes, phashes_to_hex
from .imaging import load_normalized, sha256_hex
from .keccak import keccak256_hex
from .store import EngineStore


def _decode(image_b64: str) -> bytes:
    try:
        return base64.b64decode(image_b64, validate=True)
    except Exception as exc:  # noqa: BLE001
        raise ValueError(f"image_b64 bukan base64 valid: {exc}") from exc


class OriginalityService:
    def __init__(self, store: EngineStore, embedder: Embedder) -> None:
        self._store = store
        self._embedder = embedder

    def _fingerprint(self, raw: bytes) -> tuple[str, list[bytes], np.ndarray]:
        sha = sha256_hex(raw)
        img = load_normalized(raw)
        phashes = compute_phashes(img)
        embedding = self._embedder.embed(img)
        return sha, phashes, embedding

    def hash(self, image_b64: str) -> dict:
        raw = _decode(image_b64)
        sha, phashes, embedding = self._fingerprint(raw)
        return {
            "asset_sha256": sha,
            "phashes": phashes_to_hex(phashes),
            "embedding_commit": keccak256_hex(embedding.astype(np.float32).tobytes()),
        }

    def index(self, image_b64: str, source: str | None, uri: str | None) -> dict:
        raw = _decode(image_b64)
        sha, phashes, embedding = self._fingerprint(raw)
        entry_id = self._store.add_entry(
            phashes=phashes,
            embedding=embedding,
            sha256=sha,
            source=source,
            uri=uri,
            created_at=int(time.time()),
        )
        return {"entry_id": entry_id, "asset_sha256": sha}

    def query(self, image_b64: str) -> dict:
        raw = _decode(image_b64)
        sha, phashes, embedding = self._fingerprint(raw)

        near = self._store.nearest_phash(phashes)
        emb_hit = self._store.nearest_embedding(embedding)
        max_cosine = emb_hit[1] if emb_hit is not None else 0.0

        if near is None:
            result = V.decide(None, 0, 256, max_cosine)
        else:
            result = V.decide(near.entry_id, near.matched, near.min_hamming, max_cosine)

        c2pa = read_c2pa(raw)

        return {
            "asset_sha256": sha,
            "verdict": result.verdict,
            "first_seen": {
                "is_first": result.first_seen.is_first,
                "nearest_entry_id": result.first_seen.nearest_entry_id,
                "min_hamming": result.first_seen.min_hamming,
                "hashes_matched": result.first_seen.hashes_matched,
            },
            "distinctiveness": {
                "score": result.distinctiveness.score,
                "nearest_cosine": result.distinctiveness.nearest_cosine,
                "label": result.distinctiveness.label,
            },
            "ai_declaration": {
                "c2pa_present": c2pa.c2pa_present,
                "synthid_checked": c2pa.synthid_checked,
                "notes": c2pa.notes,
            },
            "insurable": result.insurable,
            "phashes": phashes_to_hex(phashes),
            "embedding_commit": keccak256_hex(embedding.astype(np.float32).tobytes()),
        }

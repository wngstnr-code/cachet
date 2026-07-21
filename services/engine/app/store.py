"""Penyimpanan corpus: SQLite (sumber kebenaran) + cermin in-memory untuk kueri.

SQLite tabel `entries(entry_id, phash0..3 BLOB, sha256, source, uri, created_at,
embedding BLOB)` — persis §4-A1.4 plus kolom embedding supaya index vektor bisa
dibangun ulang dari satu sumber saat start. Kueri pHash = linear scan Hamming
tervektorisasi di RAM (numpy), bukan di SQL. Kueri embedding lewat vector index.

entry_id di sini adalah id CORPUS engine (auto-increment), BUKAN entryId
on-chain. Keduanya beda ruang id: corpus berisi pre-seed + semua yang di-mint,
sedangkan registry on-chain hanya yang bersertifikat. Referensi on-chain, bila
ada, disimpan di kolom `source`/`uri`. nearest_entry_id di §3.2 = id corpus ini.
"""

from __future__ import annotations

import sqlite3
import threading
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from .config import EMBEDDING_DIM
from .hashing import hamming_vector
from .vindex import build_vector_index

_NBYTES = 32


@dataclass(frozen=True)
class NearestPhash:
    entry_id: int
    matched: int
    min_hamming: int


class EngineStore:
    def __init__(self, db_path: Path) -> None:
        db_path.parent.mkdir(parents=True, exist_ok=True)
        self._db = sqlite3.connect(str(db_path), check_same_thread=False)
        self._db.execute("PRAGMA journal_mode=WAL")
        self._lock = threading.Lock()
        self._create_schema()

        # Cermin in-memory: satu matriks (N,32) per jenis hash + id sejajar.
        self._ids: list[int] = []
        self._phash_mats = [np.empty((0, _NBYTES), dtype=np.uint8) for _ in range(4)]
        self._vindex = build_vector_index(EMBEDDING_DIM)
        self._load_into_memory()

    def _create_schema(self) -> None:
        self._db.execute(
            """
            CREATE TABLE IF NOT EXISTS entries (
                entry_id   INTEGER PRIMARY KEY AUTOINCREMENT,
                phash0     BLOB NOT NULL,
                phash1     BLOB NOT NULL,
                phash2     BLOB NOT NULL,
                phash3     BLOB NOT NULL,
                sha256     TEXT NOT NULL,
                source     TEXT,
                uri        TEXT,
                embedding  BLOB NOT NULL,
                created_at INTEGER NOT NULL
            )
            """
        )
        self._db.commit()

    def _load_into_memory(self) -> None:
        cur = self._db.execute(
            "SELECT entry_id, phash0, phash1, phash2, phash3, embedding "
            "FROM entries ORDER BY entry_id"
        )
        rows = cur.fetchall()
        if not rows:
            return
        mats = [np.empty((len(rows), _NBYTES), dtype=np.uint8) for _ in range(4)]
        for i, row in enumerate(rows):
            entry_id = row[0]
            self._ids.append(entry_id)
            for k in range(4):
                mats[k][i] = np.frombuffer(row[1 + k], dtype=np.uint8)
            vec = np.frombuffer(row[5], dtype=np.float32)
            self._vindex.add(entry_id, vec)
        self._phash_mats = mats

    # ── Tulis ────────────────────────────────────────────────────────────────

    def add_entry(
        self,
        phashes: list[bytes],
        embedding: np.ndarray,
        sha256: str,
        source: str | None,
        uri: str | None,
        created_at: int,
    ) -> int:
        if len(phashes) != 4 or any(len(p) != _NBYTES for p in phashes):
            raise ValueError("butuh 4 phash @ 32 byte")
        emb = embedding.astype(np.float32)
        with self._lock:
            cur = self._db.execute(
                "INSERT INTO entries (phash0, phash1, phash2, phash3, sha256, "
                "source, uri, embedding, created_at) VALUES (?,?,?,?,?,?,?,?,?)",
                (
                    phashes[0], phashes[1], phashes[2], phashes[3],
                    sha256, source, uri, emb.tobytes(), created_at,
                ),
            )
            self._db.commit()
            entry_id = int(cur.lastrowid)

            self._ids.append(entry_id)
            for k in range(4):
                row = np.frombuffer(phashes[k], dtype=np.uint8).reshape(1, _NBYTES)
                self._phash_mats[k] = np.vstack([self._phash_mats[k], row])
            self._vindex.add(entry_id, emb)
        return entry_id

    # ── Baca / kueri ─────────────────────────────────────────────────────────

    def count(self) -> int:
        return len(self._ids)

    def nearest_phash(self, query_phashes: list[bytes]) -> NearestPhash | None:
        """Kandidat pHash terdekat di seluruh corpus.

        Untuk tiap entri hitung 4 jarak Hamming (query.hash_k vs entry.hash_k),
        lalu pilih entri dengan (jumlah hash cocok terbanyak, jarak terkecil).
        """
        n = self.count()
        if n == 0:
            return None

        # (4, N) jarak Hamming: baris k = hash ke-k terhadap seluruh corpus.
        dists = np.stack(
            [hamming_vector(self._phash_mats[k], query_phashes[k]) for k in range(4)]
        ).astype(np.int32)

        from .config import HAMMING_THRESHOLD, HASH_BITS

        matched = (dists <= HAMMING_THRESHOLD).sum(axis=0)  # (N,)
        min_h = dists.min(axis=0)  # (N,)
        rank = matched.astype(np.int64) * (HASH_BITS + 1) - min_h.astype(np.int64)
        best = int(np.argmax(rank))
        return NearestPhash(
            entry_id=self._ids[best],
            matched=int(matched[best]),
            min_hamming=int(min_h[best]),
        )

    def nearest_embedding(self, query_vec: np.ndarray) -> tuple[int, float] | None:
        res = self._vindex.search(query_vec, k=1)
        return res[0] if res else None

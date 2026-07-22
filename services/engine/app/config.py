"""Konfigurasi engine dari .env root monorepo.

Default tiap tool TIDAK menunjuk ke root (§6), jadi kita cari .env naik ke atas
lewat find_dotenv(). Semua parameter verdict di sini adalah SATU sumber
kebenaran off-chain, mengikuti §1.3 — angka on-chain hidup di kontrak B.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import find_dotenv, load_dotenv

# Muat .env root sekali saat modul di-import. find_dotenv menaiki pohon direktori
# dari cwd; kalau .env belum ada (mis. CI unit test) ini no-op yang aman.
load_dotenv(find_dotenv(usecwd=True))


# ── Parameter verdict (§1.3) — deterministik, bagian dari klaim keras ────────

# Ensemble pHash: 16×16 → 256 bit per hash. NEAR_DUP bila ≥2 dari 4 hash punya
# Hamming ≤ HAMMING_THRESHOLD terhadap kandidat terdekat.
HASH_SIZE = 16
HASH_BITS = HASH_SIZE * HASH_SIZE  # 256
HAMMING_THRESHOLD = 25
NEAR_DUP_MIN_MATCHES = 2

# Zona abu-abu embedding (advisory): "terlalu dekat untuk lolos, terlalu jauh
# untuk ditolak otomatis" → boleh mint tapi TIDAK insurable (anti-evasion G5).
GRAY_ZONE_LOW = 0.90
GRAY_ZONE_HIGH = 0.97

# Distinctiveness (advisory): 1 − max cosine. Label ambang §3.2.
DISTINCTIVE_HIGH = 0.7
DISTINCTIVE_LOW = 0.3

# Normalisasi gambar sebelum hashing (§4-A1.2).
RESIZE_LONG_SIDE = 512

# Dimensi embedding (open_clip ViT-B/32).
EMBEDDING_DIM = 512


@dataclass(frozen=True)
class Settings:
    port: int
    index_dir: Path
    embedder_kind: str  # "clip" (produksi) | "fake" (test/tanpa ML)

    @property
    def db_path(self) -> Path:
        return self.index_dir / "engine.db"


def load_settings() -> Settings:
    index_dir = Path(os.getenv("INDEX_PATH", "./data/index")).expanduser()
    return Settings(
        port=int(os.getenv("ENGINE_PORT", "8100")),
        index_dir=index_dir,
        # Default "clip"; test menyuntik "fake" lewat factory create_app.
        embedder_kind=os.getenv("ENGINE_EMBEDDER", "clip").lower(),
    )

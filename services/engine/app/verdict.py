"""Logika verdict first-seen + distinctiveness — fungsi murni, mudah dites.

Urutan keputusan (§1.3, §4-A1.5):
  1. NEAR_DUP  bila kandidat terdekat punya ≥2 dari 4 hash Hamming ≤ 25.
  2. GRAY_ZONE bila (bukan NEAR_DUP) dan max cosine ∈ [0.90, 0.97].
  3. ORIGINAL  selain itu.
NEAR_DUP menang atas GRAY_ZONE: klaim keras deterministik didahulukan.
"""

from __future__ import annotations

from dataclasses import dataclass

from .config import (
    DISTINCTIVE_HIGH,
    DISTINCTIVE_LOW,
    GRAY_ZONE_HIGH,
    GRAY_ZONE_LOW,
    HAMMING_THRESHOLD,
    HASH_BITS,
    NEAR_DUP_MIN_MATCHES,
)

VERDICT_ORIGINAL = "ORIGINAL"
VERDICT_NEAR_DUP = "NEAR_DUP"
VERDICT_GRAY_ZONE = "GRAY_ZONE"

LABEL_DISTINCTIVE = "DISTINCTIVE"
LABEL_DERIVATIVE = "DERIVATIVE"
LABEL_GENERIC = "GENERIC"


@dataclass(frozen=True)
class FirstSeen:
    is_first: bool
    nearest_entry_id: int | None
    min_hamming: int
    hashes_matched: int


@dataclass(frozen=True)
class Distinctiveness:
    score: float
    nearest_cosine: float
    label: str


@dataclass(frozen=True)
class VerdictResult:
    verdict: str
    first_seen: FirstSeen
    distinctiveness: Distinctiveness
    insurable: bool


def score_candidate(hammings: list[int]) -> tuple[int, int]:
    """Satu kandidat (4 jarak Hamming) → (jumlah hash cocok, hamming terkecil)."""
    matched = sum(1 for h in hammings if h <= HAMMING_THRESHOLD)
    return matched, min(hammings)


def rank_key(matched: int, min_h: int) -> int:
    """Kunci pemilihan kandidat terdekat: prioritaskan JUMLAH hash cocok, lalu
    jarak terkecil. Memaksimalkan tangkapan salinan (recall) — sebuah entri
    dengan 2 hash cocok mengalahkan entri dengan 1 hash cocok yang lebih dekat."""
    return matched * (HASH_BITS + 1) - min_h


def _label(score: float) -> str:
    if score > DISTINCTIVE_HIGH:
        return LABEL_DISTINCTIVE
    if score >= DISTINCTIVE_LOW:
        return LABEL_DERIVATIVE
    return LABEL_GENERIC


def decide(
    nearest_entry_id: int | None,
    best_matched: int,
    best_min_hamming: int,
    max_cosine: float,
) -> VerdictResult:
    """Gabungkan sinyal pHash + embedding → verdict akhir.

    nearest_entry_id None berarti corpus kosong untuk kueri ini.
    max_cosine adalah cosine ke tetangga embedding terdekat (0.0 bila kosong).
    """
    is_near_dup = (
        nearest_entry_id is not None and best_matched >= NEAR_DUP_MIN_MATCHES
    )

    score = max(0.0, min(1.0, 1.0 - max_cosine))
    distinct = Distinctiveness(
        score=round(score, 4),
        nearest_cosine=round(max_cosine, 4),
        label=_label(score),
    )

    if is_near_dup:
        verdict = VERDICT_NEAR_DUP
    elif GRAY_ZONE_LOW <= max_cosine <= GRAY_ZONE_HIGH:
        verdict = VERDICT_GRAY_ZONE
    else:
        verdict = VERDICT_ORIGINAL

    first_seen = FirstSeen(
        is_first=(verdict == VERDICT_ORIGINAL),
        nearest_entry_id=nearest_entry_id,
        min_hamming=best_min_hamming,
        hashes_matched=best_matched,
    )

    # Hanya tier deterministik yang boleh dijamin (§5.2). NEAR_DUP & GRAY_ZONE
    # tidak insurable — yang pertama jelas salinan, yang kedua terlalu dekat.
    insurable = verdict == VERDICT_ORIGINAL

    return VerdictResult(
        verdict=verdict,
        first_seen=first_seen,
        distinctiveness=distinct,
        insurable=insurable,
    )

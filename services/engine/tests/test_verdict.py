"""Unit murni logika verdict — tanpa gambar, tanpa I/O."""

from __future__ import annotations

from app import verdict as V


def test_near_dup_needs_two_matches():
    # 2 hash cocok → NEAR_DUP walau cosine rendah.
    r = V.decide(nearest_entry_id=5, best_matched=2, best_min_hamming=3, max_cosine=0.1)
    assert r.verdict == V.VERDICT_NEAR_DUP
    assert r.first_seen.is_first is False
    assert r.insurable is False
    assert r.first_seen.nearest_entry_id == 5


def test_one_match_is_not_near_dup():
    # 1 hash cocok saja belum cukup → jatuh ke ORIGINAL (cosine rendah).
    r = V.decide(nearest_entry_id=5, best_matched=1, best_min_hamming=10, max_cosine=0.2)
    assert r.verdict == V.VERDICT_ORIGINAL
    assert r.insurable is True


def test_gray_zone_band():
    for cos in (0.90, 0.93, 0.97):
        r = V.decide(nearest_entry_id=9, best_matched=0, best_min_hamming=120, max_cosine=cos)
        assert r.verdict == V.VERDICT_GRAY_ZONE
        assert r.insurable is False


def test_just_outside_gray_zone_is_original():
    r = V.decide(nearest_entry_id=9, best_matched=0, best_min_hamming=120, max_cosine=0.8999)
    assert r.verdict == V.VERDICT_ORIGINAL
    r2 = V.decide(nearest_entry_id=9, best_matched=0, best_min_hamming=120, max_cosine=0.9701)
    assert r2.verdict == V.VERDICT_ORIGINAL


def test_near_dup_beats_gray_zone():
    # Cosine di pita gray-zone TAPI 2 hash cocok → NEAR_DUP menang (tier keras dulu).
    r = V.decide(nearest_entry_id=1, best_matched=2, best_min_hamming=5, max_cosine=0.95)
    assert r.verdict == V.VERDICT_NEAR_DUP


def test_empty_corpus_is_original():
    r = V.decide(nearest_entry_id=None, best_matched=0, best_min_hamming=256, max_cosine=0.0)
    assert r.verdict == V.VERDICT_ORIGINAL
    assert r.first_seen.nearest_entry_id is None
    assert r.distinctiveness.score == 1.0


def test_distinctiveness_labels():
    assert V.decide(None, 0, 256, 0.1).distinctiveness.label == V.LABEL_DISTINCTIVE  # score 0.9
    assert V.decide(None, 0, 256, 0.5).distinctiveness.label == V.LABEL_DERIVATIVE  # score 0.5
    assert V.decide(None, 0, 256, 0.85).distinctiveness.label == V.LABEL_GENERIC     # score 0.15

"""Test store: persistensi SQLite, rebuild in-memory, kueri pHash & embedding."""

from __future__ import annotations

import numpy as np

from app.embedding import FakeEmbedder, l2_normalize
from app.hashing import compute_phashes
from app.imaging import load_normalized
from app.store import EngineStore

from .conftest import _base_image, _other_image, to_bytes


def _add(store: EngineStore, img, source="test"):
    phs = compute_phashes(load_normalized(to_bytes(img)))
    vec = l2_normalize(np.random.default_rng(0).standard_normal(512).astype(np.float32))
    return store.add_entry(phs, vec, "0xabc", source, None, 0)


def test_reload_from_disk(tmp_path):
    db = tmp_path / "p.db"
    s1 = EngineStore(db)
    eid = _add(s1, _base_image(1))
    assert s1.count() == 1

    s2 = EngineStore(db)  # buka ulang → cermin in-memory dibangun dari SQLite
    assert s2.count() == 1
    near = s2.nearest_phash(compute_phashes(load_normalized(to_bytes(_base_image(1)))))
    assert near is not None and near.entry_id == eid and near.matched >= 2


def test_nearest_phash_empty():
    import tempfile, pathlib
    with tempfile.TemporaryDirectory() as d:
        s = EngineStore(pathlib.Path(d) / "e.db")
        assert s.nearest_phash(compute_phashes(load_normalized(to_bytes(_base_image(1))))) is None


def test_nearest_embedding_roundtrip(tmp_path):
    s = EngineStore(tmp_path / "e.db")
    vec = l2_normalize(np.arange(512, dtype=np.float32))
    phs = compute_phashes(load_normalized(to_bytes(_base_image(1))))
    eid = s.add_entry(phs, vec, "0x1", None, None, 0)
    hit = s.nearest_embedding(vec)
    assert hit is not None
    assert hit[0] == eid
    assert abs(hit[1] - 1.0) < 1e-4  # cosine ke dirinya ≈ 1

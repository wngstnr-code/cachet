"""Test preseed: checkpoint/resume, sumber sintetis, corpus terisi."""

from __future__ import annotations

import json
from pathlib import Path

import preseed
from lib.checkpoint import Checkpoint
from lib.sources import synthetic_source


def test_synthetic_source_skips_done():
    skip = {"synthetic://0", "synthetic://2"}
    keys = [it.key for it in synthetic_source(4, skip)]
    assert keys == ["synthetic://1", "synthetic://3"]


def test_checkpoint_roundtrip_and_resume(tmp_path):
    path = tmp_path / "cp.json"
    cp = Checkpoint(path)
    cp.mark("synthetic://0", "synthetic")
    cp.mark("synthetic://1", "synthetic")
    cp.mark_error()
    cp.save()

    cp2 = Checkpoint(path)  # muat ulang
    assert cp2.total == 2
    assert cp2.has("synthetic://0")
    assert cp2.sources["synthetic"] == 2
    assert cp2.errors == 1


def test_preseed_synthetic_in_process(tmp_path):
    idx = tmp_path / "idx"
    cpt = tmp_path / "cp.json"
    rc = preseed.main([
        "--source", "synthetic", "--count", "40",
        "--in-process", "--index-dir", str(idx),
        "--checkpoint", str(cpt), "--save-every", "10",
    ])
    assert rc == 0
    data = json.loads(cpt.read_text())
    assert len(data["done"]) == 40
    assert data["sources"]["synthetic"] == 40


def test_preseed_resume_is_idempotent(tmp_path):
    idx = tmp_path / "idx"
    cpt = tmp_path / "cp.json"
    args = ["--source", "synthetic", "--count", "20", "--in-process",
            "--index-dir", str(idx), "--checkpoint", str(cpt)]
    assert preseed.main(args) == 0
    # Jalankan lagi target sama → tak ada tambahan (semua sudah ada).
    assert preseed.main(args) == 0
    data = json.loads(cpt.read_text())
    assert len(data["done"]) == 20

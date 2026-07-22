"""Test penulisan disclosure cakupan corpus."""

from __future__ import annotations

import corpus_coverage as C


def test_markdown_labels_and_totals():
    md = C.build_markdown(
        sources={"synthetic": 5000, "wikimedia:commons": 300},
        total=5300, errors=7,
    )
    assert "Total entri:** 5300" in md
    assert "BUKAN" in md and "seluruh internet" in md  # batas jujur wajib ada
    assert "Sintetis (bootstrap)" in md
    assert "Wikimedia Commons" in md
    assert "`synthetic`" in md and "`wikimedia:commons`" in md

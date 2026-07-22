"""Adegan kunci: tiap salinan korban WAJIB tertangkap NEAR_DUP (A2 acceptance)."""

from __future__ import annotations

import demo_fixtures as DF


def test_all_copies_caught():
    ok, total, fails = DF._run_verify()
    assert total >= 3 * 4  # ≥3 korban × 4 salinan
    assert ok == total, "salinan lolos deteksi:\n" + "\n".join(fails)


def test_victim_not_flagged_against_empty():
    # Sanity: korban pertama pada corpus kosong = ORIGINAL (bukan menuduh diri).
    import tempfile
    from pathlib import Path
    from lib.engine_client import in_process_client
    from lib.imagegen import victim_artwork
    import io

    def png(img):
        b = io.BytesIO(); img.convert("RGB").save(b, "PNG"); return b.getvalue()

    with tempfile.TemporaryDirectory() as d:
        eng = in_process_client(Path(d) / "idx")
        out = eng.query(png(victim_artwork(0)))
        assert out["verdict"] == "ORIGINAL"

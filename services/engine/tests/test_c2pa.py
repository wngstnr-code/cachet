"""Test pembaca C2PA — fallback JUMBF; gambar biasa harus c2pa_present=False."""

from __future__ import annotations

from app.c2pa_reader import read_c2pa

from .conftest import _base_image, to_bytes


def test_plain_png_has_no_c2pa():
    res = read_c2pa(to_bytes(_base_image(1)))
    assert res.c2pa_present is False
    assert res.synthid_checked is False  # MVP: selalu False, jujur
    assert "advisory" in res.notes


def test_jumbf_markers_detected_in_fallback():
    # Byte buatan berisi penanda JUMBF+c2pa → fallback melaporkan present.
    fake = b"\x00\x00\x00\x18jumb" + b"...c2pa..." + b"\x00" * 32
    res = read_c2pa(fake)
    assert res.c2pa_present is True

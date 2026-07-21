"""Pembaca deklarasi-AI C2PA (tier advisory, §F12).

MVP hanya MEMBACA keberadaan manifest, tidak memverifikasi rantai
kepercayaannya — dan itu ditulis jujur di README. synthid_checked SELALU false
(tidak dicek). Kalau library `c2pa` tersedia dipakai; kalau tidak, fallback
deteksi kotak JUMBF di byte file (C2PA membungkus manifest dalam JUMBF).
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class C2paResult:
    c2pa_present: bool
    synthid_checked: bool
    notes: str


# JUMBF: 'jumb' adalah tipe kotak ISO-BMFF pembungkus manifest C2PA. Penanda
# 'c2pa' muncul di dalam deskripsi kotak. Deteksi byte ini kasar tapi jujur:
# hanya mengklaim "ada manifest", bukan "manifest valid".
_JUMBF_MARKERS = (b"jumb", b"c2pa")


def _detect_jumbf(raw: bytes) -> bool:
    head = raw[: 512 * 1024]  # manifest ada di awal file; batasi pemindaian
    return all(m in head for m in _JUMBF_MARKERS)


def read_c2pa(raw: bytes) -> C2paResult:
    try:
        import c2pa  # noqa: WPS433 (opsional)

        present = False
        try:
            reader = c2pa.Reader.from_bytes  # API modern
        except AttributeError:
            reader = None

        if reader is not None:
            try:
                r = c2pa.Reader.from_bytes("image", raw)  # type: ignore[attr-defined]
                present = r.json() is not None
            except Exception:
                present = _detect_jumbf(raw)
        else:  # API lama read_bytes / read_file
            try:
                present = c2pa.read_bytes(raw) is not None  # type: ignore[attr-defined]
            except Exception:
                present = _detect_jumbf(raw)

        notes = "advisory only (c2pa lib: keberadaan manifest saja, rantai tak diverifikasi)"
        return C2paResult(c2pa_present=present, synthid_checked=False, notes=notes)
    except ImportError:
        present = _detect_jumbf(raw)
        notes = "advisory only (fallback: deteksi kotak JUMBF, tanpa lib c2pa)"
        return C2paResult(c2pa_present=present, synthid_checked=False, notes=notes)

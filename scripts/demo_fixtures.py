#!/usr/bin/env python3
"""Demo fixtures 'the catch' (A2.2) — adegan kunci video.

Menyiapkan 3–5 karya 'korban' + salinan yang dimodifikasi (resize/crop/JPEG/
recolor ringan), lalu MEMBUKTIKAN engine menangkap tiap salinan sebagai NEAR_DUP.

Modifikasi sengaja dipilih yang MEMANG kami jamin tertangkap (dalam radius pHash).
Kami tidak memamerkan transformasi yang lolos deteksi — itu false-negative, bukan
demo. Batas jujur ini konsisten dengan §5.2 & §7.

Perintah:
  python demo_fixtures.py generate   # materialkan korban + salinan ke scripts/demo/
  python demo_fixtures.py verify     # index korban, kueri salinan → assert NEAR_DUP

Kalau scripts/demo/originals/ berisi gambar NYATA (kamu taruh sendiri), itu dipakai
sebagai korban menggantikan yang sintetis — untuk demo yang lebih meyakinkan.
"""

from __future__ import annotations

import argparse
import io
import sys
from pathlib import Path

from PIL import Image, ImageEnhance

from lib.engine_client import in_process_client
from lib.imagegen import victim_artwork

_DEMO = Path(__file__).resolve().parent / "demo"
_ORIGINALS = _DEMO / "originals"      # gambar NYATA (opsional, kamu isi) — di-commit bila ada
_GEN = _DEMO / "generated"            # korban sintetis + salinan (di-ignore, reproducible)
_VICTIMS = _GEN / "victims"
_COPIES = _GEN / "copies"

_N_VICTIMS = 4


def _load_victims() -> list[tuple[str, Image.Image]]:
    reals = sorted([p for p in _ORIGINALS.glob("*") if p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}]) if _ORIGINALS.exists() else []
    if reals:
        return [(p.stem, Image.open(p).convert("RGB")) for p in reals]
    return [(f"victim{i}", victim_artwork(i)) for i in range(_N_VICTIMS)]


def _copies_of(img: Image.Image) -> dict[str, Image.Image]:
    """Transformasi 'salinan' yang harus tertangkap."""
    w, h = img.size
    dx, dy = w // 20, h // 20  # crop ~5%/sisi
    return {
        "resize60": img.resize((int(w * 0.6), int(h * 0.6)), Image.LANCZOS),
        "crop5pct": img.crop((dx, dy, w - dx, h - dy)),
        "recolor": ImageEnhance.Color(ImageEnhance.Brightness(img).enhance(1.15)).enhance(1.4),
        # 'jpeg40' dibuat saat menulis file / verify (butuh round-trip byte).
    }


def _jpeg(img: Image.Image, q: int = 40) -> Image.Image:
    b = io.BytesIO()
    img.convert("RGB").save(b, format="JPEG", quality=q)
    return Image.open(io.BytesIO(b.getvalue())).convert("RGB")


def _png_bytes(img: Image.Image) -> bytes:
    b = io.BytesIO()
    img.convert("RGB").save(b, format="PNG")
    return b.getvalue()


def cmd_generate() -> int:
    _VICTIMS.mkdir(parents=True, exist_ok=True)
    _COPIES.mkdir(parents=True, exist_ok=True)
    victims = _load_victims()
    for name, img in victims:
        img.convert("RGB").save(_VICTIMS / f"{name}.png")
        copies = _copies_of(img)
        for cname, cimg in copies.items():
            cimg.convert("RGB").save(_COPIES / f"{name}__{cname}.png")
        _jpeg(img).save(_COPIES / f"{name}__jpeg40.png")
    print(f"[demo] {len(victims)} korban → {_VICTIMS}")
    print(f"[demo] salinan → {_COPIES}")
    return 0


def _run_verify() -> tuple[int, int, list[str]]:
    import tempfile

    victims = _load_victims()
    with tempfile.TemporaryDirectory() as d:
        client = in_process_client(Path(d) / "idx")
        vid: dict[str, int] = {}
        for name, img in victims:
            res = client.index(_png_bytes(img), source="demo-victim", uri=f"demo://{name}")
            vid[name] = res["entry_id"]

        ok = 0
        total = 0
        fails: list[str] = []
        for name, img in victims:
            variants = dict(_copies_of(img))
            variants["jpeg40"] = _jpeg(img)
            for cname, cimg in variants.items():
                total += 1
                out = client.query(_png_bytes(cimg))
                caught = out["verdict"] == "NEAR_DUP" and out["first_seen"]["nearest_entry_id"] == vid[name]
                if caught:
                    ok += 1
                else:
                    fails.append(f"{name}/{cname}: verdict={out['verdict']} "
                                 f"nearest={out['first_seen']['nearest_entry_id']} "
                                 f"min_h={out['first_seen']['min_hamming']}")
        return ok, total, fails


def cmd_verify() -> int:
    ok, total, fails = _run_verify()
    print(f"[demo] the catch: {ok}/{total} salinan tertangkap NEAR_DUP")
    for f in fails:
        print(f"  MISS {f}", file=sys.stderr)
    return 0 if ok == total else 1


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Demo fixtures 'the catch'")
    p.add_argument("cmd", choices=["generate", "verify"])
    args = p.parse_args(argv)
    return cmd_generate() if args.cmd == "generate" else cmd_verify()


if __name__ == "__main__":
    raise SystemExit(main())

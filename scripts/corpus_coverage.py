#!/usr/bin/env python3
"""Tulis corpus-coverage.md (A2.3) — disclosure jujur cakupan registry.

Dibaca dari checkpoint preseed. Angka & sumber ini yang dipakai di README/listing
untuk klaim "dicek vs korpus kami" — WAJIB jujur: registry = korpus Cachet, BUKAN
seluruh internet (§7, §1.2), dan corpus sintetis diberi label sintetis.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path

_LABEL = {
    "synthetic": "Sintetis (bootstrap) — gambar dihasilkan program, BUKAN karya nyata",
    "wikimedia:commons": "Wikimedia Commons (media publik dunia-nyata)",
    "manifest": "Koleksi kurasi (daftar URL yang disiapkan)",
}


def build_markdown(sources: dict[str, int], total: int, errors: int) -> str:
    now = dt.date.today().isoformat()
    lines = [
        "# Cakupan Corpus Registry Cachet",
        "",
        f"> Dibuat otomatis dari checkpoint preseed pada {now}. Jangan edit tangan —",
        "> jalankan `python scripts/corpus_coverage.py`.",
        "",
        "**Batas jujur (wajib diakui, §7):** registry Cachet = **korpus kami**, BUKAN",
        "seluruh internet. \"First-seen\" berarti \"tak ada near-duplicate lebih tua **di",
        "registry ini** per timestamp T\" — bukan klaim keaslian global.",
        "",
        f"**Total entri:** {total}  ·  **gagal/dilewati saat ingest:** {errors}",
        "",
        "| Sumber | Entri | Keterangan |",
        "|---|---:|---|",
    ]
    for src, n in sorted(sources.items(), key=lambda kv: -kv[1]):
        lines.append(f"| `{src}` | {n} | {_LABEL.get(src, 'lainnya')} |")
    lines += [
        "",
        "## Catatan",
        "- Disimpan sebagai **hash + embedding + URI**, bukan file gambar (non-reversibel).",
        "- Corpus **sintetis** hanya bootstrap volume; ia TIDAK membuat klaim menangkap",
        "  copymint dunia-nyata. Yang menangkap salinan nyata adalah entri dunia-nyata",
        "  (Wikimedia/manifest) + fixture demo 'the catch'.",
        "- Embedding bersifat **advisory**; sampai CLIP di-wire (A5), embedding corpus",
        "  hasil preseed in-process adalah placeholder — tier pHash (yang dijamin) tetap valid.",
    ]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--checkpoint", default="data/preseed.checkpoint.json")
    p.add_argument("--out", default="scripts/corpus-coverage.md")
    args = p.parse_args(argv)

    cp = Path(args.checkpoint)
    if not cp.exists():
        raise SystemExit(f"checkpoint tak ada: {cp} — jalankan preseed dulu")
    data = json.loads(cp.read_text())
    md = build_markdown(
        sources=data.get("sources", {}),
        total=len(data.get("done", [])),
        errors=int(data.get("errors", 0)),
    )
    Path(args.out).write_text(md)
    print(f"[coverage] ditulis {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

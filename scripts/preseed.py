#!/usr/bin/env python3
"""Preseed corpus Cachet (A2.1).

Meng-ingest gambar publik ke registry engine — menyimpan HANYA hash+embedding+URI
(bukan file). Tujuan: "tak ada near-duplicate" bermakna sejak hari-1, dan menangkap
copymint nyata saat demo.

Contoh:
  # Bootstrap sintetis cepat (offline), in-process:
  python preseed.py --source synthetic --count 5000 --in-process --index-dir data/index

  # Gambar dunia-nyata dari Wikimedia ke engine yang sedang berjalan:
  python preseed.py --source wikimedia --count 3000 --engine http://localhost:8100

  # Koleksi kurasi (daftar URL) via engine berjalan:
  python preseed.py --source manifest --file collection.json --engine http://localhost:8100

Aman diulang: checkpoint melewati kunci yang sudah diproses (resume).
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

from lib.checkpoint import Checkpoint
from lib.engine_client import http_client, in_process_client
from lib import sources as S


def _build_source(args, skip: set[str]):
    if args.source == "synthetic":
        return S.synthetic_source(args.count, skip)
    if args.source == "wikimedia":
        return S.wikimedia_source(args.count, skip)
    if args.source == "manifest":
        entries = json.loads(Path(args.file).read_text())
        return S.manifest_source(entries, skip)
    raise SystemExit(f"sumber tak dikenal: {args.source}")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Preseed corpus Cachet")
    p.add_argument("--source", required=True, choices=["synthetic", "wikimedia", "manifest"])
    p.add_argument("--count", type=int, default=5000, help="target entri (synthetic/wikimedia)")
    p.add_argument("--file", help="manifest JSON [{url,source?,uri?}] untuk --source manifest")
    grp = p.add_mutually_exclusive_group()
    grp.add_argument("--engine", help="URL engine berjalan (mis. http://localhost:8100)")
    grp.add_argument("--in-process", action="store_true", help="jalankan engine in-process (fake embedder)")
    p.add_argument("--index-dir", default="data/index", help="dir SQLite untuk --in-process")
    p.add_argument("--checkpoint", default="data/preseed.checkpoint.json")
    p.add_argument("--save-every", type=int, default=200)
    args = p.parse_args(argv)

    ckpt = Checkpoint(Path(args.checkpoint))
    if args.in_process or not args.engine:
        client = in_process_client(Path(args.index_dir))
        where = f"in-process ({args.index_dir})"
    else:
        client = http_client(args.engine)
        where = args.engine

    print(f"[preseed] sumber={args.source} target={args.count} → {where}")
    print(f"[preseed] checkpoint={args.checkpoint} sudah-ada={ckpt.total}")

    started = time.time()
    added = 0
    for item in _build_source(args, ckpt.done):
        try:
            client.index(item.raw, source=item.source, uri=item.uri)
            ckpt.mark(item.key, item.source)
            added += 1
        except Exception as exc:  # noqa: BLE001
            ckpt.mark_error()
            print(f"[preseed] SKIP {item.key}: {exc}", file=sys.stderr)
        if added % args.save_every == 0 and added:
            ckpt.save()
            rate = added / max(1e-6, time.time() - started)
            print(f"[preseed] +{added} (total {ckpt.total}, {rate:.0f}/s, err {ckpt.errors})")

    ckpt.save()
    dur = time.time() - started
    print(f"[preseed] SELESAI: +{added} entri dalam {dur:.1f}s (total corpus {ckpt.total}, error {ckpt.errors})")
    print(f"[preseed] per-sumber: {ckpt.sources}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

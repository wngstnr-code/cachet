"""Checkpoint preseed — ramah rate-limit & bisa dilanjut.

Menyimpan kunci yang sudah diproses + hitungan per-sumber ke JSON. Kalau proses
mati di tengah (RPC/API putus), jalankan lagi → kunci yang sudah ada dilewati.
"""

from __future__ import annotations

import json
from pathlib import Path


class Checkpoint:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.done: set[str] = set()
        self.sources: dict[str, int] = {}
        self.errors: int = 0
        self._load()

    def _load(self) -> None:
        if self.path.exists():
            data = json.loads(self.path.read_text())
            self.done = set(data.get("done", []))
            self.sources = dict(data.get("sources", {}))
            self.errors = int(data.get("errors", 0))

    def has(self, key: str) -> bool:
        return key in self.done

    def mark(self, key: str, source: str) -> None:
        if key in self.done:
            return
        self.done.add(key)
        self.sources[source] = self.sources.get(source, 0) + 1

    def mark_error(self) -> None:
        self.errors += 1

    @property
    def total(self) -> int:
        return len(self.done)

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(self.path.suffix + ".tmp")
        tmp.write_text(json.dumps({
            "done": sorted(self.done),
            "sources": self.sources,
            "errors": self.errors,
        }))
        tmp.replace(self.path)  # tulis-atomik: tak ada checkpoint korup separuh

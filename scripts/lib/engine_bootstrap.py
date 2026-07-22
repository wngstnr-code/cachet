"""Buat modul engine (`app.*`) bisa di-import dari scripts.

scripts/ dan services/engine/ bersaudara di monorepo; keduanya milik Person A.
Skrip preseed memakai ulang venv + paket engine alih-alih menduplikasi logika
hashing. Ini menyisipkan services/engine ke sys.path bila belum ada.
"""

from __future__ import annotations

import sys
from pathlib import Path

_ENGINE_DIR = Path(__file__).resolve().parents[2] / "services" / "engine"


def ensure_engine_on_path() -> Path:
    p = str(_ENGINE_DIR)
    if p not in sys.path:
        sys.path.insert(0, p)
    return _ENGINE_DIR

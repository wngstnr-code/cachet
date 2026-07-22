"""Fixture test scripts — engine in-process (fake embedder), tanpa jaringan."""

from __future__ import annotations

import sys
from pathlib import Path

# scripts/ ada di path supaya `import lib...` dan `import preseed` jalan.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest  # noqa: E402

from lib.engine_client import in_process_client  # noqa: E402


@pytest.fixture
def engine(tmp_path):
    return in_process_client(tmp_path / "idx")

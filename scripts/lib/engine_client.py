"""Klien engine — satu bentuk (HTTP §3.3) untuk server nyata maupun in-process.

`EngineHttp` menerima objek apa pun ber-antarmuka httpx (`httpx.Client` untuk
engine yang berjalan di ENGINE_URL, atau FastAPI `TestClient` untuk in-process).
Preseed & demo verify tidak peduli yang mana — cukup index()/query()/count().
"""

from __future__ import annotations

import base64
from pathlib import Path
from typing import Any


def _b64(raw: bytes) -> str:
    return base64.b64encode(raw).decode()


class EngineHttp:
    def __init__(self, http: Any) -> None:
        # http: httpx.Client(base_url=...) ATAU fastapi.testclient.TestClient(app)
        self._http = http

    def index(self, raw: bytes, source: str | None = None, uri: str | None = None) -> dict:
        r = self._http.post("/index", json={"image_b64": _b64(raw), "source": source, "uri": uri})
        r.raise_for_status()
        return r.json()

    def query(self, raw: bytes) -> dict:
        r = self._http.post("/query", json={"image_b64": _b64(raw)})
        r.raise_for_status()
        return r.json()

    def count(self) -> int:
        r = self._http.get("/healthz")
        r.raise_for_status()
        return int(r.json()["entries"])


def http_client(base_url: str, timeout: float = 60.0) -> EngineHttp:
    import httpx

    return EngineHttp(httpx.Client(base_url=base_url, timeout=timeout))


def in_process_client(index_dir: Path, embedder_kind: str = "fake") -> EngineHttp:
    """Engine in-process (tanpa server) untuk preseed lokal cepat & test.

    embedder_kind='fake' default: embedding corpus jadi placeholder sampai CLIP
    di-wire (A5). Tier pHash (yang menangkap salinan) tidak bergantung embedding,
    jadi 'the catch' tetap valid.
    """
    from .engine_bootstrap import ensure_engine_on_path

    ensure_engine_on_path()
    from fastapi.testclient import TestClient
    from app.config import Settings
    from app.embedding import build_embedder
    from app.main import create_app
    from app.store import EngineStore

    settings = Settings(port=8100, index_dir=index_dir, embedder_kind=embedder_kind)
    app = create_app(
        settings=settings,
        store=EngineStore(settings.db_path),
        embedder=build_embedder(embedder_kind),
    )
    return EngineHttp(TestClient(app))

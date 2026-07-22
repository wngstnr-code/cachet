"""Factory create_app + entry point uvicorn.

create_app menerima store & embedder opsional → test menyuntik yang in-memory/
fake; produksi memakai default dari .env (SQLite + open_clip).

SENGAJA tanpa `app = create_app()` di level modul: itu akan memicu pemuatan
open_clip saat modul di-import (termasuk oleh test tanpa torch). Uvicorn memakai
mode factory (`--factory`) sehingga app baru dibuat saat server start, bukan saat
import.
"""

from __future__ import annotations

from fastapi import FastAPI

from . import __version__
from .config import Settings, load_settings
from .embedding import Embedder, build_embedder
from .routes import router
from .service import OriginalityService
from .store import EngineStore


def create_app(
    settings: Settings | None = None,
    store: EngineStore | None = None,
    embedder: Embedder | None = None,
) -> FastAPI:
    settings = settings or load_settings()
    store = store or EngineStore(settings.db_path)
    embedder = embedder or build_embedder(settings.embedder_kind)

    app = FastAPI(title="Cachet Originality Engine", version=__version__)
    app.state.settings = settings
    app.state.store = store
    app.state.service = OriginalityService(store, embedder)
    app.include_router(router)
    return app


def run() -> None:
    import uvicorn

    settings = load_settings()
    uvicorn.run("app.main:create_app", host="0.0.0.0", port=settings.port, factory=True)


if __name__ == "__main__":
    run()

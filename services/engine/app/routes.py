"""Endpoint HTTP internal engine (§4-A1.1): /hash /index /query + /healthz.

Service diambil dari app.state supaya test bisa menyuntik store sementara +
FakeEmbedder tanpa menyentuh disk atau torch.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

from .schemas import HashOut, ImageIn, IndexIn, IndexOut, QueryOut
from .service import OriginalityService

router = APIRouter()


def _svc(request: Request) -> OriginalityService:
    return request.app.state.service


@router.get("/healthz")
def healthz(request: Request) -> dict:
    return {"status": "ok", "entries": request.app.state.store.count()}


@router.post("/hash", response_model=HashOut)
def hash_image(body: ImageIn, request: Request) -> HashOut:
    try:
        return HashOut(**_svc(request).hash(body.image_b64))
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.post("/index", response_model=IndexOut)
def index_image(body: IndexIn, request: Request) -> IndexOut:
    try:
        return IndexOut(**_svc(request).index(body.image_b64, body.source, body.uri))
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.post("/query", response_model=QueryOut)
def query_image(body: ImageIn, request: Request) -> QueryOut:
    try:
        return QueryOut(**_svc(request).query(body.image_b64))
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

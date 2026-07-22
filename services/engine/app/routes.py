"""Endpoint HTTP internal engine (§4-A1.1): /hash /index /query + /healthz.

Service diambil dari app.state supaya test bisa menyuntik store sementara +
FakeEmbedder tanpa menyentuh disk atau torch.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

from .hashing import hex_to_phash
from .schemas import HashOut, ImageIn, IndexIn, IndexOut, NeardupsIn, NeardupsOut, QueryOut
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


@router.post("/neardups", response_model=NeardupsOut)
def neardups(body: NeardupsIn, request: Request) -> NeardupsOut:
    store = request.app.state.store
    if body.phashes is not None:
        if len(body.phashes) != 4:
            raise HTTPException(status_code=422, detail="phashes harus 4")
        query = [hex_to_phash(h) for h in body.phashes]
        exclude = body.exclude_entry_id
    elif body.entry_id is not None:
        query = store.get_entry_phashes(body.entry_id)
        if query is None:
            raise HTTPException(status_code=404, detail=f"entry_id {body.entry_id} tak ada")
        exclude = body.exclude_entry_id if body.exclude_entry_id is not None else body.entry_id
    else:
        raise HTTPException(status_code=422, detail="wajib phashes atau entry_id")

    matches = store.neardups_since(query, body.since_entry_id, exclude)
    return NeardupsOut(matches=matches, corpus_size=store.count())

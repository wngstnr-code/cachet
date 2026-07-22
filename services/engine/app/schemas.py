"""Skema request/response endpoint internal engine.

Ini API INTERNAL A (engine ↔ gateway), bukan Originality Profile publik §3.2.
Gateway (A3) menggabungkan hasil /query dengan premium_quote + signed + wrapper
menjadi profil §3.2. Bidang di sini sengaja dekat dengan §3.2 agar penggabungan
di gateway tinggal salin.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class ImageIn(BaseModel):
    image_b64: str = Field(..., description="Byte gambar mentah, base64. Gateway yang mengurus URL/fetch.")


class IndexIn(ImageIn):
    source: str | None = Field(None, description="Asal entri, mis. 'preseed:opensea' atau 'cachet-mint'.")
    uri: str | None = Field(None, description="URI aset / referensi on-chain (certId, assetURI).")


class HashOut(BaseModel):
    asset_sha256: str
    phashes: list[str]
    embedding_commit: str


class IndexOut(BaseModel):
    entry_id: int
    asset_sha256: str


class FirstSeenOut(BaseModel):
    is_first: bool
    nearest_entry_id: int | None
    min_hamming: int
    hashes_matched: int


class DistinctivenessOut(BaseModel):
    score: float
    nearest_cosine: float
    label: str


class AiDeclarationOut(BaseModel):
    c2pa_present: bool
    synthid_checked: bool
    notes: str


class QueryOut(BaseModel):
    """Bagian analisis orisinalitas dari profil §3.2 (tanpa premi/signature)."""

    asset_sha256: str
    verdict: str
    first_seen: FirstSeenOut
    distinctiveness: DistinctivenessOut
    ai_declaration: AiDeclarationOut
    insurable: bool
    phashes: list[str]
    embedding_commit: str


class NeardupsIn(BaseModel):
    """Cari near-dup sebuah fingerprint di antara entri > since_entry_id (Watch)."""

    phashes: list[str] | None = Field(None, description="4 pHash hex; ATAU pakai entry_id")
    entry_id: int | None = Field(None, description="Ambil fingerprint dari entri ini (dikecualikan dari hasil)")
    since_entry_id: int = Field(0, description="Hanya entri dengan id > ini")
    exclude_entry_id: int | None = None


class NeardupMatch(BaseModel):
    entry_id: int
    matched: int
    min_hamming: int
    source: str | None = None
    uri: str | None = None
    registered_at: int | None = None


class NeardupsOut(BaseModel):
    matches: list[NeardupMatch]
    corpus_size: int

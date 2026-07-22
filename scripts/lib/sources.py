"""Sumber gambar untuk preseed → aliran Item(raw, key, source, uri).

Tiga sumber:
- synthetic : corpus bootstrap sintetis (offline, cepat, jujur di disclosure).
- wikimedia : Wikimedia Commons (publik, tanpa auth) — gambar dunia-nyata.
- manifest  : file JSON [{"url","source"?,"uri"?}, ...] untuk koleksi kurasi
              (mis. daftar URL IPFS/marketplace yang Dien siapkan).

Tiap sumber MELEWATI kunci yang sudah ada di `skip` sebelum mengunduh — jadi
resume tidak mengunduh ulang. `key` harus stabil per gambar.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Iterator

from .imagegen import synthetic_corpus_image, to_png

_MAX_BYTES = 12 * 1024 * 1024  # lewati file raksasa
_UA = "CachetPreseed/0.1 (hackathon; contact dienmsk030406@gmail.com)"


@dataclass(frozen=True)
class Item:
    raw: bytes
    key: str
    source: str
    uri: str


# ── synthetic ────────────────────────────────────────────────────────────────

def synthetic_source(count: int, skip: set[str]) -> Iterator[Item]:
    for i in range(count):
        key = f"synthetic://{i}"
        if key in skip:
            continue
        yield Item(raw=to_png(synthetic_corpus_image(i)), key=key, source="synthetic", uri=key)


# ── wikimedia commons ────────────────────────────────────────────────────────

def _api(session, params: dict) -> dict:
    r = session.get(
        "https://commons.wikimedia.org/w/api.php",
        params={"format": "json", **params},
        headers={"User-Agent": _UA},
        timeout=30,
    )
    r.raise_for_status()
    return r.json()


def _random_image_titles(session, batch: int) -> list[str]:
    data = _api(session, {
        "action": "query", "list": "random",
        "rnnamespace": 6, "rnlimit": min(batch, 20),
    })
    return [x["title"] for x in data.get("query", {}).get("random", [])]


def _image_url(session, title: str) -> str | None:
    data = _api(session, {
        "action": "query", "titles": title,
        "prop": "imageinfo", "iiprop": "url|mime|size",
    })
    pages = data.get("query", {}).get("pages", {})
    for _, page in pages.items():
        info = (page.get("imageinfo") or [{}])[0]
        mime = info.get("mime", "")
        size = info.get("size", 0) or 0
        if mime.startswith("image/") and mime not in ("image/svg+xml",) and size <= _MAX_BYTES:
            return info.get("url")
    return None


def wikimedia_source(count: int, skip: set[str]) -> Iterator[Item]:
    import requests

    session = requests.Session()
    got = 0
    guard = 0  # batasi putaran supaya tak berputar selamanya bila banyak yang dilewati
    while got < count and guard < count * 5 + 50:
        for title in _random_image_titles(session, batch=20):
            guard += 1
            if got >= count:
                break
            key = f"wikimedia:{title}"
            if key in skip:
                continue
            try:
                url = _image_url(session, title)
                if not url:
                    continue
                resp = session.get(url, headers={"User-Agent": _UA}, timeout=30)
                resp.raise_for_status()
                raw = resp.content
                if len(raw) > _MAX_BYTES:
                    continue
                yield Item(raw=raw, key=key, source="wikimedia:commons", uri=url)
                got += 1
            except Exception:
                continue


# ── manifest ─────────────────────────────────────────────────────────────────

def manifest_source(entries: Iterable[dict], skip: set[str]) -> Iterator[Item]:
    import requests

    session = requests.Session()
    for e in entries:
        url = e["url"]
        key = f"manifest:{url}"
        if key in skip:
            continue
        try:
            resp = session.get(url, headers={"User-Agent": _UA}, timeout=30)
            resp.raise_for_status()
            raw = resp.content
            if len(raw) > _MAX_BYTES:
                continue
            yield Item(raw=raw, key=key, source=e.get("source", "manifest"), uri=e.get("uri", url))
        except Exception:
            continue

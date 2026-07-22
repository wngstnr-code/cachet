"""Test primitif Watch: /neardups menemukan salinan yang MASUK setelah since_id."""

from __future__ import annotations

from PIL import Image

from .conftest import _base_image, _other_image, to_b64


def _index(client, img, **kw):
    return client.post("/index", json={"image_b64": to_b64(img, **kw)}).json()["entry_id"]


def test_neardups_only_returns_newer_copies(client):
    watched = _index(client, _base_image(1))          # entry 1 = aset diawasi
    _index(client, _other_image())                    # entry 2 = beda, bukan salinan
    since = client.get("/healthz").json()["entries"]  # snapshot: 2

    # Salinan aset diawasi masuk SETELAH snapshot (mis. via preseed re-scan).
    copy_id = _index(client, _base_image(1).resize((256, 256), Image.LANCZOS))

    r = client.post("/neardups", json={"entry_id": watched, "since_entry_id": since})
    assert r.status_code == 200
    matches = r.json()["matches"]
    ids = [m["entry_id"] for m in matches]
    assert copy_id in ids            # salinan baru tertangkap
    assert watched not in ids        # aset itu sendiri dikecualikan
    assert 2 not in ids              # entri beda tak masuk


def test_neardups_by_phashes(client):
    eid = _index(client, _base_image(3))
    ph = client.post("/hash", json={"image_b64": to_b64(_base_image(3))}).json()["phashes"]
    # since 0, tanpa exclude → aset itu sendiri cocok (hamming 0)
    r = client.post("/neardups", json={"phashes": ph, "since_entry_id": 0})
    ids = [m["entry_id"] for m in r.json()["matches"]]
    assert eid in ids


def test_neardups_empty_when_nothing_new(client):
    watched = _index(client, _base_image(1))
    since = client.get("/healthz").json()["entries"]
    r = client.post("/neardups", json={"entry_id": watched, "since_entry_id": since})
    assert r.json()["matches"] == []


def test_neardups_unknown_entry_404(client):
    r = client.post("/neardups", json={"entry_id": 999, "since_entry_id": 0})
    assert r.status_code == 404

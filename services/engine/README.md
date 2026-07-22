# Cachet Originality Engine (A1)

Layanan off-chain **murni-konten** milik Person A: hashing perceptual (ensemble
×4), embedding (advisory), index, dan logika verdict *first-seen*. Tidak menyentuh
chain — orkestrasi on-chain adalah tugas gateway (A3).

Spec mengikat: `docs/technical_implementation_plan.md` §1.3 (parameter) & §4-A1.
Skema output (§3.2) diproduksi gateway dengan menggabungkan hasil `/query` di sini.

## Apa yang dijamin vs advisory (jujur — §5.2)

| Sinyal | Sifat | Status |
|---|---|---|
| Ensemble 4 pHash (near-duplicate) | deterministik, bisa di-re-run siapa pun | **klaim keras** |
| Embedding (distinctiveness, gray-zone) | probabilistik | **advisory** |
| C2PA present | pembacaan keberadaan manifest, rantai TIDAK diverifikasi | **advisory** |

`verdict`: `ORIGINAL` · `NEAR_DUP` (≥2 dari 4 hash Hamming ≤25) · `GRAY_ZONE`
(cosine ∈ [0.90, 0.97], tidak insurable). NEAR_DUP menang atas GRAY_ZONE.

## Arsitektur — kenapa embedding & index di belakang interface

Tier deterministik (pHash) adalah klaim keras yang WAJIB berdiri sendiri, jadi
open_clip & FAISS ditaruh di belakang `Protocol` yang bisa di-swap:

- **Embedder**: `ClipEmbedder` (produksi, open_clip ViT-B/32) atau `FakeEmbedder`
  (deterministik, untuk test & jalan tanpa torch).
- **VectorIndex**: `FaissIndex` (bila `faiss` ada) atau `NumpyIndex` (fallback,
  brute-force cosine — setara untuk ≤100k entri).

Akibatnya seluruh logika inti + test berjalan **tanpa torch/faiss/c2pa**. Ini
disengaja: wheel ML untuk Python 3.13 belum stabil (lihat `requirements-ml.txt`).

## Jalankan

```bash
python3.13 -m venv .venv
./.venv/bin/pip install -r requirements.txt   # deps INTI — cukup untuk test + dev
./.venv/bin/python -m pytest                  # 29 test, hijau tanpa ML

# Dev server tanpa torch (embedding fake):
ENGINE_EMBEDDER=fake ./.venv/bin/python -m app.main      # → http://localhost:8100

# Produksi (embedding CLIP nyata) — butuh requirements-ml.txt (lihat catatan
# py3.13 di file itu; kemungkinan perlu Python 3.12):
./.venv/bin/pip install -r requirements-ml.txt
./.venv/bin/python -m app.main                # ENGINE_EMBEDDER default "clip"
```

Konfigurasi via `.env` root (`load_dotenv(find_dotenv())`): `ENGINE_PORT` (8100),
`INDEX_PATH` (`./data/index` → SQLite `engine.db`), `ENGINE_EMBEDDER` (`clip`|`fake`).

## Endpoint (internal A — engine ↔ gateway)

| Method | Guna | In | Out |
|---|---|---|---|
| `POST /hash` | fingerprint murah (dipakai commit flow) | `{image_b64}` | `{asset_sha256, phashes[4], embedding_commit}` |
| `POST /index` | tambah entri ke corpus | `{image_b64, source?, uri?}` | `{entry_id, asset_sha256}` |
| `POST /query` | verify vs corpus (read-only) | `{image_b64}` | bagian analisis §3.2 (verdict, first_seen, distinctiveness, ai_declaration, insurable, phashes, embedding_commit) |
| `GET /healthz` | liveness + jumlah entri | — | `{status, entries}` |

`image_b64` = byte gambar mentah ter-base64. Gateway yang mengurus URL/fetch —
engine sengaja tidak menjangkau jaringan (hindari SSRF, jaga kemurnian).

## Catatan integrasi penting

- **`asset_sha256`** dari byte file **mentah**; **pHash & embedding** dari gambar
  **ternormalisasi** (RGB, resize sisi-panjang 512, alpha di-drop). Jangan campur.
- **`embedding_commit = keccak256(vektor float32 bytes)`** (keccak Ethereum, bukan
  sha3). Ini yang jadi `embCommit` on-chain.
- **`entry_id` di sini = id CORPUS engine** (auto-increment), **BUKAN entryId
  on-chain**. Corpus = pre-seed + semua yang di-mint; registry on-chain hanya yang
  bersertifikat. `nearest_entry_id` (§3.2) menunjuk id corpus ini.
- **Urutan hash dikunci**: `phashes[0]` = `phash` (imagehash) = `phash0` untuk
  rumus commit-reveal on-chain. Jangan ubah urutan tanpa menyepakati §3.

## Test

29 test (pytest), semuanya tanpa ML:
- `test_verdict.py` — logika verdict murni (batas gray-zone, NEAR_DUP > GRAY_ZONE, corpus kosong).
- `test_hashing.py` — bentuk 4×256-bit, determinisme, Hamming.
- `test_store.py` — persistensi SQLite + rebuild in-memory + kueri pHash/embedding.
- `test_api.py` — **the catch** §4-A1.7: identik/resize/crop~10%/JPEG q30/grayscale → NEAR_DUP; beda → ORIGINAL; embedding di pita → GRAY_ZONE.
- `test_c2pa.py` — fallback JUMBF; gambar biasa → `c2pa_present=false`.

> Catatan fixture: "crop 10%" diuji sebagai 5% tiap sisi (≈10% per dimensi).
> Membuang 10% TIAP sisi (20% per dimensi, 36% area) di luar toleransi pHash
> 256-bit — dibuktikan lewat diagnostik saat menyetel fixture, bukan asumsi.

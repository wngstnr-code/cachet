# scripts — Preseed corpus & demo fixtures (A2)

Utilitas Person A untuk **mengisi registry** (supaya "tak ada near-duplicate"
bermakna sejak hari-1) dan menyiapkan **adegan "the catch"** untuk video demo.

Spec: `docs/technical_implementation_plan.md` §4-A2. Bergantung pada engine A1
(`services/engine`) — dipakai ulang, bukan diduplikasi (`lib/engine_bootstrap.py`).

## Setup (pakai ulang venv engine)

```bash
# dari repo root
source services/engine/.venv/bin/activate
pip install -r scripts/requirements.txt          # hanya menambah `requests`
```

Engine sudah menyediakan Pillow/numpy/imagehash/fastapi/httpx. Untuk embedding
CLIP nyata butuh `requirements-ml.txt` engine (lihat catatan py3.13 di sana);
tanpa itu preseed & demo tetap jalan dengan embedding placeholder — tier pHash
(yang menangkap salinan) tidak bergantung embedding.

## 1. Preseed corpus — `preseed.py`

Ingest gambar → simpan **hanya hash + embedding + URI** (bukan file). Aman diulang
(checkpoint melewati yang sudah ada).

```bash
# Bootstrap sintetis cepat, offline, engine in-process:
python scripts/preseed.py --source synthetic --count 5000 \
    --in-process --index-dir data/index --checkpoint data/preseed.checkpoint.json

# Gambar dunia-nyata dari Wikimedia Commons (butuh network), ke engine berjalan:
python scripts/preseed.py --source wikimedia --count 3000 --engine http://localhost:8100

# Koleksi kurasi (daftar URL IPFS/marketplace yang kamu siapkan):
python scripts/preseed.py --source manifest --file collection.json --engine http://localhost:8100
```

Sumber: `synthetic` (bootstrap volume, offline) · `wikimedia` (publik, tanpa auth)
· `manifest` (JSON `[{"url","source"?,"uri"?}]`). `--engine URL` untuk engine yang
berjalan, atau `--in-process` untuk index langsung tanpa server.

**Terverifikasi (22 Jul):** 5.000 sintetis ter-index dalam ~40 dtk (~125/dtk);
query pada corpus 5k = **241 ms** (< 2 dtk); 12 gambar Wikimedia nyata ter-ingest
via network, 0 error.

## 2. Demo fixtures "the catch" — `demo_fixtures.py`

```bash
python scripts/demo_fixtures.py generate   # materialkan korban + salinan ke scripts/demo/
python scripts/demo_fixtures.py verify     # index korban, kueri salinan → NEAR_DUP
```

Korban = 4 karya (seed **terkurasi** agar tahan crop & saling non-near-dup) atau,
bila kamu taruh gambar NYATA di `scripts/demo/originals/`, itu yang dipakai. Salinan
= resize / crop ~5% / recolor ringan / JPEG q40 — transformasi yang **memang kami
jamin tertangkap**. Kami tidak memamerkan modifikasi yang lolos deteksi (itu
false-negative, bukan demo) — batas jujur §5.2/§7.

## 3. Disclosure cakupan — `corpus_coverage.py`

```bash
python scripts/corpus_coverage.py --checkpoint data/preseed.checkpoint.json \
    --out scripts/corpus-coverage.md
```

Menulis rincian jujur per-sumber untuk README/listing: registry = **korpus kami,
BUKAN seluruh internet**; corpus sintetis diberi label sintetis.

## Test

```bash
cd scripts && ../services/engine/.venv/bin/python -m pytest
```

7 test, tanpa jaringan: the catch (semua salinan tertangkap), checkpoint/resume,
sumber sintetis skip-done, preseed idempoten, disclosure coverage.

## Catatan seed terkurasi

`lib/imagegen.py` `_VICTIM_SEEDS` dipilih lewat scan (bukan acak): tiap korban
tahan crop 5%/sisi dengan margin (≥2 hash Hamming ≤20) DAN saling non-near-dup —
supaya `demo verify` stabil, bukan kebetulan. Generator acak murni sesekali
menghasilkan komposisi rapuh-crop; kurasi menghilangkan flakiness itu.

# Deploy Cachet on the shared SimpleArt OVHcloud VPS

Runbook ini men-deploy **engine + gateway saja** ke VPS production yang sudah
melayani `simpleartch.com` (2 vCore, 4 GB RAM, 40 GB NVMe). SimpleArt selalu
menjadi workload prioritas.

Desain yang disetujui: [`2026-07-22-ovh-shared-vps-design.md`](./2026-07-22-ovh-shared-vps-design.md).

## Kebijakan availability

- Deploy Cachet tidak memiliki planned downtime untuk SimpleArt.
- Sebelum blue-green deploy SimpleArt, Cachet dihentikan sementara dengan
  `cachetctl pause`, lalu dinyalakan kembali dengan `cachetctl resume`.
- Reboot atau kegagalan VPS tetap memengaruhi keduanya karena satu host.

## Artifact

| File | Fungsi |
|---|---|
| `compose.ovh.yml` | Compose production prebuilt-image, resource limit, bind mount |
| `ovh.runtime.env.example` | Daftar runtime variable tanpa secret |
| `ovh.deploy.env.example` | Template immutable image tag dan path VPS |
| `Caddyfile.shared-ovh` | Kandidat lengkap Caddy SimpleArt + Cachet |
| `Caddyfile.cachet` | Site block Cachet untuk referensi/diff |
| `build-ovh-images.sh` | Build `linux/amd64` di Mac/CI dan push ke GHCR |
| `cachetctl.sh` | Preflight, backup, deploy, pause/resume, rollback, smoke |

`docker-compose.yml` lama tetap tersedia untuk development/rehearsal lokal dan
tidak dipakai pada VPS shared production.

## Keputusan CLIP — jangan dilewati

Deployment ini **tidak memasang CLIP**:

```text
WITH_ML=0
ENGINE_EMBEDDER=fake
```

Tier empat pHash deterministik tetap aktif. Embedding bukan sinyal similarity
production dan tetap harus disebut **advisory**.

Sebelum mengaktifkan CLIP, lakukan salah satu:

1. upgrade VPS shared ke minimal sekitar **4 vCore / 8 GB RAM**; atau
2. pindahkan Cachet ke host terpisah dengan kapasitas setara atau lebih besar.

Setelah itu baru build `WITH_ML=1`, set `ENGINE_EMBEDDER=clip`, dan benchmark RAM,
startup, serta latency. Mengubah env saja pada image saat ini tidak memasang CLIP.

## Fase 1 — Cloudflare untuk `cachetprotocol.xyz`

Cloudflare R2 **tidak digunakan**. Yang digunakan adalah DNS, proxy, dan SSL/TLS.

1. Cloudflare Dashboard → **Add a domain** → `cachetprotocol.xyz` → Free plan.
2. Di Dynadot, ganti nameserver domain dengan dua nameserver yang diberikan
   Cloudflare. Tunggu zone berstatus Active.
3. Tambahkan record:
   - Type: `A`
   - Name: `api`
   - Content: public IPv4 OVHcloud VPS
   - Proxy status: **Proxied**
4. Cloudflare → SSL/TLS → Overview → pilih **Full (strict)**.
5. Cloudflare → SSL/TLS → Origin Server → buat Origin CA certificate khusus:
   - `api.cachetprotocol.xyz`
   - RSA 2048 atau ECC
6. Simpan certificate dan private key melalui kanal administratif aman. Jangan
   menaruhnya di Git, chat, image, atau build argument.

Catatan keamanan yang ditemukan saat audit: worktree SimpleArt berisi
`origin.key` yang terlacak Git dan bermode `0644`. Anggap key tersebut terekspos,
rotate certificate SimpleArt di Cloudflare, keluarkan key dari repository/history,
dan pasang key pengganti hanya di VPS. Pekerjaan Cachet tidak mengubah repository
SimpleArt secara otomatis.

## Fase 2 — Build image di luar VPS

Pastikan perubahan sudah di-commit. Untracked file boleh tetap ada karena script
memastikan seluruh tracked/staged build input bersih.

Login GHCR dengan token berizin `write:packages`:

```bash
docker login ghcr.io -u scientivan
```

Lalu dari root repository Cachet:

```bash
scripts/deploy/build-ovh-images.sh
```

Script selalu membangun `linux/amd64`, memaksa `WITH_ML=0`, men-tag kedua image
dengan full Git SHA yang sama, lalu push ke:

```text
ghcr.io/scientivan/cachet-engine:sha-...
ghcr.io/scientivan/cachet-gateway:sha-...
```

Jangan memakai `latest`.

## Fase 3 — Salin artifact ke VPS

Dari Mac, buat bundle tanpa secret:

```bash
tar -czf /tmp/cachet-ovh-deploy.tar.gz \
  scripts/deploy/compose.ovh.yml \
  scripts/deploy/ovh.runtime.env.example \
  scripts/deploy/ovh.deploy.env.example \
  scripts/deploy/Caddyfile.shared-ovh \
  scripts/deploy/cachetctl.sh

scp /tmp/cachet-ovh-deploy.tar.gz ubuntu@VPS_IP:/tmp/
```

`VPS_IP` hanya diganti pada command lokal; jangan commit nilainya.

Di VPS:

```bash
mkdir -p /tmp/cachet-ovh-deploy
tar -xzf /tmp/cachet-ovh-deploy.tar.gz -C /tmp/cachet-ovh-deploy
sudo install -d -o root -g root -m 0755 /opt/cachet
sudo install -d -o 10001 -g 10001 -m 0750 /var/lib/cachet/engine
sudo install -d -o 10001 -g 10001 -m 0750 /var/lib/cachet/gateway
sudo install -d -o root -g root -m 0700 /var/backups/cachet

sudo install -o root -g root -m 0644 \
  /tmp/cachet-ovh-deploy/scripts/deploy/compose.ovh.yml \
  /opt/cachet/compose.yml
sudo install -o root -g root -m 0755 \
  /tmp/cachet-ovh-deploy/scripts/deploy/cachetctl.sh \
  /opt/cachet/cachetctl

sudo install -o root -g root -m 0600 \
  /tmp/cachet-ovh-deploy/scripts/deploy/ovh.runtime.env.example \
  /opt/cachet/.env
sudo install -o root -g root -m 0600 \
  /tmp/cachet-ovh-deploy/scripts/deploy/ovh.deploy.env.example \
  /opt/cachet/deploy.env
```

Command `install` terakhir hanya untuk initial provisioning. Pada update berikutnya,
jangan overwrite `/opt/cachet/.env` atau `deploy.env` dengan template.

## Fase 4 — Isi konfigurasi tanpa mencetak secret

```bash
sudoedit /opt/cachet/.env
sudoedit /opt/cachet/deploy.env
sudo stat -c '%U %G %a %n' /opt/cachet/.env /opt/cachet/deploy.env
```

Expected: kedua file `root root 600`.

`/opt/cachet/.env` wajib berisi address testnet live, `GATEWAY_PK` testnet-only,
`CHAIN_MODE=viem`, `X402_BYPASS=0`, `DEMO_MODE=0`, serta URL HTTPS terkait.
`X402_FACILITATOR_URL` boleh kosong sebelum okx.ai memberikannya, tetapi paid call
akan tetap tidak tersedia. `cachetctl` memberi warning tanpa mencetak nilainya.

`/opt/cachet/deploy.env` memakai dua image tag full SHA yang dicetak oleh
`build-ovh-images.sh`.

Login GHCR pada VPS menggunakan token read-only `read:packages`:

```bash
sudo docker login ghcr.io -u scientivan
```

Masukkan token saat prompt; jangan tempel token ke command atau history.

## Fase 5 — Swap safety net

Cek kondisi sekarang:

```bash
swapon --show
free -h
```

Jika belum ada swap, buat 2 GB swap file eksplisit:

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-cachet-swap.conf
sudo sysctl --system
```

Jangan jalankan blok itu jika `/swapfile` sudah tercatat di `/etc/fstab`.

## Fase 6 — Install certificate dan Caddy route tanpa downtime SimpleArt

Pasang Origin CA certificate Cachet:

```bash
sudo install -d -o root -g caddy -m 0750 /etc/caddy/certs
sudo install -o root -g caddy -m 0640 /path/to/cachet-origin.crt \
  /etc/caddy/certs/cachetprotocol.xyz.crt
sudo install -o root -g caddy -m 0640 /path/to/cachet-origin.key \
  /etc/caddy/certs/cachetprotocol.xyz.key
```

`/path/to/...` adalah lokasi sementara yang kamu pilih saat memindahkan credential;
hapus salinan sementara setelah file terpasang.

Backup dan validasi kandidat lengkap. **Jangan reload jika validasi gagal.**

```bash
sudo cp -a /etc/caddy/Caddyfile /etc/caddy/Caddyfile.before-cachet
sudo install -o root -g root -m 0644 \
  /tmp/cachet-ovh-deploy/scripts/deploy/Caddyfile.shared-ovh \
  /etc/caddy/Caddyfile.candidate
sudo caddy validate --config /etc/caddy/Caddyfile.candidate --adapter caddyfile
sudo install -o root -g root -m 0644 \
  /etc/caddy/Caddyfile.candidate /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Config kandidat mempertahankan upstream SimpleArt di
`/opt/simpleart/caddy/upstream.caddy`, tetapi mengganti catch-all hostname dengan
hostname eksplisit. Verifikasi segera:

```bash
curl -fsS https://simpleartch.com/api/health
sudo systemctl is-active caddy
```

Jika gagal, kembalikan file backup lalu reload:

```bash
sudo install -o root -g root -m 0644 \
  /etc/caddy/Caddyfile.before-cachet /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo systemctl reload caddy
```

## Fase 7 — Initial engine dan pre-seed 5k

Preflight lalu mulai engine tanpa corpus gate:

```bash
sudo /opt/cachet/cachetctl preflight
sudo /opt/cachet/cachetctl bootstrap-engine
```

Dari Mac, buka SSH tunnel. Port engine tetap tidak publik:

```bash
ssh -N -L 18100:127.0.0.1:8100 ubuntu@VPS_IP
```

Di terminal Mac kedua, dari repo root dan venv engine:

```bash
source services/engine/.venv/bin/activate
pip install -r scripts/requirements.txt
python scripts/preseed.py \
  --source synthetic \
  --count 5000 \
  --engine http://127.0.0.1:18100 \
  --checkpoint data/ovh-preseed.checkpoint.json
```

Tutup tunnel setelah selesai. Verifikasi dari VPS:

```bash
sudo /opt/cachet/cachetctl corpus
```

Checkpoint hanya merekam progress pada volume ini. Jika volume dipulihkan kosong,
gunakan checkpoint baru agar seluruh 5k entri dikirim ulang.

## Fase 8 — Deploy gateway dan smoke test

```bash
sudo /opt/cachet/cachetctl deploy
sudo /opt/cachet/cachetctl status
```

`deploy` melakukan: preflight tanpa print secret → backup konsisten → pull image →
engine health/corpus gate → gateway health → internal smoke → public HTTPS smoke →
cek endpoint berbayar tanpa payment mengembalikan 402 → baca cert testnet #6.

Pastikan port aplikasi hanya listen di loopback:

```bash
sudo ss -ltnp | awk '$4 ~ /:(8100|8787)$/ {print}'
```

Expected address: `127.0.0.1`, bukan `0.0.0.0` atau `[::]`.

## Operasi rutin

### Deploy Cachet

1. Build/push image dari commit bersih di Mac.
2. Ubah dua tag di `/opt/cachet/deploy.env` ke SHA yang sama.
3. Jalankan:

```bash
sudo /opt/cachet/cachetctl deploy
```

### Sebelum dan sesudah deploy SimpleArt

```bash
sudo /opt/cachet/cachetctl pause
# jalankan workflow blue-green SimpleArt yang sudah ada
sudo /opt/cachet/cachetctl resume
```

### Backup, status, dan smoke

```bash
sudo /opt/cachet/cachetctl backup
sudo /opt/cachet/cachetctl status
sudo /opt/cachet/cachetctl smoke
```

Backup berada di `/var/backups/cachet/<UTC timestamp>/` dan berisi SQLite backup
konsisten, gateway JSON bila ada, serta image tags. Rotasi backup dilakukan setelah
memastikan snapshot yang lebih baru dapat dibaca; jangan menghapus backup terakhir.

### Rollback image

```bash
sudo /opt/cachet/cachetctl rollback \
  /var/backups/cachet/UTC_TIMESTAMP/deploy.env
```

Ganti `UTC_TIMESTAMP` dengan direktori backup nyata yang dipilih setelah menjalankan
`sudo ls -1 /var/backups/cachet`. Rollback image tidak menimpa data persistent.

## Acceptance akhir

- `https://simpleartch.com/api/health` tetap sehat.
- `https://api.cachetprotocol.xyz/healthz` mengembalikan HTTP 200.
- Unpaid `POST /v1/verify` mengembalikan HTTP 402.
- `GET /v1/cert/6` berhasil dari internet.
- Engine corpus `entries >= 5000` setelah recreate container.
- Tidak ada listener publik pada 8100/8787.
- `X402_BYPASS=0`, `DEMO_MODE=0`, `CHAIN_MODE=viem` tervalidasi tanpa print secret.
- `docker stats` menunjukkan Cachet berada di bawah resource ceiling.
- Previous immutable image tags tersedia dan rollback sudah direhearsal.

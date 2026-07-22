# Cachet Gateway (A3) — image produksi.
#
# ⚠️ BUILD CONTEXT = ROOT REPO (bukan apps/server), karena gateway bergantung pada
#    packages/contracts-abi lewat `file:` dependency (monorepo). Contoh:
#      docker build -f apps/server/Dockerfile -t cachet-gateway .
#    (titik = root repo). docker-compose sudah mengatur ini.
#
# COPY selektif (bukan `COPY apps/server .`) supaya node_modules host tidak ikut
# dan tak perlu .dockerignore di root (root = zona bersama).
FROM node:22-slim

RUN corepack enable
WORKDIR /repo

# tsconfig base + paket ABI (dibaca saat build; read-only, milik B).
COPY tsconfig.base.json ./tsconfig.base.json
COPY packages/contracts-abi/package.json packages/contracts-abi/index.ts packages/contracts-abi/addresses.testnet.json ./packages/contracts-abi/
COPY packages/contracts-abi/abi ./packages/contracts-abi/abi

# Gateway: manifest + lockfile dulu (cache install), lalu source.
COPY apps/server/package.json apps/server/pnpm-lock.yaml apps/server/tsconfig.json ./apps/server/
WORKDIR /repo/apps/server
RUN pnpm install
COPY apps/server/src ./src

ENV GATEWAY_PORT=8787 \
    GATEWAY_DATA_DIR=/data
EXPOSE 8787
VOLUME ["/data"]

# Konfigurasi (RPC/ADDR_*/GATEWAY_PK/CHAIN_MODE/X402_*) via env saat run — JANGAN
# di-bake ke image. CHAIN_MODE auto=viem bila ADDR_CERTIFICATE terisi.
CMD ["pnpm", "start"]

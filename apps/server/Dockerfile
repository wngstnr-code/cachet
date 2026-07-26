# Cachet Gateway (A3) — image produksi non-root.
#
# ⚠️ BUILD CONTEXT = ROOT REPO (bukan apps/server), karena gateway bergantung pada
#    packages/contracts-abi lewat `file:` dependency (monorepo). Contoh:
#      docker build -f apps/server/Dockerfile -t cachet-gateway .
#    (titik = root repo). Untuk produksi, gunakan script build di bawah.
#
# COPY selektif (bukan `COPY apps/server .`) supaya node_modules host tidak ikut.
# Production build memakai context minimal dari scripts/deploy/build-ovh-images.sh
# agar `.env` dan file monorepo lain tidak pernah dikirim ke builder.
# Tahap dependency dipisah agar cache pnpm tidak ikut ke image runtime.
FROM node:22-bookworm-slim AS dependencies

RUN corepack enable && corepack prepare pnpm@10.18.3 --activate
WORKDIR /repo

# tsconfig base + paket ABI (dibaca saat build; read-only, milik B).
# KEDUA file addresses wajib ikut: index.ts meng-import keduanya sejak deployment
# mainnet. Menyalin testnet saja membuat image ter-build mulus lalu MATI saat start
# ("Cannot find module ./addresses.mainnet.json") — image ini menjalankan tsx, jadi
# tidak ada tahap compile yang menangkapnya lebih dulu.
COPY tsconfig.base.json ./tsconfig.base.json
COPY packages/contracts-abi/package.json packages/contracts-abi/index.ts \
  packages/contracts-abi/addresses.testnet.json packages/contracts-abi/addresses.mainnet.json \
  ./packages/contracts-abi/
COPY packages/contracts-abi/abi ./packages/contracts-abi/abi

# Gateway: manifest + lockfile dulu (cache install), lalu source.
COPY apps/server/package.json apps/server/pnpm-lock.yaml apps/server/tsconfig.json ./apps/server/
WORKDIR /repo/apps/server
RUN pnpm install --frozen-lockfile
COPY apps/server/src ./src

FROM node:22-bookworm-slim AS runtime

ENV GATEWAY_PORT=8787 \
    GATEWAY_DATA_DIR=/data \
    NODE_ENV=production

WORKDIR /repo/apps/server

RUN groupadd --gid 10001 cachet \
    && useradd --uid 10001 --gid cachet --shell /usr/sbin/nologin --create-home cachet \
    && mkdir -p /data \
    && chown cachet:cachet /data

COPY --from=dependencies --chown=cachet:cachet /repo /repo

EXPOSE 8787
VOLUME ["/data"]

# Konfigurasi (RPC/ADDR_*/GATEWAY_PK/CHAIN_MODE/X402_*) via env saat run — JANGAN
# di-bake ke image. CHAIN_MODE auto=viem bila ADDR_CERTIFICATE terisi.
USER 10001:10001

HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=4 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:'+(process.env.GATEWAY_PORT||'8787')+'/healthz').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"]

# Jalankan binary tsx langsung; pnpm/corepack tidak diperlukan di image runtime.
CMD ["./node_modules/.bin/tsx", "src/index.ts"]

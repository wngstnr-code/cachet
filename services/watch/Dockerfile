# Cachet Watch worker (A4) — image produksi non-root. Context = services/watch.
FROM node:22-bookworm-slim AS dependencies

RUN corepack enable && corepack prepare pnpm@10.18.3 --activate
WORKDIR /repo

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY src ./src

FROM node:22-bookworm-slim AS runtime

ENV WATCH_PORT=8795 \
    WATCH_DATA_DIR=/data \
    NODE_ENV=production

WORKDIR /repo

RUN groupadd --gid 10001 cachet \
    && useradd --uid 10001 --gid cachet --shell /usr/sbin/nologin --create-home cachet \
    && mkdir -p /data \
    && chown cachet:cachet /data

COPY --from=dependencies --chown=cachet:cachet /repo /repo

EXPOSE 8795
VOLUME ["/data"]

# ENGINE_URL, WATCH_SUBSCRIPTIONS_FILE (store gateway, read-only), CRON_SCHEDULE via env saat run.
USER 10001:10001

HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=4 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:'+(process.env.WATCH_PORT||'8795')+'/healthz').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"]

CMD ["./node_modules/.bin/tsx", "src/index.ts"]

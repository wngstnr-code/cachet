# Cachet Watch worker (A4) — image produksi. Context = services/watch.
FROM node:22-slim

RUN corepack enable
WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN pnpm install
COPY src ./src

ENV WATCH_PORT=8795
EXPOSE 8795
VOLUME ["/data"]

# ENGINE_URL, WATCH_SUBSCRIPTIONS_FILE (store gateway), CRON_SCHEDULE via env saat run.
CMD ["pnpm", "start"]

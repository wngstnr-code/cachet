# Cachet MCP server (A3/PR-4) — image produksi. Context = apps/mcp-server.
#
# Catatan: MCP server ini bicara lewat STDIO (dijalankan sebagai subprocess oleh
# klien MCP), bukan HTTP server yang berdiri sendiri. Image ini berguna bila host
# menjalankan MCP via container. Ia meneruskan ke gateway di GATEWAY_URL.
FROM node:22-slim

RUN corepack enable
WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN pnpm install
COPY src ./src

# GATEWAY_URL via env saat run (default http://localhost:8787).
CMD ["pnpm", "start"]

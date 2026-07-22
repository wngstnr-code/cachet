/**
 * Entry point MCP (stdio). Klien MCP (Claude Code, okx.ai) menjalankan ini dan
 * memanggil tool; tool meneruskan ke gateway REST di GATEWAY_URL.
 */

import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import dotenv from "dotenv";

import { buildServer } from "./server.js";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
dotenv.config({ path: resolve(__dirname, "../../../.env") });

async function main(): Promise<void> {
  const gatewayUrl = process.env.GATEWAY_URL ?? `http://localhost:${process.env.GATEWAY_PORT ?? 8787}`;
  const server = buildServer(gatewayUrl);
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // stdio: jangan tulis ke stdout (itu kanal protokol). Log ke stderr.
  console.error(`[mcp] cachet MCP server siap · gateway=${gatewayUrl}`);
}

main().catch((err) => {
  console.error("[mcp] gagal start:", err);
  process.exit(1);
});

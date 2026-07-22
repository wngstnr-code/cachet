/**
 * Rakitan MCP server: daftarkan 6 tool §3.3 ke McpServer. Dipisah dari index.ts
 * (transport) supaya bisa dites tanpa stdio.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

import { GatewayClient } from "./gateway.js";
import { makeTools } from "./tools.js";

export function buildServer(gatewayUrl: string): McpServer {
  const server = new McpServer({ name: "cachet", version: "0.1.0" });
  const gw = new GatewayClient(gatewayUrl);

  for (const tool of makeTools(gw)) {
    server.tool(tool.name, tool.description, tool.schema, (args) =>
      tool.handler(args as Record<string, unknown>),
    );
  }
  return server;
}

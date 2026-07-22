/**
 * Entry point gateway. x402 & MCP menyusul di PR-4; PR-3 = REST core + stub chain.
 */

import { buildApp } from "./app.js";
import { buildDeps, loadConfig } from "./config.js";

async function main(): Promise<void> {
  const cfg = loadConfig();
  const deps = buildDeps(cfg);
  const app = await buildApp(deps, { uploadLimitBytes: cfg.uploadLimitBytes });

  await app.listen({ host: "0.0.0.0", port: cfg.port });
  // eslint-disable-next-line no-console
  console.log(`[gateway] listen :${cfg.port} · engine=${cfg.engineUrl} · signer=${deps.signer.address} · demo=${cfg.demoMode}`);
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("[gateway] gagal start:", err);
  process.exit(1);
});

/** Entry point gateway REST + chain client + payment gate OKX x402 v2. */

import { buildApp } from "./app.js";
import { buildDeps, loadConfig } from "./config.js";

async function main(): Promise<void> {
  const cfg = loadConfig();
  const deps = buildDeps(cfg);

  // Viem: approve payToken ke Vault sekali sebelum melayani. Stub: no-op.
  await deps.chain.ensureReady?.();

  const app = await buildApp(deps, { uploadLimitBytes: cfg.uploadLimitBytes });

  await app.listen({ host: "0.0.0.0", port: cfg.port });
  // eslint-disable-next-line no-console
  console.log(`[gateway] listen :${cfg.port} · engine=${cfg.engineUrl} · chain=${cfg.chainMode} · signer=${deps.signer.address} · demo=${cfg.demoMode}`);
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("[gateway] gagal start:", err);
  process.exit(1);
});

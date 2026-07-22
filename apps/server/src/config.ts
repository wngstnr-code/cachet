/**
 * Konfigurasi gateway dari .env ROOT monorepo (§6, §8.1) — default tiap tool tidak
 * menunjuk ke root, jadi kita resolusi eksplisit ke ../../.env.
 *
 * buildDeps() merakit dependency PRODUKSI (engine HTTP + chain stub + signer).
 * Chain masih STUB di PR-3; viem menyusul di A5 (swap satu baris di sini).
 */

import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import dotenv from "dotenv";
import { generatePrivateKey } from "viem/accounts";
import type { Hex } from "viem";

import { addresses } from "@cachet/contracts-abi";

import { StubChainClient } from "./chain/stub.js";
import type { ChainClient } from "./chain/types.js";
import { HttpEngineClient, type EngineClient } from "./engine/client.js";
import { VerdictSigner } from "./signer.js";
import { Store } from "./store.js";
import { HttpFacilitator } from "./x402/guard.js";
import type { X402Options } from "./x402/plugin.js";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
dotenv.config({ path: resolve(__dirname, "../../../.env") });

export interface Deps {
  engine: EngineClient;
  chain: ChainClient;
  signer: VerdictSigner;
  store: Store;
  certPageBase: string;
  demoMode: boolean;
  uploadLimitBytes: number;
  x402: X402Options;
}

export interface Config {
  port: number;
  engineUrl: string;
  chainId: number;
  certPageBase: string;
  demoMode: boolean;
  dataDir: string;
  gatewayPk: Hex;
  uploadLimitBytes: number;
}

export function loadConfig(): Config {
  let gatewayPk = process.env.GATEWAY_PK as Hex | undefined;
  if (!gatewayPk) {
    gatewayPk = generatePrivateKey();
    // eslint-disable-next-line no-console
    console.warn("[gateway] GATEWAY_PK tidak diset — memakai kunci EFEMERAL (dev saja).");
  }
  return {
    port: Number(process.env.GATEWAY_PORT ?? 8787),
    engineUrl: process.env.ENGINE_URL ?? "http://localhost:8100",
    chainId: Number(process.env.CHAIN_ID ?? 1952),
    certPageBase: process.env.CERT_PAGE_BASE || "https://cachet.local/cert-page",
    demoMode: process.env.DEMO_MODE === "1",
    dataDir: process.env.GATEWAY_DATA_DIR ?? resolve(__dirname, "../data"),
    gatewayPk,
    uploadLimitBytes: Number(process.env.GATEWAY_UPLOAD_LIMIT ?? 15 * 1024 * 1024),
  };
}

export function buildDeps(cfg: Config): Deps {
  const signer = new VerdictSigner(cfg.gatewayPk, cfg.chainId);
  const facilitatorUrl = process.env.X402_FACILITATOR_URL;

  const x402: X402Options = {
    // Bypass di dev (X402_BYPASS=1) atau DEMO_MODE. WAJIB false di listing.
    bypass: process.env.X402_BYPASS === "1" || cfg.demoMode,
    network: process.env.X402_NETWORK ?? `eip155:${cfg.chainId}`,
    asset: process.env.X402_ASSET ?? (addresses.payToken.address as string),
    // Penerima pembayaran x402 = revenue gateway; default alamat signer.
    payTo: process.env.X402_PAY_TO ?? signer.address,
    facilitator: facilitatorUrl ? new HttpFacilitator(facilitatorUrl) : undefined,
  };

  return {
    engine: new HttpEngineClient(cfg.engineUrl),
    // PR-3: chain = stub. A5: ganti ke ViemChainClient(addresses, rpc, pk).
    chain: new StubChainClient(),
    signer,
    store: new Store(cfg.dataDir),
    certPageBase: cfg.certPageBase,
    demoMode: cfg.demoMode,
    uploadLimitBytes: cfg.uploadLimitBytes,
    x402,
  };
}

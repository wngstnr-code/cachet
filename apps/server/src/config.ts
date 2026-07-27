/**
 * Konfigurasi gateway dari .env ROOT monorepo (§6, §8.1) — default tiap tool tidak
 * menunjuk ke root, jadi kita resolusi eksplisit ke ../../.env.
 *
 * buildDeps() merakit dependency produksi: engine HTTP, chain client, signer,
 * storage, dan seller middleware OKX x402 v2.
 */

import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import dotenv from "dotenv";
import { isAddress } from "viem";
import { generatePrivateKey } from "viem/accounts";
import type { Hex } from "viem";
import { OKXFacilitatorClient } from "@okxweb3/x402-core";
import type { Network } from "@okxweb3/x402-core/types";

import { addresses } from "@cachet/contracts-abi";

import { StubChainClient } from "./chain/stub.js";
import type { ChainClient } from "./chain/types.js";
import { ViemChainClient, type ViemAddresses } from "./chain/viem.js";
import { HttpEngineClient, type EngineClient } from "./engine/client.js";
import { VerdictSigner } from "./signer.js";
import { Store } from "./store.js";
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
  rpcUrl: string;
  chainMode: "stub" | "viem";
  certPageBase: string;
  demoMode: boolean;
  dataDir: string;
  gatewayPk: Hex;
  uploadLimitBytes: number;
}

const ZERO_ADDR = "0x0000000000000000000000000000000000000000";
const X_LAYER_TESTNET = "eip155:1952" as const;
const X_LAYER_MAINNET = "eip155:196" as const;

/**
 * Network yang boleh diiklankan di challenge 402.
 *
 * Mainnet ditambahkan karena reviewer OKX.AI menolak listing ASP yang challenge
 * 402-nya tidak menyebut CAIP-2 `eip155:196`. Nilai ini bukan sekadar label:
 * ia yang memberi tahu agent pembeli di chain mana pembayaran harus dikirim.
 */
const ALLOWED_NETWORKS = [X_LAYER_TESTNET, X_LAYER_MAINNET] as const;
type AllowedNetwork = (typeof ALLOWED_NETWORKS)[number];

const OKX_PAYMENT_BASE_URL = "https://web3.okx.com";

function requireHttpsUrl(value: string, name: string): string {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error(`${name} harus berupa URL valid`);
  }
  if (url.protocol !== "https:") throw new Error(`${name} wajib memakai HTTPS`);
  return url.toString().replace(/\/$/, "");
}

/** Muat konfigurasi seller x402 tanpa pernah mencetak nilai credential. */
export function loadX402Options(
  env: NodeJS.ProcessEnv,
  defaults: { chainId: number; payTo: `0x${string}` },
): X402Options {
  const bypass = env.X402_BYPASS === "1";
  const network = (env.X402_NETWORK ?? `eip155:${defaults.chainId}`) as Network;
  const payTo = (env.X402_PAY_TO ?? defaults.payTo) as `0x${string}`;
  const resourceBaseRaw = env.X402_RESOURCE_BASE ?? "http://localhost:8787";

  if (!isAddress(payTo)) throw new Error("X402_PAY_TO harus berupa alamat EVM valid");

  if (bypass) {
    return {
      bypass: true,
      network,
      payTo,
      resourceBase: resourceBaseRaw.replace(/\/$/, ""),
    };
  }

  if (!ALLOWED_NETWORKS.includes(network as AllowedNetwork)) {
    throw new Error(`X402_NETWORK wajib salah satu dari ${ALLOWED_NETWORKS.join(" atau ")}`);
  }

  // Network yang diiklankan WAJIB chain yang benar-benar dipakai gateway.
  // Kalau keduanya berbeda, agent pembeli mengirim dana ke chain yang salah dan
  // dana itu tidak bisa ditarik kembali — kegagalan senyap yang jauh lebih mahal
  // daripada gateway yang menolak menyala.
  const expectedNetwork = `eip155:${defaults.chainId}`;
  if (network !== expectedNetwork) {
    throw new Error(
      `X402_NETWORK (${network}) tidak cocok dengan chain gateway (${expectedNetwork}). ` +
        "Samakan X402_NETWORK dengan CHAIN_ID.",
    );
  }
  const resourceBase = requireHttpsUrl(resourceBaseRaw, "X402_RESOURCE_BASE");
  const baseUrl = requireHttpsUrl(env.OKX_BASE_URL ?? OKX_PAYMENT_BASE_URL, "OKX_BASE_URL");
  if (baseUrl !== OKX_PAYMENT_BASE_URL) {
    throw new Error(`OKX_BASE_URL untuk deployment ini wajib ${OKX_PAYMENT_BASE_URL}`);
  }

  const apiKey = env.OKX_API_KEY;
  const secretKey = env.OKX_SECRET_KEY;
  const passphrase = env.OKX_PASSPHRASE;
  if (!apiKey || !secretKey || !passphrase) {
    throw new Error("OKX_API_KEY, OKX_SECRET_KEY, dan OKX_PASSPHRASE wajib diisi bersama saat x402 aktif");
  }

  return {
    bypass: false,
    network,
    payTo,
    resourceBase,
    facilitator: new OKXFacilitatorClient({
      apiKey,
      secretKey,
      passphrase,
      baseUrl,
      syncSettle: true,
    }),
  };
}

/** Alamat kontrak dari env (isi H3 dari B), fallback addresses.testnet.json. */
function resolveAddresses(): ViemAddresses {
  const c = addresses.contracts;
  return {
    registry: (process.env.ADDR_REGISTRY ?? c.registry) as `0x${string}`,
    certificate: (process.env.ADDR_CERTIFICATE ?? c.certificate) as `0x${string}`,
    vault: (process.env.ADDR_VAULT ?? c.vault) as `0x${string}`,
    challengeManager: (process.env.ADDR_CHALLENGE ?? c.challengeManager) as `0x${string}`,
    mockUSDT: (process.env.ADDR_MOCKUSDT ?? c.mockUSDT) as `0x${string}`,
  };
}

/** Cermin apps/web/src/config.ts (`isTestnet: chainId === 1952`) — URL cert page
 *  tanpa slug chain dibaca cert page sebagai testnet (LEGACY_CHAIN), jadi mint
 *  di mainnet WAJIB kirim slug eksplisit atau pembeli membuka sertifikat orang
 *  lain di chain yang salah. */
function chainSlug(chainId: number): "mainnet" | "testnet" {
  return chainId === 196 ? "mainnet" : "testnet";
}

export function loadConfig(): Config {
  let gatewayPk = process.env.GATEWAY_PK as Hex | undefined;
  if (!gatewayPk) {
    gatewayPk = generatePrivateKey();
    // eslint-disable-next-line no-console
    console.warn("[gateway] GATEWAY_PK tidak diset — memakai kunci EFEMERAL (dev saja).");
  }
  // Mode chain: eksplisit CHAIN_MODE, atau auto = viem bila alamat Certificate terisi.
  const addrCert = process.env.ADDR_CERTIFICATE ?? addresses.contracts.certificate;
  const chainMode =
    (process.env.CHAIN_MODE as "stub" | "viem" | undefined) ??
    (addrCert && addrCert !== ZERO_ADDR ? "viem" : "stub");
  const chainId = Number(process.env.CHAIN_ID ?? 1952);
  const certPageBaseRaw = process.env.CERT_PAGE_BASE || "https://cachet.local/cert-page";
  return {
    port: Number(process.env.GATEWAY_PORT ?? 8787),
    engineUrl: process.env.ENGINE_URL ?? "http://localhost:8100",
    chainId,
    rpcUrl: process.env.RPC_URL ?? "https://testrpc.xlayer.tech",
    chainMode,
    certPageBase: `${certPageBaseRaw.replace(/\/$/, "")}/${chainSlug(chainId)}`,
    demoMode: process.env.DEMO_MODE === "1",
    dataDir: process.env.GATEWAY_DATA_DIR ?? resolve(__dirname, "../data"),
    gatewayPk,
    uploadLimitBytes: Number(process.env.GATEWAY_UPLOAD_LIMIT ?? 15 * 1024 * 1024),
  };
}

export function buildDeps(cfg: Config): Deps {
  const signer = new VerdictSigner(cfg.gatewayPk, cfg.chainId);
  const x402 = loadX402Options(
    { ...process.env, X402_BYPASS: cfg.demoMode ? "1" : process.env.X402_BYPASS },
    { chainId: cfg.chainId, payTo: signer.address },
  );

  const chain: ChainClient =
    cfg.chainMode === "viem"
      ? new ViemChainClient({
          rpcUrl: cfg.rpcUrl,
          chainId: cfg.chainId,
          gatewayPk: cfg.gatewayPk,
          addresses: resolveAddresses(),
        })
      : new StubChainClient();

  return {
    engine: new HttpEngineClient(cfg.engineUrl),
    chain,
    signer,
    store: new Store(cfg.dataDir),
    certPageBase: cfg.certPageBase,
    demoMode: cfg.demoMode,
    uploadLimitBytes: cfg.uploadLimitBytes,
    x402,
  };
}

// Sumber kebenaran alamat & chain: packages/contracts-abi (titik temu #2).
// File itu di-regenerate `make export-abi` — JANGAN salin nilainya ke sini.
import { addressesByChain } from "../../../packages/contracts-abi/index";

/** Slug yang muncul di URL. Dipakai sebagai identitas chain di seluruh app —
 *  lebih tahan salah baca daripada angka 196 vs 1952 yang mirip sekilas. */
export type ChainKey = "mainnet" | "testnet";

export interface ChainConfig {
  key: ChainKey;
  chainId: number;
  /** Nama dari addresses.*.json — bukan string di kode ini. */
  name: string;
  rpcUrl: string;
  explorer: string;
  /** Simbol token pembayaran deployment ini (mUSDT di testnet, USD₮0 di mainnet). */
  payTokenSymbol: string;
  /** true = jaminannya token faucet, bukan uang. Menentukan peringatan di UI. */
  isTestnet: boolean;
  contracts: (typeof addressesByChain)[keyof typeof addressesByChain]["contracts"];
  /** Batas bawah scan log: blok deployment. Tanpa ini getLogs menyisir genesis. */
  deployBlock: bigint;
}

/** RPC boleh ditimpa per chain lewat .env root (claude.md §6). Fallback ke nilai
 *  di addresses.*.json — itu artefak konfigurasi, bukan hardcode di kode. */
function rpcFor(key: ChainKey, fallback: string): string {
  const env = import.meta.env as Record<string, string | undefined>;
  const perChain = key === "mainnet" ? env.VITE_RPC_URL_MAINNET : env.VITE_RPC_URL_TESTNET;
  // VITE_RPC_URL lama hanya berlaku untuk testnet: itu satu-satunya chain yang
  // ada saat variabel itu dibuat. Memakainya untuk mainnet akan diam-diam
  // mengarahkan halaman mainnet ke RPC testnet.
  const legacy = key === "testnet" ? env.VITE_RPC_URL : undefined;
  return perChain ?? legacy ?? fallback;
}

function build(key: ChainKey, chainId: 196 | 1952): ChainConfig {
  const a = addressesByChain[chainId];
  return {
    key,
    chainId,
    name: a.chain.name,
    rpcUrl: rpcFor(key, a.chain.rpcUrl),
    explorer: a.chain.explorer,
    payTokenSymbol: a.payToken.symbol,
    isTestnet: chainId === 1952,
    contracts: a.contracts,
    deployBlock: BigInt(a.deployment.blockNumber),
  };
}

export const CHAINS: Record<ChainKey, ChainConfig> = {
  mainnet: build("mainnet", 196),
  testnet: build("testnet", 1952),
};

export const CHAIN_KEYS: ChainKey[] = ["mainnet", "testnet"];

/** Chain yang dibuka halaman depan. Mainnet: itu deployment yang jaminannya nyata. */
export const DEFAULT_CHAIN: ChainKey = "mainnet";

/** Chain untuk URL lama tanpa slug (`/cert/7`). WAJIB testnet: tautan itu sudah
 *  tersebar di README dan post publik yang merujuk sertifikat testnet tertentu.
 *  Mengalihkannya ke mainnet akan membuat tautan lama menampilkan sertifikat
 *  yang berbeda — atau tidak ada — tanpa siapa pun sadar. */
export const LEGACY_CHAIN: ChainKey = "testnet";

export function isChainKey(v: string): v is ChainKey {
  return v === "mainnet" || v === "testnet";
}

export const certPath = (chain: ChainKey, id: bigint | string): string =>
  `/${chain}/cert/${id}`;

/** Beranda per chain. Pemilih jaringan menuju SINI, bukan ke id yang sama di
 *  chain lain: sertifikat #7 di testnet dan #7 di mainnet adalah dua sertifikat
 *  berlainan, dan membawa id menyeberang akan menampilkan karya orang lain
 *  seolah-olah itu sertifikat yang sedang dilihat. */
export const homePath = (chain: ChainKey): string => `/${chain}`;

export const explorerTx = (c: ChainConfig, hash: string): string => `${c.explorer}/tx/${hash}`;
export const explorerAddress = (c: ChainConfig, addr: string): string =>
  `${c.explorer}/address/${addr}`;
export const sourcifyAddress = (c: ChainConfig, addr: string): string =>
  `https://repo.sourcify.dev/${c.chainId}/${addr}`;

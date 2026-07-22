// Sumber kebenaran alamat & chain: packages/contracts-abi (titik temu #2).
// File itu di-regenerate `make export-abi` — JANGAN salin nilainya ke sini.
import { addresses } from "../../../packages/contracts-abi/index";

export { addresses };

// RPC via .env root (claude.md §6). Fallback ke nilai handover di
// addresses.testnet.json — itu artefak konfigurasi, bukan hardcode di kode.
export const RPC_URL: string =
  (import.meta.env.VITE_RPC_URL as string | undefined) ?? addresses.chain.rpcUrl;

export const EXPLORER: string = addresses.chain.explorer;
export const CHAIN_ID: number = addresses.chain.chainId;

/** Batas bawah scan log: blok deployment. Tanpa ini getLogs menyisir genesis. */
export const DEPLOY_BLOCK: bigint = BigInt(addresses.deployment.blockNumber);

export const explorerTx = (hash: string): string => `${EXPLORER}/tx/${hash}`;
export const explorerAddress = (addr: string): string => `${EXPLORER}/address/${addr}`;
export const sourcifyAddress = (addr: string): string =>
  `https://repo.sourcify.dev/${CHAIN_ID}/${addr}`;

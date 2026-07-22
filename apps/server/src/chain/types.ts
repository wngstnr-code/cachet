/**
 * Kontrak ChainClient — SATU antarmuka untuk stub (sekarang) dan viem (A5).
 * Bentuk MintRequest & CertData mengikuti §3.1 (ABI beku). Membangun A1–A4 di
 * atas antarmuka ini berarti swap ke viem di A5 tidak menyentuh routes.
 */

import type { Address, Hex } from "viem";

/** 10 field, cocok persis dengan struct MintRequest §3.1 / packages/contracts-abi. */
export interface MintRequest {
  to: Address;
  phashes: [Hex, Hex, Hex, Hex];
  embCommit: Hex;
  revealedCommit: Hex; // 0x00…0 bila tanpa commit-reveal
  assetURI: string;
  tokenURI_: string;
  declaredValue: bigint; // base unit 6 desimal
  fraudBond: bigint;
  premium: bigint;
  insurable: boolean;
}

export interface CertData {
  entryId: bigint;
  declaredValue: bigint;
  mintedAt: number; // unix detik
  coverageStart: number;
  coverageEnd: number;
  insurable: boolean;
  revoked: boolean;
  challengesSurvived: number;
}

export interface ChainClient {
  // Persiapan sekali-jalan (viem: approve payToken ke Vault). Stub: no-op.
  ensureReady?(): Promise<void>;

  // Parameter (baca dari chain di impl nyata — JANGAN hardcode di gateway)
  fraudBondAmount(): Promise<bigint>;
  quotePremium(declaredValue: bigint): Promise<bigint>;
  maxDeclaredValue(): Promise<bigint>;
  waitingPeriod(): Promise<number>;
  challengeBondAmount(): Promise<bigint>;
  vaultAddress(): Address; // target approve penantang (RFC-001 P6)
  payTokenAddress(): Address;

  // Commit-reveal
  commit(commitHash: Hex): Promise<{ txHash: Hex; timestamp: number }>;
  commitTimestamp(commitHash: Hex): Promise<number>;

  // Mint atomik (jalur produksi tunggal)
  registerAndMint(r: MintRequest): Promise<{ entryId: bigint; certId: bigint; txHash: Hex }>;

  // Challenge
  challenge(certId: bigint, evidenceURI: string): Promise<{ challengeId: bigint; txHash: Hex }>;

  // Baca untuk get_certificate
  certData(certId: bigint): Promise<CertData>;
  isCoverageActive(certId: bigint): Promise<boolean>;
  ownerOf(certId: bigint): Promise<Address>;
}

export const ZERO_BYTES32: Hex =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

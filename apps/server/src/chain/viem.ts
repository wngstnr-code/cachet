/**
 * ViemChainClient — jalur PRODUKSI on-chain (A5), menggantikan StubChainClient.
 * Sama antarmuka (ChainClient) supaya routes tak berubah.
 *
 * Mematuhi 6 aturan packages/contracts-abi/README:
 * 1. Mint HANYA lewat Certificate.registerAndMint.
 * 2. Premi/bond dibaca dari chain (quotePremium/fraudBondAmount) — tak hardcode.
 * 3. Approve payToken SEKALI ke Vault (ensureReady) — allowance maxUint256.
 * 4. Coverage tak aktif seketika → status pakai isCoverageActive on-chain.
 * 5. Penerima mint harus bisa onERC721Received (validasi di pemanggil).
 * 6. Parameter bisa berubah → selalu baca dari chain.
 */

import {
  createPublicClient,
  createWalletClient,
  erc20Abi,
  http,
  maxUint256,
  type Address,
  type Hex,
  type PublicClient,
  type WalletClient,
} from "viem";
import { privateKeyToAccount, type PrivateKeyAccount } from "viem/accounts";

import {
  CachetCertificateAbi,
  CachetRegistryAbi,
  CachetVaultAbi,
  ChallengeManagerAbi,
} from "@cachet/contracts-abi";

import { AppError } from "../errors.js";
import { xlayerChain } from "./xlayer.js";
import type { CertData, ChainClient, MintRequest } from "./types.js";

export interface ViemAddresses {
  registry: Address;
  certificate: Address;
  vault: Address;
  challengeManager: Address;
  mockUSDT: Address;
}

export interface ViemOptions {
  rpcUrl: string;
  chainId: number;
  gatewayPk: Hex;
  addresses: ViemAddresses;
}

/** Ekstrak nama custom error kontrak (WrongPremium, DeclaredValueTooHigh, …) dari
 *  error viem → AppError dengan code konsisten stub. */
function mapChainError(err: unknown): AppError {
  const e = err as { walk?: (fn: (e: unknown) => boolean) => unknown; shortMessage?: string; message?: string };
  let name: string | undefined;
  try {
    const found = e.walk?.((x: any) => typeof x?.data?.errorName === "string") as any;
    name = found?.data?.errorName;
  } catch {
    /* ignore */
  }
  const msg = (e.shortMessage ?? e.message ?? "chain call reverted").split("\n")[0];
  return new AppError(name ?? "CHAIN_REVERT", msg, 400);
}

export class ViemChainClient implements ChainClient {
  private account: PrivateKeyAccount;
  private pub: PublicClient;
  private wallet: WalletClient;
  private addr: ViemAddresses;

  constructor(opts: ViemOptions) {
    const chain = xlayerChain(opts.chainId, opts.rpcUrl);
    this.account = privateKeyToAccount(opts.gatewayPk);
    this.pub = createPublicClient({ chain, transport: http(opts.rpcUrl) });
    this.wallet = createWalletClient({ account: this.account, chain, transport: http(opts.rpcUrl) });
    this.addr = opts.addresses;
  }

  /** Approve payToken ke Vault SEKALI (allowance besar) bila belum cukup. */
  async ensureReady(): Promise<void> {
    const allowance = await this.pub.readContract({
      address: this.addr.mockUSDT,
      abi: erc20Abi,
      functionName: "allowance",
      args: [this.account.address, this.addr.vault],
    });
    if (allowance < maxUint256 / 2n) {
      const hash = await this.wallet.writeContract({
        address: this.addr.mockUSDT,
        abi: erc20Abi,
        functionName: "approve",
        args: [this.addr.vault, maxUint256],
        chain: this.wallet.chain,
        account: this.account,
      });
      await this.pub.waitForTransactionReceipt({ hash });
    }
  }

  // ── Parameter (baca dari chain) ────────────────────────────────────────────

  fraudBondAmount(): Promise<bigint> {
    return this.pub.readContract({ address: this.addr.vault, abi: CachetVaultAbi, functionName: "fraudBondAmount" });
  }
  quotePremium(declaredValue: bigint): Promise<bigint> {
    return this.pub.readContract({
      address: this.addr.vault,
      abi: CachetVaultAbi,
      functionName: "quotePremium",
      args: [declaredValue],
    });
  }
  maxDeclaredValue(): Promise<bigint> {
    return this.pub.readContract({ address: this.addr.certificate, abi: CachetCertificateAbi, functionName: "maxDeclaredValue" });
  }
  async waitingPeriod(): Promise<number> {
    const v = await this.pub.readContract({ address: this.addr.certificate, abi: CachetCertificateAbi, functionName: "waitingPeriod" });
    return Number(v);
  }
  challengeBondAmount(): Promise<bigint> {
    return this.pub.readContract({ address: this.addr.challengeManager, abi: ChallengeManagerAbi, functionName: "challengeBond" });
  }
  vaultAddress(): Address {
    return this.addr.vault;
  }
  payTokenAddress(): Address {
    return this.addr.mockUSDT;
  }

  // ── Commit-reveal ───────────────────────────────────────────────────────────

  async commit(commitHash: Hex): Promise<{ txHash: Hex; timestamp: number }> {
    try {
      const hash = await this.wallet.writeContract({
        address: this.addr.registry,
        abi: CachetRegistryAbi,
        functionName: "commit",
        args: [commitHash],
        chain: this.wallet.chain,
        account: this.account,
      });
      await this.pub.waitForTransactionReceipt({ hash });
      const timestamp = await this.commitTimestamp(commitHash);
      return { txHash: hash, timestamp };
    } catch (err) {
      throw mapChainError(err);
    }
  }

  async commitTimestamp(commitHash: Hex): Promise<number> {
    const v = await this.pub.readContract({
      address: this.addr.registry,
      abi: CachetRegistryAbi,
      functionName: "commitTimestamp",
      args: [commitHash],
    });
    return Number(v);
  }

  // ── Mint atomik ──────────────────────────────────────────────────────────────

  async registerAndMint(r: MintRequest): Promise<{ entryId: bigint; certId: bigint; txHash: Hex }> {
    try {
      const { request, result } = await this.pub.simulateContract({
        address: this.addr.certificate,
        abi: CachetCertificateAbi,
        functionName: "registerAndMint",
        args: [r],
        account: this.account,
      });
      const hash = await this.wallet.writeContract(request);
      await this.pub.waitForTransactionReceipt({ hash });
      const [entryId, certId] = result as unknown as [bigint, bigint];
      return { entryId, certId, txHash: hash };
    } catch (err) {
      throw mapChainError(err);
    }
  }

  // ── Challenge ─────────────────────────────────────────────────────────────────

  async challenge(certId: bigint, evidenceURI: string): Promise<{ challengeId: bigint; txHash: Hex }> {
    try {
      const { request, result } = await this.pub.simulateContract({
        address: this.addr.challengeManager,
        abi: ChallengeManagerAbi,
        functionName: "challenge",
        args: [certId, evidenceURI],
        account: this.account,
      });
      const hash = await this.wallet.writeContract(request);
      await this.pub.waitForTransactionReceipt({ hash });
      return { challengeId: result as bigint, txHash: hash };
    } catch (err) {
      throw mapChainError(err);
    }
  }

  // ── Baca untuk get_certificate ────────────────────────────────────────────────

  async certData(certId: bigint): Promise<CertData> {
    try {
      const d = (await this.pub.readContract({
        address: this.addr.certificate,
        abi: CachetCertificateAbi,
        functionName: "certData",
        args: [certId],
      })) as {
        entryId: bigint; declaredValue: bigint; mintedAt: bigint; coverageStart: bigint;
        coverageEnd: bigint; insurable: boolean; revoked: boolean; challengesSurvived: number;
      };
      return {
        entryId: d.entryId,
        declaredValue: d.declaredValue,
        mintedAt: Number(d.mintedAt),
        coverageStart: Number(d.coverageStart),
        coverageEnd: Number(d.coverageEnd),
        insurable: d.insurable,
        revoked: d.revoked,
        challengesSurvived: Number(d.challengesSurvived),
      };
    } catch (err) {
      throw mapChainError(err);
    }
  }

  isCoverageActive(certId: bigint): Promise<boolean> {
    return this.pub.readContract({ address: this.addr.certificate, abi: CachetCertificateAbi, functionName: "isCoverageActive", args: [certId] });
  }

  async ownerOf(certId: bigint): Promise<Address> {
    try {
      return await this.pub.readContract({ address: this.addr.certificate, abi: CachetCertificateAbi, functionName: "ownerOf", args: [certId] });
    } catch (err) {
      throw mapChainError(err);
    }
  }
}

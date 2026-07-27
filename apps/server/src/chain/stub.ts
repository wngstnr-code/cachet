/**
 * StubChainClient — chain in-memory yang MENIRU aturan kontrak nyata.
 *
 * Bukan sekadar mengembalikan sukses: ia menegakkan cek yang sama dengan Solidity
 * (WrongPremium, WrongFraudBond, DeclaredValueTooHigh, commit sekali-pakai & tolak
 * overwrite, id mulai 1, satu gugatan terbuka per cert). Tujuannya: bug integrasi
 * muncul saat test stub, bukan saat rekaman demo di testnet.
 *
 * Parameter default diambil dari packages/contracts-abi (addresses.params) supaya
 * konsisten dengan on-chain. Clock & waiting/coverage bisa dioverride untuk test.
 */

import { addresses } from "@cachet/contracts-abi";
import { toHex, type Address, type Hex } from "viem";

import { AppError } from "../errors.js";
import { quotePremium } from "../premium.js";
import { ZERO_BYTES32, type CertData, type ChainClient, type MintRequest } from "./types.js";

interface StubOptions {
  fraudBond?: bigint;
  premiumBps?: bigint;
  maxDeclaredValue?: bigint;
  waitingPeriodSeconds?: number;
  coverageTermSeconds?: number;
  challengeBond?: bigint;
  vault?: Address;
  payToken?: Address;
  challengeManager?: Address;
  nowFn?: () => number; // unix detik
}

const P = addresses.params;

interface Commit {
  timestamp: number;
  consumed: boolean;
}

export class StubChainClient implements ChainClient {
  private fraudBond: bigint;
  private premiumBps: bigint;
  private maxDeclared: bigint;
  private waiting: number;
  private coverageTerm: number;
  private challengeBond: bigint;
  private vault: Address;
  private payToken: Address;
  private challengeManager: Address;
  private now: () => number;

  private commits = new Map<Hex, Commit>();
  private certs = new Map<string, CertData & { owner: Address }>();
  private openChallengeOf = new Map<string, bigint>();
  private entryCount = 0n;
  private certCount = 0n;
  private challengeCount = 0n;

  // Simulasi saldo/allowance payToken kreator, hanya untuk pullCollateralFromCreator.
  // Semantik SAMA seperti ERC-20 asli: allowance & balance keduanya dikurangi
  // saat pull berhasil.
  private creatorBalances = new Map<string, bigint>();
  private creatorAllowances = new Map<string, bigint>();

  constructor(opts: StubOptions = {}) {
    this.fraudBond = opts.fraudBond ?? BigInt(P.fraudBondAmount);
    this.premiumBps = opts.premiumBps ?? BigInt(P.premiumBps);
    this.maxDeclared = opts.maxDeclaredValue ?? BigInt(P.maxDeclaredValue);
    this.waiting = opts.waitingPeriodSeconds ?? P.waitingPeriodSeconds;
    this.coverageTerm = opts.coverageTermSeconds ?? P.coverageTermSeconds;
    this.challengeBond = opts.challengeBond ?? BigInt(P.challengeBond);
    this.vault = opts.vault ?? (addresses.contracts.vault as Address);
    this.payToken = opts.payToken ?? (addresses.payToken.address as Address);
    this.challengeManager = opts.challengeManager ?? (addresses.contracts.challengeManager as Address);
    this.now = opts.nowFn ?? (() => Math.floor(Date.now() / 1000));
  }

  async fraudBondAmount() {
    return this.fraudBond;
  }
  async quotePremium(declaredValue: bigint) {
    return quotePremium(declaredValue, this.premiumBps);
  }
  async maxDeclaredValue() {
    return this.maxDeclared;
  }
  async waitingPeriod() {
    return this.waiting;
  }
  async challengeBondAmount() {
    return this.challengeBond;
  }
  vaultAddress() {
    return this.vault;
  }
  payTokenAddress() {
    return this.payToken;
  }
  challengeManagerAddress() {
    return this.challengeManager;
  }

  private fakeTx(): Hex {
    const b = new Uint8Array(32);
    crypto.getRandomValues(b);
    return toHex(b);
  }

  // ── Test-only: simulasi saldo/allowance payToken kreator ────────────────────

  setCreatorBalance(creator: Address, amount: bigint): void {
    this.creatorBalances.set(creator.toLowerCase(), amount);
  }

  setCreatorAllowance(creator: Address, amount: bigint): void {
    this.creatorAllowances.set(creator.toLowerCase(), amount);
  }

  async pullCollateralFromCreator(creator: Address, amount: bigint): Promise<{ txHash: Hex } | null> {
    const key = creator.toLowerCase();
    const balance = this.creatorBalances.get(key) ?? 0n;
    const allowance = this.creatorAllowances.get(key) ?? 0n;
    if (balance < amount || allowance < amount) return null;

    this.creatorBalances.set(key, balance - amount);
    this.creatorAllowances.set(key, allowance - amount);
    return { txHash: this.fakeTx() };
  }

  async commit(commitHash: Hex) {
    if (this.commits.has(commitHash)) {
      throw new AppError("CommitAlreadyExists", `commit sudah ada: ${commitHash}`, 409);
    }
    const timestamp = this.now();
    this.commits.set(commitHash, { timestamp, consumed: false });
    return { txHash: this.fakeTx(), timestamp };
  }

  async commitTimestamp(commitHash: Hex) {
    return this.commits.get(commitHash)?.timestamp ?? 0;
  }

  async registerAndMint(r: MintRequest) {
    if (r.declaredValue > this.maxDeclared) {
      throw new AppError(
        "DeclaredValueTooHigh",
        `declaredValue ${r.declaredValue} > maxDeclaredValue ${this.maxDeclared}`,
        400,
      );
    }
    if (r.fraudBond !== this.fraudBond) {
      throw new AppError("WrongFraudBond", `fraudBond ${r.fraudBond} != ${this.fraudBond}`, 400);
    }
    const expected = await this.quotePremium(r.declaredValue);
    if (r.premium !== expected) {
      throw new AppError("WrongPremium", `premium ${r.premium} != ${expected}`, 400);
    }

    if (r.revealedCommit !== ZERO_BYTES32) {
      const c = this.commits.get(r.revealedCommit);
      if (!c) throw new AppError("CommitNotFound", `commit tak ada: ${r.revealedCommit}`, 400);
      if (c.consumed) {
        throw new AppError("CommitAlreadyConsumed", `commit sudah dipakai: ${r.revealedCommit}`, 409);
      }
      c.consumed = true;
    }

    const entryId = ++this.entryCount; // mulai 1; 0 = "tidak ada"
    const certId = ++this.certCount;
    const mintedAt = this.now();
    const coverageStart = mintedAt + this.waiting;
    this.certs.set(certId.toString(), {
      entryId,
      declaredValue: r.declaredValue,
      mintedAt,
      coverageStart,
      coverageEnd: coverageStart + this.coverageTerm,
      insurable: r.insurable,
      revoked: false,
      challengesSurvived: 0,
      owner: r.to,
    });
    return { entryId, certId, txHash: this.fakeTx() };
  }

  async challenge(certId: bigint, _evidenceURI: string) {
    const cert = this.certs.get(certId.toString());
    if (!cert) throw new AppError("InvalidCertId", `cert tak ada: ${certId}`, 404);
    if (cert.revoked) throw new AppError("CertificateAlreadyRevoked", `cert dicabut: ${certId}`, 409);
    if (this.openChallengeOf.has(certId.toString())) {
      throw new AppError("ChallengeAlreadyOpen", `sudah ada gugatan terbuka utk ${certId}`, 409);
    }
    const challengeId = ++this.challengeCount;
    this.openChallengeOf.set(certId.toString(), challengeId);
    return { challengeId, txHash: this.fakeTx() };
  }

  async certData(certId: bigint): Promise<CertData> {
    const c = this.certs.get(certId.toString());
    if (!c) throw new AppError("InvalidCertId", `cert tak ada: ${certId}`, 404);
    const { owner, ...data } = c;
    return data;
  }

  async isCoverageActive(certId: bigint) {
    const c = this.certs.get(certId.toString());
    if (!c) return false;
    const t = this.now();
    return c.insurable && !c.revoked && t >= c.coverageStart && t <= c.coverageEnd;
  }

  async ownerOf(certId: bigint): Promise<Address> {
    const c = this.certs.get(certId.toString());
    if (!c) throw new AppError("InvalidCertId", `cert tak ada: ${certId}`, 404);
    return c.owner;
  }

  // ── Khusus test/demo (bukan bagian ChainClient) ────────────────────────────

  /** Simulasi resolver: menang → cabut; kalah → survived++. Untuk test status. */
  _resolve(certId: bigint, challengerWins: boolean): void {
    const c = this.certs.get(certId.toString());
    if (!c) throw new AppError("InvalidCertId", `cert tak ada: ${certId}`, 404);
    if (challengerWins) c.revoked = true;
    else c.challengesSurvived += 1;
    this.openChallengeOf.delete(certId.toString());
  }
}

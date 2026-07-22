import { describe, expect, it } from "vitest";
import type { Address, Hex } from "viem";

import { StubChainClient } from "../src/chain/stub.js";
import { ZERO_BYTES32, type MintRequest } from "../src/chain/types.js";

const H = (b: string) => ("0x" + b.repeat(32)) as Hex;
const CREATOR = "0x2222222222222222222222222222222222222222" as Address;

function req(over: Partial<MintRequest> = {}): MintRequest {
  return {
    to: CREATOR,
    phashes: [H("a1"), H("a2"), H("a3"), H("a4")],
    embCommit: H("bb"),
    revealedCommit: ZERO_BYTES32,
    assetURI: "sha256:x",
    tokenURI_: "sha256:x",
    declaredValue: 50_000_000n,
    fraudBond: 5_000_000n,
    premium: 1_000_000n,
    insurable: true,
    ...over,
  };
}

describe("StubChainClient — meniru aturan kontrak", () => {
  it("registerAndMint happy: id mulai 1", async () => {
    const c = new StubChainClient();
    const { entryId, certId } = await c.registerAndMint(req());
    expect(entryId).toBe(1n);
    expect(certId).toBe(1n);
    expect((await c.certData(certId)).declaredValue).toBe(50_000_000n);
    expect(await c.ownerOf(certId)).toBe(CREATOR);
  });

  it("WrongPremium bila premi meleset", async () => {
    const c = new StubChainClient();
    await expect(c.registerAndMint(req({ premium: 999_999n }))).rejects.toMatchObject({ code: "WrongPremium" });
  });

  it("WrongFraudBond bila bond meleset", async () => {
    const c = new StubChainClient();
    await expect(c.registerAndMint(req({ fraudBond: 4_000_000n }))).rejects.toMatchObject({ code: "WrongFraudBond" });
  });

  it("DeclaredValueTooHigh di atas plafon", async () => {
    const c = new StubChainClient();
    await expect(
      c.registerAndMint(req({ declaredValue: 200_000_000n, premium: 4_000_000n })),
    ).rejects.toMatchObject({ code: "DeclaredValueTooHigh" });
  });

  it("commit sekali-pakai + tolak overwrite", async () => {
    const c = new StubChainClient();
    const commitHash = H("dd");
    await c.commit(commitHash);
    await expect(c.commit(commitHash)).rejects.toMatchObject({ code: "CommitAlreadyExists" });

    await c.registerAndMint(req({ revealedCommit: commitHash }));
    // reveal kedua commit yang sama → consumed
    await expect(c.registerAndMint(req({ revealedCommit: commitHash }))).rejects.toMatchObject({
      code: "CommitAlreadyConsumed",
    });
  });

  it("reveal commit tak dikenal → CommitNotFound", async () => {
    const c = new StubChainClient();
    await expect(c.registerAndMint(req({ revealedCommit: H("ee") }))).rejects.toMatchObject({
      code: "CommitNotFound",
    });
  });

  it("satu gugatan terbuka per cert", async () => {
    const c = new StubChainClient();
    const { certId } = await c.registerAndMint(req());
    await c.challenge(certId, "ipfs://ev");
    await expect(c.challenge(certId, "ipfs://ev2")).rejects.toMatchObject({ code: "ChallengeAlreadyOpen" });
  });

  it("coverage PENDING saat masih waiting, ACTIVE setelahnya (clock injeksi)", async () => {
    let t = 1_000_000;
    const c = new StubChainClient({ waitingPeriodSeconds: 100, coverageTermSeconds: 1000, nowFn: () => t });
    const { certId } = await c.registerAndMint(req());
    expect(await c.isCoverageActive(certId)).toBe(false); // masih waiting
    t += 200; // lewat waiting
    expect(await c.isCoverageActive(certId)).toBe(true);
    t += 2000; // lewat coverageEnd
    expect(await c.isCoverageActive(certId)).toBe(false);
  });
});

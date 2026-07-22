import { describe, expect, it } from "vitest";
import { recoverTypedDataAddress, type Hex } from "viem";

import { computeCommitHash } from "../src/commit.js";
import { parseBaseUnit, toDisplay } from "../src/money.js";
import { quotePremium } from "../src/premium.js";
import { phashesHash, VERDICT_CODE, VerdictSigner } from "../src/signer.js";
import { TEST_PK } from "./helpers.js";

const H = (b: string) => ("0x" + b.repeat(32)) as Hex;

describe("premium (BigInt floor)", () => {
  it("nilai ganjil dibulatkan ke bawah, cocok kontrak", () => {
    expect(quotePremium(33_333_333n)).toBe(666_666n); // 33333333*200/10000 = 666666.66 → 666666
    expect(quotePremium(50_000_000n)).toBe(1_000_000n);
    expect(quotePremium(1n)).toBe(0n);
  });
});

describe("money base-unit", () => {
  it("toDisplay 6 desimal", () => {
    expect(toDisplay(50_000_000n)).toBe("50.000000");
    expect(toDisplay(1n)).toBe("0.000001");
  });
  it("parseBaseUnit tolak non-integer", () => {
    expect(parseBaseUnit("50000000")).toBe(50_000_000n);
    expect(() => parseBaseUnit("50.0")).toThrow();
    expect(() => parseBaseUnit("abc")).toThrow();
  });
});

describe("commit hash", () => {
  const creator = "0x1111111111111111111111111111111111111111" as const;
  it("deterministik & berubah bila salt berubah", () => {
    const a = computeCommitHash(H("aa"), H("01"), creator);
    const b = computeCommitHash(H("aa"), H("01"), creator);
    const c = computeCommitHash(H("aa"), H("02"), creator);
    expect(a).toBe(b);
    expect(a).not.toBe(c);
    expect(a).toMatch(/^0x[0-9a-f]{64}$/);
  });
});

describe("EIP-712 verdict signer", () => {
  it("tanda tangan bisa di-recover ke alamat signer", async () => {
    const signer = new VerdictSigner(TEST_PK, 1952);
    const phashes = [H("a1"), H("a2"), H("a3"), H("a4")];
    const ts = 1_753_000_000;
    const signed = await signer.sign(H("12"), "ORIGINAL", phashes, ts);

    const recovered = await recoverTypedDataAddress({
      domain: { name: "Cachet", version: "1", chainId: 1952 },
      types: {
        Verdict: [
          { name: "assetSha256", type: "bytes32" },
          { name: "verdict", type: "uint8" },
          { name: "phashesHash", type: "bytes32" },
          { name: "timestamp", type: "uint64" },
        ],
      },
      primaryType: "Verdict",
      message: {
        assetSha256: H("12"),
        verdict: VERDICT_CODE.ORIGINAL,
        phashesHash: phashesHash(phashes),
        timestamp: BigInt(ts),
      },
      signature: signed.signature,
    });
    expect(recovered.toLowerCase()).toBe(signer.address.toLowerCase());
  });
});

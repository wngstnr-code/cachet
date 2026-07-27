import { describe, expect, it } from "vitest";
import { encodeAbiParameters, encodeEventTopics, type Address, type Log } from "viem";

import { CachetCertificateAbi } from "@cachet/contracts-abi";

import { parseCertificateMinted } from "../src/chain/viem.js";

const CERT_ADDR = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" as Address;
const OTHER_ADDR = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" as Address;
const TO = "0x1111111111111111111111111111111111111111" as Address;

/** Bangun log CertificateMinted palsu — persis bentuk yang dikembalikan node
 *  RPC di `receipt.logs`, tanpa perlu chain sungguhan. */
function fakeMintedLog(certId: bigint, entryId: bigint, address: Address = CERT_ADDR): Log {
  const topics = encodeEventTopics({
    abi: CachetCertificateAbi,
    eventName: "CertificateMinted",
    args: { certId, entryId, to: TO },
  });
  const data = encodeAbiParameters([{ type: "uint256" }], [50_000_000n]);
  return {
    address,
    topics,
    data,
    blockNumber: 1n,
    blockHash: `0x${"11".repeat(32)}`,
    transactionHash: `0x${"22".repeat(32)}`,
    transactionIndex: 0,
    logIndex: 0,
    removed: false,
  } as Log;
}

describe("parseCertificateMinted (B2 — certId dari receipt, bukan simulasi)", () => {
  it("mengekstrak certId/entryId dari event, BUKAN 1n/1n default simulasi", () => {
    const logs = [fakeMintedLog(7n, 3n)];
    const out = parseCertificateMinted(logs, CERT_ADDR);
    expect(out.certId).toBe(7n);
    expect(out.entryId).toBe(3n);
  });

  it("mengabaikan log dari kontrak lain di tx yang sama", () => {
    const logs = [fakeMintedLog(99n, 99n, OTHER_ADDR), fakeMintedLog(2n, 2n, CERT_ADDR)];
    const out = parseCertificateMinted(logs, CERT_ADDR);
    expect(out.certId).toBe(2n);
    expect(out.entryId).toBe(2n);
  });

  it("melempar error jelas bila event tidak ditemukan (bukan diam-diam salah)", () => {
    expect(() => parseCertificateMinted([], CERT_ADDR)).toThrow(/CertificateMinted tidak ditemukan/);
  });
});

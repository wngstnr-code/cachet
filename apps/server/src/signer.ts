/**
 * Penandatangan verdict EIP-712 (§4-A3.3, RFC-001 P7).
 *
 *   domain: Cachet-v1 (name "Cachet", version "1", chainId)
 *   Verdict(bytes32 assetSha256, uint8 verdict, bytes32 phashesHash, uint64 timestamp)
 *   phashesHash = keccak256(abi.encodePacked(phashes[0..3]))  // 4 × bytes32
 *
 * Belum ada verifikasi on-chain di MVP (P7), tapi bentuk dikunci sekarang supaya
 * quorum multi-oracle di roadmap bisa memverifikasi verdict lama.
 */

import {
  concatHex,
  keccak256,
  type Address,
  type Hex,
} from "viem";
import { privateKeyToAccount, type PrivateKeyAccount } from "viem/accounts";

/** Pemetaan verdict → uint8. DIKUNCI — jangan ubah urutan (ikut ditandatangani). */
export const VERDICT_CODE: Record<string, number> = {
  ORIGINAL: 0,
  NEAR_DUP: 1,
  GRAY_ZONE: 2,
};

const VERDICT_TYPES = {
  Verdict: [
    { name: "assetSha256", type: "bytes32" },
    { name: "verdict", type: "uint8" },
    { name: "phashesHash", type: "bytes32" },
    { name: "timestamp", type: "uint64" },
  ],
} as const;

export function phashesHash(phashes: Hex[]): Hex {
  if (phashes.length !== 4) throw new Error("phashesHash butuh tepat 4 hash");
  return keccak256(concatHex(phashes));
}

export interface SignedVerdict {
  signer: Address;
  signature: Hex;
  timestamp: number;
  phashes_hash: Hex;
}

export class VerdictSigner {
  private account: PrivateKeyAccount;
  private domain: { name: string; version: string; chainId: number };

  constructor(privateKey: Hex, chainId: number) {
    this.account = privateKeyToAccount(privateKey);
    this.domain = { name: "Cachet", version: "1", chainId };
  }

  get address(): Address {
    return this.account.address;
  }

  async sign(
    assetSha256: Hex,
    verdict: string,
    phashes: Hex[],
    timestamp: number,
  ): Promise<SignedVerdict> {
    const code = VERDICT_CODE[verdict];
    if (code === undefined) throw new Error(`verdict tak dikenal: ${verdict}`);
    const ph = phashesHash(phashes);
    const signature = await this.account.signTypedData({
      domain: this.domain,
      types: VERDICT_TYPES,
      primaryType: "Verdict",
      message: {
        assetSha256,
        verdict: code,
        phashesHash: ph,
        timestamp: BigInt(timestamp),
      },
    });
    return { signer: this.account.address, signature, timestamp, phashes_hash: ph };
  }
}

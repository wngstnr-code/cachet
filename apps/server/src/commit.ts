/**
 * Helper commit-reveal. Rumus DIKUNCI (RFC-001 P4), identik di NatSpec kontrak,
 * README, dan sini:
 *
 *   commitHash = keccak256(abi.encodePacked(bytes32 phash0, bytes32 salt, address creator))
 *
 * Aman dari ambiguity encodePacked karena ketiga tipe fixed-size. phash0 = hash
 * PERTAMA dari ensemble (imagehash `phash`), BUKAN phash1.
 */

import { encodePacked, keccak256, type Address, type Hex } from "viem";

export const COMMIT_FORMULA =
  "keccak256(abi.encodePacked(bytes32 phash0, bytes32 salt, address creator))";

export function computeCommitHash(phash0: Hex, salt: Hex, creator: Address): Hex {
  return keccak256(encodePacked(["bytes32", "bytes32", "address"], [phash0, salt, creator]));
}

/** Blok penjelas yang WAJIB dikembalikan gateway supaya kreator tak menghitung
 *  dari prosa (§4-A3.5). */
export function commitHelp(): { formula: string; note: string } {
  return {
    formula: COMMIT_FORMULA,
    note:
      "phash0 = phashes[0] dari /verify (imagehash phash). salt = 32 byte acak yang " +
      "kamu simpan rahasia. creator = alamat wallet-mu. Kunci commit SEBELUM karya " +
      "publik; ungkap salt saat mint untuk membuktikan kepemilikan sejak timestamp commit.",
  };
}

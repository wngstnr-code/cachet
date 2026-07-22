/**
 * Rumus premi DIKUNCI (RFC-001 P5): integer, dibulatkan KE BAWAH, identik dengan
 * `Vault.quotePremium` on-chain. Meleset satu unit → `WrongPremium` → mint revert.
 *
 * Nilai pengikat tetap diambil dari `chain.quotePremium()` (baca on-chain), tapi
 * fungsi ini dipakai stub + sebagai referensi + verifikasi lokal.
 */

export const DEFAULT_PREMIUM_BPS = 200n; // 2%

export function quotePremium(declaredValue: bigint, bps: bigint = DEFAULT_PREMIUM_BPS): bigint {
  return (declaredValue * bps) / 10_000n; // BigInt: pembagian = floor
}

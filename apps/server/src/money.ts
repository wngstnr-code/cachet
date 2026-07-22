/**
 * Uang = string base-unit 6 desimal (RFC-001 P5). String yang MENGIKAT; angka
 * desimal hanya untuk manusia (`_display`). Jangan pernah pakai `number` untuk
 * nilai uang — floating point meleset di nilai ganjil dan mint bisa revert.
 */

export const DECIMALS = 6;

/** bigint base-unit → string tampilan "50.00" (bukan pengikat). */
export function toDisplay(base: bigint): string {
  const neg = base < 0n;
  const v = neg ? -base : base;
  const s = v.toString().padStart(DECIMALS + 1, "0");
  const int = s.slice(0, s.length - DECIMALS);
  const frac = s.slice(s.length - DECIMALS);
  return `${neg ? "-" : ""}${int}.${frac}`;
}

/** string base-unit (integer, mis. "50000000") → bigint. Tolak non-integer. */
export function parseBaseUnit(s: string): bigint {
  if (!/^\d+$/.test(s)) {
    throw new Error(`nilai uang harus string base-unit integer (6 desimal), dapat: ${s}`);
  }
  return BigInt(s);
}

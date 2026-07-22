/** 6 desimal (mUSDT). Tampilkan desimal hanya bila ada — "50", bukan "50.000000". */
export function fmtUSDT(baseUnits: bigint): string {
  const whole = baseUnits / 1_000_000n;
  const frac = baseUnits % 1_000_000n;
  if (frac === 0n) return whole.toString();
  return `${whole}.${frac.toString().padStart(6, "0").replace(/0+$/, "")}`;
}

export const shortAddr = (addr: string): string => `${addr.slice(0, 6)}…${addr.slice(-4)}`;

/** phash0 sebagai "fingerprint": 8 byte pertama, dipendekkan. */
export const shortHex = (hex: string): string => `${hex.slice(0, 6)}…${hex.slice(14, 18)}`;

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

export function fmtDate(unixSeconds: bigint | number): string {
  const d = new Date(Number(unixSeconds) * 1000);
  return `${MONTHS[d.getUTCMonth()]} ${d.getUTCDate()}, ${d.getUTCFullYear()}`;
}

export function fmtDateTime(unixSeconds: bigint | number): string {
  const d = new Date(Number(unixSeconds) * 1000);
  const hh = d.getUTCHours().toString().padStart(2, "0");
  const mm = d.getUTCMinutes().toString().padStart(2, "0");
  return `${fmtDate(unixSeconds)} ${hh}:${mm} UTC`;
}

export function certAge(mintedAt: bigint): string {
  const days = Math.floor((Date.now() / 1000 - Number(mintedAt)) / 86400);
  if (days < 1) return "less than a day";
  return days === 1 ? "1 day" : `${days} days`;
}

/** Escape untuk data on-chain yang dirender ke HTML (tokenURI, evidenceURI, dst). */
export function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

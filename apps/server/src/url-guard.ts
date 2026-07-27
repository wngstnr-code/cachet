/**
 * Guard untuk `image_url` (B4) — endpoint berbayar $0.02 yang men-`fetch` URL
 * apa pun tanpa validasi bisa dipakai memindai jaringan internal Docker
 * (engine ada di network privat). Menutup tiga hal: dial ke target privat
 * (langsung ATAU lewat DNS yang resolve ke IP privat), redirect ke target
 * privat, dan unduhan tak terbatas.
 *
 * TIDAK menutup: DNS rebinding penuh (request nyata bisa resolve ke IP
 * berbeda dari saat kita `dns.lookup`) — itu butuh pinning koneksi ke IP hasil
 * lookup, di luar cakupan perbaikan ini.
 */

import { promises as dns } from "node:dns";
import { isIPv4, isIPv6 } from "node:net";

import { errBadRequest } from "./errors.js";

const FETCH_TIMEOUT_MS = 10_000;

export function isPrivateIPv4(ip: string): boolean {
  const parts = ip.split(".").map(Number);
  if (parts.length !== 4 || parts.some((p) => Number.isNaN(p) || p < 0 || p > 255)) return true;
  const [a, b] = parts;
  if (a === 0) return true; // "this network"
  if (a === 10) return true; // RFC1918
  if (a === 100 && b >= 64 && b <= 127) return true; // CGNAT
  if (a === 127) return true; // loopback
  if (a === 169 && b === 254) return true; // link-local, termasuk metadata cloud 169.254.169.254
  if (a === 172 && b >= 16 && b <= 31) return true; // RFC1918
  if (a === 192 && b === 168) return true; // RFC1918
  if (a === 198 && b === 18) return true; // benchmarking
  if (a >= 224) return true; // multicast (224-239) + reserved (240-255)
  return false;
}

export function isPrivateIPv6(ip: string): boolean {
  const norm = ip.toLowerCase();
  if (norm === "::1" || norm === "::" || norm === "0:0:0:0:0:0:0:0" || norm === "0:0:0:0:0:0:0:1") return true;
  if (norm.startsWith("fe8") || norm.startsWith("fe9") || norm.startsWith("fea") || norm.startsWith("feb")) {
    return true; // fe80::/10 link-local
  }
  if (norm.startsWith("fc") || norm.startsWith("fd")) return true; // fc00::/7 unique local

  // IPv4-mapped (::ffff:a.b.c.d) — periksa IPv4 yang dikandungnya.
  const mapped = norm.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (mapped) return isPrivateIPv4(mapped[1]!);

  return false;
}

async function assertPublicHttpsUrl(raw: string): Promise<URL> {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw errBadRequest("image_url tidak valid");
  }

  // data: URI tidak pernah membuka koneksi jaringan — aman tanpa validasi host.
  if (url.protocol === "data:") return url;

  if (url.protocol !== "https:") {
    throw errBadRequest("image_url wajib https (atau data:)");
  }

  const hostname = url.hostname;
  if (hostname === "localhost") throw errBadRequest("image_url tidak diizinkan");
  if (isIPv4(hostname) && isPrivateIPv4(hostname)) throw errBadRequest("image_url tidak diizinkan");
  if (isIPv6(hostname) && isPrivateIPv6(hostname)) throw errBadRequest("image_url tidak diizinkan");

  let addrs: { address: string; family: number }[];
  try {
    addrs = await dns.lookup(hostname, { all: true });
  } catch {
    throw errBadRequest("image_url: gagal resolve host");
  }
  for (const { address, family } of addrs) {
    if (family === 4 && isPrivateIPv4(address)) throw errBadRequest("image_url tidak diizinkan");
    if (family === 6 && isPrivateIPv6(address)) throw errBadRequest("image_url tidak diizinkan");
  }
  return url;
}

function concat(chunks: Uint8Array[], total: number): Uint8Array {
  const out = new Uint8Array(total);
  let offset = 0;
  for (const c of chunks) {
    out.set(c, offset);
    offset += c.byteLength;
  }
  return out;
}

/** Validasi lalu unduh `raw` dengan batas ukuran & timeout. Target privat
 *  TIDAK PERNAH di-dial (divalidasi sebelum fetch apa pun) — ini yang menutup
 *  oracle status-code, bukan menyaring error sesudahnya. */
export async function fetchImageUrl(raw: string, maxBytes: number): Promise<Uint8Array> {
  const url = await assertPublicHttpsUrl(raw);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    // redirect:"manual" — redirect 3xx ke target privat akan lolos DNS-check
    // di atas tapi tidak pernah divalidasi ulang; menolak SEMUA redirect
    // menutup itu tanpa perlu mengejar tiap hop.
    let res: Response;
    try {
      res = await fetch(url, { signal: controller.signal, redirect: "manual" });
    } catch (err) {
      throw errBadRequest(`gagal fetch image_url: ${(err as Error).message}`);
    }

    if (res.status >= 300 && res.status < 400) {
      throw errBadRequest("image_url tidak boleh redirect");
    }
    if (!res.ok) {
      throw errBadRequest(`gagal fetch image_url: ${res.status}`);
    }

    const declared = res.headers.get("content-length");
    if (declared && Number(declared) > maxBytes) {
      throw errBadRequest("image_url terlalu besar");
    }

    if (!res.body) return new Uint8Array(await res.arrayBuffer());

    const reader = res.body.getReader();
    const chunks: Uint8Array[] = [];
    let total = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel();
        throw errBadRequest("image_url terlalu besar");
      }
      chunks.push(value);
    }
    return concat(chunks, total);
  } finally {
    clearTimeout(timer);
  }
}

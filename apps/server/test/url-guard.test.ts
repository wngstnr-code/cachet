import { afterEach, describe, expect, it, vi } from "vitest";

import { fetchImageUrl, isPrivateIPv4, isPrivateIPv6 } from "../src/url-guard.js";

/** Import ulang url-guard.ts dengan `node:dns` ter-mock (`vi.doMock`) di atas
 *  cache modul biasa — spesifier berupa VARIABEL (bukan literal) supaya tsc
 *  tidak mencoba me-resolve tag query-string sebagai path modul sungguhan;
 *  tipe hasilnya tetap dicek terhadap modul asli lewat `typeof import(...)`. */
function importFreshUrlGuard(tag: string): Promise<typeof import("../src/url-guard.js")> {
  const specifier = `../src/url-guard.js?${tag}`;
  return import(specifier) as Promise<typeof import("../src/url-guard.js")>;
}

describe("isPrivateIPv4 (B4)", () => {
  it.each([
    ["127.0.0.1", true], // loopback
    ["10.1.2.3", true], // RFC1918
    ["172.16.5.5", true], // RFC1918
    ["172.31.255.255", true],
    ["172.32.0.1", false], // di luar 172.16-31
    ["192.168.1.1", true], // RFC1918
    ["169.254.169.254", true], // metadata cloud
    ["100.64.0.1", true], // CGNAT
    ["0.0.0.0", true],
    ["224.0.0.1", true], // multicast
    ["8.8.8.8", false],
    ["1.1.1.1", false],
  ])("%s → %s", (ip, expected) => {
    expect(isPrivateIPv4(ip)).toBe(expected);
  });
});

describe("isPrivateIPv6 (B4)", () => {
  it.each([
    ["::1", true],
    ["::", true],
    ["fe80::1", true], // link-local
    ["fc00::1", true], // unique local
    ["fd12::1", true],
    ["::ffff:127.0.0.1", true], // IPv4-mapped loopback
    ["::ffff:8.8.8.8", false],
    ["2606:4700:4700::1111", false], // Cloudflare publik
  ])("%s → %s", (ip, expected) => {
    expect(isPrivateIPv6(ip)).toBe(expected);
  });
});

describe("fetchImageUrl — validasi SEBELUM dial (B4)", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.doUnmock("node:dns");
  });

  it("menolak http:// (bukan https)", async () => {
    const spy = vi.fn();
    vi.stubGlobal("fetch", spy);
    await expect(fetchImageUrl("http://example.com/a.png", 1024)).rejects.toMatchObject({
      code: "BAD_REQUEST",
    });
    expect(spy).not.toHaveBeenCalled();
  });

  it("menolak IP literal privat tanpa perlu DNS", async () => {
    const spy = vi.fn();
    vi.stubGlobal("fetch", spy);
    await expect(fetchImageUrl("https://127.0.0.1:8100/healthz", 1024)).rejects.toMatchObject({
      code: "BAD_REQUEST",
    });
    await expect(fetchImageUrl("https://169.254.169.254/latest/meta-data", 1024)).rejects.toMatchObject({
      code: "BAD_REQUEST",
    });
    expect(spy).not.toHaveBeenCalled();
  });

  it("menolak hostname 'localhost'", async () => {
    const spy = vi.fn();
    vi.stubGlobal("fetch", spy);
    await expect(fetchImageUrl("https://localhost/x.png", 1024)).rejects.toMatchObject({ code: "BAD_REQUEST" });
    expect(spy).not.toHaveBeenCalled();
  });

  it("data: URI lolos tanpa DNS/fetch (tak ada koneksi jaringan)", async () => {
    const bytes = new Uint8Array([1, 2, 3]);
    const b64 = Buffer.from(bytes).toString("base64");
    // Tidak perlu mock fetch: Node fetch native menangani data: tanpa jaringan.
    const out = await fetchImageUrl(`data:application/octet-stream;base64,${b64}`, 1024);
    expect(Array.from(out)).toEqual([1, 2, 3]);
  });

  it("hostname publik yang DNS-nya resolve ke IP privat → ditolak (bukan cuma cek string hostname)", async () => {
    vi.doMock("node:dns", () => ({
      promises: { lookup: vi.fn().mockResolvedValue([{ address: "169.254.169.254", family: 4 }]) },
    }));
    const { fetchImageUrl: guarded } = await importFreshUrlGuard("rebind-dns-private");
    const spy = vi.fn();
    vi.stubGlobal("fetch", spy);
    await expect(guarded("https://looks-public.test/a.png", 1024)).rejects.toMatchObject({ code: "BAD_REQUEST" });
    expect(spy).not.toHaveBeenCalled();
  });

  it("hostname publik yang DNS-nya resolve ke IP publik → lolos guard, fetch dipanggil", async () => {
    vi.doMock("node:dns", () => ({
      promises: { lookup: vi.fn().mockResolvedValue([{ address: "8.8.8.8", family: 4 }]) },
    }));
    const { fetchImageUrl: guarded } = await importFreshUrlGuard("rebind-dns-public");
    const body = new ReadableStream({
      start(controller) {
        controller.enqueue(new Uint8Array([9, 9]));
        controller.close();
      },
    });
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(new Response(body, { status: 200, headers: { "content-length": "2" } })),
    );
    const out = await guarded("https://really-public.test/a.png", 1024);
    expect(Array.from(out)).toEqual([9, 9]);
  });

  it("menolak redirect (3xx) alih-alih mengikutinya", async () => {
    vi.doMock("node:dns", () => ({
      promises: { lookup: vi.fn().mockResolvedValue([{ address: "8.8.8.8", family: 4 }]) },
    }));
    const { fetchImageUrl: guarded } = await importFreshUrlGuard("rebind-dns-redirect");
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 302 })));
    await expect(guarded("https://really-public.test/a.png", 1024)).rejects.toMatchObject({
      code: "BAD_REQUEST",
    });
  });

  it("menolak unduhan yang melebihi maxBytes walau content-length kosong/salah", async () => {
    vi.doMock("node:dns", () => ({
      promises: { lookup: vi.fn().mockResolvedValue([{ address: "8.8.8.8", family: 4 }]) },
    }));
    const { fetchImageUrl: guarded } = await importFreshUrlGuard("rebind-dns-oversize");
    const big = new Uint8Array(2000);
    const body = new ReadableStream({
      start(controller) {
        controller.enqueue(big);
        controller.close();
      },
    });
    // Sengaja TANPA content-length, supaya jelas ini ditegakkan dari stream, bukan header.
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(body, { status: 200 })));
    await expect(guarded("https://really-public.test/big.png", 1024)).rejects.toMatchObject({
      code: "BAD_REQUEST",
    });
  });
});

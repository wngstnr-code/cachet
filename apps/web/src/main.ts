import "@fontsource-variable/source-serif-4";
import "@fontsource-variable/jetbrains-mono";
import "./style.css";

import type { CertSummary } from "./chain";
import {
  CERT_PAGE_SIZE,
  CertNotFoundError,
  loadCert,
  loadCertCount,
  loadCertPage,
  loadImage,
} from "./chain";
import type { ChainConfig, ChainKey } from "./config";
import { CHAINS, DEFAULT_CHAIN, LEGACY_CHAIN, certPath, isChainKey } from "./config";
import type { StatusFilter } from "./views";
import {
  STATUS_FILTERS,
  certView,
  galleryLoadingView,
  galleryView,
  homeView,
  loadingView,
  notFoundView,
  rpcErrorView,
} from "./views";

const app = document.getElementById("app")!;

type Route =
  | { kind: "home"; chain: ChainConfig }
  | { kind: "gallery"; chain: ChainConfig }
  | { kind: "cert"; chain: ChainConfig; idStr: string }
  | { kind: "unknown"; chain: ChainConfig; idStr: string };

/** Router path-based. Vercel rewrite semua path ke index.html.
 *
 *    /                      beranda, DEFAULT_CHAIN
 *    /mainnet · /testnet    beranda chain tsb
 *    /<chain>/cert/:id      sertifikat
 *    /cert/:id              BENTUK LAMA -> LEGACY_CHAIN (testnet)
 *
 *  Bentuk lama dipertahankan dan TIDAK boleh dialihkan ke mainnet: tautan
 *  seperti /cert/8 sudah tersebar di README dan merujuk sertifikat testnet
 *  tertentu. Memetakannya ke mainnet akan menampilkan sertifikat lain — atau
 *  halaman kosong — tanpa satu pun tanda bahwa artinya berubah. */
function parseRoute(pathname: string): Route {
  const path = pathname.replace(/\/+$/, "") || "/";

  if (path === "/") return { kind: "home", chain: CHAINS[DEFAULT_CHAIN] };

  const gallery = path.match(/^\/([a-z]+)\/certificates$/);
  if (gallery && isChainKey(gallery[1]!)) {
    return { kind: "gallery", chain: CHAINS[gallery[1] as ChainKey] };
  }

  const scoped = path.match(/^\/([a-z]+)(?:\/cert\/(\d+))?$/);
  if (scoped && isChainKey(scoped[1]!)) {
    const chain = CHAINS[scoped[1] as ChainKey];
    return scoped[2] ? { kind: "cert", chain, idStr: scoped[2] } : { kind: "home", chain };
  }

  const legacy = path.match(/^\/cert\/(\d+)$/);
  if (legacy) return { kind: "cert", chain: CHAINS[LEGACY_CHAIN], idStr: legacy[1]! };

  return { kind: "unknown", chain: CHAINS[DEFAULT_CHAIN], idStr: path.replace(/^\//, "") };
}

async function route(): Promise<void> {
  const r = parseRoute(location.pathname);

  if (r.kind === "home") {
    document.title = `Cachet · ${r.chain.name}`;
    app.innerHTML = homeView(r.chain);
    bindLookup(r.chain);
    return;
  }

  if (r.kind === "gallery") {
    await renderGallery(r.chain);
    return;
  }

  if (r.kind === "unknown") {
    app.innerHTML = notFoundView(r.chain, r.idStr);
    return;
  }

  const { chain, idStr } = r;
  const certId = BigInt(idStr);
  const pathAtStart = location.pathname;
  document.title = `Certificate #${certId} · ${chain.name} · Cachet`;
  app.innerHTML = loadingView(chain);

  try {
    const cert = await loadCert(chain, certId);
    // Navigasi bisa terjadi selagi read berjalan (mis. pindah chain). Menulis
    // hasil yang sudah tidak diminta akan menampilkan sertifikat chain lama.
    if (location.pathname !== pathAtStart) return;

    // Gambar dimuat SETELAH data chain — halaman tidak menunggu IPFS.
    app.innerHTML = certView(cert, null);
    bindCopy();
    const image = await loadImage(cert.tokenURI);
    if (image && location.pathname === pathAtStart) {
      app.innerHTML = certView(cert, image);
      bindCopy();
    }
  } catch (err) {
    if (location.pathname !== pathAtStart) return;
    if (err instanceof CertNotFoundError) {
      app.innerHTML = notFoundView(chain, idStr);
    } else {
      console.error(err);
      app.innerHTML = rpcErrorView(chain, idStr);
    }
  }
}

/** State galeri disimpan di modul, bukan di-refetch tiap filter: filter hanya
 *  menyaring yang SUDAH dimuat, jadi menekan tombol tidak boleh memanggil chain
 *  lagi. "Load older" yang menambah data, bukan filter. */
let gallery: { chainId: number; rows: CertSummary[]; total: bigint; nextId: bigint } | null = null;

function currentFilter(): StatusFilter {
  const q = new URLSearchParams(location.search).get("status") ?? "ALL";
  return (STATUS_FILTERS as readonly string[]).includes(q) ? (q as StatusFilter) : "ALL";
}

function countByStatus(rows: CertSummary[]): Record<string, number> {
  const out: Record<string, number> = {};
  for (const r of rows) out[r.status] = (out[r.status] ?? 0) + 1;
  return out;
}

async function renderGallery(chain: ChainConfig): Promise<void> {
  document.title = `Certificates · ${chain.name} · Cachet`;

  // Cache per chain: berpindah jaringan harus memuat ulang, bukan menampilkan
  // sertifikat chain sebelumnya dengan label chain baru.
  if (!gallery || gallery.chainId !== chain.chainId) {
    app.innerHTML = galleryLoadingView(chain);
    try {
      const total = await loadCertCount(chain);
      const rows = total > 0n ? await loadCertPage(chain, total, CERT_PAGE_SIZE) : [];
      gallery = { chainId: chain.chainId, rows, total, nextId: total - BigInt(rows.length) };
    } catch (err) {
      console.error(err);
      app.innerHTML = rpcErrorView(chain, "");
      return;
    }
  }

  paintGallery(chain);
}

/** Isi thumbnail SETELAH grid tampil. Tiap tokenURI harus di-fetch dan
 *  di-parse dulu untuk mendapat field `image`, jadi melakukannya saat render
 *  akan menahan seluruh halaman demi satu URI lambat. Kegagalan per kartu
 *  berhenti di kartu itu — grid tetap berdiri. */
async function hydrateThumbs(): Promise<void> {
  const slots = [...document.querySelectorAll<HTMLElement>(".gcard-art[data-token-uri]")];
  const CHUNK = 6;
  for (let i = 0; i < slots.length; i += CHUNK) {
    await Promise.all(
      slots.slice(i, i + CHUNK).map(async (slot) => {
        const uri = slot.dataset.tokenUri;
        if (!uri) return;
        const image = await loadImage(uri);
        // Halaman bisa sudah berganti selagi fetch berjalan.
        if (!slot.isConnected) return;
        slot.innerHTML = image
          ? `<img loading="lazy" src="${image}" alt="" />`
          : `<span class="gcard-noart">no preview</span>`;
        delete slot.dataset.tokenUri;
      }),
    );
  }
}

function paintGallery(chain: ChainConfig): void {
  if (!gallery) return;
  app.innerHTML = galleryView(
    chain,
    gallery.rows,
    currentFilter(),
    countByStatus(gallery.rows),
    gallery.total,
    gallery.nextId > 0n,
  );

  void hydrateThumbs();

  document.getElementById("load-more")?.addEventListener("click", async (e) => {
    const btn = e.currentTarget as HTMLButtonElement;
    btn.disabled = true;
    btn.textContent = "Loading…";
    try {
      const more = await loadCertPage(chain, gallery!.nextId, CERT_PAGE_SIZE);
      gallery!.rows.push(...more);
      gallery!.nextId -= BigInt(more.length);
      paintGallery(chain);
    } catch (err) {
      console.error(err);
      btn.disabled = false;
      btn.textContent = "Retry";
    }
  });
}

function bindLookup(chain: ChainConfig): void {
  const form = document.getElementById("lookup-form") as HTMLFormElement | null;
  form?.addEventListener("submit", (e) => {
    e.preventDefault();
    const raw = new FormData(form).get("certId")?.toString().trim() ?? "";
    if (!/^\d+$/.test(raw)) {
      document.getElementById("lookup-error")!.textContent =
        "Certificate IDs are positive numbers.";
      return;
    }
    navigate(certPath(chain.key, raw));
  });
}

function bindCopy(): void {
  for (const btn of document.querySelectorAll<HTMLButtonElement>(".copy-btn")) {
    btn.addEventListener("click", async () => {
      await navigator.clipboard.writeText(btn.dataset.copy ?? "");
      const prev = btn.textContent;
      btn.textContent = "copied";
      setTimeout(() => (btn.textContent = prev), 1200);
    });
  }
}

function navigate(path: string): void {
  history.pushState(null, "", path);
  void route();
}

// Link internal (brand, "look up another") tanpa full reload.
document.addEventListener("click", (e) => {
  const a = (e.target as HTMLElement).closest("a");
  if (!a || a.target === "_blank") return;
  const href = a.getAttribute("href");
  if (href && href.startsWith("/") && !href.startsWith("//")) {
    e.preventDefault();
    navigate(href);
  }
});

window.addEventListener("popstate", () => void route());
void route();

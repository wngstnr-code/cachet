import "@fontsource-variable/source-serif-4";
import "@fontsource-variable/jetbrains-mono";
import "./style.css";

import { CertNotFoundError, loadCert, loadImage } from "./chain";
import type { ChainConfig, ChainKey } from "./config";
import { CHAINS, DEFAULT_CHAIN, LEGACY_CHAIN, certPath, isChainKey } from "./config";
import { certView, homeView, loadingView, notFoundView, rpcErrorView } from "./views";

const app = document.getElementById("app")!;

type Route =
  | { kind: "home"; chain: ChainConfig }
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

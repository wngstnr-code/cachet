import "@fontsource-variable/source-serif-4";
import "@fontsource-variable/jetbrains-mono";
import "./style.css";

import { CertNotFoundError, loadCert, loadImage } from "./chain";
import { certView, homeView, loadingView, notFoundView, rpcErrorView } from "./views";

const app = document.getElementById("app")!;

/** Router path-based: "/" dan "/cert/:id". Vercel rewrite semua ke index.html. */
async function route(): Promise<void> {
  const match = location.pathname.match(/^\/cert\/(\d+)$/);
  if (!match) {
    if (location.pathname !== "/") {
      app.innerHTML = notFoundView(location.pathname.replace(/^\/cert\//, ""));
      return;
    }
    app.innerHTML = homeView();
    bindLookup();
    return;
  }

  const idStr = match[1]!;
  const certId = BigInt(idStr);
  document.title = `Certificate #${certId} — Cachet`;
  app.innerHTML = loadingView(certId);

  try {
    const cert = await loadCert(certId);
    // Gambar dimuat SETELAH data chain — halaman tidak menunggu IPFS.
    app.innerHTML = certView(cert, null);
    bindCopy();
    const image = await loadImage(cert.tokenURI);
    if (image && location.pathname === `/cert/${certId}`) {
      app.innerHTML = certView(cert, image);
      bindCopy();
    }
  } catch (err) {
    if (err instanceof CertNotFoundError) {
      app.innerHTML = notFoundView(idStr);
    } else {
      console.error(err);
      app.innerHTML = rpcErrorView(idStr);
    }
  }
}

function bindLookup(): void {
  const form = document.getElementById("lookup-form") as HTMLFormElement | null;
  form?.addEventListener("submit", (e) => {
    e.preventDefault();
    const raw = new FormData(form).get("certId")?.toString().trim() ?? "";
    if (!/^\d+$/.test(raw)) {
      document.getElementById("lookup-error")!.textContent =
        "Certificate IDs are positive numbers.";
      return;
    }
    navigate(`/cert/${raw}`);
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

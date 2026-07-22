import type { CertView, ChallengeRow, CertStatus } from "./chain";
import { ChallengeStatus, deriveStatus, resolveURI } from "./chain";
import { addresses, explorerAddress, explorerTx, sourcifyAddress } from "./config";
import { certAge, esc, fmtDate, fmtDateTime, fmtUSDT, shortAddr, shortHex } from "./format";

const CERT_ADDR = addresses.contracts.certificate;

/** URI panjang (data URI ~KB) jangan di-dump mentah — pendekkan + terangkan.
 *  Untuk data URI, fakta "tersimpan on-chain" justru poin jualnya. */
function shortURI(uri: string): string {
  if (uri.startsWith("data:")) {
    const kind = uri.slice(5, uri.indexOf(";") > 0 ? uri.indexOf(";") : 40);
    return `data URI (${kind}, ${uri.length.toLocaleString("en-US")} chars, stored fully on-chain)`;
  }
  return uri.length > 80 ? `${uri.slice(0, 72)}…` : uri;
}

function shell(inner: string, title = ""): string {
  return `
    <div class="page">
      <header class="masthead">
        <a class="brand" href="/">Cachet</a>
        ${title ? `<span class="sep">/</span><h1>${title}</h1>` : ""}
        <span class="net">${esc(addresses.chain.name)} · chain ${addresses.chain.chainId}</span>
      </header>
      ${inner}
    </div>`;
}

// ── Root lookup: tanpa masthead, kartu di tengah layar ─────────────────
export function homeView(): string {
  return `
    <div class="home">
      <div class="lookup">
        <div class="brand">Cachet</div>
        <p>Public registry of first-seen certificates on ${esc(addresses.chain.name)}.
           Every certificate on this site is verifiable on-chain. You do not need to trust Cachet.</p>
        <form id="lookup-form">
          <input name="certId" inputmode="numeric" placeholder="Certificate ID" autofocus />
          <button type="submit">View certificate</button>
        </form>
        <div class="form-error" id="lookup-error"></div>
        <div class="home-net">${esc(addresses.chain.name)} · chain ${addresses.chain.chainId}</div>
      </div>
    </div>`;
}

// ── Loading / error / not found ────────────────────────────────────────
export function loadingView(): string {
  return shell(
    `<div class="hero skeleton">
       <div><div class="block"></div></div>
       <div>
         <div class="bar narrow"></div><div class="bar wide"></div><div class="bar"></div>
         <div class="bar wide"></div><div class="bar narrow"></div><div class="bar"></div>
       </div>
     </div>`,
  );
}

export function notFoundView(certId: string): string {
  return shell(`
    <div class="page-status">
      <h2>Certificate #${esc(certId)} does not exist in the registry</h2>
      <p>No certificate with this ID has been minted on ${esc(addresses.chain.name)}.
         You can verify this yourself against the contract.</p>
      <p><a class="ext" href="${explorerAddress(CERT_ADDR)}" target="_blank" rel="noopener">Certificate contract on OKX explorer</a></p>
      <p><a href="/">&larr; Look up another certificate</a></p>
    </div>`);
}

export function rpcErrorView(certId: string): string {
  return shell(`
    <div class="page-status">
      <h2>Could not reach ${esc(addresses.chain.name)}</h2>
      <p>This page reads certificate data directly from the chain, and the RPC endpoint
         did not respond. The certificate itself is unaffected; the chain remains the
         source of truth.</p>
      <p><a class="ext" href="${explorerAddress(CERT_ADDR)}" target="_blank" rel="noopener">Check the contract on OKX explorer instead</a></p>
      <p><a href="/cert/${esc(certId)}">Try again</a></p>
    </div>`);
}

// ── Halaman sertifikat ─────────────────────────────────────────────────
/** Baris STATUS: format identik dengan baris kv lain — kata status (mono,
 *  berwarna semantik) + aside italic singkat + link bukti bila ada. */
function statusRow(c: CertView, status: CertStatus): string {
  let word: string;
  let aside = "";
  let link = "";
  switch (status) {
    case "ACTIVE":
      word = "Coverage active";
      break;
    case "WAITING":
      word = "Waiting period";
      aside = `coverage active from ${fmtDateTime(c.coverageStart)}`;
      break;
    case "REVOKED": {
      word = "Revoked";
      aside = "upheld challenge; coverage, when in force, is paid to the holder at resolution";
      const lost = c.challenges.find((ch) => ch.status === ChallengeStatus.UpheldChallengerWon);
      if (lost?.resolvedTx) {
        link = ` <a class="ext" href="${explorerTx(lost.resolvedTx)}" target="_blank" rel="noopener">view ruling</a>`;
      }
      break;
    }
    case "EXPIRED":
      word = "Coverage expired";
      aside = `ended ${fmtDate(c.coverageEnd)}; the first-seen record remains valid`;
      break;
    case "NOT_INSURABLE":
      word = "Not insurable";
      aside = "records first-seen only, carries no coverage";
      break;
  }
  return `<div><span class="label">Status</span>
    <div class="value"><span class="status-word" data-status="${status}">${word}</span>${link}
      ${aside ? `<span class="aside">${aside}</span>` : ""}
    </div></div>`;
}

function challengeLabel(ch: ChallengeRow): string {
  switch (ch.status) {
    case ChallengeStatus.Open:
      return "Challenge opened, awaiting resolution";
    case ChallengeStatus.UpheldChallengerWon:
      return "Resolved: challenge upheld, certificate revoked";
    case ChallengeStatus.DismissedChallengerLost:
      return "Resolved: challenge dismissed, certificate survived";
    default:
      return "Unknown";
  }
}

function challengeRows(c: CertView): string {
  if (c.challenges.length === 0) {
    return `<div class="empty-state">No challenges have been opened against this certificate.</div>`;
  }
  const rows = c.challenges
    .map((ch) => {
      const tx = ch.resolvedTx ?? ch.openedTx;
      const txCell = tx
        ? `<a class="ext" href="${explorerTx(tx)}" target="_blank" rel="noopener">${tx.slice(0, 10)}…</a>`
        : `<a class="ext" href="${explorerAddress(addresses.contracts.challengeManager)}" target="_blank" rel="noopener">contract events</a>`;
      return `<tr>
        <td class="mono">${fmtDateTime(ch.openedAt)}</td>
        <td>${challengeLabel(ch)}</td>
        <td class="mono">${shortAddr(ch.challenger)}</td>
        <td class="mono">${txCell}</td>
      </tr>`;
    })
    .join("");
  return `<table>
    <thead><tr>
      <th class="label">Date</th><th class="label">Event</th>
      <th class="label">Challenger</th><th class="label">Transaction</th>
    </tr></thead>
    <tbody>${rows}</tbody>
  </table>`;
}

export function certView(c: CertView, imageURL: string | null): string {
  const status = deriveStatus(c);

  const artwork = imageURL
    ? `<img src="${esc(imageURL)}" alt="Certified asset for certificate #${c.certId}" />
       <figcaption>
         <span class="cap-label">asset from tokenURI</span>
         <span class="cap-value">${esc(shortURI(c.tokenURI))}</span>
       </figcaption>`
    : `<div class="placeholder">
         Asset preview unavailable: the metadata URI does not resolve to an image.
         <span class="uri">${esc(shortURI(c.tokenURI))}</span>
       </div>`;

  return shell(
    `
    <div class="hero">
      <figure class="artwork ${status === "REVOKED" ? "is-revoked" : ""}">${artwork}</figure>

      <div class="certmeta">
        <div class="kv">
          ${statusRow(c, status)}
          <div><span class="label">Certificate #</span><div class="value">${c.certId}</div></div>
          <div><span class="label">Declared value</span><div class="value">${fmtUSDT(c.declaredValue)} USDT</div></div>
          <div><span class="label">Coverage period</span>
            <div class="value">${fmtDate(c.coverageStart)} &rarr; ${fmtDate(c.coverageEnd)}</div></div>
          <div><span class="label">Certificate age</span><div class="value">${certAge(c.mintedAt)}</div></div>
          <div><span class="label">Challenges survived</span><div class="value">${c.challengesSurvived}</div></div>
          <div><span class="label">Creator</span>
            <div class="value">${shortAddr(c.creator)}
              <button class="copy-btn" data-copy="${c.creator}">copy</button>
              <a class="ext" href="${explorerAddress(c.creator)}" target="_blank" rel="noopener">explorer</a>
            </div></div>
          <div><span class="label">Current holder</span>
            <div class="value">${shortAddr(c.holder)}
              <button class="copy-btn" data-copy="${c.holder}">copy</button>
              <a class="ext" href="${explorerAddress(c.holder)}" target="_blank" rel="noopener">explorer</a>
              <span class="aside">coverage follows this holder</span>
            </div></div>
          <div><span class="label">Registry fingerprint</span>
            <div class="value">${shortHex(c.phash0)}
              <span class="aside">perceptual hash, first 8 bytes</span>
            </div></div>
        </div>
      </div>
    </div>

    <section>
      <h2>Challenge history</h2>
      ${challengeRows(c)}
    </section>

    <section>
      <h2>Verify independently</h2>
      <div class="verify-links">
        <a class="ext" href="${explorerAddress(CERT_ADDR)}" target="_blank" rel="noopener">
          <span class="what">Certificate contract</span><span class="where">OKX explorer</span></a>
        <a class="ext" href="${explorerAddress(CERT_ADDR)}/nft/${c.certId}" target="_blank" rel="noopener">
          <span class="what">This token</span><span class="where">OKX explorer</span></a>
        <a class="ext" href="${sourcifyAddress(CERT_ADDR)}" target="_blank" rel="noopener">
          <span class="what">Contract source code</span><span class="where">Sourcify</span></a>
        ${
          resolveURI(c.assetURI)
            ? `<a class="ext" href="${esc(resolveURI(c.assetURI)!)}" target="_blank" rel="noopener">
                 <span class="what">Registered asset URI</span><span class="where">${esc(shortURI(c.assetURI))}</span></a>`
            : ""
        }
      </div>
    </section>

    <footer class="fineprint">
      First-seen in the Cachet registry at <span class="mono">${fmtDateTime(c.registeredAt)}</span>.
      This records when the work was first registered with Cachet. It is <em>not</em> a claim of
      originality across the internet. Coverage is a collateralized guarantee, capped at
      ${fmtUSDT(BigInt(addresses.params.maxDeclaredValue))} USDT during bootstrap, and follows the
      current NFT holder. Disputes are adjudicated by a resolver after a public liveness window.
    </footer>
    `,
  );
}

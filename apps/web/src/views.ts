import type { CertView, ChallengeRow, CertStatus } from "./chain";
import { ChallengeStatus, deriveStatus, resolveURI } from "./chain";
import type { ChainConfig, ChainKey } from "./config";
import { CHAINS, CHAIN_KEYS, explorerAddress, explorerTx, homePath, sourcifyAddress } from "./config";
import { certAge, esc, fmtDate, fmtDateTime, fmtUSDT, shortAddr, shortHex } from "./format";

/** Pemilih jaringan. Selalu tampil, bahkan saat tidak ada yang bisa dipilih lagi:
 *  pengunjung harus bisa tahu sedang melihat chain mana TANPA menekan apa pun.
 *  Setiap opsi menuju BERANDA chain itu — lihat homePath() untuk alasannya. */
function chainSwitch(active: ChainKey): string {
  const opts = CHAIN_KEYS.map((k) => {
    const c = CHAINS[k];
    const on = k === active;
    return `<a class="chain-opt${on ? " is-active" : ""}" href="${homePath(k)}"
              ${on ? 'aria-current="page"' : ""} data-testnet="${c.isTestnet}"
              title="${esc(c.name)} · chain ${c.chainId}">${esc(c.name)}</a>`;
  }).join("");
  return `<nav class="chain-switch" aria-label="Network">${opts}</nav>`;
}

/** Peringatan testnet. BUKAN hiasan: jaminan di testnet berupa token faucet,
 *  jadi sertifikat di sana tidak menjamin apa pun secara ekonomi. Menampilkannya
 *  sama persis dengan sertifikat mainnet akan menyesatkan pembaca. */
function testnetNotice(c: ChainConfig): string {
  if (!c.isTestnet) return "";
  return `<div class="net-warning" role="note">
      <strong>Testnet certificate.</strong> The collateral behind this one is
      <span class="mono">${esc(c.payTokenSymbol)}</span> — a test token anyone can mint for free.
      Read this page as a demonstration of the mechanism, not as evidence that money is at stake.
      <a href="${homePath("mainnet")}">Look up a ${esc(CHAINS.mainnet.name)} certificate instead</a>
    </div>`;
}

/** URI panjang (data URI ~KB) jangan di-dump mentah — pendekkan + terangkan.
 *  Untuk data URI, fakta "tersimpan on-chain" justru poin jualnya. */
function shortURI(uri: string): string {
  if (uri.startsWith("data:")) {
    const kind = uri.slice(5, uri.indexOf(";") > 0 ? uri.indexOf(";") : 40);
    return `data URI (${kind}, ${uri.length.toLocaleString("en-US")} chars, stored fully on-chain)`;
  }
  return uri.length > 80 ? `${uri.slice(0, 72)}…` : uri;
}

function shell(c: ChainConfig, inner: string, title = ""): string {
  return `
    <div class="page">
      <header class="masthead">
        <a class="brand" href="${homePath(c.key)}"><img class="brand-logo" src="/cachet-logo.svg" alt="" />Cachet</a>
        ${title ? `<span class="sep">/</span><h1>${title}</h1>` : ""}
        ${chainSwitch(c.key)}
      </header>
      ${testnetNotice(c)}
      ${inner}
    </div>`;
}

// ── Root lookup: tanpa masthead, kartu di tengah layar ─────────────────
export function homeView(c: ChainConfig): string {
  const collateral = c.isTestnet
    ? `Collateral on this network is <span class="mono">${esc(c.payTokenSymbol)}</span>, a freely
       mintable test token — the mechanism is real, the money is not.`
    : `Certificates here are backed by <span class="mono">${esc(c.payTokenSymbol)}</span> held in a
       vault that has no withdraw function, not even for us.`;
  return `
    <div class="home">
      <div class="lookup">
        <div class="brand"><img class="brand-logo brand-logo-lg" src="/cachet-logo.svg" alt="" />Cachet</div>
        ${chainSwitch(c.key)}
        <p>Public registry of first-seen certificates on ${esc(c.name)}.
           Every certificate on this site is verifiable on-chain. You do not need to trust Cachet.</p>
        <p class="home-collateral${c.isTestnet ? " is-testnet" : ""}">${collateral}</p>
        <form id="lookup-form">
          <input name="certId" inputmode="numeric" placeholder="Certificate ID" autofocus />
          <button type="submit">View certificate</button>
        </form>
        <div class="form-error" id="lookup-error"></div>
        <div class="home-net">${esc(c.name)} · chain ${c.chainId}</div>
      </div>
    </div>`;
}

// ── Loading / error / not found ────────────────────────────────────────
export function loadingView(c: ChainConfig): string {
  return shell(
    c,
    `<div class="hero skeleton">
       <div><div class="block"></div></div>
       <div>
         <div class="bar narrow"></div><div class="bar wide"></div><div class="bar"></div>
         <div class="bar wide"></div><div class="bar narrow"></div><div class="bar"></div>
       </div>
     </div>`,
  );
}

export function notFoundView(c: ChainConfig, certId: string): string {
  const other = c.key === "mainnet" ? CHAINS.testnet : CHAINS.mainnet;
  return shell(
    c,
    `<div class="page-status">
      <h2>Certificate #${esc(certId)} does not exist in the registry</h2>
      <p>No certificate with this ID has been minted on ${esc(c.name)} (chain ${c.chainId}).
         You can verify this yourself against the contract.</p>
      <p class="aside">Certificate IDs are per-network: #${esc(certId)} on ${esc(other.name)}
         would be a different certificate, not this one.</p>
      <p><a class="ext" href="${explorerAddress(c, c.contracts.certificate)}" target="_blank" rel="noopener">Certificate contract on the explorer</a></p>
      <p><a href="${homePath(c.key)}">&larr; Look up another certificate</a></p>
    </div>`,
  );
}

export function rpcErrorView(c: ChainConfig, certId: string): string {
  return shell(
    c,
    `<div class="page-status">
      <h2>Could not reach ${esc(c.name)}</h2>
      <p>This page reads certificate data directly from the chain, and the RPC endpoint
         did not respond. The certificate itself is unaffected; the chain remains the
         source of truth.</p>
      <p><a class="ext" href="${explorerAddress(c, c.contracts.certificate)}" target="_blank" rel="noopener">Check the contract on the explorer instead</a></p>
      <p><a href="${certPathOf(c.key, certId)}">Try again</a></p>
    </div>`,
  );
}

const certPathOf = (k: ChainKey, id: string): string => `/${k}/cert/${id}`;

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
        link = ` <a class="ext" href="${explorerTx(c.chain, lost.resolvedTx)}" target="_blank" rel="noopener">view ruling</a>`;
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
        ? `<a class="ext" href="${explorerTx(c.chain, tx)}" target="_blank" rel="noopener">${tx.slice(0, 10)}…</a>`
        : `<a class="ext" href="${explorerAddress(c.chain, c.chain.contracts.challengeManager)}" target="_blank" rel="noopener">contract events</a>`;
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
  const chain = c.chain;
  const CERT_ADDR = chain.contracts.certificate;

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
    chain,
    `
    <div class="hero">
      <figure class="artwork ${status === "REVOKED" ? "is-revoked" : ""}">${artwork}</figure>

      <div class="certmeta">
        <div class="kv">
          ${statusRow(c, status)}
          <div><span class="label">Certificate #</span><div class="value">${c.certId}
              <span class="aside">on ${esc(chain.name)}, chain ${chain.chainId}</span>
            </div></div>
          <div><span class="label">Declared value</span>
            <div class="value">${fmtUSDT(c.declaredValue)} ${esc(chain.payTokenSymbol)}</div></div>
          <div><span class="label">Coverage period</span>
            <div class="value">${fmtDate(c.coverageStart)} &rarr; ${fmtDate(c.coverageEnd)}</div></div>
          <div><span class="label">Certificate age</span><div class="value">${certAge(c.mintedAt)}</div></div>
          <div><span class="label">Challenges survived</span><div class="value">${c.challengesSurvived}</div></div>
          <div><span class="label">Creator</span>
            <div class="value">${shortAddr(c.creator)}
              <button class="copy-btn" data-copy="${c.creator}">copy</button>
              <a class="ext" href="${explorerAddress(chain, c.creator)}" target="_blank" rel="noopener">explorer</a>
            </div></div>
          <div><span class="label">Current holder</span>
            <div class="value">${shortAddr(c.holder)}
              <button class="copy-btn" data-copy="${c.holder}">copy</button>
              <a class="ext" href="${explorerAddress(chain, c.holder)}" target="_blank" rel="noopener">explorer</a>
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
        <a class="ext" href="${explorerAddress(chain, CERT_ADDR)}" target="_blank" rel="noopener">
          <span class="what">Certificate contract</span><span class="where">${esc(chain.name)} explorer</span></a>
        <a class="ext" href="${explorerAddress(chain, CERT_ADDR)}/nft/${c.certId}" target="_blank" rel="noopener">
          <span class="what">This token</span><span class="where">${esc(chain.name)} explorer</span></a>
        <a class="ext" href="${sourcifyAddress(chain, CERT_ADDR)}" target="_blank" rel="noopener">
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
      ${fmtUSDT(c.maxDeclaredValue)} ${esc(chain.payTokenSymbol)} on this network — read live from
      the contract, not from this page — and follows the current NFT holder. A claim can only ever
      pay what the vault actually holds. Disputes are adjudicated by
      ${chain.isTestnet ? "a single resolver key" : "a 2-of-3 multisig held by the operator"}
      after a public liveness window; that is centralized adjudication, not a trustless one.
    </footer>
    `,
  );
}

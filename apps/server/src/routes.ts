/**
 * Endpoint REST §3.3. Semua handler menerima Deps yang disuntik (test memakai
 * FakeEngine + StubChain langsung). Semua endpoint mutasi idempotent bila diberi
 * request_id sama.
 */

import type { FastifyInstance } from "fastify";
import { computeCommitHash, commitHelp } from "./commit.js";
import type { Deps } from "./config.js";
import { errBadRequest, errNearDup } from "./errors.js";
import type { EngineQuery } from "./engine/client.js";
import { FIXTURE_NEAR_DUP, FIXTURE_ORIGINAL } from "./fixtures.js";
import { parseBaseUnit, toDisplay } from "./money.js";
import { buildProfile } from "./profile.js";
import { ZERO_BYTES32 } from "./chain/types.js";
import type { Address, Hex } from "viem";

const now = () => Math.floor(Date.now() / 1000);

async function getImageBytes(body: Record<string, unknown>): Promise<Uint8Array> {
  if (typeof body.image_b64 === "string") {
    return new Uint8Array(Buffer.from(body.image_b64, "base64"));
  }
  if (typeof body.image_url === "string") {
    const res = await fetch(body.image_url);
    if (!res.ok) throw errBadRequest(`gagal fetch image_url: ${res.status}`);
    return new Uint8Array(await res.arrayBuffer());
  }
  throw errBadRequest("wajib salah satu: image_b64 atau image_url");
}

/** Jalankan fn, tapi kembalikan respons tersimpan bila request_id sudah pernah. */
async function idempotent(
  deps: Deps,
  requestId: unknown,
  fn: () => Promise<unknown>,
): Promise<unknown> {
  if (typeof requestId !== "string" || !requestId) return fn();
  const cached = deps.store.getIdempotent(requestId);
  if (cached !== undefined) return cached;
  const out = await fn();
  deps.store.putIdempotent(requestId, out);
  return out;
}

export function registerRoutes(app: FastifyInstance, deps: Deps): void {
  const { engine, chain, signer } = deps;

  app.get("/healthz", async () => ({ status: "ok", signer: signer.address }));

  // ── verify ─────────────────────────────────────────────────────────────────
  app.post("/v1/verify", async (req) => {
    const body = (req.body ?? {}) as Record<string, unknown>;

    let eng: EngineQuery;
    if (deps.demoMode) {
      eng = body.demo === "near_dup" ? FIXTURE_NEAR_DUP : FIXTURE_ORIGINAL;
    } else {
      eng = await engine.query(await getImageBytes(body));
    }

    const signed = await signer.sign(eng.asset_sha256 as Hex, eng.verdict, eng.phashes as Hex[], now());

    let premium;
    if (typeof body.declared_value === "string") {
      const dv = parseBaseUnit(body.declared_value);
      premium = {
        declaredValue: dv,
        premium: await chain.quotePremium(dv),
        fraudBond: await chain.fraudBondAmount(),
      };
    }
    return buildProfile({ requestId: String(body.request_id ?? ""), engine: eng, signed, premium });
  });

  // ── commit ───────────────────────────────────────────────────────────────
  app.post("/v1/commit", async (req) => {
    const body = (req.body ?? {}) as Record<string, unknown>;
    return idempotent(deps, body.request_id, async () => {
      let commitHash: Hex;
      if (typeof body.commit_hash === "string") {
        commitHash = body.commit_hash as Hex;
      } else if (
        typeof body.phash0 === "string" &&
        typeof body.salt === "string" &&
        typeof body.creator === "string"
      ) {
        commitHash = computeCommitHash(body.phash0 as Hex, body.salt as Hex, body.creator as Address);
      } else {
        throw errBadRequest("wajib commit_hash, atau (phash0 + salt + creator) untuk dihitung server");
      }
      const { txHash, timestamp } = await chain.commit(commitHash);
      return { commit_hash: commitHash, tx_hash: txHash, timestamp, helper: commitHelp() };
    });
  });

  // ── register_and_mint ────────────────────────────────────────────────────
  app.post("/v1/mint", async (req) => {
    const body = (req.body ?? {}) as Record<string, unknown>;
    return idempotent(deps, body.request_id, async () => {
      if (typeof body.creator_address !== "string") throw errBadRequest("creator_address wajib");
      if (typeof body.declared_value !== "string") throw errBadRequest("declared_value (base-unit string) wajib");
      const creator = body.creator_address as Address;
      const declaredValue = parseBaseUnit(body.declared_value);

      const raw = await getImageBytes(body);
      const eng = await engine.query(raw);
      if (eng.verdict === "NEAR_DUP") throw errNearDup();

      const fraudBond = await chain.fraudBondAmount();
      const premium = await chain.quotePremium(declaredValue);
      const phashes = eng.phashes as [Hex, Hex, Hex, Hex];

      const revealedCommit =
        typeof body.salt === "string"
          ? computeCommitHash(phashes[0], body.salt as Hex, creator)
          : ZERO_BYTES32;

      const assetURI = (body.asset_uri as string) ?? `sha256:${eng.asset_sha256}`;
      const tokenURI = (body.token_uri as string) ?? assetURI;

      const { entryId, certId, txHash } = await chain.registerAndMint({
        to: creator,
        phashes,
        embCommit: eng.embedding_commit as Hex,
        revealedCommit,
        assetURI,
        tokenURI_: tokenURI,
        declaredValue,
        fraudBond,
        premium,
        insurable: eng.insurable,
      });

      // Karya ter-mint menyemai registry (§F10) — kueri berikutnya melihatnya.
      await engine.index(raw, "cachet-mint", `cert:${certId}`);

      const signed = await signer.sign(eng.asset_sha256 as Hex, eng.verdict, phashes, now());
      const profile = buildProfile({
        requestId: String(body.request_id ?? ""),
        engine: eng,
        signed,
        premium: { declaredValue, premium, fraudBond },
      });

      return {
        cert_id: certId.toString(),
        entry_id: entryId.toString(),
        tx_hash: txHash,
        cert_page_url: `${deps.certPageBase}/cert/${certId}`,
        profile,
      };
    });
  });

  // ── get_certificate ──────────────────────────────────────────────────────
  app.get("/v1/cert/:id", async (req) => {
    const id = (req.params as { id: string }).id;
    if (!/^\d+$/.test(id)) throw errBadRequest("cert id harus angka");
    const certId = BigInt(id);

    const data = await chain.certData(certId);
    const owner = await chain.ownerOf(certId);
    // Chain = sumber kebenaran "coverage aktif" (isCoverageActive pakai
    // block.timestamp). Jam gateway HANYA untuk membedakan dua keadaan non-aktif
    // (PENDING vs EXPIRED) — di produksi Date.now ≈ block.timestamp.
    const active = await chain.isCoverageActive(certId);
    const t = now();

    let status: string;
    if (data.revoked) status = "REVOKED";
    else if (!data.insurable) status = "NOT_INSURABLE";
    else if (active) status = "ACTIVE";
    else if (t < data.coverageStart) status = "PENDING";
    else status = "EXPIRED";

    return {
      cert_id: id,
      status,
      owner,
      entry_id: data.entryId.toString(),
      declared_value: { base: data.declaredValue.toString(), display: toDisplay(data.declaredValue) },
      coverage: {
        start: data.coverageStart,
        end: data.coverageEnd,
        active,
      },
      minted_at: data.mintedAt,
      age_days: Math.floor((t - data.mintedAt) / 86400),
      challenges_survived: data.challengesSurvived,
      cert_page_url: `${deps.certPageBase}/cert/${id}`,
    };
  });

  // ── challenge_certificate ──────────────────────────────────────────────────
  app.post("/v1/challenge", async (req) => {
    const body = (req.body ?? {}) as Record<string, unknown>;
    return idempotent(deps, body.request_id, async () => {
      if (typeof body.cert_id !== "string" && typeof body.cert_id !== "number") {
        throw errBadRequest("cert_id wajib");
      }
      if (typeof body.evidence_uri !== "string" || !body.evidence_uri) {
        throw errBadRequest("evidence_uri wajib (bukti admissible)");
      }
      const certId = BigInt(body.cert_id as string);
      const { challengeId, txHash } = await chain.challenge(certId, body.evidence_uri);

      const vault = chain.vaultAddress();
      const bond = await chain.challengeBondAmount();
      return {
        challenge_id: challengeId.toString(),
        tx_hash: txHash,
        // Instruksi EKSPLISIT (RFC-001 P6): approve ke VAULT, bukan ChallengeManager.
        instructions: {
          approve_target: vault,
          pay_token: chain.payTokenAddress(),
          bond: { base: bond.toString(), display: toDisplay(bond) },
          steps: [
            `payToken.approve(${vault}, ${bond.toString()})`,
            `ChallengeManager.challenge(${certId.toString()}, evidenceURI)`,
          ],
          warning: "Approve ke alamat VAULT, BUKAN ChallengeManager — approve ke ChallengeManager akan revert.",
        },
      };
    });
  });

  // ── watch_subscribe ────────────────────────────────────────────────────────
  app.post("/v1/watch", async (req) => {
    const body = (req.body ?? {}) as Record<string, unknown>;
    return idempotent(deps, body.request_id, async () => {
      if (typeof body.cert_id !== "string" && typeof body.cert_id !== "number") {
        throw errBadRequest("cert_id wajib");
      }
      if (typeof body.webhook_url !== "string" && typeof body.email !== "string") {
        throw errBadRequest("wajib webhook_url atau email");
      }
      const sub = deps.store.addSubscription({
        cert_id: String(body.cert_id),
        webhook_url: body.webhook_url as string | undefined,
        email: body.email as string | undefined,
      });
      return { subscription_id: sub.id, cert_id: sub.cert_id };
    });
  });
}

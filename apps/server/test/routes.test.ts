import { afterEach, describe, expect, it, vi } from "vitest";

import { StubChainClient } from "../src/chain/stub.js";
import { engineResult, FakeEngineClient, imgPayload, makeApp } from "./helpers.js";

describe("POST /v1/verify", () => {
  it("ORIGINAL → profil §3.2 tertandatangani, tanpa premi bila tak ada declared_value", async () => {
    const { app } = await makeApp({ verdict: "ORIGINAL" });
    const res = await app.inject({ method: "POST", url: "/v1/verify", payload: imgPayload });
    expect(res.statusCode).toBe(200);
    const p = res.json();
    expect(p.verdict).toBe("ORIGINAL");
    expect(p.version).toBe("1.0");
    expect(p.phashes_hash).toMatch(/^0x[0-9a-f]{64}$/);
    expect(p.signed.signature).toMatch(/^0x/);
    expect(p.premium_quote).toBeUndefined();
  });

  it("dengan declared_value → premium_quote string base-unit + _display", async () => {
    const { app } = await makeApp({ verdict: "ORIGINAL" });
    const res = await app.inject({
      method: "POST",
      url: "/v1/verify",
      payload: { ...imgPayload, declared_value: "50000000" },
    });
    const p = res.json();
    expect(p.premium_quote.declared_value).toBe("50000000");
    expect(p.premium_quote.premium).toBe("1000000"); // 2%
    expect(p.premium_quote.fraud_bond).toBe("5000000");
    expect(p.premium_quote._display.premium).toBe("1.000000");
  });

  it("tanpa image → 400 { error:{code,message} }", async () => {
    const { app } = await makeApp();
    const res = await app.inject({ method: "POST", url: "/v1/verify", payload: {} });
    expect(res.statusCode).toBe(400);
    expect(res.json().error.code).toBe("BAD_REQUEST");
  });
});

describe("POST /v1/verify — SSRF via image_url (B4)", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("image_url ke jaringan internal → 400, fetch TIDAK PERNAH dipanggil", async () => {
    const { app } = await makeApp({ verdict: "ORIGINAL" });
    const spy = vi.fn();
    vi.stubGlobal("fetch", spy);

    const res = await app.inject({
      method: "POST",
      url: "/v1/verify",
      payload: { image_url: "https://127.0.0.1:8100/healthz" },
    });

    expect(res.statusCode).toBe(400);
    // Inti fix: guard menolak SEBELUM dial, bukan menyaring status sesudahnya —
    // kalau fetch sempat dipanggil, oracle status-code masih terbuka.
    expect(spy).not.toHaveBeenCalled();
  });

  it("image_url ke metadata cloud (169.254.169.254) → 400, tanpa dial", async () => {
    const { app } = await makeApp({ verdict: "ORIGINAL" });
    const spy = vi.fn();
    vi.stubGlobal("fetch", spy);

    const res = await app.inject({
      method: "POST",
      url: "/v1/verify",
      payload: { image_url: "https://169.254.169.254/latest/meta-data" },
    });

    expect(res.statusCode).toBe(400);
    expect(spy).not.toHaveBeenCalled();
  });
});

describe("POST /v1/mint", () => {
  const mintBody = {
    ...imgPayload,
    creator_address: "0x3333333333333333333333333333333333333333",
    declared_value: "50000000",
  };

  it("ORIGINAL → cert_id, cert_page_url, profil + menyemai registry", async () => {
    const { app, engine } = await makeApp({ verdict: "ORIGINAL" });
    const res = await app.inject({ method: "POST", url: "/v1/mint", payload: mintBody });
    expect(res.statusCode).toBe(200);
    const b = res.json();
    expect(b.cert_id).toBe("1");
    expect(b.cert_page_url).toBe("https://cachet.test/testnet/cert/1");
    expect(b.profile.premium_quote.premium).toBe("1000000");
    expect(engine.indexed).toEqual([{ source: "cachet-mint", uri: "cert:1" }]);
  });

  it("NEAR_DUP → 409 NEAR_DUP_REJECTED", async () => {
    const { app } = await makeApp({ verdict: "NEAR_DUP" });
    const res = await app.inject({ method: "POST", url: "/v1/mint", payload: mintBody });
    expect(res.statusCode).toBe(409);
    expect(res.json().error.code).toBe("NEAR_DUP_REJECTED");
  });

  it("GRAY_ZONE → mint jalan tapi insurable=false", async () => {
    const { app, chain } = await makeApp({ verdict: "GRAY_ZONE" });
    const res = await app.inject({ method: "POST", url: "/v1/mint", payload: mintBody });
    expect(res.statusCode).toBe(200);
    const data = await chain.certData(1n);
    expect(data.insurable).toBe(false);
  });

  it("idempoten: request_id sama → cert_id sama (tak mint dua kali)", async () => {
    const { app } = await makeApp({ verdict: "ORIGINAL" });
    const body = { ...mintBody, request_id: "req-1" };
    const a = await app.inject({ method: "POST", url: "/v1/mint", payload: body });
    const b = await app.inject({ method: "POST", url: "/v1/mint", payload: body });
    expect(a.json().cert_id).toBe("1");
    expect(b.json().cert_id).toBe("1"); // bukan 2
  });

  it("dua request PARALEL request_id sama → tetap hanya mint sekali (kunci in-flight, B3)", async () => {
    const { app, chain } = await makeApp({ verdict: "ORIGINAL" });
    const body = { ...mintBody, request_id: "req-concurrent" };
    const [a, b] = await Promise.all([
      app.inject({ method: "POST", url: "/v1/mint", payload: body }),
      app.inject({ method: "POST", url: "/v1/mint", payload: body }),
    ]);
    expect(a.json().cert_id).toBe("1");
    expect(b.json().cert_id).toBe("1"); // bukan 2 — tanpa kunci, race bisa mint dobel
    // Bukti langsung di "chain": cert #2 tidak pernah ada.
    await expect(chain.certData(2n)).rejects.toMatchObject({ code: "InvalidCertId" });
  });
});

describe("POST /v1/mint — kolateral dari kreator", () => {
  const CREATOR = "0x3333333333333333333333333333333333333333" as const;
  const mintBody = { ...imgPayload, creator_address: CREATOR, declared_value: "50000000" };

  it("kreator sudah approve + saldo cukup → collateral_source=creator, saldo berkurang tepat fraudBond+premium", async () => {
    const { app, chain } = await makeApp({ verdict: "ORIGINAL" });
    const fraudBond = await chain.fraudBondAmount();
    const premium = await chain.quotePremium(50_000_000n);
    const needed = fraudBond + premium;

    chain.setCreatorBalance(CREATOR, needed + 1_000_000n); // ada sisa
    chain.setCreatorAllowance(CREATOR, needed);

    const res = await app.inject({ method: "POST", url: "/v1/mint", payload: mintBody });
    expect(res.statusCode).toBe(200);
    const b = res.json();
    expect(b.collateral_source).toBe("creator");
    expect(b.collateral_tx_hash).toMatch(/^0x/);

    // Bukti langsung: allowance & saldo di stub genuinely berkurang.
    const after = await chain.pullCollateralFromCreator(CREATOR, 1n);
    expect(after).toBeNull(); // allowance sudah habis dipakai, sisa < 1n tak mungkin cukup
  });

  it("kreator belum approve sama sekali → fallback collateral_source=gateway (TIDAK breaking)", async () => {
    const { app } = await makeApp({ verdict: "ORIGINAL" });
    const res = await app.inject({ method: "POST", url: "/v1/mint", payload: mintBody });
    expect(res.statusCode).toBe(200);
    const b = res.json();
    expect(b.collateral_source).toBe("gateway");
    expect(b.collateral_tx_hash).toBeUndefined();
    expect(b.cert_id).toBe("1"); // mint tetap sukses persis seperti sebelum fitur ini ada
  });

  it("allowance ADA tapi kurang dari kebutuhan → tetap fallback gateway, bukan error", async () => {
    const { app, chain } = await makeApp({ verdict: "ORIGINAL" });
    const fraudBond = await chain.fraudBondAmount();
    const premium = await chain.quotePremium(50_000_000n);
    const needed = fraudBond + premium;

    chain.setCreatorBalance(CREATOR, needed);
    chain.setCreatorAllowance(CREATOR, needed - 1n); // kurang 1 unit

    const res = await app.inject({ method: "POST", url: "/v1/mint", payload: mintBody });
    expect(res.statusCode).toBe(200);
    expect(res.json().collateral_source).toBe("gateway");
  });
});

describe("GET /v1/cert/:id", () => {
  it("status PENDING saat masih waiting period", async () => {
    const { app } = await makeApp({ verdict: "ORIGINAL" }); // waiting default 72h
    await app.inject({
      method: "POST",
      url: "/v1/mint",
      payload: { ...imgPayload, creator_address: "0x3333333333333333333333333333333333333333", declared_value: "50000000" },
    });
    const res = await app.inject({ method: "GET", url: "/v1/cert/1" });
    const c = res.json();
    expect(c.status).toBe("PENDING");
    expect(c.declared_value.display).toBe("50.000000");
  });

  it("status ACTIVE dengan waiting 0 (clock cepat)", async () => {
    let t = 1_000_000;
    const stub = new StubChainClient({ waitingPeriodSeconds: 0, coverageTermSeconds: 1_000_000, nowFn: () => t });
    const { app } = await makeApp({ verdict: "ORIGINAL", stub });
    await app.inject({
      method: "POST",
      url: "/v1/mint",
      payload: { ...imgPayload, creator_address: "0x3333333333333333333333333333333333333333", declared_value: "10000000" },
    });
    t += 10;
    const res = await app.inject({ method: "GET", url: "/v1/cert/1" });
    expect(res.json().status).toBe("ACTIVE");
  });
});

describe("POST /v1/challenge", () => {
  it("mengembalikan instruksi approve ke VAULT (RFC-001 P6), TIDAK mengirim tx sendiri", async () => {
    const { app, chain } = await makeApp({ verdict: "ORIGINAL" });
    await app.inject({
      method: "POST",
      url: "/v1/mint",
      payload: { ...imgPayload, creator_address: "0x3333333333333333333333333333333333333333", declared_value: "10000000" },
    });
    const res = await app.inject({
      method: "POST",
      url: "/v1/challenge",
      payload: { cert_id: "1", evidence_uri: "ipfs://bukti" },
    });
    expect(res.statusCode).toBe(200);
    const b = res.json();
    // Gateway tidak lagi menggugat atas nama sendiri: tidak ada challenge_id/tx_hash,
    // dan tidak ada gugatan yang benar-benar terbuka di chain untuk cert ini.
    expect(b.challenge_id).toBeUndefined();
    expect(b.tx_hash).toBeUndefined();
    expect(b.cert_id).toBe("1");
    expect(b.instructions.challenge_manager).toBe(chain.challengeManagerAddress());
    expect(b.instructions.approve_target).toBe(chain.vaultAddress());
    expect(b.instructions.bond.base).toBe((await chain.challengeBondAmount()).toString());
    expect(b.instructions.warning).toMatch(/VAULT/);
    expect(b.instructions.warning).toMatch(/wallet-mu sendiri/);
    expect(b.instructions.steps[0]).toMatch(/approve/);

    // Bukti langsung: cert masih bisa digugat SUNGGUHAN (belum ada gugatan
    // terbuka dari panggilan REST di atas) — kalau gateway sudah menggugat,
    // ini akan gagal dengan ChallengeAlreadyOpen.
    await expect(chain.challenge(1n, "ipfs://bukti-asli")).resolves.toMatchObject({ challengeId: 1n });
  });

  it("cert_id tak dikenal → error, bukan instruksi", async () => {
    const { app } = await makeApp({ verdict: "ORIGINAL" });
    const res = await app.inject({
      method: "POST",
      url: "/v1/challenge",
      payload: { cert_id: "99", evidence_uri: "ipfs://bukti" },
    });
    expect(res.statusCode).toBeGreaterThanOrEqual(400);
  });

  it("cert yang sudah revoked → 409 CertificateAlreadyRevoked", async () => {
    const { app, chain } = await makeApp({ verdict: "ORIGINAL" });
    await app.inject({
      method: "POST",
      url: "/v1/mint",
      payload: { ...imgPayload, creator_address: "0x3333333333333333333333333333333333333333", declared_value: "10000000" },
    });
    await chain.challenge(1n, "ipfs://bukti");
    chain._resolve(1n, true); // challenger menang → revoked

    const res = await app.inject({
      method: "POST",
      url: "/v1/challenge",
      payload: { cert_id: "1", evidence_uri: "ipfs://bukti-lain" },
    });
    expect(res.statusCode).toBe(409);
    expect(res.json().error.code).toBe("CertificateAlreadyRevoked");
  });
});

describe("POST /v1/watch", () => {
  it("subscribe via image_b64 → subscription_id + titik mulai", async () => {
    const { app } = await makeApp();
    const res = await app.inject({
      method: "POST",
      url: "/v1/watch",
      payload: { cert_id: "1", webhook_url: "https://hook.test/x", ...imgPayload },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().subscription_id).toMatch(/^sub_/);
    expect(res.json().watching_from_entry).toBe(0);
  });

  it("subscribe via cert yang di-mint di gateway ini → pakai fingerprint tersimpan", async () => {
    const { app, deps } = await makeApp({ verdict: "ORIGINAL" });
    await app.inject({
      method: "POST",
      url: "/v1/mint",
      payload: { ...imgPayload, creator_address: "0x3333333333333333333333333333333333333333", declared_value: "10000000" },
    });
    const res = await app.inject({
      method: "POST",
      url: "/v1/watch",
      payload: { cert_id: "1", webhook_url: "https://hook.test/x" },
    });
    expect(res.statusCode).toBe(200);
    const sub = deps.store.listSubscriptions().find((s) => s.cert_id === "1");
    expect(sub?.entry_id).toBe(1); // entri corpus dari mint
    expect(sub?.phashes?.length).toBe(4);
  });

  it("cert tak dikenal & tanpa image → 400", async () => {
    const { app } = await makeApp();
    const res = await app.inject({
      method: "POST",
      url: "/v1/watch",
      payload: { cert_id: "99", webhook_url: "https://hook.test/x" },
    });
    expect(res.statusCode).toBe(400);
  });
});

describe("DEMO_MODE", () => {
  it("verify membalas fixture tanpa engine", async () => {
    const { app } = await makeApp({ demoMode: true, engine: new FakeEngineClient(() => { throw new Error("tak boleh dipanggil"); }) });
    const res = await app.inject({ method: "POST", url: "/v1/verify", payload: { demo: "near_dup" } });
    expect(res.statusCode).toBe(200);
    expect(res.json().verdict).toBe("NEAR_DUP");
  });
});

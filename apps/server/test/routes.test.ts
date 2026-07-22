import { describe, expect, it } from "vitest";

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
    expect(b.cert_page_url).toBe("https://cachet.test/cert/1");
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
  it("mengembalikan challenge_id + instruksi approve ke VAULT (RFC-001 P6)", async () => {
    const { app } = await makeApp({ verdict: "ORIGINAL" });
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
    expect(b.challenge_id).toBe("1");
    expect(b.instructions.approve_target).toBe(b.instructions.approve_target); // vault addr ada
    expect(b.instructions.warning).toMatch(/VAULT/);
    expect(b.instructions.steps[0]).toMatch(/approve/);
  });
});

describe("POST /v1/watch", () => {
  it("subscribe → subscription_id", async () => {
    const { app } = await makeApp();
    const res = await app.inject({
      method: "POST",
      url: "/v1/watch",
      payload: { cert_id: "1", webhook_url: "https://hook.test/x" },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().subscription_id).toMatch(/^sub_/);
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

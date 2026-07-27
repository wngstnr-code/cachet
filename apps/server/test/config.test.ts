import { afterEach, describe, expect, it } from "vitest";

import { loadConfig, loadX402Options } from "../src/config.js";

const PAY_TO = "0x1111111111111111111111111111111111111111" as const;
const completeEnv: NodeJS.ProcessEnv = {
  X402_BYPASS: "0",
  X402_NETWORK: "eip155:1952",
  X402_PAY_TO: PAY_TO,
  X402_RESOURCE_BASE: "https://api.cachet.test",
  OKX_BASE_URL: "https://web3.okx.com",
  OKX_API_KEY: "test-api-key",
  OKX_SECRET_KEY: "test-secret-key",
  OKX_PASSPHRASE: "test-passphrase",
};

describe("x402 runtime config", () => {
  it("menerima config testnet lengkap", () => {
    const options = loadX402Options(completeEnv, { chainId: 1952, payTo: PAY_TO });
    expect(options.bypass).toBe(false);
    expect(options.network).toBe("eip155:1952");
    expect(options.resourceBase).toBe("https://api.cachet.test");
    expect(options.facilitator).toBeDefined();
  });

  it("bypass lokal tidak memerlukan credential atau HTTPS", () => {
    const options = loadX402Options({ X402_BYPASS: "1" }, { chainId: 1952, payTo: PAY_TO });
    expect(options.bypass).toBe(true);
    expect(options.facilitator).toBeUndefined();
  });

  it.each(["OKX_API_KEY", "OKX_SECRET_KEY", "OKX_PASSPHRASE"])(
    "menolak credential parsial tanpa %s",
    (missing) => {
      const env = { ...completeEnv };
      delete env[missing];
      expect(() => loadX402Options(env, { chainId: 1952, payTo: PAY_TO })).toThrow(/wajib diisi bersama/);
    },
  );

  it("menerima config mainnet lengkap (eip155:196)", () => {
    const options = loadX402Options(
      { ...completeEnv, X402_NETWORK: "eip155:196" },
      { chainId: 196, payTo: PAY_TO },
    );
    expect(options.bypass).toBe(false);
    expect(options.network).toBe("eip155:196");
  });

  it("menolak network di luar X Layer", () => {
    expect(() =>
      loadX402Options({ ...completeEnv, X402_NETWORK: "eip155:1" }, { chainId: 1952, payTo: PAY_TO }),
    ).toThrow(/wajib salah satu dari/);
  });

  // Justru inilah kegagalan yang paling mahal: gateway berjalan di satu chain
  // tapi mengiklankan chain lain di challenge 402 — pembeli mengirim dana ke
  // chain yang salah dan dana itu hilang. Lebih baik gateway menolak menyala.
  it("menolak network yang tidak cocok dengan chain gateway", () => {
    expect(() =>
      loadX402Options({ ...completeEnv, X402_NETWORK: "eip155:196" }, { chainId: 1952, payTo: PAY_TO }),
    ).toThrow(/tidak cocok dengan chain gateway/);

    expect(() =>
      loadX402Options({ ...completeEnv, X402_NETWORK: "eip155:1952" }, { chainId: 196, payTo: PAY_TO }),
    ).toThrow(/tidak cocok dengan chain gateway/);
  });

  it("menolak payTo bukan alamat EVM", () => {
    expect(() =>
      loadX402Options({ ...completeEnv, X402_PAY_TO: "not-an-address" }, { chainId: 1952, payTo: PAY_TO }),
    ).toThrow(/alamat EVM/);
  });

  it("menolak public resource dan Broker URL non-HTTPS", () => {
    expect(() =>
      loadX402Options({ ...completeEnv, X402_RESOURCE_BASE: "http://api.cachet.test" }, { chainId: 1952, payTo: PAY_TO }),
    ).toThrow(/X402_RESOURCE_BASE wajib memakai HTTPS/);
    expect(() =>
      loadX402Options({ ...completeEnv, OKX_BASE_URL: "http://web3.okx.com" }, { chainId: 1952, payTo: PAY_TO }),
    ).toThrow(/OKX_BASE_URL wajib memakai HTTPS/);
  });

  it("menolak HTTPS Broker selain host resmi OKX", () => {
    expect(() =>
      loadX402Options({ ...completeEnv, OKX_BASE_URL: "https://example.com" }, { chainId: 1952, payTo: PAY_TO }),
    ).toThrow(/wajib https:\/\/web3\.okx\.com/);
  });
});

describe("loadConfig — cert_page_url bawa slug chain (B1)", () => {
  const keys = ["CHAIN_ID", "CERT_PAGE_BASE"] as const;
  const saved: Record<string, string | undefined> = {};

  afterEach(() => {
    for (const k of keys) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  });

  function withEnv(overrides: Partial<Record<(typeof keys)[number], string>>) {
    for (const k of keys) saved[k] = process.env[k];
    for (const k of keys) {
      if (overrides[k] === undefined) delete process.env[k];
      else process.env[k] = overrides[k];
    }
  }

  it("CHAIN_ID=196 → certPageBase berakhiran /mainnet", () => {
    withEnv({ CHAIN_ID: "196", CERT_PAGE_BASE: "https://cachetprotocol.vercel.app" });
    expect(loadConfig().certPageBase).toBe("https://cachetprotocol.vercel.app/mainnet");
  });

  it("CHAIN_ID=1952 → certPageBase berakhiran /testnet", () => {
    withEnv({ CHAIN_ID: "1952", CERT_PAGE_BASE: "https://cachetprotocol.vercel.app" });
    expect(loadConfig().certPageBase).toBe("https://cachetprotocol.vercel.app/testnet");
  });

  it("CHAIN_ID tak diset (default 1952) → /testnet", () => {
    withEnv({ CERT_PAGE_BASE: "https://cachetprotocol.vercel.app" });
    expect(loadConfig().certPageBase).toBe("https://cachetprotocol.vercel.app/testnet");
  });

  it("CERT_PAGE_BASE dengan trailing slash tetap benar", () => {
    withEnv({ CHAIN_ID: "196", CERT_PAGE_BASE: "https://cachetprotocol.vercel.app/" });
    expect(loadConfig().certPageBase).toBe("https://cachetprotocol.vercel.app/mainnet");
  });
});

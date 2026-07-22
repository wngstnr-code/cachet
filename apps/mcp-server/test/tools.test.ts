import { describe, expect, it } from "vitest";

import { GatewayClient, type FetchFn } from "../src/gateway.js";
import { makeTools, type ToolSpec } from "../src/tools.js";

function fakeFetch(handler: (url: string, init?: RequestInit) => Response): FetchFn {
  return (async (url: string | URL | Request, init?: RequestInit) =>
    handler(String(url), init)) as unknown as FetchFn;
}

function toolMap(gw: GatewayClient): Record<string, ToolSpec> {
  return Object.fromEntries(makeTools(gw).map((t) => [t.name, t]));
}

describe("MCP tools → forward ke gateway", () => {
  it("mendaftarkan 6 tool §3.3", () => {
    const tools = makeTools(new GatewayClient("http://gw"));
    expect(tools.map((t) => t.name).sort()).toEqual(
      ["challenge_certificate", "commit_work", "get_certificate", "register_and_mint", "verify_originality", "watch_subscribe"].sort(),
    );
  });

  it("verify_originality meneruskan ke POST /v1/verify + mengembalikan body", async () => {
    let seen: { url: string; body: unknown } | null = null;
    const gw = new GatewayClient(
      "http://gw",
      fakeFetch((url, init) => {
        seen = { url, body: JSON.parse(String(init?.body)) };
        return new Response(JSON.stringify({ verdict: "ORIGINAL" }), { status: 200 });
      }),
    );
    const res = await toolMap(gw).verify_originality.handler({ image_b64: "AAAA", declared_value: "50000000" });
    expect(seen!.url).toBe("http://gw/v1/verify");
    expect((seen!.body as any).declared_value).toBe("50000000");
    expect(res.isError).toBeFalsy();
    expect(res.content[0].text).toContain("ORIGINAL");
  });

  it("get_certificate meneruskan id di path (GET)", async () => {
    let seenUrl = "";
    const gw = new GatewayClient(
      "http://gw",
      fakeFetch((url) => {
        seenUrl = url;
        return new Response(JSON.stringify({ status: "PENDING" }), { status: 200 });
      }),
    );
    const res = await toolMap(gw).get_certificate.handler({ cert_id: "7" });
    expect(seenUrl).toBe("http://gw/v1/cert/7");
    expect(res.content[0].text).toContain("PENDING");
  });

  it("402 dari gateway → tool isError + payment_required_header + hint", async () => {
    const gw = new GatewayClient(
      "http://gw",
      fakeFetch(
        () =>
          new Response(JSON.stringify({ x402Version: 1, error: "payment required" }), {
            status: 402,
            headers: { "payment-required": "BASE64HEADER" },
          }),
      ),
    );
    const res = await toolMap(gw).verify_originality.handler({ image_b64: "AAAA" });
    expect(res.isError).toBe(true);
    const payload = JSON.parse(res.content[0].text);
    expect(payload.status).toBe(402);
    expect(payload.payment_required_header).toBe("BASE64HEADER");
    expect(payload.hint).toMatch(/x402/);
  });

  it("register_and_mint meneruskan body lengkap", async () => {
    let body: any = null;
    const gw = new GatewayClient(
      "http://gw",
      fakeFetch((_url, init) => {
        body = JSON.parse(String(init?.body));
        return new Response(JSON.stringify({ cert_id: "1" }), { status: 200 });
      }),
    );
    await toolMap(gw).register_and_mint.handler({
      image_b64: "AAAA",
      creator_address: "0x3333333333333333333333333333333333333333",
      declared_value: "50000000",
    });
    expect(body.creator_address).toMatch(/^0x3333/);
    expect(body.declared_value).toBe("50000000");
  });
});

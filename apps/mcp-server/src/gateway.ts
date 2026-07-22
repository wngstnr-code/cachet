/**
 * Klien HTTP ke gateway REST (apps/server). MCP server hanya MENERUSKAN —
 * seluruh logika (verify, premi, chain) ada di gateway. Pembayaran x402 ditangani
 * oleh klien pemanggil: bila gateway membalas 402, tool mengembalikan
 * payment requirements apa adanya supaya agent pemanggil membayar lalu retry.
 *
 * fetchFn bisa disuntik untuk test (tanpa gateway sungguhan).
 */

export type FetchFn = typeof fetch;

export interface GatewayResult {
  ok: boolean;
  status: number;
  body: unknown;
  paymentRequired?: string; // header PAYMENT-REQUIRED (base64) bila 402
}

export class GatewayClient {
  constructor(
    private baseUrl: string,
    private fetchFn: FetchFn = fetch,
  ) {}

  private async call(method: string, path: string, body?: unknown): Promise<GatewayResult> {
    const res = await this.fetchFn(this.baseUrl + path, {
      method,
      headers: body ? { "content-type": "application/json" } : undefined,
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let parsed: unknown;
    try {
      parsed = text ? JSON.parse(text) : null;
    } catch {
      parsed = text;
    }
    return {
      ok: res.ok,
      status: res.status,
      body: parsed,
      paymentRequired: res.headers.get("payment-required") ?? undefined,
    };
  }

  verify(args: Record<string, unknown>) {
    return this.call("POST", "/v1/verify", args);
  }
  commit(args: Record<string, unknown>) {
    return this.call("POST", "/v1/commit", args);
  }
  mint(args: Record<string, unknown>) {
    return this.call("POST", "/v1/mint", args);
  }
  getCertificate(certId: string) {
    return this.call("GET", `/v1/cert/${encodeURIComponent(certId)}`);
  }
  challenge(args: Record<string, unknown>) {
    return this.call("POST", "/v1/challenge", args);
  }
  watch(args: Record<string, unknown>) {
    return this.call("POST", "/v1/watch", args);
  }
}

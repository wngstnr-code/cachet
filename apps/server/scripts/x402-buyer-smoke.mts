/**
 * A5.4 direct paid smoke test: acts as an external OKX-compatible buyer against
 * the deployed public gateway. Proves 402 -> sign -> pay -> 200 with a real
 * Originality Profile and payment receipt using the official OKX x402 SDK.
 *
 * Requires a funded buyer wallet (gas + the Broker-selected settlement asset
 * from the 402 challenge, e.g. USD₮0 on X Layer Testnet). Does not touch any
 * gateway config; only calls the public HTTPS endpoint as a client.
 *
 * Usage:
 *   BUYER_PK=0x... pnpm --filter @cachet/server exec tsx scripts/x402-buyer-smoke.mts [resourceBase]
 *   ROUTE=/v1/mint BODY='{"creator_address":"0x...","declared_value":"50000000","image_b64":"..."}' \
 *     BUYER_PK=0x... pnpm --filter @cachet/server exec tsx scripts/x402-buyer-smoke.mts
 */
import { createPublicClient, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { toClientEvmSigner } from "@okxweb3/x402-evm";
import { registerExactEvmScheme } from "@okxweb3/x402-evm/exact/client";
import { x402Client, x402HTTPClient } from "@okxweb3/x402-core/client";

const RPC_URL = process.env.RPC_URL ?? "https://testrpc.xlayer.tech";
const CHAIN_ID = Number(process.env.CHAIN_ID ?? 1952);
const RESOURCE_BASE = process.argv[2] ?? process.env.X402_RESOURCE_BASE ?? "https://api.cachetprotocol.xyz";
const BUYER_PK = process.env.BUYER_PK ?? process.env.DEMO_CREATOR_PK;
const ROUTE = process.env.ROUTE ?? "/v1/verify";

// 1x1 red PNG — enough for the engine to hash/verdict as a fresh ORIGINAL asset.
const TINY_PNG_B64 =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";

const DEFAULT_BODY = { image_b64: TINY_PNG_B64, request_id: `x402-buyer-smoke-${Date.now()}` };
const REQUEST_BODY = process.env.BODY ? JSON.parse(process.env.BODY) : DEFAULT_BODY;
if (!REQUEST_BODY.request_id) REQUEST_BODY.request_id = `x402-buyer-smoke-${Date.now()}`;

if (!BUYER_PK) {
  console.error("set BUYER_PK (or DEMO_CREATOR_PK) to a funded testnet wallet");
  process.exit(1);
}

const xLayerTestnet = {
  id: CHAIN_ID,
  name: "X Layer Testnet",
  nativeCurrency: { name: "OKB", symbol: "OKB", decimals: 18 },
  rpcUrls: { default: { http: [RPC_URL] } },
} as const;

async function main() {
  const account = privateKeyToAccount(BUYER_PK as `0x${string}`);
  const publicClient = createPublicClient({ chain: xLayerTestnet, transport: http(RPC_URL) });
  const signer = toClientEvmSigner(account, publicClient);

  const client = new x402Client();
  registerExactEvmScheme(client, { signer });
  const httpClient = new x402HTTPClient(client);

  const url = `${RESOURCE_BASE}${ROUTE}`;
  const body = JSON.stringify(REQUEST_BODY);

  console.log(`buyer=${account.address}`);
  console.log(`POST ${url} (unpaid)`);
  const first = await fetch(url, { method: "POST", headers: { "content-type": "application/json" }, body });
  if (first.status !== 402) {
    throw new Error(`expected 402, got ${first.status}: ${await first.text()}`);
  }

  const paymentRequired = httpClient.getPaymentRequiredResponse((name) => first.headers.get(name));
  console.log("402 challenge:", JSON.stringify(paymentRequired.accepts, null, 2));

  const payload = await httpClient.createPaymentPayload(paymentRequired);
  const paymentHeaders = httpClient.encodePaymentSignatureHeader(payload);

  console.log(`POST ${url} (with payment signature)`);
  const second = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json", ...paymentHeaders },
    body,
  });

  const text = await second.text();
  if (second.status !== 200) {
    throw new Error(`paid request failed: ${second.status}: ${text}`);
  }

  const settleHeader = second.headers.get("payment-response") ?? second.headers.get("Payment-Response");
  console.log(`paid call succeeded: ${second.status}`);
  console.log("profile:", text);
  if (settleHeader) {
    const settle = httpClient.getPaymentSettleResponse((name) =>
      name.toLowerCase() === "payment-response" ? settleHeader : null,
    );
    console.log("settlement receipt:", JSON.stringify(settle, null, 2));
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { buildApp } from "../src/app.js";
import { StubChainClient } from "../src/chain/stub.js";
import type { Deps } from "../src/config.js";
import type { EngineClient, EngineHash, EngineQuery } from "../src/engine/client.js";
import { Store } from "../src/store.js";
import { VerdictSigner } from "../src/signer.js";

// Kunci test tetap (anvil #0) — deterministik untuk verifikasi tanda tangan.
export const TEST_PK = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" as const;

const H = (byte: string) => ("0x" + byte.repeat(32)) as `0x${string}`;

export function engineResult(verdict: EngineQuery["verdict"], over: Partial<EngineQuery> = {}): EngineQuery {
  return {
    asset_sha256: H("12"),
    verdict,
    first_seen:
      verdict === "NEAR_DUP"
        ? { is_first: false, nearest_entry_id: 1, min_hamming: 5, hashes_matched: 3 }
        : { is_first: verdict === "ORIGINAL", nearest_entry_id: null, min_hamming: 256, hashes_matched: 0 },
    distinctiveness: { score: 0.8, nearest_cosine: 0.2, label: "DISTINCTIVE" },
    ai_declaration: { c2pa_present: false, synthid_checked: false, notes: "advisory only" },
    insurable: verdict === "ORIGINAL",
    phashes: [H("a1"), H("a2"), H("a3"), H("a4")],
    embedding_commit: H("bb"),
    ...over,
  };
}

export class FakeEngineClient implements EngineClient {
  public indexed: { source: string; uri: string }[] = [];
  constructor(private responder: (raw: Uint8Array) => EngineQuery = () => engineResult("ORIGINAL")) {}

  async hash(raw: Uint8Array): Promise<EngineHash> {
    const q = this.responder(raw);
    return { asset_sha256: q.asset_sha256, phashes: q.phashes, embedding_commit: q.embedding_commit };
  }
  async query(raw: Uint8Array): Promise<EngineQuery> {
    return this.responder(raw);
  }
  async index(_raw: Uint8Array, source: string, uri: string) {
    this.indexed.push({ source, uri });
    return { entry_id: this.indexed.length, asset_sha256: H("12") };
  }
  async count() {
    return this.indexed.length;
  }
}

export async function makeApp(opts: {
  verdict?: EngineQuery["verdict"];
  stub?: StubChainClient;
  engine?: FakeEngineClient;
  demoMode?: boolean;
  x402?: Partial<Deps["x402"]>;
} = {}) {
  const chain = opts.stub ?? new StubChainClient();
  const engine = opts.engine ?? new FakeEngineClient(() => engineResult(opts.verdict ?? "ORIGINAL"));
  const signer = new VerdictSigner(TEST_PK, 1952);
  const store = new Store(mkdtempSync(join(tmpdir(), "cachet-gw-")));
  const deps: Deps = {
    engine,
    chain,
    signer,
    store,
    certPageBase: "https://cachet.test",
    demoMode: opts.demoMode ?? false,
    uploadLimitBytes: 15 * 1024 * 1024,
    x402: {
      bypass: true, // default: route test tak perlu bayar
      network: "eip155:1952",
      asset: "0x9ad14e783DCe270BE1214153E940aa686f91fa40",
      payTo: signer.address,
      ...opts.x402,
    },
  };
  const app = await buildApp(deps);
  return { app, deps, chain, engine, signer };
}

export const imgPayload = { image_b64: Buffer.from("fake-image-bytes").toString("base64") };

/**
 * Klien engine A1 (services/engine) via HTTP. Gateway TIDAK meng-import kode
 * Python — ia memanggil /hash /index /query di ENGINE_URL. Test menyuntik
 * FakeEngineClient supaya cepat & tanpa Python.
 */

export interface EngineFirstSeen {
  is_first: boolean;
  nearest_entry_id: number | null;
  min_hamming: number;
  hashes_matched: number;
}

export interface EngineQuery {
  asset_sha256: string;
  verdict: "ORIGINAL" | "NEAR_DUP" | "GRAY_ZONE";
  first_seen: EngineFirstSeen;
  distinctiveness: { score: number; nearest_cosine: number; label: string };
  ai_declaration: { c2pa_present: boolean; synthid_checked: boolean; notes: string };
  insurable: boolean;
  phashes: string[];
  embedding_commit: string;
}

export interface EngineHash {
  asset_sha256: string;
  phashes: string[];
  embedding_commit: string;
}

export interface EngineClient {
  hash(raw: Uint8Array): Promise<EngineHash>;
  query(raw: Uint8Array): Promise<EngineQuery>;
  index(raw: Uint8Array, source: string, uri: string): Promise<{ entry_id: number; asset_sha256: string }>;
  count(): Promise<number>; // ukuran corpus (untuk titik-mulai Watch)
}

function b64(raw: Uint8Array): string {
  return Buffer.from(raw).toString("base64");
}

export class HttpEngineClient implements EngineClient {
  constructor(private baseUrl: string) {}

  private async post<T>(path: string, body: unknown): Promise<T> {
    const res = await fetch(this.baseUrl + path, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`engine ${path} → ${res.status}: ${text}`);
    }
    return (await res.json()) as T;
  }

  hash(raw: Uint8Array) {
    return this.post<EngineHash>("/hash", { image_b64: b64(raw) });
  }
  query(raw: Uint8Array) {
    return this.post<EngineQuery>("/query", { image_b64: b64(raw) });
  }
  index(raw: Uint8Array, source: string, uri: string) {
    return this.post<{ entry_id: number; asset_sha256: string }>("/index", {
      image_b64: b64(raw),
      source,
      uri,
    });
  }

  async count(): Promise<number> {
    const res = await fetch(this.baseUrl + "/healthz");
    if (!res.ok) throw new Error(`engine /healthz → ${res.status}`);
    const json = (await res.json()) as { entries: number };
    return json.entries;
  }
}

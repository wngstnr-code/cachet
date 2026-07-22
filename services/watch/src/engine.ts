/** Klien engine untuk Watch — hanya butuh /neardups. */

import type { NeardupMatch } from "./types.js";

export interface NeardupsQuery {
  entry_id?: number;
  phashes?: string[];
  since_entry_id: number;
  exclude_entry_id?: number;
}

export interface NeardupsResult {
  matches: NeardupMatch[];
  corpus_size: number;
}

export interface EngineWatchClient {
  neardups(q: NeardupsQuery): Promise<NeardupsResult>;
}

export class HttpEngineWatchClient implements EngineWatchClient {
  constructor(private baseUrl: string) {}

  async neardups(q: NeardupsQuery): Promise<NeardupsResult> {
    const res = await fetch(this.baseUrl + "/neardups", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(q),
    });
    if (!res.ok) throw new Error(`engine /neardups → ${res.status}`);
    return (await res.json()) as NeardupsResult;
  }
}

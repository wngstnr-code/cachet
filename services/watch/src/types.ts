/** Bentuk subscription (cermin dari apps/server store) + draft challenge. */

export interface Subscription {
  id: string;
  cert_id: string;
  webhook_url?: string;
  email?: string;
  created_at: number;
  entry_id?: number;
  phashes?: string[];
  last_checked: number;
}

export interface NeardupMatch {
  entry_id: number;
  matched: number;
  min_hamming: number;
  source?: string | null;
  uri?: string | null;
  registered_at?: number | null;
}

export interface DraftChallenge {
  watched_cert_id: string;
  watched_entry_id: number | null;
  copy_entry_id: number;
  copy_source?: string | null;
  copy_uri?: string | null;
  matched_hashes: number;
  min_hamming: number;
  evidence_note: string;
  detected_at: number;
}

/**
 * Fixture DEMO_MODE (§13) — respons dari data tersimpan tanpa menyentuh engine/
 * chain. Untuk latihan alur video & cadangan bila RPC/engine rewel tepat saat
 * rekaman. WAJIB 0 di deployment yang dilisting. Bentuk konsisten dengan §3.2.
 *
 * Ini BUKAN untuk mengelabui: DEMO_MODE tak pernah diklaim sebagai transaksi live.
 */

import type { EngineQuery } from "./engine/client.js";

export const FIXTURE_ORIGINAL: EngineQuery = {
  asset_sha256: "0x" + "11".repeat(32),
  verdict: "ORIGINAL",
  first_seen: { is_first: true, nearest_entry_id: null, min_hamming: 256, hashes_matched: 0 },
  distinctiveness: { score: 0.87, nearest_cosine: 0.13, label: "DISTINCTIVE" },
  ai_declaration: { c2pa_present: false, synthid_checked: false, notes: "advisory only" },
  insurable: true,
  phashes: ["0x" + "a1".repeat(32), "0x" + "a2".repeat(32), "0x" + "a3".repeat(32), "0x" + "a4".repeat(32)],
  embedding_commit: "0x" + "bb".repeat(32),
};

/** "The catch": salinan yang tertangkap. */
export const FIXTURE_NEAR_DUP: EngineQuery = {
  asset_sha256: "0x" + "22".repeat(32),
  verdict: "NEAR_DUP",
  first_seen: { is_first: false, nearest_entry_id: 42, min_hamming: 8, hashes_matched: 3 },
  distinctiveness: { score: 0.12, nearest_cosine: 0.88, label: "GENERIC" },
  ai_declaration: { c2pa_present: false, synthid_checked: false, notes: "advisory only" },
  insurable: false,
  phashes: ["0x" + "c1".repeat(32), "0x" + "c2".repeat(32), "0x" + "c3".repeat(32), "0x" + "c4".repeat(32)],
  embedding_commit: "0x" + "cc".repeat(32),
};

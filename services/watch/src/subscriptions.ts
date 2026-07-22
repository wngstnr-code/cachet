/** Baca subscriptions dari store gateway (read-only). Worker punya state sendiri
 *  (state.ts) supaya tak ada tulis-menulis bersamaan ke file gateway. */

import { readFileSync } from "node:fs";

import type { Subscription } from "./types.js";

export function readSubscriptions(file: string): Subscription[] {
  try {
    const db = JSON.parse(readFileSync(file, "utf8")) as { subscriptions?: Subscription[] };
    return db.subscriptions ?? [];
  } catch {
    return []; // file belum ada / belum ada subscription
  }
}

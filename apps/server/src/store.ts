/**
 * Store JSON ber-tulis-atomik untuk subscriptions Watch + idempotensi request_id.
 *
 * Sengaja BUKAN better-sqlite3 (native build) demi kesederhanaan & nol dependency
 * di MVP — datanya kecil. Watch worker (PR-5) membaca file subscriptions yang sama
 * lewat path yang dikonfigurasi. Bisa di-swap ke SQLite nanti tanpa mengubah routes.
 */

import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

export interface Subscription {
  id: string;
  cert_id: string;
  webhook_url?: string;
  email?: string;
  created_at: number;
}

interface Db {
  subscriptions: Subscription[];
  idempotency: Record<string, unknown>;
}

function atomicWrite(path: string, data: unknown): void {
  mkdirSync(dirname(path), { recursive: true });
  const tmp = path + ".tmp";
  writeFileSync(tmp, JSON.stringify(data, null, 2));
  renameSync(tmp, path);
}

export class Store {
  private path: string;
  private db: Db;

  constructor(dir: string) {
    this.path = join(dir, "gateway.json");
    this.db = this.load();
  }

  private load(): Db {
    try {
      return JSON.parse(readFileSync(this.path, "utf8")) as Db;
    } catch {
      return { subscriptions: [], idempotency: {} };
    }
  }

  private persist(): void {
    atomicWrite(this.path, this.db);
  }

  addSubscription(sub: Omit<Subscription, "id" | "created_at">): Subscription {
    const record: Subscription = {
      id: `sub_${crypto.randomUUID()}`,
      created_at: Math.floor(Date.now() / 1000),
      ...sub,
    };
    this.db.subscriptions.push(record);
    this.persist();
    return record;
  }

  listSubscriptions(): Subscription[] {
    return this.db.subscriptions;
  }

  getIdempotent(key: string): unknown | undefined {
    return this.db.idempotency[key];
  }

  putIdempotent(key: string, response: unknown): void {
    this.db.idempotency[key] = response;
    this.persist();
  }
}

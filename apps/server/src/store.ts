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
  // Fingerprint aset yang diawasi + titik mulai — diisi gateway saat subscribe
  // supaya Watch worker tahu apa yang dicari tanpa akses balik ke gateway.
  entry_id?: number; // entri corpus aset diawasi (bila di-mint via gateway ini)
  phashes?: string[]; // fallback bila entry_id tak diketahui
  last_checked: number; // ukuran corpus saat subscribe → hanya entri lebih baru yang memicu
}

export interface CertMint {
  entry_id: number;
  phashes: string[];
}

interface Db {
  subscriptions: Subscription[];
  idempotency: Record<string, unknown>;
  certMints: Record<string, CertMint>;
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
  // In-memory saja, TIDAK di-persist: hanya untuk menandai "request_id ini
  // sedang dieksekusi di proses ini". Dua request paralel ber-request_id sama
  // yang lolos idempotency check (belum tersimpan) tanpa ini akan sama-sama
  // menjalankan fn() — mis. mint dua kali, bond+premi keluar dobel dari
  // gateway (B3). Aman untuk deployment single-instance (lihat
  // scripts/deploy/*.yml — tidak ada replicas).
  private inFlight = new Map<string, Promise<unknown>>();

  constructor(dir: string) {
    this.path = join(dir, "gateway.json");
    this.db = this.load();
  }

  private load(): Db {
    try {
      const db = JSON.parse(readFileSync(this.path, "utf8")) as Partial<Db>;
      return {
        subscriptions: db.subscriptions ?? [],
        idempotency: db.idempotency ?? {},
        certMints: db.certMints ?? {},
      };
    } catch {
      return { subscriptions: [], idempotency: {}, certMints: {} };
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

  recordMint(certId: string, mint: CertMint): void {
    this.db.certMints[certId] = mint;
    this.persist();
  }

  getMint(certId: string): CertMint | undefined {
    return this.db.certMints[certId];
  }

  getIdempotent(key: string): unknown | undefined {
    return this.db.idempotency[key];
  }

  getInFlight(key: string): Promise<unknown> | undefined {
    return this.inFlight.get(key);
  }

  setInFlight(key: string, p: Promise<unknown>): void {
    this.inFlight.set(key, p);
  }

  clearInFlight(key: string): void {
    this.inFlight.delete(key);
  }

  putIdempotent(key: string, response: unknown): void {
    this.db.idempotency[key] = response;
    this.persist();
  }
}
